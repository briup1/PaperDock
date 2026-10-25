# 0007 独立实现审查

- 日期：2026-10-25。
- 对照：需求／用例 v0.4、方案 v0.2、`progress.md` 当前记录；审查规范为 at-review 与 core。
- 范围：本轮 Store／Model／Windows／Editor／Manager／SelfTests 的 diff、未跟踪 `NoteSettingsTests.swift` 原文，以及关闭、启动、退出所必需的 HEAD Application 直接调用链。不扩历史审查。
- 执行边界：只读源码、manifest、已有日志／JSON 和进程状态；未构建、未重新执行测试、未启动应用或浏览器、未操作日常数据。唯一写入为本报告。

## 缺陷与规范

**在本次 diff 及直接交付边界内，未发现可给出具体失败链的真实代码缺陷，也未发现需要阻断的 core 规范偏离。** 不为凑发现增加美化或重构建议。

## 关键链路与核对依据

以管理器保存500pt、采购便签A沉底、B保持浮顶为同一场景：

```text
高度草稿500 → Model解析／Store再次校验 → 完整布局原子写成功
  ├─ 失败：旧生效值、草稿和原布局字节保持
  └─ 成功：只发布全局值，不改已开A/B的frame
       → 真正收纳再显示／启动恢复时应用500，保留宽、x和上沿
       → 折叠仍27；下次展开先保存500对应布局，再更新实际窗口

A请求沉底 → 本张未锁／可见／未删除／无未确认候选
  → 保存已确认内容 → 原子写A.layer → 发布后才改A实际level
  → B保持浮顶；高度／frame／锁定写入均保留各张层级
```

| 核对项 | 源码依据与判断 |
| --- | --- |
| 高度175…1000、有限数、小数 | `app/Sources/Model.swift:52-60` 保留失败草稿并提示；`app/Sources/Store.swift:41-45,217-222` 最终边界拒绝非有限数及越界值，成功写入后才发布。保存逻辑值不按系统像素取整。 |
| 写失败不发布新设置／层级 | `Store.swift:238-253` 先原子写完整布局，再由调用方赋值；高度失败不赋值；层级先内容save再布局，允许内容已保存而层级仍旧。`NoteSettingsTests.swift:62-84,158-164` 覆盖字节、草稿及实际level不变。 |
| 不立即跳、真正重开才生效 | `Windows.swift:28,63-67,86-123,135` 用opened区分同ID重复显示与真正重开；普通placement通知不重置现有展开frame，高度发布本身没有改frame回调。`NoteSettingsTests.swift:103-123` 覆盖其他便签通知、重复显示、真正重开及锁定重开。 |
| 旧宽、x、上沿及锁 | `Windows.swift:103-112` 从旧展开frame取上沿再替换高度；锁定恢复不走用户编辑绕过；`accessible` 只做允许的屏内可访问调整，不改全局保存值。 |
| 展开／折叠最终锁校验 | `Model.swift:46-49`、`Store.swift:196-207` 均校验锁；展开先按当前高度重算同上沿，再落盘发布。失败不改变collapsed／placement，窗口只在成功状态变化后同步。 |
| 折叠锁定隐藏按钮 | `Editor.swift:96-119` 只构建标题、解锁与必要错误入口，＋／×／层级入口在未锁分支内；展开层级入口同样受锁分支限制。 |
| 层级落盘后改变实际窗口 | `Model.swift:65-72`、`Store.swift:209-215` 最终核对目标，`Windows.swift:43-50,68-69,93-95,123` 使用目标面板候选检查及权威层级；不在失败分支调整level。显示排序只在当前level，不把沉底强制改回floating。 |
| 不覆盖未知／坏布局 | `Store.swift:61-68,84-91,169-182` 区分缺字段与null／错误类型，严格检查高度、UUID、frame和version，失败抛错而非清空重写；读取阶段无布局写入。缺字段默认177.5／floating。 |
| 设置合并不丢层级 | `Store.swift:78-80,217-222,238-249` moved保留layer；高度保存使用完整placements，placement保存携带当前defaultHeight，按张替换。 |
| 随机与既有设置不变 | 本轮未改变 `Store.create` 的池中独立randomElement选择、ColorSettings／SQLite模型或PaletteDraft链路；高度落盘不触碰Core Data配色设置。跨进程测试另核对固定／自定义设置及混合层级。 |
| 小高度正文／内容 | `Editor.swift:158-160,173-213` compact外层纵向滚动，正文有界80pt且仍用原NoteBody／NSTextView delegate／字号；管理器不走compact外层滚动。程序控件证据只按其实际覆盖理解，不等于真人滚轮、按钮、输入法完整验收。 |

