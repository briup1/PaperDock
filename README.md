# PaperDock

一款本地优先的 macOS 桌面便签应用，使用 SwiftUI、AppKit 和 Core Data 开发。支持独立便签窗口、文字与待办、搜索、纸色、钉住、折叠及回收站。无需账号，不提供云同步。

## 从源码构建

当前构建目标为 macOS 26；已使用的开发环境为 Apple Silicon、macOS 26.5.1、Swift 6.3.3 / Command Line Tools。其他环境未验证。不依赖第三方包，无需安装项目依赖。

```bash
git clone git@github.com:briup1/PaperDock.git
cd PaperDock
bash app/build.sh
```

构建产物为 `app/build/PaperDock.app`，脚本不会自动启动应用。双击应用后，默认使用当前用户的 Application Support/PaperDock 保存数据；开发时的隔离运行和测试方式见 [app/README.md](app/README.md)。当前仍为试用阶段，最新折叠与间距功能尚未完成完整功能验收，编译成功不代表所有功能已验证。

## 仓库内容

- `app/`：原生应用源码、构建及测试脚本。
- `assets/brand/`：应用图标及生成资源。
- `prototype/`：浏览器交互原型，不是原生应用。
- `experiments/native-spike/`：早期原生实验源码。
- `docs/`：需求、用例、设计和阶段审查文档。

本仓库不上传本地便签数据库、运行日志、临时工作副本、构建应用或试用 ZIP，也未创建 GitHub Release。未擅自选择开源许可证；公开可见不等于已授予开源许可。

## 本地开发历史记录

以下保留各阶段原始记录，其中的绝对路径、进程号、授权边界及“当前”状态仅适用于当时的本地工作环境；关于“不初始化/提交/推送 Git”的旧限制已由本次公开仓库授权取代。本地 `artifacts/`、`dist/` 和实验运行证据未纳入仓库，因此相应历史链接不能在 GitHub 上打开。最新源码入口以以上构建说明为准，历史报告不代表最新增量已通过全部验收。

### 当前朋友试用包（本地历史记录）

用户已反馈brand-alignment-01版本实际体验无问题，并选择Apple芯片＋macOS26、无付费开发者账号的朋友试用路线。最新本地分享包：`/Users/ziyun/workdir/self_project/PaperDock/dist/PaperDock-0.1.1-trial-arm64-macOS26.zip`；校验值同目录`.zip.sha256`，包内含应用、开始使用.txt及SHA256.txt，不含用户便签/源码/日志。0.1.0旧包保留；0.1.1新增折叠/间距功能按用户要求未跑功能测试，未用0.1.0人工反馈替代新增行为验收。

分享副本仅做本地ad-hoc完整性签名且codesign严格校验通过，不是Developer ID、未公证、未上传/发布/发送；Gatekeeper可能拦截，只使用系统提供的应用专属确认，不关闭安全机制。当前只核验macOS26.5.1 arm64单屏，不保证Intel/较旧系统或所有26小版本。应用双击默认每用户Application Support/PaperDock，首次为空；不带开发路径启动参数。原运行包与试用数据未改，本次未运行功能测试。下文为历史阶段记录，当前产物与用户反馈以此和progress最新段为准。

正式本地首版已实现，当前进入修后正式版本人工协作验收：用户已批准方案v0.2、A三栏及当前Mac单屏普通窗口。已交付本地开发.app与独立代码/程序/部分原生视觉证据；未宣称全部验收通过或发布。

正式入口：[app/README.md](app/README.md)。构建产物：`/Users/ziyun/workdir/self_project/PaperDock/app/build/PaperDock.app`。独立检查：[报告](docs/native-delivery-review.md)、[首轮结果](artifacts/acceptance/native-review-01/result.json)、[R1定向复验](artifacts/acceptance/r1-review-02/result.json)。首轮R1失败已保留、修后独立定向闭合；真人IME/边缘/跨应用/真实配色sheet和重启链仍待验证，见[当前人工轮次](artifacts/acceptance/manual-final-01/result.json)。

