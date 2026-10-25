# PaperDock 原生阶段准备审查

## 第一波：产品规则与用例静态审查

审查时间：2026-10-24。身份：独立产品/验证审查者，未参与原生实验实现。本波只读需求、用例与必要原型，没有打开浏览器、运行原生应用、执行用例或审查原生代码；下文的“覆盖”仅指步骤是否足够证明规则，不是测试通过。

### 审查基线与批准边界

- 阶段范围：[native-phase-scope.md](/Users/ziyun/workdir/self_project/PaperDock/docs/native-phase-scope.md)，以“批准与授权来源”“最小验证场景”为当前授权依据。
- 需求：[requirement.wl-req-confirm.md](/Users/ziyun/workdir/self_project/PaperDock/docs/requirements/0001-local-notes/requirement.wl-req-confirm.md)，v0.2；审查末次读取已增加“本轮确认与阶段推进”，status=approved、execution_phase=designing。
- 用例：[test-cases.wl-qa-test-planner.md](/Users/ziyun/workdir/self_project/PaperDock/docs/requirements/0001-local-notes/test-cases.wl-qa-test-planner.md)，v0.2、status=reviewing，TC-001～TC-014。
- 必要原型：[paperdock.prototype.html](/Users/ziyun/workdir/self_project/PaperDock/prototype/paperdock.prototype.html)；实核 SHA256 为 `dcb9c817a7be1cfe7aee6d2d669c1c174fb293673320e3a562cd005c7d78350a`，与阶段范围一致。只用于理解当前界面、自动标题、可见/收纳与颜色入口，不作代码质量或运行正确性结论。

用户已明确接受“原型与交互没问题”，并同意本轮方案及最小原生验证。关闭即收纳、删除与恢复、标题和待办行为、六色及随机/固定规则不需要再逐项征询。A/B/C 未明确选款，只影响最终外观选择，不阻塞系统能力实验。异常退出零丢失与保存时限尚未定义，不追加这类验收承诺；本轮仍不授权完整正式产品开发。

### 本次审查沿用的场景

```text
从屏幕边缘拖出一张合成便签
  → 写“本地保存样本Z731”、命名“本地样本”、添加待办
  → 单张换色；设置以后固定或随机池（不重染旧便签）
  → 切到本任务普通演示窗口：便签仍可见，输入焦点与可见性分开观察
  → 收纳后显式找回：同一张，不重复新建
  → 正常退出本任务应用，确认退出后重开
  → 对照退出前正文/标题/待办/单张色/新建模式/随机池
```

下面只列影响这一链路或已确认规则证明能力的实际缺口。建议步骤交给协调者原位补入用例，本报告不维护第二套完整用例。

## 必须补齐的最小缺口

### G1：正常退出恢复只检查三类内容，无法证明纸色和未来新建设置保留

**依据**：阶段范围“最小验证场景”要求重开读回标题、正文、待办、纸色与随机固定设置；需求 R01、P08、P02；用例 TC-014/2 只检查正文、手动标题和一条未完成待办。TC-009 的模式/池检查仅在网页内存中完成，不能补足退出后的检查。

**影响**：便签内容保留但纸色回到默认、随机池丢失，或者固定模式重开变随机，都可能被现有 TC-014 误判为通过。

**最小补法**：在 TC-014 增加退出前快照和两个连续的正常重开分支，不增加异常退出或大批量随机采样：

1. 沿用“本地样本”，给正文、手动标题、单张色 C2=`#2468AC` 及待办建立退出前对照；至少一条待办完成、一条未完成，以便分辨是否只保存文字而漏掉完成状态。
2. 已将 C2 加入随机池后，将未来新建固定为 C1=`#ABCDEF`，不手动保存，正常退出并确认自身进程已退出，再打开同一隔离数据目录。读回同一便签的内容、待办文本/完成状态和单张 C2；设置仍固定 C1，池仍为内置六色＋C2。再新建一张应使用 C1，不能重染原便签。
3. 切回保留 C2 的七色随机池，再正常退出重开。设置仍为随机且池成员相同、不重复；新建颜色只要求属于该池，不要求碰巧抽到 C2或相邻不同。

正式用例可创建必要记录；本轮一张便签实验可分支重置隔离样本复跑，不要求为补证据扩成管理器。实验没有提供的操作必须标未验，不能用网页结果代替。

