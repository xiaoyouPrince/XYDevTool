# 可移植、低耦合日志体系设计思考

> 本文记录 XYDevTool 日志方案的讨论和收敛过程，用于后续实现、重构及其他项目复用。目标架构已经完成首轮落地，具体状态见文末。

## 1. 背景与目标

日志功能最初需要解决以下问题：

1. 记录用户在 App 中的主要使用路径。
2. 采集关键运行时数据，支持问题定位和基础统计。
3. 将日志持久化到本地文件。
4. 在 App 内提供日志查看入口。
5. 记录网络请求的发起、响应、耗时和错误等关键阶段。

随着实现推进，问题从“如何把日志写出来”转变为“如何控制日志对业务代码的侵入，并让这套能力可以迁移到其他项目”。

## 2. 方案演进

### 2.1 业务直接依赖具体 Logger

最直接的做法是在业务代码中调用 `AppLogger.shared`，传入业务分类、事件及数据。

优点是实现快、调用直观；但它会产生明显耦合：

- 业务模块依赖具体 Logger、单例和存储实现。
- 日志分类、业务事件与当前 App 功能绑定。
- Logger 的替换、测试和跨项目迁移成本较高。
- 网络等基础模块失去独立性。
- 请求和响应容易被不同层级重复记录。

因此，具体 Logger 不应成为所有业务模块的直接依赖。

### 2.2 为每个模块定义 `XXSink`

第二种思路是为网络、导航、任务等模块分别定义事件 Sink，再由 App 层实现 Sink 并转发给日志系统。

这种方案边界清晰，也适合少量、稳定且真正需要独立替换的模块。但如果推广到所有业务，会产生新的问题：

- 每个模块都要定义协议、事件方法和适配器。
- 方法名与当前业务语义绑定，需求变化时需要跨层修改。
- 新项目业务不同，原有 Sink 很难直接复用。
- 类型数量和样板代码会随业务规模持续增长。

Sink 并没有消除耦合，只是把对 Logger 的耦合替换成了大量业务协议耦合。

### 2.3 单一 `EventRecorder` 与强类型 Event

进一步收敛后，可以只保留一个通用事件记录协议，并用强类型 Event 或 Span 表达业务行为。

该方案比多个 Sink 更统一，也更适合统计。但如果 Event 类型、字段结构和 Span 模型进入每个业务模块，仍然会带来较重的类型依赖。对于规模较小、业务变化频繁或需要快速迁移的项目，收益未必覆盖维护成本。

### 2.4 收敛为字符串优先的通用日志抽象

最终思路参考 xLog、OSLog Logger 等常见日志接口：业务只依赖一个足够小、稳定、以字符串为主要输入的抽象。

调用层不需要知道日志写入 JSONL、OSLog、数据库还是远程服务，也不需要为每种业务建立协议。具体存储、脱敏、轮转和查看功能由日志后端负责。

这不是放弃结构化日志，而是把“调用依赖”与“存储结构”分开：调用 API 保持轻量，落盘记录仍然可以拥有统一的时间、级别、分类、事件名、跟踪 ID 和扩展字段。

## 3. 目标设计原则

1. **依赖最小化**：业务只依赖稳定的日志门面，不依赖具体 Logger、单例、文件存储或 UI。
2. **字符串优先**：分类、事件名、消息和扩展字段以基础字符串表达，减少业务类型传播。
3. **结构化落盘**：调用简单不等于只存一段文本，后端仍应生成结构化记录。
4. **包装可选**：业务可直接调用基础 API，也可在自身模块内增加便捷包装。
5. **包装不反向进入核心**：业务包装属于业务模块，通用日志核心不认识具体功能和事件。
6. **网络边界独立**：网络工具通过 Delegate 暴露生命周期数据，不直接依赖日志体系。
7. **默认低成本**：关闭某级别日志时，不应提前构造大型请求体、响应体或复杂字段。
8. **敏感数据受控**：认证信息、Cookie、个人数据等由统一策略过滤，不依赖调用者自觉处理。

## 4. 分层结构

建议将日志能力分为三层：

```text
业务模块
  ├─ 直接使用基础字符串 API
  └─ 可选的业务包装层
             │
             ▼
通用 Logger 门面
  - level / category / event / message / traceID / fields
             │
             ▼
可替换日志后端
  - 本地文件、OSLog、内存、测试替身、组合输出
  - 过滤、脱敏、序列化、轮转
```

业务包装只负责提高重复调用的一致性，不是日志核心的必要组成部分。

## 5. 基础字符串 API

基础 API 可以保持为轻量值类型，示意如下：

```swift
public struct Logger {
    public init(category: String)

    public func debug(_ message: @autoclosure () -> String)
    public func info(_ message: @autoclosure () -> String)
    public func warning(_ message: @autoclosure () -> String)
    public func error(_ message: @autoclosure () -> String)

    public func event(
        _ name: String,
        message: @autoclosure () -> String = "",
        traceID: String? = nil,
        fields: @autoclosure () -> [String: String] = [:]
    )
}
```

