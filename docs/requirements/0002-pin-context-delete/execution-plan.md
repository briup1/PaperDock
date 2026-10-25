# 0002执行工作包

用户已确认需求v0.1全部口径并要求“全部ok 立即开发”。方案v0.1采用delegated/adopted（不是伪造人工批准技术稿），check_design_doc.py --require-executable PASS。仅整张锁定/正常重启位置及状态保持、全部列表卡片右键精准软删除。需求和用例同目录唯一正文，具体预期引用TC-015～019，不复制。正式0001真人结果不因本轮授权自动通过。

PD-04：钉住、跨入口锁保护、锁/frame保存恢复及右键软删除为同一工作包，因共用Store/AppModel/Editor/Windows/Manager写集由一位持续实现者串行完成。不新增产品角色、不横切多个人并发改同文件。无Git、不安装/发布/权限/外部写入；成员不再委派。

```text
已批准需求/已采用方案 → 用例独立静态准入 → 实现PD-04＋自测 → 冻结/自身PID退出
                                                                  ↓
                                                     独立聚焦检查＋新构建/定向验收
                                                                  ↓
                                                     修复回同owner → 受影响复验
```

- 协调者所有权：本目录需求/用例/方案/同源HTML/执行计划，根README/progress。
- 准入检查者只写case-readiness-review.md，不改用例和实现。当前原实现工位已不可写，按同Task retry-of启动替代Pi，核对完成后该持续owner实施PD-04；后续验收由另一个未写实现者进行。
- 实现者仅app/Sources必要改动、app脚本/README、artifacts/developer/pin-delete-01/新产物；旧build运行中不覆写，先用独立输出目录。旧prototype/experiments/旧artifacts及用户试用data只读不改。方案推荐不改CoreData模型，采用同独占目录的原子锁/frame元数据；如需偏离须先报直接必要原因。
- 独立检查/验收者仅docs/pin-delete-review.md、artifacts/acceptance/pin-delete-review-01/result.json及evidence/；源码只读，缺陷交回owner。聚焦锁的跨入口最终保护/迟到操作、旧库兼容、窗口关闭/移动/尺寸、右键目标ID/确认/取消/置灰、日期不变、两进程重启；真实右键/物理拖动不能程序冒充。系统窗口捕获仅自身PID且preflight已有权限，不申请/改权限。

旧人工实例PID46879尚在运行，已请用户正常菜单退出，不能强杀/写旧库。新代码可离线构建/纯规则测试；新的GUI验收待核对旧实例已退出才启动，避免两个边缘入口重叠。锁/frame存储只在新合成目录或显式复制旧合成库的隔离副本验证，不迁移日常资料或原库。

完成：可运行增量.app、必要RED/GREEN与直接回归、独立冻结源hash核验和可判定结果、已知阻断闭合/未验明确。不能为了交付把新增效果未验写verified或覆盖旧失败。同缺陷连续三次不过熔断。文档HTML当前仅生成/结构检查，浏览器视觉未验；不因此阻止已明确委托普通可逆实现，但交付须如实说明。
