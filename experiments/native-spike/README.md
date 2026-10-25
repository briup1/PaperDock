# 一张便签：一次性 Mac 原生可行性实验

本目录是可丢弃的实验，不是正式 PaperDock 工程、可安装产品或第二份实施方案。只使用 AppKit / Foundation / CoreData / Darwin 系统框架；无第三方依赖、包管理器、Xcode安装、权限申请、系统设置修改、后台常驻或网络请求。正式需求/原型/方案保持只读。

## 本轮增量：靠近边缘探出（2026-10-24）

上一轮真人记录见 `/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/manual-evidence/user-01/manual-result.md`：用户已确认旧常显入口的拖出、中文IME、与浏览器切换时置顶/焦点、收纳找回、同目录重启保留正常；来源是用户反馈，不是程序回调或协调者逐字段屏幕核验。下面原始记录中的“未真人验证”保留为当时状态，不覆盖这份后续真人记录；**本轮新增hover仍等待新的真人检查**。

本轮只改 `main.swift` 和本README，新二进制/日志/隔离数据全部在 `hover-evidence/`；`Model.swift`、`spike.sh`、旧 `build/paperdock-spike`、manual-evidence和旧证据保持不动。因此旧 `spike.sh run` 默认仍指向旧常显版本；**本轮请使用下方明确的hover二进制命令，不要误跑旧二进制**。

```text
隐藏：屏幕右侧中段仅保留 2pt × 130pt 自有命中条
  → NSTrackingArea activeAlways 收到进入 → 向左探出24pt标签（不激活/不抢key）
  → 离开标签 → 收回2pt
  → 按住向左拖 → 忽略tracking exit、不提前缩窗
      ├─ 未过40pt松开：取消并收回
      └─ 超过40pt：仅触发一次既有便签显示/聚焦；继续拖不重复
          → 松开收回2pt → 之后再次靠近仍可唤出
```

隐藏不是零占用，也不声称整条屏幕边缘感应：常驻可接收事件的2pt宽自有窗口，按1%不透明度绘制极淡色命中面，窗口本身alphaValue保持1、保持ordered，不用alphaValue=0或orderOut。隐藏时**不会留下24pt透明拦截带**；2pt区域仍可能挡住底下应用的点击。展开才占24pt；只有主屏原130pt中段，不覆盖全屏高，不做多屏热插拔。主屏由启动时NSScreen确定。

窗口使用 `.nonactivatingPanel` 且不能成为key/main；进入/离开只缩放自身frame，**不调用激活或makeKey**。真正拖过阈值才沿原逻辑显示/激活便签。事件退出若仍在展开标签范围（旧tracking区域的迟到事件）会忽略；取消时鼠标仍压在2pt条上则需先离开再靠近，以免刚收回就再次探出。无全局监听、键鼠注入、权限申请或高频轮询；本轮自动化依旧直接调用自有NSView方法，不能证明窗口服务器真实交付hover、跨应用不抢焦点或真实拖动捕获。

### 新版本复跑与手动启动

```bash
# 可选：独立编译到新文件，防止改旧build或覆盖本轮已冻结二进制
swiftc -warnings-as-errors /Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/Model.swift /Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/main.swift -framework AppKit -framework CoreData -o /Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/hover-evidence/paperdock-hover-independent

# 只验hover状态机（新目录；约2秒，自动退出）
/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/hover-evidence/paperdock-hover --data-dir /Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/hover-evidence/review-hover-01 --auto hover

# 真人启动：新隔离数据目录，不动上轮user-01；需要协调者安排串行操作
/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/hover-evidence/paperdock-hover --data-dir /Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/hover-evidence/manual-hover-01
```

本机实测NSScreen frame为 `{{0,0},{1512,982}}`，visibleFrame为 `{{0,0},{1512,949}}`：**隐藏命中区 x=1510…1512、y≈409…539（AppKit从左下向上）；展开区 x=1488…1512、同一高度**。等价屏幕从顶向下约443…573pt，即右侧中段；Retina物理像素为2倍。坐标可能有0.5pt对齐，运行时 `edge-window` / `edge-phase` 日志给出当前frame，不硬编码此数值作布局。

