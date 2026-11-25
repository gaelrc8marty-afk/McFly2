#!/usr/bin/env bash
# Diagnostic Wi-Fi / box — macOS et Linux.
# Usage : bash wifi_diag.sh > rapport.txt 2>&1
# Lecture seule : ne modifie aucun réglage.

section() { printf '\n===== %s =====\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

OS=$(uname -s)
section "Système"
uname -a

section "Passerelle (box)"
if [ "$OS" = "Darwin" ]; then
  GW=$(route -n get default 2>/dev/null | awk '/gateway/ {print $2}')
else
  GW=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')
fi
echo "Passerelle : ${GW:-inconnue}"

section "Connexion Wi-Fi actuelle"
if [ "$OS" = "Darwin" ]; then
  IF=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}')
  echo "Interface : $IF"
  # system_profiler donne RSSI, bruit, canal, PHY, débit
  system_profiler SPAirPortDataType 2>/dev/null | sed -n '/Current Network Information/,/Other Local Wi-Fi Networks/p'
else
  if have nmcli; then
    nmcli -f IN-USE,SSID,BSSID,CHAN,FREQ,RATE,SIGNAL,SECURITY dev wifi list --rescan no | grep '^\*'
  fi
  IF=$(iw dev 2>/dev/null | awk '/Interface/ {print $2; exit}')
  echo "Interface : $IF"
  [ -n "$IF" ] && iw dev "$IF" link 2>/dev/null
  [ -n "$IF" ] && iw dev "$IF" station dump 2>/dev/null | grep -E 'signal|bitrate|retries|failed'
fi

section "Réseaux voisins (encombrement des canaux)"
if [ "$OS" = "Darwin" ]; then
  system_profiler SPAirPortDataType 2>/dev/null | sed -n '/Other Local Wi-Fi Networks/,$p' | grep -E 'Channel|Signal' | head -80
elif have nmcli; then
  nmcli -f SSID,BSSID,CHAN,FREQ,SIGNAL,SECURITY dev wifi list --rescan yes
fi

section "Latence et pertes vers la box (50 pings)"
[ -n "$GW" ] && ping -c 50 -i 0.2 "$GW" 2>/dev/null | tail -3

section "Latence et pertes vers Internet (1.1.1.1)"
ping -c 30 -i 0.3 1.1.1.1 2>/dev/null | tail -3

section "Résolution DNS"
if [ "$OS" = "Darwin" ]; then scutil --dns | grep nameserver | sort -u; else cat /etc/resolv.conf 2>/dev/null | grep nameserver; fi
for h in google.com cloudflare.com; do
  /usr/bin/time -p nslookup "$h" >/dev/null 2>/tmp/dnst.$$ ; grep real /tmp/dnst.$$ | sed "s/^/$h /"
done
rm -f /tmp/dnst.$$

section "Débit (si speedtest / networkQuality disponible)"
if [ "$OS" = "Darwin" ] && have networkQuality; then networkQuality -s
elif have speedtest; then speedtest --simple 2>/dev/null || speedtest
elif have speedtest-cli; then speedtest-cli --simple
else echo "Aucun outil de débit trouvé (installez speedtest-cli ou testez sur fast.com)"; fi

section "Appareils vus sur le réseau local"
arp -a 2>/dev/null | head -60

echo
echo "Terminé. Renvoyez le contenu de ce rapport pour analyse."
