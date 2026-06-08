---
name: xydevtool-network
description: >-
  XYDevTool macOS 网络请求模块：架构、文件地图、id/name 语义、树形历史、AppKit 列表、
  持久化与常见改动入口。在修改 FEATURES/Network、网络历史、变量/脚本、导入导出、
  XYNetTool 或用户提到网络请求工具时使用。
---

# XYDevTool 网络模块

## 先读这三条（高价值、易踩坑）

1. **`id` 是内部主键**：选中、删除、拖拽、加载编辑区一律用 `HistoryNode.id`（UUID）。
2. **请求 `name` 是业务主键**：同名请求覆盖更新；分组 `name` 在分组命名空间内唯一（见 PRD）。
3. **历史列表是 AppKit**：`NSOutlineView` 嵌入 `PanelHistoryView`；编辑区/顶栏仍是 SwiftUI。勿改 `NetResquestController` 当主路径。

## 文件地图（改什么去哪个文件）

| 目标 | 文件 |
|------|------|
| 发请求、变量、脚本、历史读写 | `FEATURES/Network/NetworkDataModel.swift` |
| HTTP 底层 | `FEATURES/Network/XYNetTool.swift` |
| `HistoryNode` 树模型 / `HistoryTree` | `FEATURES/Network/NetModels.swift` |
| 主布局 | `SwiftUIViews/NetworkPanelView.swift` |
| 历史列表壳层（顶栏 + Representable） | `SwiftUIViews/PanelHistoryView.swift` |
| **AppKit 历史树** | `FEATURES/Network/AppKitViews/` |
| 顶栏 URL/Method/Submit | `SwiftUIViews/PanelTopView.swift` |
| Header/Body 编辑 | `SwiftUIViews/PanelRequestView.swift` |
| 响应展示 | `SwiftUIViews/PanelResponceView.swift` |
| 变量/脚本/导入导出 | `SwiftUIViews/PanelSettingsView.swift` |
| 打开窗口 | `ViewController.swift` → `openNetworkWindow()` |
| 历史路径协议 | `Protocols/BaseDataProtocol.swift` |
| AppKit 迁移 PRD | `.prd/network/history-appkit-migration.md` |

## 架构（当前）

```text
NetworkHostingRoot
  ├─ NetworkPanelView
  │    ├─ PanelTopView              (@Observable NetworkEditorStore)
  │    ├─ PanelHistoryView          (SwiftUI 顶栏 + HistoryOutlineRepresentable)
  │    ├─ PanelRequestView / PanelResponceView
  │    └─ PanelStatusView → SettingsView
  │
  ├─ NetworkDataModel               (historyRoots, makeRequest, …)
  ├─ HistoryListUIStore             (selectedId, requestCount, treeRevision)
  └─ NetworkEditorStore             (表单字段，与列表分离)

AppKitViews/HistoryOutlineView → HistoryOutlineController → historyRoots
```

## 历史列表状态（HistoryListUIStore）

| 字段 | 用途 |
|------|------|
| `selectedId` | 当前选中节点 id；Outline 与 `NetworkDataModel.selectedId` 同步 |
| `requestCount` | 顶栏「请求历史(n)」 |
| `treeRevision` | 树变更时递增 → Outline `reloadData()` |

**已无** `rows` / `HistoryDisplayRow` / `flatten`（AppKit 直接绑定 `historyRoots`）。

## 历史树数据层 API

```text
historyRoots: [HistoryNode]          # 源数据，顺序 = 展示顺序
refreshHistoryListUI()               # 更新 requestCount / selectedId / treeRevision
selectHistory(id:)                   # 选中并加载编辑区（分阶段 metadata + text）
createGroup() / deleteGroup(...)     # 分组 CRUD
moveNode / moveNodeIntoGroup         # 拖拽结果写回
applySiblingOrder(parentId:orderedIds:)
HistoryListActions                   # UI 操作门面（传给 PanelHistoryView）
```

## 持久化

| 数据 | 位置 |
|------|------|
| 请求历史 | `history.json` v2 树形 `{ "version": 2, "item": [HistoryNode…] }` |
| 变量 | `UserDefaults` → `xydev.network.variables` |
| 全局后置脚本 | `UserDefaults` → `xydev.network.globalPostScripts` |
| 导出三文件 | `network_history.json`、`network_variables.json`、`network_global_scripts.json` |

## AppKit 历史列表要点

- 整行拖拽排序（`shouldStartDragFromRow` 排除删除按钮区域）。
- 分组：双击/右键重命名；右键/删除按钮删组（`NSAlert`）。
- 右键菜单：`HistoryOutlineView.menu(for:)` 子类实现（非 delegate 虚构 API）。
- 行 UI：`HistoryRowCellView` + `HistoryTableRowView`（选中/悬停/拖入高亮）。
- 行高常量：`HistoryListLayout.rowHeight`（勿用已删除的 `effectiveHistoryRowHeight`）。

## 常见任务速查

| 任务 | 做法 |
|------|------|
| 修列表选中/刷新 | `HistoryOutlineController` + `treeRevision` |
| 修拖拽排序 | `HistoryOutlineController+DragDrop.swift` |
| 修分组重命名 | `HistoryOutlineController+Rename.swift` |
| 加 HTTP 方法 | `HttpMethod` + `XYNetTool.RequestType` + `makeRequest` |
| 新历史字段 | `HistoryNode` + `update(with:)` + 导出 + `selectHistory` 加载 |
| 设置页判断选中请求 | `dataModel.isSelectedRequest` |

## 不要做的事

- 不要恢复 SwiftUI `ForEach` 扁平历史列表（已迁 AppKit）
- 不要用 `name` 做列表内部定位（用 `id`）
- 不要为排序单独引入 `itemID`（已有 `id`）
- 不要在每次拖拽帧写 `history.json`（松手后 `commitHistoryMutation`）
- 不要改 `NetResquestController` / storyboard 当主 UI

## 延伸阅读

细节见 [reference.md](reference.md)。PRD：`.prd/network/history-grouping-v1.md`（分组功能）、`.prd/network/history-appkit-migration.md`（列表 AppKit 迁移，已完成）。
