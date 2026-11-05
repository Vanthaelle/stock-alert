// Stock-Alert front end. This file uses plain JavaScript and fetch().
'use strict';

const API_URL = 'api/index.php';
const state = {
    csrfToken: null,
    username: null,
    currentView: 'dashboard',
    inventoryRows: [],
    warehouseRows: [],
    chartInstances: {},
};

const homeView = document.getElementById('home-view');
const adminView = document.getElementById('admin-view');
const adminContent = document.getElementById('admin-content');
const pageTitle = document.getElementById('page-title');
const modalRoot = document.getElementById('modal-root');
const toastContainer = document.getElementById('toast-container');

function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, (character) => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;',
    })[character]);
}

function numberFormat(value) {
    return new Intl.NumberFormat().format(Number(value || 0));
}

function formatDate(value) {
    if (!value) return '—';
    // MySQL returns a local date/time string without a timezone suffix.
    const date = new Date(String(value).replace(' ', 'T'));
    if (Number.isNaN(date.getTime())) return escapeHtml(value);
    return date.toLocaleString([], { year: 'numeric', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
}

async function api(action, options = {}) {
    const method = options.method || 'GET';
    const headers = {};
    const fetchOptions = { method, credentials: 'same-origin', headers };

    if (method !== 'GET') {
        headers['Content-Type'] = 'application/json';
        if (action !== 'login' && state.csrfToken) {
            headers['X-CSRF-Token'] = state.csrfToken;
        }
        fetchOptions.body = JSON.stringify(options.body || {});
    }

    let response;
    try {
        response = await fetch(`${API_URL}?action=${encodeURIComponent(action)}`, fetchOptions);
    } catch (error) {
        throw new Error('Could not reach the local server. Check that Apache and MySQL are running in XAMPP.');
    }

    let result;
    try {
        result = await response.json();
    } catch (error) {
        throw new Error('The server returned an unreadable response. Check the PHP files and Apache error log.');
    }

    if (!response.ok || result.success === false) {
        throw new Error(result.message || `Request failed (${response.status}).`);
    }
    return result;
}

function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `<span class="toast-mark">${type === 'success' ? '✓' : '!'}</span><span>${escapeHtml(message)}</span>`;
    toastContainer.appendChild(toast);
    window.setTimeout(() => toast.remove(), 4200);
}

function setAlertBadge(count) {
    const badge = document.getElementById('nav-alert-count');
    const safeCount = Math.max(0, Number(count || 0));
    badge.textContent = safeCount > 99 ? '99+' : String(safeCount);
    badge.hidden = safeCount === 0;
}

function emptyState(title, description, icon = '◇') {
    return `<div class="empty-state"><span class="empty-icon">${icon}</span><strong>${escapeHtml(title)}</strong><p>${escapeHtml(description)}</p></div>`;
}

function statusBadge(quantity, reorderLevel) {
    const qty = Number(quantity);
    const reorder = Number(reorderLevel);
    if (qty <= 0) return '<span class="status status-out">Out of stock</span>';
    if (qty <= reorder) return '<span class="status status-low">Low</span>';
    return '<span class="status status-ok">OK</span>';
}

function transferRows(rows) {
    if (!rows.length) return `<tr><td colspan="6">${emptyState('No transfers yet', 'Completed stock movements will appear here.', '⇄')}</td></tr>`;
    return rows.map((row) => `
        <tr>
            <td><span class="cell-main">${escapeHtml(row.item_name)}</span><span class="cell-sub mono">${escapeHtml(row.sku)}</span></td>
            <td>${escapeHtml(row.from_name)}</td>
            <td>${escapeHtml(row.to_name)}</td>
            <td><strong>${numberFormat(row.quantity)}</strong></td>
            <td>${escapeHtml(formatDate(row.created_at))}</td>
            <td><span class="cell-sub">${escapeHtml(row.admin_username || 'Admin')}</span></td>
        </tr>`).join('');
}

function lowStockRows(rows) {
    if (!rows.length) return `<tr><td colspan="5">${emptyState('All stock levels look good', 'No inventory rows are at or below their reorder level.', '✓')}</td></tr>`;
    return rows.map((row) => `
        <tr>
            <td><span class="cell-main">${escapeHtml(row.item_name)}</span><span class="cell-sub mono">${escapeHtml(row.sku)}</span></td>
            <td>${escapeHtml(row.warehouse_name)}</td>
            <td>${numberFormat(row.quantity)} <span class="cell-sub">of ${numberFormat(row.reorder_level)}</span></td>
            <td><span class="missing-count">${numberFormat(row.missing_units)} missing</span></td>
            <td>${statusBadge(row.quantity, row.reorder_level)}</td>
        </tr>`).join('');
}

function destroyCharts(prefix) {
    Object.keys(state.chartInstances).forEach((key) => {
        if (key.startsWith(prefix)) {
            state.chartInstances[key].destroy();
            delete state.chartInstances[key];
        }
    });
}

function renderCharts(prefix, data) {
    destroyCharts(prefix);
    if (!window.Chart) {
        document.querySelectorAll(`#${prefix}-stock-chart, #${prefix}-alert-chart`).forEach((canvas) => {
            const message = document.createElement('p');
            message.className = 'muted';
            message.textContent = 'Charts need an internet connection to load the Chart.js CDN.';
            canvas.replaceWith(message);
        });
        return;
    }

    const stockCanvas = document.getElementById(`${prefix}-stock-chart`);
    const alertCanvas = document.getElementById(`${prefix}-alert-chart`);
    if (!stockCanvas || !alertCanvas) return;

    const textColor = '#9999b5';
    const gridColor = 'rgba(173, 173, 210, .10)';
    const stockLabels = data.stock_by_warehouse.map((row) => row.name);
    const stockValues = data.stock_by_warehouse.map((row) => Number(row.total_units));
    state.chartInstances[`${prefix}-stock`] = new Chart(stockCanvas, {
        type: 'bar',
        data: {
            labels: stockLabels,
            datasets: [{
                label: 'Units in stock',
                data: stockValues,
                backgroundColor: ['rgba(124, 58, 237, .78)', 'rgba(37, 99, 235, .78)', 'rgba(96, 165, 250, .72)'],
                borderRadius: 7,
                borderSkipped: false,
                maxBarThickness: 52,
            }],
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false }, tooltip: { backgroundColor: '#171727', titleColor: '#fff', bodyColor: '#ddd' } },
            scales: {
                x: { ticks: { color: textColor, font: { size: 10 } }, grid: { display: false } },
                y: { beginAtZero: true, ticks: { color: textColor, precision: 0, font: { size: 9 } }, grid: { color: gridColor } },
            },
        },
    });

    const alertLabels = data.alerts_by_warehouse.map((row) => row.name);
    const alertValues = data.alerts_by_warehouse.map((row) => Number(row.alert_count));
    state.chartInstances[`${prefix}-alerts`] = new Chart(alertCanvas, {
        type: 'doughnut',
        data: {
            labels: alertLabels,
            datasets: [{
                label: 'Low-stock rows',
                data: alertValues,
                backgroundColor: ['#7C3AED', '#2563EB', '#60A5FA', '#F59E0B'],
                borderColor: '#171727',
                borderWidth: 3,
                hoverOffset: 5,
            }],
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            cutout: '68%',
            plugins: {
                legend: { position: 'bottom', labels: { color: textColor, usePointStyle: true, pointStyle: 'circle', padding: 14, font: { size: 9 } } },
                tooltip: { backgroundColor: '#171727', titleColor: '#fff', bodyColor: '#ddd' },
            },
        },
    });
}

