import sys, os, json, re, math

def f(v):
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s

def P(x, y):
    return f"{f(x)} {f(y)}"

def poly(pts, radii):
    n = len(pts)
    segs = []
    for i in range(n):
        p0, v, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        r = radii[i]
        if r == 0:
            segs.append((v, None, None, v))
            continue
        def toward(a, b, d):
            dx, dy = b[0] - a[0], b[1] - a[1]
            L = (dx * dx + dy * dy) ** 0.5
            d = min(d, L / 2)
            return (a[0] + dx / L * d, a[1] + dy / L * d)
        a = toward(v, p0, r)
        b = toward(v, p2, r)
        c1 = (a[0] + 2 / 3 * (v[0] - a[0]), a[1] + 2 / 3 * (v[1] - a[1]))
        c2 = (b[0] + 2 / 3 * (v[0] - b[0]), b[1] + 2 / 3 * (v[1] - b[1]))
        segs.append((a, c1, c2, b))
    d = f"M{P(*segs[0][3])}"
    for a, c1, c2, b in segs[1:] + segs[:1]:
        d += f"L{P(*a)}"
        if c1:
            d += f"C{P(*c1)} {P(*c2)} {P(*b)}"
    return d + "Z"

def hole(pts, radii):
    n = len(pts)
    a = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    return poly(pts[::-1], radii[::-1]) if a > 0 else poly(pts, radii)

K = 0.5523

def corner(v, a_from, b_to, r):
    def toward(p, q, d):
        dx, dy = q[0] - p[0], q[1] - p[1]
        L = (dx * dx + dy * dy) ** 0.5
        return (p[0] + dx / L * d, p[1] + dy / L * d)
    a = toward(v, a_from, r)
    b = toward(v, b_to, r)
    c1 = (a[0] + 2 / 3 * (v[0] - a[0]), a[1] + 2 / 3 * (v[1] - a[1]))
    c2 = (b[0] + 2 / 3 * (v[0] - b[0]), b[1] + 2 / 3 * (v[1] - b[1]))
    return f"L{P(*a)}C{P(*c1)} {P(*c2)} {P(*b)}"

def upper_arc(cx, cy, rx, ry, left_to_right=True):
    if left_to_right:
        return (f"C{P(cx - rx, cy - ry * K)} {P(cx - rx * K, cy - ry)} {P(cx, cy - ry)}"
                f"C{P(cx + rx * K, cy - ry)} {P(cx + rx, cy - ry * K)} {P(cx + rx, cy)}")
    return (f"C{P(cx + rx, cy - ry * K)} {P(cx + rx * K, cy - ry)} {P(cx, cy - ry)}"
            f"C{P(cx - rx * K, cy - ry)} {P(cx - rx, cy - ry * K)} {P(cx - rx, cy)}")

def lower_arc_rtl(cx, cy, rx, ry):
    return (f"C{P(cx + rx, cy + ry * K)} {P(cx + rx * K, cy + ry)} {P(cx, cy + ry)}"
            f"C{P(cx - rx * K, cy + ry)} {P(cx - rx, cy + ry * K)} {P(cx - rx, cy)}")

def lower_arc_ltr(cx, cy, rx, ry):
    return (f"C{P(cx - rx, cy + ry * K)} {P(cx - rx * K, cy + ry)} {P(cx, cy + ry)}"
            f"C{P(cx + rx * K, cy + ry)} {P(cx + rx, cy + ry * K)} {P(cx + rx, cy)}")

def ellipse_hole(cx, cy, rx, ry):
    d = f"M{P(cx + rx, cy)}" + upper_arc(cx, cy, rx, ry, left_to_right=False)
    d += (f"C{P(cx - rx, cy + ry * K)} {P(cx - rx * K, cy + ry)} {P(cx, cy + ry)}"
          f"C{P(cx + rx * K, cy + ry)} {P(cx + rx, cy + ry * K)} {P(cx + rx, cy)}Z")
    return d

def can(w, gap, rim):
    cx = w / 2
    rx, ry, ey = w * 0.38, 4.5, -76.5
    sh = -69.0
    cut1 = -64.0
    body_top = cut1 + gap
    cut2 = 0.5
    base_top = cut2 + gap
    bs, be, bx, bry = 6.0 + (gap - 3.5) / 2, 9.5, w * 0.4, 3.5

    top = f"M{P(0, cut1)}"
    top += corner((0, sh), (0, cut1), (cx - rx, ey), 3)
    top += f"L{P(cx - rx, ey)}" + upper_arc(cx, ey, rx, ry)
    top += corner((w, sh), (cx + rx, ey), (w, cut1), 3)
    top += f"L{P(w, cut1)}Z"
    top += ellipse_hole(cx, ey + rim * 0.15, rx - rim, ry - rim * 0.45)

    body = f"M{P(0, body_top)}L{P(w, body_top)}L{P(w, cut2)}L{P(0, cut2)}Z"

    base = f"M{P(0, base_top)}L{P(w, base_top)}"
    base += corner((w, bs), (w, base_top), (cx + bx, be), 2.5)
    base += f"L{P(cx + bx, be)}" + lower_arc_rtl(cx, be, bx, bry)
    base += corner((0, bs), (cx - bx, be), (0, base_top), 2.5)
    base += "Z"
    return w, [top, body, base]

def sodacan(i):
    return can(*[(48.0, 2.4, 3.6), (50.0, 3.5, 4.6), (53.0, 5.0, 6.0)][i])

def slimcan(i):
    return can(*[(35.0, 2.4, 3.6), (37.0, 3.5, 4.6), (40.0, 5.0, 6.0)][i])

def waterglass(i):
    w, gap, rim = [(52.0, 2.4, 3.2), (54.0, 3.5, 4.2), (57.0, 5.0, 5.6)][i]
    cx = w / 2
    ht, ry, ey = w / 2, 5.5, -75.5
    hb, bry, yB = w * 0.37, 4.5, 8.0
    def half(y):
        return ht + (hb - ht) * (y - ey) / (yB - ey)
    yc = -3.0
    yb = yc + gap

    body = f"M{P(cx - ht, ey)}" + upper_arc(cx, ey, ht, ry)
    body += f"L{P(cx + half(yc), yc)}" + lower_arc_rtl(cx, yc, half(yc), bry)
    body += "Z"
    body += ellipse_hole(cx, ey + rim * 0.15, ht - rim, ry - rim * 0.45)

    base = f"M{P(cx - half(yb), yb)}" + lower_arc_ltr(cx, yb, half(yb), bry)
    base += f"L{P(cx + hb, yB)}" + lower_arc_rtl(cx, yB, hb, bry)
    base += "Z"
    return w, [body, base]

