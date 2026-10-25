# PaperDock AI 开发入口

本入口已按本轮“建立标准 Harness 文档、允许整理资料”的授权启用，只承接现有约定与当前实现，不新增业务能力或改变既有批准。规则性质见各正文：已确认是明确授权/约束，默认实践是从代码归纳的写法，不等于 CI 已强制。

## 基础约束

- 以当前源码、构建脚本和本需求批准为准；历史“当前”、PID、候选路径及当时授权不自动适用于新任务。需求批准、实现完成、程序验证、真人体验、安装及发布分别表达。
- 保留既有改动与历史失败。开发/验证使用项目内独占绝对数据与证据路径，不共写日常库，不双击候选应用或用 `open -a` 猜参数；不强杀用户实例，不清空坏库，不擅自迁移、复制或回退真实数据。
- 构建不等于测试，NSView 内容缓存图不等于系统截图，程序 marked text 不等于真人中文输入法。只声明实际证据覆盖的范围。
- 提交、推送、安装、打包发送、发布、历史删除、外部写入及权限调整核对本轮明确授权。加载本地交付 Skill 不等于调用交付；默认开发停在验证/待体验。

## 按任务读取

| 任务 | 最小入口 |
|---|---|
| 理解代码或新增/修改功能 | [工程结构](docs/harness/rules/工程结构.md) → [编码规范](docs/harness/rules/编码规范.md)的相关组件 |
| 确认新需求、实施、交接 | [开发流程规范](docs/harness/rules/开发流程规范.md) → 项目 [改动 Skill](.agents/skills/paperdock-change/SKILL.md)；不是每次都重跑 setup |
| 改业务/状态 | [业务模型](docs/harness/wiki/业务模型.md) → [数据模型](docs/harness/wiki/数据模型.md) → 对应既有需求 |
| 改参数、导出、脚本或交付边界 | [接口协议](docs/harness/wiki/接口协议.md)；名称歧义查[领域术语](docs/harness/wiki/领域术语.md) |
| 选择验证、准备体验 | [测试规范](docs/harness/rules/测试规范.md) → 本机 `.harness-local/testing.md`（忽略文件；干净克隆不存在时，先按测试规范补空入口卡） |
| 明确要求本地交付收尾 | [本地交付 Skill](.agents/skills/paperdock-local-delivery/SKILL.md)，不能继承旧 ready 或历史安装授权 |

具体代码设计/实现、排障、审查、测试仍按当前宿主可用 Skill 的真实位置加载；不把工作台能力视为已安装。存在 `.codegraph/` 且涉及源码结构/影响时先按图查询，改前查 impact；本轮根目录未发现该目录。

## 资料映射与缺口

本次调查范围为整个 PaperDock 的主要运行单元与边界；不是全库缺陷审计，也没有重跑业务验证。事实基线为 `246670c8db14bd7a4f3759f93cfa024d1d6b9a22` 上的源码，后续以实际文件为准。

| 对象 | 覆盖与唯一正文 | 缺口/不适用 |
|---|---|---|
| 正式原生应用 | 工程结构：main/Options、Application、Manager/Settings、Editor/BodyCoordinator、Model/PaletteDraft、Windows/Edge、Store、Palette/PaletteUI及测试入口 | SwiftUI/AppKit/Core Data，非 Web 服务；无 HTTP/账号/云同步 |
| 主要用户能力 | 业务模型：所有新建入口、正文/标题/待办、管理搜索与分组、收纳/删除恢复、配色、锁/折叠、全局高度/按张层级、保存退出 | 实现存在不等于全验通过；跨应用、真人 IME、滚轮/Tab、真实保存/重试点按等仍看[0007 执行记录](docs/requirements/0007-note-layer-height/progress.md) |
| 数据与模块交互 | 数据模型负责 SQLite 三实体、布局 JSON、内存草稿和目录锁；接口协议负责 CLI/导出、模块调用、runner、交付脚本和 AppKit helper | 不承诺双文件事务、未知模型迁移、异常退出零丢失或多屏恢复 |
| 本地交付单元 | 接口协议与现有 [0006 实施记录](docs/requirements/0006-local-delivery/implementation.md)，脚本及项目 Skill 继续为参数与授权 Owner | 历史手工快照/安装不等于标准 ready；真实运行版本本轮未核验 |
| 原型与原生实验 | 工程结构定位两个 prototype HTML；[实验 README](experiments/native-spike/README.md)继续负责实验复跑与证据 | 原型内存、实验单快照不是正式产品实现，未用其旧通过替代当前验证 |
| 需求与历史材料 | [需求索引](docs/requirements/README.md)；原 `docs/requirements/0001…0007`、根/应用 README 历史段、审查报告原位保留 | 不迁到 `docs/changes`，不双写需求/用例；`artifacts/`、`dist/`、根 `progress.md` 等为忽略的本机历史，克隆可能无原始证据 |

首次实现或模块职责、接口、状态/长期规则变化后，由本次交付负责人回读上述正文并补缺；普通文案/样式无稳定事实变化时说明无需更新，不新增流程平台。当前环境支持范围按 README 与原始证据：macOS 26、Apple Silicon，其他系统、多屏/Space/全屏等不能外推。
