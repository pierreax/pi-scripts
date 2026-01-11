#!/bin/bash
# Raspberry Pi Disaster Recovery Backup Script
# Backs up everything needed to recover from SD card failure
# Backs up to OneDrive using existing rclone configuration

# Configuration
BACKUP_DATE=$(date +%Y-%m-%d)
ONEDRIVE_BACKUP_ROOT="OneDrive:Documents/Pi-Backup"
LOG_FILE="/home/pierre/backup-logs/disaster-recovery-backup.log"
RCLONE_CONFIG="/home/pierre/.config/rclone/rclone.conf"

# Create log directory
mkdir -p /home/pierre/backup-logs

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=========================================="
log "Starting Disaster Recovery Backup"
log "=========================================="

# 1. Backup entire home directory (excluding cache and temp files)
log "Backing up home directory..."
log "Note: Excluding .git, node_modules, and browser cache (restored via git/npm)"
/usr/bin/rclone sync /home/pierre "$ONEDRIVE_BACKUP_ROOT/home-pierre" \
    --exclude ".cache/**" \
    --exclude ".local/share/Trash/**" \
    --exclude "*.tmp" \
    --exclude "OneDrive/**" \
    --exclude "backup-logs/**" \
    --exclude "ha_config_backup*/**" \
    --exclude ".git/**" \
    --exclude "**/.git/**" \
    --exclude "node_modules/**" \
    --exclude "**/node_modules/**" \
    --exclude ".config/chromium/**" \
    --exclude ".config/google-chrome/**" \
    --exclude ".mozilla/**" \
    --exclude ".npm/**" \
    --exclude "__pycache__/**" \
    --exclude "**/__pycache__/**" \
    --exclude "*.pyc" \
    --exclude "mosquitto/**" \
    --exclude ".claude/statsig/**" \
    --log-file="$LOG_FILE" \
    --log-level INFO \
    --progress

if [ $? -eq 0 ]; then
    log "✓ Home directory backup completed"
else
    log "✗ Home directory backup failed"
fi

# 2. Backup Home Assistant config (main config only)
log "Backing up Home Assistant configuration..."

# Backup home assistant config from pi user (this is the main one - 236MB)
if [ -d "/home/pi/homeassistant_config" ]; then
    sudo /usr/bin/rclone sync /home/pi/homeassistant_config "$ONEDRIVE_BACKUP_ROOT/home-assistant" \
        --config="$RCLONE_CONFIG" \
        --log-file="$LOG_FILE" \
        --log-level INFO
    log "✓ Home Assistant config backed up"
else
    log "ℹ Home Assistant config not found, skipping"
fi

# 3. Backup Pi-hole config (Docker-based installation)
log "Backing up Pi-hole configuration..."
if docker ps --format '{{.Names}}' | grep -q "pihole"; then
    # Create temp directory for pihole backup
    PIHOLE_TEMP="/tmp/pihole-backup-$$"
    mkdir -p "$PIHOLE_TEMP"

    # Copy config from Docker container
    docker cp pihole:/etc/pihole "$PIHOLE_TEMP/" 2>/dev/null
    docker cp pihole:/etc/dnsmasq.d "$PIHOLE_TEMP/" 2>/dev/null

    # Sync to OneDrive
    /usr/bin/rclone sync "$PIHOLE_TEMP" "$ONEDRIVE_BACKUP_ROOT/pihole" \
        --log-file="$LOG_FILE" \
        --log-level INFO

    # Cleanup
    rm -rf "$PIHOLE_TEMP"
    log "✓ Pi-hole config backed up (from Docker container)"
else
    log "ℹ Pi-hole container not running, skipping"
fi

# 4. Backup host dnsmasq config (if exists outside Docker)
if [ -d "/etc/dnsmasq.d" ] && [ "$(ls -A /etc/dnsmasq.d 2>/dev/null)" ]; then
    sudo /usr/bin/rclone sync /etc/dnsmasq.d "$ONEDRIVE_BACKUP_ROOT/dnsmasq-host" \
        --config="$RCLONE_CONFIG" \
        --log-file="$LOG_FILE" \
        --log-level INFO
    log "✓ Host dnsmasq config backed up"
fi

# 5. Save list of installed packages
log "Saving list of installed packages..."
dpkg --get-selections > /tmp/installed-packages.txt
/usr/bin/rclone copy /tmp/installed-packages.txt "$ONEDRIVE_BACKUP_ROOT/system-info/" \
    --log-file="$LOG_FILE" \
    --log-level INFO
rm /tmp/installed-packages.txt
log "✓ Package list saved"

