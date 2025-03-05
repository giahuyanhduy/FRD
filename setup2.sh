#!/bin/bash

# Đường dẫn cài đặt FRPC
FRP_DIR="/root/frp_0.54.0_linux_amd64"
FRP_VERSION="0.54.0"

# Xác định kiến trúc
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
        ;;
    aarch64)
        FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_arm64.tar.gz"
        ;;
    armv7l)
        FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_arm.tar.gz"
        ;;
    *)
        echo "Kiến trúc $ARCH không hỗ trợ!"
        exit 1
        ;;
esac

# Xóa FRPC cũ
[ -d "$FRP_DIR" ] && echo "Xóa FRPC cũ..." && rm -rf "$FRP_DIR"
[ -f "/opt/start_frpc.sh" ] && echo "Xóa script cũ..." && rm -f "/opt/start_frpc.sh"
[ -f "/etc/systemd/system/frpc.service" ] && echo "Xóa dịch vụ cũ..." && systemctl stop frpc 2>/dev/null && systemctl disable frpc 2>/dev/null && rm -f "/etc/systemd/system/frpc.service"

# Tải và cài FRPC
cd /root
wget -q $FRP_URL -O frp.tar.gz
tar -xzf frp.tar.gz
rm frp.tar.gz
mv frp_${FRP_VERSION}_linux_* $FRP_DIR
cd $FRP_DIR
chmod +x frpc

# Tạo file frpc.ini.template không lưu log
cat > frpc.ini.template << 'EOF'
[common]
server_addr = 103.77.166.69
server_port = 9000
token = Anhduy3112

[socks5]
type = tcp
remote_port = REPLACE_PORT
plugin = socks5
plugin_user = duyhuynh
plugin_passwd = Anhduy
EOF

# Tạo script start_frpc.sh với kiểm tra lỗi
cat > /opt/start_frpc.sh << 'EOF'
#!/bin/bash
if [ ! -f /opt/autorun ]; then
    echo "Lỗi: File /opt/autorun không tồn tại!"
    exit 1
fi
PORT=$(cat /opt/autorun | grep -oP '\d+(?=:localhost:22)')
if [ -z "$PORT" ]; then
    echo "Lỗi: Không tìm thấy cổng trong /opt/autorun!"
    exit 1
fi
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "Lỗi: PORT ($PORT) không phải số nguyên!"
    exit 1
fi
sed "s/REPLACE_PORT/$PORT/" /root/frp_0.54.0_linux_amd64/frpc.ini.template > /root/frp_0.54.0_linux_amd64/frpc.ini
/root/frp_0.54.0_linux_amd64/frpc -c /root/frp_0.54.0_linux_amd64/frpc.ini
EOF
chmod +x /opt/start_frpc.sh

# Tạo file dịch vụ systemd
cat > /etc/systemd/system/frpc.service << 'EOF'
[Unit]
Description=FRP Client Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /opt/start_frpc.sh
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Kích hoạt và khởi động
systemctl daemon-reload
systemctl enable frpc
systemctl start frpc

echo "FRPC cài đặt xong với INI, không lưu log. Kiểm tra: systemctl status frpc"
