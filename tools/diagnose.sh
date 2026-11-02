#!/usr/bin/env bash
# 一次性诊断：包是否装上、插件是否被加载、il2cpp 是否命中。
#
# 用法（Git Bash / WSL / macOS）：
#   ./tools/diagnose.sh 192.168.1.23
#
# 第一次会问 root 密码（Relaxin 默认 alpine），之后 5 分钟内复用同一连接。
set -uo pipefail

IP="${1:-}"
if [ -z "$IP" ]; then
  echo "用法: $0 [IPHONE_IP]"
  echo "手机 IP: 设置 → Wi-Fi → 点当前网络名 → IP 地址"
  exit 1
fi

CTL_SOCK="$HOME/.ssh/phigros-ctl-$IP"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 \
          -o ControlMaster=auto -o ControlPath=$CTL_SOCK -o ControlPersist=300"
SSH="ssh $SSH_OPTS root@$IP"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
warn()  { printf '\033[33m%s\033[0m\n' "$*"; }
head2() { printf '\n\033[1m===== %s =====\033[0m\n' "$*"; }

# ---------- 1. 网络 ----------
head2 "1/6 网络连通性"
if ping -c 1 -W 2 "$IP" >/dev/null 2>&1; then
  green "ping OK — $IP 可达"
else
  warn "ping 不通（有些系统禁 ICMP，先别急）"
fi

# ---------- 2. SSH ----------
head2 "2/6 SSH 连接"
if $SSH "echo __ssh_ok__" 2>/dev/null | grep -q __ssh_ok__; then
  green "SSH OK"
else
  red "SSH 连不上"
  cat <<'EOF'

  处理办法：
  1. Sileo 里搜索并安装 OpenSSH（Relaxin 不一定自带）
  2. 确认手机和电脑在同一个 Wi-Fi
  3. 确认 IP 没变（重启路由器后手机会换 IP）
  4. 密码默认 alpine，输入时屏幕不显示字符是正常的

  装完 OpenSSH 再跑一次这个脚本。
EOF
  exit 1
fi

# ---------- 3. 包是否安装 ----------
head2 "3/6 包安装状态"
PKG=$($SSH "/var/jb/usr/bin/dpkg -l 2>/dev/null | grep phigrosauto" 2>/dev/null)
if [ -n "$PKG" ]; then
  green "$PKG"
else
  red "dpkg 里查不到 phigrosauto —— 包没装上"
  echo "  Sileo → 已安装 里搜 PhigrosAuto 看看；没有就重装一次。"
fi

# ---------- 4. 插件文件 ----------
head2 "4/6 插件文件是否到位"
LS=$($SSH "ls -l /var/jb/Library/MobileSubstrate/DynamicLibraries/ 2>/dev/null | grep PhigrosAuto" 2>/dev/null)
if [ -n "$LS" ]; then
  green "$LS"
else
  red "DynamicLibraries 里没有 PhigrosAuto.*"
  echo "  可能装到了 rootful 路径。检查一下："
  $SSH "ls -l /Library/MobileSubstrate/DynamicLibraries/ 2>/dev/null | grep PhigrosAuto" 2>/dev/null \
    && warn "  发现它被装到了 rootful 路径 /Library/... —— 装错形态了，需要 rootless 的包"
fi

# ---------- 5. 注入器 ----------
head2 "5/6 注入器（ElleKit / Substrate）"
INJ=$($SSH "ls /var/jb/usr/lib/libellekit.dylib /var/jb/usr/lib/libsubstrate.dylib \
            /var/jb/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate 2>/dev/null" 2>/dev/null)
if [ -n "$INJ" ]; then
  green "$INJ"
else
  red "找不到 ElleKit / CydiaSubstrate —— 插件没有加载器，dylib 不会被注入"
  echo "  Sileo 里搜索 ElleKit 安装，装完 killall SpringBoard"
fi

# ---------- 6. 抓日志 ----------
head2 "6/6 抓 35 秒日志"
cat <<'EOF'

  现在请拿起手机：进游戏，进到一首歌的游玩界面，随便打几下。
  脚本会抓 35 秒日志，然后自动分析。

EOF
printf '  3 秒后开始抓日志…\n'
sleep 3

echo "  >>> 开始，去点游戏 <<<"
LOG=$($SSH "timeout 35 idevicesyslog 2>/dev/null | grep -i PhigrosAuto" 2>/dev/null)
echo "  >>> 结束 <<<"

head2 "分析结果"
if [ -z "$LOG" ]; then
  red "35 秒内没有抓到任何 PhigrosAuto 日志"
  cat <<'EOF'

  三种可能，按这个顺序排查：
  a) 插件没被注入 —— 回到上面第 4、5 项的检查结果
  b) 注入成功但没打日志 —— 包是 Release 编译，NSLog 应该还在，这条可能性低
  c) 你这 35 秒内没进游戏 —— 重跑一次，确认进到了游玩界面

  快速确认注入有没有发生：
    ssh root@IP "grep -c PhigrosAuto /var/log/syslog 2>/dev/null"
EOF
else
  echo "$LOG"
  echo
  if echo "$LOG" | grep -q "ready —"; then
    green "★ 插件已就绪，类名命中，可以开打了"
    echo "  进游戏后左下角有半透明圆球，点一下变绿 = 代打开启"
  elif echo "$LOG" | grep -q "候选类名全部未命中"; then
    warn "插件加载成功，但 Phigros 的类名和候选表对不上"
    echo "  需要跑 discover.js 取真实类名，流程见 INSTALL.md 第四节"
  elif echo "$LOG" | grep -q "il2cpp 绑定失败"; then
    red "il2cpp 符号没绑上 —— UnityFramework 当时还没加载完"
    echo "  这是时序问题，重进一次游戏再看"
  elif echo "$LOG" | grep -q "放弃探测"; then
    warn "探测超时（60 秒内没找到管理器）"
    echo "  通常是进游戏太慢，或者类名不对"
  else
    warn "抓到了日志但没匹配到已知分支，把上面内容原样发我"
  fi
fi

head2 "抓完"
echo "  完整日志（不只 PhigrosAuto 的）："
echo "    ssh root@$IP 'idevicesyslog | grep -i phigros'"
echo
echo "  关掉复用连接："
echo "    ssh -O exit -o ControlPath=$CTL_SOCK root@$IP 2>/dev/null"
