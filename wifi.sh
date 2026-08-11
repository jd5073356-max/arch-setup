#!/bin/bash
# ═══════════════════════════════════════════════════════════
# WIFI HELPER — correr desde la USB live de Arch (sin internet)
# Uso: bash wifi.sh
# ═══════════════════════════════════════════════════════════

set -e

echo "Desbloqueando adaptadores WiFi..."
rfkill unblock wifi
rfkill unblock all

echo ""
echo "Interfaces disponibles:"
iwctl device list
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
