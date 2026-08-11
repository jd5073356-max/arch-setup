#!/bin/bash
# ═══════════════════════════════════════════════════════════
# WIFI HELPER — correr desde la USB live de Arch (sin internet)
# Uso: bash wifi.sh
# Incluye tethering USB por celular si no hay WiFi
# ═══════════════════════════════════════════════════════════

echo "Desbloqueando adaptadores WiFi..."
rfkill unblock wifi 2>/dev/null || true
rfkill unblock all 2>/dev/null || true

echo ""
echo "Interfaces WiFi detectadas:"
iwctl device list 2>/dev/null

WIFI_COUNT=$(iwctl device list 2>/dev/null | grep -ci "wlan\|phy")

if [ "$WIFI_COUNT" -eq 0 ]; then
  echo ""
  echo ">>> NO SE DETECTÓ NINGÚN ADAPTADOR WIFI <<<"
  echo ""
  echo "Los drivers no están en la ISO. Opciones:"
  echo "  1) Conectar celular por USB y activar 'Compartir internet / USB tethering'"
  echo "  2) Conectar cable Ethernet"
  echo ""

  read -rp "¿Conectaste el celular por USB con tethering activado? (s/n): " TETHER

  if [ "$TETHER" = "s" ] || [ "$TETHER" = "S" ]; then
    echo "Buscando interfaz de tethering..."
    sleep 3
    ip link show | grep -E "enp.*usb|usb0|eth[0-9]" || true
    TETHER_IF=$(ip link show | grep -oP 'enp[^:]+' | head -1)
    TETHER_IF="${TETHER_IF:-usb0}"
    dhcpcd "$TETHER_IF" 2>/dev/null || dhclient "$TETHER_IF" 2>/dev/null || true
    sleep 2
    ping -c 2 archlinux.org && echo "" && echo "✓ Conectado por USB tethering!" && exit 0
    echo "✗ No funcionó. Revisá que el tethering esté activado en el celular."
    echo "  Android: Ajustes → Conexiones → Zona Wi-Fi/Compartir → Compartir por USB"
    echo "  iPhone:  Ajustes → Datos móviles → Compartir Internet → Permitir a otros"
    exit 1
  else
    echo "Opción 2: conectá un cable Ethernet y volvé a correr este script."
    echo "Si no, necesitás buscar los drivers de tu placa WiFi."
    echo "Podés ver la placa con: lspci | grep -i net"
    exit 1
  fi
fi

echo ""
echo "¿Nombre de la interfaz? (ej: wlan0)"
read -r IFACE
IFACE="${IFACE:-wlan0}"

echo ""
echo "Encendiendo $IFACE y escaneando..."
iwctl adapter "$(echo "$IFACE" | sed 's/wlan/phy/')" set-property Powered on 2>/dev/null || true
iwctl station "$IFACE" set-property Powered on 2>/dev/null || true
sleep 2
iwctl station "$IFACE" scan
sleep 4

echo ""
echo "Redes encontradas:"
iwctl station "$IFACE" get-networks
echo ""

echo "¿Nombre de la red (SSID)?"
read -r SSID

echo "¿Contraseña? (vacío si es abierta)"
read -rs PASS
echo ""

if [ -z "$PASS" ]; then
  iwctl station "$IFACE" connect "$SSID"
else
  iwctl --passphrase "$PASS" station "$IFACE" connect "$SSID"
fi

sleep 4
ping -c 2 archlinux.org && echo "" && echo "✓ Conectado!" || echo "✗ Falló — ¿SSID/contraseña correctos?"
