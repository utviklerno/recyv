import http.server
import socketserver
import json
import os
import re
from urllib.parse import urlparse, parse_qs

# Configuration
PORT = int(os.environ.get('PORT', 8080))
API_KEY = os.environ.get('API_KEY', 'secretpassword')

# In-memory store for disk data
# Structure: { "disk_id": { ... disk data ... } }
DISK_DATA = {}

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

        # Fallback to default (serving other static files if needed)
        # We limit to static folder if needed, but for simplicity:
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
            # Expecting data to have an 'id' field
            if 'id' not in data:
                self.send_error(400, "Missing 'id' field in JSON")
                return
            
            disk_id = data['id']
            DISK_DATA[disk_id] = data
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "success"}')
            return

        self.send_error(404, "Not Found")

def run():
    print(f"Starting server on port {PORT}")
    with socketserver.TCPServer(("", PORT), DiskMonHandler) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    run()
