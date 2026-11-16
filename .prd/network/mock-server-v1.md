# 网络工具本地 Mock 服务 — PRD v1

> **状态**：P0 / P1 / P2 已实现  
> **模块**：Network / Mock Server  
> **最后更新**：2026-11-16  
> **依赖数据**：请求历史树 `historyRoots`（`HistoryNode` 的 method / url / response）

---

## 1. 背景与目标

网络工具已能保存接口请求与响应。目标是：把这些本地历史数据变成可被局域网设备访问的 **HTTP Mock 服务**，便于客户端联调、无后端时的接口模拟。

### 1.1 期望使用方式

1. 用户在网络工具中开启 Mock 服务  
2. 本机启动 HTTP 服务并监听端口  
3. 局域网设备访问 `http://<本机局域网IP>:<port>/<path>`  
4. 服务按规则匹配历史接口，返回对应已保存数据  

### 1.2 已确认决策（2026-11-16）

| # | 决策 | 结论 |
|---|------|------|
| 1 | 匹配粒度 | MVP：**HTTP Method + URL Path**（忽略 scheme / host / query） |
| 2 | 返回体 | **自动剥离** `_statusCode` / `_headers` / `_mimeType` 等调试字段后再返回业务 body |
| 3 | 路由范围 | 默认纳入历史中 **所有已有 response 的请求**（无需手动勾选） |

---

## 2. 范围

### 2.1 MVP 包含（P0）

| 能力 | 说明 |
|------|------|
| 启停服务 | 网络工具内 Toggle / 按钮；运行中显示状态 |
| 端口配置 | 可改端口；默认建议 `18080`；占用时明确报错 |
| 局域网可达 | 绑定 `0.0.0.0`；展示本机局域网 IP 与 Base URL（可复制） |
| 路由构建 | 扫描历史树全部 request 节点；仅纳入 `response` 非空者 |
| 匹配 | `METHOD + path`；忽略 query 与 host |
| 冲突 | 同 method+path 多条时，取 **历史树前序遍历中最后一条有 response 的**（≈最近写入/靠后的），UI 标「冲突」 |
| 响应 | 状态码 ← `_statusCode`（缺省 200）；Body ← 剥离 meta 后的内容；`Content-Type` 默认 `application/json`（文本类可按 `_mimeType` / `_text` 调整） |
| 未匹配 | 返回 `404` + 简短 JSON 错误说明 |
| 简易日志 | 窗口内显示最近若干条：时间、method、path、命中名/未命中、状态码 |
| 生命周期 | 停止服务可手动；关闭网络窗口或退出 App 时 **停止** 服务 |
| 安全提示 | UI 标明「调试用，会向局域网暴露历史响应数据」 |

### 2.2 明确不做（MVP）

- 按 body / header / query 精确匹配  
- 执行前置 / 后置脚本或变量实时替换  
- HTTPS、鉴权、仅本机模式（可进 P2）  
- 逐条启用开关、独立 Mock 编辑器（可进 P1/P3）  
- 延迟、失败率模拟  
- 复用「自定义服务器」现有终端壳实现  

---

## 3. 用户流程

```
打开网络工具
  → 历史中已有带 response 的请求
  → 打开 Mock 面板 / 点击开启
  → （可选）改端口
  → 服务启动成功，展示 Base URL 与路由数
  → 局域网设备请求对应 path
  → Mock 返回剥离后的 body
  → 用户停止服务或关闭窗口
```

### 3.1 界面建议（嵌入网络窗口）

- **入口**：底部状态栏旁或独立「Mock」折叠面板（避免另开主功能入口）  
- **控件**：启停、端口、本机 IP 列表（多网卡时）、复制 Base URL、路由数量、最近访问日志  
- **路由列表（可简）**：Method、Path、来源请求 name、是否冲突  

---

## 4. 路由与匹配规则

### 4.1 从历史生成路由

对每个 `HistoryNode`（`type == request`）：

1. `response` 为空 / 空白 → **跳过**  
2. 解析 `request.method`（缺省按 `GET`）与 `request.url`  
3. 从 url 取 **path**（无合法 URL 则跳过或记入无效列表）  
4. 规范化 path：保证以 `/` 开头；去除多余重复 `/`（MVP 不做复杂 normalize）  
5. 生成路由键：`"{METHOD} {path}"`（METHOD 大写）  

### 4.2 入站匹配

1. 读取入站 method + path（**丢弃 query**）  
2. 查路由表；命中则返回对应 mock  
3. 未命中 → `404`：

```json
{ "error": "mock_not_found", "method": "GET", "path": "/v1/foo" }
```

### 4.3 冲突

同一 `METHOD + path` 多条历史：

- 路由表只保留一条（前序遍历最后一条有 response）  
- UI 将该 path 标为冲突，并列出被覆盖的 name（P0 至少提示冲突数量；P1 展示明细）  

---

