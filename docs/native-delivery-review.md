# PaperDock 正式首版：独立交付检查 · native-review-01

2026-10-24，任务 `task_266984ff733a` / dispatch `ctx_042798e7b7b6`。检查者未参与 `app/` 实现，本轮只写本报告及新目录 `/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/`；源码、需求、方案、用例、旧实验/原型/数据均未修改，未向下委派。

## 本轮检查的是哪一个版本

- 输入：正式执行工作包；需求/用例 **v0.3**；用户已批准 **design v0.2 / A 三栏 / 当前 Mac 单屏普通窗口**；独立原生验收计划；`app/README.md`；实现冻结报告。
- 开始前经 Orca 核实：实现 `task_1d6dc05cbc88`、准备 `task_978ab6e10bbb` 均 succeeded；开发 GUI PID96370、97642 定向 ps 无匹配，项目 PaperDock 可执行进程无匹配，才启动本轮 GUI。
- 版本：`0.1.0-local`，无 Git、不虚构 commit。14 个正式源码/脚本/README 的冻结 hash 均匹配开发清单，本轮结束前再核对全 OK。
- [本轮源清单](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/source-before.sha256) SHA256：`b4f1ba865c6e0f91cd7e69e7f04cb06ae9b97e902677b378c2b803983b187b20`。输入文件逐份 hash 见 [inputs.sha256](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/inputs.sha256)，结束复核见 [source-after-check.log](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/source-after-check.log)。这些结果不得套用到修复后的源版本。
- 新独立正式二进制：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/build/PaperDock.app/Contents/MacOS/PaperDock`，SHA256 `6c069a802b52f5462580071fa407d16b02a03a73245587daec700eb8c7cc1c56`。
- 环境实测 macOS26.5.1 / 25F80 / arm64，Swift6.3.3，CLT；主屏1512×982pt、visible1512×949pt、scale2。窗口内容常用1060×700pt、较窄880×600pt；浮窗370×480pt。图片像素为2倍，窗口实拍额外包含标题栏。原生视图明确 light，深色便签按自身配色，未外推所有系统外观/多屏/全屏/旧系统。

## 只读 focused-delivery 检查

本次沿同一场景检查：

```text
新建一张便签
 → 唯一 UUID / AppModel / Core Data Note+Todo+Settings
 → A三栏与同ID浮窗 / 同一NSTextView桥接
 → 搜索失配继续写同一张、待办/颜色/收纳
 → 正常保存与跨进程读回
```

完整读取正式10个Swift文件、构建/运行/测试脚本和直接契约，检查稳定ID、IME桥接生命周期、内容日期、配色草稿和提交、窗口/入口唯一性、坏库保护及保存失败。只审设计符合性及直接交付阻断，不扩到无关架构、历史债、风格或全库扫描。已加载 wl-requesting-code-review focused-delivery、at-review及core、at-test与test-execution；本项目为原生Swift，未套Java/Vue/网页测试。

**设计偏离：本轮未发现可证实的业务设计偏离。** 下面是直接验证阻断，不将缺少真人证据说成功能损坏。

### R1 · Major / CHANGES REQUIRED：GUI失败仍退出0，runner可假通过

`/Users/ziyun/workdir/self_project/PaperDock/app/Sources/Application.swift:L103–105`：`report()`只记录 `testFailure` 并打印 FAIL；失败路径随后 `NSApp.terminate`。`/Users/ziyun/workdir/self_project/PaperDock/app/Sources/main.swift:L63–65` 依赖 `app.run()` 之后读取这个字段，但本机实际 terminate 直接结束进程，未兑现非零结果。`/Users/ziyun/workdir/self_project/PaperDock/app/test.sh:L27–31` 仅以 wait成功和正常退出标记判断GUI成功，证据捕获/GUI断言失败也可能被接受。

复现不是推测：

1. 在本轮新目录把 evidence-dir 本身置为普通文件，运行独立正式二进制 `--gui-test`。stderr多条 FAIL，但 PID11702 的 `wait=0`；纯命令行 `unknown-suite` 正常 `exit=1`，故问题在GUI退出链而不是shell吞码。
2. 更贴近runner的反例：本轮新 evidence-dir 正常存在，只把 `00-first-state-content.png` 建成目录，阻止第一张图写入。GUI明确 FAIL，PID13106 的 `wait=0`，且仍写出 `normal-exit.txt`；runner当前两个门都会接受失败GUI。没有改文件权限，没有破坏旧图或库。

真实绝对命令、stderr、PID及退出码分别见 [negative-exit.log](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/negative-exit.log)、[negative-gui-marker.log](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/negative-gui-marker.log)。这不证明正向图或其他规则实际失败，但证明单靠目前 exit0/正常退出标记不能批准GUI验证。

**最小修复建议**：由原实现者将GUI失败状态连接到可靠的真实进程退出结果，runner再验证明确GUI成功结果而不是仅正常退出；补该负向分支。独立者不修源码、不改预期；已即时发协调者并获确认，本轮冻结，不等待修复。后续仅针对退出状态/runner负向和受影响GUI另建轮次复验，其他未变规则不重复全跑。

## 实际验证与证据边界

**唯一逐用例/检查点结果**：[result.json](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/result.json)。TC-001～014均有对应记录，P程序、G独立读图、H真人分别填写；原型重置/B-C/全局快捷键/异常零丢失等边界分开说明，未验保留，不在本报告另复制逐项表。部分程序检查只证明子性质，没有把整步真实GUI操作写成通过。

### 真实命令

1. 独立新构建并运行现有正式套件：

```bash
bash /Users/ziyun/workdir/self_project/PaperDock/app/test.sh \
  /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/suites \
  /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/build
