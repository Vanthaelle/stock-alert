<?php
declare(strict_types=1);
$c=require __DIR__.'/config.php';ini_set('session.use_strict_mode','1');session_name($c['app']['session_name']);session_set_cookie_params(['httponly'=>true,'secure'=>!empty($_SERVER['HTTPS'])&&$_SERVER['HTTPS']!=='off','samesite'=>'Lax','path'=>'/']);if(session_status()!==PHP_SESSION_ACTIVE)session_start();
require_once __DIR__.'/db.php';require_once __DIR__.'/response.php';require_once __DIR__.'/auth.php';require_once __DIR__.'/csrf.php';require_once __DIR__.'/validators.php';require_once __DIR__.'/services/AlertService.php';require_once __DIR__.'/services/InventoryService.php';require_once __DIR__.'/services/TransferService.php';
set_exception_handler(static function(Throwable $e):void{if(str_contains($_SERVER['SCRIPT_NAME']??'','/api/'))api_error($e);error_log((string)$e);http_response_code(500);echo 'An unexpected error occurred.';});
