# Raspberry Pi Scripts

Collection of utility scripts for Raspberry Pi management and automation.

## Disaster Recovery Scripts

### pi-disaster-recovery-backup.sh
Comprehensive backup script that backs up everything needed to recover from SD card failure to OneDrive.

**What it backs up:**
- Home directory (excluding cache, temp files, .git, node_modules, ESP-IDF toolchains and build dirs)
- Home Assistant configuration (Docker-based), with a consistent `sqlite3 .backup` snapshot of the recorder DB
- Pi-hole configuration (Docker-based)
- DNS masq configuration
- Thread/OTBR network keys (`~/thread/otbr-data`, root-owned → `Pi-Backup/thread-otbr-data`)
- udev rule + sysctl for the Thread RCP (`Pi-Backup/thread-system/*.txt` — OneDrive rejects `.rules`)
- Installed packages list
- Crontab
- System information
- `RECOVERY-INSTRUCTIONS.md` (restore steps, incl. Thread keys before `docker start otbr`)

**rclone.conf ownership:** steps run with `sudo rclone` may write refreshed OneDrive tokens back
to `rclone.conf`, making it root-owned and breaking the steps that run as `pierre`. The script
calls `fix_rclone_conf` (chown pierre + chmod 600) at start and between the sudo steps.

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

The backup runs weekly, Sunday 02:00, via cron (`git pull` first, so pushed changes apply to the next run):

```
0 2 * * 0 cd /home/pierre/pi-scripts && git pull && /home/pierre/pi-scripts/pi-disaster-recovery-backup.sh
```

Harmless: `deletefile` ERROR lines for `home-assistant_v2.db-wal`/`-shm` (those files no longer exist on OneDrive).

Check backup logs at: `/home/pierre/backup-logs/disaster-recovery-backup.log`

## Recovery

In case of SD card failure, see the recovery instructions file that gets backed up with your data:
`OneDrive:Documents/Pi-Backup/RECOVERY-INSTRUCTIONS.md`
