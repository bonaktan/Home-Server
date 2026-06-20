#!/usr/bin/env bash
# Debian bootstrap: static IP, essentials, unattended-upgrades, SSH hardening,
# nftables firewall, zsh, powerline fonts, docker, tailscale.
# Run as: sudo bash bootstrap.sh
#   (it prompts for your Tailscale auth key, then daemonizes itself so the
#    rest survives the SSH tunnel dropping — tail /root/bootstrap.log to watch)
set -euo pipefail

### ---- EDIT THESE ----
IFACE="enx00e04c360bc4"
STATIC_IP="192.168.1.4/24"
GATEWAY="192.168.1.1"
DNS="1.1.1.1 8.8.8.8"
SSH_PORT="5022"
KEY_USER="${SUDO_USER:-root}"
KEY_HOME="$(eval echo ~"$KEY_USER")"
### --------------------

log(){ echo -e "\n=== $* ===\n"; }

[ "$(id -u)" -eq 0 ] || { echo "Run as root"; exit 1; }

# Self-daemonize: prompt for Tailscale auth key now (interactive), then re-exec
# this script in the background so it survives the SSH tunnel dropping.
if [ -z "${BOOTSTRAP_DAEMONIZED:-}" ]; then
  read -s -p "Tailscale auth key (tskey-...): " TS_AUTHKEY; echo
  SCRIPT_PATH="$(readlink -f "$0")"
  export TS_AUTHKEY BOOTSTRAP_DAEMONIZED=1
  nohup setsid "$SCRIPT_PATH" >/root/bootstrap.log 2>&1 < /dev/null &
  disown
  echo "Bootstrapping in background (PID $!). Tail /root/bootstrap.log for progress."
  exit 0
fi

log "1. Static IP for $IFACE"
if [ -d /etc/netplan ] && command -v netplan >/dev/null 2>&1; then
  cat >/etc/netplan/99-$IFACE.yaml <<EOF
network:
  version: 2
  ethernets:
    $IFACE:
      dhcp4: false
      addresses: [$STATIC_IP]
      routes: [{to: default, via: $GATEWAY}]
      nameservers: {addresses: [$(echo $DNS | sed 's/ /, /g')]}
EOF
  netplan apply || true
else
  cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%s)
  # remove only the lines belonging to this interface (allow-hotplug/auto + iface block), leave rest of file untouched
  sed -i -E "/^(allow-hotplug|auto)[[:space:]]+$IFACE[[:space:]]*$/d" /etc/network/interfaces
  sed -i -E "/^iface[[:space:]]+$IFACE[[:space:]]+inet[[:space:]]+dhcp[[:space:]]*$/d" /etc/network/interfaces
  cat >>/etc/network/interfaces <<EOF

