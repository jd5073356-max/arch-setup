#!/bin/bash
# ═══════════════════════════════════════════════════════════
# WIFI HELPER — correr desde la USB live de Arch (sin internet)
# Uso: bash wifi.sh
# ═══════════════════════════════════════════════════════════

echo "Escaneando interfaces wifi..."
iwctl device list

echo ""
echo "¿Nombre de la interfaz? (ej: wlan0)"
read -r IFACE
IFACE="${IFACE:-wlan0}"

echo "Escaneando redes..."
iwctl station "$IFACE" scan
sleep 3
iwctl station "$IFACE" get-networks

echo ""
echo "¿Nombre de la red (SSID)?"
read -r SSID

echo "¿Contraseña? (dejar vacío si es abierta)"
read -rs PASS

if [ -z "$PASS" ]; then
  iwctl station "$IFACE" connect "$SSID"
else
  iwctl --passphrase "$PASS" station "$IFACE" connect "$SSID"
fi

sleep 3
ping -c1 archlinux.org && echo "✓ Conectado!" || echo "✗ Falló — revisá SSID/contraseña"
