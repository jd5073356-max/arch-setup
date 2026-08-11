#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# ARCH POST-INSTALL SCRIPT — corre directo desde arch-chroot o live USB
# Uso: curl -fsSL URL_RAW | bash
# ═══════════════════════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
BOLD='\033[1m'
OK="${GREEN}[✓]${NC}"; WARN="${YELLOW}[!]${NC}"; FAIL="${RED}[✗]${NC}"

banner() { echo -e "\n${BOLD}${BLUE}══════════ $* ══════════${NC}\n"; }
info()  { echo -e " ${BLUE}[i]${NC} ${BOLD}$1${NC}"; }
check() { echo -e " ${OK} $1"; }
warn()  { echo -e " ${WARN} $1"; }
die()   { echo -e " ${FAIL} $1"; exit 1; }

# ═══════════════════════ SANITY CHECKS ═══════════════════════
[ "$(id -u)" -eq 0 ] || die "Ejecutá como root: sudo bash $0"

[[ -f /etc/arch-release ]] || die "Este script solo corre en Arch Linux"

ping -c1 archlinux.org &>/dev/null || die "Sin internet. Conectate primero."

# ═══════════════════════ PACMAN ═══════════════════════
banner "Configurando pacman"
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i '/ParallelDownloads/a ILoveCandy' /etc/pacman.conf
check "Pacman configurado (color, paralelo, candy)"

pacman -Syy --noconfirm
pacman -S --noconfirm --needed archlinux-keyring
check "Keyring actualizado"

# ═══════════════════════ PAQUETES BASE ═══════════════════════
banner "Paquetes esenciales"
pacman -S --noconfirm --needed \
  base-devel git curl wget vim neovim \
  bash-completion man-db man-pages \
  htop btop fastfetch neofetch \
  ripgrep fd fzf bat eza zoxide \
  unzip p7zip unrar zip \
  tar gzip xz \
  openssh networkmanager iwd \
  linux-firmware sof-firmware \
  ufw \
  zsh tmux
check "Paquetes base instalados"

# ═══════════════════════ WIFI DRIVERS ═══════════════════════
banner "Firmware WiFi"
CPU_VENDOR=$(grep -m1 vendor_id /proc/cpuinfo | awk '{print $3}')
if lspci -k 2>/dev/null | grep -qi "network\|wireless"; then
  pacman -S --noconfirm --needed \
    broadcom-wl-dkms 2>/dev/null || true
fi

# Firmware común para adaptadores USB y PCI
pacman -S --noconfirm --needed 2>/dev/null \
  iwlwifi-dvm-firmware iwlwifi-mvm-firmware 2>/dev/null || true
pacman -S --noconfirm --needed 2>/dev/null \
  mt76-firmware mt76x2-firmware mt7601u-firmware 2>/dev/null || true
pacman -S --noconfirm --needed 2>/dev/null \
  rtw88-firmware rtw89-firmware 2>/dev/null || true
pacman -S --noconfirm --needed 2>/dev/null \
  realtek-firmware rtlwifi_new-dkms-firmware 2>/dev/null || true
pacman -S --noconfirm --needed 2>/dev/null \
  b43-firmware 2>/dev/null || true
check "Firmware WiFi instalado (Intel, MediaTek, Realtek, Broadcom)"

systemctl enable NetworkManager
check "NetworkManager activado"

# ═══════════════════════ LOCALE ═══════════════════════
banner "Locale"

echo -e "${BOLD}¿Idioma del sistema?${NC}"
echo "  1) Español (es_CO.UTF-8)  — Colombia"
echo "  2) Español (es_ES.UTF-8)  — España"
echo "  3) Español (es_MX.UTF-8)  — México"
echo "  4) Español (es_AR.UTF-8)  — Argentina"
echo "  5) Inglés  (en_US.UTF-8)"
read -rp "Elegí [1-5] (default 1): " lang_choice
lang_choice="${lang_choice:-1}"

case $lang_choice in
  2) LOCALE="es_ES.UTF-8";;
  3) LOCALE="es_MX.UTF-8";;
  4) LOCALE="es_AR.UTF-8";;
  5) LOCALE="en_US.UTF-8";;
  *) LOCALE="es_CO.UTF-8";;
esac

sed -i "s/^#\($LOCALE\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
export LANG="$LOCALE"

