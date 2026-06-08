# Network 模块 PRD 索引

本目录存放 XYDevTool **网络请求**相关的产品需求文档。

## 文档列表

| 文档 | 说明 | 状态 |
|------|------|------|
| [history-grouping-v1.md](./history-grouping-v1.md) | 请求历史多层分组（v1） | 已实现 |
| [history-appkit-migration.md](./history-appkit-migration.md) | 历史列表 AppKit（NSOutlineView）迁移 | **已完成** |

## 相关代码（实现时对照）

| 区域 | 路径 |
|------|------|
| 数据层 | `XYDevTool/FEATURES/Network/NetworkDataModel.swift` |
| 模型 | `XYDevTool/FEATURES/Network/NetModels.swift` |
| 历史列表 UI（SwiftUI 壳 + AppKit 树） | `XYDevTool/FEATURES/Network/SwiftUIViews/PanelHistoryView.swift` |
| AppKit 历史树 | `XYDevTool/FEATURES/Network/AppKitViews/` |
| 顶栏 | `XYDevTool/FEATURES/Network/SwiftUIViews/PanelTopView.swift` |
| 持久化路径 | `BaseDataProtocol.history_path` → `history.json` |

## 修订记录

| 日期 | 文档 | 变更 |
|------|------|------|
| 2026-06-08 | history-grouping-v1.md | 初版定稿；含分组重命名（双击 / 右键） |
| 2026-06-08 | history-grouping-v1.md | v1 代码实现完成 |
| 2026-06-08 | history-appkit-migration.md | 新增 AppKit 迁移五阶段 PRD |
| 2026-06-08 | history-appkit-migration.md | Phase 1/2 实现完成 |
| 2026-06-08 | history-appkit-migration.md | Phase 3 拖拽完成 |
| 2026-06-08 | history-appkit-migration.md | Phase 4 重命名/右键菜单完成 |
| 2026-06-08 | history-appkit-migration.md | Phase 5 清理完成，迁移收官 |
| 2026-06-08 | history-grouping-v1.md | 同步 AppKit 实现：整行拖拽、API、行高常量 |
| 2026-06-08 | history-appkit-migration.md | 补全 AppKitViews 文件结构；修正迁移前/后描述 |
