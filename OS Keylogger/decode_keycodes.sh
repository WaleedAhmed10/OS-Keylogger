#!/bin/bash
# ============================================================
#  Keycode Decoder — Pure Bash
#  Decodes raw keycode log entries into readable text
#  Usage: ./decode_keycodes.sh logs/<filename>.log
# ============================================================

LOG_FILE="$1"

if [[ -z "$LOG_FILE" || ! -f "$LOG_FILE" ]]; then
    echo "Usage: ./decode_keycodes.sh <logfile>"
    echo ""
    echo "Available logs:"
    ls -t logs/*.log 2>/dev/null | head -10 | sed 's/^/  /'
    exit 1
fi

# ─── KEYCODE → CHARACTER MAP ─────────────────────────────────
decode_key() {
    local key="$1"
    case "$key" in
        KEY_A) echo -n "a" ;; KEY_B) echo -n "b" ;; KEY_C) echo -n "c" ;;
        KEY_D) echo -n "d" ;; KEY_E) echo -n "e" ;; KEY_F) echo -n "f" ;;
        KEY_G) echo -n "g" ;; KEY_H) echo -n "h" ;; KEY_I) echo -n "i" ;;
        KEY_J) echo -n "j" ;; KEY_K) echo -n "k" ;; KEY_L) echo -n "l" ;;
        KEY_M) echo -n "m" ;; KEY_N) echo -n "n" ;; KEY_O) echo -n "o" ;;
        KEY_P) echo -n "p" ;; KEY_Q) echo -n "q" ;; KEY_R) echo -n "r" ;;
        KEY_S) echo -n "s" ;; KEY_T) echo -n "t" ;; KEY_U) echo -n "u" ;;
        KEY_V) echo -n "v" ;; KEY_W) echo -n "w" ;; KEY_X) echo -n "x" ;;
        KEY_Y) echo -n "y" ;; KEY_Z) echo -n "z" ;;
        KEY_1) echo -n "1" ;; KEY_2) echo -n "2" ;; KEY_3) echo -n "3" ;;
        KEY_4) echo -n "4" ;; KEY_5) echo -n "5" ;; KEY_6) echo -n "6" ;;
        KEY_7) echo -n "7" ;; KEY_8) echo -n "8" ;; KEY_9) echo -n "9" ;;
        KEY_0) echo -n "0" ;;
        KEY_SPACE)      echo -n " "        ;;
        KEY_ENTER)      echo ""            ;;
        KEY_TAB)        echo -n "    "     ;;
        KEY_BACKSPACE)  echo -n "[BKSP]"   ;;
        KEY_LEFTSHIFT|KEY_RIGHTSHIFT) echo -n "[SHIFT]" ;;
        KEY_LEFTCTRL|KEY_RIGHTCTRL)   echo -n "[CTRL]"  ;;
        KEY_LEFTALT|KEY_RIGHTALT)     echo -n "[ALT]"   ;;
        KEY_CAPSLOCK)   echo -n "[CAPS]"   ;;
        KEY_ESC)        echo -n "[ESC]"    ;;
        KEY_DELETE)     echo -n "[DEL]"    ;;
        KEY_UP)         echo -n "[↑]"      ;;
        KEY_DOWN)       echo -n "[↓]"      ;;
        KEY_LEFT)       echo -n "[←]"      ;;
        KEY_RIGHT)      echo -n "[→]"      ;;
        KEY_DOT)        echo -n "."        ;;
        KEY_COMMA)      echo -n ","        ;;
        KEY_SEMICOLON)  echo -n ";"        ;;
        KEY_SLASH)      echo -n "/"        ;;
        KEY_MINUS)      echo -n "-"        ;;
        KEY_EQUAL)      echo -n "="        ;;
        KEY_LEFTBRACE)  echo -n "["        ;;
        KEY_RIGHTBRACE) echo -n "]"        ;;
        *)              echo -n "[$key]"   ;;
    esac
}

# ─── DECODE THE LOG FILE ─────────────────────────────────────
OUT_FILE="${LOG_FILE%.log}_decoded.txt"

echo "================================================" | tee "$OUT_FILE"
echo " DECODED KEY LOG: $(basename "$LOG_FILE")"        | tee -a "$OUT_FILE"
echo " Decoded at: $(date '+%Y-%m-%d %H:%M:%S')"        | tee -a "$OUT_FILE"
echo "================================================" | tee -a "$OUT_FILE"

while IFS= read -r line; do
    # Pass through header/separator lines as-is
    if [[ "$line" == =* || "$line" == " SESSION"* || "$line" == " REASON"* || "$line" == " USER"* ]]; then
        echo "$line" | tee -a "$OUT_FILE"
        continue
    fi

    # Extract timestamp and KEY_ tokens from the line
    ts=$(echo "$line" | grep -oP '^\d{2}:\d{2}:\d{2}')
    keys=$(echo "$line" | grep -oP 'KEY_\w+')

    [[ -z "$keys" ]] && continue

    # Skip release events
    echo "$line" | grep -qi "release" && continue

    printf "%s  →  " "$ts" | tee -a "$OUT_FILE"
    while IFS= read -r key; do
        decode_key "$key" | tee -a "$OUT_FILE"
    done <<< "$keys"
    echo "" | tee -a "$OUT_FILE"

done < "$LOG_FILE"

echo "================================================" | tee -a "$OUT_FILE"
echo ""
echo "Decoded output saved to: $OUT_FILE"
