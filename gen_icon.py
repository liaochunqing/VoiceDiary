#!/usr/bin/env python3
"""Render VoiceDiary App Icon C (翻页) at 1024x1024."""

from PIL import Image, ImageDraw

SIZE = 1024
SC = SIZE / 120.0  # scale: 120-unit SVG → 1024px

def s(v):
    return round(v * SC)

def hex_rgb(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16), a)

def diag_grad(w, h, c1, c2):
    """Top-left to bottom-right diagonal gradient."""
    r1,g1,b1,_ = hex_rgb(c1)
    r2,g2,b2,_ = hex_rgb(c2)
    rm,gm,bm = (r1+r2)//2,(g1+g2)//2,(b1+b2)//2
    tiny = Image.new('RGBA', (2, 2))
    tiny.putpixel((0,0),(r1,g1,b1,255))
    tiny.putpixel((1,1),(r2,g2,b2,255))
    tiny.putpixel((0,1),(rm,gm,bm,255))
    tiny.putpixel((1,0),(rm,gm,bm,255))
    return tiny.resize((w,h), Image.BILINEAR)

def horiz_grad(w, h, c1, c2):
    """Left-to-right horizontal gradient."""
    r1,g1,b1,_ = hex_rgb(c1)
    r2,g2,b2,_ = hex_rgb(c2)
    tiny = Image.new('RGBA', (2, 1))
    tiny.putpixel((0,0),(r1,g1,b1,255))
    tiny.putpixel((1,0),(r2,g2,b2,255))
    return tiny.resize((w,h), Image.BILINEAR)

def composite(base, layer):
    return Image.alpha_composite(base, layer)

def new_layer():
    return Image.new('RGBA', (SIZE, SIZE), (0,0,0,0))

def bezier_quad(p0, p1, p2, steps=30):
    pts = []
    for i in range(steps+1):
        t = i/steps
        x = (1-t)**2*p0[0] + 2*(1-t)*t*p1[0] + t**2*p2[0]
        y = (1-t)**2*p0[1] + 2*(1-t)*t*p1[1] + t**2*p2[1]
        pts.append((round(x), round(y)))
    return pts

# ── Canvas ──────────────────────────────────────────────────────────────
canvas = Image.new('RGBA', (SIZE, SIZE))

# 1. Background gradient #F5EBD5 → #E8D8B8 (diagonal)
canvas = composite(canvas, diag_grad(SIZE, SIZE, '#F5EBD5', '#E8D8B8'))

# 2. Book spine (left leather strip) – diagonal gradient #7A5230 → #3A2210
spine_layer = new_layer()
sw, sh = s(22), s(100)
spine_grad = diag_grad(sw, sh, '#7A5230', '#3A2210')
spine_mask = Image.new('L', (SIZE, SIZE), 0)
ImageDraw.Draw(spine_mask).rounded_rectangle(
    [s(12), s(10), s(12+22), s(10+100)], radius=s(4), fill=255)
spine_layer.paste(spine_grad, (s(12), s(10)))
spine_layer.putalpha(spine_mask)
canvas = composite(canvas, spine_layer)

# 3. Spine gold accent line  x=20, y=10→110, opacity 0.6
gl = new_layer()
ImageDraw.Draw(gl).line(
    [s(20), s(10), s(20), s(110)],
    fill=hex_rgb('#C9A23A', int(255*0.6)),
    width=max(1, s(0.8)))
canvas = composite(canvas, gl)

# 4. Back page layer  x=34,y=14,w=70,h=92, #E0CEAE @ 70%
l1 = new_layer()
ImageDraw.Draw(l1).rounded_rectangle(
    [s(34), s(14), s(34+70), s(14+92)],
    radius=s(2), fill=hex_rgb('#E0CEAE', int(255*0.7)))
canvas = composite(canvas, l1)

# 5. Middle page layer  x=36,y=12,w=70,h=92, #EAD9BC @ 80%
l2 = new_layer()
ImageDraw.Draw(l2).rounded_rectangle(
    [s(36), s(12), s(36+70), s(12+92)],
    radius=s(2), fill=hex_rgb('#EAD9BC', int(255*0.8)))
