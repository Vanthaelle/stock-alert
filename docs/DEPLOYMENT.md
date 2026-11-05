# Deployment notes

1. Copy `stock-alert` into XAMPP `htdocs`.
2. Start Apache and MySQL.
3. Import `database/stock_alert.sql` for a fresh database. For an existing installation, export a backup and import `database/upgrade_existing.sql` after selecting the existing database.
4. Create the first administrator at `/stock-alert/setup.php`.
5. Use `/stock-alert/` for the combined public home and admin login.

Do not expose `app/`, `database/`, or `tests/` directories on public hosting. Their included `.htaccess` files deny direct access under Apache. Keep PHP and MySQL versions supported by your XAMPP distribution.
