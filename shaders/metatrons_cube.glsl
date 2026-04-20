// ─────────────────────────────────────────────────────────────
//  Metatron's Cube — GLSL TOP  /  TouchDesigner
//  No inputs required.
//
//  Resolution/aspect — автоматично через dFdx/dFdy на vUV
//  absTime           — вбудований TD, не оголошувати
//
//  Parameters → Uniforms panel:
//
//  scale         float   Overall zoom              default  1.0
//  hex_grid      float   Inner ring distance       default  1.0
//  r_center      float   Center circle radius      default  0.52
//  r_inner       float   Inner 6 circles radius    default  1.0
//  r_outer       float   Outer 6 circles radius    default  1.0
//  glow          float   Glow brightness           default 14.0
//  sharp         float   Line sharpness            default 55.0
//  rot_speed     float   Rotation speed            default  0.0
//  pulse_amt     float   Circle pulse amount       default  0.0
// ─────────────────────────────────────────────────────────────

uniform float scale;
uniform float hex_grid;
uniform float r_center;
uniform float r_inner;
uniform float r_outer;
uniform float glow;
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

    // ── UV + aspect ───────────────────────────────────────────
    // dFdx(vUV.s) = 1/width   →   width  = 1 / dFdx(vUV.s)
    // dFdy(vUV.t) = 1/height  →   height = 1 / dFdy(vUV.t)
    // aspect = width / height = dFdy(vUV.t) / dFdx(vUV.s)
    float aspect = abs(dFdy(vUV.t)) / abs(dFdx(vUV.s));

    vec2 uv  = vUV.st - 0.5;
    uv.x    *= aspect;
    uv      *= 7.5 / scale;

    // ── Анімація ──────────────────────────────────────────────
    float rot   = absTime * rot_speed * 0.06;
    float pulse = 1.0 + pulse_amt * 0.004 * sin(absTime * 1.8);
    float PI3   = 1.0471975;

    // ── 13 центрів ────────────────────────────────────────────
    vec2 pts[13];
    pts[0] = vec2(0.0);

    for (int i = 0; i < 6; i++) {
        float a  = 1.5707963 + float(i) * PI3 + rot;
        pts[1+i] = vec2(cos(a), sin(a)) * hex_grid;
    }
    for (int i = 0; i < 6; i++) {
        pts[7+i] = pts[1+i] * 2.0;
    }

    float eps = 0.014 / sharp;
    float acc = 0.0;

    // ── 78 ліній ──────────────────────────────────────────────
    for (int i = 0; i < 13; i++) {
        for (int j = i + 1; j < 13; j++) {
            float d = sdSeg(uv, pts[i], pts[j]);
            acc += loren(d, eps) * glow * 0.009;
            acc += exp(-d * 14.0)       * 0.015;
        }
    }

    // ── Центральне коло ───────────────────────────────────────
    {
        float d = abs(length(uv) - r_center * pulse);
        acc += loren(d, eps) * glow * 0.030;
        acc += exp(-d * 9.0)        * 0.060;
    }

    // ── Внутрішнє кільце ─────────────────────────────────────
    for (int i = 1; i < 7; i++) {
        float d = abs(length(uv - pts[i]) - r_inner * pulse);
        acc += loren(d, eps) * glow * 0.026;
        acc += exp(-d * 9.0)        * 0.055;
    }

    // ── Зовнішнє кільце ──────────────────────────────────────
    for (int i = 7; i < 13; i++) {
        float d = abs(length(uv - pts[i]) - r_outer * pulse);
        acc += loren(d, eps) * glow * 0.026;
        acc += exp(-d * 9.0)        * 0.055;
    }

    // ── Атмосфера ─────────────────────────────────────────────
    acc += exp(-length(uv) * 0.55) * 0.25;
    acc += exp(-length(uv) * 3.00) * 0.10;

    // ── Tone mapping ──────────────────────────────────────────
    float b = acc / (1.0 + acc * 0.17);

    float atm = exp(-length(uv) * 1.1);
    vec3  col = vec3(b) + vec3(0.030, 0.015, 0.07) * atm * (1.0 - b * 0.6);

    fragColor = TDOutputSwizzle(vec4(clamp(col, 0.0, 1.0), 1.0));
}
