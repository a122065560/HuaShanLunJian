#!/bin/bash
# ============================================================
# 话山论见 HuaShanLunJian 一键构建脚本（仅生成 .app）
# 双击此文件即可构建 话山论见.app 到 build/ 目录
# ============================================================

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 路径（双击时 CWD 是家目录，必须先切换到脚本所在目录）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$PROJECT_DIR/app"
BUILD_DIR="$SCRIPT_DIR"

echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}  话山论见 HuaShanLunJian 构建工具（仅 .app）${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${BLUE}项目目录: $PROJECT_DIR${NC}"
echo ""

# 检查 app 目录
if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}❌ 找不到 app/ 目录: $APP_DIR${NC}"
    echo -e "${BLUE}请确保 build_app.command 位于项目 build/ 目录下${NC}"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi

# ----------------------------------------------------------------
# 查找 Python 3.10
# 优先级：TRAE 自带 python3.10 > 系统 python3.10 > 系统 python3
# ----------------------------------------------------------------
echo -e "${YELLOW}[1/4] 检测 Python 环境...${NC}"

TRAE_PY310="/Users/damon/Library/Application Support/TRAE SOLO CN/ModularData/ai-agent/vm/tools/opt/python@3.10/3.10.20_3"

PY_BIN=""
PY_HOME_EXPORT=""
PY_PATH_EXTRA=""

if [ -d "$TRAE_PY310" ] && [ -x "$TRAE_PY310/libexec/bin/python3" ]; then
    # TRAE 自带 python3.10（需设置 PYTHONHOME）
    PY_BIN="$TRAE_PY310/libexec/bin/python3"
    PY_HOME_EXPORT="export PYTHONHOME=\"$TRAE_PY310/Frameworks/Python.framework/Versions/3.10\""
    PY_PATH_EXTRA="$TRAE_PY310/libexec/bin:$TRAE_PY310/Frameworks/Python.framework/Versions/3.10/bin"
    echo -e "${GREEN}  ✅ 使用 TRAE Python 3.10: $PY_BIN${NC}"
elif command -v python3.10 &> /dev/null; then
    # 系统 python3.10（不设置 PYTHONHOME，避免版本不匹配）
    PY_BIN="$(which python3.10)"
    PY_PATH_EXTRA="$(dirname "$PY_BIN")"
    echo -e "${GREEN}  ✅ 使用系统 Python 3.10: $PY_BIN${NC}"
elif command -v python3 &> /dev/null; then
    # fallback: 系统 python3（不设置 PYTHONHOME）
    PY_BIN="$(which python3)"
    PY_VERSION=$(python3 --version 2>&1)
    PY_PATH_EXTRA="$(dirname "$PY_BIN")"
    echo -e "${YELLOW}  ⚠️  未找到 python3.10，使用 $PY_VERSION（可能存在兼容性问题）${NC}"
    echo -e "${BLUE}  建议安装 Python 3.10: brew install python@3.10${NC}"
else
    echo -e "${RED}❌ 未找到 Python 3，请先安装 Python 3.10+${NC}"
    echo -e "${BLUE}  安装方式: brew install python@3.10${NC}"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi

# 设置环境变量
# 关键：清除 PYTHONPATH（TRAE 沙箱会污染），只在用 TRAE python 时设置 PYTHONHOME
unset PYTHONPATH
if [ -n "$PY_HOME_EXPORT" ]; then
    eval "$PY_HOME_EXPORT"
fi
export PATH="$PY_PATH_EXTRA:$PATH"

# 验证 Python 可用
echo -e "${BLUE}  验证 Python...${NC}"
if ! python3 -c "import sys; print(f'  Python {sys.version}')" 2>/dev/null; then
    echo -e "${RED}❌ Python 启动失败，可能是 PYTHONHOME 不匹配${NC}"
    echo -e "${BLUE}  尝试清除 PYTHONHOME 后重试...${NC}"
    unset PYTHONHOME
    if ! python3 --version 2>/dev/null; then
        echo -e "${RED}❌ Python 仍无法启动，请检查 Python 安装${NC}"
        echo ""
        read -p "按回车键退出..."
        exit 1
    fi
fi
echo ""

