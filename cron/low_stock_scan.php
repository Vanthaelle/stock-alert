<?php
declare(strict_types=1);require __DIR__.'/../app/bootstrap.php';if(PHP_SAPI!=='cli'){http_response_code(403);exit("CLI only\n");}try{$n=AlertService::scan(db());echo "Scanned $n active items at ".date(DATE_ATOM).PHP_EOL;}catch(Throwable $e){error_log((string)$e);fwrite(STDERR,"Scan failed: ".$e->getMessage().PHP_EOL);exit(1);}
