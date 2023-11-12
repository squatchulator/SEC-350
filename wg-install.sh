#!/bin/bash

sudo apt update
sudo apt install wireguard -y

echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

sudo touch /etc/wireguard/wg0.conf
sudo touch /etc/wireguard/wg0-client.conf

export USERNAME="squatchulator"
export PASSKEY="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"

cd
git clone https://$USERNAME:$PASSKEY@github.com/squatchulator/SEC-350.git

sudo chmod -R +wrx /etc/wireguard

sudo wg genkey | sudo tee /etc/wireguard/server-priv | sudo wg pubkey > /etc/wireguard/server-pub
export SERVERPRIV=$(sudo cat /etc/wireguard/server-priv)
export SERVERPUB=$(sudo cat /etc/wireguard/server-pub)

sudo wg genkey | sudo tee /etc/wireguard/client-priv | sudo wg pubkey > /etc/wireguard/client-pub
export CLIENTPRIV=$(sudo cat /etc/wireguard/client-priv)
export CLIENTPUB=$(sudo cat /etc/wireguard/client-pub)

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

sudo ufw allow 7890/udp
sudo ufw disable
sudo ufw enable

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

sudo wg-quick up wg0

cd
sudo cp -R /etc/wireguard SEC-350
cd SEC-350
sudo chmod -R +wrx wireguard
git add .
git config --global user.email "miles.cummings@mymail.champlain.edu"
git config --global user.name "squatchulator"
git commit -m "Automated push of Wireguard configs"
git push
