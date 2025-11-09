> 一个免费的 macOS NTFS 读写开源工具，基于 macFUSE 与 ntfs-3g 构建。
> [English Version](./README.md)

# 🧩 macOS 一键读写 NTFS：完整免费方案（macFUSE + ntfs-3g）

> 适用：Apple Silicon (M1/M2/M3/M4) + macOS 14/15，已在 macOS 15.7 上验证通过。

---

## 一、为什么 macOS 无法直接写 NTFS？

macOS 天生只支持 **NTFS 只读**。插入 Windows 硬盘时，只能浏览文件，无法编辑、复制或删除。

要实现写入，需要第三方驱动：

* **macFUSE**：提供文件系统桥接层。
* **ntfs-3g**：开源的 NTFS 读写实现。

两者结合后，macOS 就能完整地读写 NTFS 了。

---

## 二、安装与环境准备

### 1. 安装依赖

```bash
brew install --cask macfuse
brew tap gromgit/homebrew-fuse
brew install ntfs-3g-mac
```

### 2. 启用系统扩展

1. 关机 → 长按电源键 → 进入 **Options (恢复模式)**。
2. 打开菜单：**Utilities → Startup Security Utility**。
3. 选择系统磁盘，设置为 **Reduced Security**，并勾选：

   * Allow user management of kernel extensions。
4. 重启后，在 **系统设置 → 隐私与安全性** 中点击 **Allow macFUSE 开发者 Benjamin Fleischer**。
5. 再次重启完成授权。

---

## 三、创建一键脚本（挂载 + 卸载 + 弹出）

将以下脚本保存为 `~/Desktop/ntfs-smart.sh`，并执行：

```bash
chmod +x ~/Desktop/ntfs-smart.sh
```

#### 可选：创建全局软链接

为了在任意终端直接运行脚本，可以添加软链接：

```bash
sudo ln -s ~/Projects/personal/macos-ntfs-smart-mount/src/zh/ntfs-smart.sh /usr/local/bin/ntfs-smart
```

若想使用英文提示信息，只需把路径改为 `src/en/ntfs-smart.sh`。之后即可直接运行 `ntfs-smart`（涉及写入时依旧会提示输入 sudo 密码）。

### 脚本主要功能

* 自动检测系统只读挂载 (fskit)，并卸载后重新挂载为可写。
* 读写挂载时使用 `ntfs-3g`。
* 卸载时执行 `diskutil eject` 自动断电。
* 自动清理 Spotlight、QuickLook 占用进程。

### 脚本内容（节选）

```bash
sudo /opt/homebrew/bin/ntfs-3g /dev/diskXsY /Volumes/MyPassport -o local -o allow_other -o auto_xattr -o auto_cache
```

完整版本包含自动检测和安全卸载逻辑，可直接运行一键挂载或卸载。

---

## 四、使用方法

### ▶️ 挂载硬盘

插入 NTFS 硬盘后执行：

```bash
~/Desktop/ntfs-smart.sh
```

输出示例：

```
⚙️ 检测到 macOS 自动只读挂载 (fskit): /dev/disk4s1
➡️  正在卸载以重新挂载为可写...
✅ 找到分区: /dev/disk4s1
📌 正在挂载到 /Volumes/MyPassport (读写)...
🎉 挂载成功: /Volumes/MyPassport
```

Finder 中即可自由读写。

### ⏏️ 卸载与安全弹出

再次执行脚本：

```
🔄 尝试卸载 /Volumes/MyPassport ...
✅ 已安全卸载 /Volumes/MyPassport，可以物理拔盘。
🔌 正在执行完整弹出: /dev/disk4...
✅ 设备已断开，可安全拔出。
```

---

## 五、隐藏系统文件（可选）

NTFS 卷常见系统目录：

```
$RECYCLE.BIN
System Volume Information
```

这些是 Windows 自动生成的，可执行以下命令隐藏：

```bash
echo "$RECYCLE.BIN" >> /Volumes/MyPassport/.hidden
echo "System Volume Information" >> /Volumes/MyPassport/.hidden
```

---

## 六、常见问题排查

| 问题        | 原因           | 解决                             |
| --------- | ------------ | ------------------------------ |
| read-only | macOS 自动只读挂载 | 运行脚本自动卸载并重挂                    |
| 挂载失败      | macFUSE 未授权  | 系统设置中点击 Allow 开发者              |
| 卸载后仍显示设备  | Finder 缓存未刷新 | 运行 `diskutil eject /dev/diskX` |

---

## 七、总结

* 免费、稳定、兼容 Apple Silicon。
* 自动化脚本一键操作，无需 Finder 介入。
* 完全断电卸载，安全可靠。

运行：

```bash
~/Desktop/ntfs-smart.sh
```

即可完成 NTFS 读写与安全弹出全过程。

---

## 八、成功验证

运行后输出：

```
🎉 挂载成功: /Volumes/MyPassport
✅ 设备已断开，可安全拔出。
```

你的 Mac，终于能像 Windows 一样写入 NTFS 了 🚀

---

**License:** [MIT](./LICENSE) © 2025 Yangson
