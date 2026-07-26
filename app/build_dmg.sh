#!/bin/bash
# ============================================================
# 话山论见 一键打包脚本
# 生成 macOS ARM64 .app 和 .dmg 安装包
# ============================================================
set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  🪑 话山论见 HuaShanLunJian 打包脚本 (ARM64)${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 变量
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/build"
cd "$SCRIPT_DIR"

DIST_DIR="$SCRIPT_DIR/dist"
BUILD_DIR="$SCRIPT_DIR/build"
DMG_NAME="${DMG_NAME:-话山论见-v1.2.0-arm64.dmg}"

mkdir -p "$OUTPUT_DIR"

# ----------------------------------------------------------------
# Step 1: 检查依赖
# ----------------------------------------------------------------
echo -e "${YELLOW}[1/7] 检查依赖...${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ 未找到 python3${NC}"
    exit 1
fi

PY_ARCH=$(python3 -c "import platform; print(platform.machine())")
echo -e "${GREEN}  ✅ Python $(python3 --version | cut -d' ' -f2) ($PY_ARCH)${NC}"

# 安装项目依赖
echo -e "${YELLOW}  ⏳ 检查项目依赖...${NC}"
python3 -m pip install -r requirements.txt --break-system-packages -q 2>&1 | tail -3
echo -e "${GREEN}  ✅ 项目依赖已就绪${NC}"

# 下载 Playwright Chromium 到用户目录（避免 /tmp 被沙箱阻止，且重启后缓存持久）
# 用 curl 直接下载（playwright install 在沙箱下会 EPERM 失败）
PW_BROWSERS_TMP="${HOME}/.huashanlunjian/pw-chromium-cache"
# 向后兼容：如果旧版缓存目录存在，迁移到新目录
if [ -d "${HOME}/.polysage/pw-chromium-cache" ] && [ ! -d "$PW_BROWSERS_TMP" ]; then
    mkdir -p "${HOME}/.huashanlunjian"
    mv "${HOME}/.polysage/pw-chromium-cache" "$PW_BROWSERS_TMP"
    echo -e "${YELLOW}  📦 Chromium 缓存已迁移至 ~/.huashanlunjian${NC}"
fi
CHROME_VER="149.0.7827.55"
CHROME_REV="1228"
FFMPEG_REV="1011"
PW_BASE="https://cdn.playwright.dev/builds/cft/${CHROME_VER}/mac-arm64"
FFMPEG_URL="https://cdn.playwright.dev/builds/ffmpeg/${FFMPEG_REV}/ffmpeg-mac-arm64.zip"

# 下载并解压单个组件（参数: url, 目标目录）
_download_pw_component() {
    local url="$1"
    local dest_dir="$2"
    local tmp_zip="${HOME}/.huashanlunjian/_pw_download.zip"
    echo -e "${YELLOW}    下载: $url${NC}"
    if curl -L -o "$tmp_zip" "$url" --progress-bar 2>&1 | tail -1; then
        mkdir -p "$dest_dir"
        unzip -q -o "$tmp_zip" -d "$dest_dir/" 2>&1
        rm -f "$tmp_zip"
        return 0
    else
        echo -e "${RED}    下载失败: $url${NC}"
        rm -f "$tmp_zip"
        return 1
    fi
}

# 确保所有 Playwright 浏览器组件都已下载
# chromium-1228: 完整 Chromium（headful 模式）
# chromium_headless_shell-1228: 无头 Shell（headless=True 时需要）
# ffmpeg-1011: 视频录制组件
ensure_pw_browsers() {
    local need_download=0
    [ ! -d "$PW_BROWSERS_TMP/chromium-${CHROME_REV}" ] && need_download=1
    [ ! -d "$PW_BROWSERS_TMP/chromium_headless_shell-${CHROME_REV}" ] && need_download=1
    # ffmpeg 可选，不强制

    if [ $need_download -eq 0 ]; then
        echo -e "${GREEN}  ✅ Chromium 已存在于缓存目录，跳过下载${NC}"
        return 0
    fi

    echo -e "${YELLOW}  ⏳ 下载 Playwright Chromium 组件...${NC}"
    mkdir -p "$PW_BROWSERS_TMP"

    # 1. Chromium (headful)
    if [ ! -d "$PW_BROWSERS_TMP/chromium-${CHROME_REV}" ]; then
        _download_pw_component \
            "${PW_BASE}/chrome-mac-arm64.zip" \
            "$PW_BROWSERS_TMP/chromium-${CHROME_REV}" \
            && echo -e "${GREEN}    ✅ Chromium 已下载${NC}" \
            || echo -e "${RED}    ❌ Chromium 下载失败${NC}"
    fi

    # 2. Headless Shell (headless=True 时需要)
    if [ ! -d "$PW_BROWSERS_TMP/chromium_headless_shell-${CHROME_REV}" ]; then
        _download_pw_component \
            "${PW_BASE}/chrome-headless-shell-mac-arm64.zip" \
            "$PW_BROWSERS_TMP/chromium_headless_shell-${CHROME_REV}" \
            && echo -e "${GREEN}    ✅ Headless Shell 已下载${NC}" \
            || echo -e "${YELLOW}    ⚠️  Headless Shell 下载失败（非关键）${NC}"
    fi

    # 3. FFmpeg (视频录制，可选)
    if [ ! -d "$PW_BROWSERS_TMP/ffmpeg-${FFMPEG_REV}" ]; then
        _download_pw_component \
            "$FFMPEG_URL" \
            "$PW_BROWSERS_TMP/ffmpeg-${FFMPEG_REV}" \
            && echo -e "${GREEN}    ✅ FFmpeg 已下载${NC}" \
            || echo -e "${YELLOW}    ⚠️  FFmpeg 下载失败（非关键）${NC}"
    fi

    # 最终验证
    if [ -d "$PW_BROWSERS_TMP/chromium-${CHROME_REV}" ]; then
        echo -e "${GREEN}  ✅ Chromium 缓存就绪${NC}"
    else
        echo -e "${RED}  ❌ Chromium 下载失败，内置浏览器将不可用${NC}"
        echo -e "${BLUE}  可手动运行 AGENTS.md 中的 curl 下载命令${NC}"
    fi
}

ensure_pw_browsers

# 检查 PyInstaller
if ! python3 -c "import PyInstaller" 2>/dev/null; then
    echo -e "${YELLOW}  ⏳ 安装 PyInstaller...${NC}"
    python3 -m pip install pyinstaller==6.3.0 --break-system-packages -q
fi
echo -e "${GREEN}  ✅ PyInstaller $(python3 -m PyInstaller --version)${NC}"

echo ""

# ----------------------------------------------------------------
# Step 2: 清理旧产物
# ----------------------------------------------------------------
echo -e "${YELLOW}[2/7] 清理旧产物...${NC}"
# 先清除扩展属性和保护标志，防止 macOS 阻止删除
xattr -cr "$BUILD_DIR" "$DIST_DIR" 2>/dev/null || true
chflags -R nouchg "$BUILD_DIR" "$DIST_DIR" 2>/dev/null || true
rm -rf "$BUILD_DIR" "$DIST_DIR" 2>/dev/null || true
rm -rf "$SCRIPT_DIR/__pycache__" 2>/dev/null || true
find "$SCRIPT_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
echo -e "${GREEN}  ✅ 已清理${NC}"
echo ""

# ----------------------------------------------------------------
# Step 3: PyInstaller 打包（命令行参数方式，避免 spec 文件导致 PYZ archive 丢失）
# ----------------------------------------------------------------
echo -e "${YELLOW}[3/7] PyInstaller 打包中（ARM64）...${NC}"
echo -e "${BLUE}  这可能需要几分钟...${NC}"

export PYINSTALLER_CONFIG_DIR="${TMPDIR:-/tmp}/pyinstaller_cache"
mkdir -p "$PYINSTALLER_CONFIG_DIR"

python3 -m PyInstaller \
    --noconfirm \
    --clean \
    --target-arch arm64 \
    --windowed \
    --osx-bundle-identifier com.huashanlunjian.app \
    --name "话山论见" \
    --icon AppIcon.icns \
    --add-data "logo_ui.png:." \
    --add-data "logo_ui@2x.png:." \
    main.py \
    ui_main_window.py \
    ui_widgets.py \
    ui_worker.py \
    ui_flowlayout.py \
    browser.py \
    core.py \
    config_manager.py \
    utils.py \
    logger.py \
    platform_adapter.py \
    macos_adapter.py \
    windows_adapter.py \
    --hidden-import PyQt6 \
    --hidden-import PyQt6.QtCore \
    --hidden-import PyQt6.QtGui \
    --hidden-import PyQt6.QtWidgets \
    --hidden-import PyQt6.sip \
    --hidden-import qasync \
    --hidden-import playwright \
    --hidden-import playwright.async_api \
    --hidden-import playwright._impl \
    --hidden-import openai \
    --hidden-import platform_adapter \
    --hidden-import macos_adapter \
    --hidden-import windows_adapter \
    --collect-submodules PyQt6 \
    --collect-binaries PyQt6 \
    --collect-all playwright \
    --collect-data qasync \
    --copy-metadata openai \
    --copy-metadata qasync \
    --exclude-module PyQt6.Qt6 \
    --exclude-module tkinter \
    --exclude-module matplotlib \
    --exclude-module numpy \
    --exclude-module pandas \
    --exclude-module PIL \
    --exclude-module PyQt5 \
    --exclude-module PySide6 \
    --exclude-module PyQt6.Qt3DCore \
    --exclude-module PyQt6.Qt3DRender \
    --exclude-module PyQt6.Qt3DAnimation \
    --exclude-module PyQt6.Qt3DExtras \
    --exclude-module PyQt6.Qt3DInput \
    --exclude-module PyQt6.Qt3DLogic \
    --exclude-module PyQt6.QtBluetooth \
    --exclude-module PyQt6.QtCharts \
    --exclude-module PyQt6.QtDataVisualization \
    --exclude-module PyQt6.QtDesigner \
    --exclude-module PyQt6.QtHelp \
    --exclude-module PyQt6.QtMultimedia \
    --exclude-module PyQt6.QtMultimediaWidgets \
    --exclude-module PyQt6.QtNetwork \
    --exclude-module PyQt6.QtNfc \
    --exclude-module PyQt6.QtOpenGL \
    --exclude-module PyQt6.QtOpenGLWidgets \
    --exclude-module PyQt6.QtPdf \
    --exclude-module PyQt6.QtPdfWidgets \
    --exclude-module PyQt6.QtPositioning \
    --exclude-module PyQt6.QtPrintSupport \
    --exclude-module PyQt6.QtQml \
    --exclude-module PyQt6.QtQuick \
    --exclude-module PyQt6.QtQuick3D \
    --exclude-module PyQt6.QtQuickControls2 \
    --exclude-module PyQt6.QtQuickWidgets \
    --exclude-module PyQt6.QtRemoteObjects \
    --exclude-module PyQt6.QtSensors \
    --exclude-module PyQt6.QtSerialPort \
    --exclude-module PyQt6.QtSpatialAudio \
    --exclude-module PyQt6.QtSql \
    --exclude-module PyQt6.QtTest \
    --exclude-module PyQt6.QtTextToSpeech \
    --exclude-module PyQt6.QtWebChannel \
    --exclude-module PyQt6.QtWebEngineCore \
    --exclude-module PyQt6.QtWebEngineQuick \
    --exclude-module PyQt6.QtWebEngineWidgets \
    --exclude-module PyQt6.QtWebSockets \
    --exclude-module PyQt6.QtXml \
    2>&1 | tail -10

if [ ! -d "$DIST_DIR/话山论见.app" ]; then
    echo -e "${RED}❌ 打包失败${NC}"
    exit 1
fi
echo -e "${GREEN}  ✅ .app 打包成功${NC}"
echo ""

# ----------------------------------------------------------------
# Step 4: 优化 Frameworks（去重 + 清理多余 Qt6 framework）
# PyInstaller --windowed 已把所有依赖放到 Contents/Frameworks/，
# 无需再从 COLLECT 目录复制 _internal（旧逻辑导致依赖两份重复，+300MB）
# ----------------------------------------------------------------
echo -e "${YELLOW}[4/7] 优化 Qt6 framework 和 Playwright driver...${NC}"

APP_BUNDLE="$DIST_DIR/话山论见.app"
APP_FW="$APP_BUNDLE/Contents/Frameworks"
APP_QT6LIB="$APP_FW/PyQt6/Qt6/lib"

# 找到 PyQt6 的 Qt6 库路径（源）
QT6_LIB=$(python3 -c "
import PyQt6, os
qt6_dir = os.path.join(os.path.dirname(PyQt6.__file__), 'Qt6', 'lib')
print(qt6_dir)
" 2>&1) || { echo "  ⚠️ python3 获取 QT6_LIB 失败: $QT6_LIB"; QT6_LIB=""; }

if [ -n "$QT6_LIB" ] && [ -d "$QT6_LIB" ]; then
    echo "  QT6_LIB=$QT6_LIB"
    # PyInstaller --collect-binaries 已把全部52个 Qt6 framework 放到 Frameworks/PyQt6/Qt6/lib
    # 但 PyInstaller 复制的 framework 可能有断裂符号链接，从源重新复制4个实际使用的 framework
    for fw in QtCore QtGui QtWidgets QtDBus; do
        rm -rf "$APP_QT6LIB/$fw.framework"
        cp -R "$QT6_LIB/$fw.framework" "$APP_QT6LIB/"
        echo "  修复 Qt6/$fw framework ✓"
    done
    # 删除多余 Qt6 framework（只保留4个，删除其余48个，节省约50MB）
    for fw_dir in "$APP_QT6LIB"/*.framework; do
        fw_name=$(basename "$fw_dir" .framework)
        case "$fw_name" in
            QtCore|QtGui|QtWidgets|QtDBus) ;;
            *) rm -rf "$fw_dir" ;;
        esac
    done
    echo -e "${GREEN}  ✅ Qt6 framework 已优化（仅保留 QtCore/QtGui/QtWidgets/QtDBus）${NC}"
else
    echo -e "${YELLOW}  ⚠️  Qt6 库未找到 (QT6_LIB='$QT6_LIB')${NC}"
fi

# Playwright driver 已由 PyInstaller --collect-all 正确放到 Resources/playwright/driver
# （PyInstaller --windowed .app 中 sys._MEIPASS = Contents/Resources/，Python 包在 Resources）
echo -e "${GREEN}  ✅ Playwright driver 已就绪（PyInstaller 自动放置）${NC}"

# 复制 Playwright Chromium 浏览器到 .app 包内
# 关键：同时复制到 Resources 和 Frameworks 两个位置，覆盖所有可能的 sys._MEIPASS 解析路径
# - sys._MEIPASS = Contents/Resources/ → 在 Resources/playwright/driver/package/ 搜索
# - sys._MEIPASS = Contents/Resources/_internal/ (= ../Frameworks/) → 在 Frameworks/playwright/driver/package/ 搜索
# 同时创建 local-browsers（不带点）符号链接，兼容 PLAYWRIGHT_BROWSERS_PATH=0
APP_RESOURCES="$APP_BUNDLE/Contents/Resources"
_copy_chromium_to() {
    local dest_parent="$1"
    if [ ! -d "$dest_parent/playwright/driver/package" ]; then
        return 1
    fi
    local dest="$dest_parent/playwright/driver/package/.local-browsers"
    mkdir -p "$dest"
    cp -R "$PW_BROWSERS_TMP"/* "$dest/"
    # 创建 local-browsers（不带点）符号链接 → .local-browsers（带点）
    ln -sf ".local-browsers" "$dest_parent/playwright/driver/package/local-browsers"
    return 0
}

if [ -d "$PW_BROWSERS_TMP" ] && [ -d "$PW_BROWSERS_TMP/chromium-1228" ]; then
    # 复制到 Resources（sys._MEIPASS = Contents/Resources/ 时）
    if _copy_chromium_to "$APP_RESOURCES"; then
        echo -e "${GREEN}  ✅ Chromium 已复制到 Resources/playwright/.local-browsers${NC}"
    fi
    # 复制到 Frameworks（sys._MEIPASS = Contents/Resources/_internal/ = Frameworks/ 时）
    if _copy_chromium_to "$APP_FW"; then
        echo -e "${GREEN}  ✅ Chromium 已复制到 Frameworks/playwright/.local-browsers${NC}"
    fi
    echo -e "${GREEN}  ✅ local-browsers 符号链接已创建（兼容 PLAYWRIGHT_BROWSERS_PATH=0）${NC}"
else
    echo -e "${RED}  ❌ Chromium 未下载，内置浏览器将不可用！${NC}"
    echo -e "${BLUE}  请手动运行: PLAYWRIGHT_BROWSERS_PATH=\"$PW_BROWSERS_TMP\" python3 -m playwright install chromium${NC}"
fi

# 清理 PyInstaller 创建的断裂符号链接（指向已删除 framework 的链接）
find "$APP_FW" -type l ! -exec test -e {} \; -delete 2>/dev/null || true
echo -e "${GREEN}  ✅ 已清理断裂符号链接${NC}"

# 删除 COLLECT 目录残留（PyInstaller 生成的 dist/话山论见/，与 .app 内容重复，占305MB）
rm -rf "$DIST_DIR/话山论见"

# 更新 Info.plist 和应用图标
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo -e "${GREEN}  ✅ 应用图标已嵌入${NC}"
else
    echo -e "${YELLOW}  ⚠️  AppIcon.icns 未找到${NC}"
fi

# ----------------------------------------------------------------
# 关键修复：创建 Qt6 framework 符号链接
# .so 文件依赖 @rpath/QtXxx（纯名称），rpath = @loader_path/..（即 Frameworks/）
# 需创建符号链接指向 Frameworks 内的 framework
# ----------------------------------------------------------------
echo -e "${BLUE}  创建 Qt6 framework 符号链接...${NC}"

# 1. 在 Qt6/lib 目录创建符号链接 (QtXxx -> QtXxx.framework/Versions/A/QtXxx)
cd "$APP_QT6LIB"
symlink_count=0
for fw_dir in *.framework; do
    fw_name="${fw_dir%.framework}"
    if [ -f "$fw_dir/Versions/A/$fw_name" ]; then
        ln -sf "$fw_dir/Versions/A/$fw_name" "$fw_name"
        symlink_count=$((symlink_count + 1))
    fi
done
echo -e "${GREEN}  ✅ Qt6/lib 目录创建 $symlink_count 个符号链接${NC}"

# 2. 在 Frameworks/ 目录创建符号链接 (QtXxx -> PyQt6/Qt6/lib/QtXxx.framework/Versions/A/QtXxx)
#    供 .so 文件的 rpath @loader_path/.. 使用（从 Frameworks/PyQt6/ 出发，.. = Frameworks/）
cd "$APP_FW"
for f in Qt*; do
    [ -L "$f" ] && rm "$f"
done
fw_count=0
for fw_dir in "$APP_QT6LIB"/*.framework; do
    fw_basename=$(basename "$fw_dir")
    fw_name="${fw_basename%.framework}"
    if [ -f "$fw_dir/Versions/A/$fw_name" ]; then
        ln -sf "PyQt6/Qt6/lib/${fw_basename}/Versions/A/${fw_name}" "$fw_name"
        fw_count=$((fw_count + 1))
    fi
done
echo -e "${GREEN}  ✅ Frameworks/ 目录创建 $fw_count 个符号链接${NC}"

# 3. 复制 qt.conf 到 Resources/
cp "$SCRIPT_DIR/qt.conf" "$APP_BUNDLE/Contents/Resources/qt.conf" 2>/dev/null || true

echo -e "${GREEN}  ✅ 资源已同步${NC}"
echo ""

# ----------------------------------------------------------------
# Step 5: 重新签名（深度签名，解决 macOS 26 兼容性）
# ----------------------------------------------------------------
echo -e "${YELLOW}[5/7] 签名 .app...${NC}"
# 移除可能残留的 entitlements 和 TCC 记录（非关键步骤，失败不阻断）
xattr -cr "$DIST_DIR/话山论见.app" 2>/dev/null || true
# 用 --deep 递归签名所有组件（ad-hoc 签名不能用 --options=runtime，会导致 Team ID 不一致）
# 签名是 ad-hoc 的，失败不影响功能（用户右键→打开即可），用 || true 防止 set -e 退出
codesign --force --deep --sign - "$DIST_DIR/话山论见.app" 2>&1 | tail -2 || true
echo -e "${GREEN}  ✅ 签名完成${NC}"

# 签名后创建 _internal 符号链接（codesign --deep 无法处理指向父目录的符号链接，会报错退出）
# PyInstaller 的 PyQt6 runtime hook 通过 _internal 路径查找 Qt plugins/libraries
ln -sf ../Frameworks "$DIST_DIR/话山论见.app/Contents/Resources/_internal"
# 验证符号链接
if [ -L "$DIST_DIR/话山论见.app/Contents/Resources/_internal" ]; then
    echo -e "${GREEN}  ✅ _internal 符号链接已创建（→ ../Frameworks）${NC}"
else
    echo -e "${RED}  ❌ _internal 符号链接创建失败！${NC}"
fi
echo ""

# ----------------------------------------------------------------
# Step 6: 生成 .dmg（可通过 SKIP_DMG=1 跳过）
# ----------------------------------------------------------------
if [ -n "$SKIP_DMG" ]; then
    echo -e "${YELLOW}[6/7] 跳过 .dmg 生成（SKIP_DMG 模式，仅生成 .app）${NC}"
    echo ""
else
echo -e "${YELLOW}[6/7] 生成 .dmg 安装包...${NC}"

DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
DMG_STAGING="$DIST_DIR/dmg_staging"

rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"

cp -R "$DIST_DIR/话山论见.app" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo -e "${BLUE}  创建磁盘镜像（单步模式，无需挂载）...${NC}"
# 使用单步 hdiutil create，直接生成压缩后的 .dmg，避免 attach/detach 操作
hdiutil create \
    -volname "话山论见 HuaShanLunJian" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH" 2>&1 | tail -2

rm -rf "$DMG_STAGING"

if [ -f "$DMG_PATH" ]; then
    echo -e "${GREEN}  ✅ .dmg 生成成功${NC}"
else
    # .dmg 失败不阻断流程，.app 已生成，继续执行后续步骤
    echo -e "${YELLOW}  ⚠️  .dmg 生成失败，但 .app 已成功构建，继续...${NC}"
fi
echo ""
fi  # 结束 SKIP_DMG 判断

# ----------------------------------------------------------------
# Step 7: 完成报告
# ----------------------------------------------------------------
echo -e "${YELLOW}[7/7] 打包完成！${NC}"
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}  🎉 打包成功！${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}📦 产物位置：${NC}"
echo -e "  App:  $OUTPUT_DIR/话山论见.app"
echo -e "  DMG:  $DMG_PATH"
echo ""

# 复制 .app 到 build/ 目录
if [ -d "$DIST_DIR/话山论见.app" ]; then
    rm -rf "$OUTPUT_DIR/话山论见.app"
    cp -R "$DIST_DIR/话山论见.app" "$OUTPUT_DIR/话山论见.app"
    echo -e "${GREEN}  ✅ .app 已复制到 build/ 目录${NC}"
fi

APP_SIZE=$(du -sh "$DIST_DIR/话山论见.app" 2>/dev/null | cut -f1)
DMG_SIZE=$(du -sh "$DMG_PATH" 2>/dev/null | cut -f1)
echo -e "${GREEN}📊 文件大小：${NC}"
echo -e "  App:  $APP_SIZE"
echo -e "  DMG:  $DMG_SIZE"
echo ""

echo -e "${GREEN}🔧 架构验证：${NC}"
ARCH=$(lipo -archs "$DIST_DIR/话山论见.app/Contents/MacOS/话山论见" 2>/dev/null || echo "unknown")
echo -e "  可执行文件架构: $ARCH"
echo ""

echo -e "${BLUE}💡 安装方法：${NC}"
echo -e "  1. 双击 .dmg 文件挂载"
echo -e "  2. 将 话山论见.app 拖到 Applications 文件夹"
echo -e "  3. 首次打开：右键 → 打开（绕过 Gatekeeper）"
echo -e "  4. 在启动台打开 话山论见 HuaShanLunJian"
echo ""

# ----------------------------------------------------------------
# Step 8: 触发 Windows .exe 构建（通过 GitHub Actions）
# ----------------------------------------------------------------
# CI 环境（GitHub Actions）中跳过此步骤
if [ -n "$GITHUB_ACTIONS" ]; then
    echo -e "${BLUE}  [CI 环境] 跳过 Windows 构建触发${NC}"
else
echo -e "${YELLOW}[8/8] 构建 Windows .exe 安装包...${NC}"

# 检查是否在 git 仓库中
if git rev-parse --git-dir > /dev/null 2>&1; then
    # 检查 gh CLI 是否安装
    if command -v gh &> /dev/null; then
        # 检查是否已认证
        if gh auth status &> /dev/null 2>&1; then
            echo -e "${BLUE}  通过 GitHub Actions 触发 Windows 构建...${NC}"
            # 获取版本号
            VERSION_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")
            
            # 触发 workflow
            if gh workflow run release.yml -f version="$VERSION_TAG" 2>/dev/null; then
                echo -e "${GREEN}  ✅ Windows 构建已触发（版本: $VERSION_TAG）${NC}"
                echo -e "${BLUE}  等待构建完成...${NC}"
                
                # 等待 workflow 启动
                sleep 5
                
                # 获取最新的 workflow run
                RUN_ID=$(gh run list --workflow=release.yml --limit=1 --json databaseId -q '.[0].databaseId' 2>/dev/null)
                
                if [ -n "$RUN_ID" ]; then
                    echo -e "${BLUE}  Workflow Run ID: $RUN_ID${NC}"
                    echo -e "${BLUE}  监听构建进度（可按 Ctrl+C 跳过等待）...${NC}"
                    
                    # 监听构建（超时20分钟）
                    timeout 1200 gh run watch "$RUN_ID" --exit-status 2>/dev/null || true
                    
                    # 检查构建结果
                    RUN_STATUS=$(gh run view "$RUN_ID" --json conclusion -q '.conclusion' 2>/dev/null || echo "unknown")
                    
                    if [ "$RUN_STATUS" = "success" ]; then
                        echo -e "${GREEN}  ✅ Windows 构建成功！正在下载 .exe...${NC}"
                        
                        # 下载 Windows 产物到 build/ 目录
                        gh run download "$RUN_ID" -n windows-exe -D "$OUTPUT_DIR" 2>/dev/null || true
                        
                        # 查找下载的 .exe
                        EXE_FILE=$(find "$OUTPUT_DIR" -maxdepth 1 -name "*.exe" -type f 2>/dev/null | head -1)
                        if [ -n "$EXE_FILE" ]; then
                            EXE_SIZE=$(du -sh "$EXE_FILE" 2>/dev/null | cut -f1)
                            echo -e "${GREEN}  ✅ Windows .exe 已下载到 build/${NC}"
                            echo -e "  EXE: $EXE_FILE ($EXE_SIZE)"
                        else
                            echo -e "${YELLOW}  ⚠️  产物下载完成但未找到 .exe 文件${NC}"
                            echo -e "${BLUE}  可手动从 GitHub Actions 页面下载${NC}"
                        fi
                    else
                        echo -e "${YELLOW}  ⚠️  Windows 构建状态: $RUN_STATUS${NC}"
                        echo -e "${BLUE}  可手动从 GitHub Actions 页面查看和下载${NC}"
                        echo -e "${BLUE}  https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions${NC}"
                    fi
                else
                    echo -e "${YELLOW}  ⚠️  无法获取 Workflow Run ID${NC}"
                    echo -e "${BLUE}  请手动查看: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions${NC}"
                fi
            else
                echo -e "${YELLOW}  ⚠️  无法触发 GitHub Actions workflow${NC}"
                echo -e "${BLUE}  请确保 .github/workflows/release.yml 已推送到仓库${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠️  GitHub CLI 未认证，跳过 Windows 构建${NC}"
            echo -e "${BLUE}  运行 'gh auth login' 认证后可自动构建 Windows .exe${NC}"
            echo -e "${BLUE}  或手动推送 tag 触发: git tag v1.0.0 && git push origin v1.0.0${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠️  未安装 GitHub CLI (gh)，跳过 Windows 构建${NC}"
        echo -e "${BLUE}  安装: brew install gh${NC}"
        echo -e "${BLUE}  或手动推送 tag 触发: git tag v1.0.0 && git push origin v1.0.0${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠️  不在 git 仓库中，跳过 Windows 构建${NC}"
    echo -e "${BLUE}  初始化 git 仓库并推送到 GitHub 后可自动构建 Windows .exe${NC}"
fi
fi  # 结束 GITHUB_ACTIONS 判断
echo ""

# ----------------------------------------------------------------
# Step 9: 清理中间构建文件（只清理 app/build 和 app/dist，不删 build/）
# ----------------------------------------------------------------
echo -e "${YELLOW}[清理] 删除中间构建文件...${NC}"
rm -rf "$SCRIPT_DIR/build"
rm -rf "$SCRIPT_DIR/dist"
echo -e "${GREEN}  ✅ app/build/ 和 app/dist/ 已清理${NC}"
echo ""
