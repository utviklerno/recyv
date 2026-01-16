# Recyv Disk Monitor

![Recyv Dashboard](recyvdash.png)

**Recyv** is a minimalist, secure, and resilient disk monitoring solution designed for home labs, server farms, and privacy-conscious users. It decouples data collection from data visualization using a unique SSH-based transport mechanism.

## Why is this solution "Cool"?

Most monitoring solutions (Prometheus, Zabbix, Datadog) requires heavy agents, complex firewalls, or exposed HTTP ports. **Recyv** takes a different approach:

1.  **Security First (SSH Transport)**: We don't expose any HTTP write endpoints. Data is transferred securely using SSH keys. If you can SSH into your server, you can monitor it.
2.  **"Dust Sucker" Architecture**: The server uses an asynchronous "Inbox" pattern. Clients drop JSON files via SSH, and a background processor "sucks them up." This means **zero data loss** during server restarts or network blips.
3.  **Zero-Dependency Client**: The client is a simple Bash script. It relies on standard tools installed on 99% of Linux systems: `ssh`, `smartctl`, `cron`, and `python3`. No binary blobs, no heavy services.
4.  **Resilient Identity**: Machines are identified by a combination of IP and Hostname, allowing you to monitor clusters where default hostnames (like `pve` or `ubuntu`) might overlap.
5.  ** NVMe & SATA Support**: Fully supports modern NVMe namespaces and legacy SATA drives, handling large SMART data payloads gracefully.

---

## Features

*   **Centralized Dashboard**: View CPU, RAM, Load Average, and Disk Health for all your machines in one place.
*   **Smart Health Logic**: Automatically detects Critical Warnings (NVMe), Reallocated Sectors (SATA), and High Temperatures.
*   **Offline Detection**: Visually warns you if a machine hasn't reported in over 3 minutes.
*   **Persistent Keys**: Auto-generates and persists SSH keys on the first run.
*   **Dockerized Server**: A lightweight Alpine-based container (~50MB).

---

## Installation

### 1. Server Setup (Docker)

1.  Clone the repository:
    ```bash
    git clone https://github.com/utviklerno/recyv.git
    cd recyv
    ```

2.  Start the server:
    ```bash
    docker-compose up -d --build
    ```

3.  **Get your Client Key**:
    The server auto-generates a secure SSH key pair on startup. You need the **Private Key** to install clients. View it with:
    ```bash
    docker-compose logs
    ```
    *Copy the block starting with `-----BEGIN OPENSSH PRIVATE KEY-----`.*

The dashboard is now available at `http://localhost:8080`.

### 2. Client Setup (Linux Host)

On the machine you want to monitor (requires root):

1.  Run the installer:
    ```bash
    curl -sL https://raw.githubusercontent.com/utviklerno/recyv/main/client/install.sh | sudo bash
    ```

2.  Follow the prompts:
    *   **SSH Target**: Enter your server's address (e.g., `recyv@192.168.1.50 -p 2222`).
    *   **Private Key**: Paste the key you copied from the server logs.

3.  **Done!** The installer sets up a cron job that runs every minute.

---

## Roadmap & Todos

We are actively working on making Recyv even better. Here is what's coming next:

### 🚀 Upcoming Features
- [ ] **Alerting Engine**:
    - [ ] Webhooks (Slack, Discord, Teams).
    - [ ] Email Notifications (SMTP).
    - [ ] SMS Alerts (Twilio/Gateway).
- [ ] **Cross-Platform Support**:
    - [ ] **Windows Client**: PowerShell-based collector sending data via OpenSSH.
    - [ ] **macOS Client**: Zsh/Bash collector for Mac Mini/Studio labs.
- [ ] **Historical Data**: Simple graphs for temperature and storage usage over time.
- [ ] **Auth**: Optional Basic Auth for the web dashboard.

### 🛠 Improvements
- [ ] Configurable thresholds for temperature warnings (currently > 55°C).
- [ ] Dark Mode toggle.
- [ ] Compact list view for clusters with 50+ drives.

---

## Troubleshooting

*   **Client Connection**: If the client fails to connect, check the logs on the client:
    ```bash
    /root/recyv.sh
    ```
*   **Permissions**: Ensure the `./data` and `./keys` folders on the server are writable by the Docker container.
*   **Firewall**: Ensure Port `2222` (SSH) and `8080` (Web) are allowed on your server.

## License

MIT License. Feel free to fork, modify, and use in your own projects.
