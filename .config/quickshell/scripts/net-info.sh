#!/bin/sh
# Details of network interface $1 for the Wi-Fi and Ethernet hover cards (modules/WifiCard.qml,
# modules/EthernetCard.qml). Prints key=value lines; keys are missing when they don't apply.

if="$1"

# NetworkManager profile name, MAC address, and for cables the negotiated speed (Mb/s, -1 when
# unknown) and duplex.
echo "conn=$(nmcli -g GENERAL.CONNECTION device show "$if" 2>/dev/null)"
sys=/sys/class/net/$if
echo "mac=$(cat "$sys/address" 2>/dev/null)"
[ -e "$sys/wireless" ] || [ -e "$sys/phy80211" ] || {
    echo "speed=$(cat "$sys/speed" 2>/dev/null)"
    echo "duplex=$(cat "$sys/duplex" 2>/dev/null)"
}

# Wi-Fi: channel, frequency and security of the network in use ("*"). SSID is left out: it may contain ':'.
nmcli -t -f IN-USE,CHAN,FREQ,SECURITY device wifi list ifname "$if" --rescan no 2>/dev/null |
    awk -F: '$1 == "*" { print "chan=" $2; sub(/ MHz/, "", $3); print "freq=" $3; print "security=" $4; exit }'

# One line per field; several values are joined with " | ".
nmcli -g IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show "$if" 2>/dev/null | {
    read -r ip; read -r gateway; read -r dns
    echo "ip=$ip"
    echo "gateway=$gateway"
    echo "dns=$dns"
}

# "signal: -52 dBm", "rx bitrate: 866.7 MBit/s VHT-MCS 9 80MHz short GI VHT-NSS 2"
iw dev "$if" link 2>/dev/null | awk '
    /signal:/ { print "dbm=" $2 }
    /tx bitrate:/ { print "tx=" $3 }
    /rx bitrate:/ {
        print "rx=" $3
        for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+MHz$/) print "width=" substr($i, 1, length($i) - 3)
        if (/EHT-/) print "gen=7"; else if (/HE-/) print "gen=6"; else if (/VHT-/) print "gen=5"; else if (/HT-/) print "gen=4"
    }'
