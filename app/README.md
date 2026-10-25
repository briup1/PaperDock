# PaperDock 本机开发版 0.1.1-local

正式实现位于本目录，与 `prototype/`、`experiments/` 及旧库无代码/数据复用关系。采用 Swift + SwiftUI A三栏、AppKit 浮动窗口/边缘、NSTextView 正文、Core Data 多记录（Note/Todo/Settings 三实体）；不以单记录 JSON 快照充当产品。当前支持范围仅本机 macOS 26.5.1 arm64、单屏普通窗口；版本号不是发布版本。

## 当前源码与阅读入口（2026-10-25 Harness 整理）

长期实现说明见[项目入口](../AGENTS.md)、[工程结构](../docs/harness/rules/工程结构.md)、[业务模型](../docs/harness/wiki/业务模型.md)、[数据模型](../docs/harness/wiki/数据模型.md)和[接口协议](../docs/harness/wiki/接口协议.md)；验证选择见[测试规范](../docs/harness/rules/测试规范.md)。本文件原有章节保留命令与阶段历史，不独立维护第二套当前模型。下文“本轮/当前/PID/无Git/未迁移”等语句属于原记录时点，不能覆盖当前源码与本轮授权。

源码已包含 0007 的设置页高度输入/保存/生效值/反馈，默认 190pt 只用于新库或缺字段，已存 177.5 等值不覆盖；有限范围 175…1000pt，保存后下次打开/展开生效，当前打开窗不跳。按张 layer 与高度仍在 NoteLayout.json version=1，SQLite 三实体未变；缺字段兼容，null/错类型拒绝，无 v2 自动迁移。展开按当前全局高度而非旧尺寸。compact 的“添加待办”固定在滚动区外，新增按 UUID 定位/聚焦，候选未确认拒绝添加。

已有专项入口是 `--test note-settings-rules`、`note-settings-compat`、`note-settings-controls`、`note-settings-todo-controls`、`note-settings-write`→`note-settings-read`，在同一当前候选上显式运行；旧 test.sh 不自动包含这些套件。[0007 执行记录](../docs/requirements/0007-note-layer-height/progress.md)与[反馈实现审查](../docs/requirements/0007-note-layer-height/feedback-implementation-review.md)保留原始成功/失败及真人/标准 ready 缺口；不以历史程序结果宣称当前 HEAD 全部通过。本次只整理文档，未重新构建/测试/安装。

## 0002 增量：钉住与列表右键删除

本轮新增整张锁定：浮窗顶部“钉住”，锁后禁止移动、缩放、标题正文、待办、配色、收纳、删除及窗口关闭；顶部仅保留解锁入口，管理器同一ID同步只读且可解锁。普通应用退出仍走原保存链。锁定/解锁不改内容修改日期，正常重开恢复钉住时的位置与尺寸、锁状态。解锁后可继续原操作；不新增多屏恢复策略或全窗口布局保存。

“全部便签”卡片右键删除绑定被点卡片ID，不依赖当前选中项；确认框显示对象标题，取消不变、确认移到回收站并收起对应浮窗，恢复仍为收纳。锁定卡片的删除置灰，已打开的旧配色草稿和旧删除请求也不能越过最终锁校验。

锁和frame存于同一独占数据目录的`NoteLayout.json`（version=1），Core Data模型保持不变；缺文件旧记录默认未锁，文件存在但损坏/未知版本/非法ID或坐标尺寸会报错保留原件，不静默清空。先成功保存内容及原子写入元数据再发布锁状态，失败仍保留原锁状态。导出JSON新增`placements`（按便签UUID字符串索引），便于比对锁状态和frame；原`notes`、`settings`保持。

0002开发冻结与复验入口见`artifacts/developer/pin-delete-01/implementation-report.md`。不覆盖仍在使用的`app/build`，本轮.app在：

```text
/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/pin-delete-01/build-final/PaperDock.app
```

聚焦规则、元数据失败与跨进程检查（两个输出目录必须未存在）：

```bash
bash /Users/ziyun/workdir/self_project/PaperDock/app/test-pin-delete.sh /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/pin-rules-new /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/pin-build-new
```

