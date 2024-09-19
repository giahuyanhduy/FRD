#!/bin/bash

# Cài đặt Python và các thư viện cần thiết cho Google Sheets API

apt install -y python3 python3-pip
pip3 install --upgrade google-api-python-client google-auth-httplib2 google-auth-oauthlib

# Tải file client_secret.json từ GitHub (hoặc lưu cục bộ)
wget https://raw.githubusercontent.com/giahuyanhduy/FRD/main/client.json -O client.json

# Đặt đường dẫn tới token và client_secret.json
TOKEN_PATH="token.json"  # Token sẽ được tạo tự động khi lần đầu xác thực
CLIENT_SECRET_PATH="/root/client.json"

# Cài đặt thông tin Google Sheets API
SPREADSHEET_ID="1Qpvk0UCJm4CRT3xTonuIduD5BT1CD2lt926JZo8iD-I"
RANGE_NAME="Sheet1!B:B"  # Cột B chứa các cổng đã sử dụng

# Tạo Python script để lấy danh sách cổng từ Google Sheets
cat <<EOPYTHON > check_ports.py
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
import os

SCOPES = ['https://www.googleapis.com/auth/spreadsheets.readonly']

TOKEN_PATH = '$TOKEN_PATH'
CLIENT_SECRET_PATH = '$CLIENT_SECRET_PATH'

def get_used_ports():
    creds = None
    if os.path.exists(TOKEN_PATH):
        creds = Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES)
    else:
        flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRET_PATH, SCOPES)
        creds = flow.run_local_server(port=0)
        with open(TOKEN_PATH, 'w') as token:
            token.write(creds.to_json())

    service = build('sheets', 'v4', credentials=creds)
    sheet = service.spreadsheets()
    result = sheet.values().get(spreadsheetId="$SPREADSHEET_ID", range="$RANGE_NAME").execute()
    values = result.get('values', [])
    used_ports = [int(row[0]) for row in values if row]
    return used_ports

if __name__ == '__main__':
    used_ports = get_used_ports()
    print(used_ports)
EOPYTHON

# Lấy danh sách cổng đã sử dụng từ Google Sheets
USED_PORTS=$(python3 check_ports.py)

# Tìm cổng chưa được sử dụng
REMOTE_PORT=12000
for port in $(seq 12000 12100); do
  if [[ ! "$USED_PORTS" =~ "$port" ]]; then
    REMOTE_PORT=$port
    break
  fi
done

# Cài đặt FRP client
FRP_VERSION="0.60.0"
SERVER_IP="103.77.166.69"
LOCAL_PORT=8080
FRP_USER="duyhuynh"
FRP_PASS="Anhduy3112"

# Tạo file cấu hình cho FRP client
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

# Gửi thông tin cổng mới lên Google Sheets
cat <<EOPYTHON > append_ports.py
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
import os

SCOPES = ['https://www.googleapis.com/auth/spreadsheets']

TOKEN_PATH = '$TOKEN_PATH'
CLIENT_SECRET_PATH = '$CLIENT_SECRET_PATH'

def append_port(hostname, remote_port, local_port):
    creds = None
    if os.path.exists(TOKEN_PATH):
        creds = Credentials.from_authorized_user_file(TOKEN_PATH, SCOPES)
    else:
        flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRET_PATH, SCOPES)
        creds = flow.run_local_server(port=0)
        with open(TOKEN_PATH, 'w') as token:
            token.write(creds.to_json())

    service = build('sheets', 'v4', credentials=creds)
    sheet = service.spreadsheets()
    values = [[hostname, remote_port, local_port]]
    body = {'values': values}
    result = sheet.values().append(spreadsheetId="$SPREADSHEET_ID", range="Sheet1!A1:C1", valueInputOption="USER_ENTERED", body=body).execute()
    print(f'{result.get("updates").get("updatedCells")} cells appended.')

if __name__ == '__main__':
    import socket
    hostname = socket.gethostname()
    append_port(hostname, "$REMOTE_PORT", "$LOCAL_PORT")
EOPYTHON

# Chạy script để gửi thông tin lên Google Sheets
python3 append_ports.py

# Xóa các file tạm thời
rm -f check_ports.py append_ports.py