**阻断判断**：不阻断编写方案或启动已获准的最小实验；阻断“正常退出恢复范围已证实”的结论。应在正式开发计划采用该验收基线前补齐；实际正式开发另需方案批准。

### G2：原生窗口可见、输入焦点、边缘触发和收纳混在一个宽泛预期里

**依据**：需求 R02、D01/D07；阶段范围明确包含边缘拖出、普通窗口置顶/焦点、移动缩放、收纳找回。TC-001/4 只有“切到普通应用窗口，便签可见且可编辑”；TC-010/1～3 是网页模拟，没有原生对应操作。当前没有步骤区分“仍置顶但未获焦点”和“被收纳”，也没有明确证明边缘拖出只产生一张。

**影响**：便签强抢焦点、切换普通窗口后实际消失、边缘点击/拖拽各生成一次、关闭后仍留下窗口，都可能只凭单张截图漏检。后台可见不等于应继续接收键盘输入，“可编辑”需要回点便签后才能判定。

**最小补法**：在 TC-001/4 和 TC-010 增加原生分支，沿用同一张便签和本任务普通演示窗口：

1. 从已说明的屏幕边缘唤出并完成一次拖拽；记录便签数量/身份，预期只新增一张。菜单栏备用新建与边缘拖出分开记录，不能仅菜单新建成功就报边缘成功。
2. 将普通演示窗口与便签部分重叠，主动点击演示窗口并输入合成文字；便签仍在其上方可见，键盘输入应属于演示窗口。再点击便签正文输入另一段文字，应写入同一便签，不把可见性当成焦点归属。
3. 移动、缩放一次，核对内容仍可见且可继续编辑；不强行追加窗口位置/尺寸跨重启保留承诺。
4. 点便签关闭按钮后，确认它从桌面消失，但仍可经已提供入口找回同一记录；不是删除、退出应用或重复新建。切走焦点、指针离开边缘与显式关闭分别观察，不能混写成“隐藏”。
5. TC-014 的正常退出分支至少覆盖一次退出前已收纳的样本：重开不擅自把它当成新建便签显示，显式找回仍是原记录。若实现尚未给出重开时可见/收纳状态规则，方案必须明确这一点，不从窗口是否有焦点推断保存状态。

**阻断判断**：不阻断方案编写或最小实验；阻断“边缘、置顶/焦点、收纳链路均已验证”的结论。正式验收前必须有真实原生入口及以上可观察结果；本轮无公开自动化/人工操作证据的部分应标未验，不授予系统权限补测。

### G3：最新授权已补入需求，但用例仍把已接受目标写成待批准；原型用例也没有正式验收迁移口径

**依据**：需求“本轮确认与阶段推进”与阶段范围已接受自动保存/正常重开目标，TC-014/1、覆盖表 P08 却仍要求先评审该目标。需求 P03/P04/Q01/Q06 已接受现有行为，但 TC-004/2、TC-006/5、TC-010/3 仍写“由 Q02 批准”“由 Q04 确认”；覆盖表将触发动作、待办等列为建议。需求正文也保留旧 P08 待评审字样，但已在最新阶段节声明优先级。用例公共准备仍是“每条刷新重置、只操作内存示例”，TC-001/4 与 TC-014 却是原生操作。

**影响**：这不是发现用户尚未确认，而是执行材料的历史状态没收口。执行者可能重复追问已接受规则，或把网页完成的标题/搜索/颜色用例计作原生产品通过；若机械套用公共准备，还会在保存检查前重置样本。

**最小补法**：

- 用例开头同步当前阶段：产品目标已批准，独立用例审查与原生实验仍各自记录，正式产品开发未获准。TC-014/1 改为需要“当前阶段已授权的原生实验入口/正式验收入口＋隔离目录”，不再要求重批 P08；实验入口只能证明所覆盖的能力，不冒充正式产品入口。
- 把上述旧“待批准/确认”句和覆盖表对应项改成已接受规则的确定预期，保留未执行标记；关闭、待办、日期等不另拉一轮确认。异常恢复和 A/B/C 未选款仍保留真正的边界。
- 原型公共准备明确只适用于原型步骤。TC-001 原生分支、TC-010 原生分支及 TC-014 使用独立数据目录与明确退出/重开步骤，不刷新网页、不重置待读回样本。正式开发后将已接受的产品用例映射到正式入口重跑；本轮最小实验不必实现全文搜索/完整管理器来获得一份“全绿”报告。

