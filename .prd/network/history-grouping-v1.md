# 请求历史多层分组 — PRD v1

> **状态**：已实现  
> **模块**：Network / 请求历史列表  
> **最后更新**：2026-06-08  
> **列表 UI**：AppKit `NSOutlineView`（见 [history-appkit-migration.md](./history-appkit-migration.md)）

---

## 1. 背景与现状

### 1.1 当前实现（v1 + AppKit 迁移后）

- 历史为**树形根数组** `historyRoots: [HistoryNode]`，持久化 `history.json` v2：

  ```json
  { "version": 2, "item": [ { "type": "group", "id": "...", "children": [ ... ] }, ... ] }
  ```

- **`id` 是内部主键**：选中 / 删除 / 拖拽 / 加载编辑区一律用 `HistoryNode.id`（UUID）。
- **请求 `name` 是业务主键**：发请求时同名覆盖更新、异名新建（见 §6）。
- **展示顺序** = 各层 `children` 数组顺序 = `history.json` 中树结构顺序。
- **主 UI**：`PanelHistoryView`（SwiftUI 顶栏）+ `HistoryOutlineRepresentable` → AppKit `NSOutlineView`；整行拖拽排序（删除按钮区域除外），松手 `commitHistoryMutation` 写盘。
- **行高**：`HistoryListLayout.rowHeight`（28pt，含最小高度防重叠）。
- **列表状态**：`HistoryListUIStore`（`selectedId` / `requestCount` / `treeRevision`）；编辑区字段在 `NetworkEditorStore`，与列表分离。

### 1.2 痛点

同功能模块的请求较多时，扁平列表难以组织；需要类似 **Xcode 项目导航器** 的分组能力。

---

## 2. 目标（v1 范围）

| 包含 | 不包含（可 v2） |
|------|----------------|
| 多层分组（组内可再建组） | 行缝隙精确插入位置 |
| 顶栏「+」创建分组 | 多选、批量移动 |
| 请求 / 分组拖入、拖出、组嵌套 | 搜索过滤 |
| 同层整行拖拽排序（组 + 请求） | |
| 分组折叠，状态持久化 | |
| 空分组 `(empty)` 标记 | |
| 删分组弹窗 + 锁定项二次确认 | |
| **分组重命名**（双击 / 右键） | 请求重命名 UI |

---

## 3. 数据模型

### 3.1 节点 `HistoryNode`

| 字段 | group | request | 说明 |
|------|:-----:|:-------:|------|
| `id` | ✅ | ✅ | 全局唯一 UUID；创建后不变；**所有内部操作主键** |
| `type` | `"group"` | `"request"` | 节点类型 |
| `name` | ✅ | ✅ | 业务展示名（见 §3.2 命名空间） |
| `collapsed` | ✅ | — | 是否折叠；默认 `false`（展开） |
| `children` | ✅ | — | 有序子节点数组；顺序 = 展示 / 排序顺序 |
| `request` / `isLock` / `enablePostScript` / `postResponseScript` / `selectedPostScriptIDs` / `response` | — | ✅ | 沿用现有 `XYItem` 字段 |

### 3.2 命名空间（分开唯一）

| 类型 | 唯一性 |
|------|--------|
| 请求 `name` | 在所有 `type=request` 节点中**全局唯一** |
| 分组 `name` | 在所有 `type=group` 节点中**全局唯一** |

- ✅ 允许：分组叫「登录」、请求也叫「登录」
- ❌ 禁止：两个请求同名；两个分组同名

重命名、新建时须校验对应命名空间；冲突则提示，不提交。

### 3.3 `id` 与 `name` 分工

| 场景 | 规则 |
|------|------|
| 列表选中、加载编辑区、删除、拖拽定位 | 使用 **`id`** |
| 发请求写入历史（**保留现有逻辑**） | 按请求 **`name`**：同名 → 更新该 request 节点；异名 → 新建 request |
| `updateHistory` 匹配范围 | **仅** `type=request` 节点，不误匹配分组 |
| 重命名 | 修改 `name`，`id` 不变 |

### 3.4 持久化格式（v2）