function dashboardMarkup(data, prefix) {
    const summary = data.summary;
    const cards = [
        ['Total items', summary.total_items, '▤', 'Distinct products in the catalog', 'rgba(124,58,237,.14)'],
        ['Units in stock', summary.total_units, '▦', 'Across all warehouses', 'rgba(37,99,235,.14)'],
        ['Warehouses', summary.warehouse_count, '▣', 'Active storage locations', 'rgba(96,165,250,.14)'],
        ['Low-stock items', summary.low_stock_count, '♢', 'At or below reorder level', 'rgba(251,191,36,.12)'],
    ];

    return `
        <div class="stats-grid">
            ${cards.map(([label, value, icon, foot, glow]) => `
                <article class="stat-card" style="--glow:${glow}">
                    <div class="stat-top"><span>${label}</span><span class="stat-icon">${icon}</span></div>
                    <strong class="stat-value">${numberFormat(value)}</strong>
                    <span class="stat-foot">${foot}</span>
                </article>`).join('')}
        </div>
        <div class="chart-grid">
            <article class="chart-card">
                <div class="content-panel-header"><div><h3>Stock per warehouse</h3><p class="muted">Total units currently stored</p></div></div>
                <div class="chart-wrap"><canvas id="${prefix}-stock-chart" aria-label="Bar chart showing units in stock by warehouse"></canvas></div>
            </article>
            <article class="chart-card">
                <div class="content-panel-header"><div><h3>Low-stock distribution</h3><p class="muted">Inventory rows needing attention</p></div></div>
                <div class="chart-wrap"><canvas id="${prefix}-alert-chart" aria-label="Doughnut chart showing low stock rows by warehouse"></canvas></div>
            </article>
        </div>
        <div class="dashboard-lower">
            <section class="content-panel">
                <div class="content-panel-header"><div><h3>Low-stock watchlist</h3><p class="muted">The most urgent items right now</p></div><span class="tag tag-public">${numberFormat(summary.low_stock_count)} ALERTS</span></div>
                <div class="table-wrap"><table><thead><tr><th>Item</th><th>Warehouse</th><th>On hand</th><th>Missing</th><th>Status</th></tr></thead><tbody>${lowStockRows(data.low_stock_preview)}</tbody></table></div>
            </section>
            <section class="content-panel">
                <div class="content-panel-header"><div><h3>Recent transfers</h3><p class="muted">Latest warehouse movements</p></div></div>
                <div class="table-wrap"><table><thead><tr><th>Item</th><th>From</th><th>To</th><th>Qty</th><th>Date</th><th>By</th></tr></thead><tbody>${transferRows(data.recent_transfers)}</tbody></table></div>
            </section>
        </div>`;
}

