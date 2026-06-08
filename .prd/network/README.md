# Network 模块 PRD 索引

本目录存放 XYDevTool **网络请求**相关的产品需求文档。

## 文档列表

| 文档 | 说明 | 状态 |
|------|------|------|
| [history-grouping-v1.md](./history-grouping-v1.md) | 请求历史多层分组（v1） | 已定稿，待开发 |

## 相关代码（实现时对照）

| 区域 | 路径 |
|------|------|
| 数据层 | `XYDevTool/FEATURES/Network/NetworkDataModel.swift` |
| 模型 | `XYDevTool/FEATURES/Network/NetModels.swift` |
| 历史列表 UI | `XYDevTool/FEATURES/Network/SwiftUIViews/PanelHistoryView.swift` |
| 顶栏 | `XYDevTool/FEATURES/Network/SwiftUIViews/PanelTopView.swift` |
| 持久化路径 | `BaseDataProtocol.history_path` → `history.json` |

## 修订记录

| 日期 | 文档 | 变更 |
|------|------|------|
| 2026-06-08 | history-grouping-v1.md | 初版定稿；含分组重命名（双击 / 右键） |
