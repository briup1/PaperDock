# 0007 执行记录：190pt反馈修正已实现，待本轮独立审查与体验

当前执行阶段：verifying，不标done。当前反馈修正候选为下方“v0.5反馈修正增量”的candidate-final；上轮candidate-03与独立审查仅为历史证据，不自动覆盖本轮新增行为。

## 范围、授权和单包计划

来源：需求／用例v0.4、唯一方案HTML v0.2。协调者转达用户真实原文：“直接修改需求和方案、其余没问题、进入开发、全部交给你协调、效率优先”。175…1000pt为委托下推荐，不是用户逐字规定；177.5保存精度不变，真实系统外框允许≤1pt对齐误差。

唯一负责人串行同一高耦合包，不再委派：

1. 更新需求／用例v0.4、唯一方案HTML v0.2，撤销旧批量减半／v2迁移；已完成。协调者另派独立文档复审，三处精度已吸收，见case-readiness-review.md的v0.4段；修订后不冒充再次独立复核。
2. 独占AppKit／SwiftUI probe；真实WindowServer排序／程序编辑／重显／短布局已有证据，真实key仍未证实。协调者明确仅以程序链采用可逆隔离候选开发；方案delegated/adopted，approval_evidence=null，not_verified保留最终体验Gate。
3. 串行完成Store／Model／Windows／Editor／Manager与必要SelfTests、NoteSettingsTests、app/README；不改SQLite模型及随机池。
4. 标准fingerprint因他人输入拒绝，保留失败；候选使用HEAD tracked基线＋本轮白名单逐文件叠加，测试前source manifest／hash留存，其他输入取HEAD。聚焦程序测试及候选内容图已完成，现旧GUI探针失败原样保留。
5. 提供候选绝对命令与审查材料，不生成ready、不提交安装、不自动持续启动交给用户。

用例：TC-001锁条；TC-002高度草稿／范围／失败前旧值／短布局；TC-003旧字段／跨进程；TC-004/005层级／候选／锁绕过；TC-006原配色。具体数据、操作和预期仅用例正文维护。

仅项目内合成数据、零新依赖成本；未提交／推送／安装／发布，未读日常库、未退出用户PaperDock、未改系统设置／权限。工作区Application.swift关于版本、根README、local_delivery及0006等属于其他任务，不改、不纳入候选。

## 改动清单及源码来源

本轮正式文件（以下均相对仓库，仅便于核对；真实根为`/Users/ziyun/workdir/self_project/PaperDock`）：

- `app/Sources/Store.swift`：NoteHeight有限范围、全局高度和按张layer；v1缺字段兼容／null错类型拒绝，原子写后发布；展开按当前高度、最终锁校验、保留颜色模型。
- `app/Sources/Model.swift`：高度草稿／可见反馈、成功才生效，层级操作与锁定／候选边界。
- `app/Sources/Windows.swift`：打开生命周期应用高度、保持宽/x/上沿，现有打开窗不因通知跳动；折展尺寸同步、normal−1／floating与显示顺序、超屏显示限幅不改设置、目标面板候选保护。
- `app/Sources/Editor.swift`：折叠锁定不构建＋／×／层级按钮，保留错误／解锁；互斥层级操作、compact统一外层滚动，仍用原有界NSTextView／字号。
- `app/Sources/Manager.swift`：管理页高度输入＋保存、生效值及错误／成功提示。
- `app/Sources/SelfTests.swift`：分派新套件、compact-red新默认及容差；原windows测试针对无系统关闭按钮的borderless窗改用正式windowShouldClose delegate，并补测试自身hide回调，不修改应用关闭行为。
- `app/Sources/NoteSettingsTests.swift`：新增未跟踪文件，调用正式边界覆盖高度／失败／锁绕过／旧字段／跨进程和原生控件。
- `app/README.md`：0007当前语义、测试与数据兼容边界。
- `docs/requirements/0007-note-layer-height/requirement.wl-req-confirm.{md,html}`、`test-cases.wl-qa-test-planner.{md,html}`、`design.wl-design-doc.html`、`render-docs.py`、本`progress.md`：当前目录原本未跟踪，逐个列明，不因git diff空就遗漏。`case-readiness-review.md`由协调者的独立审查者追加，不是本负责人所改。

