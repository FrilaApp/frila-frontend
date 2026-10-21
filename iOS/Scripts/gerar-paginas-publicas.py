#!/usr/bin/env python3
import html
import os
import re
import sys

src = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Docs", "PaginaPublica"))
if len(sys.argv) < 2:
    print(f"Uso: {sys.argv[0]} <pasta de saída>", file=sys.stderr)
    sys.exit(1)
out = sys.argv[1]

def inl(t):
    t = html.escape(t, quote=False)
    t = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', t)
    t = re.sub(r'`(.+?)`', r'<code>\1</code>', t)
    t = re.sub(r'\[([^\]]+)\]\((https?://[^)]+|mailto:[^)]+|/[^)]*)\)', r'<a href="\2">\1</a>', t)
    t = re.sub(r'\[A DEFINIR[^\]]*\]', '<em>em atualização</em>', t)
    return t

def conv(md):
    L = md.split('\n')
    o = []
    i = 0
    stack = []
    def close():
        while stack:
            o.append('</%s>' % stack.pop())
    while i < len(L):
        l = L[i]
        if l.startswith('|'):
            close()
            rows = []
            while i < len(L) and L[i].startswith('|'):
                if not re.match(r'^\|[\s\-:|]+\|$', L[i]):
                    rows.append([c.strip() for c in L[i].strip('|').split('|')])
                i += 1
            o.append('<div class="t"><table>')
            for n, r in enumerate(rows):
                tag = 'th' if n == 0 else 'td'
                o.append('<tr>' + ''.join('<%s>%s</%s>' % (tag, inl(c), tag) for c in r) + '</tr>')
            o.append('</table></div>')
            continue
        m = re.match(r'^(#{1,4}) (.+)', l)
        if m:
            close()
            n = len(m.group(1))
            o.append('<h%d>%s</h%d>' % (n, inl(m.group(2)), n))
        elif l.strip() == '---':
            close()
            o.append('<hr>')
        elif re.match(r'^\s+- ', l):
            if not stack or stack[-1] != 'ul':
                if stack and stack[-1] == 'ol':
                    pass
                o.append('<ul>')
                stack.append('ul')
            o.append('<li>%s</li>' % inl(l.strip()[2:]))
        elif re.match(r'^- ', l):
            while stack and stack[-1] != 'ul':
                o.append('</%s>' % stack.pop())
            if not stack:
                o.append('<ul>')
                stack.append('ul')
            o.append('<li>%s</li>' % inl(l[2:]))
        elif re.match(r'^\d+\. ', l):
            if 'ul' in stack[-1:]:
                o.append('</ul>')
                stack.pop()
            if not stack:
                o.append('<ol>')
                stack.append('ol')
            o.append('<li>%s</li>' % inl(re.sub(r'^\d+\. ', '', l)))
        elif l.strip() == '':
            pass
        else:
            close()
            o.append('<p>%s</p>' % inl(l))
        i += 1
    close()
    return '\n'.join(o)

CSS = """<style>:root{--bg:#fbfaf8;--fg:#1f1d1b;--mut:#6b6560;--ac:#B93A1C;--ln:#e4e0da}@media(prefers-color-scheme:dark){:root{--bg:#181716;--fg:#ece9e5;--mut:#a39d96;--ac:#EA5A36;--ln:#33302d}}
body{margin:0;background:var(--bg);color:var(--fg);font:17px/1.65 -apple-system,system-ui,"Segoe UI",sans-serif}main{max-width:720px;margin:0 auto;padding:32px 20px 64px}
nav{display:flex;gap:16px;flex-wrap:wrap;border-bottom:1px solid var(--ln);padding-bottom:12px;margin-bottom:24px}nav a{color:var(--mut);text-decoration:none}nav a.brand{color:var(--ac);font-weight:700}nav a:hover{color:var(--fg)}
h1{font-size:1.9rem;line-height:1.2}h2{font-size:1.25rem;margin-top:2em}h3{font-size:1.05rem;margin-top:1.5em}a{color:var(--ac)}hr{border:0;border-top:1px solid var(--ln);margin:32px 0}code{font-size:.9em}
.t{overflow-x:auto}table{border-collapse:collapse;font-size:.92rem}td,th{border:1px solid var(--ln);padding:6px 10px;text-align:left;vertical-align:top}footer{color:var(--mut);font-size:.9rem;margin-top:48px;border-top:1px solid var(--ln);padding-top:16px}footer a{color:var(--mut);text-decoration:none}footer a:hover{color:var(--fg)}</style>"""

pages = [("privacidade", "Política de Privacidade"), ("termos", "Termos de Uso"), ("suporte", "Suporte")]
nav = '<nav><a href="/" class="brand">Frila</a>' + ''.join('<a href="/%s">%s</a>' % (p, t) for p, t in pages) + '</nav>'
footer = '<footer>Frila · <a href="/privacidade">Privacidade</a> · <a href="/termos">Termos</a> · <a href="/suporte">Suporte</a> · <a href="mailto:suporte@frilabr.com">suporte@frilabr.com</a></footer>'

os.makedirs(out, exist_ok=True)

# Home (raiz /)
home_src = f"{src}/home.md"
if os.path.exists(home_src):
    home_md = open(home_src, encoding='utf-8').read()
    home_body = conv(home_md)
else:
    home_body = "<h1>Frila</h1><p>Turnos avulsos de trabalho.</p>"

app_store_comment = """<!-- Espaço reservado para o botão de download na App Store (disponível quando o app for publicado na loja) -->
<!-- <p><a href="#" class="btn-appstore">Baixar na App Store</a></p> -->"""

home_html = f'<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Frila — Turnos avulsos de trabalho</title><meta name="description" content="O Frila conecta estabelecimentos a profissionais autônomos para turnos avulsos de trabalho no setor de alimentação e eventos."><meta name="color-scheme" content="light dark">{CSS}</head><body><main>{nav}{home_body}\n{app_store_comment}\n{footer}</main></body></html>\n'
open(f"{out}/index.html", "w", encoding="utf-8").write(home_html)

# Páginas legais (/privacidade, /termos, /suporte)
for p, t in pages:
    md = open(f"{src}/{p}.md", encoding='utf-8').read()
    os.makedirs(f"{out}/{p}", exist_ok=True)
    open(f"{out}/{p}/index.html", "w", encoding="utf-8").write(f'<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{t} — Frila</title><meta name="color-scheme" content="light dark">{CSS}</head><body><main>{nav}{conv(md)}{footer}</main></body></html>\n')