function renderDashboard(container, data, prefix) {
    container.innerHTML = dashboardMarkup(data, prefix);
    renderCharts(prefix, data);
    setAlertBadge(data.summary.low_stock_count);
}

async function loadPublicDashboard() {
    const container = document.getElementById('public-dashboard-content');
    try {
        const result = await api('public_dashboard');
        renderDashboard(container, result.data, 'public');
    } catch (error) {
        container.innerHTML = `<div class="empty-state"><span class="empty-icon">!</span><strong>Dashboard unavailable</strong><p>${escapeHtml(error.message)}</p></div>`;
    }
}

function showHome() {
    adminView.hidden = true;
    homeView.hidden = false;
    modalRoot.innerHTML = '';
    state.username = null;
    state.csrfToken = null;
    Object.values(state.chartInstances).forEach((chart) => chart.destroy());
    state.chartInstances = {};
    loadPublicDashboard();
}

function showAdmin() {
    homeView.hidden = true;
    adminView.hidden = false;
    document.getElementById('sidebar-username').textContent = state.username || 'Admin';
    loadView('dashboard');
}

function setActiveNavigation(view) {
    document.querySelectorAll('.nav-item[data-view]').forEach((button) => {
        button.classList.toggle('active', button.dataset.view === view);
    });
}

async function refreshAlertBadge() {
    try {
        const result = await api('alerts');
        setAlertBadge(result.count);
    } catch (error) {
        // A page refresh will show a useful message if the session has expired.
    }
}

async function loadView(view) {
    state.currentView = view;
    setActiveNavigation(view);
    const titles = {
        dashboard: 'Dashboard', inventory: 'Inventory', transfers: 'Transfer History',
        alerts: 'Low Stock Alerts', warehouses: 'Warehouses',
    };
    pageTitle.textContent = titles[view] || 'Dashboard';
    adminContent.innerHTML = '<div class="loading-state"><span class="spinner"></span> Loading ' + escapeHtml(titles[view] || 'workspace') + '…</div>';

    try {
        if (view === 'dashboard') {
            const result = await api('dashboard');
            renderDashboard(adminContent, result.data, 'admin');
        } else if (view === 'inventory') {
            await renderInventory();
        } else if (view === 'transfers') {
            await renderTransfers();
        } else if (view === 'alerts') {
            await renderAlerts();
        } else if (view === 'warehouses') {
            await renderWarehouses();
        }
    } catch (error) {
        adminContent.innerHTML = `<div class="content-panel">${emptyState('Could not load this page', error.message, '!')}</div>`;
        if (error.message.includes('log in') || error.message.includes('session')) {
            showToast(error.message, 'error');
        }
    }
}