建议的调用形式：

```swift
private let logger = Logger(category: "network")

logger.info("Preparing request")

logger.event(
    "request.completed",
    traceID: requestID,
    fields: [
        "method": request.httpMethod ?? "",
        "statusCode": String(statusCode),
        "durationMs": String(durationMs)
    ]
)
```

这里保留 `event` 和 `fields`，是因为仅有自由文本很难可靠统计。它们仍然只使用基础类型，不要求业务依赖 Event、Payload 或 Span 等专用模型。

## 6. 业务层可选包装

业务层可以自由选择直接使用基础 API，或者针对稳定、重复的事件增加包装。例如：

```swift
extension Logger {
    func requestCompleted(
        requestID: String,
        statusCode: Int,
        durationMs: Int
    ) {
        event(
            "request.completed",
            traceID: requestID,
            fields: [
                "statusCode": String(statusCode),
                "durationMs": String(durationMs)
            ]
        )
    }
}
```

也可以在业务模块内建立一个很薄的命名空间：

```swift
enum NetworkLog {
    static func requestCompleted(
        logger: Logger,
        requestID: String,
        statusCode: Int,
        durationMs: Int
    ) {
        logger.event(/* ... */)
    }
}
```

这两种包装均应位于使用它们的业务模块，而不是通用日志库。迁移到不同业务的新项目时，可以直接使用基础 API，并只迁移真正适用的包装。

### 6.1 何时直接使用字符串 API

- 临时诊断信息。
- 低频、一次性的业务节点。
- 尚未稳定、仍在快速变化的事件。
- 不参与统计或自动分析的普通运行日志。

### 6.2 何时增加业务包装

- 同一事件在多个位置重复记录。
- 字段结构已经稳定。
- 事件会用于统计、筛选、告警或测试断言。
- 需要统一脱敏、字段命名或错误映射。

判断标准不是“它属于哪个业务”，而是“重复和一致性是否已经产生实际维护成本”。不要预先为所有事件建立包装。

## 7. 方案可行性分析

### 7.1 主要收益

- **迁移成本低**：新项目只需引入通用 Logger、配置后端，即可直接记录日志。
- **业务自由度高**：简单场景使用字符串，稳定事件按需包装，两者可以共存。
- **核心稳定**：业务字段和功能变化不会迫使日志核心修改协议。
- **便于渐进演进**：早期直接记录，事件成熟后再提取包装，无需一次性设计完整事件体系。
- **便于测试**：后端可替换为内存记录器，业务不依赖文件系统和单例。
- **保留统计能力**：事件名与字符串字段仍能形成结构化数据。

### 7.2 主要风险

字符串接口会牺牲一部分编译期约束：

- 事件名可能拼写错误。
- 同一字段可能出现不同命名或单位。
- 重命名事件时，编译器无法找到所有语义关联。
- 自由文本不适合直接作为稳定统计口径。

这些风险不应通过重新建立庞大的强类型层来解决，而应使用轻量治理：

1. 事件名统一采用 `领域.对象.动作/状态` 或在固定 category 下使用 `对象.状态`，例如 `network.request.completed`。
2. 稳定统计事件建立一份小型事件目录，记录字段和单位。
3. 高频稳定事件再提取为业务包装或常量，普通日志保持字符串形式。
4. 对核心事件增加测试，验证事件名和必要字段。

因此，该方案不是“完全无约束”，而是把约束放到真正需要稳定性的少数事件上。

## 8. 网络模块的边界

网络工具不应直接依赖 Logger，也不需要以日志为目的定义 `XYNetToolEventSink`。更合适的方式是提供普通 Delegate，将真实请求阶段的数据抛给外部：

```swift
protocol XYNetToolDelegate: AnyObject {
    func netTool(_ tool: XYNetTool, willSend request: URLRequest, requestID: String)

    func netTool(
        _ tool: XYNetTool,
        didReceive data: Data?,
        response: URLResponse?,
        requestID: String,
        duration: TimeInterval
    )

    func netTool(
        _ tool: XYNetTool,
        didFail error: Error,
        requestID: String,
        duration: TimeInterval
    )
}
```

App 层可以实现 Delegate 并写日志，也可以做调试展示、性能统计或完全忽略这些回调。这样网络工具只暴露网络生命周期，不知道外部如何消费数据。

需要避免在网络工具、业务模型和页面层同时完整记录请求与响应。建议由 Delegate 适配层负责标准网络日志，业务层只补充用户意图和业务结果。

## 9. 调用简单与结构化存储并不冲突

无论业务使用基础字符串 API 还是包装 API，日志后端都应转成相同记录结构，例如：

```json
{
  "timestamp": "2026-06-24T10:00:00.000+08:00",
  "level": "info",
  "category": "network",
  "event": "request.completed",
  "message": "Request completed",
  "traceID": "request-uuid",
  "fields": {
    "method": "GET",
    "statusCode": "200",
    "durationMs": "183"
  }
}
```

