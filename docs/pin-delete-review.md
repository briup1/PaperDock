# 0002 钉住与列表右键删除：独立聚焦检查

执行轮次：[唯一结果记录](/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/pin-delete-review-01/result.json)。本检查者未写产品实现、未再委派；仅新建本文及该轮 evidence，源码、旧失败、旧产物和旧用户库未修改。模式为 `focused-delivery`，不是全库审查或完整真人验收。

## 固定输入与审查范围

- 需求/用例均 v0.1，检查点引用 TC-015～019；方案 v0.1，`decision_mode=delegated / status=adopted`，不冒充人工批准技术细节。
- 实现冻结：`/Users/ziyun/workdir/self_project/PaperDock/artifacts/developer/pin-delete-01/frozen-source.sha256` 与 `frozen-binary.sha256`；执行前、执行后全部校验退出 0。
- 独立构建二进制 SHA256：`26d75d50002bc64c8d63c7f60d8a8e75193d04be25ecd5099fa4af76331fe490`，与实现者冻结二进制一致。独立产物在 `/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/pin-delete-review-01/evidence/build/PaperDock.app`，没有覆盖 `app/build`。
- 以 R1 源文件哈希为基线比对现有工作树，检查本次变动的 Store/Model/Windows/Editor/Manager/main/SelfTests、新 PinTests 与 runner，以及直接依赖。没有可取得的完整历史源码文本 diff，不虚构提交或文本差异。`Application.swift`、`test.sh`、`build.sh` 与 R1 哈希一致，退出与结果门未回退。
- 环境：macOS 26.5.1 arm64，Swift 6.3.3；只用已存在工具，无权限申请、安装、Git、发布或全局输入注入。

## 按实际操作核对的链路

```text
A浮窗钉住 → AppModel取A的frame
  → Store先保存内容，再原子写NoteLayout.json
      ├─ 内容/元数据失败：旧锁状态不变，报错
      └─ 成功发布锁：编辑器只读＋面板禁移动/缩放/关闭
                         ↓
管理器/旧配色/迟到删除/正文delegate → 同一稳定ID最终验锁 → 拒绝改A

选中A，卡片B右键 → 闭包捕获n.id=B → pendingDelete=B且确认标题来自B
  ├─ 取消：A/B完整字段不变
  └─ 确认时重查B锁：仅B软删除/收起，恢复同ID且为收纳
```

### 代码与程序证据

未发现具体设计偏离或本次交付范围内已证实的代码阻断缺陷；无须回派修复的发现。以下是已核对的关键位置，不表示其真人交互已通过：

- `/Users/ziyun/workdir/self_project/PaperDock/app/Sources/Store.swift:125-161`：缺文件才默认未锁；坏 JSON、未知版本、非法ID、非法frame拒载且保留原文件；保存成功才更新 placements。锁、解锁落盘失败保留旧态，探针另验证失败解锁时磁盘字节不变。
- `/Users/ziyun/workdir/self_project/PaperDock/app/Sources/Store.swift:172-187`、`/Users/ziyun/workdir/self_project/PaperDock/app/Sources/Model.swift:95-106`：edit/arrange、带便签来源的配色在最终入口检查锁；current/fixed/random 三种旧草稿均不能改便签或 settings；独立的全局设置入口仍可用。
- `/Users/ziyun/workdir/self_project/PaperDock/app/Sources/Windows.swift:36-74`：锁态禁 `isMovable` / background move / resizable / close，关闭 delegate 重查锁；重开先恢复 frame 再显示。
- `/Users/ziyun/workdir/self_project/PaperDock/app/Sources/Editor.swift:7-23, 85-110`：锁后正文 delegate 拒写，marked text 回到锁前有效正文，不保存未确认候选；标题/待办只读。独立探针给 NSTextView 真正挂上 delegate，覆盖 unmark 回调，不仅测试手动 delegate 调用。
- `/Users/ziyun/workdir/self_project/PaperDock/app/Sources/Model.swift:43-52`、`/Users/ziyun/workdir/self_project/PaperDock/app/Sources/Manager.swift:73-77, 101-109`：卡片闭包只取 n.id；确认目标标题取 pendingDelete，不取 selected；确认再次验锁；只有卡片有菜单，空白无目标菜单。

