#!/bin/bash
# ============================================================
#  Linux Keyboard Input Monitoring System
#  Bahria University - OS Project (Spring 2026)
#  Student: Hussain Ahmed | Enrollment: 09-131242-030
#  GUI: Zenity | Shell: Bash | Platform: Fedora/Linux
# ============================================================

# ─── CONFIGURATION ──────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/keylog_$(date +%Y%m%d_%H%M%S).log"
HISTORY_FILE="$LOG_DIR/command_history.log"
PID_FILE="$LOG_DIR/keylogger.pid"
INDICATOR_FILE="$LOG_DIR/.monitoring_active"

mkdir -p "$LOG_DIR"

# ─── COLORS (for terminal output) ───────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ─── HELPER: Check if running as root ───────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        zenity --error \
            --title="Permission Denied" \
            --text="<b>User Permission Required</b>\n\nThis application requires <b>root/sudo</b> privileges to monitor keyboard input.\n\nPlease run with:\n<tt>sudo ./keylogger.sh</tt>" \
            --width=380
        exit 1
    fi
}

# ─── HELPER: Check dependencies ─────────────────────────────
check_deps() {
    local missing=()
    for cmd in zenity showkey python3 xdotool; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        zenity --warning \
            --title="Missing Dependencies" \
            --text="<b>Some tools are not installed:</b>\n\n$(printf '• %s\n' "${missing[@]}")\n\nInstall with:\n<tt>sudo dnf install ${missing[*]}</tt>\n\n<i>Continuing with available tools...</i>" \
            --width=380
    fi
}

# ─── HELPER: Visible tray indicator ─────────────────────────
show_indicator() {
    touch "$INDICATOR_FILE"
    # Show a persistent notification while monitoring is ON
    (
        while [[ -f "$INDICATOR_FILE" ]]; do
            sleep 30
            notify-send "🔴 Keylogger Active" "Monitoring is ON. Open the app to stop." \
                --urgency=normal --expire-time=5000 2>/dev/null || true
        done
    ) &
    echo $! > "$LOG_DIR/.indicator.pid"
}

hide_indicator() {
    rm -f "$INDICATOR_FILE"
    if [[ -f "$LOG_DIR/.indicator.pid" ]]; then
        kill "$(cat "$LOG_DIR/.indicator.pid")" 2>/dev/null || true
        rm -f "$LOG_DIR/.indicator.pid"
    fi
}

