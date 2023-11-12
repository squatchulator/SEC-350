#!/bin/bash
# https://www.wireguard.com/quickstart/
# https://www.digitalocean.com/community/tutorials/how-to-set-up-wireguard-on-ubuntu-20-04
# ChatGPT
# https://www.freecodecamp.org/news/build-your-own-wireguard-vpn-in-five-minutes/
# TO INSTALL: wget -O wg-install.sh https://raw.githubusercontent.com/squatchulator/SEC-350/master/wg-install.sh
sudo apt update
sudo apt install wireguard -y
# Enable port forwarding on this guy
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
# Create the config files
sudo touch /etc/wireguard/wg0.conf
sudo touch /etc/wireguard/wg0-client.conf
# Create the env variables for my git creds so the whole process is automated
# NOTE: The passkey will expire really soon
export USERNAME="squatchulator"
export PASSKEY="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"
# Clone my repo so we can add configs to it later (GPT was very helpful figuring this out)
cd
git clone https://$USERNAME:$PASSKEY@github.com/squatchulator/SEC-350.git
# Allow for read/write/execute of all contents in wireguard directory
sudo chmod -R +wrx /etc/wireguard
# Keygen for the server
sudo wg genkey | sudo tee /etc/wireguard/server-priv | sudo wg pubkey > /etc/wireguard/server-pub
export SERVERPRIV=$(sudo cat /etc/wireguard/server-priv)
export SERVERPUB=$(sudo cat /etc/wireguard/server-pub)
# Keygen for the client
sudo wg genkey | sudo tee /etc/wireguard/client-priv | sudo wg pubkey > /etc/wireguard/client-pub
export CLIENTPRIV=$(sudo cat /etc/wireguard/client-priv)
export CLIENTPUB=$(sudo cat /etc/wireguard/client-pub)
# Edit the server config file
sudo tee /etc/wireguard/wg0.conf > /dev/null <<EOF
[Interface]
PrivateKey = $SERVERPRIV
Address = 10.8.0.1/24
ListenPort = 7890
SaveConfig = true
PreUp = ufw route allow in on wg0 out on eth0
PreUp = iptables -t nat -A PREROUTING -d 10.8.0.1 -p tcp --dport 3389 -j DNAT --to-destination 172.16.200.11:3389
PreUp = iptables -t nat -A POSTROUTING -o ens160 -j MASQUERADE
PostDown = ufw route delete allow in on wg0 out on eth0
PostDown = iptables -t nat -D PREROUTING -d 10.8.0.1 -p tcp --dport 3389 -j DNAT --to-destination 172.16.200.11:3389
PostDown = iptables -t nat -D POSTROUTING -o ens160 -j MASQUERADE
[Peer]
PublicKey = $CLIENTPUB
AllowedIPs = 10.8.0.2/24
EOF
# Allow the port through the local firewall, and restart it
sudo ufw allow 7890/udp
sudo ufw disable
sudo ufw enable
# Now, we need a config file for the client.
sudo tee /etc/wireguard/wg0-client.conf > /dev/null <<EOF
[Interface]
PrivateKey = $CLIENTPRIV
Address = 10.8.0.2/24
ListenPort = 7890
[Peer]
PublicKey = $SERVERPUB
AllowedIPs = 10.8.0.1/24
Endpoint = 10.0.17.114:7890
EOF
# Start the server
sudo wg-quick up wg0
# Time for git stuff.
cd
sudo cp -R /etc/wireguard SEC-350
cd SEC-350
sudo chmod -R +wrx wireguard
git add .
git config --global user.email "miles.cummings@mymail.champlain.edu"
git config --global user.name "squatchulator"
git commit -m "Automated push of Wireguard configs"
git push