def tumbler(g, t):
    cx = 23
    lid = poly([(cx - 23.5, -71), (cx + 23.5, -71), (cx + 23.5, -63), (cx - 23.5, -63)], [3, 3, 1, 1])
    sw = t * 1.15
    straw = poly([(cx - 3 - sw / 2, -87), (cx - 3 + sw / 2, -87), (cx - 3 + sw / 2, -70), (cx - 3 - sw / 2, -70)], [2, 2, 0, 0])
    y0 = -63 + g
    body = poly([(cx - 22, y0), (cx + 22, y0), (cx + 17, -10), (cx + 14, -3), (cx + 14, 12.5),
                 (cx - 14, 12.5), (cx - 14, -3), (cx - 17, -10)],
                [1, 1, 4, 4, 3.5, 3.5, 4, 4])
    hx0, hx1, hy0, hy1 = cx + 12, 62, -57, -22
    handle = poly([(hx0, hy0), (hx1, hy0), (hx1, hy1), (hx0, hy1)], [0, 8, 8, 0])
    handle += hole([(hx0, hy0 + t), (hx1 - t, hy0 + t), (hx1 - t, hy1 - t), (hx0, hy1 - t)], [0, 3, 3, 0])
    return 62.5, shifted([straw, lid, body, handle], 0.5)

def fliplid(g, t):
    W = 36
    body = poly([(0, -52), (W, -52), (W, 12.5), (0, 12.5)], [2, 2, 6, 6])
    lx1, ly0 = 24, -86
    slope_y = -72 + 12 * lx1 / W
    lid = poly([(0, -52 - g), (0, ly0), (lx1, ly0), (lx1, slope_y), (W, -60), (W, -52 - g)], [1.5, 7, 7, 3, 3, 1.5])
    lid += hole([(t, ly0 + t), (lx1 - t, ly0 + t), (lx1 - t, -73), (t, -73)], [3, 3, 1.5, 1.5])
    return W, [body, lid]

def loopcap(g, t):
    W, cx = 50, 25
    band = 3.5
    body = poly([(cx - 13, -57), (cx + 13, -57), (W, -47), (W, band), (0, band), (0, -47)], [1.5, 1.5, 10, 0, 0, 10])
    base = poly([(0, band + g), (W, band + g), (W, 12.5), (0, 12.5)], [0, 0, 5, 5])
    cy1 = -57 - g
    lx0, lx1, ly0, ly1 = cx - 12.5, cx + 12.5, -86, cy1 - 9
    cap = poly([(cx - 16.5, cy1), (cx - 16.5, ly1), (lx0, ly1), (lx0, ly0), (lx1, ly0), (lx1, ly1), (cx + 16.5, ly1), (cx + 16.5, cy1)],
               [1.5, 2, 1.5, 6, 6, 1.5, 2, 1.5])
    cap += hole([(lx0 + t, ly0 + t), (lx1 - t, ly0 + t), (lx1 - t, ly1 + 1 - 2), (lx0 + t, ly1 + 1 - 2)], [2.5, 2.5, 1.5, 1.5])
    return W, [body, base, cap]

def insulated(g, t):
    W, cx = 36, 18
    band = 3
    body = poly([(cx - 9.5, -69), (cx + 9.5, -69), (cx + 9.5, -64), (W, -44), (W, band), (0, band), (0, -44), (cx - 9.5, -64)],
                [1, 1, 8, 16, 0, 0, 16, 8])
    base = poly([(0, band + g), (W, band + g), (W, 12.5), (0, 12.5)], [0, 0, 5, 5])
    cy1 = -69 - g
    cap = poly([(cx - 11, cy1 - 12), (cx + 11, cy1 - 12), (cx + 11, cy1), (cx - 11, cy1)], [4, 4, 1, 1])
    return W, [body, base, cap]

def squeeze(g, t):
    W, cx = 40, 20
    body = poly([(3, -60), (W - 3, -60), (W, -42), (W - 6.5, -18), (W, 4), (W, 12.5), (0, 12.5), (0, 4), (6.5, -18), (0, -42)],
                [3, 3, 10, 22, 10, 5, 5, 10, 22, 10])
    cy1 = -60 - g
    cap = poly([(2, cy1 - 9), (W - 2, cy1 - 9), (W - 2, cy1), (2, cy1)], [2, 2, 1.5, 1.5])
    nozzle = poly([(cx - 8, cy1 - 8), (cx - 4, -85), (cx + 4, -85), (cx + 8, cy1 - 8)], [0, 2, 2, 0])
    return W, [body, cap, nozzle]

def shaker(g, t):
    W, cx = 46, 23
    body = poly([(0, -56), (W, -56), (W - 4.5, 12.5), (4.5, 12.5)], [1, 1, 5, 5])
    for y in (-42, -30, -18):
        body += hole([(6, y), (14, y), (14, y + g), (6, y + g)], [g / 2] * 4)
    y1 = -56 - g
    lid = poly([(-1, y1 - 8), (W + 1, y1 - 8), (W + 1, y1), (-1, y1)], [2, 2, 1, 1])
    dome = poly([(cx - 15, y1 - 7), (cx - 10, -80), (cx + 12, -80), (cx + 15, y1 - 7)], [0, 4, 4, 0])
    spout = poly([(cx - 11, -77), (cx - 13, -86), (cx - 5, -86), (cx - 3, -78)], [0, 2, 2, 0])
    return W + 2, shifted([body, lid, dome, spout], 1)

def inset(pts, dists):
    n = len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    sign = 1 if area > 0 else -1
    lines = []
    for i in range(n):
        p, q = pts[i], pts[(i + 1) % n]
        dx, dy = q[0] - p[0], q[1] - p[1]
        L = (dx * dx + dy * dy) ** 0.5
        nx, ny = -dy / L * sign, dx / L * sign
        d = dists[i]
        lines.append(((p[0] + nx * d, p[1] + ny * d), (dx, dy)))
    out = []
    for i in range(n):
        (p1, d1), (p2, d2) = lines[i - 1], lines[i]
        den = d1[0] * d2[1] - d1[1] * d2[0]
        u = ((p2[0] - p1[0]) * d2[1] - (p2[1] - p1[1]) * d2[0]) / den
        out.append((p1[0] + d1[0] * u, p1[1] + d1[1] * u))
    return out

