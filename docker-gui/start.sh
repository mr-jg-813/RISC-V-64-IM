#!/bin/bash

set -e

export DISPLAY=:1

mkdir -p /root/.vnc

# Set VNC password
printf 'riscv123\nriscv123\nn\n' | tigervncpasswd /root/.vnc/passwd

cat > /root/.vnc/xstartup <<'EOF'
#!/bin/sh

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

export DISPLAY=:1

xrdb "$HOME/.Xresources" 2>/dev/null || true

exec dbus-launch --exit-with-session startxfce4
EOF

chmod +x /root/.vnc/xstartup

rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1

vncserver :1 \
    -geometry 1600x900 \
    -depth 24 \
    -localhost no \
    -SecurityTypes VncAuth

echo "=== VNC started on :5901 ==="
echo "=== Starting noVNC on :6080 ==="

exec websockify \
    --web=/usr/share/novnc/ \
    0.0.0.0:6080 \
    localhost:5901