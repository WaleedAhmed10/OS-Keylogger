# 🖥 Keyboard Input Monitoring System
**Bahria University — Operating Systems Project (Spring 2026)**  
**Student:** Hussain Ahmed | **Enrollment:** 09-131242-030  
**Submitted to:** Aamir Sohail

---

## 📌 Overview

A Linux-based keyboard input monitoring system built with **Bash** and **Zenity** (GUI), with a **Python** decoder for keycodes. Designed for educational purposes inside a controlled VMware environment running **Fedora**.

---

## 📁 Project Structure

```
keylogger-project/
├── keylogger.sh          ← Main app (Bash + Zenity GUI)
├── decode_keycodes.sh    ← Bash keycode decoder
├── setup.sh              ← Dependency installer (Fedora/DNF)
├── logs/                 ← Auto-created; stores session logs
│   └── keylog_YYYYMMDD_HHMMSS.log
└── README.md
```

---

## ⚙️ Dependencies

| Tool       | Purpose                          |
|------------|----------------------------------|
| `zenity`   | GTK GUI dialogs                  |
| `evtest`   | Capture keyboard keycodes        |
| `showkey`  | Fallback keycode reader          |
| `xclip`    | Copy suggestions to clipboard    |
| `notify-send` | Visible monitoring indicator  |

---

## 🚀 How to Run

### 1. Install dependencies (Fedora)
```bash
sudo ./setup.sh
```

### 2. Launch the GUI
```bash
sudo ./keylogger.sh
```

### 3. Decode a log file
```bash
./decode_keycodes.sh logs/keylog_20260515_143022.log
```

---

## 🧩 Features

### ✅ User Permission Required
- App checks for root/sudo on launch
- Shows a Zenity error dialog if run without proper permissions

### ✅ Visible Indicator (Mode ON → Visible)
- When monitoring is active, periodic desktop notifications appear
- Clearly shows the monitoring state in the main menu label

### ❌ Password/Keys Capture → Excluded
- As per design decision, password capture is intentionally NOT implemented

### ✅ Log Maintenance with Reason
- Every session asks the user for a **reason/label**
- Reason is stored at the top of each log file
- Timestamps are recorded for every entry

### ✅ Command Suggestions
- Shows previously used commands (from bash history)
- Shows frequently useful Linux commands
- Double-click any command to copy to clipboard

### ✅ Command Assistant
- Describe a task in plain English
- Get the appropriate Linux command suggested
- One-click copy to clipboard

---

## 🔐 OS Concepts Demonstrated

| Concept             | Implementation                          |
|---------------------|-----------------------------------------|
| I/O Management      | Reading from `/dev/input/` devices      |
| System Calls        | `evtest`, `showkey` for input access    |
| Process Management  | Background processes, PID tracking      |
| File Management     | Log creation, reading, deletion         |
| Permissions         | Root check, file permission handling    |

---

## ⚠️ Ethical Notice

This project is strictly for **educational use** inside a **controlled VMware environment**.  
Do not use on systems you do not own or have explicit permission to monitor.
