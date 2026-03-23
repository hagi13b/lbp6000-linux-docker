FROM debian:bookworm-slim

# Уникаємо інтерактивних вікон
ENV DEBIAN_FRONTEND=noninteractive

# 1. Налаштування архітектури та встановлення системних ліб для Bookworm
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
    cups \
    cups-client \
    libpopt0:i386 \
    libxml2:i386 \
    libstdc++6:i386 \
    libgtk2.0-0:i386 \
    libpango-1.0-0:i386 \
    libpangocairo-1.0-0:i386 \
    libglib2.0-0:i386 \
    procps \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 2. Копіювання драйверів (мають бути в папці з Dockerfile)
COPY cndrvcups-common_3.20-1_amd64.deb /tmp/
COPY cndrvcups-capt_2.70-1_amd64.deb /tmp/

# 3. Встановлення драйверів силоміць (ігноруючи libpng12 та libglade)
RUN dpkg -i --force-depends /tmp/cndrvcups-common_3.20-1_amd64.deb && \
    dpkg -i --force-depends /tmp/cndrvcups-capt_2.70-1_amd64.deb && \
    rm /tmp/*.deb

# 4. Створення структури для CCPD та FIFO каналу
RUN mkdir -p /var/ccpd && \
    mkfifo /var/ccpd/fifo0 && \
    chown -R lp:lp /var/ccpd && \
    chmod 777 /var/ccpd/fifo0

# 5. Створення фінального скрипта запуску
RUN echo '#!/bin/bash\n\
# Стартуємо CUPS\n\
/usr/sbin/cupsd\n\
sleep 2\n\
\n\
# Дозволяємо віддалене керування (Пункт 2)\n\
cupsctl --remote-admin --remote-any --share-printers\n\
sed -i "s/<Location \/>/<Location \/>\\n  Allow All/" /etc/cups/cupsd.conf\n\
sed -i "s/<Location \/admin>/<Location \/admin>\\n  Allow All/" /etc/cups/cupsd.conf\n\
\n\
# Реєстрація принтера (Пункт 3)\n\
lpadmin -x LBP6000 2>/dev/null\n\
lpadmin -p LBP6000 -m CNCUPSLBP6018CAPTK.ppd -v ccp://localhost:59687 -E\n\
/usr/sbin/ccpdadmin -p LBP6000 -o /dev/usb/lp0\n\
\n\
# Запуск демона Canon\n\
/etc/init.d/ccpd restart\n\
\n\
echo "=========================================="\n\
echo "Принт-сервер LBP6000 запущено!"\n\
echo "CUPS доступний на порту 631"\n\
echo "Статус CCPD:"\n\
/etc/init.d/ccpd status\n\
echo "=========================================="\n\
\n\
# Тримаємо контейнер активним через логи\n\
tail -f /var/log/cups/error_log' > /entrypoint.sh && chmod +x /entrypoint.sh

# Відкриваємо стандартний порт CUPS
EXPOSE 631

ENTRYPOINT ["/entrypoint.sh"]