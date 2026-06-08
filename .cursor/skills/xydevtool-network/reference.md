# XYDevTool 网络模块 — 参考

## 架构

```text
ViewController.openNetworkWindow()
  └─ NSHostingController(NetworkPanelView.environmentObject(NetworkDataModel()))
       ├─ PanelTopView          # name / url / method / submit
       ├─ PanelHistoryView      # 历史 + 拖拽排序
       ├─ PanelRequestView      # headers / body (JSON 字符串)
       ├─ PanelResponceView     # 响应
       └─ PanelStatusView       # 状态 + SettingsView（变量/脚本/导入导出）

NetworkDataModel (业务)
  ├─ makeRequest / updateHistory / 变量 / 脚本
  └─ XYNetTool (URLSession)

持久化: history.json | UserDefaults(变量/脚本)
```

## `name` 主键语义（与 itemID 方案对比后的结论）

- `XYItem.name`：用户可见名称，可修改。
- `updateHistory(with:)`：`item.name == item_his.name` → 原地 `update`；否则 `append`。
- `XYItem` 的 `==` / `hash` 仅基于 `name`。
- 空名称提交时默认用 URL `host` 作为 `name`。
- **重命名后提交**：用新 `requesName` 匹配，旧 `name` 条目仍保留（会多出一条），这是现有行为，非重名覆盖。

因此列表定位统一用 `name`；无需 `itemID`，除非未来允许同名并存。

## `makeRequest()` 流程

1. `validateVariablesBeforeRequest()` — 空 key、重复 key、循环引用
2. `applyVariables(to:)` — 替换 URL / Header / Body 中的 `{{key}}`
3. 解析 Header、Parameters 为 JSON 对象（非法则 alert）
4. 组装 `XYItem`，**历史里存未替换的原始** url/header/body
5. `correct(headers:params:)` — 若 `userScript` 非空，Shell 预处理（**无 UI**）
6. `XYNetTool.get` / `.post` → 成功写 `httpResponse` + `updateHistory(with:)` + 可选后置脚本

## 变量系统

- 语法：`{{key}}`，支持嵌套；检测循环引用。
- 存 UserDefaults；设置页有解析预览 `variableResolutionPreview()`。

## 脚本

### 请求前 `userScript`（隐藏能力）

- `runUserScript` 经 `/bin/sh` 执行。
- 输出 JSON 行：`{"headers":...,"parameters":...}` 或 `{"response":"..."}` 跳过网络层。

### 全局后置脚本

- 存在 `globalPostScripts`；每请求可勾选 `selectedPostScriptIDs`。
- 执行：`sh -c <command> "xy-post-script" <响应文本> <变量JSON>`；支持 `$1`/`$2`。
- 输出更新变量：JSON `{"variables":{...}}` 或多行 `key=value`。

## `XYNetTool` 要点

- 基于 `URLSession`；GET 拼 query，POST 默认 JSON body + `application/json`。
- 旧接口：`get`/`post` → `[String: Any]` 字典回调。
- 新接口：`request` → `NetResponse`（statusCode、headers、parsedBody）；**UI 未使用**。
- 默认不校验 HTTP 状态码（4xx 仍可能走 success）。

## 历史拖拽实现摘要（PanelHistoryView）

```swift
// 拖动中
displayItems.move(...)  // 带 spring 动画
reorderCompensation += indexDelta * rowHeight

// 显示
.offset(y: dragTranslation - reorderCompensation)

// 松手
dataModel.applyHistoryOrder(displayItems)
```

**光标漂移根因（已修）**：在 `performLiveMove` 里 `dragTranslation -= ...` 会被下一帧 `dragTranslation = value.translation.height` 覆盖，补偿无法累计。

## 导入导出

`exportNetworkConfigs` / `importNetworkConfigs` 需要目录内三个文件齐全；导入会整体替换 `historyArray`、`variables`、`globalPostScripts`。

## 遗留代码（勿作主路径）

- `Network.storyboard` 引用不存在的 `NetRequestVC`
- `NetResquestController.swift` + xib、`View/LeftView.swift`、`View/TopView.swift`

## 已知局限 / 后续增强方向

- 仅 GET/POST；POST 固定 JSON body
- `history_path` 在 Bundle 资源目录，沙盒下可能不理想（可迁 Application Support）
- 响应区未展示 HTTP 状态码与 response headers
- `userScript` 无编辑入口
