#!/bin/sh
# PhigrosAuto 诊断 —— 不依赖 pgrep / vmmap / ps
#
# 下载到手机：
#   curl -o /var/mobile/probe.sh https://raw.githubusercontent.com/huhuhhuuu/PhigrosAuto/main/tools/probe.sh
#   sh /var/mobile/probe.sh
#
# 或者直接在终端里逐条敲下面的 SECTION。

DL=/var/jb/Library/MobileSubstrate/DynamicLibraries
LOG=/var/mobile/PhigrosAuto.log

echo "========== 1. 装的哪个版本 =========="
# 不用 dpkg -l（可能没装 dpkg 或路径不同），直接看包数据库里的版本文件
if [ -f /var/jb/var/lib/dpkg/status ]; then
  awk '/^Package: com\.yg\.phigrosauto$/,/^$/' /var/jb/var/lib/dpkg/status 2>/dev/null \
    | grep -E '^(Package|Version|Status)' 
elif [ -f /var/lib/dpkg/status ]; then
  awk '/^Package: com\.yg\.phigrosauto$/,/^$/' /var/lib/dpkg/status 2>/dev/null \
    | grep -E '^(Package|Version|Status)'
else
  echo "  找不到 dpkg status，改看文件时间戳"
fi

echo
echo "========== 2. 插件文件与时间戳（判断版本） =========="
ls -l "$DL" 2>/dev/null | grep -i phigros
echo "  1.1.0 约 17682 字节 / 1.2.0 约 19300 字节（deb 体积）"

echo
echo "========== 3. plist 内容 =========="
cat "$DL/PhigrosAuto.plist" 2>/dev/null || echo "  缺失"

echo
echo "========== 4. 注入器 =========="
for f in /var/jb/usr/lib/libellekit.dylib \
         /var/jb/usr/lib/libsubstrate.dylib \
         /var/jb/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate; do
  [ -f "$f" ] && echo "  OK  $f"
done

echo
echo "========== 5. 日志（决定性证据） =========="
if [ -f "$LOG" ]; then
  echo "  存在 / $(wc -l < "$LOG") 行 / $(wc -c < "$LOG") 字节"
  echo "  --- 内容 ---"
  cat "$LOG"
else
  echo "  不存在: $LOG"
  echo
  echo "  => dylib 没有进入游戏进程，或 constructor 没跑到。"
  echo "     先做这两件事再看一次："
  echo "       1) 确认装的是 1.2.0（见上面第 1 节）"
  echo "       2) killall -9 SpringBoard   然后重新打开游戏"
fi

echo
echo "========== 6. 找游戏进程（不用 pgrep） =========="
if command -v ps >/dev/null 2>&1; then
  ps aux 2>/dev/null | grep -i '[P]higros' || echo "  游戏没在跑"
else
  # 兜底：killall 的 -0 只探测不发送
  if killall -0 Phigros 2>/dev/null; then
    echo "  Phigros 正在运行"
  else
    echo "  游戏没在跑（或 killall 也缺）"
  fi
fi

echo
echo "========== 7. 进程里有没有加载 dylib =========="
if command -v vmmap >/dev/null 2>&1; then
  PID=$(ps aux 2>/dev/null | grep -i '[P]higros' | awk '{print $2}' | head -1)
  if [ -n "$PID" ]; then
    vmmap "$PID" 2>/dev/null | grep -i phigros || echo "  dylib 未映射进进程"
  fi
else
  echo "  没有 vmmap，跳过（日志文件已足够判断）"
fi
