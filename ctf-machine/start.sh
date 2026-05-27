#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════╗"
echo "║         CTF 靶機啟動中 — 數位實驗高中            ║"
echo "╚══════════════════════════════════════════════════╝"

# 啟動 Apache2（HTTP port 80）
echo "[*] 啟動 Apache2..."
service apache2 start
echo "    ✓ HTTP 服務就緒 (port 80)"

# 啟動 SSH（port 22）
echo "[*] 啟動 SSH..."
service ssh start
echo "    ✓ SSH 服務就緒 (port 22)"

# 啟動 vsftpd（FTP port 21）
echo "[*] 啟動 vsftpd..."
/usr/sbin/vsftpd /etc/vsftpd.conf &
sleep 1
echo "    ✓ FTP 服務就緒 (port 21)"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║  靶機已就緒！開始尋找 3 個 flag 吧！            ║"
echo "╚══════════════════════════════════════════════════╝"

# 保持 container 持續運行
tail -f /dev/null