auto $IFACE
iface $IFACE inet static
    address ${STATIC_IP%/*}
    netmask 255.255.255.0
    gateway $GATEWAY
    dns-nameservers $DNS
EOF
  ifdown "$IFACE" 2>/dev/null || true
  ifup "$IFACE" || true
fi

log "2. apt update + essential packages/drivers"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
  firmware-linux firmware-linux-nonfree linux-headers-$(uname -r) \
  build-essential curl wget vim htop net-tools git unzip ca-certificates \
  gnupg software-properties-common nftables \
  unattended-upgrades apt-listchanges fail2ban || true

log "3. unattended-upgrades"
cat >/etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
sed -i 's|^//\(\s*"\${distro_id}:\${distro_codename}-security";\)|\1|' /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null || true
systemctl enable --now unattended-upgrades

log "4. Generate SSH keypair for $KEY_USER"
mkdir -p "$KEY_HOME/.ssh"
KEYFILE="$KEY_HOME/.ssh/id_ed25519_bootstrap"
if [ ! -f "$KEYFILE" ]; then
  ssh-keygen -t ed25519 -f "$KEYFILE" -N "" -C "$KEY_USER@$(hostname)-bootstrap"
fi
cat "$KEYFILE.pub" >> "$KEY_HOME/.ssh/authorized_keys"
sort -u -o "$KEY_HOME/.ssh/authorized_keys" "$KEY_HOME/.ssh/authorized_keys"
chown -R "$KEY_USER":"$KEY_USER" "$KEY_HOME/.ssh"
chmod 700 "$KEY_HOME/.ssh"
chmod 600 "$KEY_HOME/.ssh/authorized_keys" "$KEYFILE"
chmod 644 "$KEYFILE.pub"

log "5. SSH hardening (port $SSH_PORT, pubkey only)"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%s)
sed -i -E \
  -e "s/^#?Port .*/Port $SSH_PORT/" \
  -e "s/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/" \
  -e "s/^#?PasswordAuthentication .*/PasswordAuthentication no/" \
  -e "s/^#?PermitRootLogin .*/PermitRootLogin prohibit-password/" \
  /etc/ssh/sshd_config
grep -q "^Port $SSH_PORT" /etc/ssh/sshd_config || echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

log "6. Firewall (nftables) - allow new SSH port, keep 22 open temporarily as safety net"
mkdir -p /etc/nftables.conf.d 2>/dev/null || true
cat >/etc/nftables.conf <<EOF
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        iif "lo" accept
        ct state established,related accept
        ct state invalid drop

        tcp dport $SSH_PORT accept
        tcp dport 22 accept   # remove once you confirm $SSH_PORT works (see comment at script end)

        icmp type echo-request accept
        icmpv6 type { echo-request, nd-neighbor-solicit, nd-neighbor-advert, nd-router-advert } accept

        udp dport 41641 accept
        iifname "tailscale0" accept
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
systemctl enable nftables
nft -f /etc/nftables.conf
systemctl restart nftables

log "7. Restart sshd (existing sessions stay alive; new connections use port $SSH_PORT)"
systemctl restart ssh

log "8. zsh + oh-my-zsh + plugins"
apt-get install -y zsh
su - "$KEY_USER" -c 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
ZSH_CUSTOM="$KEY_HOME/.oh-my-zsh/custom"
[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || \
  su - "$KEY_USER" -c "git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || \
  su - "$KEY_USER" -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
sed -i -E 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' "$KEY_HOME/.zshrc"
sed -i -E 's/^plugins=\(.*\)/plugins=(git branch command-not-found zsh-autosuggestions zsh-syntax-highlighting)/' "$KEY_HOME/.zshrc"
chown "$KEY_USER":"$KEY_USER" "$KEY_HOME/.zshrc"
chsh -s "$(command -v zsh)" "$KEY_USER"

log "9. Powerline patched fonts"
apt-get install -y fonts-powerline vim-powerline

log "10. Docker"
install -m 0755 -d /etc/apt/keyrings
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
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker "$KEY_USER"

log "11. Tailscale"
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --authkey="$TS_AUTHKEY"

log "12. tmux + ctop"
apt-get install -y tmux ca-certificates curl gnupg 
curl -fsSL https://azlux.fr/repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/azlux-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/azlux-archive-keyring.gpg] http://packages.azlux.fr/debian $(lsb_release -cs) main" \
  | tee /etc/apt/sources.list.d/azlux.list >/dev/null
apt-get update -y
apt-get install -y docker-ctop

log "DONE"
echo "Private key: $KEYFILE  (copy this to your local machine, then connect with: ssh -p $SSH_PORT -i id_ed25519_bootstrap $KEY_USER@192.168.1.4)"
echo "IMPORTANT: test the new port in a SEPARATE terminal BEFORE closing this session."
echo "Once confirmed, remove the port-22 rule:"
echo "  edit /etc/nftables.conf, delete the 'tcp dport 22 accept' line, then: nft -f /etc/nftables.conf"
echo
echo "Other notes:"
echo "- zsh set as default shell for $KEY_USER; log out/in to take effect."
echo "- Powerline fonts installed system-side; set your LOCAL terminal emulator's font to a Powerline-patched font for agnoster glyphs to render."
echo "- $KEY_USER added to 'docker' group; log out/in (or 'newgrp docker') to use docker without sudo."
echo "- Tailscale started with the provided auth key; check status with: tailscale status"