真人请先将鼠标移离边缘，再贴近上述2pt条：观察探出；移到左方或上下方观察收回；再进入按住拖，拖过40pt创建/找回便签后松手，标签应隐藏；再次靠近还能用；未过阈值松手不应新建/弹便签。请同时在浏览器编辑时靠近/离开验证不抢焦点。首次启动仍会像旧实验那样显示演示窗口并激活应用，这与**hover本身不激活**不同，不将启动行为算作hover抢焦点。退出用菜单栏或⌘Q，不把收纳当退出。

### 本轮实际证据与冻结

- `hover-evidence/build.log`：实际swiftc warnings-as-errors编译成功。
- `hover-evidence/hover-check-01/events.jsonl`：程序驱动进入/离开/展开区迟到exit、拖动中exit、低于阈值取消、不移动取消、两次重新进入拖动、重复drag只触发一次、完成收回均通过；检查窗口始终非key，hover前后自身key/active未变化。真实跨应用不抢焦点还需真人。
- `hover-evidence/note-regression-01/events.jsonl`：只复跑直接相关旧链路seed/read-fixed/read-random，入口改为hover后原可见/key/中文/待办/收纳/配色/重启读回通过；正文/保存实现与Model.swift未变。
- `hover-evidence/invalid-mode-01/events.jsonl`、`hover-evidence/exit-codes.txt`：故意无效auto返回1，正向hover/回归返回0，没有恢复旧假PASS问题。
- `hover-evidence/baseline-unchanged.sha256`：Model.swift、spike.sh、旧build二进制前后hash相同；旧用户数据没有打开或写入。
- `hover-evidence/SHA256SUMS`：新源码、README、未改Model.swift与本轮二进制冻结hash。
- `hover-evidence/process-exit.txt`：本轮自有PID 29458、30071、30156、30220、30311均已正常退出并以ps核实不存在，不留后台实例。

自动化没有真人输入、系统鼠标投递或屏幕截图，本轮只可称**hover状态机programmatic通过**，不声称新增靠近体验已真人验收。特别是1%命中面在当前系统跨应用的真实hover送达、边缘与Dock/其他浮窗竞争、真实按住拖时的事件捕获，留给本轮真人；多屏/Space等仍非本轮目标。

## 原始环境与实际运行（常显入口基线，以下保留历史）

2026-10-24 本机：macOS 26.5.1 (25F80)、arm64、Swift 6.3.3、Command Line Tools (`/Library/Developer/CommandLineTools`)；无完整 Xcode。`EnvironmentProbe.swift` 已实际编译运行导入 AppKit/CoreData；最终代码用 `swiftc -warnings-as-errors` 编译通过。只证明本机，不证明 macOS 15、Intel、其他系统版本或沙盒/签名/商店分发。

实际链路：

```text
NSStatusItem 菜单入口 / NSScreen 右边缘自有小窗口
  → 向左拖动回调超过 40pt → 这一张浮动便签
  → NSTextView 编辑中文字符串、手动标题、一条可勾选待办
  → 关闭收纳 / 菜单找回、程序移动缩放
  → 单张纸色 / 以后固定 / 加入随机（去重）/ 切回原随机池
  → CoreData SQLite 保存整个状态 → 正常退出 → 新进程读回
```

实验故意只有一张便签；菜单上的“新建/找回”首次创建，以后找回同一张，不代表多条记录管理器。只有一条待办，自动标题仅从正文取值、没有拼接待办；六种实验色值不等于已批准网页六色；只验证颜色可以绘制、随机/固定可以保存，不是产品色板或完整标题/待办规则实现。没有完整管理/搜索/分组/回收站、最终选色草稿事务、成品样式或全局快捷键。本轮不扩展这些业务。

## 独立复跑命令

以下示例的 `review-*` 目录必须尚不存在；换目录名即可再跑，不覆盖前轮输出。所有数据参数要求本目录下的绝对路径，越界拒绝；同一数据目录重复写实例会被锁拒绝。实现者不写 `review-evidence/`，独立审查者可将新数据路径设在它的子目录。

