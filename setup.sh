#!/bin/bash

# Cài đặt thông tin của client
FRP_VERSION="0.60.0"
SERVER_IP="103.77.166.69"
LOCAL_PORT=8080
FRP_USER="duyhuynh"
FRP_PASS="Anhduy3112"
API_SERVER="http://103.77.166.69"

# Lấy tên máy (hostname) của client
HOSTNAME=$(hostname)

# Lấy danh sách các cổng đã sử dụng từ server qua file JSON
USED_PORTS=$(curl -s $API_SERVER/used_ports | jq -r '.used_ports[]')

# Chọn cổng ngẫu nhiên từ 12000 đến 12100 nhưng không trùng với các cổng đã sử dụng
REMOTE_PORT=12000
for port in $(seq 12000 12100); do
  if [[ ! " ${USED_PORTS[@]} " =~ " ${port} " ]]; then
    REMOTE_PORT=$port
    break
  fi
done

# Cài đặt FRP client
mkdir -p /usr/local/frp
cd /usr/local/frp
wget https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz
tar -xvzf frp_${FRP_VERSION}_linux_amd64.tar.gz
rm frp_${FRP_VERSION}_linux_amd64.tar.gz

# Tạo file cấu hình frpc.ini
cat <<EOT > frpc.ini
[common]
server_addr = $SERVER_IP
server_port = 7000
tcp_mux = true
tcp_mux.keepalive_interval = 30

[proxy]
type = http
local_port = $LOCAL_PORT
remote_port = $REMOTE_PORT
http_user = $FRP_USER
http_passwd = $FRP_PASS
EOT

# Tạo file dịch vụ systemd cho FRP client
cat <<EOT > /etc/systemd/system/frpc.service
[Unit]
Description=FRP Client Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/frp/frpc -c /usr/local/frp/frpc.ini
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT

# Kích hoạt và khởi động dịch vụ FRP
systemctl daemon-reload
systemctl enable frpc
systemctl start frpc

# Gửi thông tin client lên API server tại 103.77.166.69
echo "Sending client info to server..."

curl -X POST $API_SERVER/client_data \
-H "Content-Type: application/json" \
-d '{
    "hostname": "'"$HOSTNAME"'",
    "remote_port": '"$REMOTE_PORT"',
    "local_port": '"$LOCAL_PORT"'
}'

echo "Client info sent successfully!"