def carton(g, t):
    fw, dx, dy = 30, 16, -6
    top, bot, rise, fin_h = -48, 12.5, 17, 6
    h = g / 2
    A, B, C, D = (0, top), (fw, top), (fw, bot), (0, bot)
    E = (fw / 2, top - rise)
    E2, B2, C2 = (E[0] + dx, E[1] + dy), (fw + dx, top + dy), (fw + dx, bot + dy)
    r, rb = 1.5, 3
    front = poly(inset([A, B, C, D], [h, h, 0, 0]), [r, r, r, rb])
    gable = poly(inset([A, E, B], [0, h, h]), [r, r, r])
    side = poly(inset([B, B2, C2, C], [h, 0, 0, h]), [r, r, rb, r])
    roof = poly(inset([E, E2, B2, B], [0, 0, h, h]), [r, r, r, r])
    lift = g * math.hypot(dx, dy) / dx
    F1, F2 = (E[0], E[1] - lift), (E2[0], E2[1] - lift)
    fin = poly([F1, F2, (F2[0], F2[1] - fin_h), (F1[0], F1[1] - fin_h)], [r, r, r, r])
    return fw + dx, [front, gable, side, roof, fin]

def area(pts):
    n = len(pts)
    return sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))

def circle(cx, cy, r):
    return (f"M{P(cx - r, cy)}" + upper_arc(cx, cy, r, r)
            + f"C{P(cx + r, cy + r * K)} {P(cx + r * K, cy + r)} {P(cx, cy + r)}"
            + f"C{P(cx - r * K, cy + r)} {P(cx - r, cy + r * K)} {P(cx - r, cy)}Z")

def segment(p, q, w, r):
    dx, dy = q[0] - p[0], q[1] - p[1]
    L = (dx * dx + dy * dy) ** 0.5
    nx, ny = -dy / L * w / 2, dx / L * w / 2
    pts = [(p[0] + nx, p[1] + ny), (q[0] + nx, q[1] + ny), (q[0] - nx, q[1] - ny), (p[0] - nx, p[1] - ny)]
    if area(pts) < 0:
        pts = pts[::-1]
    return poly(pts, [r] * 4)

def arc(cx, cy, rx, ry, a0, a1):
    def pt(a):
        return (cx + rx * math.cos(a), cy - ry * math.sin(a))
    def dv(a):
        return (-rx * math.sin(a), -ry * math.cos(a))
    steps = max(1, math.ceil(abs(a1 - a0) / (math.pi / 2) - 1e-9))
    d = ""
    for i in range(steps):
        sa = a0 + (a1 - a0) * i / steps
        sb = a0 + (a1 - a0) * (i + 1) / steps
        k = 4 / 3 * math.tan((sb - sa) / 4)
        p0, p3 = pt(sa), pt(sb)
        d0, d3 = dv(sa), dv(sb)
        c1 = (p0[0] + k * d0[0], p0[1] + k * d0[1])
        c2 = (p3[0] - k * d3[0], p3[1] - k * d3[1])
        d += f"C{P(*c1)} {P(*c2)} {P(*p3)}"
    return d

def arc_c(c, r, a0, sweep):
    steps = max(1, math.ceil(abs(sweep) / (math.pi / 2) - 1e-9))
    d = ""
    for i in range(steps):
        sa, sb = a0 + sweep * i / steps, a0 + sweep * (i + 1) / steps
        k = 4 / 3 * math.tan((sb - sa) / 4)
        p0 = (c[0] + r * math.cos(sa), c[1] + r * math.sin(sa))
        p3 = (c[0] + r * math.cos(sb), c[1] + r * math.sin(sb))
        c1 = (p0[0] - k * r * math.sin(sa), p0[1] + k * r * math.cos(sa))
        c2 = (p3[0] + k * r * math.sin(sb), p3[1] - k * r * math.cos(sb))
        d += f"C{P(*c1)} {P(*c2)} {P(*p3)}"
    return d

def straw_path(pts, w, R=0, flat_start=False):
    p0, p1 = pts[0], pts[-1]
    u = lambda a, b: ((b[0] - a[0]) / math.dist(a, b), (b[1] - a[1]) / math.dist(a, b))
    u1, u2 = u(p0, pts[1]), u(pts[-2], p1)
    f1, f2 = math.atan2(u1[1], u1[0]), math.atan2(u2[1], u2[0])
    sg = 1
    off = lambda p, f, s: (p[0] - s * w / 2 * math.sin(f), p[1] + s * w / 2 * math.cos(f))
    if area([off(p0, f1, 1), off(p1, f2, 1), off(p1, f2, -1), off(p0, f1, -1)]) < 0:
        sg = -1
    fillet = None
    if len(pts) == 3:
        b = pts[1]
        th = math.acos(max(-1, min(1, u1[0] * u2[0] + u1[1] * u2[1])))
        dd = R * math.tan(th / 2)
        T1, T2 = (b[0] - u1[0] * dd, b[1] - u1[1] * dd), (b[0] + u2[0] * dd, b[1] + u2[1] * dd)
        N = (-u1[1], u1[0])
        if N[0] * u2[0] + N[1] * u2[1] < 0:
            N = (-N[0], -N[1])
        C = (T1[0] + N[0] * R, T1[1] + N[1] * R)
        a1, a2 = math.atan2(T1[1] - C[1], T1[0] - C[0]), math.atan2(T2[1] - C[1], T2[0] - C[0])
        sw = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        fillet = (T1, T2, C, a1, sw)
    def side(s, forward):
        A = lambda p, f: off(p, f, s * sg)
        if not fillet:
            return f"L{P(*A(p1, f2))}" if forward else f"L{P(*A(p0, f1))}"
        T1, T2, C, a1, sw = fillet
        if forward:
            r = math.dist(C, A(T1, f1))
            return f"L{P(*A(T1, f1))}" + arc_c(C, r, a1, sw) + f"L{P(*A(p1, f2))}"
        r = math.dist(C, A(T2, f2))
        return f"L{P(*A(T2, f2))}" + arc_c(C, r, a1 + sw, -sw) + f"L{P(*A(p0, f1))}"
    d = f"M{P(*off(p0, f1, sg))}" + side(1, True)
    d += arc_c(p1, w / 2, f2 + sg * math.pi / 2, -sg * math.pi)
    d += side(-1, False)
    if not flat_start:
        d += arc_c(p0, w / 2, f1 - sg * math.pi / 2, -sg * math.pi)
    return d + "Z"

def rounded_rim(cx, cy, rx, ry, left_to, right_to, r, da=0.5):
    def toward(p, q, dist):
        dx, dy = q[0] - p[0], q[1] - p[1]
        L = (dx * dx + dy * dy) ** 0.5
        return (p[0] + dx / L * dist, p[1] + dy / L * dist)
    def blend(a, v, b):
        c1 = (a[0] + 2 / 3 * (v[0] - a[0]), a[1] + 2 / 3 * (v[1] - a[1]))
        c2 = (b[0] + 2 / 3 * (v[0] - b[0]), b[1] + 2 / 3 * (v[1] - b[1]))
        return f"C{P(*c1)} {P(*c2)} {P(*b)}"
    vl, vr = (cx - rx, cy), (cx + rx, cy)
    al, ar = toward(vl, left_to, r), toward(vr, right_to, r)
    bl = (cx + rx * math.cos(math.pi - da), cy - ry * math.sin(math.pi - da))
    br = (cx + rx * math.cos(da), cy - ry * math.sin(da))
    return f"M{P(*al)}" + blend(al, vl, bl) + arc(cx, cy, rx, ry, math.pi - da, da) + blend(br, vr, ar)

