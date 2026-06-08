# 请求历史列表 AppKit 迁移 — PRD

> **状态**：开发中（Phase 5）  
> **模块**：Network / 请求历史列表  
> **最后更新**：2026-06-08

---

## 1. 背景与动机

### 1.1 现状

- 历史列表由 SwiftUI `PanelHistoryView` 实现（`ScrollView + LazyVStack + ForEach`）。
- 多层分组、拖拽排序、折叠、重命名等 v1 功能已落地（见 [history-grouping-v1.md](./history-grouping-v1.md)）。
- 数据层为 `historyRoots: [HistoryNode]` + `HistoryTree` 工具；操作入口为 `HistoryListActions`。

### 1.2 痛点

| 问题 | 表现 |
|------|------|
| 无 cell 复用 | 每次状态刷新遍历全表，行数增加后选中/滚动卡顿 |
| 粗粒度刷新 | 编辑区加载牵连列表 diff（已部分拆分 store，仍不够） |
| 拖拽实现重 | `GeometryReader` + `PreferenceKey` 手搓跟手，主线程压力大 |
| 与 Xcode 体验差距 | 目标交互类似项目导航器，SwiftUI 列表模型不适合 |

### 1.3 目标

在**不改变数据层语义**的前提下，将历史列表**局部替换为 AppKit `NSOutlineView`**，其余面板（顶栏、请求/响应编辑、设置）保持 SwiftUI。

---

## 2. 范围与阶段

### 2.1 总原则

- **数据层不动**：`HistoryNode`、`history.json` v2、`HistoryListActions` API 保持兼容。
- **混合 UI**：`NSViewRepresentable` 桥接，嵌入 `NetworkPanelView` 左侧栏。
- **渐进迁移**：分阶段交付，每阶段可独立验证。
- **SwiftUI 列表代码**：Phase 1 完成后 `PanelHistoryView` 仅保留顶栏壳层；原 SwiftUI 行视图在 Phase 5 删除。

### 2.2 阶段排期

| 阶段 | 名称 | 工期（估） | 状态 |
|------|------|-----------|------|
| **Phase 1** | MVP：树展示 + 选中 + 折叠 | 1～2 天 | **已完成** |
| **Phase 2** | 删除、样式、刷新同步 | +1 天 | **已完成** |
| **Phase 3** | 拖拽排序 / 移入分组 / 跨层移动 | +2～3 天 | **已完成** |
| **Phase 4** | 重命名、右键菜单、删组弹窗 | +1 天 | **已完成** |
| **Phase 5** | 清理 SwiftUI 遗留、回归、文档 | +1 天 | 待开发 |

**全量 parity 合计**：约 5～8 个工作日。

---

## 3. Phase 1 — MVP

> **状态**：已完成

### 3.1 目标

验证 AppKit 列表能否解决**选中延迟**问题，建立可扩展的 Outline 骨架。

### 3.2 包含

| 项 | 说明 |
|----|------|
| `NSOutlineView` 树形展示 | 直接绑定 `historyRoots`，不再 `flatten` 驱动列表 |
| 分组展开 / 折叠 | 系统 disclosure + 同步 `node.collapsed` 持久化 |
| 点击选中 | `outlineViewSelectionDidChange` → `actions.selectHistory(id:)` |
| 选中态外部同步 | `historyListUI.selectedId` 变化时回写 Outline 选中行 |
| 树数据刷新 | `historyListUI.treeRevision` 递增 → `reloadData` |
| 行高 | `HistoryListLayout.rowHeight`（28pt） |
| 空分组文案 | 组名后显示 `(empty)` |
| 顶栏保留 SwiftUI | 「请求历史(n)」标题 +「+」新建分组 |

### 3.3 不包含（后续阶段）

- 行内删除按钮、锁定校验提示（Phase 2）
- `≡` 拖拽排序、移入分组（Phase 3）
- 双击 / 右键重命名、删组弹窗（Phase 4）
- 拖拽过程视觉反馈、drop 高亮（Phase 3）

### 3.4 验收标准

1. 打开网络窗口，历史树正确展示分组与请求层级。
2. 点击任意节点，**选中高亮即时出现**，编辑区随后加载（允许 1 帧延迟）。
3. 点击 disclosure 折叠/展开分组，重启应用后状态保持。
4. 新建分组、导入配置后列表自动刷新且选中合理。
5. 快速连点不同历史项，无选中错乱、无崩溃。

---

## 4. Phase 2～5 概要

### Phase 2 — 基础交互（已完成）

- 自定义 `HistoryRowCellView`：行尾删除按钮（红色 trash）。
- `HistoryTableRowView`：蓝底默认/悬停/选中样式（对齐原 SwiftUI 列表）。
- 锁定请求删除拦截（`isRequestLocked` + `showAlert`）。
- 分组删除：`NSAlert` 三选一 + 锁定强制删除二次确认。
- `reloadData` 后恢复展开态（`captureExpandedGroupIds`）与选中行（`listUI.selectedId`）。

