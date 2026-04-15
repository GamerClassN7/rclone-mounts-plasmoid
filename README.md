# Rclone Mounts — KDE Plasma Plasmoid

A **KDE Plasma 6** widget for managing rclone cloud remotes directly from your panel or desktop.

![Mounts Tab](image.png)
![History Tab](image-1.png)

---

## Overview

Mount and unmount rclone remotes with one click, track transfer history, and monitor active uploads/downloads in real time, all without opening a terminal.

**Features:**
- One-click mount / unmount for remotes
- Completed transfer history with success / error indicator
- Real-time active transfer monitoring
- Start and stop rclone RC daemon from the context menu
- Remote search/filter

---

## Installation

```bash
git clone <repo-url>
cd rclone-mounts-plasmoid
chmod +x install.sh
./install.sh
```

After installation: right-click the panel or desktop -> **Add Widgets** -> search for **Rclone**.

> Requires: `rclone` and KDE Plasma 6

---

**Keywords:** rclone, KDE Plasma, plasmoid, widget, cloud storage, mount, Google Drive, OneDrive, S3