# 0003 compact/icon：独立聚焦复核与有限诊断

## 本轮版本、权限与入口

- 需求/用例/方案均为0003 v0.1；范围仅TC-020～022及直接依赖。采用focused-delivery，不扩大到全库、性能、输入法或无关回归。
- 当前候选是 `artifacts/developer/compact-icon-01/build-06/PaperDock.app`，不是旧`build-final`。二进制SHA256：`11eda448ec1636ddadcbc4e5acd8dfac339ec02b05c67b37da397c12a5440aeb`。
- 实际核对的清单为`frozen-source.sha256`和`frozen-artifact.sha256`（本轮没有名为frozen-binary.sha256的0003清单）。执行前后全部匹配，日志见本轮evidence的source/artifact-before/after.log。
- 唯一逐项记录：[result.json](../artifacts/acceptance/compact-icon-review-01/result.json)；本轮证据目录：[evidence](../artifacts/acceptance/compact-icon-review-01/evidence/)。未修改业务源码、正式测试、用例预期、旧结果或旧构建；未作第四次补丁，原实现Task的failed不变。
- 旧用户PID46879仍运行；没有终止、共写其库、覆盖`app/build`、启动第二完整GUI/边缘、激活应用、安装、权限修改、全局输入、发布或Git操作。

## 实际操作链路与观察

```text
冻结hash核对
  → 原业务源链接独立Diagnostic.swift（仅证据目录，未引入ApplicationController/主应用入口）
  → 自有未显示NSPanel，270×355pt外框 / 270×323pt内容 / scale=2
  → 合成20句正文＋8待办，同一ID
  → 排版/clip/最终字符矩形对照，固定一次诊断，无循环试错
  → 内容图实际读图、独立未修改源码包构建与图标核对
  → 源码/原包hash复核，自有PID正常结束
```

探针命令、构建退出码、PID记录在`evidence/commands.log`，源码是`evidence/Diagnostic.swift`。它链接当前原始`Store/Model/Palette/PaletteUI/Editor/Windows.swift`，没有替换正文、窗口或存储实现；只提供独立诊断入口和失败辅助类型。独立完整包另通过原`app/build.sh`输出到`evidence/build/PaperDock.app`，成功但没有运行完整应用。

### 长文异常：能证明什么

旧证据保持不变：`controls-02.log`、`diagnostic.log`、`controls-03.log`在最终字符viewport断言失败。旧诊断frame/bounds高631、used高615，而visible y220..331，可见字符{210,139}/605；bounds接近底部的旧弱断言不能证明真正到尾。

本轮只执行一次未显示探针。`observations.json`记录：

| 时点 | textContainer宽 | text frame高 | clip/visible y范围 | used高 | 最终字符 |
|---|---:|---:|---|---:|---|
| 首次scroll前，读取usedRect | 254 | 421 | 0..111 | 120 | 未查询 |
| 首次scroll并settle | 254 | 631 | 520..631 | 615 | 未查询 |
| 插入尾文、第二次scroll后ensureLayout | 254 | 631 | 520..631 | 615 | rect y608..623，与真实clip相交；可见字符{510,95}/605 |
| 显式完成全文排版后再scroll/settle | 254 | 631 | 520..631 | 615 | 同上 |
| 直接clip到底对照 | 254 | 631 | 520..631 | 615 | 同上，仅诊断，不作产品PASS |

本轮没有改容器宽度、字号、正文业务、断言预期。正文`insertText`经真实delegate保存到同一ID，图中“末尾可编辑”可见；待办卷轴从y0..74到y108..182，`long-todos-bottom.png`实际可见6、7、8及“核对项目8末尾续写”。**待办续写通过Store.edit模拟，不是实际TextField键盘输入；不能当真人编辑验收。**

关键限制：本轮在第一次scroll之前额外调用了`layoutManager.usedRect`等观察API，可能影响惰性排版，因此不是与旧失败完全等价的复现。最初frame421/used120随后631/615的变化支持“排版状态尚未稳定”的解释；但不能仅凭一次不同观测顺序成功，断言根因已经确定，更不能推翻旧三次失败或证明真实产品滚动正常。本轮对照已用尽，协调者已明确接受收口，不继续探针。

### 实际读图与有限异常

