![DevTool logo](/Screenshots/logo.png)


[English](./README.md) | 简体中文

DevTool
============

一款简洁 UI 和功能强大的 macOS 应用程序。它是我开发工作过程中常用工具的集合，开源出来也希望能帮助到有需要的人，目前的主要功能如下

- JSON 格式化工具: 用于快速格式化网络 JSON 数据成为格式化后的 JSON 方便阅读

- JSON 转 Model: 读取 JSON 数据生成 Swift Model，支持多种配置选项，尤其对于复杂 JSON 的解析，充分解放双手

- AppIcon 生成器: 支持生成 iOS/macOS App 图标，一键生成并导出到指定目录

- 网络请求工具: 一个便捷的网络请求工具，意在替代 Postman, 为前后端接口连调提速。自动记录历史请求记录并支持导出/导入。

- ... 

Functions & Features
========

JSONFormat
-----

- 格式化接口返回的 JSON 字符串，变成易于阅读和理解的格式
- ...

JSON 转 Model
-----

- 自动 JSON 文件转换为 Swift Class，减少重复工作，降低出错概率
- 自动解析嵌套类型 array 和 dictionary，并将嵌套类型的内容按实际解析成新的类
- 对于数组类型自动解析其 dict 元素完整的键值，有效避免测试 Json 测试数据中数组元素key乱写/少写导致可能的丢失情况
- 支持自定义类前缀
- 支持自定义类继承基类 + 遵守协议
- 支持将原来 JSON 的 value 设置为属性注释，方便后续维护的时候查看代码
- 支持自动生成 CodingKeys, 方便后续直接使用系统 Codable 协议进行模型转换
- ...

AppIcon 生成器
-----

- 用户传入指定图片，一键生成 iOS/macOS AppIcon。适合个人开发者做个人项目快速生成图标(本项目图标就由此生成，本功能也是因为本项目生成图标而生)
- ...

网络请求工具
-----

- 简洁的网络请求工具，参考 Postman，只是更加简洁，不需要联网检查软件可用性，所有记录在本地更安全
- 支持自定义请求名称/ 输入 URL/ 请求头/ 请求体/可以直接发送请求并看到原始返回结果
- 支持历史请求数据保存/导出/导入
- 支持请求的删除和锁定(防止误删历史记录，解锁后可删除)


Screenshots
========================
![jsonFormatter.png](/Screenshots/jsonFormatter.png)
![json2model.png](/Screenshots/json2model.png)
![appIcons.png](/Screenshots/appIcons.png)
![netRequest.png](/Screenshots/netRequest.png)


Install
============

- 直接下载 [Release Packages](https://github.com/xiaoyouPrince/XYDevTool/releases)
- 克隆源代码，通过 Xcode 编译, 将编译好的项目 XYDevTool.app 拷贝到 Application 文件夹下


Others
======

这些功能是我经常使用的，所以我在我的应用程序中编写了它们。如果您有更好的建议，如更多功能，请提交 MR/issues，谢谢！如果你喜欢，请点击一颗星星来鼓励我😁







