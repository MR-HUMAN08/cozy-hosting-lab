#!/bin/bash
# ═══════════════════════════════════════════════════════
# CozyHosting CTF Lab - Start Script
# ═══════════════════════════════════════════════════════

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║         CozyHosting - HTB CTF Lab                 ║"
echo "║     Replicating HackTheBox CozyHosting Machine    ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[!] Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}[!] Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Check for port conflicts
echo -e "${YELLOW}[*] Checking for port conflicts...${NC}"
if ss -tlnp 2>/dev/null | grep -q ':22 ' || netstat -tlnp 2>/dev/null | grep -q ':22 '; then
    echo -e "${YELLOW}[!] WARNING: Port 22 is already in use.${NC}"
    echo -e "${YELLOW}    You may need to stop your local SSH server:${NC}"
    echo -e "${YELLOW}    sudo systemctl stop ssh${NC}"
    echo -e "${YELLOW}    Or change the port mapping in docker-compose.yml${NC}"
    echo ""
fi

if ss -tlnp 2>/dev/null | grep -q ':80 ' || netstat -tlnp 2>/dev/null | grep -q ':80 '; then
    echo -e "${YELLOW}[!] WARNING: Port 80 is already in use.${NC}"
    echo -e "${YELLOW}    You may need to stop your local web server.${NC}"
    echo ""
fi

# Build and start
echo -e "${GREEN}[*] Building CozyHosting lab container...${NC}"
echo ""

cd "$(dirname "$0")"

# Use docker compose (v2) or docker-compose (v1)
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

$COMPOSE_CMD build --no-cache

echo ""
echo -e "${GREEN}[*] Starting CozyHosting lab...${NC}"
$COMPOSE_CMD up -d

echo ""
echo -e "${GREEN}[*] Waiting for services to start...${NC}"
sleep 5

# Get container IP
CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' cozyhosting 2>/dev/null || echo "unknown")

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN} ✓ CozyHosting Lab is RUNNING!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN} Target Information:${NC}"
echo -e "   Web:          http://localhost (port 80)"
echo -e "   SSH:          port 22"
echo -e "   Container IP: ${CONTAINER_IP}"
echo ""
echo -e "${YELLOW} Add to /etc/hosts (optional):${NC}"
echo -e "   echo '127.0.0.1 cozyhosting.htb' | sudo tee -a /etc/hosts"
echo ""
echo -e "${YELLOW} Start scanning:${NC}"
echo -e "   nmap -sV -sC localhost"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW} To stop the lab:${NC}"
echo -e "   $COMPOSE_CMD down"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