可复核diff：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/review/tracked-task.diff`；新文件／文档原样副本和未跟踪列表同目录，不能用tracked diff替代。

## 唯一当前候选

源码快照：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/candidate-03/source`。

- HEAD基线：`0634b0f87032cc1d69538a47f3d59bf6f1c39b8b`；原始tracked逐文件复制，再叠加上述8个app文件（含新增测试）；Application.swift、build.sh、图标及其他非本轮输入从HEAD取，不夹带工作区修改。
- 测试前manifest：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/candidate-03/source-manifest.json`；逐文件输入hash：同目录`build-inputs.sha256`；生成脚本为本轮artifacts下`snapshot.py`（不成为产品能力／新依赖）。
- 构建输入摘要SHA-256：`673fcbd7d713247ff2a0c17960ce7f61a06e842ba1028e0e7e615acd31b4cae4`。
- 二进制：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/candidate-03/build/PaperDock.app/Contents/MacOS/PaperDock`；二进制hash同目录`binary.sha256`。
- 构建实际命令：`bash /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/candidate-03/source/app/build.sh /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/candidate-03/build`，exit 0，日志同目录`build.log`。未覆盖默认app/build。

仅待用户／协调者明确启动体验的空隔离库命令（本轮未执行此命令，不双击app，不用open -a）：

```bash
/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/candidate-03/build/PaperDock.app/Contents/MacOS/PaperDock \
  --data-dir /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/user-experience/data \
  --evidence-dir /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/user-experience/evidence
```

若两个体验目录已被其他运行创建，先核对归属，不能复用或清空。候选只含本轮叠加，不含他人“关于版本”改动，无标准ready。

## 标准指纹拒绝（不伪造交接）

测试前先调用现`python3 app/local_delivery.py fingerprint --paths`选择本轮逐个文件。首次在probe阶段选择五模块及0007文档，exit 1：`Build input outside selected snapshot: app/Sources/Application.swift`，原日志`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/fingerprint-preflight.log`。

补齐本轮SelfTests／新增测试／app README及progress后的完整范围重试仍exit 1，相同原因，日志`fingerprint-before-final-tests.log`；不能靠扩大选择纳入他人文件绕过。未调用approve，不存在本轮标准ready；替代manifest明确是源码快照证据，不冒充标准交接。

## 关键实验与采用记录

根：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/probe`。工具链本轮核实Swift6.3.3／macOS26.5.1 arm64。独立Probe.swift只编译AppKit／SwiftUI，不链接正式应用，不读便签库。

- 第一次编译Body命名与View.Body冲突exit 1，compile.log保留；改名后compile-02.log exit 0。
- 三次实际运行PID86372／87285／87907均wait 0、normalExit=true、进程结束。CGWindowListCopyWindowInfo实际顺序floating > normal > desktop，编辑／隐藏重显后仍下；但原程序key=false，177.5实际外框178。3轮停下并上报，不无限重跑。
- 175／约178pt SwiftUI合成内容图已实际查看：第12待办、添加、错误和重试可达。是内容缓存图，不是系统截图或最终产品。
- 协调者另明确授权一次不同目的定点诊断：finishLaunching、activate等待、normal与desktop同型nonactivating面板对照。`focus-diagnostic/result.json`：app.isActive=false，normal和desktop都isKey=false／keyWindow=nil，sendEvent可编辑。PID89911 wait0、normalExit=true、进程结束；未发现负level额外差异，但真实key仍未证实。
- 协调者明确决策：“采用程序链证据进入候选开发”，仅可回退隔离候选；不得把程序编辑写成真人跨应用／IME通过。方案critical_validation verified仅指实际最小程序假设，同时not_verified列出真实key等最终体验Gate；不是放弃缺口或用户接受完整交付。

## 正式程序验证与原始失败

所有`--test`用当前快照build绝对二进制，显式`--data-dir`。真实命令结果见各候选evidence/commands.log；每个独立套件用全新目录，共享持久化目录仅write正常结束后另进程read。

### candidate-01

构建exit0；新规则、严格兼容、原生controls、pin-rules、editor、palette、dates、跨进程write/read均exit0。旧windows套件exit1 `close stash`：测试自身仍performClose(nil)且未接hide回调。未以改应用行为绕过；SelfTests定点改为现正式关闭delegate并接回调，下一快照复跑通过。

### candidate-02

构建exit0；note-settings-controls、windows、note-settings-write/read exit0。最终note-settings-rules、compat、pin-metadata、pin-io、pin-rules、editor、palette、dates、controller各exit0；布局原子失败、严格null／坏值、候选保护、锁绕过均走正式边界。

额外扩大一次原GUI链：

```text
…/candidate-02/build/PaperDock.app/Contents/MacOS/PaperDock --gui-test
  --data-dir …/candidate-02/evidence/gui-data
  --evidence-dir …/candidate-02/evidence/gui
