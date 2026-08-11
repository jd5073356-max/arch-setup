#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# INSTALADOR COMPLETO — conecta WiFi + instala Arch + configura
# Correr desde la USB live apenas bootea
# ═══════════════════════════════════════════════════════════════

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
BOLD='\033[1m'
banner() { echo -e "\n${CYAN}${BOLD}══ $* ══${NC}"; }
step()  { echo -e "${GREEN}[✓]${NC} $1"; }
ask()   { echo -ne "${CYAN}[?]${NC} $1 "; }

# ─────────────────────────────────────
# PASO 1 — Conectarse al WiFi
# ─────────────────────────────────────
banner "PASO 1: Conectar WiFi"

echo "Interfaces disponibles:"
iwctl device list
echo ""

read -rp "Nombre de la interfaz (ej: wlan0): " IFACE
IFACE="${IFACE:-wlan0}"

echo "Escaneando redes..."
iwctl station "$IFACE" scan
sleep 3

echo ""
echo "Redes encontradas:"
iwctl station "$IFACE" get-networks
echo ""

read -rp "Nombre de la red (SSID): " SSID
read -rsp "Contraseña: " PASS
echo ""

if [ -z "$PASS" ]; then
  iwctl station "$IFACE" connect "$SSID"
else
  iwctl --passphrase "$PASS" station "$IFACE" connect "$SSID"
fi

sleep 3
ping -c 3 archlinux.org && echo "" && step "WiFi conectado" || { echo "ERROR: No se pudo conectar"; exit 1; }

# ─────────────────────────────────────
# PASO 2 — Particionar el disco
# ─────────────────────────────────────
banner "PASO 2: Particionar disco"

echo ""
echo "Discos disponibles:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -v loop
echo ""

read -rp "¿En qué disco instalar Arch? (ej: /dev/nvme0n1 o /dev/sda): " DISK

echo ""
echo "Esta acción BORRARÁ TODO el disco $DISK"
echo "¿Continuar? (escribí 'SI' en mayúsculas)"
read -r CONFIRM
[ "$CONFIRM" = "SI" ] || { echo "Cancelado"; exit 0; }

SWAP_SIZE=$(grep MemTotal /proc/meminfo | awk '{printf "%.0f", $2/1024/1024 + 1}')G

echo "Creando particiones en $DISK..."

sgdisk -Z "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 "$DISK"
sgdisk -n 2:0:+${SWAP_SIZE} -t 2:8200 "$DISK"
sgdisk -n 3:0:0 -t 3:8300 "$DISK"

sleep 2
partprobe "$DISK" 2>/dev/null || true

PART="${DISK}"
[ -e "${DISK}p1" ] && PART="${DISK}p" || [ -e "${DISK}1" ] && PART="${DISK}"

EFI="${PART}1"; SWAP="${PART}2"; ROOT="${PART}3"

step "Particiones creadas: EFI=$EFI  SWAP=$SWAP  ROOT=$ROOT"

# ─────────────────────────────────────
# PASO 3 — Formatear
# ─────────────────────────────────────
banner "PASO 3: Formatear"

mkfs.fat -F32 "$EFI"
mkswap "$SWAP"
swapon "$SWAP"
mkfs.ext4 "$ROOT"

step "Formateo listo"

# ─────────────────────────────────────
# PASO 4 — Montar
# ─────────────────────────────────────
banner "PASO 4: Montar sistema base"

mount "$ROOT" /mnt
mount --mkdir "$EFI" /mnt/boot

step "Sistema montado en /mnt"

# ─────────────────────────────────────
# PASO 5 — Instalar paquetes base
# ─────────────────────────────────────
banner "PASO 5: Instalar sistema base (~5 min)"

pacstrap -K /mnt base base-devel linux linux-firmware linux-headers \
  networkmanager iwd sudo git curl wget neovim vim \
  man-db man-pages bash-completion zsh

genfstab -U /mnt >> /mnt/etc/fstab

step "Sistema base instalado"

# ─────────────────────────────────────
# PASO 6 — Copiar scripts a /root/
# ─────────────────────────────────────
banner "PASO 6: Copiando scripts"

cp /mnt/setup-arch.sh /mnt/root/setup-arch.sh 2>/dev/null || true
cp /mnt/wifi.sh /mnt/root/wifi.sh 2>/dev/null || true
chmod +x /mnt/root/setup-arch.sh /mnt/root/wifi.sh 2>/dev/null || true

# También copio desde sda3 si está montado
if mountpoint -q /mnt/scripts 2>/dev/null; then
  cp /mnt/scripts/setup-arch.sh /mnt/root/
  cp /mnt/scripts/wifi.sh /mnt/root/
  chmod +x /mnt/root/setup-arch.sh /mnt/root/wifi.sh
fi

step "Scripts copiados a /root/ del nuevo sistema"

# ─────────────────────────────────────
# PASO 7 — arch-chroot y correr setup-arch.sh
# ─────────────────────────────────────
banner "PASO 7: Entrando a chroot"

echo ""
echo "Ahora vas a entrar al sistema instalado."
echo "Una vez dentro, ejecutá:"
echo ""
echo "  bash /root/setup-arch.sh"
echo ""
echo "Ese script te guía paso a paso (usuario, contraseña,"
echo "escritorio, herramientas, GRUB, etc.)"
echo ""
echo -e "${BOLD}Presioná ENTER para continuar...${NC}"
read -r

arch-chroot /mnt
