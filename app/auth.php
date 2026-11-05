<?php
declare(strict_types=1);
function current_user():?array{return $_SESSION['user']??null;}
function require_auth():array{$u=current_user();if(!$u){header('Location: '.(str_contains($_SERVER['SCRIPT_NAME']??'','/api/')?'../index.php':'index.php'));exit;}return $u;}
function require_role(array $roles):array{$u=current_user();if(!$u){json_response(false,null,'UNAUTHENTICATED','Administrator login is required.',[],401);}if(!in_array($u['role'],$roles,true)){json_response(false,null,'FORBIDDEN','Administrator access is required.',[],403);}return $u;}
function e(mixed $v):string{return htmlspecialchars((string)$v,ENT_QUOTES|ENT_SUBSTITUTE,'UTF-8');}
