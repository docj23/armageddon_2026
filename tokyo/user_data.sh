#!/bin/bash
# User data script for EC2 instance
# This runs ONCE when the instance first boots

# Update system packages
dnf update -y

# Install Python 3 and pip
dnf install -y python3-pip

# Install application dependencies
pip3 install flask pymysql boto3

# Create application directory
mkdir -p /opt/rdsapp

# Create the Flask application
cat >/opt/rdsapp/app.py <<'PYTHON_APP'
import json
import os
import boto3
import pymysql
from flask import Flask, request

REGION = os.environ.get("AWS_REGION", "ap-northeast-1")
SECRET_ID = os.environ.get("SECRET_ID", "shinjuku/rds/mysql")

secrets = boto3.client("secretsmanager", region_name=REGION)

def get_db_creds():
    resp = secrets.get_secret_value(SecretId=SECRET_ID)
    s = json.loads(resp["SecretString"])
    return s

def get_conn():
    c = get_db_creds()
    host = c["host"]
    user = c["username"]
    password = c["password"]
    port = int(c.get("port", 3306))
    db = c.get("dbname", "labdb")
    return pymysql.connect(
        host=host,
        user=user,
        password=password,
        port=port,
        database=db,
        autocommit=True
    )

app = Flask(__name__)

@app.route("/")
def home():
    return """
    <h2>EC2 → RDS Notes App</h2>
    <p>GET /init - Initialize database</p>
    <p>POST /add?note=hello - Add a note</p>
    <p>GET /list - List all notes</p>
    """

@app.route("/init")
def init_db():
    c = get_db_creds()
    host = c["host"]
    user = c["username"]
    password = c["password"]
    port = int(c.get("port", 3306))
    
    conn = pymysql.connect(
        host=host,
        user=user,
        password=password,
        port=port,
        autocommit=True
    )
    cur = conn.cursor()
    cur.execute("CREATE DATABASE IF NOT EXISTS labdb;")
    cur.execute("USE labdb;")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS notes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            note VARCHAR(255) NOT NULL
        );
    """)
    cur.close()
    conn.close()
    return "Database initialized successfully."

@app.route("/add", methods=["POST", "GET"])
def add_note():
    note = request.args.get("note", "").strip()
    if not note:
        return "Missing note parameter. Try: /add?note=hello", 400
    
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("INSERT INTO notes(note) VALUES(%s);", (note,))
    cur.close()
    conn.close()
    return f"Note added: {note}"

@app.route("/list")
def list_notes():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    
    out = "<h3>Notes</h3><ul>"
    for r in rows:
        out += f"<li>{r[0]}: {r[1]}</li>"
    out += "</ul>"
    return out

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PYTHON_APP

# Create systemd service
cat >/etc/systemd/system/rdsapp.service <<'SERVICE_FILE'
[Unit]
Description=EC2 to RDS Notes App
After=network.target

[Service]
WorkingDirectory=/opt/rdsapp
Environment=SECRET_ID=shinjuku/rds/mysql
Environment=AWS_REGION=ap-northeast-1
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE_FILE

# Start the application service
systemctl daemon-reload
systemctl enable rdsapp
systemctl start rdsapp