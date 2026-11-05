<?php
declare(strict_types=1);
function csrf_token():string{if(empty($_SESSION['csrf']))$_SESSION['csrf']=bin2hex(random_bytes(32));return $_SESSION['csrf'];}
function verify_csrf():void{$t=$_SERVER['HTTP_X_CSRF_TOKEN']??'';if(!is_string($t)||!hash_equals($_SESSION['csrf']??'',$t))json_response(false,null,'CSRF_INVALID','Refresh the page and try again.',[],403);}
