# 网络模块统一导出包 — PRD v1

> **状态**：v1 已实现  
> **模块**：Network / Export Bundle  
> **最后更新**：2026-11-17  

---

## 1. 目标

所有网络相关导出落到同一自建导出包内，按类别分目录；导入识别该包结构。兼容旧扁平配置目录与旧 Mock 单文件。

## 2. 包结构

```text
XYDevTool-Network-YYYYMMDD-HHmmss/
  manifest.json
  config/
    network_history.json
    network_variables.json
    network_global_scripts.json
    network_global_pre_scripts.json
  mock/
    network_mock_assets.json
  docs/
    api-docs.md
```

`manifest.json`：`version`（包格式，从 1）、`exportedAt`、`categories`、可选计数摘要。

## 3. 入口

| 操作 | 位置 | 行为 |
|------|------|------|
| 导出全部 | 设置 | 选父目录 → 建包 → config + mock + docs（docs=全部历史） |
| 仅导出配置 | 设置 | 建包只含 config |
| 导入 | 设置 | 选包根或旧扁平目录 → 导入 config（+mock 若有） |
| 导出 Mock 资产 | Mock 资产 | 建包只含 mock |
| 导入 Mock 资产 | Mock 资产 | 包内 mock 文件或旧单文件 JSON |
| 导出文档 | 文档窗 | 建包只含 docs |

分项导出每次新建时间戳包，不追加进上次包。docs 导入忽略。

## 4. 验收

1. 导出全部生成带时间戳包，可再导入 config+mock  
2. 分项包只含对应类目且 manifest 正确  
3. 旧扁平配置目录、旧 Mock 单文件仍可导入  
4. 文档导入不改 App 状态  

## 5. 修订记录

| 日期 | 变更 |
|------|------|
| 2026-11-17 | 初版定稿并落地 |