def soda_bottle(g, t):
    W, cx = 30, 15
    cap = poly([(cx - 6.5, -86), (cx + 6.5, -86), (cx + 6.5, -80), (cx - 6.5, -80)], [1.5, 1.5, 1, 1])
    y0 = -80 + g
    body = poly([(cx - 5, y0), (cx + 5, y0), (cx + 5.5, -62), (cx + 13, -44), (cx + 10.5, -24), (cx + 15, -4),
                 (cx + 13.5, 12.5), (cx - 13.5, 12.5), (cx - 15, -4), (cx - 10.5, -24), (cx - 13, -44), (cx - 5.5, -62)],
                [1, 1, 10, 12, 16, 10, 3, 3, 10, 16, 12, 10])
    return W, [cap, body]

def beer_bottle(g, t):
    W, cx = 30, 15
    cap = poly([(cx - 6, -86), (cx + 6, -86), (cx + 6, -81), (cx - 6, -81)], [1.5, 1.5, 1, 1])
    y0 = -81 + g
    upper = poly([(cx - 4.5, y0), (cx + 4.5, y0), (cx + 4.5, -62), (W, -40), (W, -28), (0, -28), (0, -40), (cx - 4.5, -62)],
                 [0.8, 0.8, 8, 14, 0, 0, 14, 8])
    label = poly([(0, -28 + g), (W, -28 + g), (W, -4), (0, -4)], [0, 0, 0, 0])
    base = poly([(0, -4 + g), (W, -4 + g), (W, 12.5), (0, 12.5)], [0, 0, 4, 4])
    return W, [cap, upper, label, base]

def hot_cup(g, t):
    W, cx = 48, 24
    lid = poly([(0, -63), (0, -69), (5, -70), (8, -79), (W - 8, -79), (W - 5, -70), (W, -69), (W, -63)],
               [1.5, 1.5, 1.5, 3, 3, 1.5, 1.5, 1.5])
    yt, yb = -63 + g, 12.5
    def half(y):
        return 22 + (16 - 22) * (y - yt) / (yb - yt)
    def band(y0, y1, r0, r1):
        return poly([(cx - half(y0), y0), (cx + half(y0), y0), (cx + half(y1), y1), (cx - half(y1), y1)], [r0, r0, r1, r1])
    y1, y2 = -44, -14
    return W, [lid, band(yt, y1, 1, 0), band(y1 + g, y2, 0, 0), band(y2 + g, yb, 0, 3.5)]

def dome_cup(g, t):
    W, cx = 46, 23
    sw = t * 0.9
    straw = straw_path([(cx + 3, -68), (cx + 3, -87 + sw / 2)], sw)
    rim = poly([(0, -60), (W, -60), (W, -55), (0, -55)], [1.5, 1.5, 1.5, 1.5])
    dome = f"M{P(cx - 19, -59)}" + upper_arc(cx, -59, 19, 14) + f"L{P(cx + 19, -58)}L{P(cx - 19, -58)}Z"
    yt = -55 + g
    cup = poly([(cx - 21, yt), (cx + 21, yt), (cx + 15, 12.5), (cx - 15, 12.5)], [1, 1, 3.5, 3.5])
    return W, [straw, rim, dome, cup]

def boba(g, t):
    W, cx = 44, 22
    rim = poly([(0, -66), (W, -66), (W, -61), (0, -61)], [1.5, 1.5, 1.5, 1.5])
    yt = -61 + g
    cup = poly([(cx - 20.5, yt), (cx + 20.5, yt), (cx + 15, 12.5), (cx - 15, 12.5)], [1, 1, 3.5, 3.5])
    r = 4.4 - g * 0.35
    for px, py in ((-10, 3), (0, 4.5), (10, 3), (-5, -4.5), (5, -4.5)):
        cup += ellipse_hole(cx + px, py, r, r)
    straw = straw_path([(cx - 1.5, -63), (cx + 5.7, -84.2)], t * 1.35, flat_start=True)
    return W, [rim, cup, straw]

def cocktail(g, t):
    W, cx = 50, 25
    sw = t * 0.95
    ry, top = 4.5, -78
    vr, vl = (cx + sw / 2, -40), (cx - sw / 2, -40)
    bowl = rounded_rim(cx, top, cx, ry, vl, vr, 3)
    bowl += corner(vr, (W, top), (cx + sw / 2, 8), 6)
    bowl += f"L{P(cx + sw / 2, 8)}L{P(cx - sw / 2, 8)}"
    bowl += corner(vl, (cx - sw / 2, 8), (0, top), 6)
    bowl += "Z"
    rim = 4.2 * t / 6
    bowl += ellipse_hole(cx, top + rim * 0.15, cx - rim, ry - rim * 0.45)
    foot = f"M{P(cx - 16, 8.5)}" + upper_arc(cx, 8.5, 16, 4) + lower_arc_rtl(cx, 8.5, 16, 4) + "Z"
    return W, [bowl, foot]

def beer_stein(g, t):
    W, bw = 60, 44
    foam = poly([(0, -70), (bw, -71), (bw, -61), (0, -61)], [0, 0, 1.5, 1.5])
    foam += circle(8.5, -70, 8.5) + circle(22, -74, 11) + circle(35.5, -71, 8.5)
    yt = -61 + g
    body = poly([(0, yt), (bw, yt), (bw, 12.5), (0, 12.5)], [1, 1, 5, 5])
    for x in (11, 22, 33):
        body += hole([(x - g / 2, -48), (x + g / 2, -48), (x + g / 2, -2), (x - g / 2, -2)], [g / 2] * 4)
    hx0, hy0, hy1 = 38, -52, -8
    handle = poly([(hx0, hy0), (W, hy0), (W, hy1), (hx0, hy1)], [0, 9, 9, 0])
    handle += hole([(hx0, hy0 + t), (W - t, hy0 + t), (W - t, hy1 - t), (hx0, hy1 - t)], [0, 3.5, 3.5, 0])
    return W, [foam, body, handle]

