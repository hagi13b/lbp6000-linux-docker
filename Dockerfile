FROM debian:bookworm-slim

# インタラクティブなプロンプトを表示しない設定
ENV DEBIAN_FRONTEND=noninteractive

# 1. アーキテクチャの設定と Debian Bookworm 用のシステムライブラリのインストール
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

# 2. ドライバファイルのコピー
COPY cndrvcups-common_3.20-1_amd64.deb /tmp/
COPY cndrvcups-capt_2.70-1_amd64.deb /tmp/

# 3. 依存関係を無視してドライバを強制インストール
RUN dpkg -i --force-depends /tmp/cndrvcups-common_3.20-1_amd64.deb && \
    dpkg -i --force-depends /tmp/cndrvcups-capt_2.70-1_amd64.deb && \
    rm /tmp/*.deb

# 4. CCPD 用の構造と FIFO チャネルの作成
RUN mkdir -p /var/ccpd && \
    mkfifo /var/ccpd/fifo0 && \
    chown -R lp:lp /var/ccpd && \
    chmod 777 /var/ccpd/fifo0

# 5. 最終的な起動スクリプトの作成
RUN echo '#!/bin/bash\n\
# 起動前に CUPS のアクセス権限を修正\n\
chown -R lp:lp /var/spool/cups /var/cache/cups /etc/cups\n\
chmod -R 777 /var/spool/cups /var/cache/cups\n\
\n\
# CUPS サービスの開始\n\
/usr/sbin/cupsd\n\
sleep 2\n\
\n\
# リモート管理と共有を許可\n\
cupsctl --remote-admin --remote-any --share-printers\n\
sed -i "s/<Location \/>/<Location \/>\\n  Allow All/" /etc/cups/cupsd.conf\n\
sed -i "s/<Location \/admin>/<Location \/admin>\\n  Allow All/" /etc/cups/cupsd.conf\n\
\n\
# プリンタの登録\n\
lpadmin -x LBP6000 2>/dev/null\n\
lpadmin -p LBP6000 -m CNCUPSLBP6018CAPTK.ppd -v ccp://localhost:59687 -E\n\
\n\
# プリンタを共有設定にし、ジョブを受け付けるように明示\n\
lpadmin -p LBP6000 -o printer-is-shared=true -u allow:all\n\
cupsenable LBP6000\n\
cupsaccept LBP6000\n\
\n\
/usr/sbin/ccpdadmin -p LBP6000 -o /dev/usb/lp0\n\
\n\
# Canon CCPD デーモンの起動\n\
/etc/init.d/ccpd restart\n\
\n\
echo "=========================================="\n\
echo "LBP6000 プリントサーバーが起動しました！"\n\
echo "CCPD ステータス:"\n\
/etc/init.d/ccpd status\n\
echo "=========================================="\n\
\n\
# エラーログを監視し続けてコンテナを維持\n\
tail -f /var/log/cups/error_log' > /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 631
ENTRYPOINT ["/entrypoint.sh"]