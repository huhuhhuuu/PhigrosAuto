#!/usr/bin/env bash
# 从 Windows 把 .deb 装到 iPhone 15 Pro（iOS 17.1 / Relaxin，rootless）
#
# 用法：
#   ./tools/deploy.sh 192.168.1.23 packages/com.yg.phigrosauto_1.0.0_iphoneos-arm64.deb
#
# 前提：手机已装 OpenSSH，和电脑在同一 Wi-Fi，root 密码已知（Relaxin 默认 alpine）。
set -euo pipefail

IP="${1:-}"
DEB="${2:-}"

if [ -z "$IP" ] || [ -z "$DEB" ]; then
  echo "用法: $0 [IPHONE_IP] [DEB_PATH]"
  echo "例:   $0 192.168.1.23 packages/com.yg.phigrosauto_1.0.0_iphoneos-arm64.deb"
  exit 1
fi
[ -f "$DEB" ] || { echo "找不到 deb: $DEB"; exit 1; }

NAME="$(basename "$DEB")"

echo "==> 探测设备连通性"
ping -c 1 -W 2 "$IP" >/dev/null 2>&1 || {
  echo "ping 不通 $IP。确认手机和电脑在同一 Wi-Fi、IP 没变。"; exit 1; }

echo "==> 传包到 /var/mobile/"
scp -o StrictHostKeyChecking=accept-new "$DEB" "root@$IP:/var/mobile/$NAME"

echo "==> 安装（rootless，dpkg 在 /var/jb 下）"
ssh -o StrictHostKeyChecking=accept-new "root@$IP" \
  "/var/jb/usr/bin/dpkg -i /var/mobile/$NAME || /var/jb/usr/bin/dpkg -i --force-depends /var/mobile/$NAME; \
   killall -9 SpringBoard || true"

echo "==> 验证"
ssh "root@$IP" "/var/jb/usr/bin/dpkg -l | grep phigrosauto || echo '没查到包'"
ssh "root@$IP" "ls -l /var/jb/Library/MobileSubstrate/DynamicLibraries/ | grep PhigrosAuto || echo '没查到插件文件'"

cat <<EOF

装完了。看日志：
  ssh root@$IP
  idevicesyslog | grep PhigrosAuto

出现 "[PhigrosAuto] ready" 就成，进游戏点左下角圆球。
EOF