**阻断判断**：不阻断设计与最小实验，当前最新阶段文本足够确定授权；阻断把 v0.2 原样作为无歧义正式执行基线，也不能据此声称用户批准缺失。协调者最小同步即可，无须再问用户。

### G4：两个已接受规则缺少能判定的测试数据/独立动作

**依据与最小补法**：

- **自动标题可见字符**：需求 R03/Q01，TC-003/4 写“仅待办、含组合表情”却没有具体输入和确切标题。补独立分支：清空手动标题及其他内容，只留待办“发送报价”，预期标题“发送报价”；另一分支无待办、正文为 `👨‍👩‍👧‍👦甲乙丙丁戊`，预期标题 `👨‍👩‍👧‍👦甲乙丙丁`。既有空白/换行分支明确预期“明天联系客”。不用再设计一组 Unicode 功能大全。
- **待办操作更新时间**：需求 P03，TC-006/5 只有“新增待办”可证明迁到今天，并承认缺历史待办；TC-006/3 在今天内完成/撤销，看不出这两步是否各自更新时间。最小提供隔离历史样本（D-1、同一待办），分别独立执行改文字、完成、取消完成、移除；每个动作前恢复 D-1 对照，预期单次动作即更新为今天。不要先新增再勾选后只检查最终日期，也无需修改系统时钟。若原生实验无相关入口，此项留正式验收，不逼实验增加完整日期分组界面。

**阻断判断**：不阻断设计和最小原生实验；阻断这两项正式规则的“完整覆盖/已验证”结论。属于已有规则的最小补证，不是新增功能或新增产品决策。

## 未发现需要追加的问题

- TC-009 对默认六色随机、允许重复、固定、只改单张、去重入池并切随机、切回已有池、取消/关闭/Escape、旧便签不重染，已给出可观察步骤；不要求随机一定抽到某色，不凑统计测试。缺的是 G1 的跨退出保留，不是把同页颜色流程推倒重写。
- TC-005 已覆盖标题、正文后段、收纳检索，以及搜索中继续编辑不串写；不以当前没有原生管理器为由要求最小实验补完整管理功能。
- TC-010/011 已表达关闭收纳与删除回收站的产品区别；问题在 G2 的原生证明与 G3 的旧确认措辞，不是需要用户重选关闭行为。
- 原型/原生证据边界在需求、用例开头、TC-001/4、TC-013、TC-014 已明确，未发现直接把浏览器叠层宣称为系统置顶的断言。应保持这一边界，并补 G3 的分阶段执行口径。
- A/B/C、多显示器、全屏/Space、真实中文输入法、最低系统版本与异常退出恢复均不借本波扩成阻断实验的新增范围；没有证据的能力如实列未验。

## 第一波交接结论

已确认的产品规则足以继续方案与最小原生实验，没有需要再向用户追问关闭/颜色等决策的缺口；现有用例仍需补 G1～G4，才能作为正式、可判定且不混淆证据的执行基线。这是文档静态审查完成，不是原型或原生测试通过，也不代替方案批准后的正式开发授权。

第一波结束时第二波尚未开始；以下第二波在工程师冻结并退出自身应用后按新派单执行。保留上文为v0.2历史审查，不把当时缺口误认为v0.3仍全部未解决。

## 第二波：冻结实现、原生证据与 v0.3 用例复核

审查时间：2026-10-24。工程师任务已完成且自身实例退出后入场；独立读取 Model.swift、main.swift、spike.sh 及最终/失败历史证据，未改实现、方案、需求或用例。无 .codegraph 目录。本波只审一次性原生实验，不按完整产品功能要求它实现搜索/管理器。

### 1. 冻结一致性与实际执行

根目录为 `/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/`。审查前后核对源码及原二进制，均与工程师 `evidence/SHA256SUMS` 一致：

