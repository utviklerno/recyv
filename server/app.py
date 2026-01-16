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
DISK_DATA = {
    "machines": {}
}

# Lock for thread safety
DATA_LOCK = threading.Lock()

def load_data():
    global DISK_DATA
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, 'r') as f:
                loaded_data = json.load(f)
            
            if "machines" in loaded_data:
                DISK_DATA = loaded_data
            else:
                print("Migrating legacy data structure (resetting)...")
                DISK_DATA = { "machines": {} }
            
            print(f"Loaded {len(DISK_DATA.get('machines', {}))} machines from {DATA_FILE}")
        except Exception as e:
            print(f"Error loading data: {e}")
            DISK_DATA = { "machines": {} }
    else:
        print("No existing data found. Starting fresh.")

def save_data():
    try:
        os.makedirs(DATA_DIR, exist_ok=True)
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
            files = glob.glob(os.path.join(INBOX_DIR, '*.json'))
            
            if not files:
                time.sleep(1)
                continue
            
            files.sort()
            changes_made = False
            
            with DATA_LOCK:
                for file_path in files:
                    try:
                        with open(file_path, 'r') as f:
                            data = json.load(f)
                        
                        machine_id = data.get('machine_id')
                        msg_type = data.get('type')
                        
                        if machine_id:
                            # Ensure machine entry exists
                            if machine_id not in DISK_DATA['machines']:
                                DISK_DATA['machines'][machine_id] = { "info": {}, "disks": {} }
                            
                            machine_node = DISK_DATA['machines'][machine_id]
                            
                            # Always update last_seen for any activity from this machine
                            machine_node['info']['last_seen'] = int(time.time())
                            changes_made = True
                            
                            if msg_type == 'disk':
                                device = data.get('device')
                                if device:
                                    machine_node['disks'][device] = data.get('smart_data')
                                    
                            elif msg_type == 'system_info':
                                new_info = data.get('info', {})
                                machine_node['info'].update(new_info)
                        
                        os.remove(file_path)
                        
                    except Exception as e:
                        print(f"Error processing file {file_path}: {e}")
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

        if path == '/api/disks':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            with DATA_LOCK:
                self.wfile.write(json.dumps(DISK_DATA).encode())
            return

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

        if path == '/api/ping':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "pong"}')
            return

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
        self.send_error(404, "Not Found")

def run():
    os.makedirs(INBOX_DIR, exist_ok=True)
    load_data()
    processor_thread = threading.Thread(target=process_inbox, daemon=True)
    processor_thread.start()
    
    print("-" * 50)
    print(f"Recyv Server Running")
    print("-" * 50)
    print(f"Port:       {PORT}")
    print(f"Mode:       SSH Inbox Processing (Grouped by Machine)")
    print("-" * 50)
    
    with socketserver.TCPServer(("", PORT), RecyvHandler) as httpd:
        httpd.serve_forever()

if __name__ == "__main__":
    run()
