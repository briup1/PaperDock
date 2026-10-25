# PD05紧凑便签与图标工作包

用户本会话在270×355pt外框、仅便签字号留白缩小、去便签桌面可见及已展示蓝色P图标后明确OK立即实现。需求v0.1 approved；方案v0.1 delegated/adopted（非伪造人工技术批准），结构可执行检查PASS。用例TC020～022 v0.1，独立静态准入task_76c950ed1580，Orca run_8f219d9dfbf9。

```text
准入静态核对 → PD05同一工作包实现/自测 → 冻结 → 独立聚焦检查/新构建/视觉核对
                                              └→ 直接缺陷回原owner → 定向复验
```

实现者所有权：app/必要Windows/Editor/NoteBody/图标加载与build脚本/README/聚焦测试，artifacts/developer/compact-icon-01/新证据。assets/brand批准素材只读，旧原型/实验/0002冻结证据/旧manual data不改；Store/Model与CoreData模型无业务变更；例外是直接必要的NotePlacement.valid旧宽340下限需同步新窗minSize，保留异常值拒绝，新增270×355钉住重开测试，不改锁语义和JSON格式。独立者只写docs/compact-icon-review.md及artifacts/acceptance/compact-icon-review-01/result.json/evidence。协调者写本目录文档、README/progress。成员不再委派。

禁止把尺寸写成内容区或像素；目标为新窗frame270×355pt，依据用户实测旧窗。不要scaleEffect整张缩放造成命中区和文字模糊，按compact设置字体/间距及图标工具可达；色盘主界面不缩成小色块，管理器默认不变。已有placement原frame恢复不能被新最小尺寸夹大；无placement新窗才用目标。图标资源打包Bundle内可独立目录运行，不靠开发机绝对路径、不重启Dock/清缓存。

旧PID46879若仍运行，禁止覆写旧app/build/启动第二完整边缘GUI/改其库；无显示自有窗口与控件图先检查并分类，完整GUI/系统截图与真人操作待旧实例正常退出再补。不强杀，不为此空转。所有自有测试正常返回和PID归属记录，无安装/权限/全局输入/发布/Git/日常数据写入。

最低必要验证：新默认frame＋内容尺寸、compact vs manager字号、浅/深/空/锁态/长正文20句和8待办可滚动，历史390×500frame不改，图标bundle声明/hash/解包及小尺寸可辨，0002锁/右键与R1结果门直接回归。不因旧版真人未验补成已过。按统一test-execution存唯一新result.json，失败保留/修后新轮，不复制旧通过冒充新版本。结构与内容缓存图不是系统截图；有缺口交付说明，不置全需求done。