```

PID99083，真实wait=1、进程结束，normal-exit.txt存在，但同PID gui-result.json为status=failed、completed=false，failure=`real close stashes`。定位HEAD Application.swift旧探针仍对borderless无系统关闭按钮的窗performClose(nil)；本轮不改他人Application或快照HEAD来伪造通过。失败保留，正常保存标记**不等于GUI通过**。candidate-03未改产品逻辑，仅加强测试，故不再重复同一已知GUI失败。

### candidate-03（当前）

只加强测试至默认270宽短窗、展开失败保护、1000超屏可达及图像。产品输入与candidate-02一致，未因测试行号变化机械重跑所有不变套件；前述相关通过可按manifest逐文件核对复用。

实际本候选运行：

- `--test note-settings-controls --data-dir …/candidate-03/evidence/note-settings-controls` exit0：当前打开不跳、整理B及重复显示A不跳、失败后重试前新开仍旧值且字节不变、真正重开新高、旧锁保持、175/177.5有界正文和长文末尾delegate编辑、末待办与增删、错误滚到底和内容保留、层级失败／锁绕过／marked text、折叠27／下次展开当前值、1000显示限幅且保存值不变。
- `--test note-settings-rules --data-dir …/candidate-03/evidence/note-settings-rules` exit0：新增展开失败仍折叠及metadata不变，其余范围／草稿／最终Store校验／内容时间。
- `--test note-settings-write`→另进程`--test note-settings-read`，同`…/candidate-03/evidence/persistence`，各exit0：全局500、A沉底B锁定浮顶、完整内容／时间／ID／自定义设置跨进程，原生恢复高度500和混合level。
- 另`--test note-settings-write --data-dir …/candidate-03/evidence/launch-smoke-data` exit0准备合成样本，再普通启动同data＋`--evidence-dir …/candidate-03/evidence/launch-smoke --quit-after 3`。PID3207 wait0、进程结束，launch/exit同PID、dirty=false／无error、normal-exit存在，两个窗口height500、levels=-1/3。这是正常启动／保存／退出冒烟，不是GUI探针passed、真人key或全功能验收。

内容图：`…/candidate-03/evidence/note-settings-controls/content/`中的175/177.5顶部、bottom-error和collapsed-locked-error已实际查看；默认270宽也能看到末待办、添加、错误／重试；锁条只有标题、错误及解锁。launch-smoke/manager-content.png已查看，高度输入、保存与生效值500可读。均为NSView.cacheDisplay原生内容，不含系统遮挡、不是实机窗口截图。

## 自查、证据边界及待办

- 按已读core规范自查本轮diff：仅直接范围；存储值校验、null与缺字段区分、锁最终拒绝、原子写后发布、失败旧值／草稿保留、目录锁与SQLite模型／颜色逻辑不变。源码manifest与候选输入已核对，未夹带他人Application；不是独立实现审查。
- 需求／用例HTML同源hash、本地链接与锚点检查通过；check_design_doc.py --require-executable为delegated/adopted结构通过；git diff --check通过。不把静态检查写成HTML浏览器视觉通过。
- [独立实现审查](implementation-review.md)已完成：本轮diff与直接交付边界内无新增代码阻断，可进入限定的隔离候选体验；报告已只读核对源码manifest、白名单来源、已有命令退出码及旧GUI失败记录，不代表重新执行测试或全部验收通过。
- 最终未验：真人key／跨应用沉底后键盘与点按、真人中文IME和滚轮／Tab手感、真实边缘手势、完整GUI与HTML桌面／390px视觉。正常GUI旧探针已明确失败；未宣称功能全通过、ready、done或可正式安装。
- 当前结论为**隔离候选开发、所列聚焦程序验证及[独立实现审查](implementation-review.md)已完成，无新增代码阻断，仍待最终真人体验**。旧GUI failed／completed=false、真实key／跨应用／IME／滚轮Tab等缺口及无标准ready边界不变，不能标done或正式安装；源码与旧证据保留，无后台进程交接，无日常数据操作。
- 本次仅更新本执行记录的审查状态与报告链接，未改源码／需求／方案／用例，未重跑测试、截图或生成ready。

## v0.5反馈修正增量：190pt、设置入口与连续待办（2026-10-25）

本节为新增执行记录，不改写上面的失败和历史候选。用户明确批准“按190pt修正原型立即更改两处并替换本机体验”；本工作包只实现、隔离验证和构建候选，安装／真实数据处理由协调者另行执行。

```text
旧：列表顶部高度区；滚动[标题→正文→待办→添加]
  → 第1条挤出添加按钮，190pt也可复现
