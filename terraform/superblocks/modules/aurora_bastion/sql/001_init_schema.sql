-- --- sql/001_init_schema.sql ---
-- Initial database schema for wegdemodb
-- Compatible with Aurora MySQL 8.0
--
-- Usage:
--   mysql -h <aurora-endpoint> -u wegdbadmin -p < 001_init_schema.sql
--
-- This script is idempotent and can be run multiple times safely

-- ===== DATABASE SETUP =====

-- Use the database (created by Terraform)
-- Note: Replace 'wegdemodb' with your actual var.db_name if different
USE wegdemodb;

-- Set character set and collation
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

-- ===== TABLES =====

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(50),
    status ENUM('active', 'inactive', 'suspended', 'deleted') NOT NULL DEFAULT 'active',
    email_verified_at TIMESTAMP NULL DEFAULT NULL,
    last_login_at TIMESTAMP NULL DEFAULT NULL,
    failed_login_attempts INT UNSIGNED DEFAULT 0,
    locked_until TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_email (email),
    KEY idx_users_status (status),
    KEY idx_users_created_at (created_at),
    KEY idx_users_email_status (email, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='User accounts table';

-- Accounts table (financial accounts, wallets, etc.)
CREATE TABLE IF NOT EXISTS accounts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    account_number VARCHAR(50) NOT NULL,
    account_type ENUM('checking', 'savings', 'investment', 'credit', 'wallet') NOT NULL,
    name VARCHAR(255) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    balance DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    available_balance DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    status ENUM('active', 'inactive', 'frozen', 'closed') NOT NULL DEFAULT 'active',
    metadata JSON,
    opened_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_accounts_number (account_number),
    KEY idx_accounts_user_id (user_id),
    KEY idx_accounts_status (status),
    KEY idx_accounts_user_status (user_id, status),
    KEY idx_accounts_type (account_type),
    CONSTRAINT fk_accounts_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='User financial accounts';

-- Transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_id BIGINT UNSIGNED NOT NULL,
    transaction_id VARCHAR(100) NOT NULL,
    reference_number VARCHAR(100),
    amount DECIMAL(18,2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    txn_type ENUM('credit', 'debit') NOT NULL,
    txn_category ENUM('deposit', 'withdrawal', 'transfer', 'payment', 'fee', 'interest', 'adjustment', 'other') NOT NULL,
    description TEXT,
    balance_before DECIMAL(18,2),
    balance_after DECIMAL(18,2),
    counterparty_name VARCHAR(255),
    counterparty_account VARCHAR(100),
    status ENUM('pending', 'processing', 'completed', 'failed', 'reversed') NOT NULL DEFAULT 'pending',
    metadata JSON,
    occurred_at DATETIME NOT NULL,
    settled_at DATETIME,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_transactions_id (transaction_id),
    KEY idx_transactions_account_id (account_id),
    KEY idx_transactions_occurred_at (occurred_at),
    KEY idx_transactions_account_occurred (account_id, occurred_at),
    KEY idx_transactions_status (status),
    KEY idx_transactions_type (txn_type),
    KEY idx_transactions_category (txn_category),
    KEY idx_transactions_reference (reference_number),
    CONSTRAINT fk_transactions_account FOREIGN KEY (account_id)
        REFERENCES accounts(id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Financial transactions';

-- Audit log table (for compliance)
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED,
    entity_type VARCHAR(50) NOT NULL,
    entity_id BIGINT UNSIGNED NOT NULL,
    action VARCHAR(50) NOT NULL,
    old_values JSON,
    new_values JSON,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_audit_user_id (user_id),
    KEY idx_audit_entity (entity_type, entity_id),
    KEY idx_audit_action (action),
    KEY idx_audit_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Audit trail for compliance';

-- Sessions table (for session management)
CREATE TABLE IF NOT EXISTS sessions (
    id VARCHAR(128) NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    payload TEXT NOT NULL,
    last_activity TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_sessions_user_id (user_id),
    KEY idx_sessions_last_activity (last_activity),
    CONSTRAINT fk_sessions_user FOREIGN KEY (user_id)
        REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='User session management';

-- ===== VIEWS =====

-- Account summary view
CREATE OR REPLACE VIEW v_account_summary AS
SELECT
    a.id,
    a.account_number,
    a.account_type,
    a.name,
    a.currency,
    a.balance,
    a.available_balance,
    a.status,
    u.email AS user_email,
    u.first_name,
    u.last_name,
    u.status AS user_status,
    a.created_at,
    a.updated_at
FROM accounts a
JOIN users u ON a.user_id = u.id
WHERE a.status = 'active' AND u.status = 'active';

-- Recent transactions view
CREATE OR REPLACE VIEW v_recent_transactions AS
SELECT
    t.id,
    t.transaction_id,
    t.amount,
    t.currency,
    t.txn_type,
    t.txn_category,
    t.description,
    t.status,
    t.occurred_at,
    a.account_number,
    a.name AS account_name,
    u.email AS user_email
FROM transactions t
JOIN accounts a ON t.account_id = a.id
JOIN users u ON a.user_id = u.id
WHERE t.occurred_at >= DATE_SUB(NOW(), INTERVAL 90 DAY)
ORDER BY t.occurred_at DESC;

-- ===== STORED PROCEDURES =====

DELIMITER $$

-- Procedure to create a new transaction with balance update
CREATE PROCEDURE IF NOT EXISTS sp_create_transaction(
    IN p_account_id BIGINT,
    IN p_amount DECIMAL(18,2),
    IN p_txn_type ENUM('credit', 'debit'),
    IN p_description TEXT,
    IN p_transaction_id VARCHAR(100)
)
BEGIN
    DECLARE v_balance_before DECIMAL(18,2);
    DECLARE v_balance_after DECIMAL(18,2);
    DECLARE v_available_before DECIMAL(18,2);
    DECLARE v_available_after DECIMAL(18,2);

    START TRANSACTION;

    -- Lock the account row
    SELECT balance, available_balance
    INTO v_balance_before, v_available_before
    FROM accounts
    WHERE id = p_account_id
    FOR UPDATE;

    -- Calculate new balance
    IF p_txn_type = 'credit' THEN
        SET v_balance_after = v_balance_before + p_amount;
        SET v_available_after = v_available_before + p_amount;
    ELSE
        -- Check sufficient balance for debit
        IF v_available_before < p_amount THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient balance for transaction';
        END IF;

        SET v_balance_after = v_balance_before - p_amount;
        SET v_available_after = v_available_before - p_amount;
    END IF;

    -- Update account balance
    UPDATE accounts
    SET balance = v_balance_after,
        available_balance = v_available_after,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_account_id;

    -- Insert transaction record
    INSERT INTO transactions (
        account_id, transaction_id, amount, txn_type,
        description, balance_before, balance_after,
        status, occurred_at
    ) VALUES (
        p_account_id, p_transaction_id, p_amount, p_txn_type,
        p_description, v_balance_before, v_balance_after,
        'completed', CURRENT_TIMESTAMP
    );

    COMMIT;
END$$

DELIMITER ;

-- ===== INDEXES FOR PERFORMANCE =====

-- Additional composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_txn_composite_search
    ON transactions(account_id, status, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_users_login
    ON users(email, password_hash, status);

CREATE INDEX IF NOT EXISTS idx_accounts_balance_check
    ON accounts(user_id, status, available_balance);

-- ===== USERS AND PERMISSIONS =====

-- Note: These commands should be run by the master user after connecting
-- Uncomment and modify as needed for your application

/*
-- Create application users (run as master user)
-- Replace 'your_password' with strong passwords from Secrets Manager

-- Application writer user (for backend services)
CREATE USER IF NOT EXISTS 'app_writer'@'%' IDENTIFIED BY 'your_secure_password_here';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON wegdemodb.* TO 'app_writer'@'%';

-- Application reader user (for read-only operations)
CREATE USER IF NOT EXISTS 'app_reader'@'%' IDENTIFIED BY 'your_secure_password_here';
GRANT SELECT ON wegdemodb.* TO 'app_reader'@'%';

-- Analytics user (for reporting)
CREATE USER IF NOT EXISTS 'analytics_user'@'%' IDENTIFIED BY 'your_secure_password_here';
GRANT SELECT ON wegdemodb.v_account_summary TO 'analytics_user'@'%';
GRANT SELECT ON wegdemodb.v_recent_transactions TO 'analytics_user'@'%';

-- Apply privileges
FLUSH PRIVILEGES;
*/

-- ===== INITIAL SEED DATA (OPTIONAL) =====

-- Uncomment to insert test data in development

/*
-- Test user
INSERT INTO users (email, password_hash, first_name, last_name, status, email_verified_at)
VALUES ('test@example.com', '$2b$12$LQMxQ7TvgxMBTvT5F4V.F.FqRH5ExBKPPKDZ/kgNyIe.vAV7XnIaa', 'Test', 'User', 'active', NOW());

-- Test account
INSERT INTO accounts (user_id, account_number, account_type, name, currency, balance, available_balance, status)
SELECT id, 'ACC-TEST-001', 'checking', 'Test Checking Account', 'USD', 1000.00, 1000.00, 'active'
FROM users WHERE email = 'test@example.com';

-- Test transactions
INSERT INTO transactions (
    account_id, transaction_id, amount, currency, txn_type, txn_category,
    description, balance_before, balance_after, status, occurred_at
)
SELECT
    a.id,
    CONCAT('TXN-', UUID()),
    100.00,
    'USD',
    'credit',
    'deposit',
    'Initial deposit',
    0.00,
    100.00,
    'completed',
    NOW()
FROM accounts a
JOIN users u ON a.user_id = u.id
WHERE u.email = 'test@example.com'
LIMIT 1;
*/

-- ===== MIGRATION TRACKING TABLE =====

-- Track schema versions
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(50) NOT NULL,
    description VARCHAR(255),
    executed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    execution_time_ms INT,
    PRIMARY KEY (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Database schema migration tracking';

-- Record this migration
INSERT INTO schema_migrations (version, description, execution_time_ms)
VALUES ('001_init_schema', 'Initial database schema with users, accounts, and transactions', 0)
ON DUPLICATE KEY UPDATE executed_at = CURRENT_TIMESTAMP;

-- ===== SUMMARY =====
SELECT
    'Schema initialization complete' AS status,
    COUNT(DISTINCT TABLE_NAME) AS tables_created,
    COUNT(DISTINCT ROUTINE_NAME) AS procedures_created,
    DATABASE() AS database_name,
    VERSION() AS mysql_version,
    NOW() AS executed_at
FROM information_schema.TABLES t
LEFT JOIN information_schema.ROUTINES r ON r.ROUTINE_SCHEMA = t.TABLE_SCHEMA
WHERE t.TABLE_SCHEMA = DATABASE()
GROUP BY t.TABLE_SCHEMA;