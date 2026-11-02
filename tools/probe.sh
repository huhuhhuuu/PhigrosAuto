#!/bin/sh
# 判断 dylib 到底有没有进入游戏进程（在手机本机跑）
#
#   sh /var/mobile/probe.sh
#
# 结果只有三种，直接对应下一步：
#   A. dylib 没加载   -> 注入链路问题（ElleKit / plist / rootHide）
#   B. 加载了无日志   -> constructor 没跑或日志写不了
#   C. 有日志         -> 看日志内容定位

GAME=Phigros
DYLIB=PhigrosAuto.dylib
LOG=/var/mobile/PhigrosAuto.log

PID=$(pgrep -f "$GAME" 2>/dev/null | head -1)

if [ -z "$PID" ]; then
  echo "!! 游戏没在运行。先打开游戏、进到主界面，再跑这个脚本。"
  exit 1
fi
echo "游戏进程 PID=$PID"

echo
echo "===== 1. dylib 是否映射进了进程 ====="
if command -v vmmap >/dev/null 2>&1; then
  vmmap "$PID" 2>/dev/null | grep -i phigrosauto && echo ">>> A: 已加载" || echo ">>> dylib 未加载"
else
  echo "无 vmmap，改用 /proc 风格检查"
  ls -l /var/jb/usr/bin/vmmap 2>/dev/null || echo "  (没有 vmmap)"
fi

echo
echo "===== 2. 镜像列表里找 UnityFramework ====="
if command -v vmmap >/dev/null 2>&1; then
  vmmap "$PID" 2>/dev/null | grep -i -m3 UnityFramework
else
  echo "  (跳过)"
fi

echo
echo "===== 3. 插件日志 ====="
if [ -f "$LOG" ]; then
  echo "存在，$(wc -l < "$LOG") 行"
  echo "--- 全部内容 ---"
  cat "$LOG"
else
  echo ">>> 日志文件不存在: $LOG"
  echo
  echo "说明 constructor 没执行，即 dylib 没被注入进这个进程。"
  echo "按顺序查："
  echo "  ls /var/jb/Library/MobileSubstrate/DynamicLibraries/"
  echo "  ls /var/jb/usr/lib/libellekit.dylib"
  echo "  cat /var/jb/Library/MobileSubstrate/DynamicLibraries/PhigrosAuto.plist"
  echo "  killall -9 SpringBoard     # 装完包必须重启桌面"
fi

echo
echo "===== 4. rootHide 补丁痕迹 ====="
ls -l /var/jb/usr/lib/DynamicPatches/AutoPatches.dylib 2>/dev/null \
  || ls -l /var/jb/Library/MobileSubstrate/DynamicLibraries/*.rootHidePatches 2>/dev/null \
  || echo "  (没有 rootHide 补丁，普通注入)"