新：设置页完整高度区；固定工具栏→滚动内容→固定下沿添加
  → 每次新增按UUID滚到新行并聚焦，下一次添加不移位
```

### 范围与复现

- 批准记录已写需求／用例v0.5、方案v0.3；新增TC-007与TC-008。高度190仅用于新空库／缺字段，已保存177.5等值不覆盖；SQLite模型、布局version1与随机规则不变。
- 复用原失败证据：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/todo-height-diagnosis-01/analysis.md`。
- 新回归先于产品修正执行：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/before-fix-02` build exit0、controls exit1 `add fully visible after 190.0/1`；证明不是只把177.5调190即可修好。首次测试编译autoclosure抛错build1保留在before-fix，修测试后才得到行为失败。
- 直接新增：Manager迁入SettingsView整个高度区；Store默认190；Editor固定下沿添加、ScrollViewReader滚动及FocusState；Model／Windows增加仅本张的marked-text添加前检查，候选未确认拒绝新增而非抢焦点；SelfTests改新默认断言；NoteSettingsTests补已保存177.5原字节不变；新增TodoControlsTests真实控件回归。app/README同步；Application.swift、根README、local_delivery、0006及原型未改。

### 最终候选与测试前输入

- 根目录：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/candidate-final`。
- 源码：该目录`source`；HEAD=`0634b0f87032cc1d69538a47f3d59bf6f1c39b8b`，来源与上轮candidate-03相同。八个原覆盖模块／说明保留，并新增TodoControlsTests覆盖；Application.swift与其他输入逐字来自HEAD。未夹带工作区他人改动。
- 测试前记录：`source-manifest.json`、`build-inputs.sha256`；摘要=`2a42dccb55b68fc5ca51455e28418298b826301c3afce193d528846b50d0df2d`。最终逐文件重新核对工作区与快照hash相同，Application与HEAD逐字相同。
- 二进制：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/candidate-final/build/PaperDock.app/Contents/MacOS/PaperDock`。
- 二进制SHA256=`8daa3889a9b41b884382eca0fd4fe1cf1ba6cb99f2f521516e8643f4dad80d41`，文件`binary.sha256`。
- 构建：`bash /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/candidate-final/source/app/build.sh /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/candidate-final/build`，真实exit0，build.log保留。
- 标准fingerprint仍因他人Application.swift拒绝exit1，`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/fingerprint-preflight.log`保留；不扩大白名单、不approve、不写standard ready。
- 本轮相对上轮源码增量：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/incremental-source.diff`。

### 聚焦结果与不能冒称的部分

完整命令、真实PID／退出码及进程结束：candidate-final的`evidence/commands.json`；每套日志同目录，套件均用独占合成数据，write正常结束后才另进程read同库。

