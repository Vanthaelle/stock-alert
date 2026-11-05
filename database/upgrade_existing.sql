-- Run this once in phpMyAdmin after selecting the existing stock_alert database.
-- This migration does not drop or modify existing tables or records.
CREATE TABLE IF NOT EXISTS purchase_orders (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 order_no VARCHAR(32) NOT NULL UNIQUE,
 item_id BIGINT UNSIGNED NOT NULL,
 supplier_id BIGINT UNSIGNED NOT NULL,
 quantity INT UNSIGNED NOT NULL,
 unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0,
 expected_date DATE NULL,
 notes VARCHAR(255) NULL,
 status ENUM('Pending','Ordered','Received','Cancelled') NOT NULL DEFAULT 'Pending',
 created_by BIGINT UNSIGNED NOT NULL,
 created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 CONSTRAINT fk_po_item FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE RESTRICT,
 CONSTRAINT fk_po_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT,
 CONSTRAINT fk_po_user FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
 INDEX (status), INDEX (created_at)
) ENGINE=InnoDB;
