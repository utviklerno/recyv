import http.server
import socketserver
import json
import os
import re
from urllib.parse import urlparse

# Configuration
PORT = int(os.environ.get('PORT', 8080))
API_KEY = os.environ.get('API_KEY', 'secretpassword')
DATA_DIR = '/app/data'
DATA_FILE = os.path.join(DATA_DIR, 'disks.json')

# In-memory store for disk data
DISK_DATA = {}

def load_data():
    global DISK_DATA
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r') as f:
                DISK_DATA = json.load(f)
            print(f"Loaded {len(DISK_DATA)} records from {DATA_FILE}")
        except Exception as e:
            print(f"Error loading data: {e}")
            DISK_DATA = {}
    else:
        print("No existing data found. Starting fresh.")

def save_data():
    try:
        # Ensure directory exists
        os.makedirs(DATA_DIR, exist_ok=True)
        with open(DATA_FILE, 'w') as f:
            json.dump(DISK_DATA, f, indent=2)
    except Exception as e:
        print(f"Error saving data: {e}")

class DiskMonHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        path = parsed_path.path

        # Serve API: All disks
        if path == '/api/disks':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(DISK_DATA).encode())
            return

        # Serve API: Single disk
        # Pattern: /api/disks/<id>
        match = re.match(r'^/api/disks/(.+)$', path)
        if match:
            disk_id = match.group(1)
            if disk_id in DISK_DATA:
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(DISK_DATA[disk_id]).encode())
            else:
                self.send_error(404, "Disk not found")
            return

        # Serve Static Page
        if path == '/' or path == '/index.html':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            try:
                with open('static/index.html', 'rb') as f:
                    self.wfile.write(f.read())
            except FileNotFoundError:
                self.wfile.write(b"Index file not found")
            return

        self.send_error(404, "Not Found")

    def do_POST(self):
        parsed_path = urlparse(self.path)
        path = parsed_path.path

        if path == '/api/upload':
            # Auth Check
            auth_header = self.headers.get('X-API-Key')
            if auth_header != API_KEY:
                self.send_error(403, "Unauthorized")
                return

            # Read Body
            try:
                content_length = int(self.headers.get('Content-Length', 0))
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode('utf-8'))
            except Exception as e:
                self.send_error(400, f"Bad Request: {str(e)}")
                return

            # Update Data
            if 'id' not in data:
                self.send_error(400, "Missing 'id' field in JSON")
                return
            
            disk_id = data['id']
            DISK_DATA[disk_id] = data
            
            # Persist data
            save_data()
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "success"}')
            return

        self.send_error(404, "Not Found")

def run():
    load_data()
    print(f"Starting server on port {PORT}")
    with socketserver.TCPServer(("", PORT), DiskMonHandler) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    run()