# ----------------------------------------------------------------
# 清理旧产物
# ----------------------------------------------------------------
echo -e "${YELLOW}[2/4] 清理旧产物...${NC}"
# 清除扩展属性和保护标志（macOS 26 文件保护）
xattr -cr "$BUILD_DIR/话山论见.app" 2>/dev/null || true
chflags -R nouchg "$BUILD_DIR/话山论见.app" 2>/dev/null || true
rm -rf "$BUILD_DIR/话山论见.app"
echo -e "${GREEN}  ✅ 旧产物已清理${NC}"
echo ""

# ----------------------------------------------------------------
# 构建 .app（调用 build_dmg.sh，跳过 dmg 生成和 Windows 构建）
# ----------------------------------------------------------------
echo -e "${YELLOW}[3/4] 构建 话山论见.app（PyInstaller 打包）...${NC}"
echo -e "${BLUE}  这可能需要几分钟，请耐心等待...${NC}"
echo ""

cd "$APP_DIR"

# SKIP_DMG=1: 跳过 hdiutil（本地可能受限）
# GITHUB_ACTIONS=true: 跳过 Windows 构建（仅生成本地 .app）
# 不用 tail 管道，直接输出完整日志（方便排查错误）
LOG_FILE="$BUILD_DIR/build.log"
if GITHUB_ACTIONS=true SKIP_DMG=1 bash build_dmg.sh 2>&1 | tee "$LOG_FILE"; then
    BUILD_SUCCESS=true
else
    BUILD_SUCCESS=false
fi

echo ""

# ----------------------------------------------------------------
# 验证产物
# ----------------------------------------------------------------
echo -e "${YELLOW}[4/4] 验证产物...${NC}"

# build_dmg.sh 会把 .app 复制到 $OUTPUT_DIR（即 $PROJECT_DIR/build/）
APP_PATH="$BUILD_DIR/话山论见.app"

if [ -d "$APP_PATH" ]; then
    APP_SIZE=$(du -sh "$APP_PATH" 2>/dev/null | cut -f1)
    echo -e "${GREEN}  ✅ 话山论见.app 构建成功！${NC}"
    echo -e "${GREEN}  📦 位置: $APP_PATH ($APP_SIZE)${NC}"

    # 架构验证
    ARCH=$(lipo -archs "$APP_PATH/Contents/MacOS/话山论见" 2>/dev/null || echo "unknown")
    echo -e "${GREEN}  🔧 架构: $ARCH${NC}"
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${GREEN}  🎉 构建完成！${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo -e "${BLUE}💡 使用方法：${NC}"
    echo -e "  双击 话山论见.app 启动（首次需右键 → 打开）"
    echo ""
    echo -e "${BLUE}💡 如需 .dmg 或 Windows .exe，请发版后从 GitHub Release 下载：${NC}"
    echo -e "  https://github.com/a122065560/PolySage/releases"
    echo ""
else
    echo -e "${RED}❌ 构建失败：未找到 $APP_PATH${NC}"
    echo -e "${YELLOW}  完整日志已保存到: $LOG_FILE${NC}"
    echo -e "${BLUE}  请查看上方输出中的错误信息${NC}"
    echo ""
    # 尝试从 app/dist 恢复（build_dmg.sh 可能在清理前已生成 .app）
    if [ -d "$APP_DIR/dist/话山论见.app" ]; then
        echo -e "${YELLOW}  发现 app/dist/ 中有 .app，尝试复制...${NC}"
        cp -R "$APP_DIR/dist/话山论见.app" "$APP_PATH"
        APP_SIZE=$(du -sh "$APP_PATH" 2>/dev/null | cut -f1)
        echo -e "${GREEN}  ✅ 已从 app/dist 恢复: $APP_PATH ($APP_SIZE)${NC}"
        echo ""
        echo -e "${BLUE}================================================${NC}"
        echo -e "${GREEN}  🎉 构建完成（从 dist 恢复）！${NC}"
        echo -e "${BLUE}================================================${NC}"
        echo ""
    else
        echo -e "${RED}  app/dist/ 中也未找到 .app，PyInstaller 打包可能失败${NC}"
        echo ""
    fi
fi

# 清理中间构建文件（app/build 和 app/dist）
rm -rf "$APP_DIR/build" "$APP_DIR/dist" 2>/dev/null || true

echo ""
read -p "按回车键退出..."
