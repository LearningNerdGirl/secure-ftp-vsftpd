#!/bin/bash
# setup-vsftpd.sh
# Automated vsftpd setup script with TLS encryption
# Usage: sudo ./setup-vsftpd.sh <username> <server_ip>

set -e

# === Validate input ===
if [ "$#" -ne 2 ]; then
    echo "Usage: sudo $0 <ftp_username> <server_ip>"
    echo "Example: sudo $0 sammy 192.168.18.117"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

FTP_USER=$1
SERVER_IP=$2

echo "🚀 Starting vsftpd setup for user '$FTP_USER' on $SERVER_IP"

# === Step 1: Install vsftpd ===
echo "📦 Installing vsftpd..."
apt update -qq
apt install -y vsftpd openssl

# === Step 2: Backup original config ===
if [ ! -f /etc/vsftpd.conf.orig ]; then
    cp /etc/vsftpd.conf /etc/vsftpd.conf.orig
    echo "✅ Original config backed up to /etc/vsftpd.conf.orig"
fi

# === Step 3: Configure firewall ===
echo "🔥 Configuring firewall..."
ufw allow 20,21,990/tcp
ufw allow 40000:50000/tcp

# === Step 4: Create FTP user ===
if id "$FTP_USER" &>/dev/null; then
    echo "ℹ️  User '$FTP_USER' already exists"
else
    adduser --disabled-password --gecos "" "$FTP_USER"
    echo "Please set a password for $FTP_USER:"
    passwd "$FTP_USER"
fi

# === Step 5: Set up directory structure ===
echo "📂 Setting up directory structure..."
mkdir -p /home/$FTP_USER/ftp/files
chown nobody:nogroup /home/$FTP_USER/ftp
chmod a-w /home/$FTP_USER/ftp
chown $FTP_USER:$FTP_USER /home/$FTP_USER/ftp/files

# === Step 6: Create test file ===
echo "vsftpd test file - setup successful" > /home/$FTP_USER/ftp/files/test.txt
chown $FTP_USER:$FTP_USER /home/$FTP_USER/ftp/files/test.txt

# === Step 7: Generate SSL certificate ===
echo "🔐 Generating SSL certificate..."
if [ ! -f /etc/ssl/private/vsftpd.pem ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/vsftpd.pem \
        -out /etc/ssl/private/vsftpd.pem \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Personal/CN=$SERVER_IP"
    echo "✅ SSL certificate created"
else
    echo "ℹ️  SSL certificate already exists"
fi

# === Step 8: Write vsftpd.conf ===
echo "⚙️  Writing vsftpd.conf..."
cat > /etc/vsftpd.conf <<EOF
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
chroot_local_user=YES
allow_writeable_chroot=NO
user_sub_token=\$USER
local_root=/home/\$USER/ftp
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
pasv_address=$SERVER_IP
rsa_cert_file=/etc/ssl/private/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem
ssl_enable=YES
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
EOF

# === Step 9: Add user to whitelist ===
echo "$FTP_USER" > /etc/vsftpd.userlist
echo "✅ Added $FTP_USER to /etc/vsftpd.userlist"

# === Step 10: Restart service ===
echo "🔄 Restarting vsftpd..."
systemctl restart vsftpd
systemctl enable vsftpd

# === Verify ===
sleep 2
if systemctl is-active --quiet vsftpd; then
    echo ""
    echo "✅ vsftpd is running successfully!"
    echo ""
    echo "📋 Connection Details:"
    echo "   Host:       $SERVER_IP"
    echo "   Port:       21"
    echo "   Encryption: Require explicit FTP over TLS"
    echo "   User:       $FTP_USER"
    echo ""
    echo "🎉 Setup complete!"
else
    echo "❌ vsftpd failed to start. Check logs with: journalctl -u vsftpd"
    exit 1
fi