def juice_box(g, t):
    fw, dx, dy = 28, 13, -9
    top, bot = -44, 12.5
    h = g / 2
    A, B, C, D = (0, top), (fw, top), (fw, bot), (0, bot)
    A2, B2, C2 = (dx, top + dy), (fw + dx, top + dy), (fw + dx, bot + dy)
    r, rb = 1.5, 3
    front = poly(inset([A, B, C, D], [h, h, 0, 0]), [r, r, r, rb])
    lid = poly(inset([A2, B2, B, A], [0, h, h, 0]), [r, r, r, r])
    side = poly(inset([B, B2, C2, C], [h, 0, 0, h]), [r, r, rb, r])
    straw = straw_path([(21, -50), (21, -61), (11, -73)], t * 0.8, 5)
    return fw + dx, [front, lid, side, straw]

def xform(d, fn):
    out = ""
    for tok in re.split(r"([MLCZ])", d):
        if tok in ("M", "L", "C", "Z") or not tok.strip():
            out += tok
            continue
        vals = [float(v) for v in tok.split()]
        pts = [fn(vals[k], vals[k + 1]) for k in range(0, len(vals), 2)]
        out += " ".join(P(*p) for p in pts)
    return out

def shifted(paths, dx):
    return [xform(d, lambda x, y: (x + dx, y)) for d in paths]

def rotated(d, angle, dx, dy):
    c, s_ = math.cos(angle), math.sin(angle)
    return xform(d, lambda x, y: (dx + x * c - y * s_, dy + x * s_ + y * c))

def rocks_glass(g, t):
    W, cx = 56, 28
    ht, ry, ey = 28, 5, -62
    hb, bry, yB = 25.5, 4.5, 8.0
    def half(y):
        return ht + (hb - ht) * (y - ey) / (yB - ey)
    yc = -4.0
    yb = yc + g
    body = f"M{P(cx - ht, ey)}" + upper_arc(cx, ey, ht, ry)
    body += f"L{P(cx + half(yc), yc)}" + lower_arc_rtl(cx, yc, half(yc), bry) + "Z"
    rim = 4.2 * t / 6
    body += ellipse_hole(cx, ey + rim * 0.15, ht - rim, ry - rim * 0.45)
    cube = [(-7.5, -7.5), (7.5, -7.5), (7.5, 7.5), (-7.5, 7.5)]
    for ox, oy, a in ((cx - 9, -38, 0.26), (cx + 9.5, -24, -0.35)):
        c, s_ = math.cos(a), math.sin(a)
        pts = [(ox + x * c - y * s_, oy + x * s_ + y * c) for x, y in cube]
        body += hole(pts, [3] * 4)
    base = f"M{P(cx - half(yb), yb)}" + lower_arc_ltr(cx, yb, half(yb), bry)
    base += f"L{P(cx + hb, yB)}" + lower_arc_rtl(cx, yB, hb, bry) + "Z"
    return W, [body, base]

def champagne_flute(g, t):
    W, cx = 28, 14
    hw, top, ry = 10.5, -82.5, 3.8
    sw = t * 0.95
    bulge, waist = (cx + 11.5, -60), (cx + sw / 2, -27)
    lb, lw = (cx - 11.5, -60), (cx - sw / 2, -27)
    flute = rounded_rim(cx, top, hw, ry, lb, bulge, 1.5)
    flute += corner(bulge, (cx + hw, top), waist, 14)
    flute += corner(waist, bulge, (cx + sw / 2, 8), 9)
    flute += f"L{P(cx + sw / 2, 8)}L{P(cx - sw / 2, 8)}"
    flute += corner(lw, (cx - sw / 2, 8), lb, 9)
    flute += corner(lb, lw, (cx - hw, top), 14)
    flute += "Z"
    rim = 4.2 * t / 6 * 0.8
    flute += ellipse_hole(cx, top + rim * 0.15, hw - rim, ry - rim * 0.45)
    br = 3.0 - g * 0.15
    for bx, by in ((-2, -42), (2.5, -54), (-1.5, -66)):
        flute += ellipse_hole(cx + bx, by, br, br)
    foot = f"M{P(cx - 14, 8.5)}" + upper_arc(cx, 8.5, 14, 4) + lower_arc_rtl(cx, 8.5, 14, 4) + "Z"
    return W, [flute, foot]

def tropical(g, t):
    cx = 18
    top, hw, ry = -50, 18, 3.5
    sw = t * 0.95
    rb, lb = (cx + 18.5, -32), (cx - 18.5, -32)
    rw, lw = (cx + sw / 2, -8), (cx - sw / 2, -8)
    glass = rounded_rim(cx, top, hw, ry, lb, rb, 1.5)
    glass += corner(rb, (cx + hw, top), rw, 14)
    glass += corner(rw, rb, (cx + sw / 2, 8), 8)
    glass += f"L{P(cx + sw / 2, 8)}L{P(cx - sw / 2, 8)}"
    glass += corner(lw, (cx - sw / 2, 8), lb, 8)
    glass += corner(lb, lw, (cx - hw, top), 14)
    glass += "Z"
    rim = 4.2 * t / 6
    glass += ellipse_hole(cx, top + rim * 0.15, hw - rim, ry - rim * 0.45)
    foot = f"M{P(cx - 15, 8.5)}" + upper_arc(cx, 8.5, 15, 4) + lower_arc_rtl(cx, 8.5, 15, 4) + "Z"
    tip = (cx + 13, -66)
    pole = straw_path([(cx + 4, -42), tip], t * 0.7)
    angle = math.atan2(tip[0] - cx - 4, -(tip[1] + 42))
    canopy = rotated(rounded_rim(0, 0, 16, 8.5, (0, 0), (0, 0), 2, 0.35) + "Z", angle, *tip)
    return 46.25, shifted([glass, foot, pole, canopy], 0.15)

def stick_pack(g, t):
    W, teeth, depth = 34, 5, 3
    def zig(y, up):
        step = W / teeth
        pts = []
        for k in range(teeth + 1):
            pts.append((k * step, y))
            if k < teeth:
                pts.append((k * step + step / 2, y - depth if up else y + depth))
        return pts
    top_seal = [(0, -66 - g)] + zig(-81, True) + [(W, -66 - g)]
    top = poly(top_seal, [1.5] + [1.4] * (len(top_seal) - 2) + [1.5])
    body = poly([(0, -66), (W, -66), (W, -2), (0, -2)], [1.5] * 4)
    bolt = [(19.5, -50), (9, -31), (16, -31), (14, -16), (25, -37), (18, -37)]
    body += hole(bolt, [1] * len(bolt))
    bottom_seal = [(0, -2 + g), (W, -2 + g)] + zig(12.5 - depth, False)[::-1]
    bottom = poly(bottom_seal, [1.5, 1.5] + [1.4] * (len(bottom_seal) - 2))
    return W, [top, body, bottom]