## 5. 响应组装

历史 `response` 为网络工具成功回调后的 **合成展示串**（见 Help）。Mock 返回时：

| 来源字段 | 用途 |
|----------|------|
| `_statusCode` | HTTP 状态码；缺失或非法 → `200` |
| `_headers` | MVP **默认不原样回放**（避免宿主头干扰）；固定必要头即可 |
| `_mimeType` | 辅助决定 Content-Type |
| `_text` | 若存在且无其它业务字段，作为文本 body |
| `_jsonArray` | 若存在，作为 JSON 数组 body |
| `_base64` | MVP 可返回 JSON `{"_base64":"..."}` 或直接二进制（建议 MVP：**仍包一层 JSON 说明**，P1 再支持原始二进制） |
| 其它键 | 合并为 JSON **对象** body |

剥离键集合（不得出现在业务 JSON body 中）：

- `_statusCode`  
- `_headers`  
- `_mimeType`  

若剥离后为空对象且无 `_text` / `_jsonArray`：返回 `{}`，状态码仍按上表。

---

## 6. 服务与网络

| 项 | MVP |
|----|-----|
| 绑定地址 | `0.0.0.0` |
| 协议 | HTTP/1.1 |
| CORS | MVP 可选：对所有 Origin 回 `Access-Control-Allow-Origin: *`（方便浏览器调试；实现时二选一并写进 Help） |
| OPTIONS | 若开 CORS，可对 OPTIONS 直接 `204` |
| 端口占用 | 启动失败，UI 提示换端口 |
| 防火墙 | Help 说明：局域网连不上时检查 macOS 防火墙 |

---

## 7. 架构建议（实现时对照）

| 部分 | 建议 |
|------|------|
| 数据 | 只读 `NetworkDataModel.historyRoots`；启服或历史变更时重建路由表 |
| 服务 | 独立 `MockServer`（如 `NWListener` + 简易 HTTP 解析），勿塞进 `XYNetTool` 发包路径 |
| UI | SwiftUI 面板，状态与日志 `@MainActor` |
| 日志 | 使用现有 `Logger` category（如 `network_mock`） |
| 与 CustomServer | **分离**；不复用其 Process/终端实现 |

历史变更时（Submit 更新、导入配置、删除）：

- 服务运行中 → **热更新路由表**（P0 需要，避免必须重启服务）  

---

## 8. 分期

| 阶段 | 内容 |
|------|------|
| **P0 MVP** | 启停、端口、IP/URL、Method+Path、剥离 meta、404、简易日志、关窗停服、冲突取最后一条 |
| **P1** | 路由行菜单（复制路径 / 完整 URL / curl）、冲突明细与指定胜出、逐条启用、未命中 Method 提示、轻量「自定义返回」Override（不改历史） |
| **P2** | query 匹配可选、仅本机 `127.0.0.1`、延迟、CORS 开关细化 |
| **P3** | 完整 Mock 资产（批量编辑、导入导出 Mock 集） |

---

## 9. 验收标准（P0）

1. 开启后，同一局域网设备可用 `http://<IP>:<port>/<path>` 访问  
2. 历史中带 response 的 `POST https://api.xx.com/v1/login` 可被 `POST /v1/login` 命中  
3. 返回 JSON **不含** `_statusCode` / `_headers` / `_mimeType`  
4. HTTP 状态码与历史中 `_statusCode` 一致（有则）  
5. 无匹配 path 返回 404 JSON  
6. 同 path 冲突时服务仍可启动，且行为符合「最后一条」规则  
7. 停止服务或关闭网络窗口后，端口不再接受连接  
8. 端口被占用时有明确错误，不静默失败  

---

## 10. 文档义务

实现后需更新：

- `Resource/Help/network-tool.md`（新增 Mock 章节）  
- `README.md` / `README.zh-CN.md`（网络工具简述）  
- `.cursor/skills/xydevtool-network/`（若存在实现说明）  
- 本目录 [README.md](./README.md) 索引状态  

---

## 11. 开放问题（可实现中再定，不阻塞 P0）

1. CORS：默认全开 `*` 还是默认关闭？  
2. `_base64` 响应 MVP 是包 JSON 还是直接二进制？  
3. 多网卡时默认展示哪块 IP（选第一个非 loopback / 让用户选）？  

---

## 12. 修订记录

| 日期 | 变更 |
|------|------|
| 2026-11-16 | 初版：确认 Method+Path、剥离 meta、默认全部有 response 的历史；划定 P0–P3 |
| 2026-11-16 | P0 落地：`FEATURES/Network/Mock/*` + `PanelMockView`；Help/README 已同步 |
| 2026-11-16 | P1：路由菜单（路径/URL/curl）、冲突指定胜出、逐条启用、Method 提示、自定义返回 Override |
| 2026-11-16 | P2：匹配 Query、仅本机、延迟、CORS 开关 |
