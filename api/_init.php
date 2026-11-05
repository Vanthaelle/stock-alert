<?php
declare(strict_types=1);require_once __DIR__.'/../app/bootstrap.php';$user=require_role(['admin']);if($_SERVER['REQUEST_METHOD']!=='GET')verify_csrf();$pdo=db();
