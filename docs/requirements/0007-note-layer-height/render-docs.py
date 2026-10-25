#!/usr/bin/env python3
"""Generate reading pages from their Markdown sources using the existing renderer."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
source = ROOT.parent / "0001-local-notes/render-docs.py"
code = source.read_text().replace(
    '视觉检查与结果见 <a href="../../prototype-validation.md">../../prototype-validation.md</a>（生成器不执行视觉验收）。',
    "视觉验证未执行；当前审查缺口见正文（生成器不执行视觉验收）。",
)
code = code.replace(
    "'产品需求已批准 · 当前阶段见首节授权记录' if meta['status'] == 'approved' else '用例预期与执行结果分开 · 非测试通过'",
    "('业务用例v0.5 · 修正原型已批准 · 独立复核另记 · 非测试通过' if name.startswith('test-cases') else '业务需求v0.5 · 190pt修正已批准 · 非测试通过') if meta['status'] == 'approved' else '用例预期与执行结果分开 · 非测试通过'",
)
namespace = {"__file__": str(source), "__name__": "paperdock_doc_renderer"}
exec(compile(code, str(source), "exec"), namespace)
namespace["ROOT"] = ROOT
for name in ("requirement.wl-req-confirm", "test-cases.wl-qa-test-planner"):
    namespace["generate"](name)
