# 网络请求工具

轻量、纯本地的 HTTP 调试工具，适合日常接口联调。数据保存在本机，可整套导出/导入。

## 发请求

1. 填写 **请求名称**、**URL**，选择 **GET / POST**
2. 在请求头 / 请求参数区输入 **JSON 对象**
3. 点击 **Submit** 发送

| 规则 | 说明 |
|------|------|
| 名称留空 | 自动使用 URL 的 host |
| 同名请求 | 再次 Submit **覆盖** 原记录 |
| 异名请求 | **新建** 一条历史 |
| 选中分组 | 新建请求落入该分组；否则在根级 |

## 历史记录（树形）

- 左侧树形展示，支持 **多层分组**、展开/折叠
- 点击 **请求** → 加载到编辑区；点击 **分组** → 选中，用于在其下新建
- 顶栏 **+**：选中分组时在其下新建分组，否则根级新建
- **整行拖拽**：同层排序、拖入/拖出分组（点删除按钮不会触发拖拽）
- **分组**：双击或右键重命名；删除时可「仅删分组」或「删分组及内容」
- **请求**：行尾删除；🔒 锁定后不可删

## 变量

在 URL / Header / Body 中使用 `{{key}}`，发请求前自动替换。

- 设置 ⚙️ → **变量设置** → 新增 key/value
- 支持嵌套；设置页可预览最终解析结果
- 历史里存 **未替换** 的原文

## 前置脚本（请求前）

用于签名、改 Header/Body 等，再交给 App 发包。

### 配置

1. 设置 → **全局前置脚本库** → 新增脚本
2. 命令示例：`swift ~/swift-pre-script.swift`（直接写 shell 或外部路径均可）
3. 选中历史请求 → **当前接口前置脚本**（单选）

### 传参方式

App 通过环境变量 **`XYDEV_PRE_REQUEST_JSON`** 注入请求 JSON，内容包括：

- `url` / `method`
- `headersText` / `parametersText`（可为空，视为 `{}`）
- `headers` / `parameters`（解析后的对象，作备用）

### 输出（stdout 一行 JSON）

| 模式 | 输出 | 行为 |
|------|------|------|
| 改包继续发 | `parametersText` + 可选 `headersText`、`url` | App **原样**写入 httpBody，保 key 顺序 |
| GET 已签名 | 完整 `url`（含 query） | 不再从字典拼 query |
| 脚本代发 | `{"response":"..."}` | 跳过 HTTP，直接展示 |
| 失败 | `{"error":"..."}` 或 stderr | 弹窗提示 |

### 签名注意

- POST 请用 **`parametersText`** 返回签名后的 JSON 字符串
- 不要只返回 `parameters` 对象，否则可能经 Dictionary 重序列化导致顺序变化、验签失败

## 后置脚本（响应后）

1. 设置 → **全局后置脚本库** → 新增脚本
2. 命令支持 `$1` / `$2`：`$1`=响应文本，`$2`=变量 JSON
3. 选中请求 → **当前接口后置脚本**（可多选）
4. 输出 JSON `{"variables":{...}}` 或多行 `key=value` 写回变量

## 导入 / 导出

导出目录包含：

- `network_history.json`
- `network_variables.json`
- `network_global_scripts.json`（后置）
- `network_global_pre_scripts.json`（前置）

导入时会整体替换对应数据。

## 限制

- 仅 GET / POST；POST 默认 JSON body
- 响应区展示 body 原文，暂未展示 HTTP 状态码与响应头