统一记录结构可以继续支持本地 JSONL 文件、日志查看 UI、分类筛选、请求链路关联和基础统计。

## 10. 配置、后端与性能

通用 Logger 门面不应硬编码 `AppLogger.shared`。建议在 App 启动时一次性配置日志后端：

```swift
LoggingSystem.configure(
    handler: LocalFileLogHandler(/* ... */)
)
```

Logger 内部只向已配置的 Handler 发送标准记录。可用后端包括：

- 本地 JSONL 文件。
- OSLog。
- 内存 Handler，用于单元测试。
- 多目标 Handler，同时写入文件和系统日志。
- No-op Handler，在未配置或关闭日志时直接丢弃。

消息和扩展字段应采用 `@autoclosure` 或闭包延迟生成，并在级别过滤后再执行。请求体、响应体等大数据还应设置长度限制，必要时只记录摘要、大小或哈希。

## 11. 隐私与安全

网络日志不能无条件记录所有原始内容。建议在 Handler 或 Processor 层统一处理：

- 删除或遮盖 `Authorization`、Cookie、Token、密码等字段。
- 对请求体和响应体设置最大长度。
- 二进制数据仅记录类型、长度和摘要。
- 默认不记录文件内容及用户隐私数据。
- 日志导出前可以执行二次脱敏。

脱敏策略位于统一后端，能够同时覆盖直接字符串调用和业务包装调用。

## 12. 跨项目复用方式

迁移到业务完全不同的新项目时，只需要：

1. 复用通用 Logger 门面、记录结构和所需 Handler。
2. 在新 App 启动时配置存储目录、级别和脱敏策略。
3. 使用新项目自己的 category 与事件名。
4. 仅在存在重复、稳定事件时创建新项目自己的可选包装。

无需复制 XYDevTool 的功能枚举，也无需为新项目重新设计一套 `XXSink`。业务包装是否迁移由其语义是否适用决定，而不是日志框架强制要求。

## 13. 对 XYDevTool 的建议调整边界

后续实施时可以按以下方向逐步调整：

1. 提取不包含 AppKit、业务枚举和固定目录的通用 Logger 门面。
2. 将当前本地文件能力改为 Logger 后端实现。
3. 移除业务代码对 `AppLogger.shared` 的直接依赖。
4. 删除或弱化与具体功能绑定的 `AppLogCategory`、`AppLogEvent` 类型。
5. 将 `XYNetToolEventSink` 改为表达网络生命周期的 `XYNetToolDelegate`。
6. 在 App 层实现网络 Delegate 到 Logger 的适配。
7. 保留现有日志查看 UI，但让分类和事件从日志内容动态读取。
8. 先使用 `requestID` 关联网络链路；只有出现跨异步、多层链路分析需求时再引入 Span。

这些调整可以分阶段进行，不需要一次性重写全部日志代码。

## 14. 最终结论

建议采用“**通用字符串 Logger + 可选业务包装 + 可替换后端**”作为业务日志基线；网络工具使用普通 Delegate 暴露请求生命周期，再由 App 层决定是否写日志。

业务层可以直接使用基础字符串方法，也可以在事件稳定、重复或需要统计时自行包装。两种方式不是互斥选择，而是同一体系的不同成熟度层级：先保持低成本接入，再只对真正需要稳定契约的事件增加约束。

这个方案不能做到业务对日志完全零依赖，但可以把依赖压缩为一个长期稳定、与具体 App 无关的最小抽象，同时避免大量业务 Sink、强类型事件和适配器随项目增长而扩散。

## 15. 当前落地状态

首轮重构已完成以下内容：

- 通用 `Logger`、`LogHandler`、`LoggingSystem` 和 `LogOperation` 已独立到仅依赖 Foundation 的文件。
- 本地 JSONL、会话检测、文件轮转和日志管理已收敛为 `LocalLogService` 后端。
- 业务调用已改为按 category 创建轻量 `Logger`，不再依赖具体存储单例和业务分类枚举。
- `XYNetToolEventSink` 已删除，网络工具改为通过 `XYNetToolDelegate` 暴露真实请求生命周期。
- App 层网络适配器负责将真实请求和响应转换为通用日志字段。
- 日志查看器根据实际日志动态展示 category，并直接读取当前日志结构。
- 本地日志后端支持 `LogBackendPlugin` 插件链，默认挂载可配置的 `LogPrivacyPlugin`。
- App 在启动阶段配置正文记录开关、字段长度、敏感键及替换文本；隐私规则不进入 Logger 和业务模块。
- 业务网络日志只保留用户路径、校验和脚本阶段，原始请求与响应统一由网络 Delegate 适配层记录。
- 普通请求和文件下载均已接入相同的网络生命周期回调。

业务包装层暂未批量创建。后续只在事件重复、字段稳定或形成统计契约时按需增加，避免重新引入大量样板代码。
