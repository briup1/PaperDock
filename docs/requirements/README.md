# PaperDock 需求与历史资料索引

沿用本目录为需求唯一归宿，不迁移到 docs/changes，也不在 Harness 中复制需求、方案或具体用例。长期当前实现与协作约定从[项目根入口](../../AGENTS.md)进入；早期阶段报告保留当时结论，不代表最新源码已通过全部验收。

## 既有需求

| 目录 | 需求与具体用例 Owner | 实施/审查及边界 |
|---|---|---|
| 0001-local-notes | [需求](0001-local-notes/requirement.wl-req-confirm.md)、[用例](0001-local-notes/test-cases.wl-qa-test-planner.md)、[方案](0001-local-notes/design.wl-design-doc.html) | [执行计划](0001-local-notes/execution-plan.md)、[首版独立报告](../native-delivery-review.md)；首版证据不自动覆盖后续增量 |
| 0002-pin-context-delete | [需求](0002-pin-context-delete/requirement.wl-req-confirm.md)、[用例](0002-pin-context-delete/test-cases.wl-qa-test-planner.md)、[方案](0002-pin-context-delete/design.wl-design-doc.html) | [执行计划](0002-pin-context-delete/execution-plan.md)、[钉住/删除审查](../pin-delete-review.md) |
| 0003-compact-icon | [需求](0003-compact-icon/requirement.wl-req-confirm.md)、[用例](0003-compact-icon/test-cases.wl-qa-test-planner.md)、[方案](0003-compact-icon/design.wl-design-doc.html) | [执行计划](0003-compact-icon/execution-plan.md)、[紧凑图标报告](../compact-icon-review.md)，原失败/熔断保留 |
| 0004-sticky-chrome | [需求及局部方案/验证边界](0004-sticky-chrome/requirement.wl-req-confirm.md) | 无单独方案/用例正文，不虚构；历史授权为只编译，不能当功能全通过 |
| 0005-collapse-note | [需求及局部方案/验证边界](0005-collapse-note/requirement.wl-req-confirm.md) | 无单独方案/用例正文，保留其当时只编译和待体验边界；当前展开高度语义以后续 0007 与源码为准 |
| 0006-local-delivery | [需求](0006-local-delivery/requirement.wl-req-confirm.md)、[既有用例](0006-local-delivery/test-cases.md)、[实施记录](0006-local-delivery/implementation.md) | Python 指纹/交接/提交安装工具及项目 Skill；模拟测试与实际安装分开 |
| 0007-note-layer-height | [需求 v0.5](0007-note-layer-height/requirement.wl-req-confirm.md)、[用例](0007-note-layer-height/test-cases.wl-qa-test-planner.md)、[方案](0007-note-layer-height/design.wl-design-doc.html) | [执行记录](0007-note-layer-height/progress.md)、[原实现审查](0007-note-layer-height/implementation-review.md)、[反馈修正审查](0007-note-layer-height/feedback-implementation-review.md)；verifying，真人/GUI/标准 ready 缺口不改写 |

已有 HTML 由各目录 render-docs.py 从 Markdown 同源生成，HTML 不是另一份可独立编辑的需求/用例；技术方案 HTML 为自己的唯一正文。旧文件名/路径继续可用，编号不得因目录整理而重分配。

## 其他阶段与证据

- [原型验证](../prototype-validation.md)、[风格记录](../style-review.md)保留网页阶段事实；两个原型当前定位见[工程结构](../harness/rules/工程结构.md)。
- [原生阶段范围](../native-phase-scope.md)、[准入复核](../native-readiness-review.md)、[验收计划](../native-acceptance-plan.md)保留历史分工/授权；不自动继承为新任务权限。
- artifacts/、dist/、.work/、根 progress.md 和实验 evidence 受 .gitignore 控制，原始本机证据可能在干净克隆缺失。共享报告只保留引用，不制造空证据或把缺失改成通过。
- 0007 的手工快照与已安装启动记录属于当时版本；当前源码基线为根 AGENTS 所列 Git 提交，二者不能混为同一测试对象。本轮 Harness 没有启动/安装/重测。

## 新任务放置

新需求先核对现有编号及是否已有同义需求，再沿本目录建立下一个编号-主题；向需求/方案/用例能力传入该真实目录。需求批准、实现授权、测试/体验、交付安装分别核对。具体流程见[开发流程规范](../harness/rules/开发流程规范.md)，不要求补齐每个历史需求本来没有的文件。