- `note-settings-todo-controls` exit0，PID79942：190与175两轮空便签真实NSButton.performClick逐次0→1→2→3，逐次核对实际count、添加按钮与全部裁剪祖先可视区、新行输入完整可视及currentEditor===panel.firstResponder；添加位置恒定。100行正文delegate末尾编辑／字号12.5、保存失败追加仍保留、滚动错误区、正式save恢复、锁入口隐藏与Store最终拒绝、程序marked text阻止新增均通过。不是物理指针／中文IME／跨应用焦点。
- 设置验证：Manager中已无高度输入，SettingsView中原高度区完整可见；Model保存失败保留175与草稿500，成功后生效500，成功／错误内容图均实读。此处验证真实渲染＋正式Model调用，未把设置保存按钮真人点击记通过。
- `note-settings-controls`、`note-settings-rules`、`note-settings-compat`、`note-settings-write`→`note-settings-read`、`editor`、`palette`、`controller`、`windows`、`pin-rules`、`pin-metadata`、`pin-io`、`compact-red`各exit0且进程结束。兼容套件确认缺字段190、已有177.5不重写，严格错误字段拒绝；旧高度失败／生命周期与锁／层级规则回归通过。
- 原生内容图在`evidence/note-settings-todo-controls/content`，190/175三条后、错误区、设置失败／成功与manager均实际查看：入口／新行无重叠裁切，设置输入／保存／生效值／反馈齐全。NSView缓存图不等于系统窗口截图，尚无可信原生截图基准，不声称完整视觉或跨应用通过。
- 中途candidate-01／02／diagnostic-03／03止于`retry missing`：默认SwiftUI重试按钮真实可见，但隐藏视图无NSButton或AX子节点可定位，不是产品无重试。协调者明确收敛后，仅candidate-04尝试一次几何sendEvent，日志`saved=false errorCleared=false`，不能证明点击重试已通过。最终测试移除该诊断，保留正式save恢复断言；真实重试按钮、设置保存按钮点按留待真人，不再重跑同型定位。
- 未运行完整GUI探针／持续GUI体验／安装；旧candidate-02 GUI failed／completed=false证据保留，不被本轮套件通过覆盖。真人key、跨应用、IME、滚轮／Tab与完整验收仍未验。本轮独立Review由协调者安排，不能继承上轮独立审查；无standard ready、不标done。

供协调者／用户另行明确运行的空库入口（本工作包未启动）：

```bash
/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/candidate-final/build/PaperDock.app/Contents/MacOS/PaperDock \
  --data-dir /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/user-experience/data \
  --evidence-dir /Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/user-experience/evidence
```

### 协调者收口：已安装启动，待真人体验

独立审查已完成：[本轮反馈实现审查](feedback-implementation-review.md)，无新增代码阻断；审查者未重跑测试，明确保留真人项目与标准ready缺口。

按用户本轮“立即按原型更改两处，然后替换本机版本”授权：核对唯一旧PID33213、绝对应用路径及原数据目录后，通过AppKit terminate正常退出并确认进程结束；未强杀。原目录`/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/compact-user-03/data`通过正式Store.setDefaultHeight(190)将177.5改190，执行前已在合成库验证该路径；操作中核对SQLite主文件hash不变、其他布局字段不变、内存正文／待办／配色及placements无变化，不复制／迁移数据库。

安装并启动：`/Users/ziyun/Applications/PaperDock.app`，PID91476；同PID的NSRunningApplication确认finishedLaunching=true，命令行使用上述原数据目录。候选来源仍为candidate-final，签名前SHA256如上；本机ad-hoc签名验证通过。启动核对不等于完整验收或标准ready。

旧应用保留在`/Users/ziyun/Applications/PaperDock.previous-0007-before-fix.app`，不自动回退数据。日常启动继续使用`/Users/ziyun/Applications/启动 PaperDock.command`，沿用原数据目录；未提交、推送或清理旧包。

本次安装结果：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/local-install/result.json`。当前状态为已更新、待真人体验；真实设置保存／重试按钮、中文IME、跨应用与滚轮Tab等未验项仍保留。另有执行者误建OpenViking零字节空文件的偏差，详见implementation-report.md；无内容上传，未擅自删除。
