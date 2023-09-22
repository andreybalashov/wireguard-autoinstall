#!/bin/bash

apt update && apt install -y wireguard curl tar ufw
cd /etc/wireguard

ufw allow 51820/udp

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf

cat <<EOF > /etc/wireguard/start-wgui.sh
#!/bin/bash
 
cd /etc/wireguard
./wireguard-ui -bind-address 0.0.0.0:5000
EOF

chmod +x start-wgui.sh

cat <<EOF > /etc/systemd/system/wgui-web.service
[Unit]
Description=WireGuard UI
 
[Service]
Type=simple
ExecStart=/etc/wireguard/start-wgui.sh
 
[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > /etc/wireguard/update.sh
#!/bin/bash
 
VER=\$(curl -sI https://github.com/ngoduykhanh/wireguard-ui/releases/latest | grep "location:" | cut -d "/" -f8 | tr -d '\r')
 
echo "downloading wireguard-ui \$VER"
curl -sL "https://github.com/ngoduykhanh/wireguard-ui/releases/download/\$VER/wireguard-ui-\$VER-linux-amd64.tar.gz" -o wireguard-ui-\$VER-linux-amd64.tar.gz
 
echo -n "extracting "; tar xvf wireguard-ui-\$VER-linux-amd64.tar.gz
 
echo "restarting wgui-web.service"
systemctl restart wgui-web.service
EOF

chmod +x /etc/wireguard/update.sh
cd /etc/wireguard; ./update.sh

cat <<EOF > /etc/systemd/system/wgui.service
[Unit]
Description=Restart WireGuard
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart wg-quick@wg0.service

[Install]
RequiredBy=wgui.path
EOF

cat <<EOF > /etc/systemd/system/wgui.path
[Unit]
Description=Watch /etc/wireguard/wg0.conf for changes

[Path]
PathModified=/etc/wireguard/wg0.conf

[Install]
WantedBy=multi-user.target
EOF

touch /etc/wireguard/wg0.conf
systemctl enable wgui.{path,service} wg-quick@wg0.service wgui-web.service
systemctl start wgui.{path,service}

