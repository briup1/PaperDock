#!/usr/bin/env python3
"""Regenerate these two reading pages from their sole Markdown sources; stdlib only."""
from pathlib import Path
from html import escape
import re
import hashlib

ROOT = Path(__file__).resolve().parent
CSS = """
:root{--bg:#F7F6F3;--fg:#2F3437;--muted:#787774;--line:#EAE7E0;--accent:#9F2F2D;--soft:#FDEBEC}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.7 'Plus Jakarta Sans','PingFang SC','Microsoft YaHei',sans-serif}
a{color:var(--accent);text-underline-offset:3px;overflow-wrap:anywhere}button{font:inherit;color:inherit;cursor:pointer}a:focus-visible,button:focus-visible{outline:2px solid var(--accent);outline-offset:3px}
.shell{max-width:1520px;margin:auto;display:grid;grid-template-columns:290px minmax(0,1fr);gap:42px;padding:32px}
aside{position:sticky;top:20px;align-self:start;max-height:calc(100vh - 40px);overflow:auto;padding-right:12px;min-width:0}
.eyebrow{font:11px/1.6 'JetBrains Mono',ui-monospace,monospace;color:var(--accent);letter-spacing:.06em}
h1,h2{font-family:'Instrument Serif','Songti SC','SimSun',serif;letter-spacing:-.02em;font-weight:500}h1{font-size:29px;line-height:1.35}h2{font-size:32px;margin:12px 0 24px}h3{font-size:19px;margin:30px 0 12px}p{margin:13px 0}strong{font-weight:650}
.chips{display:flex;flex-wrap:wrap;gap:7px;margin:16px 0}.chip{display:inline-block;border:1px solid var(--line);background:white;border-radius:999px;padding:3px 9px;font:11px/1.7 ui-monospace,monospace}.warning{background:#FBF3DB;color:#956400}
nav{display:grid;gap:5px;margin:24px 0}nav a{display:block;text-decoration:none;color:var(--fg);padding:9px 10px;border-left:2px solid transparent;font-size:13px;border-radius:0 4px 4px 0}nav a:hover{background:white}nav a.active{background:var(--soft);border-left-color:var(--accent);color:var(--accent)}
main{min-width:0;max-width:1040px}.crumb{font:12px ui-monospace,monospace;color:var(--muted)}.crumb:before{content:'●';color:var(--accent);margin-right:9px}section{animation:appear .5s cubic-bezier(.16,1,.3,1)}section[hidden]{display:none}@keyframes appear{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:none}}
pre{background:#26221E;color:#EDE8E0;padding:20px;border-radius:6px;overflow:auto;font:14px/1.8 'JetBrains Mono',ui-monospace,monospace;white-space:pre;max-width:100%}code{background:#F0EEE9;color:#2F3437;padding:2px 5px;border-radius:4px}pre>code{display:block;background:transparent;color:inherit;padding:0;border-radius:0;font:inherit}
.table-wrap{overflow-x:auto;border:1px solid var(--line);border-radius:6px;margin:18px 0}table{border-collapse:collapse;width:100%;font-size:13px;background:white}th{font:12px/1.7 ui-monospace,monospace;background:#FBFAF7;text-align:left}th,td{border:1px solid var(--line);padding:11px 12px;vertical-align:top;min-width:130px}td{overflow-wrap:anywhere}th:first-child,td:first-child{min-width:145px}ul{padding-left:23px}li{margin:9px 0}li.story{border-left:2px solid var(--accent);background:white;padding:12px 16px;list-style:none;margin-left:-23px}li.story strong{color:var(--accent)}
dl{display:grid;grid-template-columns:130px minmax(0,1fr);gap:12px;margin:14px 0}dt{font-weight:650}dd{margin:0;min-width:0}.pager{display:flex;justify-content:space-between;gap:16px;border-top:1px solid var(--line);padding:24px 0;margin-top:30px}.pager button{border:1px solid var(--line);border-radius:6px;padding:12px 16px;background:white}.pager button:disabled{color:#A8A49C;cursor:default}.source{color:var(--muted);font-size:12px;overflow-wrap:anywhere;margin-top:24px}
@media(max-width:859px){.shell{display:block;padding:20px}aside{position:static;max-height:none;padding:0}nav{grid-template-columns:repeat(2,minmax(0,1fr));margin:16px 0;gap:4px}main{max-width:none}h1{font-size:25px}h2{font-size:27px}dl{grid-template-columns:1fr;gap:4px}dd{margin-bottom:10px}pre{padding:14px}th,td{min-width:150px}}
@media(prefers-reduced-motion:reduce){section{animation:none}}
"""
JS = """
const panels=[...document.querySelectorAll('main section')], links=[...document.querySelectorAll('nav a')];let current=0;
function show(i,scroll=false){current=Math.max(0,Math.min(i,panels.length-1));panels.forEach((p,n)=>p.hidden=n!==current);links.forEach((a,n)=>{a.classList.toggle('active',n===current);if(n===current)a.setAttribute('aria-current','page');else a.removeAttribute('aria-current')});document.getElementById('prev').disabled=current===0;document.getElementById('next').disabled=current===panels.length-1;if(scroll)document.querySelector('main').scrollIntoView({block:'start'})}
function hash(){const id=decodeURIComponent(location.hash.slice(1)),target=id&&document.getElementById(id);if(target){const panel=target.closest('section');if(panel)show(panels.indexOf(panel))}else show(0)}
links.forEach((a,i)=>a.addEventListener('click',()=>show(i,true)));window.addEventListener('hashchange',hash);document.getElementById('prev').onclick=()=>{show(current-1,true);location.hash=panels[current].id};document.getElementById('next').onclick=()=>{show(current+1,true);location.hash=panels[current].id};document.addEventListener('keydown',e=>{if(e.altKey||e.metaKey||e.ctrlKey||e.target.closest('input,textarea,select,button'))return;if(e.key==='ArrowDown'||e.key==='ArrowUp'){e.preventDefault();show(current+(e.key==='ArrowDown'?1:-1),true);location.hash=panels[current].id}});hash();
"""


