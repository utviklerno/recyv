# DiskMon

A simple, lightweight disk monitoring tool for Linux based on Docker and Python.

## Features
*   **Minimalist Server**: A tiny Docker container running a Python web server.
*   **Secure Transport**: Uses SSH with persistent keys to transfer data securely.
*   **Simple Client**: A bash script that uses `smartctl` to send disk health data.

## Server Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/utviklerno/recyv.git
    cd recyv
    ```

2.  Generate SSH Keys:
    ```bash
    ./genkeys.sh
    ```
    This will create a `keys` directory with server host keys and a client access key.
    **Note:** The content of `keys/client_key` is the private key you need for your clients.

3.  Configure and start the server:
    ```bash
    docker-compose up -d --build
    ```

The dashboard will be available at `http://localhost:8080`.

### Data Persistence
The server stores disk data in JSON format in the `./data` directory on the host machine.

## Client Installation

On the client machine (the host you want to monitor):

1.  **Run the installer via curl:**

    ```bash
    curl -sL https://raw.githubusercontent.com/utviklerno/recyv/main/client/install.sh | sudo bash
    ```

    The script will:
    1.  Install dependencies.
    2.  Ask for your **Server SSH Address** (e.g. `diskmon@192.168.1.50 -p 2222`).
    3.  Ask you to paste the **Client Private Key** (from `keys/client_key` on the server).
    4.  Configure the client script and cron job.

## API Usage

*   `GET /api/disks`: Get data for all disks.
*   `GET /api/disks/<id>`: Get data for a specific disk.
