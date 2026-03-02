#!/bin/bash
# ═══════════════════════════════════════════════════════
# Create fake Spring Boot JAR file at /app/cloudhosting-0.0.1.jar
# This JAR contains the PostgreSQL credentials that the attacker
# will discover during post-exploitation.
# ═══════════════════════════════════════════════════════

set -e

JAR_DIR="/tmp/jarcontents"
APP_DIR="/app"

# Create directory structure matching a real Spring Boot JAR
mkdir -p "${JAR_DIR}/BOOT-INF/classes"
mkdir -p "${JAR_DIR}/BOOT-INF/lib"
mkdir -p "${JAR_DIR}/META-INF"
mkdir -p "${JAR_DIR}/org/springframework/boot/loader"
mkdir -p "${APP_DIR}"

# ─── application.properties (contains the PostgreSQL credentials!) ───
cat > "${JAR_DIR}/BOOT-INF/classes/application.properties" << 'PROPERTIES'
server.address=127.0.0.1
server.servlet.session.timeout=5m
management.endpoints.web.exposure.include=health,beans,env,sessions,mappings
management.endpoint.sessions.enabled=true
spring.datasource.driver-class-name=org.postgresql.Driver
spring.datasource.url=jdbc:postgresql://localhost:5432/cozyhosting
spring.datasource.username=postgres
spring.datasource.password=Vg&nvzAQ7XxR
spring.jpa.database-platform=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.hibernate.ddl-auto=none
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
spring.mvc.hiddenmethod.filter.enabled=true
PROPERTIES

# ─── MANIFEST.MF ───
cat > "${JAR_DIR}/META-INF/MANIFEST.MF" << 'MANIFEST'
Manifest-Version: 1.0
Created-By: Maven JAR Plugin 3.3.0
Build-Jdk-Spec: 17
Implementation-Title: cloudhosting
Implementation-Version: 0.0.1
Main-Class: org.springframework.boot.loader.JarLauncher
Start-Class: htb.cloudhosting.CloudHostingApplication
Spring-Boot-Version: 3.0.2
Spring-Boot-Classes: BOOT-INF/classes/
Spring-Boot-Lib: BOOT-INF/lib/
MANIFEST

# ─── Fake Spring Boot loader class (empty file, just for structure) ───
touch "${JAR_DIR}/org/springframework/boot/loader/JarLauncher.class"

# ─── Fake application class ───
mkdir -p "${JAR_DIR}/BOOT-INF/classes/htb/cloudhosting"
touch "${JAR_DIR}/BOOT-INF/classes/htb/cloudhosting/CloudHostingApplication.class"

# ─── Fake scheduled task class ───
mkdir -p "${JAR_DIR}/BOOT-INF/classes/htb/cloudhosting/scheduled"
touch "${JAR_DIR}/BOOT-INF/classes/htb/cloudhosting/scheduled/FakeUser.class"

# ─── Additional config files for realism ───
mkdir -p "${JAR_DIR}/BOOT-INF/classes/templates"
cat > "${JAR_DIR}/BOOT-INF/classes/templates/404.html" << 'HTML'
<!DOCTYPE html>
<html>
<head><title>Error</title></head>
<body>
<h1>Whitelabel Error Page</h1>
</body>
</html>
HTML

# ─── Create the JAR (which is just a ZIP file) ───
cd "${JAR_DIR}"
zip -r "${APP_DIR}/cloudhosting-0.0.1.jar" . > /dev/null 2>&1

# Set permissions (readable by app user for reverse shell exfiltration)
chmod 644 "${APP_DIR}/cloudhosting-0.0.1.jar"
chown root:root "${APP_DIR}/cloudhosting-0.0.1.jar"

# Cleanup
rm -rf "${JAR_DIR}"

echo "[+] Created /app/cloudhosting-0.0.1.jar"
