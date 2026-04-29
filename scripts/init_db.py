#!/usr/bin/env python3
"""
Generate bcrypt hash for 'manchesterunited' and initialize PostgreSQL database.
This runs during container startup to ensure proper bcrypt hashes.
"""

import subprocess
import bcrypt
import sys

def main():
    # Generate bcrypt hash for 'manchesterunited' (this is the crackable password)
    password = b"manchesterunited"
    salt = bcrypt.gensalt(rounds=10)
    hashed = bcrypt.hashpw(password, salt).decode('utf-8')

    print(f"[*] Generated bcrypt hash for database: {hashed}")

    # Read the SQL template
    with open('/tmp/init.sql', 'r') as f:
        sql = f.read()

    # Replace placeholder with real hash
    sql = sql.replace('PLACEHOLDER_HASH', hashed)

    # Write the final SQL
    with open('/tmp/init_final.sql', 'w') as f:
        f.write(sql)

    # Execute SQL against PostgreSQL
    try:
        # Create database
        subprocess.run(
            ['sudo', '-u', 'postgres', 'psql', '-c', 'CREATE DATABASE cozyhosting;'],
            check=False,  # Might already exist
            capture_output=True
        )

        # Run init SQL
        result = subprocess.run(
            ['sudo', '-u', 'postgres', 'psql', '-d', 'cozyhosting', '-f', '/tmp/init_final.sql'],
            check=True,
            capture_output=True,
            text=True
        )
        print(f"[+] Database initialized successfully")
        print(result.stdout)

    except subprocess.CalledProcessError as e:
        print(f"[-] Database initialization failed: {e.stderr}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
