-- ═══════════════════════════════════════════════════════
-- CozyHosting PostgreSQL Database Initialization
-- ═══════════════════════════════════════════════════════

-- Create the cozyhosting database (run as postgres superuser)
-- Note: Database creation is handled by entrypoint.sh

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    name VARCHAR(50) NOT NULL,
    password VARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL
);

-- Insert data
-- The 'admin' password hash will be replaced by init_db.py with a real bcrypt hash of 'manchesterunited'
-- The 'kanderson' password is a bcrypt hash of a random strong password (not crackable)
INSERT INTO users (name, password, role) VALUES
    ('kanderson', '$2a$10$E/Vcd9ecflmPudWeLSEIv.cvK6QjxjWlWXpij1NVNV3Mm6eH58zim', 'Admin'),
    ('admin', 'PLACEHOLDER_HASH', 'Admin');