以下均为`NSView.cacheDisplay`得到的**未显示控件内容图**，不是系统截图，不包含系统标题栏/窗口服务器遮挡，也不证明真实置顶、焦点或鼠标操作。

- `empty.png`、`light.png`、`dark.png`：空白/浅/深色可读；顶栏钉住、纸色、管理、收纳图标在内容范围内；无“桌面可见”。
- `long-original-order.png`、`long-todos-bottom.png`：正文末尾文字及待办8分别有匹配的同ID几何/模型证据；底部添加、保存文字可见。
- `locked.png`：已钉住与解锁可见；文本isEditable=false、窗口不可移动/不可缩放。**正文首行在日期下缘出现被截半/侵入的绘制异常**，不把它包装成视觉通过；只能确认未显示缓存绘制异常，尚未证明真实屏幕同样发生。
- `manager.png`：独立编辑器未缩小，正文17pt/inset12×16；图中保留“已钉住·整张锁定”管理器标签。但它是500×650的独立编辑器内容图，不是完整三栏管理器的系统截图。
- 从本轮独立包解出的`unpacked.iconset/icon_16x16.png`、`icon_32x32.png`、`icon_512x512@2x.png`已实际读图：蓝底白P/浅蓝折角可辨，无额外文字；非运行时Dock证据。

## 聚焦发现（不作修复）

1. `app/Sources/CompactTests.swift:66-80`：🟡 risk：先scroll、后ensureLayout，最后一次scroll后没有settle，并用text坐标的visibleRect直接查询container坐标glyph。当前真实失败仍在第80行；本轮textContainerOrigin=(8,8)，坐标偏移应被记录。**8pt偏移本身不能解释旧300pt差距**，不能据此声称“改坐标即可修好”。最小后续是在用户许可的可见隔离窗口中，完成实际排版后对照clip与最终字符rect，区分产品缺陷和测试时序；不降低预期、不只加等待凑通过。
2. `app/Sources/Editor.swift:33,53-56,112-115`：❓ q：compact正文已有三处裁剪，但本轮锁后滚动内容缓存图仍在日期下缘显示半行正文。定位只到正文桥接/裁剪接缝，不确定是原生可见绘制缺陷还是未显示cacheDisplay行为。最小处理是同一可见隔离场景确认原生clip边界；若真实存在再由人工决定是否恢复修复，不能在本轮继续加裁剪补丁。

除此之外，本轮核对的默认尺寸、compact样式分支、管理器状态保留及Bundle图标接入没有发现已证实的新设计偏离；这不是全功能通过。

## 同冻结范围已核对的局部事实

- `Windows.swift:49-58`从外框推contentRect，无placement才使用新270×355；已有placement恢复原frame。实测所有本轮空白/浅/深/长文新窗外框270×355、内容270×323，未显示。
- `Editor.swift:38-39,108-115,126`仅compact采用12.5正文/15标题/小间距；manager正文实测17/inset12×16。`Editor.swift:77-79`删除范围只针对compact未锁时文案；管理器状态标签保留。
- 历史frame(150,160,390,500)保存后以另一NoteWindows恢复，frame/锁/ID/内容/日期一致；这是**同进程重新构造窗口**，不是本轮跨进程重启证明。
- `Store.swift:50-52`宽下限270、高350与窗口minSize270×350一致，有限值/坐标/最大尺寸检查保留，属于已授权必要依赖；本轮未改Store或数据格式。
- `build.sh:8-10`复制ICNS并声明，`Application.swift:26-28`使用自身Bundle加载。独立包资源与批准素材SHA256同为`156e472f14af0288d670694b589e6ed59e8f840c249e1877922ba0ffa996dea7`，iconutil成功；运行时Dock仍未验。
- 0002规则/元数据/小frame跨进程/R1负向门的旧程序记录仅作为历史依据，不复制为本轮新通过；没有为填满结果重新跑无关套件。

## 收口与剩余验证

自有诊断PID18461同步正常退出0，wait后PID不存在；所有构建命令同步返回，进程记录仅剩原用户PaperDock PID46879。未显示窗口在结束时orderOut，无自有常驻服务或浏览器。

