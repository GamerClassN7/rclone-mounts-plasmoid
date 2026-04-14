# Rclone Mounts — KDE Plasma Plasmoid

Widget for **KDE Plasma 6** to manage rclone cloud storage remotes directly from the panel or desktop.

![Mounts tab](image.png)
![History tab](image-1.png)

---

## Description

Mount and unmount rclone remotes with a single click, track transfer history and active uploads/downloads — all without a terminal.

**Features:**
- Mount / unmount remotes with one click
- Transfer history with success / error indicator
- Real-time active transfer monitoring
- Start and stop the rclone RC daemon from the context menu
- Remote search

---

## Installation

```bash
git clone https://github.com/GamerClassN7/rclone-mounts-plasmoid.git
cd rclone-mounts-plasmoid
chmod +x install.sh
./install.sh
```

After installation: right-click the panel or desktop → **Add Widget** → search for **Rclone**.

> Requires: `rclone` and KDE Plasma 6

---

## License

GPL-2.0+

---

**Keywords:** rclone, KDE Plasma, plasmoid, widget, cloud storage, mount, Google Drive, OneDrive, S3