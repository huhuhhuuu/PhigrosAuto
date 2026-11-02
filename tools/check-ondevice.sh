#!/bin/sh
# PhigrosAuto 装机自检（在手机本机跑，用 NewTerm / 终端）
#
#   sh /var/mobile/check.sh
#
# 1.1.0 起插件自己写 /var/mobile/PhigrosAuto.log，
# 不再依赖 iOS 17 上已废弃的 /var/log/syslog。

LOG=/var/mobile/PhigrosAuto.log
DL=/var/jb/Library/MobileSubstrate/DynamicLibraries

hdr() { echo; echo "===== $* ====="; }

hdr "1 环境"
[ -d /var/jb ] && echo "  /var/jb 存在 — rootless OK" || echo "  !! 缺 /var/jb"
echo "  $(uname -m)  iOS $(sw_vers -productVersion 2>/dev/null)"

hdr "2 包版本"
/var/jb/usr/bin/dpkg -l 2>/dev/null | grep -i phigrosauto || dpkg -l 2>/dev/null | grep -i phigrosauto

hdr "3 插件文件"
ls -l "$DL" 2>/dev/null | grep -i phigrosauto || echo "  !! $DL 里没有"

hdr "4 注入器"
for f in /var/jb/usr/lib/libellekit.dylib /var/jb/usr/lib/libsubstrate.dylib; do
  [ -f "$f" ] && echo "  OK  $f"
done

hdr "5 插件日志"
if [ -f "$LOG" ]; then
  echo "  文件: $LOG  ($(wc -c < "$LOG") 字节)"
  echo "  --- 最后 30 行 ---"
  tail -30 "$LOG"
else
  echo "  !! 日志文件不存在"
  echo
  echo "  这说明 dylib 从来没有进入游戏进程，即没有注入。"
  echo "  检查顺序："
  echo "    a) 游戏进程在跑吗：      pgrep -f Phigros"
  echo "    b) 进程里有没有加载它：  vmmap \$(pgrep -f Phigros) | grep -i phigrosauto"
  echo "    c) ElleKit 是否正常：    ls /var/jb/usr/lib/libellekit.dylib"
  echo "    d) 装完包有没有重启桌面：killall -9 SpringBoard"
fi

hdr "6 dylib 架构"
D="$DL/PhigrosAuto.dylib"
if [ -f "$D" ]; then
  lipo -archs "$D" 2>/dev/null || echo "  (没有 lipo)"
fi
