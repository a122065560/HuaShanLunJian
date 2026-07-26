<div align="center">

# 话山论见 HuaShanLunJian

**AI 多智能体讨论会议桌——让你的 AI 们开个会**

[![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-ARM64-blue)](https://github.com/a122065560/HuaShanLunJian/releases)
[![Windows](https://img.shields.io/badge/Windows-x64-blue)](https://github.com/a122065560/HuaShanLunJian/releases)

</div>

## 这是什么？

DeepSeek、智谱、千问、MiniMax、Kimi……这些 AI 各有所长。话山论见把它们拉到同一个"会议室"，围绕你提出的话题展开多轮圆桌讨论——互相质疑、补充、碰撞，最终输出一份结构化的讨论方案。

**无需任何 API Key**，应用通过内置浏览器自动操作 AI 网页。

## 核心功能

- **多 AI 协同讨论** — 2-5 个 AI 同时参会，分工为军师（主持引导）和谋士（轮流发言），针对同一话题多轮深度交锋
- **零配置开箱即用** — 下载安装包 → 启动内置浏览器 → 登录 AI 网页 → 开始讨论，不需要注册账号或配置 API
- **双模式** — 托管模式（全自动讨论，无需值守）和圆桌模式（用户主导节奏，随时介入引导）
- **自动结案** — 讨论达到预设轮次后，军师自动整合各方观点，生成结构化方案
- **文件上传** — 支持上传 .txt / .md / .csv 文件作为讨论背景素材

## 使用须知

1. **内置浏览器** — 应用自带 Chromium 浏览器，首次使用时会自动启动，无需手动安装 Chrome
2. **必须先登录 AI 网页** — 在内置浏览器中打开各 AI 平台并完成登录，否则讨论时该 AI 会因未登录而发言失败
3. **建议勾选已登录的 AI** — 只勾选你已成功登录的 AI 参与讨论，避免某个 AI 因未登录导致讨论中断
4. **首次使用可能需要等待** — 内置浏览器首次启动和加载 AI 网页可能需要一些时间，耐心等待即可

## 快速上手

1. 安装后打开「话山论见」
2. 点击「🚀 启动 Chrome」启动内置浏览器
3. 在浏览器中打开各 AI 平台并登录
4. 回到应用，勾选已登录的 AI
5. 输入讨论话题，点击「开始讨论」

## 下载

前往 [Releases 页面](https://github.com/a122065560/HuaShanLunJian/releases) 下载对应平台的安装包：

| 文件 | 平台 |
|------|------|
| `HuaShanLunJian-v*arm64.dmg` | macOS (Apple Silicon) |
| `HuaShanLunJian-v*Windows.exe` | Windows x64 |

---

## ⚠️ 免责声明与许可协议

**请在使用前仔细阅读以下条款：**

1. **学习交流用途** — 本项目仅供个人学习、研究和技术交流使用。**严禁用于任何商业用途**。
2. **非官方客户端** — 本项目为第三方开源工具，**非官方出品**，与任何 AI 模型提供商无隶属关系。
3. **风险自担** — 本项目通过自动化技术模拟网页操作。使用者应当自行评估并承担因使用本工具可能产生的账号风险（如账号被封禁）或法律风险。开发者不承担任何连带责任。
4. **GPL-3.0 协议**：
   - 本项目基于 `GPL-3.0` 协议开源。
   - 这意味着你可以自由地使用、修改和分发本软件，但**任何衍生作品必须同样开源**，且必须保留原作者的版权声明。
   - 本项目依赖 `PyQt6`，根据其协议要求，本项目必须采用 `GPL-3.0` 或更高版本协议。

## 🙏 致谢

本项目灵感来源于对 AI 协作模式的探索。感谢以下技术支持：
- [PyQt6](https://www.riverbankcomputing.com/software/pyqt/) — 跨平台 GUI 框架
- [Playwright](https://playwright.dev/) — 浏览器自动化引擎
- AI 模型服务：智谱清言、DeepSeek、通义千问、MiniMax、Kimi、豆包（排名不分先后）

---

<div align="center">GPL-3.0 License · 话山论见 HuaShanLunJian</div>
