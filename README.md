> A free, open-source NTFS read-write tool for macOS — powered by macFUSE & ntfs-3g.
> [中文教程 (Chinese Version)](./README_zh.md)

# 🧩 macOS NTFS Read-Write Made Easy: 100% Free with macFUSE + ntfs-3g

> Compatible with Apple Silicon (M1/M2/M3/M4) and macOS 14/15. Verified on macOS 15.7.

---

## 1. Why macOS Can’t Write to NTFS by Default

macOS natively supports **NTFS read-only**. When you plug in a Windows drive, you can browse files but cannot edit, copy, or delete them.

To enable write access, two open-source tools are required:

* **macFUSE**: a file system bridge.
* **ntfs-3g**: the open-source NTFS implementation.

Together, they enable full NTFS read/write support on macOS.

---

## 2. Installation and Setup

### 1. Install Dependencies

```bash
brew install --cask macfuse
brew tap gromgit/homebrew-fuse
brew install ntfs-3g-mac
```

### 2. Enable Kernel Extensions

1. Shut down → hold the power button → choose **Options (Recovery Mode)**.
2. From the menu: **Utilities → Startup Security Utility**.
3. Select your system disk, choose **Reduced Security**, and check:

   * Allow user management of kernel extensions.
4. Restart → open **System Settings → Privacy & Security**, and click **Allow** for macFUSE developer Benjamin Fleischer.
5. Reboot again to complete authorization.

---

## 3. Create a One-Click Script (Mount + Unmount + Eject)

Save the script as `~/Desktop/ntfs-smart.sh` and make it executable:

```bash
chmod +x ~/Desktop/ntfs-smart.sh
```

#### Optional: add a global shortcut

Create a symlink so you can run the script from any terminal:

```bash
sudo ln -s ~/Projects/personal/macos-ntfs-smart-mount/src/en/ntfs-smart.sh /usr/local/bin/ntfs-smart
```

Prefer the Chinese logs? Point the symlink to `src/zh/ntfs-smart.sh` instead. After this, just run `ntfs-smart` anywhere (it will still prompt for sudo when needed).

### Script Features

* Automatically detect macOS read-only mounts (fskit) and remount as writable.
* Use `ntfs-3g` for read-write operations.
* Run `diskutil eject` on unmount to ensure power-off safety.
* Kill Spotlight and QuickLook processes that may block unmount.

### Sample Core Command

```bash
sudo /opt/homebrew/bin/ntfs-3g /dev/diskXsY /Volumes/MyPassport -o local -o allow_other -o auto_xattr -o auto_cache
```

Full version includes detection, remounting, and safe eject logic.

---

## 4. How to Use

### ▶️ Mount the Drive

Plug in your NTFS disk and run:

```bash
~/Desktop/ntfs-smart.sh
```

Example output:

```
⚙️ Detected macOS read-only mount (fskit): /dev/disk4s1
➡️  Unmounting and remounting as writable...
✅ Found partition: /dev/disk4s1
📌 Mounting at /Volumes/MyPassport (read-write)...
🎉 Mounted successfully: /Volumes/MyPassport
```

Finder now allows full read-write operations.

### ⏏️ Unmount and Safe Eject

Run again to safely unmount:

```
🔄 Attempting to unmount /Volumes/MyPassport ...
✅ Successfully unmounted /Volumes/MyPassport, safe to unplug.
🔌 Performing full eject: /dev/disk4...
✅ Device safely ejected.
```

---

## 5. Hide Windows System Folders (Optional)

Common NTFS system folders:

```
$RECYCLE.BIN
System Volume Information
```

These are automatically created by Windows. To hide them in Finder:

```bash
echo "$RECYCLE.BIN" >> /Volumes/MyPassport/.hidden
echo "System Volume Information" >> /Volumes/MyPassport/.hidden
```

---

## 6. Troubleshooting

| Issue                       | Cause                         | Fix                                        |
| --------------------------- | ----------------------------- | ------------------------------------------ |
| read-only                   | macOS auto-mounted with fskit | Run script to unmount and remount          |
| mount failure               | macFUSE not authorized        | Allow macFUSE developer in System Settings |
| still visible after unmount | Finder cache not refreshed    | Run `diskutil eject /dev/diskX`            |

---

## 7. Summary

* 100% free and open source.
* Compatible with Apple Silicon.
* One-command automation.
* Safe hardware-level eject.

Run:

```bash
~/Desktop/ntfs-smart.sh
```

for full NTFS read/write and safe eject automation.

---

## 8. Verification

Example output:

```
🎉 Mounted successfully: /Volumes/MyPassport
✅ Device safely ejected.
```

Your Mac can finally write to NTFS — just like Windows 🚀

---

**License:** [MIT](./LICENSE) © 2025 Yangson
