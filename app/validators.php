<?php
declare(strict_types=1);
function positive_int(mixed $v,string $f='quantity'):int{if(!is_scalar($v)||filter_var($v,FILTER_VALIDATE_INT)===false||(int)$v<1)json_response(false,null,'VALIDATION_ERROR','Enter a positive whole number.',[$f=>'Must be a positive integer.'],422);return (int)$v;}
function request_json():array{$v=json_decode(file_get_contents('php://input'),true);return is_array($v)?$v:[];}