def pitcher(g, t):
    W = 64
    upper = poly([(0, -78), (42, -72), (44.5, -42), (7.2, -42), (8.5, -62)], [4, 2, 0, 0, 8])
    lower = poly([(7, -42 + g), (44.8, -42 + g), (46.5, -18), (45, 12.5), (7, 12.5), (5, -18)], [0, 0, 12, 4, 4, 12])
    hx0, hy0, hy1 = 40, -66, -14
    handle = poly([(hx0, hy0), (W, hy0), (W, hy1), (hx0, hy1)], [0, 13, 13, 0])
    handle += hole([(hx0, hy0 + t), (W - t, hy0 + t), (W - t, hy1 - t), (hx0, hy1 - t)], [0, 5, 5, 0])
    return W, [upper, lower, handle]

def coconut_w(g, t):
    rx, ry, cx, cy = 32, 34, 32, -21.5
    k = ry / rx
    rho, e = 22, math.asin(0.3)
    z0 = math.sqrt(rx * rx - rho * rho)
    ey = cy - z0 * math.cos(e) * k
    ea, eb = rho, rho * math.sin(e) * k
    s = z0 * math.tan(e) / rho
    tx, ty = rho * math.sqrt(1 - s * s), (z0 * math.cos(e) + rho * s * math.sin(e))
    al = math.atan2(ty, tx)
    tau = math.asin(s)
    shell = f"M{P(cx - rx * math.cos(al), cy - ry * math.sin(al))}"
    shell += arc(cx, ey, ea, eb, math.pi - tau, tau)
    shell += arc(cx, cy, rx, ry, al, -math.pi - al) + "Z"
    rim = 4.2 * t / 6
    shell += ellipse_hole(cx, ey + rim * 0.15, ea - rim, eb - rim * 0.45)
    straw = straw_path([(cx + 2, ey + 8), (cx + 15, ey - 25)], t * 0.8)
    return 2 * rx, [shell, straw]

def citrus_w(g, t):
    R0, cx, cy = 38, 38, -35
    peel = 5
    ring_out = R0 - peel
    ring_in = ring_out - g
    seg_r = ring_in - 2.5
    slice_ = circle(cx, cy, R0) + ellipse_hole(cx, cy, ring_out, ring_out) + circle(cx, cy, ring_in)
    n = 8
    for k in range(n):
        a0 = 2 * math.pi * k / n + math.pi / n
        a1 = a0 + 2 * math.pi / n
        outer = [(cx + seg_r * math.cos(a0 + (a1 - a0) * j / 3), cy + seg_r * math.sin(a0 + (a1 - a0) * j / 3)) for j in range(4)]
        pts = [(cx, cy)] + outer
        if area(pts) < 0:
            pts = pts[::-1]
        d = [g / 2 if (i == 0 or i == len(pts) - 1) else 0 for i in range(len(pts))]
        ins = inset(pts, d)
        radii = [1.5 if i == 0 else 3 if (i == 1 or i == len(ins) - 1) else 30 for i in range(len(ins))]
        slice_ += hole(ins, radii)
    return 2 * R0, [slice_]

WEIGHT_PARAMS = [(2.4, 4.5), (3.5, 6.0), (5.0, 8.0)]

def coconut(i):
    return coconut_w(*WEIGHT_PARAMS[i])

def citrus(i):
    return citrus_w(*WEIGHT_PARAMS[i])

def solid(pts, radii):
    return poly(pts, radii) if area(pts) > 0 else poly(pts[::-1], radii[::-1])

def shot_glass(g, t):
    W, cx = 46, 23
    ht, ry, ey = 23, 4.5, -50
    hb, bry, yB = 17, 4.5, 8.0
    def half(y):
        return ht + (hb - ht) * (y - ey) / (yB - ey)
    yc, cry = -17.0, 6.0
    yb = yc + g
    body = f"M{P(cx - ht, ey)}" + upper_arc(cx, ey, ht, ry)
    body += f"L{P(cx + half(yc), yc)}" + lower_arc_rtl(cx, yc, half(yc), cry) + "Z"
    rim = 4.2 * t / 6
    body += ellipse_hole(cx, ey + rim * 0.15, ht - rim, ry - rim * 0.45)
    base = f"M{P(cx - half(yb), yb)}" + lower_arc_ltr(cx, yb, half(yb), cry)
    base += f"L{P(cx + hb, yB)}" + lower_arc_rtl(cx, yB, hb, bry) + "Z"
    return W, [body, base]

def bean_w(g, t, knockout=None):
    a, b, k, rot = 24, 36, 8.5, 0.6
    n_arc, n_cut = 36, 28
    def crease(y, side):
        u = math.pi * y / (2 * b)
        c = k * math.sin(2 * u) * math.cos(u)
        dc = k * math.pi / (2 * b) * (2 * math.cos(2 * u) * math.cos(u) - math.sin(2 * u) * math.sin(u))
        L = math.hypot(1, dc)
        return (c + side * g / 2 / L, y - side * g / 2 * dc / L)
    def outside(p):
        return (p[0] / a) ** 2 + (p[1] / b) ** 2 - 1
    def cross(side, y0, y1):
        for _ in range(60):
            m = (y0 + y1) / 2
            if (outside(crease(m, side)) > 0) == (outside(crease(y0, side)) > 0):
                y0 = m
            else:
                y1 = m
        return (y0 + y1) / 2
    halves = []
    for side in (1, -1):
        yt, yb = cross(side, -b - 8, 0), cross(side, b + 8, 0)
        cut = [crease(yt + (yb - yt) * j / (n_cut - 1), side) for j in range(n_cut)]
        pt, pb = cut[0], cut[-1]
        ft, fb = math.atan2(pt[1] / b, pt[0] / a), math.atan2(pb[1] / b, pb[0] / a)
        f0, f1 = fb, ft
        if side == 1 and f1 > f0:
            f1 -= 2 * math.pi
        if side == -1 and f1 < f0:
            f1 += 2 * math.pi
        rim = [(a * math.cos(f0 + (f1 - f0) * j / (n_arc - 1)), b * math.sin(f0 + (f1 - f0) * j / (n_arc - 1))) for j in range(1, n_arc - 1)]
        pts = cut + rim
        radii = [1.5] + [99] * (n_cut - 2) + [1.5] + [99] * (n_arc - 2)
        halves.append((pts, radii))
    c, s_ = math.cos(rot), math.sin(rot)
    rot_pts = [[(x * c - y * s_, x * s_ + y * c) for x, y in pts] for pts, _ in halves]
    xs = [p[0] for pts in rot_pts for p in pts]
    ys = [p[1] for pts in rot_pts for p in pts]
    if knockout:
        cx, cy, height = knockout
        k_ = height / (max(ys) - min(ys))
        mx, my = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        return [hole([(cx + (x - mx) * k_, cy + (y - my) * k_) for x, y in pts], radii)
                for pts, (_, radii) in zip(rot_pts, halves)]
    dx, dy = -min(xs), -35 - (min(ys) + max(ys)) / 2
    paths = [solid([(x + dx, y + dy) for x, y in pts], radii) for pts, (_, radii) in zip(rot_pts, halves)]
    return max(xs) - min(xs), paths