async function refreshCurrentView() {
    await loadView(state.currentView);
    if (state.currentView !== 'dashboard') await refreshAlertBadge();
}

function inventoryRow(row) {
    const haystack = `${row.sku} ${row.name} ${row.description} ${row.warehouse_name}`.toLowerCase();
    return `<tr data-warehouse-id="${row.warehouse_id}" data-search="${escapeHtml(haystack)}">
        <td><span class="cell-main">${escapeHtml(row.name)}</span><span class="cell-sub">${escapeHtml(row.description || 'No description')}</span></td>
        <td><span class="mono">${escapeHtml(row.sku)}</span></td>
        <td>${escapeHtml(row.warehouse_name)}<span class="cell-sub">${escapeHtml(row.warehouse_location)}</span></td>
        <td><strong>${numberFormat(row.quantity)}</strong><span class="cell-sub">Reorder at ${numberFormat(row.reorder_level)}</span></td>
        <td>${statusBadge(row.quantity, row.reorder_level)}</td>
        <td><div class="table-actions">
            <button class="icon-button" type="button" title="Edit inventory row" aria-label="Edit ${escapeHtml(row.name)}" data-action="edit-item" data-stock-id="${row.stock_id}">✎</button>
            <button class="icon-button danger" type="button" title="Delete item" aria-label="Delete ${escapeHtml(row.name)}" data-action="delete-item" data-item-id="${row.item_id}" data-item-name="${escapeHtml(row.name)}">×</button>
        </div></td>
    </tr>`;
}

async function renderInventory() {
    const [inventoryResult, warehouseResult] = await Promise.all([api('inventory'), api('warehouses')]);
    state.inventoryRows = inventoryResult.data;
    state.warehouseRows = warehouseResult.data;
    adminContent.innerHTML = `
        <div class="page-intro"><div><h2>Inventory</h2><p>Manage products and their balances in each warehouse. Editing product details updates that SKU everywhere; quantity changes only the selected warehouse row.</p></div>
            <div class="page-actions"><button class="button button-primary" id="add-item-button" type="button">＋ Add item</button></div>
        </div>
        <section class="content-panel">
            <div class="toolbar">
                <div class="search-box"><span class="search-symbol">⌕</span><input id="inventory-search" type="search" placeholder="Search SKU, item or warehouse…" aria-label="Search inventory"></div>
                <select id="warehouse-filter" aria-label="Filter by warehouse"><option value="all">All warehouses</option>${state.warehouseRows.map((warehouse) => `<option value="${warehouse.id}">${escapeHtml(warehouse.name)}</option>`).join('')}</select>
            </div>
            <div class="table-wrap"><table><thead><tr><th>Item</th><th>SKU</th><th>Warehouse</th><th>Quantity</th><th>Status</th><th>Actions</th></tr></thead><tbody id="inventory-table-body">${state.inventoryRows.length ? state.inventoryRows.map(inventoryRow).join('') : `<tr><td colspan="6">${emptyState('No inventory rows yet', 'Add your first item to start tracking stock.', '▤')}</td></tr>`}</tbody></table></div>
            <p class="table-note">${numberFormat(state.inventoryRows.length)} inventory row(s). A product can appear in more than one warehouse after a transfer.</p>
        </section>`;

    document.getElementById('add-item-button').addEventListener('click', () => openItemModal());
    document.getElementById('inventory-search').addEventListener('input', filterInventoryRows);
    document.getElementById('warehouse-filter').addEventListener('change', filterInventoryRows);
    document.getElementById('inventory-table-body').addEventListener('click', async (event) => {
        const button = event.target.closest('button[data-action]');
        if (!button) return;
        if (button.dataset.action === 'edit-item') {
            const item = state.inventoryRows.find((row) => String(row.stock_id) === button.dataset.stockId);
            if (item) openItemModal(item);
        }
        if (button.dataset.action === 'delete-item') {
            const itemName = button.dataset.itemName;
            if (!window.confirm(`Delete “${itemName}” from the catalog and remove all its stock rows? This cannot be done when the item has transfer history.`)) return;
            try {
                const result = await api('delete_item', { method: 'POST', body: { item_id: Number(button.dataset.itemId) } });
                showToast(result.message);
                await refreshCurrentView();
            } catch (error) {
                showToast(error.message, 'error');
            }
        }
    });
}

