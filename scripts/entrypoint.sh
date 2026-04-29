#!/bin/bash
# ═══════════════════════════════════════════════════════
# CozyHosting Lab - Container Entrypoint
# Starts all services: PostgreSQL, SSH, nginx, Spring Boot
# ═══════════════════════════════════════════════════════

set -e

# ─── Verify required files exist ───
echo "═══════════════════════════════════════════════"
echo "  Verifying required files..."
echo "═══════════════════════════════════════════════"

if [ ! -f /tmp/init.sql ]; then
    echo "[!] ERROR: /tmp/init.sql not found in container"
    echo "[!] This file should be copied during Docker build"
    exit 1
fi

if [ ! -f /tmp/init_db.py ]; then
    echo "[!] ERROR: /tmp/init_db.py not found in container"
    echo "[!] This file should be copied during Docker build"
    exit 1
fi

if [ ! -f /entrypoint.sh ]; then
    echo "[!] ERROR: /entrypoint.sh not found"
    exit 1
fi

echo "[+] All required files verified"

# ─── Root flag (configurable via FLAG env var) ───
if [ -z "$FLAG" ]; then
    FLAG="flag{c0zy_h0st1ng_5pr1ng_b00t_pwn3d_2024}"
fi
echo "$FLAG" > /root/root.txt
chmod 600 /root/root.txt

echo "═══════════════════════════════════════════════"
echo "  CozyHosting CTF Lab - Starting Services..."
echo "═══════════════════════════════════════════════"

# ─── 1. Start PostgreSQL ───
echo "[*] Starting PostgreSQL..."
service postgresql start
sleep 2

# Wait for PostgreSQL to be ready
for i in $(seq 1 30); do
    if sudo -u postgres pg_isready -q 2>/dev/null; then
        echo "[+] PostgreSQL is ready"
        break
    fi
    echo "[*] Waiting for PostgreSQL... ($i/30)"
    sleep 1
done

# Set PostgreSQL password for postgres user
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'Vg&nvzAQ7XxR';" 2>/dev/null || true

# Configure PostgreSQL to accept password authentication
PG_HBA=$(find /etc/postgresql -name 'pg_hba.conf' 2>/dev/null | head -1)
if [ -n "$PG_HBA" ]; then
    sed -i 's/local\s\+all\s\+all\s\+peer/local   all             all                                     md5/' "$PG_HBA"
    sed -i 's/host\s\+all\s\+all\s\+127.0.0.1\/32\s\+scram-sha-256/host    all             all             127.0.0.1\/32            md5/' "$PG_HBA"
    service postgresql restart
    sleep 2
fi

# ─── 2. Initialize Database ───
echo "[*] Initializing database..."
python3 /tmp/init_db.py

# ─── 3. Start SSH Server ───
echo "[*] Starting SSH server..."
service ssh start
echo "[+] SSH server started on port 22"

# ─── 4. Start Nginx ───
echo "[*] Starting Nginx..."
service nginx start
echo "[+] Nginx started on port 80"

# ─── 5. Start Spring Boot Application ───
echo "[*] Starting CozyHosting Spring Boot application..."
echo "═══════════════════════════════════════════════"
echo "  CozyHosting Lab is READY!"
echo "  Web:  http://localhost:80"
echo "  SSH:  port 22"
echo "═══════════════════════════════════════════════"

# Run Spring Boot JAR as 'app' user (foreground, keeps container alive)
exec sudo -u app java -jar /app/cloudhosting-0.0.1.jar
