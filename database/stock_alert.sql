-- XAMPP import. For shared hosting, remove CREATE DATABASE and USE.
CREATE DATABASE IF NOT EXISTS stock_alert CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE stock_alert;
CREATE TABLE IF NOT EXISTS users(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,name VARCHAR(120) NOT NULL,email VARCHAR(190) NOT NULL UNIQUE,password_hash VARCHAR(255) NOT NULL,role ENUM('admin','manager','viewer') NOT NULL DEFAULT 'viewer',is_active TINYINT(1) NOT NULL DEFAULT 1,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS warehouses(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,name VARCHAR(150) NOT NULL UNIQUE,code VARCHAR(30) NOT NULL UNIQUE,address VARCHAR(255),is_active TINYINT(1) NOT NULL DEFAULT 1,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS suppliers(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,name VARCHAR(190) NOT NULL,contact_person VARCHAR(120),email VARCHAR(190),phone VARCHAR(50),address VARCHAR(255),lead_time_days INT UNSIGNED NOT NULL DEFAULT 7,payment_terms VARCHAR(120),notes TEXT,is_active TINYINT(1) NOT NULL DEFAULT 1,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS categories(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,name VARCHAR(120) NOT NULL UNIQUE,description VARCHAR(255)) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS items(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,sku VARCHAR(60) NOT NULL UNIQUE,name VARCHAR(190) NOT NULL,category_id BIGINT UNSIGNED,unit VARCHAR(30) NOT NULL DEFAULT 'pcs',reorder_level INT UNSIGNED NOT NULL DEFAULT 0,reorder_qty INT UNSIGNED NOT NULL DEFAULT 0,unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0,preferred_supplier_id BIGINT UNSIGNED,is_active TINYINT(1) NOT NULL DEFAULT 1,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,updated_at TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,CONSTRAINT fk_item_cat FOREIGN KEY(category_id) REFERENCES categories(id) ON DELETE RESTRICT,CONSTRAINT fk_item_supplier FOREIGN KEY(preferred_supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT,INDEX(category_id),INDEX(name)) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS batches(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,item_id BIGINT UNSIGNED NOT NULL,batch_number VARCHAR(80) NOT NULL,manufacturing_date DATE NOT NULL,expiration_date DATE NOT NULL,received_date DATE NOT NULL DEFAULT (CURRENT_DATE),supplier_id BIGINT UNSIGNED,unit_cost DECIMAL(12,2),notes TEXT,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,UNIQUE(item_id,batch_number),CONSTRAINT fk_batch_item FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE RESTRICT,CONSTRAINT fk_batch_supplier FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT,CHECK(expiration_date>manufacturing_date),INDEX(expiration_date),INDEX(item_id)) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS stock_levels(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,batch_id BIGINT UNSIGNED NOT NULL,warehouse_id BIGINT UNSIGNED NOT NULL,quantity INT NOT NULL DEFAULT 0 CHECK(quantity>=0),updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,UNIQUE(batch_id,warehouse_id),FOREIGN KEY(batch_id) REFERENCES batches(id) ON DELETE RESTRICT,FOREIGN KEY(warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,INDEX(warehouse_id)) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS transfers(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,transfer_no VARCHAR(30) NOT NULL UNIQUE,from_warehouse_id BIGINT UNSIGNED NOT NULL,to_warehouse_id BIGINT UNSIGNED NOT NULL,notes TEXT,idempotency_key VARCHAR(64) NOT NULL UNIQUE,user_id BIGINT UNSIGNED NOT NULL,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,FOREIGN KEY(from_warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,FOREIGN KEY(to_warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT,INDEX(created_at)) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS transfer_lines(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,transfer_id BIGINT UNSIGNED NOT NULL,batch_id BIGINT UNSIGNED NOT NULL,quantity INT UNSIGNED NOT NULL,FOREIGN KEY(transfer_id) REFERENCES transfers(id) ON DELETE RESTRICT,FOREIGN KEY(batch_id) REFERENCES batches(id) ON DELETE RESTRICT) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS stock_movements(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,batch_id BIGINT UNSIGNED NOT NULL,warehouse_id BIGINT UNSIGNED NOT NULL,type ENUM('receive','issue','adjust','write_off','transfer_in','transfer_out') NOT NULL,quantity_change INT NOT NULL,balance_after INT NOT NULL CHECK(balance_after>=0),reason VARCHAR(255) NOT NULL,reference VARCHAR(80),user_id BIGINT UNSIGNED NULL,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,FOREIGN KEY(batch_id) REFERENCES batches(id) ON DELETE RESTRICT,FOREIGN KEY(warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE RESTRICT,INDEX(created_at),INDEX(batch_id),INDEX(warehouse_id)) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS low_stock_alerts(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,item_id BIGINT UNSIGNED NOT NULL,status ENUM('draft','sent','resolved','dismissed') NOT NULL DEFAULT 'draft',open_item_id BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN status IN ('draft','sent') THEN item_id ELSE NULL END) STORED UNIQUE,subject VARCHAR(255) NOT NULL,body TEXT NOT NULL,available_qty INT NOT NULL,reorder_level INT NOT NULL,suggested_qty INT NOT NULL,supplier_name VARCHAR(190),supplier_email VARCHAR(190),supplier_phone VARCHAR(50),resolved_at DATETIME,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE RESTRICT,INDEX(status),INDEX(item_id)) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS purchase_orders(id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,order_no VARCHAR(32) NOT NULL UNIQUE,item_id BIGINT UNSIGNED NOT NULL,supplier_id BIGINT UNSIGNED NOT NULL,quantity INT UNSIGNED NOT NULL,unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0,expected_date DATE NULL,notes VARCHAR(255),status ENUM('Pending','Ordered','Received','Cancelled') NOT NULL DEFAULT 'Pending',created_by BIGINT UNSIGNED NOT NULL,created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE RESTRICT,FOREIGN KEY(supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT,FOREIGN KEY(created_by) REFERENCES users(id) ON DELETE RESTRICT,INDEX(status),INDEX(created_at)) ENGINE=InnoDB;
CREATE OR REPLACE VIEW v_item_availability AS SELECT i.id item_id,COALESCE(SUM(CASE WHEN b.expiration_date>=CURDATE() AND w.is_active=1 THEN sl.quantity ELSE 0 END),0) available_qty FROM items i LEFT JOIN batches b ON b.item_id=i.id LEFT JOIN stock_levels sl ON sl.batch_id=b.id LEFT JOIN warehouses w ON w.id=sl.warehouse_id GROUP BY i.id;
INSERT IGNORE INTO warehouses(name,code,address) VALUES('Main Warehouse','MAIN','Olongapo'),('North Depot','NORTH','Subic'),('South Distribution','SOUTH','Bataan'),('East Storage','EAST','Zambales');
INSERT IGNORE INTO suppliers(name,contact_person,email,phone,lead_time_days,payment_terms) VALUES
('MedSupply PH','Ana Cruz','sales@medsupply.example','09170000001',5,'Net 30'),('FreshLine Foods','Ben Reyes','orders@freshline.example','09170000002',2,'COD'),('CleanChem Trading','Carlo Lim','hello@cleanchem.example','09170000003',7,'Net 15'),('BeautySource','Dina Tan','sales@beautysource.example','09170000004',10,'Net 30'),('SafeCare Medical','Ella Santos','orders@safecare.example','09170000005',4,'Net 30'),('Prime Essentials','Faye Garcia','sales@prime.example','09170000006',6,'Net 15'),('Pacific Packaging','Gio Flores','info@pacificpack.example','09170000007',8,'COD'),('Daily Goods','Hana Dizon','orders@dailygoods.example','09170000008',3,'COD'),('LabPro Supplies','Ivan Co','sales@labpro.example','09170000009',12,'Net 30'),('Wellness Depot','Joy Ramos','hello@wellness.example','09170000010',5,'Net 15');
INSERT IGNORE INTO categories(name,description) VALUES('Medical Supplies','Clinical consumables'),('Food & Beverage','Perishable goods'),('Cleaning Chemicals','Cleaning and sanitation'),('Cosmetics','Personal care'),('Laboratory','Lab consumables'),('Packaging','Storage and packing');

INSERT IGNORE INTO items(sku,name,category_id,unit,reorder_level,reorder_qty,unit_cost,preferred_supplier_id) VALUES
('SKU-001','Medical Item 1',1,'pcs',20,40,2.35,1),
('SKU-002','Product Item 2',2,'pcs',20,40,4.70,2),
('SKU-003','Product Item 3',3,'pcs',20,40,7.05,3),
('SKU-004','Product Item 4',4,'pcs',20,40,9.40,4),
('SKU-005','Product Item 5',5,'pcs',20,40,11.75,5),
('SKU-006','Product Item 6',6,'pcs',20,40,14.10,6),
('SKU-007','Medical Item 7',1,'pcs',20,40,16.45,7),
('SKU-008','Product Item 8',2,'pcs',20,40,18.80,8),
('SKU-009','Product Item 9',3,'pcs',20,40,21.15,9),
('SKU-010','Product Item 10',4,'pcs',20,40,23.50,10),
('SKU-011','Product Item 11',5,'pcs',12,24,25.85,1),
('SKU-012','Product Item 12',6,'pcs',12,24,28.20,2),
('SKU-013','Medical Item 13',1,'pcs',12,24,30.55,3),
('SKU-014','Product Item 14',2,'pcs',12,24,32.90,4),
('SKU-015','Product Item 15',3,'pcs',12,24,35.25,5),
('SKU-016','Product Item 16',4,'pcs',12,24,37.60,6),
('SKU-017','Product Item 17',5,'pcs',12,24,39.95,7),
('SKU-018','Product Item 18',6,'pcs',12,24,42.30,8),
('SKU-019','Medical Item 19',1,'pcs',12,24,44.65,9),
('SKU-020','Product Item 20',2,'pcs',12,24,47.00,10),
('SKU-021','Product Item 21',3,'pcs',12,24,49.35,1),
('SKU-022','Product Item 22',4,'pcs',12,24,51.70,2),
('SKU-023','Product Item 23',5,'pcs',12,24,54.05,3),
('SKU-024','Product Item 24',6,'pcs',12,24,56.40,4),
('SKU-025','Medical Item 25',1,'pcs',12,24,58.75,5),
('SKU-026','Product Item 26',2,'pcs',12,24,61.10,6),
('SKU-027','Product Item 27',3,'pcs',12,24,63.45,7),
('SKU-028','Product Item 28',4,'pcs',12,24,65.80,8),
('SKU-029','Product Item 29',5,'pcs',12,24,68.15,9),
('SKU-030','Product Item 30',6,'pcs',12,24,70.50,10),
('SKU-031','Medical Item 31',1,'pcs',12,24,72.85,1),
('SKU-032','Product Item 32',2,'pcs',12,24,75.20,2),
('SKU-033','Product Item 33',3,'pcs',12,24,77.55,3),
('SKU-034','Product Item 34',4,'pcs',12,24,79.90,4),
('SKU-035','Product Item 35',5,'pcs',12,24,82.25,5),
('SKU-036','Product Item 36',6,'pcs',12,24,84.60,6),
('SKU-037','Medical Item 37',1,'pcs',12,24,86.95,7),
('SKU-038','Product Item 38',2,'pcs',12,24,89.30,8),
('SKU-039','Product Item 39',3,'pcs',12,24,91.65,9),
('SKU-040','Product Item 40',4,'pcs',12,24,94.00,10);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(1,'B-001-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),1,2.35);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(1,1,0);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(1,'B-001-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),1,2.35);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(2,2,0);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(2,'B-002-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),2,4.70);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(3,2,0);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(2,'B-002-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),2,4.70);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(4,3,0);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(3,'B-003-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),3,7.05);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(5,3,0);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(3,'B-003-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),3,7.05);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(6,4,0);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(4,'B-004-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),4,9.40);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(7,4,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(7,4,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(4,'B-004-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),4,9.40);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(8,1,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(8,1,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(5,'B-005-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),5,11.75);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(9,1,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(9,1,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(5,'B-005-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),5,11.75);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(10,2,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(10,2,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(6,'B-006-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),6,14.10);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(11,2,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(11,2,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(6,'B-006-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),6,14.10);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(12,3,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(12,3,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(7,'B-007-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),7,16.45);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(13,3,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(13,3,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(7,'B-007-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL -5 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),7,16.45);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(14,4,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(14,4,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(8,'B-008-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL -5 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),8,18.80);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(15,4,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(15,4,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(8,'B-008-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),8,18.80);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(16,1,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(16,1,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(9,'B-009-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),9,21.15);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(17,1,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(17,1,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(9,'B-009-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),9,21.15);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(18,2,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(18,2,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(10,'B-010-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),10,23.50);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(19,2,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(19,2,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(10,'B-010-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),10,23.50);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(20,3,4);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(20,3,'receive',4,4,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(11,'B-011-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),1,25.85);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(21,3,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(21,3,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(11,'B-011-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),1,25.85);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(22,4,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(22,4,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(12,'B-012-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),2,28.20);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(23,4,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(23,4,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(12,'B-012-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),2,28.20);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(24,1,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(24,1,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(13,'B-013-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),3,30.55);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(25,1,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(25,1,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(13,'B-013-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),3,30.55);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(26,2,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(26,2,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(14,'B-014-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),4,32.90);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(27,2,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(27,2,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(14,'B-014-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),4,32.90);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(28,3,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(28,3,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(15,'B-015-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),5,35.25);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(29,3,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(29,3,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(15,'B-015-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),5,35.25);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(30,4,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(30,4,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(16,'B-016-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),6,37.60);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(31,4,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(31,4,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(16,'B-016-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL -5 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),6,37.60);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(32,1,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(32,1,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(17,'B-017-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL -5 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),7,39.95);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(33,1,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(33,1,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(17,'B-017-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),7,39.95);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(34,2,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(34,2,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(18,'B-018-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),8,42.30);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(35,2,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(35,2,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(18,'B-018-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),8,42.30);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(36,3,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(36,3,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(19,'B-019-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),9,44.65);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(37,3,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(37,3,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(19,'B-019-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),9,44.65);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(38,4,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(38,4,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(20,'B-020-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),10,47.00);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(39,4,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(39,4,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(20,'B-020-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),10,47.00);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(40,1,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(40,1,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(21,'B-021-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),1,49.35);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(41,1,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(41,1,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(21,'B-021-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),1,49.35);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(42,2,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(42,2,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(22,'B-022-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),2,51.70);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(43,2,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(43,2,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(22,'B-022-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),2,51.70);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(44,3,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(44,3,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(23,'B-023-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),3,54.05);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(45,3,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(45,3,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(23,'B-023-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),3,54.05);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(46,4,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(46,4,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(24,'B-024-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),4,56.40);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(47,4,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(47,4,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(24,'B-024-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),4,56.40);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(48,1,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(48,1,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(25,'B-025-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),5,58.75);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(49,1,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(49,1,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(25,'B-025-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL -5 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),5,58.75);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(50,2,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(50,2,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(26,'B-026-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL -5 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),6,61.10);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(51,2,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(51,2,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(26,'B-026-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),6,61.10);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(52,3,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(52,3,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(27,'B-027-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),7,63.45);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(53,3,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(53,3,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(27,'B-027-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),7,63.45);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(54,4,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(54,4,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(28,'B-028-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),8,65.80);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(55,4,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(55,4,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(28,'B-028-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),8,65.80);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(56,1,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(56,1,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(29,'B-029-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),9,68.15);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(57,1,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(57,1,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(29,'B-029-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),9,68.15);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(58,2,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(58,2,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(30,'B-030-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),10,70.50);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(59,2,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(59,2,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(30,'B-030-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),10,70.50);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(60,3,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(60,3,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(31,'B-031-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),1,72.85);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(61,3,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(61,3,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(31,'B-031-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),1,72.85);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(62,4,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(62,4,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(32,'B-032-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),2,75.20);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(63,4,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(63,4,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(32,'B-032-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),2,75.20);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(64,1,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(64,1,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(33,'B-033-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),3,77.55);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(65,1,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(65,1,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(33,'B-033-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),3,77.55);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(66,2,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(66,2,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(34,'B-034-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),4,79.90);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(67,2,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(67,2,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(34,'B-034-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL -5 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),4,79.90);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(68,3,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(68,3,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(35,'B-035-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL -5 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),5,82.25);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(69,3,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(69,3,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(35,'B-035-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),5,82.25);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(70,4,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(70,4,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(36,'B-036-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),6,84.60);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(71,4,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(71,4,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(36,'B-036-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),6,84.60);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(72,1,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(72,1,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(37,'B-037-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),7,86.95);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(73,1,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(73,1,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(37,'B-037-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),7,86.95);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(74,2,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(74,2,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(38,'B-038-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),8,89.30);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(75,2,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(75,2,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(38,'B-038-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),8,89.30);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(76,3,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(76,3,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(39,'B-039-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 15 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),9,91.65);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(77,3,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(77,3,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(39,'B-039-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),9,91.65);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(78,4,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(78,4,'receive',23,23,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(40,'B-040-1',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 150 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),10,94.00);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(79,4,22);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(79,4,'receive',22,22,'Opening seed balance',NULL);
INSERT IGNORE INTO batches(item_id,batch_number,manufacturing_date,expiration_date,received_date,supplier_id,unit_cost) VALUES(40,'B-040-2',DATE_SUB(CURDATE(),INTERVAL 180 DAY),DATE_ADD(CURDATE(),INTERVAL 160 DAY),DATE_SUB(CURDATE(),INTERVAL 30 DAY),10,94.00);
INSERT IGNORE INTO stock_levels(batch_id,warehouse_id,quantity) VALUES(80,1,23);
INSERT IGNORE INTO stock_movements(batch_id,warehouse_id,type,quantity_change,balance_after,reason,user_id) VALUES(80,1,'receive',23,23,'Opening seed balance',NULL);
