-- Stock-Alert database setup. Import this file once in phpMyAdmin.
CREATE DATABASE IF NOT EXISTS stock_alert
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE stock_alert;

CREATE TABLE admins (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    username VARCHAR(60) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_admins_username (username)
) ENGINE=InnoDB;

CREATE TABLE warehouses (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(180) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_warehouses_name (name)
) ENGINE=InnoDB;

CREATE TABLE items (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    sku VARCHAR(64) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NOT NULL DEFAULT '',
    reorder_level INT UNSIGNED NOT NULL DEFAULT 5,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_items_sku (sku),
    KEY idx_items_name (name)
) ENGINE=InnoDB;

-- A row stores the balance of one item in one warehouse.
CREATE TABLE stock (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    item_id INT UNSIGNED NOT NULL,
    warehouse_id INT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_stock_item_warehouse (item_id, warehouse_id),
    KEY idx_stock_warehouse (warehouse_id),
    CONSTRAINT fk_stock_item FOREIGN KEY (item_id) REFERENCES items (id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_stock_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses (id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Transfer records are permanent history. They cannot be edited or deleted in the app.
CREATE TABLE transfers (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    item_id INT UNSIGNED NOT NULL,
    from_warehouse_id INT UNSIGNED NOT NULL,
    to_warehouse_id INT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    note VARCHAR(500) NOT NULL DEFAULT '',
    created_by INT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_transfers_created_at (created_at),
    KEY idx_transfers_item (item_id),
    KEY idx_transfers_from (from_warehouse_id),
    KEY idx_transfers_to (to_warehouse_id),
    CONSTRAINT fk_transfers_item FOREIGN KEY (item_id) REFERENCES items (id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_transfers_from FOREIGN KEY (from_warehouse_id) REFERENCES warehouses (id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_transfers_to FOREIGN KEY (to_warehouse_id) REFERENCES warehouses (id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_transfers_admin FOREIGN KEY (created_by) REFERENCES admins (id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Seed admin account:
-- Username: admin
-- Password: StockAlert@123
-- The password is stored as a PHP password_hash() value, never as plain text.
INSERT INTO admins (id, username, password_hash) VALUES
(1, 'admin', '$2y$12$tzhSTtGt8erH3Uouu4m5Q.ebQMQdxpa9hc3b/6Gs0X3vAcMXyhqvC');

INSERT INTO warehouses (id, name, location) VALUES
(1, 'Central Warehouse', 'Manila, Metro Manila'),
(2, 'North Branch', 'Quezon City, Metro Manila'),
(3, 'South Branch', 'Cebu City, Cebu');

INSERT INTO items (id, sku, name, description, reorder_level) VALUES
(1, 'STK-001', 'Ergonomic Laptop Stand', 'Adjustable aluminum stand for laptops.', 5),
(2, 'STK-002', 'Wireless Mouse', 'Rechargeable wireless optical mouse.', 8),
(3, 'STK-003', 'Mechanical Keyboard', 'Compact mechanical keyboard with backlight.', 5),
(4, 'STK-004', 'HDMI Cable 2m', 'High-speed HDMI cable, two meters long.', 10),
(5, 'STK-005', 'USB-C Hub', 'Multi-port USB-C adapter for laptops.', 4),
(6, 'STK-006', '24-inch Monitor', 'Full HD office monitor.', 3),
(7, 'STK-007', 'Ethernet Cable', 'Cat 6 network cable.', 8),
(8, 'STK-008', 'HD Webcam', '1080p USB webcam with microphone.', 5),
(9, 'STK-009', 'Noise-Canceling Headset', 'Wired headset for calls and online classes.', 4),
(10, 'STK-010', 'Portable SSD 1TB', 'External solid-state drive, one terabyte.', 3),
(11, 'STK-011', 'Laptop Backpack', 'Padded backpack for laptops up to 15 inches.', 5),
(12, 'STK-012', 'USB-C Power Adapter', '65W USB-C power adapter.', 6);

INSERT INTO stock (id, item_id, warehouse_id, quantity) VALUES
(1, 1, 1, 12), (2, 2, 1, 4),  (3, 3, 1, 9),  (4, 4, 1, 2),
(5, 5, 1, 6),  (6, 6, 1, 5),  (7, 7, 1, 20), (8, 8, 1, 0),
(9, 9, 1, 8),  (10, 10, 1, 1), (11, 11, 1, 7), (12, 12, 1, 11),
(13, 1, 2, 3),  (14, 2, 2, 12), (15, 3, 2, 2),  (16, 4, 2, 14),
(17, 5, 2, 1),  (18, 6, 2, 2),  (19, 7, 2, 6),  (20, 8, 2, 4),
(21, 9, 2, 2),  (22, 10, 2, 0), (23, 11, 2, 10), (24, 12, 2, 4),
(25, 1, 3, 5),  (26, 2, 3, 7),  (27, 3, 3, 4),  (28, 4, 3, 8),
(29, 5, 3, 3),  (30, 6, 3, 0),  (31, 7, 3, 12), (32, 8, 3, 0),
(33, 9, 3, 5),  (34, 10, 3, 4), (35, 11, 3, 2), (36, 12, 3, 9);

-- These sample rows illustrate the transfer log. The stock rows above show the current balances.
INSERT INTO transfers
(id, item_id, from_warehouse_id, to_warehouse_id, quantity, note, created_by, created_at) VALUES
(1, 1, 1, 2, 3, 'Initial replenishment for the north branch.', 1, DATE_SUB(NOW(), INTERVAL 12 DAY)),
(2, 2, 2, 3, 2, 'Mouse units moved for the computer lab.', 1, DATE_SUB(NOW(), INTERVAL 8 DAY)),
(3, 6, 1, 3, 1, 'Replacement monitor for the south branch.', 1, DATE_SUB(NOW(), INTERVAL 4 DAY)),
(4, 9, 3, 1, 2, 'Returned headset stock to central.', 1, DATE_SUB(NOW(), INTERVAL 1 DAY));
