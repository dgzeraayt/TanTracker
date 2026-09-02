import re, json, pathlib
src = pathlib.Path('src/screenshots.dc.html').read_text()
icon_json = json.load(open('/Users/bt/.claude/projects/-Users-bt-claude-TanTracker/9476d7f2-66f3-4676-8cee-6d6a80ee5881/tool-results/toolu_01N7vpqmXRfLWrR8AysVncCE.txt'))  # placeholder, replaced below
def helmet(s):
    m = re.search(r'<helmet[^>]*>(.*?)</helmet>', s, re.S); return m.group(1)
def defs(s):
    m = re.search(r'<svg style="position:absolute;width:0;height:0;overflow:hidden".*?</svg>', s, re.S); return m.group(0)
def strip_scif(s):
    s = re.sub(r'<sc-if[^>]*>', '', s); return s.replace('</sc-if>', '')
def balanced(s, start):
    i = s.index('>', start)+1; depth = 1
    for m in re.finditer(r'<div\b|</div>', s[i:]):
        depth += 1 if m.group(0) == '<div' else -1
        if depth == 0: return s[start:i+m.end()]
head = helmet(src).replace('<meta name="design_doc_mode" content="canvas">','')
d = defs(src)
shots = [balanced(src, m.start()) for m in re.finditer(r'<div class="shot"', src)]
print('shots', len(shots))
for n, sh in enumerate(shots, 1):
    html = f'<!DOCTYPE html><html><head><meta charset="utf-8">{head}<style>html,body{{margin:0;padding:0;background:#000;width:1290px;height:2796px;overflow:hidden}} .shot{{box-shadow:none!important}}</style></head><body>{d}{strip_scif(sh)}</body></html>'
    pathlib.Path(f'render/shot{n}.html').write_text(html)
