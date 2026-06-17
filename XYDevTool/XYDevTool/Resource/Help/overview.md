# 软件说明

**XYDevTool** 是一款面向 macOS 的开发者工具集，将日常开发中常用的辅助能力整合在一个应用中，界面简洁、数据本地保存。

## 主要功能

| 模块 | 说明 |
|------|------|
| JSON 格式化 | 将压缩 JSON 格式化为易读形式 |
| JSON 转 Model | 根据 JSON 自动生成 Swift 模型代码 |
| AppIcon 生成器 | 从一张图生成 iOS / macOS 应用图标 |
| 网络请求工具 | 轻量 HTTP 调试，支持历史分组、变量与脚本 |
| 自定义服务器 | 本地静态资源服务 |
| 图片查看器 | 查看图片信息与元数据 |

## 设计原则

- **本地优先**：网络工具的历史、变量、脚本等数据保存在本机，可导出备份
- **模块化**：各功能独立窗口，从主界面进入
- **可扩展**：复杂逻辑（如签名）通过脚本扩展，文档随版本更新

## 获取与更新

- 源码编译：克隆 [GitHub 仓库](https://github.com/xiaoyouPrince/XYDevTool) 后用 Xcode 打开 `XYDevTool.xcworkspace`
- 发布包：见 [Releases](https://github.com/xiaoyouPrince/XYDevTool/releases)
- 启动时如有新版本，会提示更新

## 反馈

欢迎通过 GitHub Issues 提交问题或功能建议。
