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
# PASO 1 — Internet (saltar si ya hay)
# ─────────────────────────────────────
banner "PASO 1: Internet"

if ping -c 1 archlinux.org &>/dev/null; then
  step "Ya hay internet — saltando WiFi"
else
  echo "No hay conexión. Conectate con: bash /mnt/wifi.sh"
  echo "Y después volvé a correr: bash /mnt/instalar.sh"
  exit 1
fi

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

# Validar que el disco existe
[ -b "$DISK" ] || { echo "ERROR: $DISK no existe. Ejecutá lsblk y elegí bien el disco (ej: /dev/nvme0n1)"; exit 1; }

echo "Creando particiones en $DISK..."

# Desmontar por si estaba montado
umount ${DISK}* 2>/dev/null || true

# Tabla GPT + particiones con fdisk (viene en la ISO)
{
  echo g          # nueva tabla GPT
  echo n          # partición 1 (EFI)
  echo 1
  echo
  echo +1G
  echo t          # tipo
  echo 1
  echo n          # partición 2 (swap)
  echo 2
  echo
  echo +${SWAP_SIZE}
  echo t
  echo 2
  echo 19         # linux swap
  echo n          # partición 3 (root)
  echo 3
  echo
  echo
  echo w          # escribir
} | fdisk "$DISK"

sleep 2
partprobe "$DISK" 2>/dev/null || true

# Detectar prefijo de partición (nvme0n1 → nvme0n1p,  sda → sda)
if echo "$DISK" | grep -q "nvme"; then
  PART="${DISK}p"
else
  PART="${DISK}"
fi

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
