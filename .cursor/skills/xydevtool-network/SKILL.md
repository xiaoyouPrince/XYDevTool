---
name: xydevtool-network
description: >-
  XYDevTool macOS 网络请求模块：架构、文件地图、name 主键语义、持久化、拖拽排序与
  常见改动入口。在修改 FEATURES/Network、网络历史、变量/脚本、导入导出、XYNetTool
  或用户提到网络请求工具时使用。
---

# XYDevTool 网络模块

## 先读这三条（高价值、易踩坑）

1. **`name` 是业务主键**：同名历史会覆盖更新，不会并存；列表选中/删除/排序/拖拽都用 `name`。**不要加 itemID**。
2. **展示顺序 = `historyArray` 数组顺序 = `history.json` 中 `item` 数组顺序**；改顺序只动数组，无需 `sortOrder` 字段。
3. **主入口是 SwiftUI**：`ViewController.openNetworkWindow()` → `NetworkPanelView` + `NetworkDataModel()`。`Network.storyboard` / `NetResquestController` 是遗留，勿当主路径。

## 文件地图（改什么去哪个文件）

| 目标 | 文件 |
|------|------|
| 发请求、变量、脚本、历史读写 | `XYDevTool/FEATURES/Network/NetworkDataModel.swift` |
| HTTP 底层 | `XYDevTool/FEATURES/Network/XYNetTool.swift` |
| 数据模型 `XYItem` / `XYRequest` | `XYDevTool/FEATURES/Network/NetModels.swift` |
| 主布局 | `SwiftUIViews/NetworkPanelView.swift` |
| 顶栏 URL/Method/Submit | `SwiftUIViews/PanelTopView.swift` |
| 历史列表 + 拖拽排序 | `SwiftUIViews/PanelHistoryView.swift` |
| Header/Body 编辑 | `SwiftUIViews/PanelRequestView.swift` |
| 响应展示 | `SwiftUIViews/PanelResponceView.swift` |
| 变量/脚本/导入导出 | `SwiftUIViews/PanelSettingsView.swift` |
| 打开窗口 | `XYDevTool/ViewController.swift` → `openNetworkWindow()` |
| 历史路径协议 | `XYDevTool/Protocols/BaseDataProtocol.swift` |

## 持久化

| 数据 | 位置 |
|------|------|
| 请求历史 | `Bundle.main.resourcePath + "/history.json"`（`BaseDataProtocol.history_path`） |
| 变量 | `UserDefaults` → `xydev.network.variables` |
| 全局后置脚本 | `UserDefaults` → `xydev.network.globalPostScripts` |
| 导出三文件 | `network_history.json`、`network_variables.json`、`network_global_scripts.json` |

`historyArray` 的 `didSet` 会调用 `updateHistory()` 写盘。

## 数据层关键 API

```text
setCurrentHistory(with name:)     # 选中历史加载到编辑区
updateHistory(with item:)          # 按 name 覆盖或 append
makeRequest()                      # 校验变量 → 替换 {{var}} → XYNetTool
applyHistoryOrder(_ items:)        # 拖拽结束写回顺序（有变化才持久化）
removeHistory(named:)              # 按 name 删除
moveHistory(fromName:toName:)       # 按 name 换位（较少直接用，拖拽走 applyHistoryOrder）
```

## UI：历史拖拽排序（已实现）

- **仅** `≡` 把手 `DragGesture`；行点击选中，垃圾桶删除。
- 拖动中改本地 `displayItems`；松手 `applyHistoryOrder(displayItems)`。
- 跟光标三变量（勿混用）：
  - `dragTranslation` = 每帧手势位移（只赋值，不在 move 里减）
  - `reorderCompensation` = 每次让位累加 `indexDelta × rowHeight`
  - 视觉偏移 = `dragTranslation - reorderCompensation`
- 容器用 `ScrollView + VStack`（不用 `List.onMove` 整行拖）。

## 常见任务速查

| 任务 | 做法 |
|------|------|
| 加 HTTP 方法 | `HttpMethod`（UI）+ `XYNetTool.RequestType` + `makeRequest` switch |
| 展示 statusCode/headers | UI 未接；`XYNetTool.request` → `NetResponse` 已存在 |
| 请求前脚本 UI | `userScript` 有逻辑无界面，接 `SettingsView` 或顶栏 |
| 新历史字段 | `XYItem` + `update(with:)` + 导出字典 + `setCurrentHistory` |
| 修拖拽跟手 | 查 `PanelHistoryView` 补偿是否写进 `dragTranslation`（反模式） |

## 不要做的事

- 不要用 `ForEach(..., id: \.self)` 索引作历史列表 id（拖拽会错乱）
- 不要为排序单独引入 `itemID`（与现有 `name` 主键冲突）
- 不要在拖拽每一格都写 `history.json`（用 `displayItems` 缓冲，松手再 `applyHistoryOrder`）
- 不要改 `NetResquestController` 当主 UI

## 延伸阅读

细节（请求流程、变量/脚本协议、`XYNetTool` 限制、遗留代码）见 [reference.md](reference.md)。