canvas = composite(canvas, l2)

# 6. Current page – horizontal gradient #E8D8B8 → #FBF3E3
#    Shape: M38 10 L100 10 Q104 10 104 14 L104 106 Q104 110 100 110 L38 110 Z
#    ≈ right-rounded rect with straight left edge
px, py = s(38), s(10)
pw, ph = s(104-38), s(110-10)
page_grad = horiz_grad(pw, ph, '#E8D8B8', '#FBF3E3')
page_mask = Image.new('L', (SIZE, SIZE), 0)
pm_draw = ImageDraw.Draw(page_mask)
pm_draw.rounded_rectangle([s(38), s(10), s(104), s(110)], radius=s(4), fill=255)
# Flatten left rounding – fill the 4px strip on the left of the rect
pm_draw.rectangle([s(38), s(10), s(38)+s(4), s(110)], fill=255)
page_layer = new_layer()
page_layer.paste(page_grad, (px, py))
page_layer.putalpha(page_mask)
canvas = composite(canvas, page_layer)

# 7. Paper lines  y=32,42,52,62,72  x=46→96
ll = new_layer()
ld = ImageDraw.Draw(ll)
for yl in [32, 42, 52, 62, 72]:
    ld.line([s(46), s(yl), s(96), s(yl)],
            fill=hex_rgb('#D9CBAC', 255), width=max(1, s(0.8)))
canvas = composite(canvas, ll)

# 8. Dog-ear fold  M80 110 L104 110 L104 86 Q92 92 80 110 Z
fold_layer = new_layer()
fd = ImageDraw.Draw(fold_layer)
# Approximate bezier: (104,86) → ctrl(92,92) → (80,110)
curve = bezier_quad((s(104), s(86)), (s(92), s(92)), (s(80), s(110)))
fold_poly = [(s(80), s(110)), (s(104), s(110))] + curve
fd.polygon(fold_poly, fill=hex_rgb('#D9CBAC', 255))
# Fold crease line
fd.line([s(80), s(110), s(104), s(86)],
        fill=hex_rgb('#C9A23A', int(255*0.6)), width=max(1, s(1)))
canvas = composite(canvas, fold_layer)

# 9. Microphone  cx=71,cy=82
ml = new_layer()
md = ImageDraw.Draw(ml)
cx, cy = 71, 82
# Glow
md.ellipse([s(cx-10), s(cy-10), s(cx+10), s(cy+10)],
           fill=hex_rgb('#C9A23A', int(255*0.15)))
# Body  x=67,y=74,w=8,h=12,rx=4
md.rounded_rectangle([s(67), s(74), s(67+8), s(74+12)],
                     radius=s(4), fill=hex_rgb('#C9A23A', 255))
# Arc  M63 82 Q63 90 71 90 Q79 90 79 82
arc1 = bezier_quad((s(63), s(82)), (s(63), s(90)), (s(71), s(90)))
arc2 = bezier_quad((s(71), s(90)), (s(79), s(90)), (s(79), s(82)))
arc_pts = arc1 + arc2[1:]
lw = max(2, s(2))
for i in range(len(arc_pts)-1):
    md.line([arc_pts[i], arc_pts[i+1]], fill=hex_rgb('#C9A23A',255), width=lw)
# Stand
md.line([s(71), s(90), s(71), s(96)], fill=hex_rgb('#C9A23A',255), width=lw)
# Base
md.line([s(66), s(96), s(76), s(96)], fill=hex_rgb('#C9A23A',255), width=lw)
canvas = composite(canvas, ml)

# ── Save ─────────────────────────────────────────────────────────────────
out = 'Sources/Resources/Assets.xcassets/AppIcon.appiconset/fanyeapp.png'
canvas.convert('RGB').save(out, 'PNG')
print(f"Saved {SIZE}x{SIZE} → {out}")
