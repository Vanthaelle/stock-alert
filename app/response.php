<?php
declare(strict_types=1);
function json_response(bool $ok,mixed $data=null,?string $code=null,string $message='',array $fields=[],int $status=200):never { http_response_code($status);header('Content-Type: application/json; charset=utf-8');echo json_encode(['ok'=>$ok,'data'=>$data,'error'=>$ok?null:['code'=>$code??'ERROR','message'=>$message,'fields'=>(object)$fields]],JSON_UNESCAPED_SLASHES|JSON_INVALID_UTF8_SUBSTITUTE);exit; }
function api_error(Throwable $e):never { $id=bin2hex(random_bytes(5));error_log("[$id] ".$e);$debug=(require __DIR__.'/config.php')['app']['debug'];json_response(false,null,'INTERNAL_ERROR',$debug?$e->getMessage():"Unexpected server error. Reference: $id",[],500); }