```json
{
  "version": 2,
  "item": [
    {
      "type": "group",
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "登录模块",
      "collapsed": false,
      "children": [
        {
          "type": "request",
          "id": "660e8400-e29b-41d4-a716-446655440001",
          "name": "获取 token",
          "isLock": false,
          "request": { "method": "POST", "url": "...", "header": "...", "body": "..." }
        },
        {
          "type": "group",
          "id": "770e8400-e29b-41d4-a716-446655440002",
          "name": "子流程",
          "collapsed": true,
          "children": []
        }
      ]
    },
    {
      "type": "request",
      "id": "880e8400-e29b-41d4-a716-446655440003",
      "name": "未分组请求",
      "request": { ... }
    }
  ]
}
```

### 3.5 迁移与兼容

| 情况 | 处理 |
|------|------|
| 旧 `history.json` 无 `version` / 无 `type` | 每条视为根级 `request`；启动时补 `id` |
| 缺失 `collapsed` | 视为 `false`（展开） |
| 导出 `network_history.json` | 使用 v2 格式 |
| 导入 | 支持 v2；兼容读取 v1 扁平格式 |

---

## 4. UI 规范

### 4.1 顶栏「+」— 创建分组

入口：`PanelHistoryView` 顶栏 **「+」** 按钮（「请求历史(n)」右侧）。

| 当前选中 | 行为 |
|----------|------|
| 选中 **`type=group`** | 在该组下新建空子分组 |
| 未选中，或选中 **`type=request`** | 在**根级**新建空分组 |

**默认分组名**：`新分组`、`新分组 2`、`新分组 3`…（在分组命名空间内自动去重）。

### 4.2 列表行布局（AppKit）

**原则**：系统 disclosure 控制折叠；名称随 `NSOutlineView` 层级缩进（`HistoryListLayout.indentPerLevel` = 12pt）；整行可拖拽。

```
▼  登录模块                                    🗑
▶  子流程 (empty)                              🗑
     获取 token                                  🗑
   未分组请求                                    🗑
```

| 元素 | 分组行 | 请求行 |
|------|--------|--------|
| 折叠三角 `▶/▼` | ✅ 系统 disclosure；点击切换折叠 | — |
| 名称 | 随层级缩进（每层 +12pt） | 缩进随父级深度 |
| `(empty)` 后缀 | 见 §4.3 | — |
| 删除 🗑 | ✅ 行尾 `NSButton` | ✅（锁定项逻辑不变） |
| 选中 / 悬停 | ✅ `HistoryTableRowView` 背景 | ✅；点击加载到编辑区 |
| 拖拽 | ✅ 整行（排除删除按钮 hit area） | ✅ 整行 |

### 4.3 `(empty)` 判定

分组标题显示为 **`名称 (empty)`** 当且仅当：

> 该分组**子树内没有任何 `type=request` 节点**。

说明：子分组全是空壳、子树内零请求时，父组仍显示 `(empty)`。拖入第一条请求后后缀自动消失。

### 4.4 折叠

- 点击三角切换 `collapsed`，立即持久化。
- **默认展开**；下次打开以用户上次操作为准。
- 折叠时隐藏该组下全部子孙（含子组、请求）。

### 4.5 分组重命名

**入口（二选一）**：

1. **双击**分组名称 → 进入行内编辑
2. **右键**分组行 → 上下文菜单 → **「重命名」** → 进入行内编辑

**编辑行为**：

| 项 | 规则 |
|----|------|
| 确认 | `Enter` 或失焦（focus 离开） |
| 取消 | `Esc` |
| 校验 | 分组命名空间内不可与已有分组重名；不可为空 |
| 冲突 | Alert 提示，保持编辑前名称 |
| 写盘 | 成功后更新 `name` 并持久化；`id` 不变 |

> v1 **不包含**请求重命名 UI；请求仍通过顶栏名称字段在提交时体现。

---

## 5. 拖拽交互

实现：`HistoryOutlineController+DragDrop.swift`（AppKit 原生拖拽）。

### 5.1 整行拖拽 — 同层排序

- **分组、请求**均可拖拽排序（`shouldStartDragFromRow` 排除删除按钮区域）。
- **仅限同一父节点**下的兄弟节点之间调整顺序（`applySiblingOrder`）。
- 同一父下分组与请求可**混排**。
- 松手后一次写盘（`commitHistoryMutation` → 更新父级 `children` 或根 `item` 顺序）。

