# QRCode 功能 PRD

## 背景

XYDevTool 当前已包含 JSON、网络请求、图片查看、AppIcon 等开发辅助能力。QRCode 功能目标是补齐日常开发、测试、联调、运营素材制作中高频的二维码生成与读取场景，优先保持本地、轻量、无需账号、无需联网。

竞品参考：`https://www.qr-code-generator.com/free-generator/?nis=6&ch=1`。该页面定位为免费二维码生成器，覆盖 URL、vCard 等类型，并提供颜色、Logo、边框、下载等定制能力；其前端编辑器还包含 URL、Text、WiFi、Email、SMS、vCard Plus、PDF、App Stores、Social Media、Images、Video、MP3、Event、Coupon、Feedback、Rating、Business、Bitcoin、EPC 等入口。其中 PDF、App Stores、Social Media、Images、Video、MP3、Coupon、Feedback、Rating、Business 等偏动态落地页或云端托管，不适合直接作为本地工具 MVP。

## 目标

1. 在主功能页面提供 QRCode 功能入口。
2. 支持常见静态二维码内容生成，生成结果可预览、复制、保存。
3. 支持二维码图片识别，便于排查线上二维码内容。
4. 支持 MVP 范围内的基础参数配置，但不做 Logo、SVG、历史记录、批量生成等扩展能力。
5. 所有核心能力默认本地完成，不依赖第三方服务。

## 非目标

1. MVP 不做动态二维码、短链、扫描统计、地域统计。
2. MVP 不做云端文件托管、PDF 落地页、图片/视频/音频落地页。
3. MVP 不做账号体系、团队协作、模板市场。
4. MVP 不做营销活动后台，如优惠券、评分、反馈表单。
5. MVP 不做 Logo 嵌入、SVG 导出、历史记录、批量生成。

## 目标用户

1. 开发者：把 URL、deeplink、WiFi、调试文本快速转为二维码。
2. 测试/QA：扫描或解析二维码，验证内容是否正确。
3. 产品/运营辅助：临时生成基础二维码素材。

## 功能清单

| 版本 | 功能 | 内容 | 备注 |
| --- | --- | --- | --- |
| MVP | 主入口 | 首页增加 `QRCode` 按钮，打开独立窗口 | 入口名称固定为 `QRCode` |
| MVP | 文本二维码 | 任意纯文本输入生成二维码 | 本地静态码 |
| MVP | URL 二维码 | URL 输入、格式校验、自动补全 `https://` 可选 | 本地静态码 |
| MVP | WiFi 二维码 | SSID、密码、加密方式、隐藏网络 | 格式：`WIFI:T:WPA;S:ssid;P:pwd;H:false;;` |
| MVP | Email 二维码 | 收件人、主题、正文 | `mailto:` |
| MVP | SMS 二维码 | 手机号、短信内容 | `SMSTO:` 或 `sms:` 需兼容测试 |
| MVP | 电话二维码 | 电话号码 | `tel:` |
| MVP | vCard/联系人 | 姓名、公司、职位、电话、邮箱、地址、网站 | 优先 vCard 3.0 |
| MVP | 预览 | 实时或点击生成后展示二维码 | 显示内容摘要和尺寸 |
| MVP | 导出 PNG | 选择尺寸导出 PNG | 建议 256/512/1024/2048 |
| MVP | 复制图片 | 复制二维码图片到剪贴板 | macOS 原生体验 |
| MVP | 复制内容 | 复制当前二维码原始内容 | 便于校验 |
| MVP | 识别二维码图片 | 导入图片并解析二维码内容 | 用于验证和排错 |
| MVP | 基础参数 | 容错级别、静区边距、导出尺寸 | 默认值优先保证可扫性 |
| 后续版本 | 样式定制 | 前景色、背景色、模板样式 | 保持高对比度校验 |
| 后续版本 | Logo 嵌入 | 中心 Logo 图片、比例限制、圆角/背景 | 自动提高容错等级 |
| 后续版本 | 导出 SVG | 矢量导出 | 适合打印和设计软件 |
| 后续版本 | 历史记录 | 保存最近生成/识别记录 | 本地存储 |
| 后续版本 | 批量生成 | 多行输入或 CSV 批量生成多个二维码 | 可导出文件夹 |
| 后续版本 | App/deeplink 模板 | App Scheme、Universal Link、App Store URL | 静态链接模板 |
| 后续版本 | Event 日历 | 事件标题、地点、开始/结束时间 | iCalendar 文本 |

## MVP 范围

第一版只做 MVP：

1. 内容类型：Text、URL、WiFi、Email、SMS、Phone、vCard。
2. 结果操作：预览、复制图片、复制内容、导出 PNG、识别图片。
3. 基础参数：容错级别、静区边距、导出尺寸。
4. 后续版本：Logo、SVG、历史记录、批量生成、更多模板和营销类二维码。

## 页面结构建议

1. 左侧：类型选择列表，包括 Text、URL、WiFi、Email、SMS、Phone、vCard。
2. 中间：当前类型表单。
3. 右侧：二维码预览、内容摘要、复制/导出操作。
4. 顶部或底部：导入图片识别入口。

## 验收标准

1. 首页点击 `QRCode` 能打开独立窗口。
2. 输入有效 URL 后可生成可扫描二维码。
3. 输入任意文本后可生成二维码，并能复制 PNG 到剪贴板。
4. 导出的 PNG 在手机系统相机或常见扫码 App 中可识别。
5. 导入包含二维码的图片后能解析出内容。
6. WiFi、Email、SMS、Phone、vCard 生成的内容符合常见扫码器识别格式。
7. 所有 P0 能力离线可用。

## 技术方向

1. 生成：优先评估 `CoreImage` 的 `CIQRCodeGenerator`，减少第三方依赖。
2. 识别：优先评估 `CIDetector`/Vision 二维码识别能力。
3. UI：使用 SwiftUI 独立窗口，和现有 JSONFormatter、Network 工具保持一致。
4. 导出：MVP 只做 PNG，走 `NSBitmapImageRep`。
5. 可扫性：默认使用高对比度，优先保证扫码成功率。

## 已确认决策

1. 第一版只做 MVP。
2. Logo、SVG、历史记录、批量生成等放入后续版本。
3. 首页入口和功能窗口名称固定为 `QRCode`。

## 实现状态

1. MVP 已实现：Text、URL、WiFi、Email、SMS、Phone、vCard。
2. MVP 已实现：二维码预览、复制图片、复制内容、PNG 导出、图片识别。
3. MVP 已实现：容错级别、静区边距、导出尺寸。
4. 后续版本待实现：样式定制、Logo、SVG、历史记录、批量生成、App/deeplink 模板、Event 日历。
