<?php
// Central database and session settings for Stock-Alert.
declare(strict_types=1);

$DB_HOST = '127.0.0.1';
$DB_NAME = 'stock_alert';
$DB_USER = 'root';
$DB_PASS = ''; // Default XAMPP MySQL password is blank.

// Use secure cookie settings when the site is opened over HTTPS.
$https = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => $https,
    'httponly' => true,
    'samesite' => 'Lax',
]);
if (session_status() !== PHP_SESSION_ACTIVE) {
    session_start();
}

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

try {
    $pdo = new PDO(
        "mysql:host={$DB_HOST};dbname={$DB_NAME};charset=utf8mb4",
        $DB_USER,
        $DB_PASS,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]
    );
} catch (Throwable $error) {
    error_log('Stock-Alert database connection failed: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Cannot connect to the database. Start MySQL in XAMPP and import database.sql.',
    ]);
    exit;
}

function json_response(array $data, int $status = 200): void
{
    http_response_code($status);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

function request_data(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }

    $data = json_decode($raw, true);
    if (!is_array($data)) {
        json_response(['success' => false, 'message' => 'Request body must be valid JSON.'], 400);
    }
    return $data;
}

function require_admin(): void
{
    if (empty($_SESSION['admin_id'])) {
        json_response(['success' => false, 'message' => 'Please log in as an administrator.'], 401);
    }
}

function verify_csrf(): void
{
    $sentToken = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? '';
    $savedToken = $_SESSION['csrf_token'] ?? '';
    if (!is_string($sentToken) || !is_string($savedToken) || $savedToken === '' || !hash_equals($savedToken, $sentToken)) {
        json_response(['success' => false, 'message' => 'Your session security token is missing or expired. Please log in again.'], 403);
    }
}

function required_text(array $data, string $key, string $label, int $maxLength): string
{
    $rawValue = $data[$key] ?? null;
    if (!is_string($rawValue)) {
        json_response(['success' => false, 'message' => $label . ' must be text.'], 422);
    }
    $value = trim($rawValue);
    if ($value === '') {
        json_response(['success' => false, 'message' => $label . ' is required.'], 422);
    }
    if (mb_strlen($value) > $maxLength) {
        json_response(['success' => false, 'message' => $label . ' must be ' . $maxLength . ' characters or fewer.'], 422);
    }
    return $value;
}

function optional_text(array $data, string $key, int $maxLength): string
{
    $rawValue = $data[$key] ?? '';
    if (!is_string($rawValue)) {
        json_response(['success' => false, 'message' => 'Optional text fields must contain text.'], 422);
    }
    $value = trim($rawValue);
    if (mb_strlen($value) > $maxLength) {
        json_response(['success' => false, 'message' => 'A text field is longer than allowed.'], 422);
    }
    return $value;
}

function valid_int(array $data, string $key, string $label, int $minimum = 0): int
{
    $value = $data[$key] ?? null;
    if (!is_int($value) && !is_string($value)) {
        json_response(['success' => false, 'message' => $label . ' must be a whole number.'], 422);
    }
    if (is_string($value)) {
        $value = trim($value);
    }
    $validated = filter_var($value, FILTER_VALIDATE_INT);
    if ($validated === false || $validated < $minimum || $validated > 4294967295) {
        json_response(['success' => false, 'message' => $label . ' must be a whole number between ' . $minimum . ' and 4,294,967,295.'], 422);
    }
    return (int)$validated;
}

function alert_rows(PDO $pdo): array
{
    $sql = "SELECT s.id AS stock_id, i.id AS item_id, i.sku, i.name AS item_name,
                   i.reorder_level, s.quantity, w.id AS warehouse_id, w.name AS warehouse_name,
                   GREATEST(i.reorder_level - s.quantity, 0) AS missing_units
            FROM stock s
            INNER JOIN items i ON i.id = s.item_id
            INNER JOIN warehouses w ON w.id = s.warehouse_id
            WHERE s.quantity <= i.reorder_level
            ORDER BY missing_units DESC, s.quantity ASC, i.name ASC";
    return $pdo->query($sql)->fetchAll();
}

function dashboard_data(PDO $pdo): array
{
    $totalItems = (int)$pdo->query('SELECT COUNT(*) FROM items')->fetchColumn();
    $totalUnits = (int)$pdo->query('SELECT COALESCE(SUM(quantity), 0) FROM stock')->fetchColumn();
    $warehouseCount = (int)$pdo->query('SELECT COUNT(*) FROM warehouses')->fetchColumn();
    $alerts = alert_rows($pdo);

    $stockByWarehouse = $pdo->query(
        "SELECT w.name, COALESCE(SUM(s.quantity), 0) AS total_units
         FROM warehouses w
         LEFT JOIN stock s ON s.warehouse_id = w.id
         GROUP BY w.id, w.name
         ORDER BY w.name"
    )->fetchAll();

    $alertsByWarehouse = $pdo->query(
        "SELECT w.name, SUM(CASE WHEN s.id IS NOT NULL AND s.quantity <= i.reorder_level THEN 1 ELSE 0 END) AS alert_count
         FROM warehouses w
         LEFT JOIN stock s ON s.warehouse_id = w.id
         LEFT JOIN items i ON i.id = s.item_id
         GROUP BY w.id, w.name
         ORDER BY w.name"
    )->fetchAll();

    $recentTransfers = $pdo->query(
        "SELECT t.id, t.quantity, t.note, t.created_at,
                i.sku, i.name AS item_name,
                wf.name AS from_name, wt.name AS to_name,
                a.username AS admin_username
         FROM transfers t
         INNER JOIN items i ON i.id = t.item_id
         INNER JOIN warehouses wf ON wf.id = t.from_warehouse_id
         INNER JOIN warehouses wt ON wt.id = t.to_warehouse_id
         INNER JOIN admins a ON a.id = t.created_by
         ORDER BY t.created_at DESC, t.id DESC
         LIMIT 5"
    )->fetchAll();

    return [
        'summary' => [
            'total_items' => $totalItems,
            'total_units' => $totalUnits,
            'warehouse_count' => $warehouseCount,
            'low_stock_count' => count($alerts),
        ],
        'stock_by_warehouse' => $stockByWarehouse,
        'alerts_by_warehouse' => $alertsByWarehouse,
        'low_stock_preview' => array_slice($alerts, 0, 6),
        'recent_transfers' => $recentTransfers,
    ];
}

function ensure_post(): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') {
        json_response(['success' => false, 'message' => 'This action requires a POST request.'], 405);
    }
}

function ensure_get(): void
{
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
        json_response(['success' => false, 'message' => 'This action requires a GET request.'], 405);
    }
}
