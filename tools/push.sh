#!/usr/bin/env bash
# 一键推到 GitHub 并触发 Actions 编译。
#
# 用法（Git Bash / WSL / macOS 都行）：
#   ./tools/push.sh                      # 交互式，会问仓库地址
#   ./tools/push.sh git@github.com:you/PhigrosAuto.git
#
# 前提：本机已能免密推送到该仓库（SSH key 或 git credential manager 里存过 token）。
set -euo pipefail

cd "$(dirname "$0")/.."
REPO_URL="${1:-}"

echo "==> 静态自检"
python tools/preflight.py 2>/dev/null || python3 tools/preflight.py

if [ ! -d .git ]; then
  echo "==> 初始化仓库"
  git init -q
  git branch -M main
fi

# 提交身份没配过的话给个默认值，避免 commit 失败
git config user.name  >/dev/null 2>&1 || git config user.name  "PhigrosAuto"
git config user.email >/dev/null 2>&1 || git config user.email "phigrosauto@local"

if [ -z "$(git remote 2>/dev/null)" ]; then
  if [ -z "$REPO_URL" ]; then
    read -r -p "GitHub 仓库地址（如 git@github.com:you/PhigrosAuto.git）: " REPO_URL
  fi
  git remote add origin "$REPO_URL"
fi

echo "==> 提交"
git add -A
if git diff --cached --quiet; then
  echo "没有改动，跳过 commit"
else
  git commit -q -m "PhigrosAuto $(date +%Y-%m-%d\ %H:%M)"
fi

echo "==> 推送"
git push -u origin main

cat <<'EOF'

推送完成。接下来：
  1. 打开仓库 → Actions → 左侧 build → Run workflow
     （push 到 main 通常会自动触发，不用手动点）
  2. 等 lint 和 deb 两个 job 都变绿，约 5-10 分钟（首次拉 Theos 和 SDK 慢）
  3. 页面底部 Artifacts → 下载 PhigrosAuto-rootless
  4. 解压得到的 .deb 传到手机，按 INSTALL-ios17.md 第三节安装
EOF