function filterInventoryRows() {
    const search = document.getElementById('inventory-search').value.trim().toLowerCase();
    const warehouseId = document.getElementById('warehouse-filter').value;
    document.querySelectorAll('#inventory-table-body tr[data-search]').forEach((row) => {
        const matchesText = row.dataset.search.includes(search);
        const matchesWarehouse = warehouseId === 'all' || row.dataset.warehouseId === warehouseId;
        row.hidden = !(matchesText && matchesWarehouse);
    });
}

function showModal(title, subtitle, bodyHtml) {
    modalRoot.innerHTML = `
        <div class="modal-backdrop" id="modal-backdrop">
            <section class="modal-card" role="dialog" aria-modal="true" aria-labelledby="modal-title">
                <div class="modal-header"><div><h2 id="modal-title">${escapeHtml(title)}</h2><p>${escapeHtml(subtitle)}</p></div><button type="button" class="modal-close" id="modal-close" aria-label="Close">×</button></div>
                ${bodyHtml}
            </section>
        </div>`;
    document.getElementById('modal-close').addEventListener('click', closeModal);
    document.getElementById('modal-backdrop').addEventListener('click', (event) => {
        if (event.target.id === 'modal-backdrop') closeModal();
    });
    const firstInput = modalRoot.querySelector('input, select, textarea');
    if (firstInput) firstInput.focus();
}

function closeModal() {
    modalRoot.innerHTML = '';
}

function openItemModal(item = null) {
    const editing = Boolean(item);
    const options = state.warehouseRows.map((warehouse) => `<option value="${warehouse.id}" ${editing && String(item.warehouse_id) === String(warehouse.id) ? 'selected' : ''}>${escapeHtml(warehouse.name)}</option>`).join('');
    const body = `
        <form id="item-form" novalidate>
            <div class="form-grid">
                <div class="form-field"><label for="item-sku">SKU *</label><input id="item-sku" name="sku" maxlength="64" required value="${escapeHtml(item?.sku || '')}" placeholder="STK-013"></div>
                <div class="form-field"><label for="item-name">Item name *</label><input id="item-name" name="name" maxlength="150" required value="${escapeHtml(item?.name || '')}" placeholder="Wireless keyboard"></div>
                <div class="form-field full"><label for="item-description">Description</label><textarea id="item-description" name="description" maxlength="500" placeholder="Short description (optional)">${escapeHtml(item?.description || '')}</textarea></div>
                <div class="form-field"><label for="item-warehouse">Warehouse *</label><select id="item-warehouse" name="warehouse_id" required>${options}</select></div>
                <div class="form-field"><label for="item-quantity">Quantity *</label><input id="item-quantity" name="quantity" type="number" min="0" step="1" required value="${editing ? Number(item.quantity) : 0}"></div>
                <div class="form-field"><label for="item-reorder">Reorder level *</label><input id="item-reorder" name="reorder_level" type="number" min="0" step="1" required value="${editing ? Number(item.reorder_level) : 5}"></div>
            </div>
            ${editing ? `<p class="table-note">The item details are shared by every warehouse. This quantity belongs only to ${escapeHtml(item.warehouse_name)}.</p>` : '<p class="table-note">A new item is added to the selected warehouse with the starting quantity above.</p>'}
            <div class="modal-actions"><button class="button button-soft" type="button" id="cancel-item">Cancel</button><button class="button button-primary" type="submit" id="save-item">${editing ? 'Save changes' : 'Create item'}</button></div>
        </form>`;
    showModal(editing ? 'Edit inventory item' : 'Add inventory item', editing ? 'Update item information and this warehouse balance.' : 'Create a product and its initial warehouse balance.', body);

    document.getElementById('cancel-item').addEventListener('click', closeModal);
    const form = document.getElementById('item-form');
    form.addEventListener('submit', async (event) => {
        event.preventDefault();
        if (!form.checkValidity()) { form.reportValidity(); return; }
        const formData = new FormData(form);
        const payload = {
            sku: String(formData.get('sku')).trim(),
            name: String(formData.get('name')).trim(),
            description: String(formData.get('description')).trim(),
            warehouse_id: Number(formData.get('warehouse_id')),
            quantity: Number(formData.get('quantity')),
            reorder_level: Number(formData.get('reorder_level')),
        };
        if (!Number.isInteger(payload.quantity) || payload.quantity < 0 || !Number.isInteger(payload.reorder_level) || payload.reorder_level < 0) {
            showToast('Quantity and reorder level must be whole numbers of zero or more.', 'error');
            return;
        }
        if (!payload.warehouse_id) { showToast('Create a warehouse before adding an item.', 'error'); return; }
        if (editing) payload.stock_id = Number(item.stock_id);
        const saveButton = document.getElementById('save-item');
        saveButton.disabled = true;
        try {
            const result = await api(editing ? 'update_item' : 'create_item', { method: 'POST', body: payload });
            closeModal();
            showToast(result.message);
            await refreshCurrentView();
        } catch (error) {
            showToast(error.message, 'error');
            saveButton.disabled = false;
        }
    });
}