# ─── CORE: Start monitoring ──────────────────────────────────
start_monitoring() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        zenity --warning \
            --title="Already Running" \
            --text="Keyboard monitoring is <b>already active</b>.\n\nPID: $(cat "$PID_FILE")" \
            --width=320
        return
    fi

    # Ask for reason/session label
    local reason
    reason=$(zenity --entry \
        --title="Start Monitoring Session" \
        --text="<b>Enter a reason/label for this session:</b>\n(e.g. 'Testing terminal input', 'OS Lab exercise')" \
        --entry-text="OS Lab Session" \
        --width=420)

    [[ $? -ne 0 ]] && return  # User cancelled

    echo "============================================" >> "$LOG_FILE"
    echo " SESSION START: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo " REASON: ${reason:-No reason given}"           >> "$LOG_FILE"
    echo " USER: $(logname 2>/dev/null || echo $SUDO_USER)" >> "$LOG_FILE"
    echo "============================================" >> "$LOG_FILE"

    show_indicator

    # Detect available keyboard device
    local kbd_device
    kbd_device=$(ls /dev/input/by-path/*kbd* 2>/dev/null | head -1)
    if [[ -z "$kbd_device" ]]; then
        kbd_device=$(ls /dev/input/event* 2>/dev/null | head -1)
    fi

    if [[ -n "$kbd_device" ]]; then
        # Use evtest or showkey to capture raw input
        if command -v evtest &>/dev/null; then
            evtest "$kbd_device" 2>/dev/null | \
                grep --line-buffered "KEY_" | \
                awk '{for(i=1;i<=NF;i++) if($i~/KEY_/) print strftime("%H:%M:%S"), $i}' \
                >> "$LOG_FILE" &
            echo $! > "$PID_FILE"
        else
            # Fallback: use showkey in background
            (showkey --keycodes 2>&1 | while IFS= read -r line; do
                echo "$(date '+%H:%M:%S') $line" >> "$LOG_FILE"
            done) &
            echo $! > "$PID_FILE"
        fi
    else
        # Demo mode: log bash history changes
        (while [[ -f "$PID_FILE" ]]; do
            if [[ -f "$HISTORY_FILE" ]]; then
                tail -1 "$HISTORY_FILE" >> "$LOG_FILE" 2>/dev/null
            fi
            sleep 2
        done) &
        echo $! > "$PID_FILE"
    fi

    zenity --info \
        --title="✅ Monitoring Started" \
        --text="<b>Keyboard monitoring is now ACTIVE</b>\n\n📁 Log file:\n<tt>$LOG_FILE</tt>\n\n🔴 <b>Visible Indicator:</b> Active (notifications enabled)\n\n<i>Session reason: ${reason:-N/A}</i>" \
        --width=420
}

# ─── CORE: Stop monitoring ───────────────────────────────────
stop_monitoring() {
    if [[ ! -f "$PID_FILE" ]]; then
        zenity --info \
            --title="Not Running" \
            --text="No active monitoring session found." \
            --width=280
        return
    fi

    local pid
    pid=$(cat "$PID_FILE")

    kill "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    hide_indicator

    echo "============================================" >> "$LOG_FILE"
    echo " SESSION END:   $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "============================================" >> "$LOG_FILE"

    zenity --info \
        --title="⏹ Monitoring Stopped" \
        --text="<b>Monitoring has been stopped.</b>\n\nLog saved to:\n<tt>$LOG_FILE</tt>" \
        --width=380
}

# ─── VIEW: Log viewer ────────────────────────────────────────
view_logs() {
    local logs=()
    while IFS= read -r f; do
        logs+=("$f" "$(wc -l < "$f") lines — $(stat -c %y "$f" | cut -d. -f1)")
    done < <(ls -t "$LOG_DIR"/*.log 2>/dev/null)

    if [[ ${#logs[@]} -eq 0 ]]; then
        zenity --info --title="No Logs" --text="No log files found yet.\nStart a monitoring session first." --width=300
        return
    fi

    local selected
    selected=$(zenity --list \
        --title="📋 Select Log File to View" \
        --column="File" --column="Info" \
        "${logs[@]}" \
        --width=600 --height=300)

    [[ -z "$selected" ]] && return

    local content
    content=$(tail -100 "$selected")

    zenity --text-info \
        --title="Log: $(basename "$selected")" \
        --filename=<(echo "$content") \
        --width=700 --height=500 \
        --font="Monospace 10"
}

# ─── FEATURE: Command suggestions ───────────────────────────
command_suggestions() {
    # Build suggestion list from bash history + common commands
    local history_cmds=()
    if [[ -f "/root/.bash_history" ]]; then
        mapfile -t history_cmds < <(sort /root/.bash_history | uniq -c | sort -rn | head -20 | awk '{$1=""; print $0}' | sed 's/^ //')
    fi
    if [[ -f "/home/$SUDO_USER/.bash_history" ]]; then
        mapfile -t more < <(sort "/home/$SUDO_USER/.bash_history" | uniq -c | sort -rn | head -20 | awk '{$1=""; print $0}' | sed 's/^ //')
        history_cmds+=("${more[@]}")
    fi

    # Common Linux commands
    local common_cmds=(
        "ls -la" "cd /home" "pwd" "whoami" "ps aux" "top" "htop"
        "df -h" "free -h" "uname -a" "cat /etc/os-release"
        "grep -r '' ." "find . -name '*.sh'" "chmod +x script.sh"
        "systemctl status" "journalctl -xe" "ip addr show"
        "ping -c 4 google.com" "curl -I https://example.com"
        "tar -czf archive.tar.gz ." "zip -r archive.zip ."
        "python3 --version" "bash --version"
    )

    # Combine and deduplicate
    local all_cmds=()
    for cmd in "${history_cmds[@]}" "${common_cmds[@]}"; do
        [[ -n "$cmd" ]] && all_cmds+=("$cmd")
    done

    # Build zenity list
    local list_items=()
    for cmd in "${all_cmds[@]}"; do
        list_items+=("$cmd")
    done

    local chosen
    chosen=$(printf '%s\n' "${list_items[@]}" | sort -u | \
        zenity --list \
            --title="💡 Command Suggestions" \
            --text="<b>Previously used &amp; frequently used commands</b>\nDouble-click to copy to clipboard:" \
            --column="Command" \
            --width=560 --height=420)

    if [[ -n "$chosen" ]]; then
        echo "$chosen" | xclip -selection clipboard 2>/dev/null || \
        echo "$chosen" | xsel --clipboard --input 2>/dev/null || true

        zenity --info \
            --title="📋 Copied!" \
            --text="Command copied to clipboard:\n\n<tt>$chosen</tt>\n\nPaste it in your terminal with <b>Ctrl+Shift+V</b>" \
            --width=380
    fi
}

# ─── FEATURE: Command assistant ─────────────────────────────
command_assistant() {
    local task
    task=$(zenity --entry \
        --title="🤖 Command Assistant" \
        --text="<b>What do you want to do?</b>\n(Describe your task and get a command suggestion)" \
        --entry-text="list all running processes" \
        --width=480)

    [[ $? -ne 0 ]] && return

    local suggestion=""
    local explanation=""

    # Simple keyword-based suggestions
    case "${task,,}" in
        *"running process"*|*"process list"*)
            suggestion="ps aux | grep -v grep"
            explanation="Lists all running processes with user, PID, CPU and memory usage." ;;
        *"disk"*"space"*|*"storage"*)
            suggestion="df -h"
            explanation="Shows disk space usage in human-readable format." ;;
        *"memory"*|*"ram"*)
            suggestion="free -h"
            explanation="Displays RAM and swap memory usage." ;;
        *"network"*|*"ip"*|*"address"*)
            suggestion="ip addr show"
            explanation="Shows all network interfaces and their IP addresses." ;;
        *"find file"*|*"search file"*)
            suggestion="find / -name 'filename' 2>/dev/null"
            explanation="Searches the entire filesystem for a file by name." ;;
        *"who"*"logged"*|*"current user"*)
            suggestion="who && whoami"
            explanation="Shows currently logged-in users and your own username." ;;
        *"kernel"*|*"os version"*|*"system info"*)
            suggestion="uname -a && cat /etc/os-release"
            explanation="Displays kernel version and OS distribution details." ;;
        *"kill"*"process"*)
            suggestion="kill -9 \$(pgrep process_name)"
            explanation="Force-kills a process by name. Replace 'process_name'." ;;
        *"permission"*|*"chmod"*)
            suggestion="chmod 755 filename"
            explanation="Sets read/write/execute for owner, read/execute for others." ;;
        *"log"*|*"journal"*)
            suggestion="journalctl -xe --no-pager | tail -50"
            explanation="Shows the last 50 system log entries with details." ;;
        *"install"*)
            suggestion="sudo dnf install package-name"
            explanation="Installs a package using DNF (Fedora package manager)." ;;
        *"service"*|*"systemctl"*)
            suggestion="systemctl status service-name"
            explanation="Checks the status of a systemd service." ;;
        *)
            suggestion="# No exact match found for: $task"
            explanation="Try describing your task differently, e.g. 'show disk space', 'list processes', 'find a file'." ;;
    esac

    local action
    action=$(zenity --question \
        --title="💡 Command Suggestion" \
        --text="<b>Task:</b> $task\n\n<b>Suggested command:</b>\n<tt>$suggestion</tt>\n\n<b>Explanation:</b>\n$explanation\n\n<i>Copy this command to clipboard?</i>" \
        --ok-label="Copy to Clipboard" \
        --cancel-label="Dismiss" \
        --width=500)

    if [[ $? -eq 0 ]]; then
        echo "$suggestion" | xclip -selection clipboard 2>/dev/null || \
        echo "$suggestion" | xsel --clipboard --input 2>/dev/null || true
        zenity --info --title="Copied!" --text="Command copied!\n\n<tt>$suggestion</tt>" --width=360
    fi
}

# ─── VIEW: Status dashboard ──────────────────────────────────
show_status() {
    local status_icon="⭕ INACTIVE"
    local pid_info="None"
    local log_count
    log_count=$(ls "$LOG_DIR"/*.log 2>/dev/null | wc -l)
    local last_log="None"

    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        status_icon="🔴 ACTIVE"
        pid_info="PID: $(cat "$PID_FILE")"
        last_log="$LOG_FILE"
    else
        last_log=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
        last_log="${last_log:-None}"
    fi

    zenity --info \
        --title="📊 System Status" \
        --text="<b>Keyboard Monitor — Status Dashboard</b>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<b>Monitoring Status:</b>  $status_icon
<b>Process:</b>           $pid_info
<b>Indicator:</b>         $( [[ -f "$INDICATOR_FILE" ]] && echo "🔴 Visible" || echo "⚫ Hidden")
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<b>Total Log Files:</b>   $log_count
<b>Log Directory:</b>
<tt>$LOG_DIR</tt>
<b>Last Log File:</b>
<tt>$(basename "$last_log")</tt>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<b>System:</b>            $(uname -r)
<b>User:</b>              $(logname 2>/dev/null || echo $SUDO_USER)
<b>Time:</b>              $(date '+%Y-%m-%d %H:%M:%S')" \
        --width=480
}

# ─── VIEW: Clear old logs ────────────────────────────────────
clear_logs() {
    local count
    count=$(ls "$LOG_DIR"/*.log 2>/dev/null | wc -l)

    if [[ $count -eq 0 ]]; then
        zenity --info --title="No Logs" --text="No log files to delete." --width=260
        return
    fi

    zenity --question \
        --title="🗑 Clear Logs" \
        --text="<b>Delete all log files?</b>\n\nFound <b>$count</b> log file(s) in:\n<tt>$LOG_DIR</tt>\n\n<i>This action cannot be undone.</i>" \
        --ok-label="Delete All" \
        --cancel-label="Cancel" \
        --width=380

    if [[ $? -eq 0 ]]; then
        rm -f "$LOG_DIR"/*.log
        zenity --info --title="Done" --text="All log files deleted." --width=260
    fi
}

# ─── MAIN MENU ───────────────────────────────────────────────
main_menu() {
    while true; do
        local monitor_label="▶ Start Monitoring"
        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            monitor_label="⏹ Stop Monitoring  [ACTIVE 🔴]"
        fi

        local choice
        choice=$(zenity --list \
            --title="🖥 Keyboard Input Monitor — Bahria University OS Project" \
            --text="<b>Welcome, $(logname 2>/dev/null || echo ${SUDO_USER:-user})</b>\nSelect an option:" \
            --column="Action" \
            --width=500 --height=420 \
            "$monitor_label" \
            "📊 View Status" \
            "📋 View Logs" \
            "💡 Command Suggestions" \
            "🤖 Command Assistant" \
            "🗑 Clear Logs" \
            "❌ Exit")

        [[ $? -ne 0 || -z "$choice" || "$choice" == "❌ Exit" ]] && break

        case "$choice" in
            *"Start Monitoring"*) start_monitoring ;;
            *"Stop Monitoring"*)  stop_monitoring  ;;
            *"View Status"*)      show_status       ;;
            *"View Logs"*)        view_logs         ;;
            *"Command Suggestions"*) command_suggestions ;;
            *"Command Assistant"*)   command_assistant   ;;
            *"Clear Logs"*)       clear_logs        ;;
        esac
    done

    # Cleanup on exit
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        zenity --question \
            --title="Exit" \
            --text="Monitoring is still <b>active</b>. Stop it before exiting?" \
            --ok-label="Stop & Exit" --cancel-label="Exit Anyway" --width=340
        [[ $? -eq 0 ]] && stop_monitoring
    fi
}

# ─── ENTRY POINT ─────────────────────────────────────────────
check_root
check_deps
main_menu
