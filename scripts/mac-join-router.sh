#!/bin/bash
# Move the Mac onto the ESP32 NAT router's AP, and fall back to the upstream
# network if internet doesn't come up — so a headless Mac never strands itself.
# Usage: scripts/mac-join-router.sh [timeout_s]   (reads .router-creds)
set -u
cd "$(dirname "$0")/.."
source .router-creds
IF=en0
TIMEOUT=${1:-60}
FALLBACK_SSID="${FALLBACK_SSID:-lighthouse-guest}"
LOG=/tmp/mac-join-router.log

online() { /usr/bin/curl -s -m 5 -o /dev/null https://discord.com/api/v10/gateway; }
diag() {
    echo "$(date) ip=$(/usr/sbin/ipconfig getifaddr "$IF") gw=$(/usr/sbin/ipconfig getoption "$IF" router)" \
         "raw_ip=$(/usr/bin/curl -s -m 4 -o /dev/null -w '%{http_code}' https://1.1.1.1)" \
         "dns=$(/usr/bin/curl -s -m 4 -o /dev/null -w '%{http_code}' https://discord.com)" >>"$LOG"
}

echo "$(date) joining $AP_SSID" >>"$LOG"
/usr/sbin/networksetup -setairportnetwork "$IF" "$AP_SSID" "$AP_PASS" >>"$LOG" 2>&1

start=$(date +%s)
while (( $(date +%s) - start < TIMEOUT )); do
    diag
    if online; then
        echo "$(date) online via $AP_SSID after $(( $(date +%s) - start ))s" >>"$LOG"
        exit 0
    fi
    sleep 3
done

echo "$(date) no internet via $AP_SSID, reverting to $FALLBACK_SSID" >>"$LOG"
if [[ -n "${FALLBACK_PASS:-}" ]]; then
    /usr/sbin/networksetup -setairportnetwork "$IF" "$FALLBACK_SSID" "$FALLBACK_PASS" >>"$LOG" 2>&1
else
    /usr/sbin/networksetup -setairportnetwork "$IF" "$FALLBACK_SSID" >>"$LOG" 2>&1
fi
exit 1
