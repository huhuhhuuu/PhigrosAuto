#!/usr/bin/env python3
"""工程静态自检：不依赖 iOS 工具链，本地和 CI 都能跑。

抓的是最容易在 CI 上浪费一轮 macOS 分钟的问题：
  1. 必需文件是否齐全
  2. plist 的 Bundle id 是否正确
  3. control 的架构是否为 rootless
  4. 头文件里声明的函数是否都有实现（排除 static inline）
  5. 源文件大括号是否配平
  6. Config.h 里被代码引用的宏是否都定义了

用法: python tools/preflight.py
"""

import re
import sys
import pathlib
import plistlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
FAILS = []


def fail(msg):
    FAILS.append(msg)


def check_required_files():
    required = [
        "Makefile", "control", "Tweak.xm", "Config.h",
        "IL2CPP.h", "IL2CPP.m", "Autoplay.h", "Autoplay.m",
        "NoteModel.h", "NoteModel.m", "IOHIDTouch.h", "IOHIDTouch.m",
        "PhigrosAuto.plist",
    ]
    for f in required:
        if not (ROOT / f).exists():
            fail(f"缺少文件: {f}")


def check_plist():
    """PhigrosAuto.plist 是 OpenStep 格式（Theos 认），plistlib 只吃 XML，这里用文本解析。"""
    p = ROOT / "PhigrosAuto.plist"
    if not p.exists():
        return
    txt = p.read_text(encoding="utf-8")
    m = re.search(r"Bundles\s*=\s*\((.*?)\)", txt, re.S)
    if not m:
        fail("plist 里找不到 Bundles 数组")
        return
    bundles = re.findall(r'"([^"]+)"', m.group(1))
    if bundles != ["com.PigeonGames.Phigros"]:
        fail(f"plist Bundle id 不对: {bundles}")


def check_control():
    p = ROOT / "control"
    if not p.exists():
        return
    txt = p.read_text(encoding="utf-8")
    if not re.search(r"^Package: ", txt, re.M):
        fail("control 缺 Package 字段")
    if not re.search(r"^Architecture: iphoneos-arm64", txt, re.M):
        fail("control 的 Architecture 必须是 iphoneos-arm64（rootless）")


def check_header_impl():
    """头文件里以分号结尾的函数声明，.m 里必须有定义。static inline 除外。"""
    pairs = [("IL2CPP.h", "IL2CPP.m"), ("Autoplay.h", "Autoplay.m"),
             ("NoteModel.h", "NoteModel.m"), ("IOHIDTouch.h", "IOHIDTouch.m")]
    for h, m in pairs:
        hp, mp = ROOT / h, ROOT / m
        if not hp.exists() or not mp.exists():
            continue
        hdr = hp.read_text(encoding="utf-8")
        src = mp.read_text(encoding="utf-8")
        for line in hdr.splitlines():
            # 跳过 static inline / 宏 / 结构体字段
            if "static inline" in line or line.strip().startswith("#"):
                continue
            match = re.match(r"^\s*(?:void|BOOL|int|float|double|const char\s*\*)\s*\*?\s*(PH\w+)\s*\(", line)
            if not match:
                continue
            fn = match.group(1)
            if not re.search(r"\b%s\s*\(" % re.escape(fn), src):
                fail(f"{h}: {fn} 声明了但 {m} 里没有定义")


def check_braces():
    for p in sorted(ROOT.glob("*.m")) + sorted(ROOT.glob("*.xm")):
        s = p.read_text(encoding="utf-8")
        s = re.sub(r"//[^\n]*", "", s)
        s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
        s = re.sub(r'"(?:\\.|[^"\\])*"', '""', s)
        s = re.sub(r"'(?:\\.|[^'\\])*'", "''", s)
        if s.count("{") != s.count("}"):
            fail(f"{p.name}: 大括号不配平 {s.count('{')} vs {s.count('}')}")


def check_macros():
    """代码里用到的 kXxx 宏，Config.h 里必须定义。"""
    cfg = (ROOT / "Config.h").read_text(encoding="utf-8")
    defined = set(re.findall(r"#define\s+(k\w+)", cfg))
    for name in ["Autoplay.m", "Tweak.xm", "IOHIDTouch.m"]:
        p = ROOT / name
        if not p.exists():
            continue
        src = p.read_text(encoding="utf-8")
        for used in set(re.findall(r"\b(k[A-Z]\w+)\b", src)):
            if used.startswith(("kF_", "kNoteType", "kUnknownType", "kMax", "kTap",
                                "kHold", "kHit", "kFlick", "kHandled", "kTick",
                                "kPlayfield", "kTouch")):
                if used not in defined and not used.startswith(("kF_", "kNoteType")):
                    fail(f"{name} 用到 {used}，但 Config.h 里没有定义")


def main():
    check_required_files()
    check_plist()
    check_control()
    check_header_impl()
    check_braces()
    check_macros()

    if FAILS:
        print("静态自检失败：")
        for f in FAILS:
            print("  - " + f)
        return 1
    print("静态自检全部通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
