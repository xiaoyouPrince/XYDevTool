# XYDevTool 网络模块 — 参考

> 本文档侧重**流程与语义**；文件地图与改动入口见 [SKILL.md](SKILL.md)。

## 架构

```text
ViewController.openNetworkWindow()
  └─ NetworkHostingRoot
       ├─ NetworkPanelView
       │    ├─ PanelTopView              # name / url / method / submit
       │    ├─ PanelHistoryView
       │    │    ├─ SwiftUI 顶栏（计数 + 新建分组）
       │    │    └─ HistoryOutlineRepresentable → NSOutlineView
       │    ├─ PanelRequestView          # headers / body (JSON 字符串)
       │    ├─ PanelResponceView         # 响应
       │    └─ PanelStatusView → SettingsView（变量/脚本/导入导出）
       │
       ├─ NetworkDataModel               # makeRequest / updateHistory / 变量 / 脚本
       ├─ HistoryListUIStore             # selectedId, requestCount, treeRevision
       └─ NetworkEditorStore             # 表单字段，与列表分离

NetworkDataModel.historyRoots  ←→  HistoryOutlineController (AppKit)
XYNetTool (URLSession)

持久化: history.json v2 | UserDefaults(变量/脚本)
```

**状态拆分动机**：列表选中/刷新与编辑区加载分离，避免选中一项时整窗 SwiftUI diff。列表侧靠 `HistoryListUIStore.treeRevision` 驱动 Outline `reloadData()`；编辑区靠 `NetworkEditorStore` + 分阶段 `selectHistory`。

---

## `id` 与 `name` 分工

### 内部主键 `id`（`HistoryNode.id`，UUID）

用于：列表选中、删除、拖拽定位、加载编辑区、`history.json` 树内节点引用。

### 业务主键 `name`

**请求 `name`**（在所有 `type=request` 节点中全局唯一）：

- `updateHistory(with:)`：`item.name` 与已有请求同名 → 原地 `update`，**位置不变**；异名 → 新建 request 节点。
- `XYItem` 的 `==` / `hash` 仅基于 `name`（历史遗留，树模型仍以 `id` 为主）。
- 空名称提交时默认用 URL `host` 作为 `name`。
- **顶栏改 `requesName` 后提交**：用新 `name` 匹配；若与旧名不同则**新建一条**，旧条目仍保留（现有行为，非自动重命名）。

**分组 `name`**（在所有 `type=group` 节点中全局唯一）：

- 分组与请求 **可同名**（如分组「登录」+ 请求「登录」）。
- 重命名走 `renameGroup`，校验分组命名空间唯一。

| 场景 | 字段 |
|------|------|
| 列表选中、删除、拖拽、加载编辑区 | `HistoryNode.id` |
| 发请求写入历史（同名覆盖） | 请求 `name` |
| 分组重命名 / 唯一性校验 | 分组 `name` |

---

## `makeRequest()` 流程

1. `validateVariablesBeforeRequest()` — 空 key、重复 key、循环引用
2. `applyVariables(to:)` — 替换 URL / Header / Body 中的 `{{key}}`（**仅用于实际发包**）
3. 解析 Header、Parameters 为 JSON 对象（非法则 alert）
4. 组装 `XYItem`；**历史里存未替换的原始** `url` / `header` / `body`（`editor` 中的原文）
5. `correct(headers:params:)` — 若 `userScript` 非空，经 `/bin/sh` 预处理（**无 UI 入口**，见脚本节）
6. 若脚本返回 `response` → 直接写 `httpResponse`，跳过网络
7. 否则 `XYNetTool.get` / `.post` → 成功写 `httpResponse` + `updateHistory(with:)` + 可选后置脚本

---

## `updateHistory(with:)` 落点

```text
findRequestNode(byName:) 找到同名 request
  ├─ 有 → existing.update(with: item)，persistHistory，位置不变
  └─ 无 → HistoryNode.fromXYItem(item)
           ├─ 当前选中为分组 → insert 到该组 children 末尾
           └─ 否则 → append 到 historyRoots 根级末尾
```

写盘后由 `commitHistoryMutation` / `refreshHistoryListUI()` 递增 `treeRevision`，Outline 刷新。

---

## `selectHistory(id:)` 分阶段加载

为避免选中卡顿，加载拆两帧：

1. **metadata**：`editor.loadMetadata` — name、lock、url、method、脚本勾选（顶栏立刻刷新）
2. **text**：`editor.loadTextContent` — headers、body、response 等大字段（`DispatchQueue.main.async` 下一帧）

选中分组时：更新 `selectedId`，`currentHistory = nil`，不加载编辑区表单。

---

## 变量系统

