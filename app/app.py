#!/usr/bin/env python3
"""
CozyHosting - Spring Boot Mimic Application
Replicates the HackTheBox CozyHosting machine for CTF lab purposes.
Flask app that mimics Spring Boot behavior (whitelabel errors, actuator, JSESSIONID).
"""

import os
import uuid
import time
import subprocess
from datetime import datetime
from flask import (
    Flask, request, redirect, url_for, render_template,
    make_response, jsonify, session
)

app = Flask(__name__)
app.secret_key = os.urandom(32)

# ─── Session Management (mimics Spring Boot HttpSession) ───
# Stores active sessions: {session_id: username}
active_sessions = {}

def generate_session_id():
    """Generate a Spring Boot-style session ID (32-char hex)."""
    return uuid.uuid4().hex.upper()

# Pre-seed kanderson's admin session (simulates logged-in admin)
KANDERSON_SESSION = generate_session_id()
active_sessions[KANDERSON_SESSION] = "kanderson"


def get_authenticated_user():
    """Check JSESSIONID cookie and return username if valid."""
    jsessionid = request.cookies.get('JSESSIONID')
    if jsessionid and jsessionid in active_sessions:
        return active_sessions[jsessionid]
    return None


# ─────────────── Public Routes ───────────────

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/services')
def services():
    return render_template('services.html')

@app.route('/pricing')
def pricing():
    return render_template('pricing.html')


# ─────────────── Authentication ───────────────

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username', '')
        password = request.form.get('password', '')

        # Always fail login — the intended path is session hijacking
        error = "Invalid username or password!"
        resp = make_response(render_template('login.html', error=error))
        return resp

    # Check if already authenticated
    user = get_authenticated_user()
    if user:
        return redirect('/admin')

    return render_template('login.html')

@app.route('/logout')
def logout():
    jsessionid = request.cookies.get('JSESSIONID')
    if jsessionid and jsessionid in active_sessions:
        # Don't actually remove kanderson's session (keep it for the lab)
        if active_sessions.get(jsessionid) != 'kanderson':
            del active_sessions[jsessionid]
    resp = make_response(redirect('/'))
    resp.delete_cookie('JSESSIONID')
    return resp


# ─────────────── Admin Dashboard ───────────────

@app.route('/admin')
def admin():
    user = get_authenticated_user()
    if not user:
        return redirect('/login')
    return render_template('admin.html', username=user)


# ─────────────── Vulnerable SSH Execution ───────────────

