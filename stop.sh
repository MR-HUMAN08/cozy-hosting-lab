#!/bin/bash
# Stop and remove the CozyHosting lab
cd "$(dirname "$0")"
if docker compose version &> /dev/null 2>&1; then
    docker compose down -v
else
    docker-compose down -v
fi
echo "[+] CozyHosting lab stopped and cleaned up."