# TODO: preguntar timezone también
echo -e "\n${BOLD}¿Zona horaria?${NC}"
echo "  1) America/Bogota    2) America/Mexico_City    3) America/Argentina/Buenos_Aires"
echo "  4) Europe/Madrid      5) America/New_York       6) UTC"
read -rp "Elegí [1-6] (default 1): " tz_choice
tz_choice="${tz_choice:-1}"
case $tz_choice in
  2) TZ="America/Mexico_City";;
  3) TZ="America/Argentina/Buenos_Aires";;
  4) TZ="Europe/Madrid";;
  5) TZ="America/New_York";;
  6) TZ="UTC";;
  *) TZ="America/Bogota";;
esac
ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
hwclock --systohc
check "Locale: $LOCALE — Zona: $TZ"

# ═══════════════════════ HOSTNAME ═══════════════════════
banner "Hostname"
read -rp "Nombre del equipo (ej: aethon, archbox): " HOSTNAME
HOSTNAME="${HOSTNAME:-archbox}"
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF
check "Hostname: $HOSTNAME"

# ═══════════════════════ USUARIO ═══════════════════════
banner "Usuario"
read -rp "Nombre de usuario: " USERNAME
USERNAME="${USERNAME:-user}"

if id "$USERNAME" &>/dev/null; then
  warn "Usuario '$USERNAME' ya existe — usando el existente"
else
  useradd -m -G wheel,audio,video,optical,storage -s /bin/bash "$USERNAME"
  echo -e "\n${BOLD}Poné la contraseña para $USERNAME:${NC}"
  passwd "$USERNAME"
fi

echo -e "\n${BOLD}Poné la contraseña de root:${NC}"
passwd

if ! grep -q '^%wheel ALL=(ALL:ALL) ALL' /etc/sudoers; then
  sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
fi
check "Usuario $USERNAME configurado con sudo"

# ═══════════════════════ AUR HELPER ═══════════════════════
banner "AUR Helper (paru)"

su - "$USERNAME" -c "
  cd /tmp
  git clone https://aur.archlinux.org/paru-bin.git
  cd paru-bin
  makepkg -si --noconfirm
"
check "Paru instalado"

# ═══════════════════════ SHELL ═══════════════════════
banner "Shell (Zsh + plugin manager)"
pacman -S --noconfirm --needed zsh zsh-completions
su - "$USERNAME" -c "
  curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash -s -- --unattended
  git clone https://github.com/zsh-users/zsh-autosuggestions   \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting 2>/dev/null || true
  sed -i 's/^plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting z docker docker-compose sudo)/' ~/.zshrc
"
chsh -s /bin/zsh "$USERNAME"
check "Zsh + Oh-My-Zsh configurado"

# ═══════════════════════ DESKTOP ENVIRONMENT ═══════════════════════
banner "Entorno de escritorio"

echo -e "${BOLD}Elegí una opción:${NC}"
echo "  1) GNOME  (completo, ~1.2 GB)"
echo "  2) KDE Plasma (completo, ~1.5 GB)"
echo "  3) XFCE   (ligero, ~400 MB)"
echo "  4) i3 WM  (tiling, minimalista)"
echo "  5) Hyprland (tiling, Wayland, moderno)"
echo "  6) NINGUNO (solo terminal)"
read -rp "Elegí [1-6]: " de_choice

install_gnome() {
  pacman -S --noconfirm --needed \
    xorg gnome gnome-extra gdm \
    networkmanager
  systemctl enable gdm
  systemctl enable NetworkManager
  check "GNOME instalado + GDM activado"
}

install_kde() {
  pacman -S --noconfirm --needed \
    xorg plasma plasma-wayland-session sddm sddm-kcm \
    kde-applications \
    networkmanager
  systemctl enable sddm
  systemctl enable NetworkManager
  check "KDE Plasma instalado + SDDM activado"
}

install_xfce() {
  pacman -S --noconfirm --needed \
    xorg xfce4 xfce4-goodies lightdm lightdm-gtk-greeter \
    network-manager-applet \
    networkmanager
  systemctl enable lightdm
  systemctl enable NetworkManager
  check "XFCE instalado + LightDM activado"
}

