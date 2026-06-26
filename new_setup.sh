#!/bin/bash

set -euo pipefail

read -p "Enter your SSH public key: " SSH_PUBLIC_KEY
read -p "Enter your Tailscale Auth Key: " TAILSCALE_AUTH_KEY


echo "1. Install Necessary Sources"

echo "1.1. Docker"
mkdir -p --mode=0755 /usr/share/keyrings
mkdir -p --mode=0755 /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

echo "1.2. ctop"
apt install gnupg
curl -fsSL https://azlux.fr/repo.gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/azlux-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian $(lsb_release -cs) main" \
  | tee /etc/apt/sources.list.d/azlux.list >/dev/null

echo "1.3. Tailscale"
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list


echo "2. Install needed Software"

echo "2.1. Missed Upgrades"
apt-get update -y
apt-get full-upgrade -y

echo "2.2. Apt Installs"
apt-get install \
    firmware-linux firmware-linux-nonfree firmware-iwlwifi linux-headers-$(uname -r) \
    i965-va-driver mesa-vulkan-drivers lm-sensors lsb-release  \
    build-essential curl wget neovim vim htop net-tools git unzip zsh tmux command-not-found \
    ca-certificates gnupg \
    iptables iptables-persistent fail2ban apt-listchanges unattended-upgrades \
    wpasupplicant systemd-resolved openssh-server \
    python3 python3-dev python3-venv libaugeas-dev gcc \
    logwatch ncdu \
    fonts-powerline \
    tailscale \
    docker-ctop \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin


echo "3. Setup Softwares"

echo "3.1. unattended-upgrades"
cat >/etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
sed -i 's|^//\(\s*"\${distro_id}:\${distro_codename}-security";\)|\1|' /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null || true
systemctl enable --now unattended-upgrades

echo "3.2. apt-listchanges and Dynamic MOTD"
cat > /etc/apt/listchanges.conf <<EOF
[apt]
frontend=text
email_address=root
confirm=0
save_seen=/var/lib/apt/listchanges.db
which=both
EOF

LOGFILE=/var/log/apt-listchanges-since-login.log
touch "$LOGFILE"
chmod 644 "$LOGFILE"

cat > /etc/apt/apt.conf.d/05listchanges-redirect <<EOF
DPkg::Pre-Invoke {"/usr/bin/apt-listchanges --apt >> /var/log/apt-listchanges-since-login.log 2>&1 || true";};
EOF

mkdir -p /etc/update-motd.d
if ! grep -q "pam_motd.so.*motd_dir" /etc/pam.d/sshd 2>/dev/null; then
    sed -i '/pam_motd.so.*motd=\/run\/motd.dynamic/d; /pam_motd.so.*noupdate/d' /etc/pam.d/sshd
    cat >> /etc/pam.d/sshd <<EOF
session    optional     pam_motd.so  motd_dir=/etc/update-motd.d
EOF
fi

cat > /etc/update-motd.d/95-apt-changes <<'EOF'
#!/bin/sh
LOGFILE=/var/log/apt-listchanges-since-login.log
if [ -s "$LOGFILE" ]; then
    echo "=== Package changes since your last login ==="
    cat "$LOGFILE"
    : > "$LOGFILE"
fi
EOF
chmod +x /etc/update-motd.d/95-apt-changes


echo "3.3. oh-my-zsh"
KEY_HOME="$(eval echo ~"$SUDO_USER")"
apt-get install -y zsh
if [ ! -d "$KEY_HOME/.oh-my-zsh" ]; then
  su - "$SUDO_USER" -c 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
fi
[ -f "$KEY_HOME/.zshrc" ] || su - "$SUDO_USER" -c "cp $KEY_HOME/.oh-my-zsh/templates/zshrc.zsh-template $KEY_HOME/.zshrc"
ZSH_CUSTOM="$KEY_HOME/.oh-my-zsh/custom"
[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || \
  su - "$SUDO_USER" -c "git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || \
  su - "$SUDO_USER" -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
sed -i -E 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$KEY_HOME/.zshrc"
sed -i -E 's/^plugins=\(.*\)/plugins=(git branch command-not-found zsh-autosuggestions zsh-syntax-highlighting)/' "$KEY_HOME/.zshrc"
chown "$SUDO_USER":"$SUDO_USER" "$KEY_HOME/.zshrc"
chsh -s "$(command -v zsh)" "$SUDO_USER"



echo "3.4. SSH Hardening"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%s)
sed -i -E \
  -e "s/^#?Port .*/Port 5022/" \
  -e "s/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/" \
  -e "s/^#?PasswordAuthentication .*/PasswordAuthentication no/" \
  -e "s/^#?PermitRootLogin .*/PermitRootLogin prohibit-password/" \
  /etc/ssh/sshd_config
grep -q "^Port 5022" /etc/ssh/sshd_config || echo "Port 5022" >> /etc/ssh/sshd_config
grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config


echo "3.5. SSH Key"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

echo "$SSH_PUBLIC_KEY" >> ~/.ssh/authorized_keys


echo "3.6. Fail2Ban"
cat >/etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 3
bantime.increment = true
bantime.multipliers = 1 2 4 8 16 32 64
bantime.maxtime = 1w
ignoreip = 127.0.0.1/8 ::1 192.168.1.2 192.168.1.11

[sshd]
enabled = true
port    = ssh
maxretry = 3
EOF


echo "3.7. Tailscale"
tailscale up --auth-key=$TAILSCALE_AUTH_KEY


echo "3.8. Firewall"
iptables -F
iptables -X
iptables -Z

iptables -P INPUT   DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT  ACCEPT

iptables -A INPUT -i lo -j ACCEPT -m comment --comment "Accept Localhost"
iptables -A INPUT ! -i lo -s 127.0.0.0/8 -j DROP -m comment --comment "Anti Loopback Spoofing"

iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT -m comment --comment "Allow Established Rules"
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP -m comment --comment "Block Malformed Packets"

iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT -m comment --comment "Allow ICMP Pings at 1 request/second"

iptables -A INPUT -i tailscale0 -j ACCEPT -m comment --comment "Accept Tailscale Traffic"
iptables -A INPUT -p udp --dport 41641 -j ACCEPT -m comment --comment "Service: Tailscale, Peer Handshake"

iptables -A INPUT -p tcp --dport 5022 -m iprange --src-range 192.168.1.2-192.168.1.20 -m conntrack --ctstate NEW -m recent --set --name ssh_limit -m comment --comment "Service: SSH, Rate Limiting Tag"
iptables -A INPUT -p tcp --dport 5022 -m iprange --src-range 192.168.1.2-192.168.1.20 -m recent --update --seconds 60 --hitcount 4 --name ssh_limit -j DROP -m comment --comment "Service: SSH, Rate Limiting"
iptables -A INPUT -p tcp --dport 5022 -m iprange --src-range 192.168.1.2-192.168.1.20 -j ACCEPT -m comment --comment "Service: SSH, SSH Access"

iptables -A INPUT -p tcp -m multiport --dports 80,443  -j ACCEPT -m comment --comment "Service: nginx, Webserver"
iptables -A INPUT -p udp -m multiport --dports 53,67,123 -j ACCEPT -m comment --comment "Service: Pi-Hole, DNS/DHCP/NTP Servers"

iptables -A INPUT -m limit --limit 20/min -j LOG --log-prefix "iptables-drop: " -m comment --comment "Log Dropped Packets"
iptables -A INPUT -j DROP

netfilter-persistent save
netfilter-persistent reload


echo "Done."