@app.route('/executessh', methods=['POST'])
def execute_ssh():
    user = get_authenticated_user()
    if not user:
        return redirect('/login')

    hostname = request.form.get('host', '')
    username = request.form.get('username', '')

    # Input validation (blocks spaces but not other special chars — VULNERABLE!)
    if not hostname:
        return render_template('admin.html', username=user,
                             ssh_status="error",
                             ssh_message="Host field is required!")

    if not username:
        return render_template('admin.html', username=user,
                             ssh_status="error",
                             ssh_message="Username field is required!")

    if ' ' in hostname:
        return render_template('admin.html', username=user,
                             ssh_status="error",
                             ssh_message="Hostname can't contain whitespaces!")

    if ' ' in username:
        return render_template('admin.html', username=user,
                             ssh_status="error",
                             ssh_message="Username can't contain whitespaces!")

    # ╔═══════════════════════════════════════════════════════════════╗
    # ║  VULNERABLE: Command injection via unsanitized username      ║
    # ║  The username is concatenated directly into a shell command  ║
    # ╚═══════════════════════════════════════════════════════════════╝
    cmd = f"ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no {username}@{hostname}"

    try:
        # shell=True + executable='/bin/bash' ensures bash interprets the command
        # This enables /dev/tcp and makes ; work as command separator
        proc = subprocess.Popen(cmd, shell=True, executable='/bin/bash',
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            pass
        message = f"Host key verification failed for {hostname}."
    except Exception as e:
        message = str(e)

    return render_template('admin.html', username=user,
                         ssh_status="error",
                         ssh_message=message)


# ─────────────── Spring Boot Actuator Endpoints ───────────────

@app.route('/actuator')
def actuator():
    """Spring Boot Actuator root endpoint."""
    return jsonify({
        "_links": {
            "self": {"href": "/actuator", "templated": False},
            "sessions": {"href": "/actuator/sessions", "templated": False},
            "beans": {"href": "/actuator/beans", "templated": False},
            "health": {"href": "/actuator/health", "templated": False},
            "env": {"href": "/actuator/env", "templated": False},
            "mappings": {"href": "/actuator/mappings", "templated": False}
        }
    })

@app.route('/actuator/sessions')
def actuator_sessions():
    """
    VULNERABLE: Exposes active session cookies without authentication.
    This allows attackers to steal JSESSIONID values and hijack sessions.
    """
    return jsonify(active_sessions)

@app.route('/actuator/health')
def actuator_health():
    return jsonify({"status": "UP"})

@app.route('/actuator/env')
def actuator_env():
    return jsonify({
        "activeProfiles": [],
        "propertySources": [
            {"name": "server.ports", "properties": {"local.server.port": {"value": 8080}}},
            {"name": "servletContextInitParams", "properties": {}}
        ]
    })

@app.route('/actuator/beans')
def actuator_beans():
    return jsonify({
        "contexts": {
            "application": {
                "beans": {
                    "cloudHostingApplication": {
                        "aliases": [],
                        "scope": "singleton",
                        "type": "htb.cloudhosting.CloudHostingApplication",
                        "dependencies": []
                    }
                }
            }
        }
    })

@app.route('/actuator/mappings')
def actuator_mappings():
    return jsonify({
        "contexts": {
            "application": {
                "mappings": {
                    "dispatcherServlets": {
                        "dispatcherServlet": [
                            {"handler": "htb.cloudhosting.controller.IndexController#index()","predicate": "{GET [/]}"},
                            {"handler": "htb.cloudhosting.controller.AdminController#admin()","predicate": "{GET [/admin]}"},
                            {"handler": "htb.cloudhosting.controller.AdminController#executessh()","predicate": "{POST [/executessh]}"},
                            {"handler": "htb.cloudhosting.controller.LoginController#login()","predicate": "{GET [/login]}"}
                        ]
                    }
                }
            }
        }
    })


# ─────────────── Spring Boot Whitelabel Error Page ───────────────

@app.route('/error')
def error_page():
    """Explicit /error endpoint — Spring Boot default."""
    timestamp = datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "+00:00"
    return render_template('error.html',
                         status=999,
                         error="None",
                         message="No message available",
                         timestamp=timestamp,
                         path="/error"), 404

@app.errorhandler(404)
def not_found(e):
    """Return Spring Boot whitelabel error for unknown routes."""
    timestamp = datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "+00:00"
    return render_template('error.html',
                         status=404,
                         error="Not Found",
                         message="",
                         timestamp=timestamp,
                         path=request.path), 404

@app.errorhandler(500)
def internal_error(e):
    timestamp = datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "+00:00"
    return render_template('error.html',
                         status=500,
                         error="Internal Server Error",
                         message="Unexpected error",
                         timestamp=timestamp,
                         path=request.path), 500

@app.errorhandler(405)
def method_not_allowed(e):
    timestamp = datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "+00:00"
    return render_template('error.html',
                         status=405,
                         error="Method Not Allowed",
                         message="",
                         timestamp=timestamp,
                         path=request.path), 405


# ─────────────── Response Headers (mimic Spring Boot) ───────────────

@app.after_request
def add_spring_boot_headers(response):
    """Add headers that mimic Spring Boot / Java servlet responses."""
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-XSS-Protection'] = '0'
    response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'
    response.headers['X-Frame-Options'] = 'DENY'

    # Remove Flask/Python-identifying headers
    response.headers.pop('Server', None)

    # Set JSESSIONID cookie if not present (Spring Boot always does this)
    if 'JSESSIONID' not in request.cookies:
        visitor_session = generate_session_id()
        response.set_cookie('JSESSIONID', visitor_session,
                          httponly=True, samesite='Lax', path='/')

    return response


# ─────────────── Run ───────────────

if __name__ == '__main__':
    print("[*] CozyHosting Application Starting...")
    print(f"[*] kanderson session: {KANDERSON_SESSION}")
    app.run(host='0.0.0.0', port=8080, threaded=True)
