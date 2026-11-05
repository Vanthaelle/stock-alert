<?php
declare(strict_types=1);
return ['db'=>['host'=>getenv('STOCK_DB_HOST')?:'127.0.0.1','name'=>getenv('STOCK_DB_NAME')?:'stock_alert','user'=>getenv('STOCK_DB_USER')?:'root','pass'=>getenv('STOCK_DB_PASS')!==false?getenv('STOCK_DB_PASS'):'','charset'=>'utf8mb4'],'app'=>['name'=>'Stock-Alert','debug'=>filter_var(getenv('STOCK_DEBUG')?:'0',FILTER_VALIDATE_BOOL),'session_name'=>'stock_alert_session']];