加`--controls`可检查自身未显示的原生面板、正文/色盘控件与恢复前定位，并生成局部内容PNG；不安装边缘入口、不激活或运行完整应用，不等于真人拖动/真实右键菜单/中文输入法候选验收。完整GUI及真人验证前必须核对旧试用实例已正常退出，不关闭他人实例，不共写旧库。

## 0004：无系统标题栏的独立便签

本轮独立便签移除整块系统标题栏及交通灯，保留工具栏×收纳；工具栏仅压缩垂直留白至目标约27pt，12pt图标及按钮本体不缩小。未锁时可拖工具栏空白处，正文仍用于选字编辑；锁定时禁止拖动/缩放，解锁入口保留。仅compact移除底部常驻保存状态区，自动保存和失败提示/重试不改，管理器保持原布局与保存提示。新窗仍270×355pt外框，有记录的placement仍恢复原frame。

新构建输出：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/sticky-chrome-01/build/PaperDock.app`。未覆盖旧app/build或用户运行中的build06，不自动启动新实例。按用户要求本轮只编译、不执行测试/GUI探针/截图；行为由用户后续实测，旧CompactTests失败记录不改、不据编译成功宣称已通过。

## 0005：折叠标题条与待办间距

独立便签的−位于×左侧，折叠为原宽度、原纸色、同一上沿的27pt标题条；保留手动优先的当前标题，长标题单行省略。＋恢复同一便签原展开尺寸和内容；×仍收纳，找回仍保持折叠。未锁时可拖标题区，展开沿拖后的上沿恢复，不跳回旧位置。折叠条仍有钉住/解锁，锁定期间禁止折展、拖动和收纳。管理器保持完整编辑布局，未锁的同ID标题编辑会同步标题条。

`NoteLayout.json`仍为version=1，只增加`collapsed`字段；仅缺字段按旧数据默认false，null/错误类型仍报错。frame始终保存展开尺寸和当前上沿对应的展开原点，不把27pt塞入原350pt下限。折展/锁定先保存有效内容、原子写元数据成功后发布；失败保留旧状态并提示。正文仍在输入法候选期间时拒绝折叠，提示先确认或取消，不将候选伪保存。拖动结束/实时缩放结束只保存布局，不因每次鼠标移动重写全部便签；布局写失败回到上次位置。以上整理动作不改内容修改时间，也不改SQLite模型。

compact待办列表底部及“添加待办”顶部留白缩小，字号/勾选框/管理器未改。正常退出重开恢复折叠状态、条位置及展开尺寸。

本轮只离线编译，**未运行测试、GUI、截图或独立Review，以上行为待用户体验，不以编译代替功能通过**。新产物与冻结交接：

```text
/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/collapse-note-01/build/PaperDock.app
/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/collapse-note-01/handoff.md
```

未退出或强杀用户旧进程，未写compact-user-03/data，未覆盖brand-alignment/app/build/dist0.1.0，也未启动新实例或重打包朋友ZIP。用户正常退出旧版本后再切换；切换运行由协调者/用户另行操作。

## 无网络构建

需要当前机器已有 Command Line Tools / Swift 6.3.3；无需完整 Xcode、第三方包或安装。命令通过 `bash` 执行，不需要修改脚本权限。构建不会复制到 Applications、不会运行 codesign 或发布。

```bash
bash /Users/ziyun/workdir/self_project/PaperDock/app/build.sh
```

输出 `/Users/ziyun/workdir/self_project/PaperDock/app/build/PaperDock.app`。独立验收可指定全新绝对构建目录（不要覆盖实现者产物）：

```bash
bash /Users/ziyun/workdir/self_project/PaperDock/app/build.sh /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/review-01/build
```

## 在隔离目录运行

开发/验收**必须显式指定项目内独占绝对路径**，不同进程不能共写同一目录；同目录第二实例会拒绝打开。以下为手动体验目录，非日常资料：

```bash
bash /Users/ziyun/workdir/self_project/PaperDock/app/run.sh --data-dir /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/manual-01/data --evidence-dir /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/manual-01/evidence
```

独立构建可直接执行其 `PaperDock.app/Contents/MacOS/PaperDock`，参数相同。不使用 `open -a`，避免参数与PID归属不明。无参数运行才使用用户 Application Support 下的 `PaperDock` 私有目录；本轮开发从未运行该模式。路径参数校验为绝对路径；测试/夹具/导出/计时退出/截图动作不允许省略 `--data-dir`。

首次启动是空库，无例子或自动新建。菜单“文件→新建便签”、局部 Command+N、左栏新建、列表＋、首次空态入口、右侧有效拖出均调用同一 `AppModel.newNote→Store.create`。不提供全局快捷键。

### 真实操作

```text
普通应用仍有焦点 → 指针靠近主屏右侧中段2pt×130pt命中条
  → 展开24pt入口 → 向左拖至少40pt松开 → 新建一张并收回
  → 点击正文才编辑（显示浮窗不主动夺取键盘）
  → 关闭浮窗=收纳 → 菜单“管理全部便签”找回同一ID