**Verdict：EVIDENCE INSUFFICIENT；长文与视觉门禁BLOCKED，不能交付PASS。** 本轮证明了在特定只读观测/排版时序下末尾与待办8可达，但无法在当前禁止显示GUI的环境中区分真实产品bug与测试排版时序，旧实现failed保持不变。下一步只由用户正常退出旧实例并决定是否允许隔离可见GUI确认；不自动恢复修复、不继续未显示试验。

---

## compact-visible-02：用户退出后的单次可见诊断（2026-10-24）

用户已回复退出，协调者及本轮启动前均查不到旧PID46879和项目PaperDock进程。本轮只获准隔离可见诊断，**没有获准第四次业务修复**。新增唯一结果为[compact-visible-02/result.json](../artifacts/acceptance/compact-visible-02/result.json)，`previousRun`链接原`compact-icon-review-01/result.json`；以上历史失败、观察及限制原文不改，本节是新增证据而非覆盖旧结论。

### 本轮真实执行链

```text
build-06源/产物冻结hash全部匹配 + 启动前无项目实例
  → 独立VisibleDiagnostic.app链接正式Store/Model/Palette/PaletteUI/Editor/Windows
  → NSApp.run正常事件循环 → 正式NoteWindows显示一个NSPanel
  → 同一便签20句正文/8待办，按CompactTests原顺序capture→scroll→insertText→scroll→ensureLayout→glyph断言
  → 记录原失败（此前不额外读usedRect、不提前ensureLayout）
  → 仅一次有界对照：全文排版→重新scroll→正常事件轮→几何及系统实拍
  → 待办到底、同ID程序续写→锁前/锁后cache与窗口服务器图对照
  → 正常保存→NSApp.terminate→delegate stop→run返回→wait=0→ps无PID
```

- 自有PID **31011**，唯一窗口ID **149644**，便签ID **B6952176-F4FE-4BE1-B0D8-29A3C28A090F**。`NSApp.isRunning=true`、`isVisible=true`、`occlusionState.visible=true`；不是又一轮未显示控件盲试。
- 使用公开`CGPreflightScreenCaptureAccess()`，本轮返回true；**未调用request或修改权限**。ScreenCaptureKit只选择同时匹配自身PID与指定windowID的窗口，`desktopIndependentWindow`采集，不含全屏/他人应用。系统图540×710px，scale2；实际外框270×355pt，内容270×323pt。
- [探针源码](../artifacts/acceptance/compact-visible-02/evidence/VisibleDiagnostic.swift)仅在本轮evidence。没有复制/替换业务实现，没有ApplicationController、边缘入口、管理器或全局输入；正文用自有NSTextView.insertText，待办用Store.edit，锁用原AppModel.toggleLock，**全部programmatic，不是真人滚轮/键盘/点击证据**。
- 源码及原build-06产物执行前后hash全部匹配；`app/build`、旧data、旧结果/旧产物、正式测试和预期均未动。探针首次编译因自身两处多余String强解包失败，修正探针后编译0；没有启动第二轮GUI，没有业务补丁。

### 末尾是否实际可见：原顺序不可见，一次对照后可见

原测试顺序在**已显示真实窗口**仍复现失败，不能再把旧失败仅归因于“窗口未显示”。同一便签的实测如下（坐标均pt）：

| 时点 | 正文clip转为text坐标 | 最后字rect（text坐标） | 可见字符/605 | 实际结果 |
|---|---|---|---|---|
| 原顺序第一次scroll后弱bounds检查 | visible y370..481，text高481 | 尚未查询，不提前排版 | 尚未查询 | 弱检查true，但不证明尾字可见 |
| 插入尾文、第二次scroll，再按原测试ensureLayout/查询 | y295..406，text高631 | y608..623 | 原查询{289,131}；坐标修正后{289,120} | 原强断言false；尾字不相交，系统图无“末尾可编辑” |
| 唯一对照：全文排版、重滚、正常事件轮后 | y520..631，text仍高631 | y608..623 | 修正后{510,95} | 最后字**完整包含**，系统图可读“末尾可编辑” |

