# Stock-Alert

A small multi-warehouse inventory system made with HTML, CSS, vanilla JavaScript, PHP 8, PDO, and MySQL/MariaDB. It is designed to run inside XAMPP without Node.js, npm, Composer, or a PHP framework.

## Project structure

```text
stock-alert/
├── api/
│   └── index.php       # JSON API: login, dashboard, inventory, warehouses, transfers, alerts
├── css/
│   └── style.css       # Responsive purple / blue / dark theme
├── js/
│   └── app.js          # Vanilla JavaScript UI and fetch() calls
├── .htaccess           # Disables folder listing and blocks direct SQL/README access
├── config.php          # One place for database and PHP session settings
├── database.sql        # Creates the database and adds sample data
├── index.html          # Public dashboard, login form, and admin app shell
└── README.md           # This setup guide
```

## Setup in XAMPP (Windows)

1. Install and open **XAMPP Control Panel**.
2. Start **Apache** and **MySQL**. Both should show a running status.
3. Open `C:\xampp\htdocs\` in File Explorer.
4. Create a new folder named `stock-alert`.
5. Extract/copy all files from this project into `C:\xampp\htdocs\stock-alert\`. Keep the `api`, `css`, and `js` folders in place.
6. Open `http://localhost/phpmyadmin/` in your browser.
7. In phpMyAdmin, select **Import**, choose the included `database.sql`, and click **Import** or **Go**. The SQL file creates the `stock_alert` database and its tables automatically. Do not create the database by hand first.
8. The default XAMPP database settings are already in `config.php`: host `127.0.0.1`, database `stock_alert`, username `root`, and blank password. Change them there only if your local MySQL setup is different.
9. Open **http://localhost/stock-alert/**.

## Demo administrator account

- **Username:** `admin`
- **Password:** `StockAlert@123`

The password is stored as a PHP `password_hash()` value in the database. The browser never connects to MySQL directly. It calls the PHP API, which uses PDO prepared statements and a PHP session.

## Main features

- Public read-only dashboard before login.
- Admin-only dashboard, inventory, transfer history, low-stock alerts, and warehouse management.
- Inventory create, read, update, and delete. An item is a shared catalog record; its quantity is stored separately for each warehouse.
- Warehouse create, read, update, and delete. A warehouse with units on hand or transfer history cannot be deleted.
- Atomic transfers: the source balance is locked and checked, then both stock balances and the transfer record are saved in one database transaction.
- Transfer history is read-only after a transfer is created.
- Low-stock alerts include stock at or below its reorder level, sorted by the largest shortage first.
- Server-side validation, prepared statements, session checks, and a per-session CSRF token protect write actions.

## Quick test checklist

1. Open the home page without logging in. Confirm the public dashboard is visible and has no edit controls.
2. Try an incorrect password. Confirm the form shows a clear error message.
3. Log in with the demo account. Open each item in the sidebar.
4. In **Inventory**, add an item, search for it, filter by warehouse, edit its quantity, then delete it.
5. In **Warehouses**, add a warehouse, edit its details, and try deleting a warehouse that still has stock. The app should explain why deletion is blocked. An empty warehouse with no transfer records can be deleted.
6. In **Transfer History**, transfer a quantity that is available. Confirm the source and destination balances change and a new history row appears. Try transferring more than the source has; it must be rejected without changing stock.
7. Open **Low Stock Alerts**. Confirm low and out-of-stock rows appear and the navigation badge matches the count.
8. Click **Log out**. Confirm the app returns to the public home page and admin pages require another login.

## Notes

- The charts and font are loaded from CDNs, so an internet connection is needed for those visual extras. The inventory app itself is local.
- Import `database.sql` once into a fresh database. It is a starter seed file, not a reset script.
- For a real production deployment, use a dedicated database user with a strong password, HTTPS, backups, and additional operational hardening instead of the default XAMPP root account.
