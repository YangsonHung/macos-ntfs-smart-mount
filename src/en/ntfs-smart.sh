#!/bin/bash
# ntfs-smart.sh — Intelligent one-click NTFS Mounter/Unmounter (macFUSE + ntfs-3g)
# -------------------------------------------------------------------
# Usage:
#   - Run directly: if not mounted, it mounts in read-write mode;
#                   if already mounted, it safely unmounts and ejects.
#   - Automatically detects macOS's default read-only mount (fskit)
#     and remounts it with write access.
#   - You can modify the two variables below (volume label and mount point).
# -------------------------------------------------------------------

set -e

# === Customizable Section ===
LABEL_DEFAULT="My Passport"        # The volume label as shown in Finder
MOUNTPOINT="/Volumes/MyPassport"   # Target directory for read-write mount
NTFS3G_BIN="/opt/homebrew/bin/ntfs-3g"  # Path to ntfs-3g (default for Homebrew)

log() { printf "%s\n" "$1"; }
mounted_at() { mount | awk -v mp="$1" '$0 ~ (" on " mp " ") {print $0}'; }

safe_unmount() {
  MP="$1"; DEV="$2"
  printf "🔄 Attempting to unmount %s ...\n" "$MP"
  /sbin/umount "$MP" 2>/dev/null || true
  [ -n "$DEV" ] && /usr/sbin/diskutil unmount force "/dev/$DEV" 2>/dev/null || true
  [ -n "$DEV" ] && /usr/sbin/diskutil unmountDisk force "/dev/${DEV%%s*}" 2>/dev/null || true
  if mount | grep -q "on $MP "; then
    printf "🧹 Detected busy processes, stopping Spotlight/QuickLook...\n"
    sudo mdutil -i off "$MP" >/dev/null 2>&1
    for P in mds mds_stores mdworker QuickLookUIService; do pkill -f "$P" >/dev/null 2>&1 || true; done
    osascript -e 'try' -e 'tell application "Finder" to eject (POSIX file '"'$MP'"')' -e 'end try' >/dev/null 2>&1
    /sbin/umount "$MP" 2>/dev/null || /usr/sbin/diskutil unmount force "$MP" || true
    [ -n "$DEV" ] && /usr/sbin/diskutil unmount force "/dev/$DEV" 2>/dev/null || true
    [ -n "$DEV" ] && /usr/sbin/diskutil unmountDisk force "/dev/${DEV%%s*}" 2>/dev/null || true
  fi
  if mount | grep -q "on $MP "; then
    printf "❌ Still mounted. Some processes may be holding the volume. Try: sudo lsof +D %s\n" "$MP"
    return 1
  else
    printf "✅ Successfully unmounted %s. You can safely unplug it now.\n" "$MP"
    # Perform a full device eject
    DISK_ROOT=$(echo "$DEV" | sed 's/s[0-9]*$//')
    if [ -n "$DISK_ROOT" ]; then
      printf "🔌 Performing full eject: /dev/%s...\n" "$DISK_ROOT"
      sudo diskutil eject /dev/$DISK_ROOT >/dev/null 2>&1 && printf "✅ Device ejected safely.\n" || printf "⚠️ Eject failed, please try again later.\n"
    fi
    return 0
  fi
}

# === Detect macOS automatic read-only mount ===
readonly_mount=$(mount | grep "ntfs" | grep -i "read-only" | grep "fskit" | awk '{print $1}')
if [ -n "$readonly_mount" ]; then
  printf "⚙️ Detected macOS auto read-only mount (fskit): %s\n➡️  Unmounting to remount as writable...\n" "$readonly_mount"
  sudo diskutil unmount "$readonly_mount" || sudo umount "$readonly_mount"
fi

# === Check if already mounted (ensure directory exists and is in mount list) ===
if [ -d "$MOUNTPOINT" ] && mount | grep -q "on $MOUNTPOINT "; then
  DEV_ID=$(diskutil info "$MOUNTPOINT" 2>/dev/null | awk -F': *' '/Device Node/ {print $2}')
  safe_unmount "$MOUNTPOINT" "${DEV_ID#/dev/}"
  exit $?
fi

# === Not mounted: find NTFS partition and mount ===
log "🔎 Searching for NTFS/Microsoft Basic Data partition..."
IDENTIFIER=$(diskutil info -all | awk 'BEGIN{RS="";FS="\\n"} /Volume Name:[[:space:]]*'"$LABEL_DEFAULT"'/ && /File System Personality:[[:space:]]*(NTFS|Windows_NTFS|Microsoft Basic Data)/ {for(i=1;i<=NF;i++) if($i ~ /Device Identifier:/){split($i,a,": "); print a[2]}}' | head -n1)
if [ -z "$IDENTIFIER" ]; then
  IDENTIFIER=$(diskutil list | awk '/external, physical/ {ext=1; next} /^\\/dev\\// {ext=($0 ~ /external, physical/)} ext && /Microsoft Basic Data|Windows_NTFS|NTFS/ {print $NF; exit}')
fi
if [ -z "$IDENTIFIER" ]; then
  log "❌ No NTFS partition found. Please make sure the drive is connected or adjust LABEL_DEFAULT (current: $LABEL_DEFAULT)."
  exit 1
fi

log "✅ Found partition: /dev/$IDENTIFIER"
/usr/sbin/diskutil unmountDisk force /dev/"$IDENTIFIER" >/dev/null 2>&1 || true

if [ ! -f /etc/fuse.conf ]; then
  log "🛠️  Creating /etc/fuse.conf"; sudo touch /etc/fuse.conf; fi
if ! grep -q "^user_allow_other$" /etc/fuse.conf; then
  log "🛠️  Writing user_allow_other to /etc/fuse.conf"; echo "user_allow_other" | sudo tee -a /etc/fuse.conf >/dev/null; fi

sudo mkdir -p "$MOUNTPOINT"
log "📌 Mounting to $MOUNTPOINT (read-write)..."
sudo "$NTFS3G_BIN" /dev/"$IDENTIFIER" "$MOUNTPOINT" -o local -o allow_other -o auto_xattr -o auto_cache

if mount | grep -q "on $MOUNTPOINT "; then
  log "🎉 Successfully mounted: $MOUNTPOINT\nYou can now read and write in Finder."
else
  log "❌ Mount failed. If macFUSE was blocked, go to System Settings → Privacy & Security → Allow 'Benjamin Fleischer', then reboot and try again."
  exit 2
fi