### 5.2 拖入 / 拖出（drop）

| 操作 | 结果 |
|------|------|
| 请求 → 分组行 | 成为该组子节点，追加到 **children 末尾** |
| 请求 → 根级有效落点 | 从组内移出至根级 |
| 分组 → 分组行 | 成为目标组的子分组，追加到 **children 末尾** |
| 分组 → 根级有效落点 | 从原父级移出至根级 |
| 分组 → 自身任意子孙 | **禁止**（防环） |
| 拖到请求行缝隙 | v1 **不支持**精确插入 |

### 5.3 视觉反馈

- 合法 drop 目标（分组行）：`HistoryTableRowView.isDropTarget` 高亮。
- 非法（成环等）：不高亮 / 不响应 drop。
- 拖拽由 `NSOutlineView` 原生机制驱动，无 SwiftUI `GeometryReader` / `PreferenceKey` 跟手逻辑。

---

## 6. 新建 / 更新请求落点

发请求保存历史时（`makeRequest` → `updateHistory`）：

| 场景 | 落点 |
|------|------|
| **同名** | 找到已有 request 节点，**原地更新**，位置不变 |
| **异名新建** | 当前选中为 **分组** → 新建在该组 `children` 末尾；否则 → **根级** 末尾 |

---

## 7. 删除分组

### 7.1 第一次弹窗

用户点击分组行 🗑 后：

| 选项 | 行为 |
|------|------|
| **仅删除分组** | 该组全部子节点（子组 + 请求）提升到被删组的**父级**，占据被删组原位置；内部相对顺序不变 |
| **删除分组及全部内容** | 递归删除该组及子树内所有节点 |
| **取消** | 不操作 |

**「仅删除分组」与锁定**：锁定请求随子树**上移**到父级，不删除请求本身，无需二次确认。

### 7.2 含锁定请求 + 选「删除全部」

若子树内存在 `isLock == true` 的请求，二次弹窗：

> 该分组包含 **N** 个锁定请求

| 选项 | 行为 |
|------|------|
| **强制删除** | 忽略锁定，递归删除整棵子树 |
| **取消** | 不操作 |

### 7.3 单条请求删除

与现网一致：锁定项不可直接删除，需先解锁。

---

## 8. 与代码的 API 映射（当前）

| 概念 | 实现 |
|------|------|
| 历史数据源 | `NetworkDataModel.historyRoots: [HistoryNode]` |
| 列表 UI 刷新 | `refreshHistoryListUI()` → `treeRevision++` |
| 选中 | `selectHistory(id:)` / `HistoryListUIStore.selectedId` |
| 删除请求 | `removeHistory(id:)`（经 `HistoryListActions`） |
| 同层排序 | `applySiblingOrder(parentId:orderedIds:)` |
| 跨层 / 入组 | `moveNode(id:toParentId:atIndex:)` / `moveNodeIntoGroup` |
| 更新 / 新建请求 | `updateHistory(with:)` — 按 request `name` 全局查找 |
| 分组 CRUD | `createGroup()` / `deleteGroup(id:unwrapOnly:)` / `renameGroup(id:to:)` |
| UI 操作门面 | `HistoryListActions` → `PanelHistoryView` / `HistoryOutlineController` |
| 设置页判断选中请求 | `dataModel.isSelectedRequest` |
| 导入 / 导出 | v2 格式 + v1 扁平格式兼容读取 |

---

## 9. 实现顺序（已完成）

1. ✅ **模型 + 持久化**：`HistoryNode`、v2 JSON 读写、旧数据迁移  
2. ✅ **DataModel 树 API**：按 `id` 查找、同层排序、移动节点、建组、删组、按 `name` 更新 / 新建请求  
3. ✅ **AppKit 历史树**：`HistoryOutlineRepresentable` + `HistoryRowCellView`；缩进、`(empty)`、折叠  
4. ✅ **拖拽**：整行同层排序 + drop 入组 / 出组 / 组嵌套 + 防环  
5. ✅ **顶栏「+」**、删组弹窗、锁定二次确认  
6. ✅ **分组重命名**：双击 + 右键菜单 + 行内 `NSTextField`  
7. ✅ **导入导出** + AppKit 迁移 Phase 5 清理（移除 SwiftUI 扁平列表遗留）  

