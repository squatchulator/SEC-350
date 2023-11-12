#!/bin/bash
# https://www.wireguard.com/quickstart/
# https://www.digitalocean.com/community/tutorials/how-to-set-up-wireguard-on-ubuntu-20-04 

sudo apt update
sudo apt install wireguard -y
# Enable port forwarding on this guy
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
# Create the configuration files
sudo touch /etc/wireguard/wg0.conf
sudo touch /etc/wireguard/wg0-client.conf
export USER=$(whoami)
sudo chown -R $USER /etc/wireguard
# Keygen for the server
wg genkey | tee /etc/wireguard/server-priv | wg pubkey > /etc/wireguard/server-pub
export SERVERPRIV=$(sudo cat /etc/wireguard/server-priv)
export SERVERPUB=$(sudo cat /etc/wireguard/server-pub)
# Keygen for the client
wg genkey | tee /etc/wireguard/client-priv | wg pubkey > /etc/wireguard/client-pub
export CLIENTPRIV=$(sudo cat /etc/wireguard/client-priv)
export CLIENTPUB=$(sudo cat /etc/wireguard/client-pub)
# Edit the config file 
sudo tee /etc/wireguard/wg0.conf > /dev/null <<EOF
[Interface]
PrivateKey = $SERVERPRIV
Address = 10.8.0.1/24
ListenPort = 7890
SaveConfig = true
PostUp = ufw route allow in on wg0 out on eth0
PostUp = iptables -t nat -A PREROUTING -d 10.8.0.1 -p tcp --dport 3389 -j DNAT --to-destination 172.16.200.11:3389
PostUp = iptables -t nat -A POSTROUTING -o ens160 -j MASQUERADE
PreDown = ufw route delete allow in on wg0 out on eth0
PreDown = iptables -t nat -D PREROUTING -d 10.8.0.1 -p tcp --dport 3389 -j DNAT --to-destination 172.16.200.11:3389
PreDown = iptables -t nat -D POSTROUTING -o ens160 -j MASQUERADE
[Peer]
PublicKey = $CLIENTPUB
AllowedIPs = 10.8.0.2/24
EOF
# Allow the port through the local firewall
sudo ufw allow 7890/udp
sudo ufw disable
sudo ufw enable
# Now, we need a config file for the client.
sudo tee /etc/wireguard/wg0-client.conf > /dev/null <<EOF
[Interface]
PrivateKey = $CLIENTPRIV
Address = 10.8.0.2/24
[Peer]
PublicKey = $SERVERPUB
AllowedIPs = 0.0.0.0/0
Endpoint = 10.0.17.114:7890
EOF