# 🔐 Secure FTP Server with vsftpd & TLS

> Production-grade FTP server implementation on Ubuntu, hardened with TLS encryption and tested via FileZilla. Built in a virtualized environment with full troubleshooting documentation.

![Status](https://img.shields.io/badge/status-completed-brightgreen)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-orange?logo=ubuntu)
![vsftpd](https://img.shields.io/badge/vsftpd-3.0.5-blue)
![TLS](https://img.shields.io/badge/TLS-enabled-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## 📋 Overview

This project implements a **secure FTP service** using `vsftpd` (Very Secure FTP Daemon) on Ubuntu Server, with **TLS/SSL encryption**, **chroot jail**, and **user whitelisting**. The server runs in an Oracle VirtualBox VM using bridged networking, with a Windows host running FileZilla as the FTP client.

The project goes beyond basic tutorial-following — it documents real-world troubleshooting of issues encountered during deployment, including service initialization failures, virtualization networking constraints, FTP passive-mode behavior, and TLS certificate generation.

## 🎯 Objectives

- ✅ Set up a secure FTP service on Ubuntu using vsftpd
- ✅ Configure dedicated FTP users with restricted directory access (chroot jail)
- ✅ Implement TLS/SSL encryption for all FTP transactions
- ✅ Successfully connect and transfer files using FileZilla with TLS
- ✅ Document troubleshooting steps for reproducibility
- ✅ Strengthen practical knowledge of Linux system administration, networking, and security

## 🛠️ Tech Stack

| Component        | Technology                          |
| ---------------- | ----------------------------------- |
| Operating System | Ubuntu Server 24.04 LTS             |
| FTP Daemon       | vsftpd 3.0.5                        |
| Encryption       | OpenSSL (TLSv1.2)                   |
| Firewall         | UFW (Uncomplicated Firewall)        |
| Virtualization   | Oracle VirtualBox (Bridged Adapter) |
| FTP Client       | FileZilla                           |
| Host OS          | Windows 11                          |

## 🏗️ Architecture

```
┌────────────────────────┐         ┌──────────────────────────────────┐
│   Windows 11 Host      │         │   Ubuntu VM (Bridged Adapter)    │
│                        │         │                                  │
│   ┌──────────────┐     │   LAN   │   ┌──────────────────────────┐   │
│   │  FileZilla   │◄────┼─────────┼──►│  vsftpd (TLS enabled)    │   │
│   │  FTP Client  │     │         │   │  Port 21 (control)       │   │
│   └──────────────┘     │         │   │  Port 40000-50000 (PASV) │   │
│                        │         │   └──────────────────────────┘   │
│   192.168.x.x          │         │   192.168.x(VM_IP)               │
└────────────────────────┘         └──────────────────────────────────┘
                                                  │
                                                  ▼
                                       ┌──────────────────┐
                                       │  /home/sammy/    │
                                       │     ftp/         │
                                       │       files/     │
                                       └──────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Ubuntu Server 24.04 (or compatible)
- Sudo access
- A FileZilla client on a remote machine

### Installation

```bash
# 1. Install vsftpd
sudo apt update
sudo apt install vsftpd
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.orig

# 2. Configure firewall
sudo ufw allow 20,21,990/tcp
sudo ufw allow 40000:50000/tcp
sudo ufw allow 21/tcp

# Verify (sudo ufw status verbose):
# 20,21,990/tcp    ALLOW IN  Anywhere
# 40000:50000/tcp  ALLOW IN  Anywhere
# 21/tcp           ALLOW IN  Anywhere

# 3. Create FTP user with chroot jail
sudo adduser sammy
sudo mkdir /home/sammy/ftp
sudo chown nobody:nogroup /home/sammy/ftp
sudo chmod a-w /home/sammy/ftp
sudo mkdir /home/sammy/ftp/files
sudo chown sammy:sammy /home/sammy/ftp/files

# 4. Configure vsftpd (see configs/vsftpd.conf)
sudo cp configs/vsftpd.conf /etc/vsftpd.conf

# 5. Generate self-signed SSL certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/vsftpd.pem \
  -out /etc/ssl/private/vsftpd.pem

# 6. Add user to allowed list and restart service
echo "sammy" | sudo tee /etc/vsftpd.userlist
sudo systemctl restart vsftpd
sudo systemctl status vsftpd
```

### FileZilla Client Configuration

| Setting        | Value                             |
| -------------- | --------------------------------- |
| Host           | `<server-ip>`                     |
| Port           | `21`                              |
| Protocol       | FTP - File Transfer Protocol      |
| **Encryption** | **Require explicit FTP over TLS** |
| Logon Type     | Ask for password                  |
| User           | `sammy`                           |

## 🐛 Challenges & Troubleshooting

This is the most valuable section — real issues encountered and how they were resolved.

### Issue 1: Service fails with `INVALIDARGUMENT`

**Symptom:** `vsftpd.service: Failed with result 'exit-code'`, status 2/INVALIDARGUMENT.

**Root cause:** Unrecognized configuration directive caused vsftpd to abort startup.

**Resolution:** Validated the config syntax by running the daemon directly:

```bash
sudo vsftpd /etc/vsftpd.conf
# Output: 500 OOPS: unrecognised variable in config file: userlist_file
```

Corrected the directive name and restarted.

---

### Issue 2: Connection refused on `internal ip`

**Symptom:** FileZilla on the Windows host could not reach the VM. Internal `ftp x.x.x.x` worked.

**Root cause:** VirtualBox NAT mode assigns the VM an internal-only IP that is not reachable from the host LAN.

**Resolution:** Switched the VM network adapter from **NAT** to **Bridged Adapter**. The VM received `your_server_ip` from the local DHCP and became directly reachable.

---

### Issue 3: WSAEADDRNOTAVAIL on data connection

**Symptom:** Login succeeded but directory listing failed with `WSAEADDRNOTAVAIL`.

**Root cause:** vsftpd advertised `0.0.0.0` as the passive-mode address because `pasv_address` was unset.

**Resolution:** Added the bridged IP to `/etc/vsftpd.conf`:

```
pasv_address=your_server_ip
pasv_min_port=40000
pasv_max_port=50000
```

---

### Issue 4: `530 Non-anonymous sessions must use encryption`

**Symptom:** Plain-text FTP clients rejected after enabling TLS.

**Root cause:** Expected behavior — `force_local_logins_ssl=YES` enforces encryption for all authenticated sessions.

**Resolution:** Switched to FileZilla configured with **Require explicit FTP over TLS**.

---

### Issue 5: Permission denied on local file write

**Symptom:** FileZilla error: `Could not open 'C:\Users\Default\Downloads\upload.txt' for writing`.

**Root cause:** Local site path was set to a Windows system template directory.

**Resolution:** Changed local site to actual user profile path (`C:\Users\<username>\Downloads\`).

> 📖 For all 6 challenges with full root-cause analysis, see the [full PDF report](docs/Secure_FTP_Server_Portfolio_Report.pdf).

## ✅ Testing & Verification

| Test                       | Expected | Result  |
| -------------------------- | -------- | ------- |
| Anonymous login            | Denied   | ✅ Pass |
| Non-whitelisted user       | Denied   | ✅ Pass |
| Valid user + TLS handshake | Success  | ✅ Pass |
| File download (GET)        | Success  | ✅ Pass |
| File upload (PUT)          | Success  | ✅ Pass |

## 💡 Key Learnings

- **FTP active vs passive mode** — passive mode requires explicit `pasv_address` and an open port range; easy to miss in virtualized setups
- **VirtualBox networking** — NAT is convenient for outbound traffic but invisible to the LAN; Bridged Adapter is correct when the VM serves clients
- **chroot jail security model** — vsftpd refuses to chroot into a writable directory (security feature, not a bug)
- **Systemd debugging workflow** — `systemctl status` → `journalctl -u <service>` → run daemon directly to surface config errors
- **Reading error messages literally** — several "FTP problems" turned out to be unrelated (Windows folder permissions, DHCP IPs, config typos)

## 🚧 Future Improvements

- [ ] Migrate to **SFTP** (single-port, fully encrypted, firewall-friendly)
- [ ] Replace self-signed certificate with **Let's Encrypt**
- [ ] Automate user provisioning with **Ansible** or shell scripts
- [ ] Centralized logging via **syslog/ELK stack**
- [ ] Add **fail2ban** for brute-force protection
- [ ] Cron-based automated backups to remote storage

## 📁 Repository Structure

```
secure-ftp-vsftpd/
├── README.md                          # This file
├── LICENSE                            # MIT License
├── docs/
│   └── Secure_FTP_Server_Portfolio_Report.pdf
├── configs/
│   ├── vsftpd.conf                    # Sanitized config (no real IPs/keys)
│   └── vsftpd.userlist
├── scripts/
│   └── setup-vsftpd.sh                # Automation helper
├── screenshots/
│   ├── 01-vsftpd-running.png
│   ├── 02-filezilla-tls-connected.png
│   └── 03-file-transfer-success.png
└── .gitignore
```

## 📄 Full Report

For a comprehensive write-up including architecture diagrams, complete configuration files, and detailed troubleshooting walkthroughs, see the [full portfolio report (PDF)](docs/Secure_FTP_Server_Portfolio_Report.pdf).

## 📚 References

- [vsftpd official documentation](https://security.appspot.com/vsftpd.html)
- [DigitalOcean: How To Set Up vsftpd for a User's Directory on Ubuntu 20.04](https://www.digitalocean.com/community/tutorials/how-to-set-up-vsftpd-for-a-user-s-directory-on-ubuntu-20-04)
- [OpenSSL Essentials](https://www.openssl.org/docs/)
- [FileZilla documentation](https://wiki.filezilla-project.org/)

## 📜 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Theresia Posumah**
Software Developer

- GitHub: [@yourusername](https://github.com/LearningNerdGirl)
- LinkedIn: [Your LinkedIn](https://www.linkedin.com/in/theresia-mutiara-p-742728201/)

---

⭐ If this project helped you, consider giving it a star!