install_i3() {
  pacman -S --noconfirm --needed \
    xorg i3-wm i3status i3lock dmenu \
    lightdm lightdm-gtk-greeter \
    xterm rxvt-unicode alacritty \
    feh picom rofi polybar \
    networkmanager network-manager-applet
  systemctl enable lightdm
  systemctl enable NetworkManager
  check "i3 WM instalado + LightDM activado"
}

install_hyprland() {
  pacman -S --noconfirm --needed \
    hyprland kitty waybar \
    wofi mako grim slurp \
    swaybg swayidle swaylock \
    networkmanager
  systemctl enable NetworkManager
  # Hyprland no usa DM por defecto — se lanza desde TTY o SDDM
  pacman -S --noconfirm --needed sddm
  systemctl enable sddm
  mkdir -p /usr/share/wayland-sessions
  cat > /usr/share/wayland-sessions/hyprland.desktop <<EOF
[Desktop Entry]
Name=Hyprland
Exec=Hyprland
Type=Application
EOF
  check "Hyprland instalado + SDDM activado"
}

case $de_choice in
  2) install_kde;;
  3) install_xfce;;
  4) install_i3;;
  5) install_hyprland;;
  6) info "Sin entorno gráfico — solo terminal";;
  *) install_gnome;;
esac

# ═══════════════════════ DEV TOOLS ═══════════════════════
banner "Herramientas de desarrollo"

echo -e "${BOLD}¿Instalar herramientas de desarrollo?${NC}"
echo "  1) Sí, todo (Node.js, Python, Docker, Rust, Go, VS Code)"
echo "  2) Solo lo básico (git, Node.js, Python)"
echo "  3) No, nada"
read -rp "Elegí [1-3]: " dev_choice

case $dev_choice in
  1)
    pacman -S --noconfirm --needed \
      nodejs npm python python-pip python-pipx \
      rustup go docker docker-compose \
      code firefox chromium \
      lazygit github-cli
    systemctl enable docker
    usermod -aG docker "$USERNAME"
    su - "$USERNAME" -c "rustup default stable"
    check "Dev tools full instaladas"
    ;;
  2)
    pacman -S --noconfirm --needed \
      nodejs npm python python-pip \
      github-cli lazygit
    check "Dev tools básicas instaladas"
    ;;
  *) info "Sin herramientas de desarrollo";;
esac

# ═══════════════════════ FONTS + CODECS ═══════════════════════
banner "Fonts y codecs"
pacman -S --noconfirm --needed \
  noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra \
  ttf-dejavu ttf-liberation ttf-firacode-nerd \
  gst-libav gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly \
  ffmpeg
check "Fonts y codecs instalados"

# ═══════════════════════ GRUB / BOOT ═══════════════════════
banner "Bootloader"

if [ -d /sys/firmware/efi ]; then
  pacman -S --noconfirm --needed grub efibootmgr
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
  check "GRUB (UEFI) instalado"
else
  pacman -S --noconfirm --needed grub
  grub-install --target=i386-pc "$(lsblk -ndo NAME | grep -E '^sd[a-z]$|^nvme[0-9]n[0-9]$' | head -1)"
  check "GRUB (BIOS) instalado"
fi

grub-mkconfig -o /boot/grub/grub.cfg
check "GRUB config generado"

# ═══════════════════════ FINAL ═══════════════════════
banner "INSTALACIÓN COMPLETA"

echo -e "${GREEN}${BOLD}"
echo "  █████╗ ██████╗  ██████╗██╗  ██╗"
echo " ██╔══██╗██╔══██╗██╔════╝██║  ██║"
echo " ███████║██████╔╝██║     ███████║"
echo " ██╔══██║██╔══██╗██║     ██╔══██║"
echo " ██║  ██║██║  ██║╚██████╗██║  ██║"
echo " ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝"
echo -e "${NC}"

echo ""
echo "  Usuario:     $USERNAME"
echo "  Hostname:    $HOSTNAME"
echo "  Shell:       zsh"
echo "  Locale:      $LOCALE"
echo "  Timezone:    $TZ"
echo ""

echo -e "${YELLOW}${BOLD}▶ Ahora ejecutá:${NC}"
echo "  exit"
echo "  umount -R /mnt"
echo "  reboot"
echo ""
echo -e "${BOLD}Después de reiniciar:${NC}"
echo "  - Iniciá sesión como $USERNAME"
echo "  - Si elegiste ZSH: va a cargar Oh-My-Zsh automáticamente"
echo "  - Para AUR: paru -S <paquete>"