- 语法：`{{key}}`，支持嵌套；`validateVariablesBeforeRequest()` 检测循环引用。
- 存 UserDefaults（`xydev.network.variables`）；设置页有解析预览 `variableResolutionPreview()`。
- 变量替换发生在 `makeRequest` 发包前；历史持久化的是**未替换**原文。

---

## 脚本

### 请求前 `userScript`（隐藏能力）

- `correct()` → `runUserScript`，经 `/bin/sh -c` 执行。
- 传入参数拼接：`url`、`method`、`headers` JSON、`params` JSON。
- 脚本 stdout 按行解析：
  - `{"headers":...,"parameters":...}` → 覆盖发包用的 header/params
  - `{"response":"..."}` → 跳过网络层，直接展示响应
- **注意**：经 JSON 解码的 Dictionary key 无序，含 MD5 等顺序敏感摘要时不适用此路径。

### 全局后置脚本

- 存在 `globalPostScripts`；每请求可勾选 `selectedPostScriptIDs`。
- 执行：`sh -c <command> "xy-post-script" <响应文本> <变量JSON>`；支持 `$1`/`$2`。
- 输出更新变量：JSON `{"variables":{...}}` 或多行 `key=value`。

---

## `XYNetTool` 要点

- 基于 `URLSession`；GET 拼 query，POST 默认 JSON body + `application/json`。
- 旧接口：`get`/`post` → `[String: Any]` 字典回调（`makeRequest` 仍用此路径）。
- 新接口：`request` → `NetResponse`（statusCode、headers、parsedBody）；**UI 未使用**。
- 默认不校验 HTTP 状态码（4xx 仍可能走 success 回调）。

---

## 历史列表（AppKit，2026 迁移完成）

### 文件职责

| 文件 | 职责 |
|------|------|
| `HistoryOutlineView.swift` | 子类化，右键 `menu(for:)` |
| `HistoryOutlineRepresentable.swift` | SwiftUI 桥接 |
| `HistoryOutlineController.swift` | DataSource / Delegate / 选中 |
| `+DragDrop.swift` | 拖拽 validate/accept |
| `+Delete.swift` | 删请求/删组弹窗 |
| `+Rename.swift` | 双击/菜单重命名 |
| `HistoryRowCellView.swift` | 行内容 + 删除 + 行内编辑 |
| `HistoryTableRowView.swift` | 行背景（选中/悬停/drop target） |
| `HistoryDragDrop.swift` | Pasteboard 类型 |

### 刷新路径

```text
commitHistoryMutation / refreshHistoryListUI()
  → requestCount / selectedId / treeRevision++
  → Representable 观察 treeRevision → reload(roots:)
  → reloadData 后恢复展开态（captureExpandedGroupIds）与选中行
```

折叠单独走 `setGroupCollapsed` / `toggleGroupCollapsed`：只改节点 `collapsed` + 写盘，**不**递增 `treeRevision`（避免与 `reloadData` 打架）。

### 拖拽（AppKit 原生）

- 整行发起：`pasteboardWriterForItem` + `shouldStartDragFromRow`（删除按钮区域除外）。
- 同级缝隙：`applySiblingOrder(parentId:orderedIds:)`。
- 拖入分组：`moveNodeIntoGroup`；跨父级：`moveNode(id:toParentId:atIndex:)`。
- 松手后一次 `commitHistoryMutation` 写盘；**不在拖拽帧写** `history.json`。
- 合法 drop 目标高亮：`HistoryTableRowView.isDropTarget`；禁止拖入自身子孙。

> **迁移背景**：SwiftUI 阶段曾用 `GeometryReader` + `PreferenceKey` 手搓跟手拖拽（`displayItems.move` + `dragTranslation` / `reorderCompensation`），行数增多后选中与主线程压力大，故迁 AppKit。旧实现已删除。

### 行高 / 缩进

`HistoryListLayout.rowHeight`（28）、`indentPerLevel`（12）；删除按钮 `historyRowAccessorySize`（22）。

---

## 导入导出

`exportNetworkConfigs` / `importNetworkConfigs` 需目录内三个文件齐全：

- `network_history.json`
- `network_variables.json`
- `network_global_scripts.json`

导入会**整体替换** `historyRoots`、变量、`globalPostScripts`；支持 v2 树形与 v1 扁平格式读取。

---

## 遗留代码（勿作主路径）

- `Network.storyboard` 引用不存在的 `NetRequestVC`
- `NetResquestController.swift` + xib
- `View/LeftView.swift`、`View/TopView.swift`（旧 Outline 草稿，基于扁平 `XYItem`）

---

## 已知局限 / 后续增强方向

- 仅 GET/POST；POST 固定 JSON body
- `history_path` 在 Bundle 资源目录，沙盒下可能不理想（可迁 Application Support）
- 响应区未展示 HTTP 状态码与 response headers
- `userScript` 无编辑入口（逻辑存在）
- 请求行无双击重命名 UI（仅分组支持）