```bash
# 编译；仅依赖当前已安装的 swiftc / macOS SDK
/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/spike.sh build

# 模型与 CoreData 聚焦检查（新目录，不开 GUI）
/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/spike.sh check /Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/review-evidence/review-model-01

# 三个串行、前台 AppKit 进程；约 6 秒，自行保存/退出；新目录
/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/spike.sh auto /Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/review-evidence/review-gui-01

# 可供人操作的自有窗口（新目录或已有目录）；不是后台服务
/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/spike.sh run /Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/review-evidence/review-manual-01
```

手动模式请本人：从屏幕右侧青色入口向左拖 → 输入法输入中文 → 勾选待办 → 关闭便签 → 菜单栏“纸·实验”找回 → 用 ⌘Q 或“退出实验”退出 → 对同一目录再次 run。没有请求人操作的回执时，不把这些步骤写成已执行。若出现系统权限对话框，停止并交协调者，勿修改权限。运行期间会短暂激活本任务应用，独立审查需串行使用GUI，不与其他测试争焦点。

退出码：build/check/auto 正常为 0；模型、GUI断言、保存或证据写入失败为非0；外层脚本使用 `set -e`，任一进程失败即停止。`run` 在退出前保存失败会拒绝退出并显示错误，避免悄悄丢弃；不承诺异常退出零丢失或保存时限。日志中 `PASS-*` 与退出码必须一起看，不能仅看脚本末尾文字。

## 证据索引与观察

以下全部在 `/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/` 下：

| 目的 | 证据 | 实际观察与边界 |
|---|---|---|
| 编译环境 | `evidence/environment.txt`、`evidence/build-final.log` | 框架探针实际运行；最终 warnings-as-errors build 成功；不是GUI验收 |
| 模型检查 | `evidence/model-02.log` | 中文前5可见字符、Swift Character组合字符、手动标题不被覆盖、固定/随机成员、CoreData往返、无效保存保留旧值、重复writer拒绝；Model.swift未在此后变化 |
| 最终AppKit链路 | `evidence/gui-final-02.stdout.log`、`evidence/gui-final-02/events.jsonl` | seed/read-fixed/read-random 三个不同PID实际运行，最终日志无FAIL、三个exit failed=false；stderr为空 |
| 可见/焦点 | 同上 `focus-observed` | 实际 NSWindow可见、应用active、key=true、firstResponderIsBody=true；等待真实主runloop最多2秒，不把visible直接当key |
| 真实边缘 | 同上 `screen`、`edge-window`、`edge-drag-created` | 本机屏幕frame `{{0,0},{1512,982}}`，visibleFrame高949、scale=2；入口右缘1512来自NSScreen，不是网页坐标；事件点1500→1308由自有NSView回调处理 |
| 普通窗口置顶 | 同上 `window-order` | 便签level=3、普通演示窗口level=0；演示窗口orderFront后本应用orderedWindows中便签仍在前；非跨应用实际遮挡或Space证明 |
| 中文与待办 | 同上断言 | NSTextView.insertText中文+emoji触发delegate并保存，自动标题“明天联系客”；手动标题“实验便签”，待办“核对报价”target/action完成→重启读完成→取消完成→第三进程读未完成；不是输入法组合输入 |
| 收纳与恢复 | 同上断言 | performClose隐藏而不销毁，找回内容不变；第二进程退出前收纳，第三进程不擅自显示，显式恢复后再收纳 |
| 颜色与重启 | 同上断言 | 单张#DDE8D5；#ABCDEF去重入池；切固定不重染旧便签；第二进程读回固定/池，切随机，第三进程读随机和池；移动/收纳/颜色不更新内容修改时间 |
| 内容绘制 | `evidence/gui-final-02/note-programmatic.png`、`restart-programmatic.png` | NSView.cacheDisplay生成自身内容位图，已实际打开检查：中文/emoji、待办勾选、纸色、配色控件可读；不是系统屏幕截图、窗口外观/遮挡/人操作证明，没有可信视觉基准，不宣称成品视觉验收通过 |
| 错误不覆盖 | `evidence/error-path-check.log`、`corrupt-store.stderr.log`、`outside-path.stderr.log` | 人为无效SQLite启动返回1；旧文件SHA256前后同为8fd6943e0e779666fbe53ed2756e789c7ecc7c8b581442005e0cdca229354837；目录越界返回1；不删除/重建坏库，不自动迁移 |
| GUI失败正确返回 | `evidence/exit-code-check.log`、`gui-invalid-mode.stdout.log` | 人为无效auto模式记录FAIL并返回1，防止NSApplication终止吞掉断言退出码 |
| 冻结与清理 | `evidence/SHA256SUMS`、`evidence/process-exit.txt` | 源码/脚本/二进制hash与自身PID退出检查；不触碰其他进程 |