- `main.swift`：`1ad5d89141b98f54cdea908fc55aa5f6515b1fce80a6ef231409a9b43bf7b23b`，吻合派单冻结值。
- `Model.swift`：`3ba96d557ec371211f164f0ca9f11e39349ff2e4a33d36e9712ae264eb651e26`。
- `spike.sh`：`29e07dc1db32cac1e5e5b9a19fc9fad1b842722a943e6568f1fb913474d71e78`。
- 原 `build/paperdock-spike`：`406059b4bb316b8725481f8137caaa559d25bfbf63f65ba98a818b40ea5584e4`。

未运行会改原 build/ 的 build 命令；审查后将同一 swiftc 编译命令的输出改到本轮证据目录，编译返回0、stderr空，不动冻结产物。所有独立数据都新建在 [review-evidence](/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/review-evidence/)，未复用工程师数据库。

完整实际命令见 [commands.md](/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/review-evidence/commands.md)，实际退出码见 [exit-codes.txt](/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/review-evidence/exit-codes.txt)：

| 独立操作 | 数据子目录/输入 | 退出码与结果 |
|---|---|---|
| README `spike.sh check` | `review-model-01` | 0；模型标题/字素、固定/随机成员、CoreData往返、无效保存不覆盖、重复writer拒绝断言成立 |
| README `spike.sh auto` | `review-gui-01` | 0；seed/read-fixed/read-random三个不同PID串行退出，stderr空、无FAIL |
| 二进制 `--auto invalid` | `review-invalid-auto-01` | 1；真实走GUI失败/终止路径，failed=true，不因NSApplication终止而假成功 |
| 再次 `spike.sh auto` 同目录 | 已存在 `review-gui-01` | 2；明确拒绝复用，未覆盖成功数据 |
| 同源 `swiftc -warnings-as-errors` | 输出 `review-paperdock-spike` | 0；无完整Xcode、未安装工具、未改全局开发目录 |
| `spike.sh auto` 无法创建数据目录 | `not-a-directory/child`，父为本轮合成普通文件 | 1；首进程失败即停止，无后续读回或末尾PASS，证明外层脚本传播失败 |
| 独立编译产物 `--check` 合成坏库 | `review-corrupt-01/notes.sqlite` | 1；坏库前后SHA256相同，cmp=0，未当空库重建覆盖 |
| Python标准库只读SQLite与定向PID核对 | `review-gui-01/notes.sqlite` | 0；直接解析持久化payload并核对内容，不只相信程序PASS日志 |

### 2. 实际可证明的链路及限制

```text
NSScreen真实坐标 → 自有边缘NSView的程序回调
  → AppKit浮动便签（visible/key/firstResponder分别观测）
  → NSTextView.insertText与控件target/action → CoreData SQLite
  → 自身正常退出 → 第二进程读固定配置和已完成待办
  → 切随机/撤销完成/收纳 → 第三进程读回并显式找回
```

- 本次主屏为1512×982、scale=2；入口窗口在屏幕右侧。自造 NSEvent 直接送给 EdgeView，证明坐标转换及回调能创建/找回窗口，**不证明真人拖拽、系统鼠标捕获、指针离开边缘的行为**。
- 有界真实runloop等待后，记录到 active=true、visible=true、key=true、firstResponderIsBody=true；不是将isVisible当焦点。此处只证明本次激活观测成功，未执行 TC-001/4.2 的点击普通窗口并输入，再回点便签的焦点归属链路。
- `demo.orderFrontRegardless()` 与浮动level=3、普通level=0、同进程orderedWindows顺序被断言；demo是同一SpikeApp里的NSWindow，**不是其他进程的普通应用，也不是系统屏幕遮挡实拍**。跨应用置顶/失焦后行为仍未验。
- NSTextView通过 `insertText` 输入中文与组合表情，delegate保存；待办通过 `performClick` 完成/取消完成，标题/待办文本通过控件赋值与通知回调。**不证明真实中文IME候选、marked text或真人键盘路径**。
- 三进程实际读回同一SQLite中的手动标题、正文、待办文本/先完成后未完成、单张纸色、固定/随机模式、七色去重池；第三进程启动时保持收纳，显式找回后再次收纳。独立用sqlite3只读取得1行payload，最终正文为“明天联系客户确认报价🇨🇳👩🏽‍💻”、手动标题“实验便签”、待办“核对报价”、done=false、paper=#DDE8D5、mode=random、visible=false、pool包含一次#ABCDEF，共七项，吻合事件记录。
- 移动缩放、关闭/找回、换色未改内容修改时间的程序断言成立。实验只有一张、一个待办，没有稳定记录ID、多张同存、两条不同状态待办、完整前五字标题规则或全文检索；不能说 TC-014 v0.3 已完整执行。固定后新建颜色只测 `nextPaper()`，不是创建第二张产品便签。
- 已实际查看本轮 `review-gui-01/note-programmatic.png` 和 `restart-programmatic.png`：400×440pt自身内容位图（800×880像素），标题/中文emoji/待办勾选/纸色控件可读，未见该样本内容裁切。这是 `cacheDisplay` 自有视图绘制，**不是系统截图、窗口遮挡或最终产品视觉验收**；无可信成品视觉基准。

