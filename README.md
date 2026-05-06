# Canon LBP6000 CAPT Docker プリントサーバー 🖨️

このプロジェクトは、名機 Canon LBP6000（LBP6018）を、Dockerを使用して最新のLinux環境（Debian 12以上、Ubuntu 22.04以上、Home Assistant OSなど）で動作させるためのものです。

最新のシステムライブラリと競合する古い32ビット版 Canon CAPT ドライバの問題を解決します。

---

## 📂 プロジェクト構成

ビルドを成功させるには、ディレクトリに以下のファイルが必要です：

- Dockerfile — Debian Bookworm i386 ベースのイメージ
- docker-compose.yml — 実行設定
- cndrvcups-common_3.20-1_amd64.deb — 共通ドライバコンポーネント
- cndrvcups-capt_2.70-1_amd64.deb — CAPT ドライバ本体
- setup-printer-host.sh — Avahi および mDNS 通知設定スクリプト

---

## 🛠 ステップ 1: ホストシステム（Linux）の準備

Dockerを起動する前に、使用するリソースを解放する必要があります。

### 1. ローカルの CUPS を停止する

```bash
sudo systemctl stop cups
sudo systemctl disable cups
```

### 2. 残っているドライバプロセスを強制終了する

```bash
sudo pkill -9 ccpd
sudo pkill -9 captfilter
```

### 3. USB接続を確認する

```bash
ls /dev/usb/lp0
```

このコマンドでデバイスが表示される必要があります。

### 4. Avahi を設定して mDNS アナウンスを行う

setup-printer-host.sh スクリプトは、Avahi を使用してプリンターを mDNS 経由で公開する設定を自動化します。以下を実行してください：

```bash
sudo ./setup-printer-host.sh
```

これにより、Bonjour / Avahi 経由でプリンターにアクセス可能になります。

---

## 🚀 ステップ 2: ビルドと起動

### 1. プロジェクトフォルダに移動

```bash
cd /opt/capt-lbp6000
```

### 2. コンテナを起動

```bash
docker compose up -d --build
```

### 3. 動作確認

```bash
docker exec -it lbp6000-server /etc/init.d/ccpd status
```

2つのPID番号が表示されるはずです。表示されない場合、プリンターは初期化されていません。

---

## 💻 ステップ 3: クライアント接続

プリンターは以下のアドレスで利用できます：

http://<サーバーのIPアドレス>:631/printers/LBP6000

---

### 🔹 Windows

1. 「設定 → プリンターとスキャナー → デバイスの追加」を開く
2. 「目的のプリンターが一覧にありません」をクリック
3. 「名前で共有プリンターを選択」を選択
4. 以下のURLを入力：

http://<サーバーのIPアドレス>:631/printers/LBP6000

5. ドライバー：
   - Generic → MS Publisher Imagesetter

---

### 🔹 Linux（Ubuntu / Mint / Arch）

通常、Avahi / Bonjour により自動検出されます。

検出されない場合：

1. 「プリンター設定」を開く
2. 手動で新しいプリンターを追加
3. 以下のパスを指定：

```
ipp://<サーバーのIPアドレス>:631/printers/LBP6000
```

---