以上源码路径均位于 `/Users/ziyun/workdir/self_project/PaperDock/`；行号对应本次审查时工作区与candidate-03一致的文件。

## 快照与已有程序证据

审查入口：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/review/` 的 `tracked-task.diff`、`review-manifest.json`，及 `untracked-content/app/Sources/NoteSettingsTests.swift`。

独立只读核对结果：

- candidate-03 manifest中的所有源码快照文件hash与清单一致；标记HEAD来源的文件均与 `0634b0f87032cc1d69538a47f3d59bf6f1c39b8b` 原文一致。
- 八个overlay文件与当前工作区及manifest一致；未跟踪测试的审查副本与当前原文一致。candidate-03与candidate-02五个产品模块完全相同，因此可明确区分复用的产品证据与新增测试，不把旧测试冒充本轮重跑。
- 候选 `Application.swift` 精确等于HEAD，且不同于工作区他人改动；本轮未夹带该改动。二进制SHA-256与review-manifest一致：`344eced2144b17f8524271a80174b227c037191efec54ad1d86e87fbf23bf11c`。
- 标准指纹因未选他人 `Application.swift` 拒绝，`standard_ready=false` 如实保留。白名单快照只证明隔离候选来源，不能替代标准ready或本机安装交接。

已有日志核对（不是本审查者重跑）：

- candidate-03 `evidence/commands.log` 与对应日志：note-settings-controls／rules／write／read均exit=0、日志PASS；write/read为分别执行的进程，共享持久化目录。
- candidate-02 `evidence/commands.log` 与相关日志：compat／pin-metadata／pin-io／windows及记录的相关规则回归exit=0；产品模块与candidate-03相同。
- candidate-03普通启动冒烟：PID3207、wait=0，launch/exit同PID，exit中dirty=false、无error、两张窗口高500且level分别-1／3，normal-exit标记存在；commands记录进程结束，当前ps也无该PID。**仅正常启动／保存／退出冒烟，不是完整GUI通过。**

## 旧GUI失败的归类

`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/candidate-02/evidence/gui/gui-result.json` 实际为PID99083、`status=failed`、`completed=false`、`failure=real close stashes`；commands记录wait=1且进程结束，normal-exit存在不能抹去失败。当前ps无该PID。

静态追踪：候选HEAD `Application.swift:182-183` 仍调用 `performClose(nil)`；HEAD及本轮 `Windows.swift` 的便签均为borderless、没有系统关闭按钮，且 `windowShouldClose` 的收纳业务未由本轮修改。SelfTests仅修正其测试装配的hide回调，并直接验证实际close delegate，没有给产品增加测试特例。

据此，该失败的调用前提属于既有GUI探针对borderless窗不适配，**没有证据归因于0007新增回归**；本审查未运行HEAD做独立复现，也不声称完整GUI已恢复通过。若后续要修旧探针，应按正式可触发的关闭／收纳入口修测试，不能给应用加特例。

## 审查结论与仍待验证

本轮只读实现审查无新增代码阻断，可进入已限定的隔离候选真人体验；不等于全部验收完成、标准ready或允许正式安装。真实key／跨应用点击编辑与沉底保持、真人中文IME、滚轮／Tab手感、真实边缘手势及完整GUI／HTML视觉仍按现有Gate保留，程序sendEvent、窗口排序或内容缓存图均不能补位。
