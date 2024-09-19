#!/bin/bash

# Cài đặt thông tin của client
FRP_VERSION="0.60.0"
SERVER_IP="103.77.166.69"
LOCAL_PORT=8080
FRP_USER="duyhuynh"
FRP_PASS="Anhduy3112"
API_SERVER="http://103.77.166.69"

# Cài đặt jq nếu chưa có
echo "Installing jq..."
apt-get install -y jq 

# Lấy tên máy (hostname) từ file /opt/autorun
if [ -f "/opt/autorun" ]; then
    HOSTNAME=$(grep -oP '\d{4,5}(?=:localhost:22)' /opt/autorun)
else
    HOSTNAME=$(hostname)
fi

if [ -z "$HOSTNAME" ]; then
    echo "No hostname found in /opt/autorun, using default hostname."
    HOSTNAME=$(hostname)
fi

# Lấy danh sách các cổng đã sử dụng từ server qua file JSON
echo "Fetching used ports from server..."
USED_PORTS=$(curl -s $API_SERVER/used_ports | jq -r '.used_ports[]')

# Chọn cổng không trùng với các cổng đã sử dụng
REMOTE_PORT=12000
for port in $(seq 12000 12100); do
  if [[ ! " ${USED_PORTS[@]} " =~ " ${port} " ]]; then
    REMOTE_PORT=$port
    break
  fi
done

# Cài đặt FRP client
echo "Installing FRP client..."
mkdir -p /usr/local/frp
cd /usr/local/frp
wget https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz
tar -xvzf frp_${FRP_VERSION}_linux_amd64.tar.gz
rm frp_${FRP_VERSION}_linux_amd64.tar.gz

# Tạo file cấu hình frpc.toml
echo "Creating frpc.toml file..."
cat <<EOT > frpc.toml
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

if [ -f "frpc.toml" ]; then
    echo "frpc.toml created successfully."
else
    echo "Failed to create frpc.toml."
    exit 1
fi

# Tạo file dịch vụ systemd cho FRP client
echo "Creating systemd service file..."
cat <<EOT > /etc/systemd/system/frpc.service
[Unit]
Description=FRP Client Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/frp/frpc -c /usr/local/frp/frpc.toml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT

# Kích hoạt và khởi động dịch vụ FRP
echo "Reloading systemd and starting FRP service..."
systemctl daemon-reload
systemctl enable frpc
systemctl start frpc

# Gửi thông tin client lên API server
echo "Sending client info to server..."
curl -X POST $API_SERVER/client_data \
-H "Content-Type: application/json" \
-d '{
    "hostname": "'"$HOSTNAME"'",
    "remote_port": '"$REMOTE_PORT"',
    "local_port": '"$LOCAL_PORT"'
}'

echo "Client info sent successfully!"