# 6. Backup crontab
log "Backing up crontab..."
crontab -l > /tmp/crontab-backup.txt 2>/dev/null
/usr/bin/rclone copy /tmp/crontab-backup.txt "$ONEDRIVE_BACKUP_ROOT/system-info/" \
    --log-file="$LOG_FILE" \
    --log-level INFO
rm /tmp/crontab-backup.txt
log "✓ Crontab backed up"

# 7. Save system information
log "Saving system information..."
{
    echo "=== System Info - $BACKUP_DATE ==="
    uname -a
    echo ""
    echo "=== Raspberry Pi Model ==="
    cat /proc/device-tree/model
    echo ""
    echo "=== OS Version ==="
    cat /etc/os-release
    echo ""
    echo "=== Disk Usage ==="
    df -h
    echo ""
    echo "=== Memory ==="
    free -h
    echo ""
    echo "=== Network Interfaces ==="
    ip addr
} > /tmp/system-info.txt

/usr/bin/rclone copy /tmp/system-info.txt "$ONEDRIVE_BACKUP_ROOT/system-info/" \
    --log-file="$LOG_FILE" \
    --log-level INFO
rm /tmp/system-info.txt
log "✓ System info saved"

# 8. Create recovery instructions
log "Creating recovery instructions..."
cat > /tmp/RECOVERY-INSTRUCTIONS.md << 'EOF'
# Disaster Recovery Instructions

## Quick Recovery Steps

If your Raspberry Pi SD card fails, follow these steps:

### 1. Flash New SD Card
- Download Raspberry Pi OS
- Flash to new SD card using Raspberry Pi Imager
- Boot the Pi

### 2. Install Rclone
```bash
sudo apt update
sudo apt install rclone -y
```

### 3. Configure Rclone for OneDrive
```bash
rclone config
# Choose: n (new remote)
# Name: OneDrive
# Type: onedrive
# Follow authentication prompts
```

### 4. Restore Your Files
```bash
# Restore home directory
rclone sync OneDrive:Documents/Pi-Backup/home-pierre /home/pierre

# Restore Home Assistant
sudo rclone sync OneDrive:Documents/Pi-Backup/home-assistant /home/pi/homeassistant_config

# Restore Pi-hole (Docker-based - restore after container is created)
# First install Docker and create Pi-hole container, then:
docker stop pihole
docker cp ~/restore/pihole/pihole pihole:/etc/
docker cp ~/restore/pihole/dnsmasq.d pihole:/etc/
docker start pihole

# Restore crontab
rclone copy OneDrive:Documents/Pi-Backup/system-info/crontab-backup.txt ~/restore/
crontab ~/restore/crontab-backup.txt
```

### 5. Reinstall Packages
```bash
# Download package list
rclone copy OneDrive:Documents/Pi-Backup/system-info/installed-packages.txt ~/restore/

# Reinstall packages
sudo dpkg --set-selections < ~/restore/installed-packages.txt
sudo apt-get dselect-upgrade -y
```

### 6. Reinstall Key Services
```bash
# Docker (required for Pi-hole)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Pi-hole (Docker-based)
docker run -d \
  --name pihole \
  --restart=unless-stopped \
  -p 53:53/tcp -p 53:53/udp \
  -p 80:80 \
  pihole/pihole:latest
# Then restore config as shown in step 4

# Home Assistant
# Follow official installation: https://www.home-assistant.io/installation/raspberrypi

# RetroPie (if needed)
sudo apt install retropie
```

### 7. Restore Permissions
```bash
sudo chown -R pierre:pierre /home/pierre
```

## Backup Contents

- `/home/pierre` - Your entire home directory
- Home Assistant configs
- Pi-hole configuration
- Installed packages list
- Crontab
- System information

## Backup Schedule

This backup runs automatically via cron. Check logs at:
`/home/pierre/backup-logs/disaster-recovery-backup.log`
EOF

/usr/bin/rclone copy /tmp/RECOVERY-INSTRUCTIONS.md "$ONEDRIVE_BACKUP_ROOT/" \
    --log-file="$LOG_FILE" \
    --log-level INFO
rm /tmp/RECOVERY-INSTRUCTIONS.md
log "✓ Recovery instructions created"

# 9. Cleanup old logs
log "Cleaning up old log files..."
tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"

# 10. Cleanup rclone cache to prevent SD card from filling
log "Cleaning up rclone cache..."
rm -rf /home/pierre/.cache/rclone/* 2>/dev/null || true
log "✓ Rclone cache cleaned"

log "=========================================="
log "Disaster Recovery Backup Complete!"
log "=========================================="
log "Backup location: $ONEDRIVE_BACKUP_ROOT"
log ""
