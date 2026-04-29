# ═══════════════════════════════════════════════════════
# Multi-stage Docker build for CozyHosting CTF Lab
# Stage 1: Build Spring Boot application with Maven
# Stage 2: Runtime with all services
# ═══════════════════════════════════════════════════════

# ─── Stage 1: Maven Build ───
FROM maven:3.9-eclipse-temurin-17 AS builder

WORKDIR /build

# Copy pom.xml first for dependency caching
COPY springboot-app/pom.xml .
RUN mvn dependency:go-offline -B

# Copy source and build
COPY springboot-app/src ./src
RUN mvn clean package -DskipTests

# ─── Stage 2: Runtime ───
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install all required packages
RUN apt-get update && apt-get install -y \
    openjdk-17-jre-headless \
    nginx \
    python3 \
    python3-pip \
    postgresql \
    postgresql-client \
    openssh-server \
    sudo \
    curl \
    wget \
    zip \
    unzip \
    net-tools \
    iputils-ping \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies (for DB init script)
RUN pip3 install bcrypt psycopg2-binary

# ─── Create users ───
RUN useradd -m -s /bin/bash -u 1000 app
RUN useradd -m -s /bin/bash -u 1001 josh && \
    echo "josh:manchesterunited" | chpasswd
RUN mkdir -p /home/postgres

# ─── SSH Configuration ───
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "AllowUsers josh" >> /etc/ssh/sshd_config

# ─── Sudo privileges for josh (ssh as root - GTFOBins escalation) ───
RUN echo "josh ALL=(root) /usr/bin/ssh *" > /etc/sudoers.d/josh && \
    chmod 440 /etc/sudoers.d/josh

# ─── Root flag (written at runtime via entrypoint) ───

# ─── Nginx configuration ───
COPY nginx/default.conf /etc/nginx/sites-available/default

# ─── Copy Spring Boot JAR from builder ───
RUN mkdir -p /app
COPY --from=builder /build/target/cloudhosting-0.0.1.jar /app/cloudhosting-0.0.1.jar
RUN chmod 644 /app/cloudhosting-0.0.1.jar && chown root:root /app/cloudhosting-0.0.1.jar

# ─── Database initialization ───
# Copy with explicit verification
COPY db/init.sql /tmp/init.sql
COPY scripts/init_db.py /tmp/init_db.py
RUN chmod +x /tmp/init_db.py && \
    ls -la /tmp/init.sql /tmp/init_db.py 2>/dev/null || echo "Warning: init files may not be accessible"

# ─── Entrypoint ───
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ─── Labels for Kubernetes securityContext ───
# When deployed to Kubernetes, add these capabilities to the pod:
# securityContext:
#   capabilities:
#     add:
#       - SYS_PTRACE
#       - SYS_CHROOT      # sshd privsep chroots into /run/sshd
#       - CHOWN
#       - SETUID
#       - SETGID
#       - DAC_OVERRIDE
#       - FOWNER
#       - AUDIT_WRITE
#       - NET_BIND_SERVICE

EXPOSE 22 80

ENTRYPOINT ["/entrypoint.sh"]
