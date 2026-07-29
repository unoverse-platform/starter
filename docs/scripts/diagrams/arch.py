import re, pathlib

F = "Inter, ui-sans-serif, system-ui, -apple-system, sans-serif"
INK, MUTE, LINE, EDGE = "#111827", "#6b7280", "#e5e7eb", "#9ca3af"

def esc(t):
    return str(t).replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

def symbols(names):
    """Inline each logo as a <symbol> so the SVG is self-contained."""
    out = []
    for n in names:
        raw = pathlib.Path(f"images/logos/{n}.svg").read_text()
        vb = re.search(r'viewBox="([^"]+)"', raw).group(1)
        inner = raw[raw.index(">", raw.index("<svg")) + 1: raw.rindex("</svg>")]
        out.append(f'<symbol id="l-{n}" viewBox="{vb}">{inner}</symbol>')
    return "".join(out)

def logo(n, x, y, s=26):
    return f'<use href="#l-{n}" x="{x}" y="{y}" width="{s}" height="{s}"/>'

def text(x, y, t, size=13, weight=400, fill=INK, anchor="start", ls=0):
    # Escape here rather than at every call site: one unescaped "<domain>" in a
    # label turns the whole SVG into an XML parse error.
    return (f'<text x="{x}" y="{y}" font-family="{F}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}" letter-spacing="{ls}">{esc(t)}</text>')

def boundary(x, y, w, h, label, colour, dash="6 5", bg="none"):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="{bg}" stroke="{colour}" '
            f'stroke-width="1.5" stroke-dasharray="{dash}"/>'
            + text(x + 16, y + 24, label.upper(), 12, 700, colour, ls=0.8))

def box(x, y, w, h, title, sub=None, lg=None, fill="#ffffff"):
    o = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{fill}" stroke="{LINE}" stroke-width="1.5"/>']
    tx = x + 16
    if lg:
        o.append(logo(lg, x + 14, y + h / 2 - 13))
        tx = x + 50
    ty = y + h / 2 + (5 if not sub else -2)
    o.append(text(tx, ty, title, 15, 600))
    if sub:
        o.append(text(tx, ty + 17, sub, 13, 400, MUTE))
    return "".join(o)

def edge(pts, label=None, dashed=False, lx=None, ly=None, colour=EDGE):
    d = f'M{pts[0][0]} {pts[0][1]}' + "".join(f' L{x} {y}' for x, y in pts[1:])
    o = [f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="1.6"'
         f'{chr(32)+chr(115)+"troke-dasharray=" + chr(34) + "5 4" + chr(34) if dashed else ""} marker-end="url(#ar)"/>']
    if label:
        w = len(label) * 7.0 + 18
        o.append(f'<rect x="{lx - w/2}" y="{ly - 10}" width="{w}" height="20" rx="10" fill="#fff" stroke="{LINE}"/>')
        o.append(text(lx, ly + 4, label, 12, 500, MUTE, "middle"))
    return "".join(o)

def page(w, h, title, lg, accent, body, syms):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="100%" '
            f'role="img" aria-label="{title} architecture">'
            f'<defs>{syms}<marker id="ar" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
            f'orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="{EDGE}"/></marker></defs>'
            f'<rect width="{w}" height="{h}" rx="18" fill="#ffffff" stroke="{LINE}" stroke-width="1.5"/>'
            f'{logo(lg, 28, 26, 30)}{text(68, 48, title, 18, 700)}'
            f'{body}</svg>')

ZONE = {"public":"#d97706", "operator":"#7c3aed", "internal":"#0f766e", "loopback":"#6b7280"}

def host(x, y, w, h, title, sub, lg):
    o = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="#ffffff" stroke="#cbd0da" stroke-width="1.8"/>',
         f'<rect x="{x}" y="{y}" width="{w}" height="44" rx="12" fill="#f4f5f8"/>',
         f'<rect x="{x}" y="{y+32}" width="{w}" height="12" fill="#f4f5f8"/>',
         f'<line x1="{x}" y1="{y+44}" x2="{x+w}" y2="{y+44}" stroke="#e5e7eb"/>',
         logo(lg, x+14, y+9, 24),
         text(x+50, y+22, title, 15, 700),
         text(x+50, y+38, sub, 12.5, 400, MUTE)]
    return "".join(o)

def svc(x, y, w, title, port, zone, lg=None, h=54):
    c = ZONE[zone]
    o = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="9" fill="#fff" stroke="{LINE}" stroke-width="1.4"/>',
         f'<rect x="{x}" y="{y}" width="4" height="{h}" rx="2" fill="{c}"/>']
    tx = x + 14
    if lg:
        o.append(logo(lg, x+12, y+h/2-11, 22)); tx = x + 42
    o.append(text(tx, y+h/2-2, title, 14, 600))
    o.append(text(tx, y+h/2+15, port, 12.5, 400, c))
    return "".join(o)

def legend(x, y, items):
    o = []
    for i, (label, zone) in enumerate(items):
        yy = y + i*20
        o.append(f'<rect x="{x}" y="{yy-8}" width="10" height="10" rx="3" fill="{ZONE[zone]}"/>')
        o.append(text(x+18, yy+1, label, 11, 500, MUTE))
    return "".join(o)

def tw(s, size, weight=400):
    """Approximate rendered width. Inter averages ~0.52em regular, ~0.55em semibold."""
    return len(s) * size * (0.55 if weight >= 600 else 0.52)

def fitbox(x, y, title, subs, lg=None, minw=0, pad=16):
    """A box sized to its own text, so nothing can ever overflow it."""
    lead = 36 if lg else 0
    w = max([minw, tw(title, 15, 600) + lead + pad*2] + [tw(s, 13) + lead + pad*2 for s in subs])
    h = 34 + 18*len(subs) + (8 if subs else 0)
    o = [f'<rect x="{x}" y="{y}" width="{w:.0f}" height="{h}" rx="10" fill="#fff" stroke="{LINE}" stroke-width="1.5"/>']
    tx = x + pad
    if lg:
        o.append(logo(lg, x+pad-2, y+h/2-13)); tx = x + pad + 34
    ty = y + (h/2 + 5 if not subs else h/2 - 6*len(subs) + 2)
    o.append(text(tx, ty, title, 15, 600))
    for i, s in enumerate(subs):
        o.append(text(tx, ty + 18 + i*17, s, 13, 400, MUTE))
    return "".join(o), w, h

def column(x, y, items, gap=20, minw=0):
    """Two passes: size every box to its text, then render them all at the widest."""
    widths = [fitbox(0, 0, t, s, l, minw)[1] for t, s, l in items]
    w = max(widths + [minw])
    out, yy, boxes = [], y, []
    for t, s, l in items:
        svg, _, h = fitbox(x, yy, t, s, l, w)
        out.append(svg); boxes.append((x, yy, w, h)); yy += h + gap
    return "".join(out), w, boxes

def step(x, y, n, colour="#6D5DF6"):
    return (f'<circle cx="{x}" cy="{y}" r="10" fill="{colour}"/>'
            + text(x, y+4, str(n), 12, 700, "#ffffff", "middle"))
