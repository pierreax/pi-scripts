# Raspberry Pi Scripts

Collection of utility scripts for Raspberry Pi management and automation.

## Disaster Recovery Scripts

### pi-disaster-recovery-backup.sh
Comprehensive backup script that backs up everything needed to recover from SD card failure to OneDrive.

**What it backs up:**
- Home directory (excluding cache, temp files, .git, node_modules)
- Home Assistant configuration (Docker-based)
- Pi-hole configuration (Docker-based)
- DNS masq configuration
- Installed packages list
- Crontab
- System information

**Usage:**
```bash
./pi-disaster-recovery-backup.sh
```

**Setup:**
Run the installation script first to set up the automated backup cron job.

### install-disaster-recovery.sh
Installation script that sets up the disaster recovery backup system.

**What it does:**
- Installs rclone (if not already installed)
- Creates necessary directories
- Sets up daily cron job (runs at 2 AM)
- Makes backup script executable

**Usage:**
```bash
./install-disaster-recovery.sh
```

## Requirements

- Raspberry Pi OS
- rclone configured with OneDrive remote
- Docker (for Pi-hole and Home Assistant backups)

## Backup Schedule

The backup runs automatically daily at 2:00 AM via cron.

Check backup logs at: `/home/pierre/backup-logs/disaster-recovery-backup.log`

## Recovery

In case of SD card failure, see the recovery instructions file that gets backed up with your data:
`OneDrive:Documents/Pi-Backup/RECOVERY-INSTRUCTIONS.md`