---

## 10. 测试清单

### 数据与迁移

- [ ] 旧 `history.json` 升级：补 `id`、根级 request、发请求 / 选中 / 删除行为正常  
- [ ] v2 导出再导入，树结构一致  
- [ ] 请求同名覆盖、异名新建；不与 group 名误判  

### 命名空间

- [ ] 两请求不能同名；两组不能同名  
- [ ] 分组「登录」+ 请求「登录」可并存  
- [ ] 分组重命名冲突时提示且不保存  

### 分组 CRUD

- [ ] 「+」：选中组 → 子组；无选中 / 选中请求 → 根级  
- [ ] 空组 `(empty)`；仅含空子组时父组仍 `(empty)`  
- [ ] 折叠 / 展开持久化，重启保持  

### 重命名

- [ ] 双击分组名进入编辑；Enter / 失焦保存  
- [ ] Esc 取消  
- [ ] 右键「重命名」进入编辑  
- [ ] 重名拒绝、空名拒绝  

### 拖拽

- [ ] 同层整行排序（组 + 请求混排）  
- [ ] 请求拖入组、拖出根级  
- [ ] 组拖入组（多层）  
- [ ] 拖入自身子孙 → 禁止  
- [ ] 名称随层级缩进；删除按钮区域不触发拖拽  

### 删除

- [ ] 仅删组：内容上移，锁定请求保留且仍锁定  
- [ ] 删全部 + 含锁定：二次确认；强制删除 / 取消  
- [ ] 单条锁定请求仍不可直接删  

### 业务

- [ ] 异名新建落在选中组下（§6）  
- [ ] 选中请求加载编辑区  
- [ ] 选中分组时顶栏「+」建子组  

---

## 11. 决策记录（完整）

| # | 议题 | 决策 |
|---|------|------|
| 1 | 嵌套层级 | 多层 |
| 2 | 主键 | `id` 全局唯一；`name` 为业务名 |
| 3 | 命名空间 | 分组名、请求名**分开唯一** |
| 4 | 历史更新逻辑 | 保留：请求同名更新，异名新建 |
| 5 | 删分组 | 弹窗：仅删组 / 删全部 / 取消 |
| 6 | 删全部含锁定 | 二次确认：强制删除 / 取消 |
| 7 | 折叠 | 要；默认展开；持久化用户选择 |
| 8 | 空分组 | 允许；`(empty)` 后缀 |
| 9 | 创建分组入口 | 顶栏「+」 |
| 10 | v1 拖拽 | 组拖入组：要；整行同层排序：要 |
| 11 | 「+」落点 | 选中组 → 子组；否则根级 |
| 12 | 新建请求落点 | 异名：选中组 → 组内，否则根级；同名原地更新 |
| 13 | `(empty)` 判定 | 子树内无任何 request |
| 14 | 拖拽与缩进 | 整行拖拽（排除删除按钮）；名称区随层级缩进 |
| 15 | 分组重命名 | 双击或右键；校验分组命名空间唯一 |

---

## 12. 附录：行高配置（AppKit）

| 常量 | 位置 | 默认值 | 说明 |
|------|------|--------|------|
| `HistoryListLayout.rowHeight` | `NetworkDataModel` | 28 | Outline 行高 |
| `HistoryListLayout.indentPerLevel` | `NetworkDataModel` | 12 | 每层缩进 |
| `historyRowAccessorySize` | `NetworkDataModel` | 22 | 行尾删除按钮边长 |
| `historyRowVerticalPadding` | `NetworkDataModel` | 3 | 行内上下 padding |
| `historyRowMinHeight` | `NetworkDataModel` | 28 | accessory + padding×2 |

---

## 13. 修订记录

| 日期 | 变更 |
|------|------|
| 2026-06-08 | 初版定稿 |
| 2026-06-08 | v1 功能实现完成 |
| 2026-06-08 | 同步 AppKit 迁移后现状：整行拖拽、NSOutlineView UI、API 与行高常量 |
