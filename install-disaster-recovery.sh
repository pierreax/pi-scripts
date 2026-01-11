#!/bin/bash
# Quick installer for Disaster Recovery Backup

set -e

echo "=========================================="
echo "Disaster Recovery Backup Installer"
echo "=========================================="
echo ""
echo "This will set up automated backups to OneDrive of:"
echo "  ✓ Your entire home directory (RetroPie ROMs included)"
echo "  ✓ Home Assistant configurations"
echo "  ✓ Pi-hole configuration"
echo "  ✓ Installed packages list"
echo "  ✓ System information"
echo ""
echo "Backup size: ~3.2GB"
echo "Your OneDrive space: 1TB"
echo ""

read -p "Continue with installation? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Installation cancelled."
    exit 0
fi

# Create backup logs directory
mkdir -p ~/backup-logs

# Verify backup script exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/pi-disaster-recovery-backup.sh" ]; then
    echo "Error: pi-disaster-recovery-backup.sh not found in $SCRIPT_DIR"
    exit 1
fi

echo ""
echo "✓ Using backup script from $SCRIPT_DIR"
echo ""

# Ask about scheduling
echo "How often should backups run?"
echo "1. Weekly (Sunday at 2 AM) - Recommended"
echo "2. Daily (3 AM)"
echo "3. Twice per week (Wednesday & Sunday at 2 AM)"
echo "4. Manual only (I'll run it myself)"
echo ""

read -p "Enter choice (1-4): " schedule

case $schedule in
    1)
        CRON_LINE="0 2 * * 0 cd $SCRIPT_DIR && git pull && $SCRIPT_DIR/pi-disaster-recovery-backup.sh"
        SCHEDULE_DESC="Weekly on Sunday at 2 AM"
        ;;
    2)
        CRON_LINE="0 3 * * * cd $SCRIPT_DIR && git pull && $SCRIPT_DIR/pi-disaster-recovery-backup.sh"
        SCHEDULE_DESC="Daily at 3 AM"
        ;;
    3)
        CRON_LINE="0 2 * * 0,3 cd $SCRIPT_DIR && git pull && $SCRIPT_DIR/pi-disaster-recovery-backup.sh"
        SCHEDULE_DESC="Wednesday and Sunday at 2 AM"
        ;;
    4)
        CRON_LINE=""
        SCHEDULE_DESC="Manual only"
        ;;
    *)
        echo "Invalid choice. Setting to manual only."
        CRON_LINE=""
        SCHEDULE_DESC="Manual only"
        ;;
esac

if [ -n "$CRON_LINE" ]; then
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "pi-disaster-recovery-backup.sh"; then
        echo "✓ Cron job already exists"
    else
        # Add the cron job
        (crontab -l 2>/dev/null; echo ""; echo "# Pi Disaster Recovery Backup"; echo "$CRON_LINE") | crontab -
        echo "✓ Cron job added: $SCHEDULE_DESC"
    fi
fi

echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Backup script: $SCRIPT_DIR/pi-disaster-recovery-backup.sh"
echo "Schedule: $SCHEDULE_DESC"
echo "Logs: ~/backup-logs/disaster-recovery-backup.log"
echo ""

read -p "Run first backup now? (y/n): " run_now
if [ "$run_now" = "y" ]; then
    echo ""
    echo "Running first backup..."
    "$SCRIPT_DIR/pi-disaster-recovery-backup.sh"
    echo ""
    echo "First backup complete!"
    echo ""
    echo "Check OneDrive at: Documents/Pi-Backup/"
else
    echo ""
    echo "To run backup manually:"
    echo "  $SCRIPT_DIR/pi-disaster-recovery-backup.sh"
fi

echo ""
echo "To view backup logs:"
echo "  tail -f ~/backup-logs/disaster-recovery-backup.log"
echo ""
echo "To check what's backed up on OneDrive:"
echo "  rclone ls OneDrive:Documents/Pi-Backup/"
echo ""