自动保存和退出保存确实调用CoreData `context.save()`；GUI每次保存失败设failed，手动退出保存失败会取消退出，程序终止最终传回非零。Model.swift:90–107 的加载/校验失败向外抛出，保存先校验、context失败rollback，不会将解码失败当空数据。独立坏库与模型invalid-save检查支持这些有限结论；没有做磁盘满/掉电/迁移或异常退出恢复实验，不外推零丢失。

工程师 `evidence/gui-final.stdout.log` 确有焦点失败、后续缺expected.json，却仍出现末尾PASS；它不作为成功证据。有效的 `gui-final-02` 无FAIL，本次全新目录复跑也通过，同时invalid模式返回1；这修复了错误信号，但两次有限运行仍不是焦点长期稳定性保证。相关独立提取见 `review-evidence/owner-evidence-audit.json`。

### 3. 实现缺陷与方案推荐判断

本波未发现阻断**本轮最小可行性结论**的实现缺陷，也没有需为实验扩展的规范问题。实验明确声明的单记录快照、单待办、颜色/标题简化不伪装成正式规则实现，不据此报成产品回归；正式产品不能直接照搬这些简化。

在已验证范围内，AppKit窗口/状态栏、NSTextView编辑和CoreData保存/重启路线有真实编译运行证据，足以作为方案推荐的依据。**SwiftUI没有被这个实验导入、构建或与AppKit桥接运行**，因此“SwiftUI管理界面＋AppKit窗口＋NSTextView＋CoreData”可作为下一步设计推荐，但SwiftUI承载/桥接属于建议，不是本波已证实能力；无需为此把一次性实验扩成完整产品。

方案应明确真人边缘拖动/IME、真正跨应用焦点和遮挡、多个屏幕负坐标/断连、全屏/Space/Stage Manager、Dock冲突、最低系统版本、签名沙盒/分发均未验。自有可见边缘窗口无需本轮系统权限，并不证明隐形全屏监听能力；没有权限申请/系统全局键鼠操作，不应为补齐结论绕过权限。上述未验不阻断方案推荐，但不能据此宣称正式交互全部验收通过。

### 4. v0.3 对 G1–G4 的复核与剩余最小文档反馈

已核对需求/用例MD v0.3及生成HTML包含新增关键语句，HTML静态同步不算执行通过。

- **G1 步骤已解决**：TC-014/1–5加入独立目录、退出前内容/ID/日期/两种待办状态、C2单张色、C1固定、七色池、退出后仍收纳、显式找回及再切随机重启。两次正常重启预期可判定；本次实验仅提供它的部分programmatic证据，不填完整通过。
- **G2 步骤已解决**：TC-001/4.1–4.4已分别写边缘唯一新增、普通窗口输入归属、回点便签、移动缩放与失焦不收纳；TC-010/4有原生关闭/同一记录找回，TC-014/3有收纳重开。这些步骤不因程序化事件通过就变成人工通过。
- **G3 核心已解决，仍有历史正文需最小收口**：用例公共准备分成原型/原生、正常保存不再要求重批P08；主要标题/待办/关闭步骤改成已确认。剩下直接行段见下方，不向用户重新征询。
- **G4 字符分支已解决；日期分支漏了原先的新增操作**：TC-003/4已有确定输入及精确自动标题。TC-006/5把改文字/完成/取消/移除分成D-1独立样本，但替换旧步骤时丢了“在D-1只新增待办”的原有日期检查；TC-006/2是在今天客户示例上新增，不能证明新增更新时间。仅需恢复一个独立新增分支，无需扩展实验。

