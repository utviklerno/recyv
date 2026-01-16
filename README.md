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

## Client Installation

To install the monitoring client on a Linux host:

1.  **Run the installer via curl:**

    ```bash
    curl -sL https://raw.githubusercontent.com/utviklerno/recyv/main/client/install.sh | sudo bash
    ```

    *Note: Replace `utviklerno` with your actual GitHub username.*

2.  **Configure the client:**
    
    Edit the installed script to point to your server:
    ```bash
    sudo nano /root/diskmon.sh
    ```
    Update `API_URL` and `API_KEY`.

3.  **Enable Monitoring:**
    
    Add a cron job to run the check every minute:
    ```bash
    sudo crontab -e
    ```
    Add the following line (adjusting for your specific drives):
    ```cron
    * * * * * /root/diskmon.sh /dev/sda /dev/sdb
    ```

## API Usage

*   `GET /api/disks`: Get data for all disks.
*   `GET /api/disks/<id>`: Get data for a specific disk.
*   `POST /api/upload`: Upload SMART data (requires `X-API-Key` header).