当前唯一执行入口：[执行工作包与授权](docs/requirements/0001-local-notes/execution-plan.md)、[已批准方案](docs/requirements/0001-local-notes/design.wl-design-doc.html)。下文原型/实验阶段限制是历史记录，最新范围以此及执行计划为准；仍不发布、不安装工具、不改权限、不设开机启动、不初始化/提交/推送Git，不操作日常资料。

## 增量0003：小便签与图标（候选未交付）

当前源码已接入270×355pt外框新默认、compact字号留白、去独立顶部桌面可见、Bundle蓝色P图标；但长文末尾可见验证连续失败后熔断，独立只读诊断仅确认排版时序敏感，尚不能判定实际GUI根因，不能交付为完成。候选只在artifacts/developer/compact-icon-01/build-06，未覆盖旧app/build，不建议作为已验版本使用。

[当前独立报告](docs/compact-icon-review.md) · [唯一结果](artifacts/acceptance/compact-icon-review-01/result.json) · [执行边界](docs/requirements/0003-compact-icon/execution-plan.md)。旧用户PID46879仍运行，须正常退出后在隔离新目录确认真实可见GUI滚动/剪裁，再决定定向修复；不强杀、不改旧data，不用内容缓存图冒充系统窗口实拍。

## 增量0002：钉住与右键删除

两项已实现并通过独立聚焦代码检查、独立构建及规则/未显示控件验证；真人与完整GUI仍待旧版退出后补验，不记全验收通过。

