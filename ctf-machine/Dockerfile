# 基底：debian:bookworm-slim 原生支援 linux/arm64 和 linux/amd64
FROM debian:bookworm-slim

# 安裝所需服務
RUN apt-get update && apt-get install -y \
    vsftpd \
    openssh-server \
    apache2 \
    vim \
    sudo \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# 建立使用者 tsai（密碼藏在 HTML comment 裡）
RUN useradd -m -s /bin/bash tsai && \
    echo "tsai:ILoveProgramming123" | chpasswd

# ── SSH ──────────────────────────────────────────────────
RUN mkdir -p /var/run/sshd && ssh-keygen -A
COPY config/sshd_config /etc/ssh/sshd_config

# ── FTP ──────────────────────────────────────────────────
COPY config/vsftpd.conf /etc/vsftpd.conf
RUN mkdir -p /srv/ftp && \
    chown root:root /srv/ftp && \
    chmod 755 /srv/ftp
COPY ftp/answers_midterm.txt /srv/ftp/answers_midterm.txt
RUN chmod 644 /srv/ftp/answers_midterm.txt

# ── WEB ──────────────────────────────────────────────────
COPY web/index.html /var/www/html/index.html

# ── SUDO ─────────────────────────────────────────────────
COPY config/sudoers /etc/sudoers
RUN chmod 440 /etc/sudoers

# ── FLAG3 (只有 root 可讀) ────────────────────────────────
COPY root_files/final_grades.txt /root/final_grades.txt
RUN chmod 600 /root/final_grades.txt

# ── 啟動腳本 ─────────────────────────────────────────────
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 21 22 80

CMD ["/start.sh"]
