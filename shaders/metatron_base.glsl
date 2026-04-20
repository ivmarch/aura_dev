// ─────────────────────────────────────────────────────────────
//  metatron_base.glsl  —  GLSL TOP  (Pass 1 of 3)
//
//  Кодує 4 компоненти в RGBA каналах:
//    R = лінії (78 з'єднань)
//    G = центральне коло
//    B = внутрішнє кільце (6 кіл)
//    A = зовнішнє кільце (6 кіл)
//
//  ! Pixel Format у GLSL TOP → 32-bit float (RGBA) !
//
//  Uniforms:
//  scale       float   default  1.0
//  hex_grid    float   default  1.0
//  r_center    float   default  0.52
//  r_inner     float   default  1.0
//  r_outer     float   default  1.0
//  sharp       float   default  80.0
//  rot_speed   float   default  0.0
//  pulse_amt   float   default  0.0
// ─────────────────────────────────────────────────────────────

uniform float scale;
uniform float hex_grid;
uniform float r_center;
uniform float r_inner;
uniform float r_outer;
uniform float sharp;
uniform float rot_speed;
uniform float pulse_amt;

out vec4 fragColor;

float sdSeg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

float loren(float d, float eps) {
    return eps / (d * d + eps);
}

void main() {
    float aspect = abs(dFdy(vUV.t)) / abs(dFdx(vUV.s));
    vec2 uv  = vUV.st - 0.5;
    uv.x    *= aspect;
    uv      *= 7.5 / scale;

    float rot   = absTime * rot_speed * 0.06;
    float pulse = 1.0 + pulse_amt * 0.004 * sin(absTime * 1.8);
    float PI3   = 1.0471975;

    vec2 pts[13];
    pts[0] = vec2(0.0);
    for (int i = 0; i < 6; i++) {
        float a  = 1.5707963 + float(i) * PI3 + rot;
        pts[1+i] = vec2(cos(a), sin(a)) * hex_grid;
    }
    for (int i = 0; i < 6; i++) {
        pts[7+i] = pts[1+i] * 2.0;
    }

    float eps  = 0.014 / sharp;
    float epsC = eps * 3.0;   // центр трохи товщий
    float epsR = eps * 2.5;   // кола трохи товщі від ліній

    // ── R: лінії ─────────────────────────────────────────────
    float lines = 0.0;
    for (int i = 0; i < 13; i++) {
        for (int j = i + 1; j < 13; j++) {
            float d = sdSeg(uv, pts[i], pts[j]);
            lines += loren(d, eps);
        }
    }
    lines = clamp(lines / 20.0, 0.0, 1.0);

    // ── G: центральне коло ────────────────────────────────────
    float dc     = abs(length(uv) - r_center * pulse);
    float center = clamp(loren(dc, epsC), 0.0, 1.0);

    // ── B: внутрішнє кільце ───────────────────────────────────
    float inner = 0.0;
    for (int i = 1; i < 7; i++) {
        float d = abs(length(uv - pts[i]) - r_inner * pulse);
        inner += loren(d, epsR);
    }
    inner = clamp(inner / 2.0, 0.0, 1.0);

    // ── A: зовнішнє кільце ────────────────────────────────────
    float outer = 0.0;
    for (int i = 7; i < 13; i++) {
        float d = abs(length(uv - pts[i]) - r_outer * pulse);
        outer += loren(d, epsR);
    }
    outer = clamp(outer / 2.0, 0.0, 1.0);

    fragColor = TDOutputSwizzle(vec4(lines, center, inner, outer));
}