逐项结果只在 result.json 维护：**P 为纯规则/持久化/静态绑定；G 为未显示自有原生控件；H 为完整应用/真人入口**。P/G 的通过不能合并成整条 TC 通过。本轮 22 项 P、6 项 G 有对应证据，19 项 H 因旧用户实例仍在运行保留阻塞。

## 实际命令、退出码与证据

1. 新目录构建与现有定向 runner：

```bash
bash /Users/ziyun/workdir/self_project/PaperDock/app/test-pin-delete.sh --controls /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/pin-delete-review-01/evidence/program /Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/pin-delete-review-01/evidence/build
```

总退出 0；`commands.log` 记录各子命令及真实退出码，覆盖锁保护、日期、元数据坏输入/写失败、跨进程锁/frame/解锁恢复及直接内容/配色回归。`pin-write → pin-window-read → pin-read → pin-read-unlocked` 是进程读写和首显前 frame 证据，不是菜单正常退出再重开。

2. 独立补充探针：使用未修改的正式生产类，另一个 main 仅放本轮 evidence；编译和执行退出 0。新增覆盖“挂上真实 delegate 后组合输入锁定”“锁后旧删除取消”“解锁落盘失败不改磁盘”“A锁时B仍可请求删除”“搜索同匹配词时选A操作B，取消/删除/恢复全字段和日期比较”“曾锁A解锁后能删除且B不变”。完整编译参数与新数据路径在 `/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/pin-delete-review-01/evidence/probe/commands.log`，最终日志为 `run-02.log`。探针输入增加两项断言后只重跑该探针，未重复整套规则。

3. 旧库兼容：仅复制实现者 pre-0002 `compatibility-01/legacy-source` 合成库到本轮 `evidence/compatibility-copy`；用本轮新二进制导出副本，退出 0。4 张便签、8 条两状态待办和 settings 与旧导出逐值相等，placements 为空；旧合成源所有文件前后哈希相同。记录在 `/Users/ziyun/workdir/self_project/PaperDock/artifacts/acceptance/pin-delete-review-01/evidence/compatibility.log`。未打开用户旧 manual data。

4. R1 结果门负向检查：只造本轮 `normal-exit.txt` 而不造 GUI 完成结果，向原 `test.sh --check-gui-result` 传真实已退出探针PID、wait=0，实际退出 **1（预期1）**；没有启动完整GUI。证据在本轮 `evidence/r1-negative/`。两个 runner 的 `bash -n` 退出 0。

## 可视证据与阻塞

实际逐张查看本轮 `evidence/program/data-pin-controls/` 下 `unlocked-content.png`、`locked-content.png`、`manager-locked-content.png`：未锁时钉住/纸色/管理/收纳可见；锁后顶部仅解锁，正文仍可读，管理器同ID可辨锁态与解锁，当前局部图未见新增按钮遮挡。这些是**无可见窗口的内容缓存候选证据**，无系统边框、无可信截图基准，也不含真正右键菜单；不能替代系统窗口截图或真人视觉验收。

旧用户PID **46879** 在开始及结束仍运行：旧 `app/build/PaperDock.app`，数据为旧 `artifacts/acceptance/manual-final-01/data`。没有终止/强杀它、没有共写该库、没有覆写旧 app/build。详见本轮 `evidence/preflight.log`、`final-preflight.log`、`exit-processes.log`。

因此本轮不启动完整 ApplicationController / EdgeWindow / NSApp.run，不安装第二边缘入口。自有未显示面板显式 orderOut，测试/导出/独立探针均正常返回退出 0，结束只剩旧用户实例；未启动浏览器，无浏览器需收尾。

待旧实例正常退出后再做的最小检查：TC-015 真人标题栏拖动/边缘缩放/关闭与解锁恢复；TC-016 真实跨入口/旧sheet与中文候选；TC-017 完整应用正常退出重开；TC-018/019 真实卡片右键、确认/取消及锁态置灰；以及已有权限范围内的本任务系统截图。不无限等待用户，不把0001未验自动补成通过。

**结论：当前冻结版本的独立聚焦代码检查、独立构建及 P/G 程序证据已完成，未发现需要回派的直接代码缺陷；完整交付判定仍是“证据不足”，不是全需求验收通过。缺口是旧PID正常退出后的 H 层交互、正常应用重启和系统可视证据，视觉门禁保留 BLOCKED。**