def coffee_bean(i):
    return bean_w(*WEIGHT_PARAMS[i])

BADGE_R = [37.4, 39.5, 42.1]
BADGE_CY = -35.25

def badge_bean(i):
    R = BADGE_R[i]
    groove = [2.6, 4.2, 6.2][i]
    height = 40
    a, b, rot = 24, 36, 0.6
    span = 2 * math.hypot(a * math.sin(rot), b * math.cos(rot))
    scale = height / span
    cuts = bean_w(groove / scale, 0, knockout=(R, BADGE_CY, height))
    return 2 * R, [circle(R, BADGE_CY, R) + "".join(cuts)]

def percent_parts(i):
    R = BADGE_R[i]
    cx, cy = R, BADGE_CY
    dot_r, slash, hx, hy, half_h = [(5.2, 3.0, 9.0, 10.5, 18.0), (6.4, 6.4, 9.6, 10.8, 18.0), (7.6, 9.6, 10.4, 11.2, 18.4)][i]
    top, bot = cy - half_h, cy + half_h
    run = 2 * hx * 1.05
    w_top = slash * math.hypot(run, 2 * half_h) / (2 * half_h)
    xt, xb = cx + run / 2, cx - run / 2
    slash_pts = [(xt - w_top / 2, top), (xt + w_top / 2, top), (xb + w_top / 2, bot), (xb - w_top / 2, bot)]
    dots = [(cx - hx, cy - hy), (cx + hx, cy + hy)]
    return R, cx, cy, dot_r, slash_pts, dots

def badge_percent(i):
    R, cx, cy, dot_r, slash_pts, dots = percent_parts(i)
    d = circle(cx, cy, R)
    d += hole(slash_pts, [1.5] * 4)
    for x, y in dots:
        d += ellipse_hole(x, y, dot_r, dot_r)
    return 2 * R, [d]

def teapot(g, t):
    s = 1.2
    g, t = g / s, t / s
    W, cx, cy = 66, 33, -12
    rx, ry, n = 22, 26, 2.6
    top, bot, steps = -36, 12.5, 24
    def side(y, sgn):
        return (cx + sgn * rx * (1 - abs((y - cy) / ry) ** n) ** (1 / n), y)
    right = [side(top + (bot - top) * j / steps, 1) for j in range(steps + 1)]
    left = [side(bot - (bot - top) * j / steps, -1) for j in range(steps + 1)]
    pts = right + left
    radii = [4] + [99] * (steps - 1) + [5, 5] + [99] * (steps - 1) + [4]
    body = solid(pts, radii)
    hw = right[0][0] - cx
    ly = top - g
    lid = f"M{P(cx - hw, ly)}" + upper_arc(cx, ly, hw, 8) + "Z" + circle(cx, ly - 11, 4.5)
    spout = solid([(0, -46), (6, -46), (13, -30), (24, -20), (24, 2), (7, -12)], [1.5, 1.5, 12, 0, 0, 10])
    hx0, hy0, hy1 = 42, -30, 2
    handle = poly([(hx0, hy0), (W, hy0), (W, hy1), (hx0, hy1)], [0, 12, 12, 0])
    handle += hole([(hx0, hy0 + t), (W - t, hy0 + t), (W - t, hy1 - t), (hx0, hy1 - t)], [0, 4, 4, 0])
    return W * s, [xform(d, lambda x, y: (x * s, 12.5 + (y - 12.5) * s)) for d in (body, lid, spout, handle)]

def gallon_jug(g, t):
    W = 48
    nx0, nx1, ntop = 6, 17, -68
    cx0, cx1, ctop = 3.5, 19.5, -77
    hl, htop = cx1 + g, -76
    body = solid([(0, -46), (nx0, -58), (nx0, ntop), (nx1, ntop), (nx1, -62), (hl, -62), (hl, htop), (W, htop), (W, 12.5), (0, 12.5)],
                 [10, 4, 1, 1, 2, 2, 4, 10, 5, 5])
    body += hole([(hl + t, htop + t), (W - t, htop + t), (W - t, -50), (hl + t, -50)], [3, 4, 3, 3])
    cap = poly([(cx0, ctop), (cx1, ctop), (cx1, ntop - g), (cx0, ntop - g)], [2, 2, 1, 1])
    return W, [body, cap]

def blender(g, t):
    W, cx = 46, 23
    base = poly([(cx - 19, -16), (cx + 19, -16), (cx + 23, 12.5), (cx - 23, 12.5)], [2, 2, 4, 4])
    base += ellipse_hole(cx, -1.5, 5, 5)
    jar = poly([(cx - 20, -72), (cx + 20, -72), (cx + 13, -16 - g), (cx - 13, -16 - g)], [1, 1, 2, 2])
    lid = poly([(cx - 21.5, -81), (cx + 21.5, -81), (cx + 21.5, -72 - g), (cx - 21.5, -72 - g)], [3, 3, 1, 1])
    lid += poly([(cx - 6, -86), (cx + 6, -86), (cx + 6, -79), (cx - 6, -79)], [1.5, 1.5, 0, 0])
    return W, [base, jar, lid]

def highball(g, t):
    W, cx = 38, 19
    ht, ry, ey = 19, 4.5, -68
    hb, bry, yB = 17.5, 4.5, 8.0
    def half(y):
        return ht + (hb - ht) * (y - ey) / (yB - ey)
    yc = -2.0
    yb = yc + g
    rim = 4.2 * t / 6
    sx = cx + 7
    straw = straw_path([(sx - 3, ey + 6), (sx + 5.2, -85.4)], t * 0.9)
    body = f"M{P(cx - ht, ey)}" + upper_arc(cx, ey, ht, ry)
    body += f"L{P(cx + half(yc), yc)}" + lower_arc_rtl(cx, yc, half(yc), bry) + "Z"
    body += ellipse_hole(cx, ey + rim * 0.15, ht - rim, ry - rim * 0.45)
    cube = [(-6.5, -6.5), (6.5, -6.5), (6.5, 6.5), (-6.5, 6.5)]
    for ox, oy, ang in ((cx - 4, -46, 0.26), (cx + 4, -30, -0.3), (cx - 3, -14, 0.15)):
        c, s_ = math.cos(ang), math.sin(ang)
        body += hole([(ox + x * c - y * s_, oy + x * s_ + y * c) for x, y in cube], [2.5] * 4)
    base = f"M{P(cx - half(yb), yb)}" + lower_arc_ltr(cx, yb, half(yb), bry)
    base += f"L{P(cx + hb, yB)}" + lower_arc_rtl(cx, yB, hb, bry) + "Z"
    return W, [straw, body, base]

