import http.server
import socketserver
import json
import os
import re
import time
import threading
import glob
from urllib.parse import urlparse

# Configuration
PORT = int(os.environ.get('PORT', 8080))
DATA_DIR = '/app/data'
DATA_FILE = os.path.join(DATA_DIR, 'disks.json')
INBOX_DIR = os.path.join(DATA_DIR, 'inbox')

# In-memory store for disk data
# Structure: { "logs": { "hostname": timestamp }, "disks": { "disk_id": data } }
DISK_DATA = {
    "logs": {},
    "disks": {}
}

# Lock for thread safety
DATA_LOCK = threading.Lock()

def load_data():
    global DISK_DATA
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r') as f:
                loaded_data = json.load(f)
            
            if "disks" in loaded_data and "logs" in loaded_data:
                DISK_DATA = loaded_data
            else:
                print("Migrating legacy data structure...")
                DISK_DATA = {
                    "logs": {},
                    "disks": loaded_data
                }
            
            print(f"Loaded {len(DISK_DATA.get('disks', {}))} disks from {DATA_FILE}")
        except Exception as e:
            print(f"Error loading data: {e}")
            DISK_DATA = { "logs": {}, "disks": {} }
    else:
        print("No existing data found. Starting fresh.")

def save_data():
    try:
        # Ensure directory exists
        os.makedirs(DATA_DIR, exist_ok=True)
        # Write to temp file first then rename for atomic write
        temp_file = DATA_FILE + '.tmp'
        with open(temp_file, 'w') as f:
            json.dump(DISK_DATA, f, indent=2)
        os.replace(temp_file, DATA_FILE)
    except Exception as e:
        print(f"Error saving data: {e}")

def process_inbox():
    """Background thread to process files from inbox"""
    print("Inbox processor started...")
    while True:
        try:
            # Find all json files
            files = glob.glob(os.path.join(INBOX_DIR, '*.json'))
            
            if not files:
                time.sleep(1)
                continue
            
            # Sort by filename (timestamp) to process in order
            files.sort()
            
            changes_made = False
            
            with DATA_LOCK:
                for file_path in files:
                    try:
                        with open(file_path, 'r') as f:
                            data = json.load(f)
                        
                        # Validate basic structure
                        if 'id' in data:
                            disk_id = data['id']
                            hostname = data.get('hostname')
                            
                            # Update Memory Store
                            DISK_DATA['disks'][disk_id] = data
                            if hostname:
                                DISK_DATA['logs'][hostname] = int(time.time())
                            
                            changes_made = True
                        
                        # Delete processed file
                        os.remove(file_path)
                        
                    except Exception as e:
                        print(f"Error processing file {file_path}: {e}")
                        # Move bad file to 'error' folder or delete? 
                        # For now, delete to prevent clogging
                        try:
                            os.remove(file_path)
                        except:
                            pass

                if changes_made:
                    save_data()
                    print(f"Processed {len(files)} updates. Data saved.")
                    
        except Exception as e:
            print(f"Inbox processor error: {e}")
            time.sleep(5)

class RecyvHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        path = parsed_path.path

        # Serve API: All Data (Root Object)
        if path == '/api/disks':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            with DATA_LOCK:
                self.wfile.write(json.dumps(DISK_DATA).encode())
            return

        # Serve API: Single disk
        if path.startswith('/api/disks/'):
            match = re.match(r'^/api/disks/(.+)$', path)
            if match:
                disk_id = match.group(1)
                with DATA_LOCK:
                    disks = DISK_DATA.get('disks', {})
                    if disk_id in disks:
                        self.send_response(200)
                        self.send_header('Content-type', 'application/json')
                        self.end_headers()
                        self.wfile.write(json.dumps(disks[disk_id]).encode())
                        return
                self.send_error(404, "Disk not found")
                return

        # Serve API: Ping (Test Connection)
        # Note: We removed the API Key check here since uploads are now SSH-only.
        # This endpoint is just for client connectivity tests.
        if path == '/api/ping':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "pong"}')
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

def run():
    # Ensure directories
    os.makedirs(INBOX_DIR, exist_ok=True)
    
    load_data()
    
    # Start Background Processor
    processor_thread = threading.Thread(target=process_inbox, daemon=True)
    processor_thread.start()
    
    print("-" * 50)
    print(f"Recyv Server Running")
    print("-" * 50)
    print(f"Port:       {PORT}")
    print(f"Mode:       SSH Inbox Processing")
    print("-" * 50)
    
    # Start Web Server
    with socketserver.TCPServer(("", PORT), RecyvHandler) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    run()
