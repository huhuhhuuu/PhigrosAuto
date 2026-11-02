#!/bin/sh
# 在手机本机上跑的诊断（不需要电脑、不需要 SSH 对连）
#
# 用法：把本文件拷到手机，用 NewTerm 执行：
#   sh /var/mobile/check.sh
#
# 或者直接在 NewTerm 里逐段粘贴下面的命令。

echo "=============================================="
echo " PhigrosAuto 装机自检"
echo "=============================================="
echo

# ---------- 环境 ----------
echo "[1] 越狱环境"
if [ -d /var/jb ]; then
  echo "    /var/jb 存在 —— rootless，正确"
else
  echo "    !! 没有 /var/jb —— 不是 rootless 环境？"
fi
echo "    iOS $(sw_vers -productVersion 2>/dev/null || echo '?')  $(uname -m)"
echo

# ---------- 包 ----------
echo "[2] 包安装状态"
if [ -f /var/jb/usr/bin/dpkg ]; then
  /var/jb/usr/bin/dpkg -l 2>/dev/null | grep -i phigrosauto || echo "    !! dpkg 里查不到 phigrosauto"
else
  dpkg -l 2>/dev/null | grep -i phigrosauto || echo "    !! 找不到 dpkg"
fi
echo

# ---------- 插件文件 ----------
echo "[3] 插件文件"
DL=/var/jb/Library/MobileSubstrate/DynamicLibraries
if [ -d "$DL" ]; then
  ls -l "$DL" | grep -i phigrosauto || echo "    !! $DL 里没有 PhigrosAuto.*"
else
  echo "    !! 目录不存在: $DL"
  echo "    检查 rootful 路径:"
  ls -l /Library/MobileSubstrate/DynamicLibraries 2>/dev/null | grep -i phigrosauto \
    && echo "    -> 装到 rootful 路径了，形态错误"
fi
echo

# ---------- plist 内容 ----------
echo "[4] plist 里的 bundle id"
P="$DL/PhigrosAuto.plist"
if [ -f "$P" ]; then
  cat "$P"
  echo
else
  echo "    !! 文件不存在"
fi
echo

# ---------- 注入器 ----------
echo "[5] 注入器"
FOUND=0
for f in /var/jb/usr/lib/libellekit.dylib \
         /var/jb/usr/lib/libsubstrate.dylib \
         /var/jb/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate \
         /usr/lib/libsubstrate.dylib; do
  if [ -f "$f" ]; then echo "    OK  $f"; FOUND=1; fi
done
[ "$FOUND" = 0 ] && echo "    !! 找不到 ElleKit / CydiaSubstrate，dylib 不会被注入"
echo

# ---------- 进程里有没有加载 ----------
echo "[6] 游戏进程是否加载了这个 dylib"
if command -v frida-ps >/dev/null 2>&1; then
  echo "    有 frida，可进一步用 frida 检查"
else
  PID=$(pgrep -f Phigros 2>/dev/null | head -1)
  if [ -n "$PID" ]; then
    echo "    Phigros PID=$PID"
    if command -v vmmap >/dev/null 2>&1; then
      vmmap "$PID" 2>/dev/null | grep -i phigrosauto \
        && echo "    -> dylib 已加载" \
        || echo "    -> dylib 没在这个进程里（插件未注入）"
    else
      echo "    没有 vmmap，改看日志"
    fi
  else
    echo "    Phigros 没在运行（先打开游戏再跑这条）"
  fi
fi
echo

# ---------- 最近的日志 ----------
echo "[7] 最近的插件日志"
if [ -f /var/log/syslog ]; then
  grep -i PhigrosAuto /var/log/syslog 2>/dev/null | tail -20
  [ $? -ne 0 ] && echo "    syslog 里没有 PhigrosAuto 记录"
else
  echo "    没有 /var/log/syslog，用 idevicesyslog 抓（需要从电脑连）"
fi

echo
echo "=============================================="
echo " 自检结束"
echo "=============================================="
