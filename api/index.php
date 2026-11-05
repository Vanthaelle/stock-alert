<?php
// One small JSON API for the browser app.
declare(strict_types=1);
require_once __DIR__ . '/../config.php';

$action = (string)($_GET['action'] ?? '');
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

try {
    // Login is the only public write action. It creates the administrator session.
    if ($action === 'login') {
        ensure_post();
        $data = request_data();
        $usernameValue = $data['username'] ?? null;
        $passwordValue = $data['password'] ?? null;
        if (!is_string($usernameValue) || !is_string($passwordValue)) {
            json_response(['success' => false, 'message' => 'Username and password must be text.'], 422);
        }
        $username = trim($usernameValue);
        $password = $passwordValue;
        if ($username === '' || $password === '' || mb_strlen($username) > 60 || mb_strlen($password) > 255) {
            json_response(['success' => false, 'message' => 'Enter a valid username and password.'], 422);
        }

        $statement = $pdo->prepare('SELECT id, username, password_hash FROM admins WHERE username = ? LIMIT 1');
        $statement->execute([$username]);
        $admin = $statement->fetch();

        if (!$admin || !password_verify($password, $admin['password_hash'])) {
            json_response(['success' => false, 'message' => 'Incorrect username or password. Please try again.'], 401);
        }

        session_regenerate_id(true);
        $_SESSION['admin_id'] = (int)$admin['id'];
        $_SESSION['admin_username'] = $admin['username'];
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        json_response([
            'success' => true,
            'message' => 'Welcome back, ' . $admin['username'] . '.',
            'user' => ['username' => $admin['username']],
            'csrf_token' => $_SESSION['csrf_token'],
        ]);
    }

    if ($action === 'session') {
        ensure_get();
        json_response([
            'success' => true,
            'authenticated' => !empty($_SESSION['admin_id']),
            'username' => $_SESSION['admin_username'] ?? null,
            'csrf_token' => $_SESSION['csrf_token'] ?? null,
        ]);
    }

    // Public dashboard data is deliberately read-only and does not require login.
    if ($action === 'public_dashboard') {
        ensure_get();
        json_response(['success' => true, 'data' => dashboard_data($pdo)]);
    }

    // Every other route requires a valid administrator session.
    require_admin();

    if ($method === 'POST' && $action !== 'logout') {
        verify_csrf();
    }

    if ($action === 'logout') {
        ensure_post();
        verify_csrf();
        $_SESSION = [];
        if (ini_get('session.use_cookies')) {
            $params = session_get_cookie_params();
            setcookie(session_name(), '', [
                'expires' => time() - 42000,
                'path' => $params['path'],
                'domain' => $params['domain'],
                'secure' => $params['secure'],
                'httponly' => $params['httponly'],
                'samesite' => $params['samesite'] ?? 'Lax',
            ]);
        }
        session_destroy();
        json_response(['success' => true, 'message' => 'You have been logged out.']);
    }

    if ($action === 'dashboard') {
        ensure_get();
        json_response(['success' => true, 'data' => dashboard_data($pdo)]);
    }

    if ($action === 'inventory') {
        ensure_get();
        $rows = $pdo->query(
            "SELECT s.id AS stock_id, i.id AS item_id, i.sku, i.name, i.description,
                    i.reorder_level, s.quantity, w.id AS warehouse_id,
                    w.name AS warehouse_name, w.location AS warehouse_location
             FROM stock s
             INNER JOIN items i ON i.id = s.item_id
             INNER JOIN warehouses w ON w.id = s.warehouse_id
             ORDER BY i.name, w.name"
        )->fetchAll();
        json_response(['success' => true, 'data' => $rows]);
    }

    if ($action === 'warehouses') {
        ensure_get();
        $rows = $pdo->query(
            "SELECT w.id, w.name, w.location,
                    COALESCE(SUM(s.quantity), 0) AS total_units,
                    COUNT(DISTINCT CASE WHEN s.quantity > 0 THEN s.item_id END) AS stocked_items
             FROM warehouses w
             LEFT JOIN stock s ON s.warehouse_id = w.id
             GROUP BY w.id, w.name, w.location
             ORDER BY w.name"
        )->fetchAll();
        json_response(['success' => true, 'data' => $rows]);
    }

    if ($action === 'options') {
        ensure_get();
        $items = $pdo->query('SELECT id, sku, name FROM items ORDER BY name')->fetchAll();
        $warehouses = $pdo->query('SELECT id, name FROM warehouses ORDER BY name')->fetchAll();
        json_response(['success' => true, 'data' => ['items' => $items, 'warehouses' => $warehouses]]);
    }

    if ($action === 'transfers') {
        ensure_get();
        $rows = $pdo->query(
            "SELECT t.id, t.quantity, t.note, t.created_at,
                    i.sku, i.name AS item_name,
                    wf.name AS from_name, wt.name AS to_name,
                    a.username AS admin_username
             FROM transfers t
             INNER JOIN items i ON i.id = t.item_id
             INNER JOIN warehouses wf ON wf.id = t.from_warehouse_id
             INNER JOIN warehouses wt ON wt.id = t.to_warehouse_id
             INNER JOIN admins a ON a.id = t.created_by
             ORDER BY t.created_at DESC, t.id DESC"
        )->fetchAll();
        json_response(['success' => true, 'data' => $rows]);
    }

    if ($action === 'alerts') {
        ensure_get();
        $rows = alert_rows($pdo);
        json_response(['success' => true, 'data' => $rows, 'count' => count($rows)]);
    }

    // Create a new catalog item and its starting balance in one warehouse.
    if ($action === 'create_item') {
        ensure_post();
        $data = request_data();
        $sku = required_text($data, 'sku', 'SKU', 64);
        $name = required_text($data, 'name', 'Item name', 150);
        $description = optional_text($data, 'description', 500);
        $reorderLevel = valid_int($data, 'reorder_level', 'Reorder level', 0);
        $warehouseId = valid_int($data, 'warehouse_id', 'Warehouse', 1);
        $quantity = valid_int($data, 'quantity', 'Quantity', 0);

        $pdo->beginTransaction();
        $statement = $pdo->prepare('INSERT INTO items (sku, name, description, reorder_level) VALUES (?, ?, ?, ?)');
        $statement->execute([$sku, $name, $description, $reorderLevel]);
        $itemId = (int)$pdo->lastInsertId();
        $statement = $pdo->prepare('INSERT INTO stock (item_id, warehouse_id, quantity) VALUES (?, ?, ?)');
        $statement->execute([$itemId, $warehouseId, $quantity]);
        $pdo->commit();
        json_response(['success' => true, 'message' => 'Item created successfully.']);
    }

    if ($action === 'update_item') {
        ensure_post();
        $data = request_data();
        $stockId = valid_int($data, 'stock_id', 'Stock row', 1);
        $sku = required_text($data, 'sku', 'SKU', 64);
        $name = required_text($data, 'name', 'Item name', 150);
        $description = optional_text($data, 'description', 500);
        $reorderLevel = valid_int($data, 'reorder_level', 'Reorder level', 0);
        $quantity = valid_int($data, 'quantity', 'Quantity', 0);

        $statement = $pdo->prepare('SELECT item_id FROM stock WHERE id = ?');
        $statement->execute([$stockId]);
        $itemId = $statement->fetchColumn();
        if (!$itemId) {
            json_response(['success' => false, 'message' => 'This inventory row no longer exists. Refresh the page and try again.'], 404);
        }

        $pdo->beginTransaction();
        $statement = $pdo->prepare('UPDATE items SET sku = ?, name = ?, description = ?, reorder_level = ? WHERE id = ?');
        $statement->execute([$sku, $name, $description, $reorderLevel, $itemId]);
        $statement = $pdo->prepare('UPDATE stock SET quantity = ? WHERE id = ?');
        $statement->execute([$quantity, $stockId]);
        $pdo->commit();
        json_response(['success' => true, 'message' => 'Item updated successfully.']);
    }

    if ($action === 'delete_item') {
        ensure_post();
        $data = request_data();
        $itemId = valid_int($data, 'item_id', 'Item', 1);
        $statement = $pdo->prepare('SELECT COUNT(*) FROM transfers WHERE item_id = ?');
        $statement->execute([$itemId]);
        if ((int)$statement->fetchColumn() > 0) {
            json_response(['success' => false, 'message' => 'This item has transfer history and cannot be deleted. Keep it in inventory so the history stays accurate.'], 409);
        }
        $statement = $pdo->prepare('DELETE FROM items WHERE id = ?');
        $statement->execute([$itemId]);
        if ($statement->rowCount() === 0) {
            json_response(['success' => false, 'message' => 'Item not found. Refresh the page and try again.'], 404);
        }
        json_response(['success' => true, 'message' => 'Item deleted successfully.']);
    }

    if ($action === 'create_warehouse') {
        ensure_post();
        $data = request_data();
        $name = required_text($data, 'name', 'Warehouse name', 100);
        $location = required_text($data, 'location', 'Location', 180);
        $statement = $pdo->prepare('INSERT INTO warehouses (name, location) VALUES (?, ?)');
        $statement->execute([$name, $location]);
        json_response(['success' => true, 'message' => 'Warehouse created successfully.']);
    }

    if ($action === 'update_warehouse') {
        ensure_post();
        $data = request_data();
        $warehouseId = valid_int($data, 'warehouse_id', 'Warehouse', 1);
        $name = required_text($data, 'name', 'Warehouse name', 100);
        $location = required_text($data, 'location', 'Location', 180);
        $statement = $pdo->prepare('UPDATE warehouses SET name = ?, location = ? WHERE id = ?');
        $statement->execute([$name, $location, $warehouseId]);
        if ($statement->rowCount() === 0) {
            $check = $pdo->prepare('SELECT COUNT(*) FROM warehouses WHERE id = ?');
            $check->execute([$warehouseId]);
            if ((int)$check->fetchColumn() === 0) {
                json_response(['success' => false, 'message' => 'Warehouse not found. Refresh the page and try again.'], 404);
            }
        }
        json_response(['success' => true, 'message' => 'Warehouse updated successfully.']);
    }

    if ($action === 'delete_warehouse') {
        ensure_post();
        $data = request_data();
        $warehouseId = valid_int($data, 'warehouse_id', 'Warehouse', 1);
        $check = $pdo->prepare('SELECT COUNT(*) FROM warehouses WHERE id = ?');
        $check->execute([$warehouseId]);
        if ((int)$check->fetchColumn() === 0) {
            json_response(['success' => false, 'message' => 'Warehouse not found. Refresh the page and try again.'], 404);
        }

        $stockCheck = $pdo->prepare('SELECT COALESCE(SUM(quantity), 0) FROM stock WHERE warehouse_id = ?');
        $stockCheck->execute([$warehouseId]);
        if ((int)$stockCheck->fetchColumn() > 0) {
            json_response(['success' => false, 'message' => 'This warehouse still has stock. Transfer or remove all units before deleting it.'], 409);
        }

        $transferCheck = $pdo->prepare('SELECT COUNT(*) FROM transfers WHERE from_warehouse_id = ? OR to_warehouse_id = ?');
        $transferCheck->execute([$warehouseId, $warehouseId]);
        if ((int)$transferCheck->fetchColumn() > 0) {
            json_response(['success' => false, 'message' => 'This warehouse appears in transfer history and cannot be deleted.'], 409);
        }

        $pdo->beginTransaction();
        $statement = $pdo->prepare('DELETE FROM stock WHERE warehouse_id = ?'); // Removes only empty stock rows.
        $statement->execute([$warehouseId]);
        $statement = $pdo->prepare('DELETE FROM warehouses WHERE id = ?');
        $statement->execute([$warehouseId]);
        $pdo->commit();
        json_response(['success' => true, 'message' => 'Warehouse deleted successfully.']);
    }

    // A transfer changes both balances and writes its history in the same transaction.
    if ($action === 'create_transfer') {
        ensure_post();
        $data = request_data();
        $itemId = valid_int($data, 'item_id', 'Item', 1);
        $fromId = valid_int($data, 'from_warehouse_id', 'From warehouse', 1);
        $toId = valid_int($data, 'to_warehouse_id', 'To warehouse', 1);
        $quantity = valid_int($data, 'quantity', 'Transfer quantity', 1);
        $note = optional_text($data, 'note', 500);

        if ($fromId === $toId) {
            json_response(['success' => false, 'message' => 'Choose two different warehouses.'], 422);
        }

        $pdo->beginTransaction();
        $statement = $pdo->prepare('SELECT quantity FROM stock WHERE item_id = ? AND warehouse_id = ? FOR UPDATE');
        $statement->execute([$itemId, $fromId]);
        $sourceQuantity = $statement->fetchColumn();
        if ($sourceQuantity === false || (int)$sourceQuantity < $quantity) {
            $pdo->rollBack();
            json_response(['success' => false, 'message' => 'Not enough stock in the source warehouse. The transfer was not saved.'], 409);
        }

        $statement = $pdo->prepare('UPDATE stock SET quantity = quantity - ? WHERE item_id = ? AND warehouse_id = ?');
        $statement->execute([$quantity, $itemId, $fromId]);
        $statement = $pdo->prepare(
            'INSERT INTO stock (item_id, warehouse_id, quantity) VALUES (?, ?, ?)
             ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)'
        );
        $statement->execute([$itemId, $toId, $quantity]);
        $statement = $pdo->prepare(
            'INSERT INTO transfers (item_id, from_warehouse_id, to_warehouse_id, quantity, note, created_by)
             VALUES (?, ?, ?, ?, ?, ?)'
        );
        $statement->execute([$itemId, $fromId, $toId, $quantity, $note, (int)$_SESSION['admin_id']]);
        $pdo->commit();
        json_response(['success' => true, 'message' => 'Transfer completed and stock balances updated.']);
    }

    json_response(['success' => false, 'message' => 'Unknown API action.'], 404);
} catch (PDOException $error) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('Stock-Alert database operation failed: ' . $error->getMessage());
    $sqlState = (string)$error->getCode();
    if ($sqlState === '23000') {
        json_response(['success' => false, 'message' => 'That value already exists or this record is still in use. Check for duplicate names or related records.'], 409);
    }
    json_response(['success' => false, 'message' => 'The database could not complete that action. Check the values and try again.'], 500);
} catch (Throwable $error) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('Stock-Alert API error: ' . $error->getMessage());
    json_response(['success' => false, 'message' => 'Something went wrong. Please refresh the page and try again.'], 500);
}