SHAPES = {
    "sodacan.fill": (sodacan, False),
    "waterglass.fill": (waterglass, False),
    "tumbler.handle.fill": (tumbler, True),
    "bottle.fliplid.fill": (fliplid, True),
    "bottle.loopcap.fill": (loopcap, True),
    "bottle.insulated.fill": (insulated, True),
    "bottle.squeeze.fill": (squeeze, True),
    "shakerbottle.fill": (shaker, True),
    "carton.fill": (carton, True),
    "bottle.soda.fill": (soda_bottle, True),
    "bottle.beer.fill": (beer_bottle, True),
    "cup.hot.lid.fill": (hot_cup, True),
    "cup.dome.straw.fill": (dome_cup, True),
    "cup.boba.fill": (boba, True),
    "cocktailglass.fill": (cocktail, True),
    "beerstein.fill": (beer_stein, True),
    "juicebox.fill": (juice_box, True),
    "rocksglass.ice.fill": (rocks_glass, True),
    "champagneflute.fill": (champagne_flute, True),
    "tropicaldrink.fill": (tropical, True),
    "stickpack.fill": (stick_pack, True),
    "pitcher.fill": (pitcher, True),
    "coconut.straw.fill": (coconut, False),
    "citrusslice.fill": (citrus, False),
    "sodacan.slim.fill": (slimcan, False),
    "shotglass.fill": (shot_glass, True),
    "coffeebean.fill": (coffee_bean, False),
    "coffeebean.circle.fill": (badge_bean, False),
    "percentsign.circle.fill": (badge_percent, False),
    "teapot.fill": (teapot, True),
    "jug.gallon.fill": (gallon_jug, True),
    "blender.fill": (blender, True),
    "highballglass.fill": (highball, True),
}
WEIGHTS = [("Ultralight", 0.96, 2.4, 4.5, 559.711), ("Regular", 1.0, 3.5, 6.0, 1449.84), ("Black", 1.06, 5.0, 8.0, 2933.4)]

def scale_x(d, s):
    nums = re.split(r"([MLCZ])", d)
    res = ""
    for tok in nums:
        if tok in ("M", "L", "C", "Z") or not tok.strip():
            res += tok
            continue
        vals = [float(v) for v in tok.split()]
        res += " ".join(f(v * s) if k % 2 == 0 else f(v) for k, v in enumerate(vals))
    return res

H = "M0.993654 0L3.63775 0L29.3281-67.1323L30.0303-67.1323L30.0303-70.459L28.1226-70.459ZM11.6885-24.4799L46.9815-24.4799L46.2315-26.7285L12.4385-26.7285ZM55.1196 0L57.7637 0L30.6382-70.459L29.4326-70.459L29.4326-67.1323Z"

def template(name, fn, scaled):
    guides, syms = [], []
    for i, (wname, s, g, t, col) in enumerate(WEIGHTS):
        if scaled:
            W, paths = fn(g, t)
        else:
            W, paths = fn(i)
            s = 1.0
        left = col - W * s / 2
        guides.append(f'  <line id="left-margin-{wname}-S" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" x1="{f(left)}" x2="{f(left)}" y1="600.785" y2="720.121"/>')
        guides.append(f'  <line id="right-margin-{wname}-S" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" x1="{f(left + W * s)}" x2="{f(left + W * s)}" y1="600.785" y2="720.121"/>')
        body = "".join(f'\n   <path d="{scale_x(d, s)}"/>' for d in paths)
        syms.append(f'  <g id="{wname}-S" transform="matrix(1 0 0 1 {f(left)} 696)">{body}\n  </g>')
    lines = []
    for tag, base in (("S", 696), ("M", 1126), ("L", 1556)):
        lines.append(f'  <g id="H-reference" style="fill:#27AAE1;stroke:none;" transform="matrix(1 0 0 1 339 {base})">\n   <path d="{H}"/>\n  </g>')
        lines.append(f'  <line id="Baseline-{tag}" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="{base}" y2="{base}"/>')
        lines.append(f'  <line id="Capline-{tag}" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="{f(base - 70.459)}" y2="{f(base - 70.459)}"/>')
    T = 'style="stroke:none;fill:black;font-family:sans-serif;font-size:13;'
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="3300" height="2200">
 <!--glyph: "{name}", point size: 100.0, template writer version: "101"-->
 <g id="Notes">
  <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>
  <text {T}font-weight:bold;" transform="matrix(1 0 0 1 263 322)">Weight/Scale Variations</text>
  <text {T}text-anchor:middle;" transform="matrix(1 0 0 1 559.711 322)">Ultralight</text>
  <text {T}text-anchor:middle;" transform="matrix(1 0 0 1 1449.84 322)">Regular</text>
  <text {T}text-anchor:middle;" transform="matrix(1 0 0 1 2933.4 322)">Black</text>
  <text id="template-version" {T}text-anchor:end;" transform="matrix(1 0 0 1 3036 1933)">Template v.4.0</text>
  <text {T}text-anchor:end;" transform="matrix(1 0 0 1 3036 1951)">Requires Xcode 14 or greater</text>
  <text id="descriptive-name" {T}text-anchor:end;" transform="matrix(1 0 0 1 3036 1969)">{name}</text>
  <text {T}text-anchor:end;" transform="matrix(1 0 0 1 3036 1987)">Typeset at 100 points</text>
  <text {T}" transform="matrix(1 0 0 1 263 726)">Small</text>
  <text {T}" transform="matrix(1 0 0 1 263 1156)">Medium</text>
  <text {T}" transform="matrix(1 0 0 1 263 1586)">Large</text>
 </g>
 <g id="Guides">
{chr(10).join(lines)}
{chr(10).join(guides)}
 </g>
 <g id="Symbols">
{chr(10).join(syms)}
 </g>
</svg>
'''

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: symbols.py <Assets.xcassets dir> [symbol names...]")
    root = sys.argv[1]
    names = sys.argv[2:] or list(SHAPES)
    for name in names:
        if name not in SHAPES:
            continue
        fn, scaled = SHAPES[name]
        d = os.path.join(root, f"{name}.symbolset")
        os.makedirs(d, exist_ok=True)
        open(os.path.join(d, f"{name}.svg"), "w").write(template(name, fn, scaled))
        contents = {"info": {"author": "xcode", "version": 1}, "symbols": [{"filename": f"{name}.svg", "idiom": "universal"}]}
        open(os.path.join(d, "Contents.json"), "w").write(json.dumps(contents, indent=2, separators=(",", " : ")) + "\n")
        print(name)