def inline(text):
    text = escape(text, quote=True)
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', text)
    return re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', text)


def render(lines):
    out, i = [], 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line.startswith('```'):
            block = []
            i += 1
            while i < len(lines) and not lines[i].startswith('```'):
                block.append(lines[i])
                i += 1
            out.append('<pre><code>' + escape('\n'.join(block)) + '</code></pre>')
            i += 1
        elif line.startswith('### '):
            out.append('<h3>' + inline(line[4:]) + '</h3>')
            i += 1
        elif line.startswith('|'):
            rows = []
            while i < len(lines) and lines[i].startswith('|'):
                rows.append([x.strip() for x in lines[i].strip().strip('|').split('|')])
                i += 1
            header, data = rows[0], rows[2:]
            out.append('<div class="table-wrap"><table><thead><tr>' + ''.join('<th>'+inline(x)+'</th>' for x in header) + '</tr></thead><tbody>' + ''.join('<tr>'+''.join('<td>'+inline(x)+'</td>' for x in row)+'</tr>' for row in data) + '</tbody></table></div>')
        elif line.startswith('- '):
            items = []
            while i < len(lines) and lines[i].startswith('- '):
                cls = ' class="story"' if re.match(r'- US\d+', lines[i]) else ''
                items.append('<li'+cls+'>'+inline(lines[i][2:])+'</li>')
                i += 1
            out.append('<ul>' + ''.join(items) + '</ul>')
        elif re.match(r'^\*\*[^*]+\*\*：', line) and not any(line.startswith('**'+s) for s in ['测试场景','测试数据','测试步骤']):
            label, value = line.split('：', 1)
            out.append('<dl><dt>'+inline(label.replace('**',''))+'</dt><dd>'+inline(value)+'</dd></dl>')
            i += 1
        else:
            paragraph = [line]
            i += 1
            while i < len(lines) and lines[i].strip() and not lines[i].startswith(('#','- ','|','```')):
                paragraph.append(lines[i])
                i += 1
            out.append('<p>' + inline(' '.join(paragraph)) + '</p>')
    return '\n'.join(out)


def generate(name):
    source = ROOT / (name + '.md')
    raw = source.read_text()
    _, front, body = raw.split('---', 2)
    meta = dict((k.strip(),v.strip().strip('"')) for k,v in (line.split(':',1) for line in front.strip().splitlines()))
    title = re.search(r'^# (.+)$', body, re.M).group(1)
    parts = re.split(r'^## (.+)$', body, flags=re.M)[1:]
    sections = [(parts[n], parts[n+1].strip().splitlines()) for n in range(0,len(parts),2)]
    nav = ''.join(f'<a href="#sec-{n}">{n:02d} / {escape(title)}</a>' for n,(title,_) in enumerate(sections,1))
    panels = ''.join(f'<section id="sec-{n}" aria-labelledby="title-{n}"><div class="crumb">SEC {n:02d} / {len(sections):02d}</div><h2 id="title-{n}">{escape(title)}</h2>{render(lines)}</section>' for n,(title,lines) in enumerate(sections,1))
    chips = ''.join('<span class="chip'+(' warning' if k=='status' else '')+'">'+escape(k)+': '+escape(meta[k])+'</span>' for k in ['status','execution_phase','version','created'])
    digest = hashlib.sha256(raw.encode()).hexdigest()
    approval_label = '产品需求已批准 · 当前阶段见首节授权记录' if meta['status'] == 'approved' else '用例预期与执行结果分开 · 非测试通过'
    html = f'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="generator" content="{meta['skill']}"><meta name="artifact-schema-version" content="{meta['artifact_schema_version']}"><meta name="source-sha256" content="{digest}"><title>{escape(title)} · {escape(meta['status'])}</title><style>{CSS}</style></head>
<body><div class="shell"><aside><div class="eyebrow">{meta['skill']}<br>产物规范：{meta['artifact_schema_version']}</div><h1>{escape(title)}</h1><div class="chips">{chips}</div><p class="chip warning">{approval_label}</p><nav aria-label="章节">{nav}</nav><div class="source"><a href="{name}.md">Markdown 唯一正文</a><br>批准证据：{escape(meta['approval_evidence'])}<br>HTML 由 render-docs.py 生成；视觉检查与结果见 <a href="../../prototype-validation.md">../../prototype-validation.md</a>（生成器不执行视觉验收）。</div></aside><main>{panels}<div class="pager"><button id="prev">← 上一节</button><button id="next">下一节 →</button></div></main></div><script>{JS}</script></body></html>'''
    (ROOT / (name+'.html')).write_text(html)
    print(f'generated {source.with_suffix(".html")} ({len(sections)} sections, source {digest[:12]})')


if __name__ == '__main__':
    for name in ['requirement.wl-req-confirm','test-cases.wl-qa-test-planner']:
        generate(name)
