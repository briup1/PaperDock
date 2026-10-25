# 本地交付实施记录

日期：2026-10-25。范围：[需求 0006](requirement.wl-req-confirm.md)；测试要求唯一正文：[test-cases.md](test-cases.md)。

## 实现链路

```text
开发阶段 fingerprint → 实际自动化／开发者验证 → approve 交接
  ↓
用户明确调用 paperdock-local-delivery
  ↓
交接与当前拟提交树比对 → 从该树独立构建
  → 只提交逐个选定文件 → 提交树核对 → 写入提交号／本地签名
  → AppKit 请求确认的旧 PID 正常退出 → 同卷替换安装
  → 原数据目录启动 → PID、路径、启动状态、提交号核对
  → 删除临时旧应用与限定历史 ZIP → 最近结果
```

- 项目 Skill 唯一正文：`.agents/skills/paperdock-local-delivery/SKILL.md`。通过当前 Pi 的 Skill 加载函数解析，名称、描述及目录均有效，无诊断；源码确认包管理器扫描项目 `.agents/skills`。需用户 `/reload` 后在当前会话刷新，不是已替用户执行了 `/reload`。
- 执行入口：`app/local_delivery.py`，Python 标准库，无第三方依赖。临时 Git index 生成拟提交树，保留无关暂存；真实提交使用显式路径。不推送或发布。
- AppKit 辅助：`app/local-delivery-host.swift`，只列出本应用实例、请求指定 PID 正常终止。不发送 kill 信号，不请求辅助功能权限。
- 关于版本：`app/Sources/Application.swift` 优先显示构建版本和交付提交号；普通开发构建仍显示 local，便签业务和存储模型不变。
- 分享包生成与首次历史解压目录清理未实现，按已批准排除范围不做。现有 ZIP 本轮未删除，清理仅在后续正式交付成功时执行。

## 已执行验证

1. `python3 app/test_local_delivery.py -v`：临时 Git 与安装目录自动化；覆盖指纹变动、未选构建输入、源码删除、新文件、非法路径、软链、部分暂存、保留无关暂存、构建失败、安装复制失败、启动失败保留旧应用、旧 PID 确认、多实例拒绝、退出超时不强杀、并发锁、拒绝误用父仓库及限定清理。应用启动在这些单元测试中模拟。
2. `swiftc app/local-delivery-host.swift -o .work/local-delivery-verification/delivery-host`：编译通过，`list` 只读查询得到当前用户原实例。
3. `bash app/build.sh <独占绝对构建目录>`：完整应用编译通过；对隔离构建写入测试用提交号后本地 ad-hoc 签名，`codesign --verify --deep --strict` 通过。
4. 真实独占实例启动、AppKit PID／路径／finishedLaunching 查询、正常退出请求、进程结束和 `normal-exit.txt` 核对通过。数据与证据位于 `.work/local-delivery-verification/isolated-1792914559434290000`；用户原实例保持运行。
5. 真实隔离集成：临时仓库中修改 README，走交接 → 从拟提交树完整 Swift 构建 → 真实 Git 提交 → 签名 → ditto 安装 → 真实 AppKit 启动核对，全部通过。结果见 `.work/local-delivery-verification/integration-1792914684015761000/state/last-result.json`。该测试只跳过“正式唯一旧实例检查／退出”两处，以免关闭用户应用；此部分另由上述正常退出探针和单元测试覆盖，不宣称真实日常升级已验。自有实例测试后全部正常关闭。
6. `git diff --check` 通过；需求 HTML 由现有 Markdown 渲染器生成并做同源标识检查，未做浏览器视觉验收。

这些只证明相应交付场景成立，不是稳定性、全部便签功能或真实日常库升级认证。本轮不把测试说明字段当成测试结果的自动认证；其真实性由调用 Skill 的开发者核实。

## 实际失败与修复

首轮隔离测试发现命令执行函数的默认参数在导入时绑定原项目目录，测试替换 ROOT 未能改变该默认目录；第一条用例误在当前仓库生成测试提交并写入测试 Git 身份。已在发现时停止，撤销唯一测试提交、保留全部工作文件、移除测试身份覆盖，当前 HEAD 恢复原 `0634b0f`、全局身份生效，原有未提交 AGENTS.md 保持未提交。没有推送、安装、退出用户实例或修改便签数据。

修复为调用时解析工作目录，测试创建仓库后立即断言其根目录；另新增拒绝父仓库用例。后续测试写入均在隔离仓库。本记录保留该失败，不以修后通过覆盖历史。

## 版本 2：第一部分入口

用户接受第一部分效率建议后，新增 `.agents/skills/paperdock-change/SKILL.md`；只路由既有需求确认、实现、测试与 Review 能力，不新增脚本、服务或便签功能。README 增加开发入口；本地交付 Skill 只补相邻入口导航，交接参数仍在原 Skill 维护，不复制第二套脚本约定。需求和用例原位升级到版本 2，无平行正文。

本轮实际验证：

- 当前 Pi 的 `loadSkillsFromDir` 同时加载 `paperdock-change` 和 `paperdock-local-delivery`，诊断为空；相对脚本路径、相邻 Skill、README 入口、本地用例链接均可解析。
- 同源重新生成需求阅读页，检查来源 SHA256、生成器身份与本地链接，`git diff --check` 通过；仍未执行浏览器视觉检查。
- 人工语义推演 TC15–TC20：宽/高未明仅确认必要选择；纯留白要实际视觉、不默认全量存储回归；锁定/保存变化按直接影响扩大验证；测试后变化重新取指纹补验证；待体验/失败不批准交接；纯文档不构建应用且不自动调用交付。指引均保留对应分支，但文案存在不证明未来 Agent 一定执行。

没有为验证此文档再次启动应用、创建正式交接或调用 deliver；未改应用/脚本实现、未提交安装清理。上轮构建及隔离集成结果仅代表上轮实现，不拿来宣称新增开发入口全链通过。当前尚无用此 Skill 完成真实新功能开发的证据，也无独立用例审查结论。

## 尚未执行

- 未对用户当前实例做正式退出／替换安装，未在当前项目创建正式交付提交，未清理现有 ZIP；这些是下次明确调用交付的动作。
- 未验证真实保存失败弹窗、磁盘满、安装时外部进程竞态、签名分发、公证、分享或完整关于面板视觉。
- 未做独立用例审查；需求阅读页无浏览器视觉验收。测试执行日志位于 `.work/local-delivery-verification/unit-tests.log`，不进入 Git。