#### Phase 2 验收标准

1. 点击行尾删除可删除未锁定请求；锁定请求弹出提示。
2. 分组删除弹出「仅删组 / 删组及内容 / 取消」；含锁定请求时有二次确认。
3. 悬停行背景略加深，选中行为深蓝底。
4. 删除/新建/导入后列表刷新，展开态与选中项合理保留。

### Phase 3 — 拖拽（已完成）

- `≡` 把手发起拖拽（`HistoryDragHandleView` + `beginDraggingSession`）。
- `validateDrop` / `acceptDrop`：`NSOutlineViewDropOnItemIndex` → `moveNodeIntoGroup`。
- 同级缝隙：`applySiblingOrder`；跨父级：`moveNode(toParentId:atIndex:)`。
- 禁止拖入自身子树（`canMoveNode` / `isDescendant`）。
- 悬停分组时 `HistoryTableRowView.isDropTarget` 高亮。

#### Phase 3 验收标准

1. 仅能通过 `≡` 把手拖拽，点击标题/删除不触发拖拽。
2. 同层上下调整顺序，松手后 `history.json` 顺序更新。
3. 拖到分组行上松手，节点移入该分组（含嵌套分组）。
4. 可将节点拖到根级或其他分组下（跨父级）。
5. 不能将分组拖入其子孙分组；悬停合法分组时有高亮反馈。

### Phase 4 — 分组高级能力（已完成）

- 双击分组行 → 行内 `NSTextField` 重命名（`renameGroup`）。
- 右键菜单：「重命名」「删除分组」。
- 删组 `NSAlert`（Phase 2 已有，右键/行内删除按钮共用）。
- `Esc` 取消重命名，`Return` 或失焦提交。

#### Phase 4 验收标准

1. 双击分组进入编辑，改名后列表与 `history.json` 同步。
2. 同名分组冲突时弹出错误提示，不提交。
3. 右键分组可重命名或删除（走删组弹窗流程）。
4. 请求行无双击重命名、无分组右键菜单。

### Phase 5 — 清理

- 删除 `PanelHistoryView` 内 SwiftUI 行视图 / 拖拽 / `PreferenceKey` 代码
- 精简 `HistoryListUIStore`（移除 `rows`，保留 `selectedId` / `requestCount` / `treeRevision`）
- `SettingsView` 改用 `selectedId` + `HistoryTree.findNode`
- 更新 `.cursor/skills/xydevtool-network`

---

## 5. 技术方案

### 5.1 文件结构（目标）

```
FEATURES/Network/
├── AppKitViews/
│   ├── HistoryOutlineRepresentable.swift   # NSViewRepresentable 桥接
│   ├── HistoryOutlineController.swift      # DataSource / Delegate
│   └── HistoryRowCellView.swift            # 可复用 cell
├── SwiftUIViews/
│   ├── PanelHistoryView.swift              # 顶栏 + Representable 容器
│   └── NetworkPanelView.swift              # 布局不变
├── NetworkDataModel.swift
└── NetModels.swift
```

### 5.2 数据流

```
historyRoots ──► NSOutlineView (DataSource)
                      │
         选中 ────────┼──► HistoryListActions.selectHistory(id:)
                      │
historyListUI.treeRevision ──► reloadData()
historyListUI.selectedId   ──► 回写选中行（外部变更）
```

### 5.3 与 SwiftUI 边界

| 层 | 技术 |
|----|------|
| 窗口根 / 分栏 / 顶栏 / 编辑区 | SwiftUI |
| 历史树列表 | AppKit `NSOutlineView` |
| 文本编辑 | 现有 `CustomTextEditor`（已是 AppKit） |

### 5.4 不复用

- `NetResquestController` / `OutLineViewDataSource`：基于扁平 `XYItem`，与 v2 树模型不兼容，仅作历史参考。

---

## 6. 风险

| 风险 | 缓解 |
|------|------|
| Phase 1 临时失去删除/拖拽 | PRD 明确阶段范围；尽快进入 Phase 2/3 |
| 折叠与 `reloadData` 打架 | `setGroupCollapsed` 仅改节点 + 写盘，不触发全量 flatten |
| Cell 内按钮与选中冲突 | Phase 2 用 `hitTest` / 独立 `NSButton` action 处理 |
| `pbxproj` 漏加文件 | 每阶段构建验证 |

---

## 7. 相关文档

- [history-grouping-v1.md](./history-grouping-v1.md) — 分组功能 PRD（已实现）
- [README.md](./README.md) — 本目录索引

---

## 8. 修订记录

| 日期 | 变更 |
|------|------|
| 2026-06-08 | 初版：五阶段排期 + Phase 1 详细范围 |
| 2026-06-08 | Phase 1 完成；Phase 2 删除/样式/刷新同步完成 |
| 2026-06-08 | Phase 3 拖拽排序/移入分组/跨层移动完成 |