```

不足40pt、单击或取消不新建；拖动过程中不提前收回。每ID仅一个浮窗，普通窗口层 `.floating`，失焦不自动收纳。多屏/全屏/Space/Stage Manager、右侧Dock冲突和旧系统未验证。

- A三栏：左筛选，中列按内容修改自然日分组/搜索，右栏编辑；搜索使当前记录失配时保留同一编辑器和提示，不转到其他记录。切换筛选清除选择，切换记录才换编辑器。
- 手动标题非空优先；清空回到自动标题。正文加待办移除空白/行首列表标记后取5个 Swift Character，家庭表情为一个字素。
- 正文/标题/待办增删改/完成状态改变内容时间；颜色/收纳/删除恢复/窗口移动缩放不改变。回收站隔离检索，恢复为收纳，无永久删除/自动清理。
- 纸色：六种内置色、320×210pt HSV大色盘、色相条、可选hex联动；Tab进入后方向键调色。无效hex禁应用，重选或清空恢复。暂存只在草稿；取消/×/Escape丢弃本轮预览和暂存。
- 单张只改本张；固定只影响未来新建；加入随机去重并切回随机，未勾选加入预览色则只切已有池。旧便签不会重染。设置与单张纸色共用同一草稿/提交逻辑。
- 正文为同一NSTextView实例，marked text期间不覆盖编辑器或保存未确认组合输入；确认后保存。程序模拟marked text不是用户实际输入法认证。
- 有效编辑自动保存；保存失败显示“未保存”并保留内存状态，退出再保存失败会弹窗并阻止退出。坏库/不兼容模型不清空重建；保留原文件报错退出。本版无既有正式库迁移路径，未来升级迁移须先备份另行实现，不自动迁移未知库。

正常退出用本应用菜单“退出 PaperDock”或取得本应用焦点后的 Command+Q。管理器关闭不退出，浮窗关闭只收纳。请勿用强杀充当正常退出证据。`--quit-after 5` 可让自己启动的自动观察实例经同一 `NSApp.terminate` 保存/退出；不应给真人输入法测试设置过短计时。

## 自测和独立复跑

下面两个目录必须使用本轮**未存在的新名字**。测试脚本不会清空或覆盖旧证据，第一参数已存在会拒绝；所有数据仍在项目内。

```bash
bash /Users/ziyun/workdir/self_project/PaperDock/app/test.sh /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/verification-new /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/verification-build-new
```

独立者把上述两处 `artifacts/developer/...` 改为其自己新建的 `artifacts/acceptance/...` 即可。脚本编译后串行执行 title/dates/query/controller/palette/editor/windows/hsv/bad-store、三进程 write→read→read-random 及GUI探针；真实非零立即失败，不重置旧库。`commands.log` 记录真实退出码和GUI PID；GUI门同时要求wait=0、PID已退出、`gui/normal-exit.txt`与`gui/gui-result.json`存在，结果PID等于启动PID、status=passed且completed=true。**正常保存退出标记不代表GUI测试通过**；先前GUI失败即使最后保存成功也保留失败，退出码1。退出先走原保存/拒绝退出分支，成功后停止AppKit主循环，由main写最终结果并统一返回真实退出码；不以强制exit跳过保存。测试使用正式 Store、AppModel、NSTextView delegate、HSVControl、NoteWindows 和真实菜单项，不另造“测试版实现”；故障钩子在真实save边界注入抛错，不冒充实际磁盘满。

R1定向复验只运行受影响GUI链，不重跑无关套件：

```bash
bash /Users/ziyun/workdir/self_project/PaperDock/app/test.sh --gui-only /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-new /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-build-new
```

`test.sh --check-gui-result /absolute/evidence-parent PID WAIT_STATUS`只调用与runner结束时相同的结果门，便于负向检查exit0+normal标记但没有实际GUI完成结果的反例；不启动应用、不制造通过。输入父目录应含`gui/`。期望失败输入返回1。

可单独执行（示例使用新目录）：

```bash
/Users/ziyun/workdir/self_project/PaperDock/app/build/PaperDock.app/Contents/MacOS/PaperDock --test title --data-dir /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/title-new
/Users/ziyun/workdir/self_project/PaperDock/app/build/PaperDock.app/Contents/MacOS/PaperDock --gui-test --data-dir /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/gui-new/data --evidence-dir /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/gui-new/evidence
```

### 合成夹具与状态导出

`--seed-fixture standard` 在**空库**通过正式Store写四张今天/D-1/D-7/收纳便签，各含两状态待办；`history` 同标准集，供每个日期动作独立分支；`empty-fixed` 为空库设置固定#ABCDEF与含#2468AC的7色池。日期由本地Calendar减日，不改系统时间；非空库拒绝播种。播种后退出，不暗开GUI。未提供重置/清库命令。

```bash
/Users/ziyun/workdir/self_project/PaperDock/app/build/PaperDock.app/Contents/MacOS/PaperDock --data-dir /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/fixture-new/data --seed-fixture standard --export /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/fixture-new/initial.json
```

之后不带播种参数即可同目录正常运行；`--export /absolute/file.json` 单独打开并导出真实记录/设置后退出，不变更内容。输出父目录必须已存在。导出与GUI不可共写同库，先正常退出GUI再导出。便签ID、待办ID/顺序/完成状态、修改时刻、纸色与可见/删除状态均可对照。`write/read/read-random` 是TC-014程序分支，不替代真人正常退出重开整链。

### 内容图与证据边界

`--evidence-dir` 自动导出 launch/observed/exit JSON、启动后管理器内容PNG及正常退出标记；`--gui-test` 另捕获首次空态、A三栏、浮窗、搜索失配、HSV弹层/错误、较窄浅色/空筛选等内容图，退出后另写包含当前PID、completed/status/首个failure的`gui-result.json`。截图/断言/最终证据写入失败均使真实退出码为1；普通无测试失败的退出仍为0。捕获使用公开 `NSView.cacheDisplay`，不请求屏幕录制/辅助功能权限。**这些仅自有原生内容绘制证据，不含窗口服务器遮挡/系统边框，不等于系统窗口截图、真实置顶或跨应用输入证据。** 需要真实窗口/跨应用画面时由用户用系统截图保存到本轮隔离目录，独立验收者审阅，不能拿旧实验/网页图补位。

## 本轮实现者证据与冻结

程序回归及实际源hash见 `/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/implementation-01/implementation-report.md`、同目录 `frozen-source.sha256`（源码/脚本/本文）、`frozen-binary.sha256`。没有Git仓库，不填写虚构commit；当时版本0.1.0-local + hash唯一确定该次冻结状态。独立审查开始后不再暗改冻结源；缺陷回派后产生新hash。

R1修复后的退出/runner冻结hash与定向复验见 `/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/r1-fix-01/r1-report.md`；新hash不覆盖原冻结或独立失败报告。原实现记录中的GUI退出0/normal标记不能独立证明成功，以修后明确结果门及独立定向复验为准，未改变的模型/控件规则证据可按源码核对复用。

已核实的是正式核心规则、Core Data多记录/两状态待办与固定/随机设置跨三进程、真实菜单/自有窗口状态、marked text及HSV控件程序边界，以及内容图局部自查。**未验**：真人IME候选与持续光标、真人边缘拖出/取消、跨应用真实键盘归属、实际Tab/方向键/Enter整链、真实午夜刷新、完整系统窗口截图；独立审查与逐用例验收尚未完成，不将程序自驱写成成品全部通过。未做异常强杀零丢失、性能规模保证、发布/签名分发或工具安装。