async function renderWarehouses() {
    const result = await api('warehouses');
    state.warehouseRows = result.data;
    const rows = result.data.map((warehouse) => `
        <tr>
            <td><span class="cell-main">${escapeHtml(warehouse.name)}</span><span class="cell-sub">Warehouse #${warehouse.id}</span></td>
            <td>${escapeHtml(warehouse.location)}</td>
            <td><strong>${numberFormat(warehouse.stocked_items)}</strong><span class="cell-sub">items with stock</span></td>
            <td><strong>${numberFormat(warehouse.total_units)}</strong><span class="cell-sub">total units</span></td>
            <td><div class="table-actions"><button class="icon-button" type="button" title="Edit warehouse" aria-label="Edit ${escapeHtml(warehouse.name)}" data-action="edit-warehouse" data-id="${warehouse.id}">✎</button><button class="icon-button danger" type="button" title="Delete warehouse" aria-label="Delete ${escapeHtml(warehouse.name)}" data-action="delete-warehouse" data-id="${warehouse.id}" data-name="${escapeHtml(warehouse.name)}">×</button></div></td>
        </tr>`).join('');

    adminContent.innerHTML = `
        <div class="page-intro"><div><h2>Warehouses</h2><p>Keep your storage locations organized. A warehouse can only be deleted when it has no stock and no transfer history.</p></div><div class="page-actions"><button class="button button-primary" id="add-warehouse-button" type="button">＋ Add warehouse</button></div></div>
        <section class="content-panel"><div class="content-panel-header"><div><h3>Warehouse list</h3><p class="muted">${numberFormat(result.data.length)} location(s) registered</p></div></div>
            <div class="table-wrap"><table><thead><tr><th>Warehouse</th><th>Location</th><th>Stocked items</th><th>Total units</th><th>Actions</th></tr></thead><tbody>${rows || `<tr><td colspan="5">${emptyState('No warehouses yet', 'Add a warehouse before creating inventory.', '▣')}</td></tr>`}</tbody></table></div>
        </section>`;

    document.getElementById('add-warehouse-button').addEventListener('click', () => openWarehouseModal());
    adminContent.querySelector('tbody').addEventListener('click', async (event) => {
        const button = event.target.closest('button[data-action]');
        if (!button) return;
        const warehouse = state.warehouseRows.find((row) => String(row.id) === button.dataset.id);
        if (!warehouse) return;
        if (button.dataset.action === 'edit-warehouse') openWarehouseModal(warehouse);
        if (button.dataset.action === 'delete-warehouse') {
            if (!window.confirm(`Delete “${warehouse.name}”? This only works when it has no stock and no transfer history.`)) return;
            try {
                const response = await api('delete_warehouse', { method: 'POST', body: { warehouse_id: warehouse.id } });
                showToast(response.message);
                await refreshCurrentView();
            } catch (error) {
                showToast(error.message, 'error');
            }
        }
    });
}

