<?php
declare(strict_types=1);
// Dependency-free smoke test runner. Uses a dedicated database and refuses the demo DB.
$config=require __DIR__.'/../app/config.php';$name=$config['db']['name'];if($name!=='stock_alert_test'){fwrite(STDERR,"Set STOCK_DB_NAME=stock_alert_test before running tests. Refusing to touch $name.\n");exit(2);}require __DIR__.'/../app/bootstrap.php';$tests=[];$pass=0;$fail=0;$test=function(string $name,callable $fn)use(&$pass,&$fail):void{try{$fn();$pass++;echo "PASS $name\n";}catch(Throwable $e){$fail++;echo "FAIL $name: {$e->getMessage()}\n";}};
$test('database connection',fn()=>db()->query('SELECT 1')->fetchColumn());$test('nonnegative stock guard',function(){try{db()->exec('INSERT INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(-1,-1,-1)');throw new RuntimeException('Negative quantity unexpectedly accepted');}catch(PDOException $e){}});$test('availability view exists',fn()=>db()->query('SELECT * FROM v_item_availability LIMIT 1'));
echo "\n$pass passed; $fail failed.\n";exit($fail?1:0);