以下均交协调者原位修正文与同源HTML，**不阻断方案或本轮实验结论，未全部修前不称正式用例基线已无歧义**：

1. [test-cases.wl-qa-test-planner.md](/Users/ziyun/workdir/self_project/PaperDock/docs/requirements/0001-local-notes/test-cases.wl-qa-test-planner.md):202–212（TC-006/5）补“D-1正文便签、无待办 → 只新增待办‘明日复核’ → 单次新增即迁今天、正文保留”；覆盖表:443的“每个动作日期策略”才名实一致。这是补回丢失覆盖，不是新规则。
2. 同文件:340（TC-011场景）仍写“只在用户评审建议时检查”，与已确认步骤矛盾；改为直接检查删除/收纳区别，不能把已批准行为变成待批准。:231“二维色盘与色相条形式仍待评审”可改为“原型形态已接受，正式成品布局尚待方案批准”；不重开选色方式决策。
3. [requirement.wl-req-confirm.md](/Users/ziyun/workdir/self_project/PaperDock/docs/requirements/0001-local-notes/requirement.wl-req-confirm.md):53、154仍称用例v0.2/同步版本0.2，应改v0.3；:49“本轮仅交付产品确认资料，不决定技术实现”应标为历史阶段或改成当前方案/实验阶段。开头已声明最新阶段优先，故不视作授权缺失，但不应让读者再自行消歧。来源索引历史原话可保留，不要求删除证据。

### 5. 本次实例清理与交接

本轮GUI PID为54234（seed）、54284（read-fixed）、54329（read-random）、54398（invalid反向检查）。四个均走自身NSApplication终止路径，记录移除自身状态栏项并隐藏自身窗口；定向 `ps -p` 结果均不存在，最终复核见 `review-evidence/process-exit.txt`。没有启动手动常驻实例、没有对其他进程发送kill、没有浏览器实例或系统权限变更。

**第二波结论**：独立复跑确认了冻结实验在本机的AppKit程序化窗口/编辑/收纳与CoreData正常重启链路，失败退出码和坏库不覆盖检查也成立；可据此继续一份最小实施方案，不需要扩大实验。原生真人交互/跨应用等仍未验，v0.3补齐了主要证明步骤但剩上述最小文档修正，正式完整产品开发仍需方案批准。

## 最终文档复核（2026-10-24）

本次仅静态读取 [design.wl-design-doc.html](/Users/ziyun/workdir/self_project/PaperDock/docs/requirements/0001-local-notes/design.wl-design-doc.html)、上轮列出的需求/用例修正段与同源HTML；未重跑实验、未启动GUI/浏览器、未修改任何其他文件，不重审全部历史材料。

### G1–G4 文档残余已闭合

- TC-006/5.0已补D-1无待办正文便签只新增“明日复核”，预期单次新增即迁今天、正文保留；后续分支各自重置历史样本。新增操作的日期覆盖已恢复。
- TC-007/1已明确“原型色盘形态已接受，正式成品布局仍待方案批准”；TC-011场景已改为检查已确认删除、收纳、恢复区别，不再要求用户重批。
- 需求重定义段已同步当前方案/隔离实验阶段，正文用例链接及同步版本均改v0.3；上述文字在生成HTML中也实际存在。
- 联同第二波已核对的TC-001/4、TC-003/4、TC-010/4及TC-014/1–5，原G1–G4的**步骤与文档修正问题已闭合**。这不表示其对应的原生真人/完整产品用例已执行，不要求用户再确认已有产品规则。

### 方案证据身份一致，保持关键验证未完成

静态解析方案元数据：`status=draft`、`chosen=null`、`approval_evidence=null`、`critical_validation.status=partial`；pending明确真人边缘与靠近探出、中文IME、其他应用置顶/焦点。正文SEC01/02/04/06与第二波证据一致：

- 三个新进程及CoreData读回写为程序自驱；同进程演示叠层不冒充其他应用，中文字符串不冒充真实输入法。
- 常显边缘小窗口与最终靠近探出目标明确区分，程序化成功不自动批准完整实施；真人检查尚未执行。
- SwiftUI写为管理界面推荐而非实验已运行的框架；实验简化快照、单待办、无完整管理器不被包装为正式产品。
- 最低macOS15、全屏/多Space/多屏、异常退出零丢失等没有被写成已经证实的保证。A外观仍为推荐，不推断用户已经选中。
- 方案本地引用路径均存在。未做HTML浏览器视觉检查；即使HTML显示正常，也不能替代原生真人交互与系统行为验收。