- 新版本（不要打开旧app/build期待新功能）：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/pin-delete-01/build-final/PaperDock.app`。为保护正在运行的旧版，未覆盖默认产物。
- [增量需求/用例/方案入口](docs/requirements/0002-pin-context-delete/execution-plan.md)；[独立复核](docs/pin-delete-review.md)；[唯一逐项结果](artifacts/acceptance/pin-delete-review-01/result.json)。
- 旧人工实例PID46879仍由用户使用，须正常菜单退出后再启动新版；不强杀、不改旧试用库。新运行使用项目内独立数据目录。

## 打开原型

直接用浏览器打开 `/Users/ziyun/workdir/self_project/PaperDock/prototype/paperdock.prototype.html`。零依赖、无构建；示例状态仅在内存中，刷新重置。不输入需要保留的真实资料。

原型的 Mac 桌面、屏幕边缘触发与窗口置顶都是网页内部模拟，不能证明原生可行性。正式软件的本地保存、退出恢复尚未实现。当前没有包清单、原生工程或 Git 仓库，不安装依赖、不初始化正式工程。

## 本轮授权与产品基线

用户要求先做全套产品原型，把需求与用户故事跑通，再讨论颜色风格；明确要求协调者使用 Orca 组织专业协作。用户选定新建本目录。只授权原型与文档，不开发原生软件、不发布、不提交推送、不写外部知识库、不触碰其他项目。只能一层委派。

已确认：
- Mac 本地使用，不做同步、Windows、iPhone。
- 参考 Brim 的屏幕边缘拖出新建、独立便签、普通窗口置顶、可见与收纳等交互。参考资料只读过作者文章与商店说明，未安装实测。
- 集中管理全部便签，正文前 5 个可见字符自动标题（不足 5 字全显），可手动命名，正文摘要帮助辨认；手动标题不被正文覆盖。
- 按最后修改时间分组，而非创建日期；全文与标题文字搜索，包含已收纳。
- 第一版保留文字、待办；图片、复杂富文本、标签暂不纳入。用户对先前第 3 条建议回答“同意”，本范围为当前理解，需求草稿中保留解释来源，不扩展。
- 提供常见阅读软件风格的内置纸色及自定义颜色。
- 用户最新补充：自定义以可视化选色盘选择为主，用户不需要输入色号；色号输入仅为辅助可选方式。页面内具体选色盘形态仍是原型候选，不代表正式设计已批准。

原型其余行为：用户本轮表示“其他的没有什么要修改得了”，接受现有产品行为、不再重复征询。下列沿用，但A/B/C中未明确选定某款；不将产品反馈接受扩大为正式软件开发授权：
- A 原生书桌、B 纸本档案、C 轻卡片三种界面风格。
- 纸白、暖米、羊皮纸、浅灰、淡绿、深灰六种候选纸色，无护眼疗效承诺。
- 新建配色规则已由用户更新，见下方本轮反馈；此前固定默认色方案不再适用。单张覆盖、自动文字色与取消回滚沿用。
- 关闭等于收纳；删除进入回收站可恢复，不设自动清理和永久删除。
- 修改正文、标题、待办更新内容修改日期；移动、缩放、收纳、换色、删除恢复不改变该日期。
- 新建后即使空白也显示记录；无正文与标题显示“空白便签”。
- 菜单栏新建作为备用入口；当前快捷键仅网页内有效。

## 本轮反馈：新建随机与自定义用途

用户要求新建便签从主要卡片纸色中随机，自己的颜色可以固定或加入随机；其余无修改。当前落地口径：默认随机池为内置六色；自定义可选只改当前、以后固定或加入随机。加入随机将该颜色去重加入内置＋用户加入色的池并切回随机模式。固定后所有入口的新建都使用固定色，切回随机保留加入的自定义色；不要求相邻颜色必不同。未应用/取消不更改模式和池；既有便签不重染、不更新内容日期。此处记录本轮产品决定和协调者解释，不冒充正式用例基线独立审查通过或正式开发获准。

原型owner通过Orca复用同工位派单：task_318699513760 / ctx_795e802e6f93，拥有本次原型、风格及需求用例同源同步；协调者维护本README、progress与验证报告。只做本轮增量，其他原型不再扩展。

## 协作所有权

- 协调者：维护本 README 与 progress.md，整合裁决、收件、授权内调度、最终核对。不与执行者并行编辑原型及需求文档。
- 产品执行者：拥有 docs/requirements/0001-local-notes/ 下需求与用户故事/用例文档（不含 assets），维护唯一 Markdown 正文并生成同源 HTML；原型只读。
- 交互视觉执行者：拥有 prototype/paperdock.prototype.html 与 docs/style-review.md，负责原型完善和后续修复；需求文档只读。
- 独立体验验证者：拥有 docs/prototype-validation.md 与需求目录 assets/，原型和需求只读；可在隔离浏览器中操作示例数据。使用自己的 TaskSpace 并显式收尾，不碰其他浏览器实例。

用户已明确确认“原型与交互没问题”并接受下一步方案/最小原生验证。本轮已完成CLT编译与AppKit/CoreData程序自驱实验、独立复跑和用例G1–G4补齐；不把程序事件当真人拖拽/输入法/跨应用证据。

## 原生阶段交付

- [已批准实施方案v0.2](docs/requirements/0001-local-notes/design.wl-design-doc.html)：status=approved，关键实验仅本机单屏范围verified；正式产品仍待独立验收。
- [一次性原生实验入口和复跑方法](experiments/native-spike/README.md)：系统框架、自己的窗口与CoreData隔离数据，明确单记录/单待办/色值等简化，不是产品代码。
- [独立用例/原生复跑与方案复核](docs/native-readiness-review.md)：实现与审查分离，检查正常退出码、反向失败、坏库不覆盖与进程退出。
- [阶段共同边界](docs/native-phase-scope.md)：本轮授权及所有权。

两轮人工实验已由用户确认正常，见实验manual-evidence/user-01与hover-evidence/manual-hover-01的manual-result.md，所有手动实验已退出。当前已批准正式开发：一个持续原生实现工作包与独立验收准备并行，冻结后独立审查/构建/验收，缺陷回原实现者。验收只有程序/用户证据实际支持才记通过，完整应用的IME/跨应用和视觉仍须正式入口重验。