function openWarehouseModal(warehouse = null) {
    const editing = Boolean(warehouse);
    const body = `
        <form id="warehouse-form" novalidate>
            <div class="form-grid">
                <div class="form-field full"><label for="warehouse-name">Warehouse name *</label><input id="warehouse-name" name="name" maxlength="100" required value="${escapeHtml(warehouse?.name || '')}" placeholder="East Branch"></div>
                <div class="form-field full"><label for="warehouse-location">Location *</label><input id="warehouse-location" name="location" maxlength="180" required value="${escapeHtml(warehouse?.location || '')}" placeholder="City, Province"></div>
            </div>
            <div class="modal-actions"><button class="button button-soft" type="button" id="cancel-warehouse">Cancel</button><button class="button button-primary" type="submit" id="save-warehouse">${editing ? 'Save changes' : 'Create warehouse'}</button></div>
        </form>`;
    showModal(editing ? 'Edit warehouse' : 'Add warehouse', 'Enter a clear name and its location.', body);
    document.getElementById('cancel-warehouse').addEventListener('click', closeModal);
    const form = document.getElementById('warehouse-form');
    form.addEventListener('submit', async (event) => {
        event.preventDefault();
        if (!form.checkValidity()) { form.reportValidity(); return; }
        const formData = new FormData(form);
        const payload = { name: String(formData.get('name')).trim(), location: String(formData.get('location')).trim() };
        if (editing) payload.warehouse_id = Number(warehouse.id);
        const button = document.getElementById('save-warehouse');
        button.disabled = true;
        try {
            const response = await api(editing ? 'update_warehouse' : 'create_warehouse', { method: 'POST', body: payload });
            closeModal();
            showToast(response.message);
            await refreshCurrentView();
        } catch (error) {
            showToast(error.message, 'error');
            button.disabled = false;
        }
    });
}

async function renderTransfers() {
    const [transferResult, optionsResult] = await Promise.all([api('transfers'), api('options')]);
    const items = optionsResult.data.items;
    const warehouses = optionsResult.data.warehouses;
    const canTransfer = items.length > 0 && warehouses.length >= 2;
    const itemOptions = items.map((item) => `<option value="${item.id}">${escapeHtml(item.sku)} — ${escapeHtml(item.name)}</option>`).join('');
    const warehouseOptions = warehouses.map((warehouse) => `<option value="${warehouse.id}">${escapeHtml(warehouse.name)}</option>`).join('');

    adminContent.innerHTML = `
        <div class="page-intro"><div><h2>Transfer History</h2><p>Move units between warehouses. Each transfer updates both balances and is saved as a permanent history record.</p></div></div>
        <div class="transfer-grid">
            <section class="content-panel form-panel"><h3>New stock transfer</h3><p class="muted">Choose an item, source, destination and whole-unit quantity.</p>
                ${canTransfer ? `
                <form id="transfer-form" class="stack-form" novalidate>
                    <label for="transfer-item">Item *</label><select id="transfer-item" name="item_id" required>${itemOptions}</select>
                    <label for="transfer-from">From warehouse *</label><select id="transfer-from" name="from_warehouse_id" required>${warehouseOptions}</select>
                    <label for="transfer-to">To warehouse *</label><select id="transfer-to" name="to_warehouse_id" required>${warehouseOptions}</select>
                    <label for="transfer-quantity">Quantity *</label><input id="transfer-quantity" name="quantity" type="number" min="1" step="1" required placeholder="1">
                    <label for="transfer-note">Note</label><textarea id="transfer-note" name="note" maxlength="500" placeholder="Optional reason for transfer"></textarea>
                    <button class="button button-blue button-full" type="submit" id="submit-transfer">Complete transfer <span>→</span></button>
                </form>` : `<div class="empty-state">${emptyState('More setup needed', 'Add at least one item and two warehouses before creating a transfer.', '⇄')}</div>`}
            </section>
            <section class="content-panel"><div class="content-panel-header"><div><h3>Transfer log</h3><p class="muted">Newest transfers appear first · ${numberFormat(transferResult.data.length)} record(s)</p></div><span class="tag tag-public">READ ONLY LOG</span></div>
                <div class="table-wrap"><table><thead><tr><th>Item</th><th>From</th><th>To</th><th>Qty</th><th>Date &amp; time</th><th>By</th></tr></thead><tbody>${transferRows(transferResult.data)}</tbody></table></div>
            </section>
        </div>`;

    const form = document.getElementById('transfer-form');
    if (!form) return;
    form.addEventListener('submit', async (event) => {
        event.preventDefault();
        if (!form.checkValidity()) { form.reportValidity(); return; }
        const formData = new FormData(form);
        const payload = {
            item_id: Number(formData.get('item_id')),
            from_warehouse_id: Number(formData.get('from_warehouse_id')),
            to_warehouse_id: Number(formData.get('to_warehouse_id')),
            quantity: Number(formData.get('quantity')),
            note: String(formData.get('note')).trim(),
        };
        if (payload.from_warehouse_id === payload.to_warehouse_id) {
            showToast('Choose two different warehouses.', 'error');
            return;
        }
        if (!Number.isInteger(payload.quantity) || payload.quantity < 1) {
            showToast('Transfer quantity must be a whole number greater than zero.', 'error');
            return;
        }
        const button = document.getElementById('submit-transfer');
        button.disabled = true;
        try {
            const response = await api('create_transfer', { method: 'POST', body: payload });
            showToast(response.message);
            await refreshCurrentView();
        } catch (error) {
            showToast(error.message, 'error');
            button.disabled = false;
        }
    });
}

