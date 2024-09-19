#!/bin/bash

# Cài đặt FRP client tự động
FRP_VERSION="0.45.0"
SERVER_IP="103.77.166.69"
LOCAL_PORT=8080
FRP_USER="duyhuynh"
FRP_PASS="Anhduy3112"
SHEET_ID="1Qpvk0UCJm4CRT3xTonuIduD5BT1CD2lt926JZo8iD-I"  # ID của Google Sheets từ link bạn cung cấp
API_KEY="AIzaSyDpnvTdJsrRBXtbrCKwYjJ3ijFdMtp-3pk"  # Google Sheets API Key của bạn

# Lấy hostname từ file /opt/autorun
# Tìm chuỗi *****:localhost:22 và trích xuất 4-5 ký tự số (*****)
HOSTNAME=$(grep -oP '\d{4,5}(?=:localhost:22)' /opt/autorun)

# Nếu không tìm thấy hostname, sử dụng giá trị mặc định
if [ -z "$HOSTNAME" ]; then
  HOSTNAME="Unknown"
fi

# Lấy danh sách các cổng đã sử dụng từ Google Sheets
USED_PORTS=$(curl -s "https://sheets.googleapis.com/v4/spreadsheets/$SHEET_ID/values/Sheet1!B2:B?key=$API_KEY" | grep -o '[0-9]\+')

# Tìm một remote port chưa được sử dụng trong khoảng 12000-12100
REMOTE_PORT=""
for port in $(seq 12000 12100); do
  if ! echo "$USED_PORTS" | grep -q "$port"; then
    REMOTE_PORT=$port
    break
  fi
done

# Nếu không tìm thấy remote port, thoát với thông báo lỗi
if [ -z "$REMOTE_PORT" ]; then
  echo "Không tìm thấy cổng nào khả dụng. Hãy kiểm tra lại Google Sheets."
  exit 1
fi

# Tải và cài đặt FRP client
wget https://github.com/fatedier/frp/releases/download/v$FRP_VERSION/frp_${FRP_VERSION}_linux_amd64.tar.gz
tar -xvzf frp_${FRP_VERSION}_linux_amd64.tar.gz
cd frp_${FRP_VERSION}_linux_amd64

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

# Tạo dịch vụ systemd cho FRP client
echo "Creating systemd service for FRP client..."
sudo bash -c 'cat <<EOT > /etc/systemd/system/frpc.service
[Unit]
Description=FRP Client Service
After=network.target

[Service]
ExecStart=/path/to/frp_${FRP_VERSION}_linux_amd64/frpc -c /path/to/frp_${FRP_VERSION}_linux_amd64/frpc.ini
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT'

# Thay thế /path/to với đường dẫn chính xác
sudo sed -i "s|/path/to/frp_${FRP_VERSION}_linux_amd64|$(pwd)|g" /etc/systemd/system/frpc.service

# Kích hoạt và khởi động dịch vụ FRP client
sudo systemctl enable frpc
sudo systemctl start frpc

# Gửi thông tin tới Google Sheets (lưu vào hàng mới mỗi lần chạy)
echo "Sending info to Google Sheets..."
curl -X POST -H "Content-Type: application/json" \
     -d '{
           "range": "Sheet1!A1:C1",  # Cột từ A đến C
           "majorDimension": "ROWS",
           "values": [
               ["'$HOSTNAME'", "'$REMOTE_PORT'", "'$LOCAL_PORT'"]
           ]
         }' \
     "https://sheets.googleapis.com/v4/spreadsheets/$SHEET_ID/values/Sheet1!A1:append?valueInputOption=USER_ENTERED&key=$API_KEY"

echo "FRP client setup complete and running as a service!"