### 仅余一处影响后续放行的最小澄清

[design.wl-design-doc.html](/Users/ziyun/workdir/self_project/PaperDock/docs/requirements/0001-local-notes/design.wl-design-doc.html) **SEC06“人工检查只需一张合成便签”段**描述使用当前实验常显标签拖动，可检查真人拖拽、IME和跨应用，但不能验证同页元数据pending的“靠近探出”。现有正文已声明不能将常显标签视为等价交付，故这不是已经越权批准；然而按该手动段全部做完，仍不足以自动进入“关键行为通过→批准完整实施”。

已通过Orca即时反馈协调者。最小增加一句即可：**“本次常显标签人工检查通过后，靠近探出仍未验；须在另获准的对应入口补证，或带差异请用户明确接受入口调整；此前保持partial/draft，不解除完整实施阻断。”** 不要求现在加功能或启动实验，也不要求重写方案。

协调者收到反馈后已作最小同步，本轮再次定点读取确认：SEC06明确“三项通过也不能证明靠近才探出”、须对应入口验证或用户接受差异，闭合前保持partial/draft；SEC01明确SwiftUI承载/桥接尚未实测，并链接已完成独立复跑。本项文档澄清已闭合，不再要求追加改动。

**最终静态复核结论**：原G1–G4残余文档及本次放行条件澄清均已闭合，方案准确保留程序实验与原生真人证据的区别，未发现将同进程叠层升级为跨应用成功或将未验标完成的断言。方案可按草稿交付；真人边缘/靠近探出、IME、跨应用仍未验，完整正式实施继续被关键未验及方案未批准阻断，本次静态复核不代替HTML视觉或原生验收。

## Hover 增量独立审查（2026-10-24）

本轮在工程师冻结hover实现并退出自身PID后执行，审查者未参与实现。仅检查 `experiments/native-spike/main.swift` 的边缘增量、README对应说明、既有hover程序证据，并独立编译/复跑；没有改实现、方案、原型、旧build或manual-evidence，没有重新执行历史完整审查。上一轮人工结果不扩张为本次hover已人工通过。

### 冻结对象与独立产物

审查前后实核：

- `main.swift` SHA256=`592d8f5da8d677f187e5ef2df44cd0dbfc90682e8c73a3a1b782504d29b37779`。
- 工程师 `hover-evidence/paperdock-hover` SHA256=`731de50aa8f99545e951783193f8047600c2dcfd0e96a29e175e563c66ab67e5`。
- 独立 `swiftc -warnings-as-errors Model.swift main.swift -framework AppKit -framework CoreData` 输出到本轮新目录的 `paperdock-hover-review`，SHA256=`18767626abe58563828a5d495f17637a4b136467847dd1925bc3f564eb169fa0`；编译返回0、stderr为空。二进制hash不必与工程师相同：本轮未覆盖其产物，实际分别执行了冻结产物和独立编译产物。

全部新增运行证据位于 [review-hover-20261024-01](/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/hover-evidence/review-hover-20261024-01/)。实际命令、PID及退出码见 [commands-results.json](/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/hover-evidence/review-hover-20261024-01/commands-results.json)，事件独立解析结果见 [audit.json](/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/hover-evidence/review-hover-20261024-01/audit.json)。`run-review.py` 记录本次一次性运行过程，不可原目录重跑覆盖本轮数据。

| 本次实际操作 | 新数据目录 | 实际结果 |
|---|---|---|
| 冻结 `hover-evidence/paperdock-hover --auto hover` | `review-hover-20261024-01/owner-hover` | 返回0；hover断言成立、无FAIL、exit.failed=false |
| 独立 `paperdock-hover-review --auto hover` | `review-hover-20261024-01/independent-hover` | 返回0；同一状态链成立、无FAIL、exit.failed=false |
| 独立 `paperdock-hover-review --auto invalid` | `review-hover-20261024-01/independent-invalid` | 返回1；明确FAIL与exit.failed=true，不把NSApplication终止当成功 |

