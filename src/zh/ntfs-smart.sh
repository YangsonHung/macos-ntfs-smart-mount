#!/bin/bash
# ntfs-smart.sh — 智能一键【挂载/卸载】NTFS (macFUSE + ntfs-3g)
# -------------------------------------------------------------------
# 使用说明：
#   - 直接运行即可：未挂载则读写挂载；已挂载则安全卸载并弹出。
#   - 自动检测系统默认的只读挂载 (fskit) 并替换为可写挂载。
#   - 根据需要修改下面两个变量 (卷名与挂载点)。
# -------------------------------------------------------------------

set -e

# === 可自定义区域 ===
LABEL_DEFAULT="My Passport"        # Finder 里看到的卷名
MOUNTPOINT="/Volumes/MyPassport"   # 读写挂载的目标目录
NTFS3G_BIN="/opt/homebrew/bin/ntfs-3g"  # ntfs-3g 路径 (Homebrew 默认)

log() { printf "%s\n" "$1"; }
mounted_at() { mount | awk -v mp="$1" '$0 ~ (" on " mp " ") {print $0}'; }

safe_unmount() {
  MP="$1"; DEV="$2"
  printf "🔄 尝试卸载 %s ...\n" "$MP"
  /sbin/umount "$MP" 2>/dev/null || true
  [ -n "$DEV" ] && /usr/sbin/diskutil unmount force "/dev/$DEV" 2>/dev/null || true
  [ -n "$DEV" ] && /usr/sbin/diskutil unmountDisk force "/dev/${DEV%%s*}" 2>/dev/null || true
  if mount | grep -q "on $MP "; then
    printf "🧹 检测到占用进程，尝试停止 Spotlight/QuickLook...\n"
    sudo mdutil -i off "$MP" >/dev/null 2>&1
    for P in mds mds_stores mdworker QuickLookUIService; do pkill -f "$P" >/dev/null 2>&1 || true; done
    osascript -e 'try' -e 'tell application "Finder" to eject (POSIX file '"'$MP'"')' -e 'end try' >/dev/null 2>&1
    /sbin/umount "$MP" 2>/dev/null || /usr/sbin/diskutil unmount force "$MP" || true
    [ -n "$DEV" ] && /usr/sbin/diskutil unmount force "/dev/$DEV" 2>/dev/null || true
    [ -n "$DEV" ] && /usr/sbin/diskutil unmountDisk force "/dev/${DEV%%s*}" 2>/dev/null || true
  fi
  if mount | grep -q "on $MP "; then
    printf "❌ 仍未卸载，可能还有进程占用。请运行：sudo lsof +D %s\n" "$MP"
    return 1
  else
    printf "✅ 已安全卸载 %s，可以物理拔盘。\n" "$MP"
    # 自动弹出设备
    DISK_ROOT=$(echo "$DEV" | sed 's/s[0-9]*$//')
    if [ -n "$DISK_ROOT" ]; then
      printf "🔌 正在执行完整弹出: /dev/%s...\n" "$DISK_ROOT"
      sudo diskutil eject /dev/$DISK_ROOT >/dev/null 2>&1 && printf "✅ 设备已断开，可安全拔出。\n" || printf "⚠️ 弹出失败，请稍后再试。\n"
    fi
    return 0
  fi
}

# === 检查系统自动只读挂载 ===
readonly_mount=$(mount | grep "ntfs" | grep -i "read-only" | grep "fskit" | awk '{print $1}')
if [ -n "$readonly_mount" ]; then
  printf "⚙️ 检测到 macOS 自动只读挂载 (fskit): %s\n➡️  正在卸载以重新挂载为可写...\n" "$readonly_mount"
  sudo diskutil unmount "$readonly_mount" || sudo umount "$readonly_mount"
fi

# === 检查是否已挂载 (确保目录存在且确实在 mount 列表中) ===
if [ -d "$MOUNTPOINT" ] && mount | grep -q "on $MOUNTPOINT "; then
  DEV_ID=$(diskutil info "$MOUNTPOINT" 2>/dev/null | awk -F': *' '/Device Node/ {print $2}')
  safe_unmount "$MOUNTPOINT" "${DEV_ID#/dev/}"
  exit $?
fi

# === 未挂载：开始查找分区并挂载 ===
log "🔎 寻找 NTFS/Microsoft Basic Data 分区..."
IDENTIFIER=$(diskutil info -all | awk 'BEGIN{RS="";FS="\n"} /Volume Name:[[:space:]]*'"$LABEL_DEFAULT"'/ && /File System Personality:[[:space:]]*(NTFS|Windows_NTFS|Microsoft Basic Data)/ {for(i=1;i<=NF;i++) if($i ~ /Device Identifier:/){split($i,a,": "); print a[2]}}' | head -n1)
if [ -z "$IDENTIFIER" ]; then
  IDENTIFIER=$(diskutil list | awk '/external, physical/ {ext=1; next} /^\/dev\// {ext=($0 ~ /external, physical/)} ext && /Microsoft Basic Data|Windows_NTFS|NTFS/ {print $NF; exit}')
fi
if [ -z "$IDENTIFIER" ]; then
  log "❌ 没找到 NTFS 分区。请确认硬盘已插入，或修改 LABEL_DEFAULT (当前: $LABEL_DEFAULT)。"
  exit 1
fi

log "✅ 找到分区: /dev/$IDENTIFIER"
/usr/sbin/diskutil unmountDisk force /dev/"$IDENTIFIER" >/dev/null 2>&1 || true

if [ ! -f /etc/fuse.conf ]; then
  log "🛠️  创建 /etc/fuse.conf"; sudo touch /etc/fuse.conf; fi
if ! grep -q "^user_allow_other$" /etc/fuse.conf; then
  log "🛠️  写入 user_allow_other 到 /etc/fuse.conf"; echo "user_allow_other" | sudo tee -a /etc/fuse.conf >/dev/null; fi

sudo mkdir -p "$MOUNTPOINT"
log "📌 正在挂载到 $MOUNTPOINT (读写)..."
sudo "$NTFS3G_BIN" /dev/"$IDENTIFIER" "$MOUNTPOINT" -o local -o allow_other -o auto_xattr -o auto_cache

if mount | grep -q "on $MOUNTPOINT "; then
  log "🎉 挂载成功: $MOUNTPOINT\n现在可以在 Finder 中进行读写操作。"
else
  log "❌ 挂载失败。若看到 macFUSE 阻止提示，请在系统设置中 Allow 'Benjamin Fleischer'，并重启后重试。"
  exit 2
fi