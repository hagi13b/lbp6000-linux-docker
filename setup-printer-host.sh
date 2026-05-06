#!/bin/bash

# 設定
SERVICE_FILE="/etc/avahi/services/lbp6000.service"
PRINTER_NAME="Canon LBP6000"
PRINTER_IP=$(hostname -I | awk '{print $1}')

echo "--- Canon LBP6000 ホスト側設定を開始します ---"

# 1. Avahi がインストールされていない場合はインストール
if ! dpkg -l | grep -q avahi-daemon; then
    echo "[1/3] avahi-daemon をインストールしています..."
    sudo apt-get update && sudo apt-get install -y avahi-daemon avahi-utils
else
    echo "[1/3] avahi-daemon は既にインストールされています。"
fi

# 2. サービス設定ファイルの作成
echo "[2/3] mDNS 通知の設定中..."

# 比較用のテンポラリファイル
TEMP_CONF=$(mktemp)

cat <<EOF > "$TEMP_CONF"
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">$PRINTER_NAME</name>
  <service>
    <type>_ipp._tcp</type>
    <port>631</port>
    <txt-record>txtvers=1</txt-record>
    <txt-record>qtotal=1</txt-record>
    <txt-record>rp=printers/LBP6000</txt-record>
    <txt-record>ty=Canon LBP6000</txt-record>
    <txt-record>adminurl=http://$PRINTER_IP:631/printers/LBP6000</txt-record>
    <txt-record>note=Docker Server</txt-record>
    <txt-record>pdl=application/octet-stream,application/pdf,image/pwg-raster</txt-record>
    <txt-record>Color=F</txt-record>
  </service>
</service-group>
EOF

# 設定に変更がある場合のみ更新し、サービスの再起動フラグを立てる
if [ ! -f "$SERVICE_FILE" ] || ! cmp -s "$TEMP_CONF" "$SERVICE_FILE"; then
    echo "$SERVICE_FILE の設定を更新します"
    sudo cp "$TEMP_CONF" "$SERVICE_FILE"
    RESTART_NEEDED=true
else
    echo "設定は最新です。変更は不要です。"
    RESTART_NEEDED=false
fi

rm "$TEMP_CONF"

# 3. サービスの管理
echo "[3/3] サービスの状態を確認中..."
sudo systemctl enable avahi-daemon

if [ "$RESTART_NEEDED" = true ]; then
    echo "変更を適用するため avahi-daemon を再起動します..."
    sudo systemctl restart avahi-daemon
else
    if ! systemctl is-active --quiet avahi-daemon; then
        echo "avahi-daemon を起動します..."
        sudo systemctl start avahi-daemon
    else
        echo "Avahi は最新の設定で既に動作しています。"
    fi
fi

echo "--- 設定完了 ---"
echo "プリンタ名: $PRINTER_NAME として検出されるはずです。"