```

实际退出0。完整展开命令见 [commands.log](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/suites/commands.log)，每个套件独立日志保留。标题、日期规则、查询/控制器、颜色草稿与固定/随机、NSTextView delegate、窗口和HSV、坏库以及 write/read/read-random 均得到预期程序断言；GUI正向真实菜单/窗口/内容图完成。R1另列失败，未把正向退出0当作足够覆盖负向的证据。

2. 本轮只读链接正式源码（排除产品main，加入独立Probe主入口）编译，不复制/修改正式业务实现：

```text
swiftc -swift-version 5 -O -framework AppKit -framework SwiftUI -framework CoreData
  正式 Store/Model/Editor/Manager/Palette/PaletteUI/Windows/Application/SelfTests.swift
  /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/IndependentProbe.swift
  -o /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/build/IndependentProbe
```

编译0、运行0。驱动和实际断言见 [IndependentProbe.swift](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/IndependentProbe.swift)、[independent-probe.log](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/independent-probe.log)。真实NSHostingView下查找正文NSTextView，确认同ID发布保留同实例，搜索失配继续写原ID，另一个浮窗同步；marked期间不提前保存、不被其他字段发布覆盖，确认后delegate保存；切ID换实例、不串写。五个项目内新库分别从Calendar D-1开始，待办仅新增/改字/完成/取消/移除一次均迁今天并保留正文。**这是控件程序调用，不是系统输入法认证。**

3. 正式四记录夹具播种→正常GUI打开→正常退出→同目录导出，`cmp=0`；正式系统窗口捕获完整命令见 [run-window-captures.sh](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/run-window-captures.sh) 和 [window-capture-commands.log](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/window-capture-commands.log)。没有与开发实例并发、没有多个写者共用一个目录，导出等GUI退出后才做。

4. 坏库保留使用正式bad-store套件，读取并比较主文件字节；保存失败用正式save边界钩子抛错，验证dirty/error、内存正文保留、退出判断拒绝及重试。**没有伪装真实磁盘满；未独立实拍未保存提示/NSAlert。** 反向GUI检查的实际0与期望非零明确记失败，不用后续命令覆盖原返回值。

### 原生视觉检查：已有真实窗口实拍，但不是全部GUI验收

准备文档估计无屏幕录制权限；本轮公开 `CGPreflightScreenCaptureAccess()` **实测true**。未调用request、未改权限、未注入全局输入。用公开窗口列表仅筛本任务PID的窗口ID，执行 `/usr/sbin/screencapture -x -o -l <本任务windowID> <本轮文件>`，8次均退出0。**仅指定窗口捕获，不是桌面全屏截图，也不证明外部应用遮挡关系。**

已实际逐张打开阅读8张系统窗口实拍及8张原生内容图；不是只检查存在/OCR。原生内容图为NSView.cacheDisplay，单独标注，不混称系统实拍。无正式视觉基准，均为候选证据经独立审阅，不虚构截图diff。

- [四记录A三栏实拍](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/screenshots/fixture-window-149181.png)：今天/昨天/日期组、标题摘要、收纳与数量可辨，右栏未选择为空态，无旧正文残影。
- [正式浅色浮窗实拍](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/screenshots/fixture-window-149183.png)、[深灰浮窗实拍](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/screenshots/palette-window-149199.png)：正文换行、标题、两种待办、管理/收纳/纸色可读，未见裁切、重叠。系统标题栏按其自身外观；未声称控件无障碍全面通过。
- [首次空态实拍](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/screenshots/first-window-149194.png)：首次说明与两个新建入口，三栏没有示例残影。
- [失配保留编辑器实拍](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/screenshots/palette-window-149194.png)、[较窄浅色实拍](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/screenshots/invalid-window-149194.png)：提示不挡输入，搜索与原编辑器同时可辨，880pt下本次短正文/两待办可操作；未扩张到长数据/所有宽度。
- [大HSV与无效hex实拍](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/screenshots/invalid-window-149201.png)：六色、大色盘、色相条、预览和范围/取消/应用可见；错误文字完整、应用禁用，无明显越界。该GUI probe是正式PaletteView承载于自有证据窗，**没有因此证明真实编辑器sheet的打开/关闭全链**。
- 内容图的空回收站、深浅正文/checkbox、选中列表、无搜索结果均已读；本轮观测状态未见P0/P1视觉问题。尚缺真实sheet所有模式、实际Tab焦点、长正文/多待办滚动和边缘展开实拍，不将局部读图记成全部视觉门禁PASS。

### 本轮进程收尾

六个本轮GUI/Probe PID **5685、8510、10503、10732、11702、13106** 均由本任务直接启动，经正常 `NSApp.terminate`；`wait=0`且定向 `ps` 返回1无匹配。负向进程wait0属于R1缺陷，**不是对应测试通过**。未强杀、未关他人应用。

[final-pids.log](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/final-pids.log)、[independent-process.log](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/native-review-01/evidence/independent-process.log)、GUI命令日志和各自 normal-exit/exit快照保留退出证据。没有遗留等待用户的GUI。

## 仍需要的最短人工步骤

R1修复并受影响复验通过后，由协调者安排用户用**同一修后正式版本、新隔离目录**完成以下步骤，不复用旧实验结论：

1. 从外部普通应用开始，靠近/离开边缘，取消一次拖动，再有效拖出一次并再次唤出；记录只新增一个ID。外部应用和便签部分重叠分别输入，确认焦点随点击、置顶不抢输入；便签移动缩放后续写。
2. 正式正文启用中文输入法，保留一次未确认组合、选候选、退格续写，观察重复/提前提交/光标；不是粘贴中文。
3. 从实际纸色sheet点拖大色盘、Tab/方向键/Enter应用；分别取消/右上关闭/Escape，核对单张/固定/随机隔离。菜单与列表/空态新建、局部Command+N、边缘入口分别核对唯一创建及颜色。
4. 同一合成便签按TC-014两次正常菜单退出重开，比对ID/正文/标题/两状态待办/单张色/收纳/固定及七色随机池。真实午夜刷新单列未验，不要求修改系统时钟。

**交付判断：CHANGES REQUIRED。** 本轮独立检查、独立构建与证据冻结已完成；R1需要原实现者修复，完整成品验收仍证据不足。未进行安装、改权限、发布/Git、全局键鼠注入、日常资料访问或授权外操作；未验部分不等于功能已坏，也不能写成正式全部通过。

---

## R1 定向独立复核 · r1-review-02（追加，不覆盖上轮）

2026-10-24，`task_214a5410e1e0 / ctx_543325a8853b`。原实现修复任务 `task_b8b5dcb47b1c` 已冻结；本检查者未写实现、未向下委派。唯一新轮次结果为 [r1-review-02/result.json](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-02/result.json)，`previousRun` 关联上轮 `native-review-01/result.json`；旧174项及原R1失败证据未覆盖。

### 冻结与最小检查范围

新开发清单14项全部匹配；与旧冻结逐文件比对，**恰好仅 Application.swift、main.swift、test.sh、app/README.md 改变，其余10项不变**，见 [source-check.json](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-02/evidence/source-check.json)。结束再核对全匹配。设计v0.2、用例v0.3、execution-plan未改；只读四修复文件与正式保存/退出直接依赖，未重审10个Swift文件或重跑无关全套。未变规则证据引用上轮，不复制成新通过。

独立新构建：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-02/build/PaperDock.app/Contents/MacOS/PaperDock`，SHA256 `369bfc25f3d57d3871d196676beb212764e96d74e561e10e58dd57f8ea3095b4`。构建与正式runner真实命令：

