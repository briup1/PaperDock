# 0007 使用反馈修正：独立实现审查

日期：2026-10-25。审查方式：只读源码、现有日志与内容图、独立重算SHA256；未构建、未启动／安装应用、未访问便签数据库或操作用户进程。唯一写入为本报告。

## 对象与边界

对比：
- 改前：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-01/candidate-03/source`
- 改后：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/candidate-final/source`
- 实施报告：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/implementation-report.md`

依据at-review与at-standards/references/core.md，限定本轮默认190pt、高度区迁入设置、短窗固定添加及新增行滚动／焦点，以及直接相关的输入法、锁与错误路径；不重开旧GUI问题，不审安装／版本脚本。

实际增量共9个文件：Editor、Manager、Model、Windows、Store、SelfTests、NoteSettingsTests、新TodoControlsTests与app/README。未发现夹入Application或其他本机交付改动。

## 沿用户操作核对

```text
管理器 → 设置与默认纸色 → 高度输入／保存／生效值／反馈
  → 原saveHeight／原子布局写入 → 成功后发布 → 下次打开或展开生效
短便签 → 固定添加按钮 → 本张marked text检查 → Store最终锁检查与追加
  → 新UUID行 → 外层滚动定位＋该行输入焦点 → 继续添加
保存失败 → 新条目仍在内存＋dirty／error → 内容区滚到错误／重试
```

- **高度区迁移**：Manager.swift:122–137迁入完整输入、保存、反馈、生效值；列表删除原高度区。保存仍调用原Model.saveHeight，没有另造保存路径；原配色设置保留。设置失败图实际显示草稿500、生效175及错误，成功图显示500生效且反馈完整。
- **190仅作默认**：Store.swift:42只改initial；:93依旧只在字段缺失时取initial，:173–182仍校验后接收已存值。已有177.5不覆盖，null／错类型／越界仍失败。NoteSettingsTests.swift:14–21新增保存177.5及原字节不改断言；缺字段190断言和非法输入拒绝仍在。
- **固定入口及新行**：Editor.swift:160–172仅compact把添加按钮放在ScrollView外；:163–166用新UUID滚动并设焦点，:233绑定对应行。管理器继续原非compact布局、字号与正文NSTextView；正文代理和marked text同步保护没有变化。管理器添加不走compact滚动／强制聚焦。
- **输入法和锁**：Editor.swift:214–215先检查锁／删除，再询问prepareTodoAddition；Windows.swift:51–59只检查目标便签panel的当前NSTextView，候选未确认就报错返回false，不取消候选、不主动结束编辑。通过后才追加并设置新行焦点；Store.swift:260–266的最终锁校验未改。锁时固定添加隐藏、原输入禁用链保持。
- **保存失败可达**：Editor.swift:204–205保留错误和正式save重试，仍属于中间可滚动内容。新追加保存失败不会抹掉内存条目或跳过错误；175pt故障内容图中错误、重试按钮、固定添加均实际可见，无重叠遮挡。

以上行号指改后快照，不把工作区其他改动视为被审版本。

## 测试证据的真实性和范围

证据根：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/note-settings-fix-01/candidate-final/evidence`。

逐条检查commands.json的14个完整argv、PID、exit_code=0、process_ended=true及各对应日志的PASS：note-settings-todo-controls、note-settings-controls、note-settings-rules、note-settings-compat、note-settings-write、note-settings-read、editor、palette、controller、windows、pin-rules、pin-metadata、pin-io、compact-red。argv均指同一candidate-final二进制且显式指定隔离目录；write/read使用同一persistence目录、不同PID。这里只核验已记录结果，不冒充审查者重新运行或独立wait观察。

TodoControlsTests.swift:33–54确实对190与175分别创建空便签，先断言0条，再通过真实NSButton.performClick依次添加1、2、3；不是预灌数组后滚动。每步检查实际计数、添加位置不变／完整可见、最新输入框在包含NSClipView裁剪的可视区内，以及currentEditor非空并等于panel.firstResponder。日志具有两种高度各3条SEQUENTIAL记录，hidden=true；对应内容图存在。

:60–69故障追加第4条后检查内存内容、dirty／error并滚到错误区，解除后调用正式Store.save；:70–84检查锁定输入／入口及Store拒绝追加，再用正文模拟marked text通过实际添加按钮验证不新增且候选仍在。marked分支没有单独断言firstResponder恒等，其“不抢焦点”还依赖上面的代码分支审查；不把该程序断言当真人IME通过。

实际查看6张内容图：190.0-3、175.0-3、175.0-failure、settings-failure、settings-saved、manager。新行／固定添加无裁切，错误／重试可见，设置高度区与原纸色区完整，管理列表无高度区。内容图为NSView.cacheDisplay，不是系统窗口截图。

旧失败保留：before-fix-02/controls.log仍报`add fully visible after 190.0/1`；最终日志与其分目录，未覆盖或把旧失败抹成通过。

## 源码与二进制核对

独立重算确认：
- source-manifest.json登记111个文件全部与快照hash一致，无快照内额外未登记文件。
- build-inputs.sha256的16项均匹配实际文件；构建脚本使用该快照自身Sources/*.swift及图标。
- 构建输入摘要：`2a42dccb55b68fc5ca51455e28418298b826301c3afce193d528846b50d0df2d`，按snapshot.py的序列化算法独立重算相同。
- 二进制SHA256：`8daa3889a9b41b884382eca0fd4fe1cf1ba6cb99f2f521516e8643f4dad80d41`，与binary.sha256及实施报告一致。
- Application.swift逐字等于基线提交`0634b0f87032cc1d69538a47f3d59bf6f1c39b8b`及改前candidate-03版本，origin=HEAD；与当前工作区版本不同，确认其他任务的版本改动未混入。9个overlay文件均与本次工作区对应文件相同。
- 现有文件时间顺序为manifest 18:39:12、binary 18:39:25、commands 18:39:50，与先冻结再构建／测试一致；时间与manifest不独立证明编译过程，未作此扩大主张。

标准fingerprint仍明确失败：`Build input outside selected snapshot: app/Sources/Application.swift`，standard_ready=false。手工隔离manifest不是标准ready；本报告不替协调者批准／绕过交付门。

## 发现与结论

**本次增量未发现具有具体失败链的代码阻断，未发现应报告的core规范偏离；可交协调者进入已获授权的后续本机体验环节。** 这不是“所有功能验收完成”，也不等于标准ready或安装脚本审查通过。

保留局限：未独立执行14套、完整GUI、真人中文IME／滚轮Tab、跨应用键盘／沉底遮挡、真实重试按钮或设置保存按钮点按；现有重试与设置保存成功证据是正式Store／Model调用，不能替代真人控件操作。按任务边界不扩查旧GUI、不安装、不启动、不改源码或数据，后续运行与安装门由协调者处理。