async function renderAlerts() {
    const result = await api('alerts');
    setAlertBadge(result.count);
    const rows = result.data.map((row) => `
        <tr>
            <td><span class="cell-main">${escapeHtml(row.item_name)}</span><span class="cell-sub mono">${escapeHtml(row.sku)}</span></td>
            <td>${escapeHtml(row.warehouse_name)}</td>
            <td><strong>${numberFormat(row.quantity)}</strong></td>
            <td>${numberFormat(row.reorder_level)}</td>
            <td><span class="missing-count">${numberFormat(row.missing_units)} units</span></td>
            <td>${statusBadge(row.quantity, row.reorder_level)}</td>
        </tr>`).join('');
    adminContent.innerHTML = `
        <div class="page-intro"><div><h2>Low Stock Alerts</h2><p>Items are listed when their warehouse quantity is at or below the reorder level. The largest shortages appear first.</p></div></div>
        <div class="alert-summary"><span class="alert-symbol">♢</span><div><strong>${numberFormat(result.count)} alert row(s)</strong><span>Shortage is calculated as reorder level minus current quantity.</span></div></div>
        <section class="content-panel"><div class="content-panel-header"><div><h3>Restock priority</h3><p class="muted">Sorted by missing units, then lowest current quantity</p></div></div>
            <div class="table-wrap"><table><thead><tr><th>Item</th><th>Warehouse</th><th>On hand</th><th>Reorder level</th><th>Missing</th><th>Status</th></tr></thead><tbody>${rows || `<tr><td colspan="6">${emptyState('No low-stock alerts', 'All inventory rows are above their reorder levels.', '✓')}</td></tr>`}</tbody></table></div>
        </section>`;
}

// Login form
const loginForm = document.getElementById('login-form');
loginForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (!loginForm.checkValidity()) { loginForm.reportValidity(); return; }
    const errorBox = document.getElementById('login-error');
    errorBox.hidden = true;
    const submitButton = loginForm.querySelector('button[type="submit"]');
    submitButton.disabled = true;
    const formData = new FormData(loginForm);
    try {
        const result = await api('login', {
            method: 'POST',
            body: { username: String(formData.get('username')).trim(), password: String(formData.get('password')) },
        });
        state.username = result.user.username;
        state.csrfToken = result.csrf_token;
        loginForm.reset();
        showAdmin();
        showToast(result.message);
    } catch (error) {
        errorBox.textContent = error.message;
        errorBox.hidden = false;
        document.getElementById('login-password').focus();
    } finally {
        submitButton.disabled = false;
    }
});

// Sidebar navigation
 document.querySelectorAll('.nav-item[data-view]').forEach((button) => {
    button.addEventListener('click', () => loadView(button.dataset.view));
});

document.getElementById('logout-button').addEventListener('click', async () => {
    if (!window.confirm('Log out of Stock-Alert?')) return;
    try {
        await api('logout', { method: 'POST', body: {} });
        showHome();
        showToast('You have been logged out.');
    } catch (error) {
        showToast(error.message, 'error');
    }
});

// Restore a valid session after a page refresh, or show the public dashboard.
async function startApp() {
    try {
        const result = await api('session');
        if (result.authenticated) {
            state.username = result.username;
            state.csrfToken = result.csrf_token;
            showAdmin();
        } else {
            showHome();
        }
    } catch (error) {
        showHome();
        showToast(error.message, 'error');
    }
}

startApp();
