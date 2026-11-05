<?php
declare(strict_types=1);
require __DIR__.'/_init.php';
try {
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $rows = $pdo->query("SELECT * FROM low_stock_alerts ORDER BY FIELD(status,'draft','sent','resolved','dismissed'),updated_at DESC LIMIT 300")->fetchAll();
        json_response(true, $rows);
    }
    require_role(['admin']);
    $d = request_json();
    if (($d['action'] ?? '') === 'scan') {
        $count = AlertService::scan($pdo);
        json_response(true, ['scanned_items' => $count]);
    }
    $id = positive_int($d['id'] ?? null, 'id');
    $status = (string)($d['status'] ?? '');
    if (!in_array($status, ['sent','dismissed'], true)) {
        json_response(false, null, 'VALIDATION_ERROR', 'Invalid alert action.', [], 422);
    }
    $q = $pdo->prepare("UPDATE low_stock_alerts SET status=?,updated_at=NOW() WHERE id=? AND status IN ('draft','sent')");
    $q->execute([$status, $id]);
    json_response(true, ['updated' => $q->rowCount()]);
} catch (Throwable $e) { api_error($e); }