最终运行PID：48283（seed）、48357（read-fixed）、48448（read-random）；另有退出码反向检查PID见日志。每个进程日志明确正常收尾、自身窗口orderOut、移除自身状态栏项目；结束检查这些PID已不存在。没有安装或留下启动项。

### 失败历史保留，不以旧PASS替代最终证据

`gui-01` / `gui-02` 是早期实验记录。`gui-final` 曾出现“窗口可见但立即检查不是key”的焦点时序失败；同时发现 `NSApplication.terminate` 在 `app.run()` 返回前自行结束，原本尾部exit不能表达断言失败，导致旧脚本末尾出现误导PASS。它们**不是最终通过依据**，原始日志保留便于审查。

最小修复：给激活事件最多2秒真实runloop处理时间，分别记录visible/key/firstResponder；在applicationWillTerminate传回真实失败退出码。修复后 `gui-final-02` 全链路通过，另用invalid auto模式确认失败码1。一次最终通过不等于长期焦点稳定；外部应用抢焦点时允许检查失败，不伪造焦点或注入系统事件。

## 权限边界：查证与未验

当前SDK公开头文件 `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Headers/NSEvent.h` 538–550行说明：global monitor仅异步观察投递给其他应用的事件，不能更改/拦截，且不接收自己应用事件；键盘相关监视需要辅助功能已启用/应用受信任。local monitor只接收自身sendEvent分发，不包含所有嵌套tracking loop。

本实验没有安装global/local monitor，没有 `System Events`、CGEvent全局注入、辅助功能或屏幕录制权限探测/申请。采用可见的24pt宽、约130pt高自有屏幕边缘窗口直接收mouseDown/Dragged；不是“无形全屏边缘悬停触发”的完成证据。鼠标global monitor在当前系统的跨应用实际送达、权限提示及所有系统限制均**未实测**；头文件不能证明这些行为，无需为本实验取得权限。

**所有自动GUI结果类别为programmatic**：事件对象直接交给自有NSView、文本通过NSTextView.insertText、checkbox通过performClick；未使用OS级系统输入，所以不证明真人拖动、鼠标捕获跨边界、真实中文输入法候选/marked text。真人输入、真正跨应用置顶/遮挡、多个屏幕及负坐标、外接屏重连、全屏/Space/Stage Manager、边缘与Dock冲突、全局监听权限、最低系统版本仍待人工或后续批准验证。若需要这类证据，由协调者安排人操作，不绕过权限。

## 存储实验的适用范围

继续用CoreData是因为本机公开框架已实际编译且SQLite保存/新进程恢复通过，不需要换候选或引入第三方。实验以一个Snapshot实体的binary payload保存完整一张便签与设置；这是验证系统框架可用、事务保存与退出读回的轻量样本，不代表最终查询/索引/实体设计或数据库性能结论。

模型校验失败、SQLite打不开、同目录writer冲突均显式失败；不把加载失败当空数据覆盖。只有指定项目子目录的notes.sqlite、instance.lock、events.jsonl和自有位图等实验输出被创建。正常保存每次调用CoreData context.save，退出再次保存；没有 crash/fault注入、磁盘满、文件系统掉电或迁移演练。模型文件变化时用新目录复跑，不迁移历史实验库。

**原始实验结论**：当前CLT足以编译运行一张真实AppKit便签和CoreData隔离保存/正常重启链路，公开API路线无需本轮申请系统权限。真人边缘拖动/中文IME及跨应用窗口行为未证实，不能把programmatic通过升级成正式产品或所有原生交互已验。