```bash
bash /Users/ziyun/workdir/self_project/PaperDock/app/test.sh --gui-only /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-02/evidence/positive /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-02/build
```

[positive-runner.log](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-02/evidence/positive-runner.log) 记录编译及runner退出0、GUI PID37653真实wait0；同PID `gui-result.json=passed/completed=true`、正常保存标记及定向ps无匹配全部核验，不拿旧exit0或单一normal-exit当成功。

### 失败 → 正常保存退出 → runner拒绝，逐环节复验

```text
同形首图目录冲突 → 首个截图错误保留
 → 原保存判断成功才stop+唤醒主循环 → main最终写结果并返回1
 → runner同时要求真实wait0、进程退出、正常保存、同PID明确完成
```

真实执行命令、PID、wait及ps逐条保存在 [focused-commands.log](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-02/evidence/focused-commands.log) 与 [process-events.jsonl](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-02/evidence/process-events.jsonl)：

- 同旧R1反例：新目录中仅把 `00-first-state-content.png` 建成目录，PID39806真实wait **1**，首个截图错误未被“未完成”或保存成功覆盖；normal-exit存在，但结果明确failed/completed=false。
- 探针主体完成后，尾部 `exit.json` 或 `gui-result.json` 为目录：PID39855、39962均真实wait **1**。尤其结果文件本身写失败仍非零，不能因主体完成/normal-exit存在假报通过。
- evidence-dir本身为普通合成文件：非gui-test PID40059真实wait **1**，可靠证据失败不假成功。均未改权限或制造磁盘满。
- 正式 `--check-gui-result` 同一门拒绝旧真实normal-exit但无结果、修后failed却传入模拟wait0、错PID、completed=false及缺少completed字段，均退出 **1**。这些0是**门函数参数模拟值**，不是对应GUI真实wait；正反向GUI真实wait另存，不混写。
- 非gui-test正常启动/计时退出：正式四记录夹具 → PID40159正常保存退出 **0**、dirty=false/error=null → 新进程导出，前后JSON字节完全相同；最小退出回归未见记录/待办/ID/设置丢失。这不是TC-014真人菜单退出整链通过。

