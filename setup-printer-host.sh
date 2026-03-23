#!/bin/bash

# Налаштування
SERVICE_FILE="/etc/avahi/services/lbp6000.service"
PRINTER_NAME="Canon LBP6000"
PRINTER_IP=$(hostname -I | awk '{print $1}')

echo "--- Початок налаштування хоста для Canon LBP6000 ---"

# 1. Встановлення Avahi, якщо його немає
if ! dpkg -l | grep -q avahi-daemon; then
    echo "[1/3] Встановлення avahi-daemon..."
    sudo apt-get update && sudo apt-get install -y avahi-daemon avahi-utils
else
    echo "[1/3] avahi-daemon вже встановлено."
fi

# 2. Створення конфігурації сервісу
echo "[2/3] Налаштування mDNS анонсу..."

# Тимчасовий файл для порівняння
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

# Перевіряємо, чи змінився конфіг, щоб не смикати сервіс дарма
if [ ! -f "$SERVICE_FILE" ] || ! cmp -s "$TEMP_CONF" "$SERVICE_FILE"; then
    echo "Оновлення конфігурації в $SERVICE_FILE"
    sudo cp "$TEMP_CONF" "$SERVICE_FILE"
    RESTART_NEEDED=true
else
    echo "Конфігурація актуальна, зміни не потрібні."
    RESTART_NEEDED=false
fi

rm "$TEMP_CONF"

# 3. Керування сервісом
echo "[3/3] Перевірка стану сервісу..."
sudo systemctl enable avahi-daemon

if [ "$RESTART_NEEDED" = true ]; then
    echo "Перезапуск avahi-daemon для застосування змін..."
    sudo systemctl restart avahi-daemon
else
    if ! systemctl is-active --quiet avahi-daemon; then
        echo "Старт avahi-daemon..."
        sudo systemctl start avahi-daemon
    else
        echo "Avahi вже працює з актуальним конфігом."
    fi
fi

echo "--- Налаштування завершено успішно! ---"
echo "Принтер має бути доступний як: $PRINTER_NAME"