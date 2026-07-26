# HuaShanLunJian 项目指南

## 项目概要
- **应用名**: 话山论见 HuaShanLunJian（多 AI 圆桌协作讨论桌面应用）
- **仓库**: github.com/a122065560/HuaShanLunJian
- **平台**: macOS ARM64 + Windows x64
- **技术栈**: Python 3.10+ / PyQt6 6.6.1 / qasync 0.27.1 / Playwright 1.61.0 / PyInstaller 6.3.0
- **核心模块**: `main.py`(入口)、`core.py`(讨论引擎)、`browser.py`(浏览器控制)、`config_manager.py`(配置)

## 构建方式

### 本地构建（仅 .app）
```bash
# 双击执行，或命令行运行：
bash build/build_app.command
```
- 产物: `build/话山论见.app`（约 235MB，arm64）
- 跳过 .dmg 生成（本地 hdiutil 受限）和 Windows 构建
- 完整日志保存到 `build/build.log`

### 完整构建（.dmg + Windows .exe）
```bash
# macOS .dmg（需 CI 环境或本地 hdiutil 可用）：
cd app && GITHUB_ACTIONS=true bash build_dmg.sh

# Windows .exe（通过 GitHub Actions）：
git tag v1.x.x && git push origin v1.x.x
```

### 发版流程（仅用户明确要求时执行）
1. 提交代码: `git add -A && git commit -m "fix: xxx"`
2. 推送: `git push`
3. 打标签: `git tag v1.x.x && git push origin v1.x.x`（触发 CI 构建 macOS+Windows）
4. 下载 .dmg: `gh release download v1.x.x --pattern "*.dmg" --dir app/dist --clobber`
5. GitHub Release 资产名必须纯英文: `HuaShanLunJian-{version}-macOS.dmg` / `HuaShanLunJian-{version}-Windows.exe`

## 打包环境关键约束

### Python 环境
- 本地 python3 受 TRAE 沙箱 PYTHONHOME 污染（指向 3.13），需手动设置:
  ```
  PY310="/Users/damon/Library/Application Support/TRAE SOLO CN/ModularData/ai-agent/vm/tools/opt/python@3.10/3.10.20_3"
  PYTHONHOME="$PY310/Frameworks/Python.framework/Versions/3.10"
  PATH="$PY310/libexec/bin:$PATH"
  必须清除 PYTHONPATH (env -u PYTHONPATH)
  ```
- 运行示例: `env -u PYTHONPATH PYTHONHOME="..." PATH="..." GITHUB_ACTIONS=true bash app/build_dmg.sh`

### PyInstaller 打包
- macOS 用命令行参数调用 PyInstaller，**不用 spec 文件**（spec 会导致 PYZ archive 丢失）
- Windows 用 `HuaShanLunJian.spec` + Inno Setup (`installer.iss`)
- PyQt6 和 PyQt6-Qt6 版本必须完全一致
- 签名禁用 `--options=runtime`; 命令: `codesign --force --deep --sign - 话山论见.app`
- **codesign/xattr 必须加 `|| true`**: 在 `set -e` 下，codesign 返回非零会导致脚本提前退出
- **_internal 符号链接在签名后创建**: codesign --deep 无法处理指向父目录的符号链接
- macOS 26 文件保护: 删除旧产物前需 `xattr -cr` + `chflags -R nouchg`
- 体积优化: 删除多余 Qt6 framework（仅保留 QtCore/QtGui/QtWidgets/QtDBus），550M→235M
- 代码预检查必须加载实际 Qt 库: `from PyQt6 import QtWidgets, QtCore` 以检测 ABI 兼容性问题

### Playwright Chromium 打包
- Chromium 下载缓存: `~/.huashanlunjian/pw-chromium-cache/`（用户目录，重启后持久）
- 下载命令: `PLAYWRIGHT_BROWSERS_PATH="~/.huashanlunjian/pw-chromium-cache" python3 -m playwright install chromium`
- **手动下载（playwright install 卡住时用 curl）**:
  ```bash
  PW_CACHE="$HOME/.huashanlunjian/pw-chromium-cache"
  # 1. Chromium (171MB) → chromium-1228/chrome-mac-arm64/
  curl -L -o ~/chromium.zip "https://cdn.playwright.dev/builds/cft/149.0.7827.55/mac-arm64/chrome-mac-arm64.zip"
  unzip -q -o ~/chromium.zip -d "$PW_CACHE/chromium-1228/" && rm ~/chromium.zip
  # 2. Headless Shell (75MB) → chromium_headless_shell-1228/（headless=True 时需要）
  curl -L -o ~/hs.zip "https://cdn.playwright.dev/builds/cft/149.0.7827.55/mac-arm64/chrome-headless-shell-mac-arm64.zip"
  unzip -q -o ~/hs.zip -d "$PW_CACHE/chromium_headless_shell-1228/" && rm ~/hs.zip
  # 3. FFmpeg (3MB) → ffmpeg-1011/（视频录制需要）
  curl -L -o ~/ff.zip "https://cdn.playwright.dev/builds/ffmpeg/1011/ffmpeg-mac-arm64.zip"
  unzip -q -o ~/ff.zip -d "$PW_CACHE/ffmpeg-1011/" && rm ~/ff.zip
  ```