几何见[observations.json](../artifacts/acceptance/compact-visible-02/evidence/observations.json)，已实际读[原顺序系统图](../artifacts/acceptance/compact-visible-02/evidence/01-original-order-system.png)及[对照后系统图](../artifacts/acceptance/compact-visible-02/evidence/02-layout-rescroll-system.png)。最后字container rect为`{{54.61,600},{12.40,15}}`，`textContainerOrigin=(8,8)`，转换后text rect为`{{62.61,608},{12.40,15}}`；viewport先从clip转text，再减origin查询container glyph。**8pt偏移不能解释原顺序约200pt以上的距离**，不是简单换坐标就能把旧FAIL改PASS。

已证实的因果层级：`CompactTests.swift:66-80`在全文排版尚未稳定时按旧尺寸滚动，随后ensureLayout得到631高正文，却未按新排版重新滚动/settle，故尾字仍在当前viewport之外；一次“全文排版→重滚→事件轮”的有界组合对照足以让同一内容与同一尾字可见。**尚未拆分ensureLayout、重滚、事件轮各自独立贡献，也没有证明用户手动滚轮到底会失败；这不是已证实的业务滚动故障。** 正式旧测试未重写，原失败保持。

同ID正文通过真实NSTextView delegate保存“末尾可编辑”；待办clip从顶部到y108..182，系统图实际可见6、7及“核对项目8末尾续写”。正文20句、待办8条、ID保持且dirty=false。待办续写仍是模型操作，不把它当实际TextField输入通过。

### 日期下缘半行：系统窗口确实存在，但越界/侵入未证实

已实际读[锁前系统图](../artifacts/acceptance/compact-visible-02/evidence/03-todo-bottom-before-lock-system.png)、[锁后cache前系统图](../artifacts/acceptance/compact-visible-02/evidence/04-locked-before-cache-system.png)、[锁后内容缓存图](../artifacts/acceptance/compact-visible-02/evidence/04-locked-cache.png)及[0.4秒后系统图](../artifacts/acceptance/compact-visible-02/evidence/06-locked-settled-system.png)，并仅从这些已授权图裁出日期局部，未新增GUI试验。

- 锁前原顺序与锁后图中均可见**正文viewport上缘裁出的半行，紧贴日期下缘**；不只cacheDisplay有此视觉现象。锁后系统图在本次cacheDisplay调用之前已存在半行，cache后及0.4秒后系统图SHA256完全相同（`a2d2b909…b6283e`），排除本次cacheDisplay独有伪影及这段短时序内才消失的瞬态。一次观察不等于长期稳定性验证。
- 但这**不等于正文越过clip进入日期区域**。记录的正文scroll frame在content坐标：未锁`(0,86,270,111)`，锁后`(0,80,270,151)`；系统图还包含32pt标题栏，必须转换后比较。半行出现在正文视口顶边，现有记录没有日期本身frame或越界像素证明，任意滚动停在半行可能就是正常裁剪。旧“日期侵入/clip业务bug”的推测本轮**未被证实**，不能再加裁剪补丁。
- 锁后隐藏添加待办等未锁操作，视口从111高变151高、clip y520变480；尾字仍完整可见，正文不可编辑，解锁入口可见。解锁后视口回111高、clip仍y480，尾字暂时不在viewport；本轮未再滚动，不推导为不可达或新业务缺陷。

### 图标、范围与退出

探针从自身Bundle按与`Application.swift:26-28`相同表达式加载ICNS，image有效/512pt，资源hash与冻结build-06均为`156e472f14af0288d670694b589e6ed59e8f840c249e1877922ba0ffa996dea7`。这是独立探针Bundle加载证据，**不是正式ApplicationController启动或系统Dock外观通过**；没有新跑TC-021历史frame、管理器三栏、浅/深/空白或真人移缩/右键链，旧局部通过不抄成这轮新通过。

正常结束记录：`NSApp.run returned normally`、`normal-exit.txt`、wait退出0、两次ps查PID31011均不存在，项目pgrep为空；无强杀或残留实例。没有安装、权限变更、发布、Git、日常数据或向下委派。

**本轮诊断完成，整体验收仍不能PASS。** 最小后续优先由获准owner**只修聚焦测试**：全文排版后滚动/等一次正常事件轮，用转换后的真实clip严格包含最后字rect及字符校验，保留原失败和本轮新证据，再单独验正式GUI用户滚动；目前不支持第四次业务裁剪修复，也不需要用户改权限。日期半行真实但是否构成越界仍不确定；只有正式可见链证明越界/不可达，再申请最小业务修复。
