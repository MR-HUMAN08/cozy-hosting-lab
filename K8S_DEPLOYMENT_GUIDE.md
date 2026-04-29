# Kubernetes Deployment Troubleshooting

## Problem: `init_db.py` File Not Found Error

```
python3: can't open file '/tmp/init_db.py': [Errno 2] No such file or directory
```

### Root Causes

1. **Build Context Issue**: Files not copied from build context
2. **Missing Capabilities**: Container lacks necessary Linux capabilities for proper initialization
3. **Permission Issues**: File exists but cannot be accessed/executed

### Solutions

## 1. Update Dockerfile (✓ Already Done)

The Dockerfile now includes:
- Explicit file verification during build
- Proper file permissions (`chmod +x`)
- Labels documenting required capabilities

```dockerfile
COPY db/init.sql /tmp/init.sql
COPY scripts/init_db.py /tmp/init_db.py
RUN chmod +x /tmp/init_db.py && \
    ls -la /tmp/init.sql /tmp/init_db.py
```

## 2. Add Linux Capabilities to Kubernetes Pod (REQUIRED)

When deploying to Kubernetes, add `securityContext` with these capabilities:

```yaml
securityContext:
  capabilities:
    add:
      - SYS_PTRACE           # Process tracing/debugging
      - SYS_CHROOT           # ⭐ CRITICAL for sshd privilege separation
      - CHOWN                # File ownership changes
      - SETUID               # User ID switching (su, sudo)
      - SETGID               # Group ID switching
      - DAC_OVERRIDE         # Bypass file permissions
      - FOWNER               # Change file owner/perms
      - AUDIT_WRITE          # Audit log writing
      - NET_BIND_SERVICE     # Bind to ports < 1024
```

### Why SYS_CHROOT is Critical

- OpenSSH uses privilege separation (privsep) for security
- sshd chroots into `/run/sshd` to isolate authentication processes
- Without `SYS_CHROOT` capability, SSH initialization fails
- This prevents the container from starting properly

## 3. Verify Build Context

Ensure your build includes these directories:

```
cozy-hosting-lab-main/
├── db/
│   └── init.sql          ← Required
├── scripts/
│   ├── init_db.py        ← Required
│   └── entrypoint.sh     ← Required
├── springboot-app/
├── nginx/
├── Dockerfile            ← Copies these files
└── docker-compose.yml
```

## 4. Enhanced Entrypoint (✓ Already Done)

The entrypoint now verifies files exist:

```bash
# Verify required files exist
if [ ! -f /tmp/init.sql ]; then
    echo "[!] ERROR: /tmp/init.sql not found"
    exit 1
fi

if [ ! -f /tmp/init_db.py ]; then
    echo "[!] ERROR: /tmp/init_db.py not found"
    exit 1
fi
```

## 5. Deployment Steps

### Build the Docker image:
```bash
docker build -t cozyhosting:latest .
```

### Push to your registry:
```bash
docker tag cozyhosting:latest your-registry/cozyhosting:latest
docker push your-registry/cozyhosting:latest
```

### Deploy to Kubernetes:
```bash
kubectl apply -f k8s-deployment.yaml -n letushack-user-5
```

### Verify deployment:
```bash
kubectl get pods -n letushack-user-5
kubectl logs <pod-name> -n letushack-user-5
```

## 6. Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| `init_db.py: No such file` | Missing COPY in Dockerfile | Rebuild image with COPY commands |
| `Permission denied` | Missing SETUID/SETGID caps | Add to securityContext.capabilities.add |
| SSH connection refused | Missing SYS_CHROOT capability | Add SYS_CHROOT to capabilities |
| PostgreSQL won't start | permiss issues | Add CHOWN, DAC_OVERRIDE capabilities |
| Port binding errors | Missing NET_BIND_SERVICE | Add NET_BIND_SERVICE capability |

## 7. Debugging

### Check if files were copied:
```bash
kubectl exec -it <pod-name> -n letushack-user-5 -- ls -la /tmp/
```

### Verify capabilities are applied:
```bash
kubectl exec -it <pod-name> -n letushack-user-5 -- getcap /bin/bash
```

### Check container logs for errors:
```bash
kubectl logs <pod-name> -n letushack-user-5 --tail=100
```

### Enter the container:
```bash
kubectl exec -it <pod-name> -n letushack-user-5 -- /bin/bash
```

Then check:
```bash
ls -la /tmp/init*.{sql,py}
python3 --version
file /tmp/init_db.py
```

## Summary

Your fixes:
1. ✅ **Dockerfile**: Added file verification and explicit `chmod +x`
2. ✅ **Entrypoint**: Added pre-flight checks for missing files
3. ✅ **Kubernetes YAML**: Provided with all required capabilities
4. ✅ **Documentation**: This troubleshooting guide

**Next steps:**
1. Rebuild Docker image with updated Dockerfile
2. Push to your registry
3. Update Kubernetes deployment with k8s-deployment.yaml
4. Verify logs show `[+] All required files verified` and `[+] Database initialized successfully`