- 缓存目录结构: `chromium-1228/` + `chromium_headless_shell-1228/` + `ffmpeg-1011/` + `.links/`（约 548MB）
- Chromium 复制到 .app 的 **两个位置**（覆盖所有 sys._MEIPASS 解析路径）:
  - `Contents/Resources/playwright/driver/package/.local-browsers/`
  - `Contents/Frameworks/playwright/driver/package/.local-browsers/`
- 同时创建 `local-browsers`（不带点）符号链接 → `.local-browsers`，兼容 `PLAYWRIGHT_BROWSERS_PATH=0`
- 运行时搜索顺序: 内置 Chromium → 自动下载 → 系统 Chrome（回退）
- **hdiutil 在 TRAE 沙箱中可用**（之前被阻止，现已恢复正常，本地可生成 .dmg）
- **MacBook 迁移后缓存丢失**: 迁移数据不会带走 `~/.huashanlunjian/` 目录，需重新下载 Chromium

## 配置系统
- 配置版本号: `DEFAULT_CONFIG_VERSION`（当前 v2），每次改默认配置时递增
- 用户修改配置后不被覆盖（版本号一致时尊重用户修改）
- 思考模式配置: `thinking_mode.detect`(检测) + `thinking_mode.enable_steps`(操作步骤)
- 检测与操作分离: `detect_thinking_mode`(只读) + `try_enable_thinking_mode`(只写)
- DeepSeek 跳过思考模式（enabled: False）

## Hard Constraints（不可违反的规则）
- 登录检测逻辑第4条规则: 无登录按钮 + 无 token + 无用户元素 → 判定为已登录
- 讨论参数超时 `timeout_seconds` 必须统一为 180 秒
- 讨论轮数 `max_rounds` 默认 20 轮，达到上限时军师必须强行做出最终结案
- 讨论进行中不允许中途加入 AI
- 同一个 AI 超时 2 次自动剔除中军帐
- 军师被剔除且无其他可用 AI 时，讨论终止
- 剔除 AI 后，其网页不应被重建或重新打开
- 讨论进行中不允许更换军师，仅可在讨论未开始时更换

## Lessons Learned（踩坑记录）
- 网站改版导致 DeepSeek 和智谱的 token 存储 key 名及用户元素选择器失效，引发登录状态误判
- QComboBox.addItem 时未阻塞信号会导致嵌套刷新，触发 QTableWidget 索引越界崩溃(SIGABRT)
- PyQt6 中 QMessageBox.Yes 已废弃，必须使用 QMessageBox.StandardButton.Yes
- Playwright 未打包 Chromium 导致 Windows 内置浏览器启动失败: 需设置 PLAYWRIGHT_BROWSERS_PATH=0 下载浏览器到包目录
- 千问使用 Slate.js 富文本编辑器时，用 execCommand 或 textContent 设置内容会导致发送按钮 disabled，需用 keyboard.type() 模拟真实输入
- 使用 Playwright 专有伪类选择器 :has-text() 在标准 document.querySelector() 中会引发 SyntaxError
- 内置浏览器关闭失败: Playwright 的 context.close()/browser.close() 等异步协程需在事件循环中 await 执行
- 谋士并行回复时，第一个完成后 current_speaker 传空字符串会导致剩余仍在回复中的谋士从(...)变成(?)，需计算仍在回复中的AI列表
- **Chromium 复制路径错误**: 旧代码复制到 Frameworks/，但 sys._MEIPASS 指向 Resources/，导致运行时找不到浏览器

## 文字输入策略（三段式混合输入）
- **5000 字以内**: 前5字慢输入 + 中间粘贴 + 后5字慢输入
- **5000 字以上**: 前5000字按上述规则 + 超出部分转为 txt 文件上传
- 防止直接粘贴导致部分网站出 bug，同时比纯逐字输入快 50-100 倍
- 实现: `browser.py` 的 `_type_message()` 函数

## 版本规则
- 当前最新: v1.0.0
- 下一个 fix/feature: v1.0.1
- **每次修改(修bug/新功能)后，默认只生成本地 .app**（不推送 GitHub）
- **只有在用户明确说"发版"时，才需要推送到 GitHub Release**