保存失败保护另以独立驱动只读链接正式源码，在现有 `Store.beforeSave` 边界抛错，实际 `Store.save → AppModel.canTerminate=false`，dirty/error与内存正文保留；清除故障后同边界重试成功，并经第二进程读回正文。见 [SaveBoundaryCheck.swift](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-02/evidence/SaveBoundaryCheck.swift)、[save-boundary.log](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-02/evidence/save-boundary.log)。没有进入 `applicationShouldTerminate` 的模态分支、没有重造无人处理的NSAlert，**不把这条边界检查提升为模态实操通过**。

### 新副作用、视觉与剩余证据

聚焦检查未发现新的设计偏离或可证实的直接交付阻断。新读取正向原生内容图四张：首次空态、深色浮窗/两状态待办、无效hex提示/应用禁用、880pt失配编辑器；未见新遮挡或裁切。截图在新轮次 `evidence/positive/gui/`，均为 **NSView内容图，不是系统窗口实拍**；UI文件不变，上轮系统窗口观察按原边界复用，不声明全视觉PASS，不额外申请权限/捕获桌面。

原实现者额外 `SaveExitProbe` PID25502曾模态等待超时；本轮复查ps无匹配，但历史仍缺真实wait与正常退出证据，**BLOCKED保留，绝不写成通过**。该历史缺口与本轮无模态保存边界检查分别记录。

本轮自有六个GUI PID37653/39806/39855/39962/40059/40159均经正式保存后stop/返回路径退出，真实wait分别为0/1/1/1/1/0；所有自有命令/独立边界驱动也已wait并定向ps无匹配，见 [final-pids.log](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/r1-review-02/evidence/final-pids.log)。无强杀、无遗留等待用户实例；旧JSON SHA256不变，原报告仅追加本节。

**本轮结论：R1在退出码与runner的定向范围已闭合，没有发现直接新回归；不等于整个产品PASS。** 真人中文输入法、物理边缘拖出/取消、跨应用焦点、真实配色sheet键盘/取消及完整真人正常退出恢复仍未验，历史模态探针仍BLOCKED；下一步由协调者启动同一修后正式版本引导真人，不需要本检查者等待用户操作。
