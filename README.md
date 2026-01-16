# DiskMon

A simple, lightweight disk monitoring tool for Linux based on Docker and Python.

## Features
*   **Minimalist Server**: A tiny Docker container running a Python web server.
*   **Simple Client**: A bash script that uses `smartctl` to send disk health data.
*   **Zero-dependency Client**: Uses standard tools (`curl`, `smartmontools`, `python3`).

## Server Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/utviklerno/recyv.git
    cd recyv
    ```

2.  Configure and start the server:
    ```bash
    # Set your desired port and secret key
    export PORT=8080
    export API_KEY="your-secret-password"
    
    docker-compose up -d --build
    ```

The dashboard will be available at `http://localhost:8080`.

### Data Persistence
The server stores disk data in JSON format in the `./data` directory on the host machine. This ensures data is preserved even if the container is recreated.

3.  **Client Installation**
    
    On the client machine (the host you want to monitor):
    ```bash
    curl -sL https://raw.githubusercontent.com/utviklerno/recyv/main/client/install.sh | sudo bash
    ```
    
    The script will:
    1.  Install dependencies.
    2.  Ask for your **Server URL** and **API Key**.
    3.  Test the connection to the server.
    4.  Configure the client script.
    5.  Automatically set up a cron job to monitor all drives every minute.


## API Usage

*   `GET /api/disks`: Get data for all disks.
*   `GET /api/disks/<id>`: Get data for a specific disk.
*   `POST /api/upload`: Upload SMART data (requires `X-API-Key` header).