三次GUI运行均串行自行终止、stderr为空。未执行 `spike.sh`，没有使用旧常显 `build/paperdock-spike` 冒充hover版本。

### 同一场景的源码追踪与独立观察

```text
右侧中段2pt×130pt自有窗口保持ordered、alphaValue=1
  → activeAlways tracking进入 → 展开为24pt，不激活/不抢key
  → 标签范围内的迟到exit忽略；真正离开 → 收回2pt
  → 按住拖动 → exit不收回，距离不足40pt不触发
      ├─ 松开取消 → 收回；仍压在2pt上需先离开再靠近
      └─ 达到40pt → 只显示/找回便签一次，后续drag忽略
          → 松开完成 → 收回 → 再靠近能重新触发下一次拖动
```

- `main.swift:24–26,39–45,177–189`：EdgePanel不能成为key/main，带 `.nonactivatingPanel`；tracking使用 `.mouseEnteredAndExited + .activeAlways + .inVisibleRect`，更新前移除旧area。隐藏时实际window宽2pt，不留下24pt透明拦截区；绘制面为1%不透明度，非零占用。范围仅启动时主屏中段，不外推全屏边缘或多屏。
- `main.swift:55–74`：进入/离开只更新phase与frame，没有激活或makeKey调用；收窄前用当前展开frame判断迟到exit。两份独立事件日志都先由2pt变24pt，再由24pt变2pt；所有edge-phase均key=false，自身key/active前后相等。启动仍有原有activate/demo.makeKey，拖过阈值仍沿既有restore激活便签，与单纯hover必须区分。
- `main.swift:75–97`：按下记录屏幕anchor；dragging/triggered时exit直接忽略；只有dragging且向左距离>=40才增加triggerCount并进入triggered。新日志每次按住拖只出现一个 `edge-drag-created`，两次完整拖动计数严格为 `[1,2]`，重复drag与triggered状态exit没有再次restore。
- 低于阈值松开后，程序断言便签数据与初始值相同；原地点击取消后不会立即重开，离开再进入可以展开；两次成功拖动松开均回到hidden/2pt，之后再次靠近能使用。上述分支在冻结产物和独立编译产物均成立。

工程师证据另经只读解析，提取见 [owner-evidence-audit.json](/Users/ziyun/workdir/self_project/PaperDock/experiments/native-spike/hover-evidence/review-hover-20261024-01/owner-evidence-audit.json)：hover-check-01无FAIL；note-regression-01确有hover/seed/read-fixed/read-random以及三个正常exit；invalid-mode-01确有FAIL且failed=true。其直接相关旧链路回归未因本轮重复审查而再跑，未用旧回归替代本轮新hover复跑。

### 证据边界、清理与交接

**未发现本次hover状态机的直接阻断缺陷或需扩大实验的规范问题。** 这里只能判为 **programmatic通过**：automation用自造NSEvent直接调用自有NSView方法，不能证明真实NSTrackingArea事件由窗口服务器送达、1%命中面跨应用可靠触发、真实按住拖时的鼠标捕获或外部应用键盘焦点不被影响。自有key/active保持的断言是在自身应用场景内，不是浏览器正在编辑时的独立实测。未做系统截图或视觉验收，不称hover可见体验已人工通过。

未注入系统键鼠、未请求/改变权限、未安装工具、未开浏览器或手动常驻实例。独立运行的GUI PID为37680、37757、37847，编译PID37653也已退出；各进程均已wait取得退出码并定向ps确认不存在，GUI日志记录自身窗口关闭/状态栏移除。最终定向退出核对见本轮 `process-exit.txt`。本轮前后对实验目录125个既有文件的SHA256清单完全一致（`protected-before.json` / `protected-after.json`），包括工程师二进制、旧build和manual-evidence，没有覆盖旧用户数据。

**Hover增量交接结论**：冻结版本及独立编译版本均复现了2pt隐藏→24pt探出→取消/单次触发→松开收回→再次唤出的程序状态链，失败退出码也独立成立，没有需交原owner修复的直接阻断。下一步仅由协调者安排新hover入口的真人靠近/离开、真实拖动与跨应用焦点检查；本轮不留实例、不等待用户操作，也不解除方案/正式实施的批准边界。
