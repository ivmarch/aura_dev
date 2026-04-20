// ─────────────────────────────────────────────────────────────
//  glow_v.glsl  —  GLSL TOP  (Pass 3 of 3)
//  Вертикальний blur + per-component кольори + composite
//
//  Inputs (8 текстур = 4 bloom + 4 originali):
//    [0] glow_h_lines     горизонт. bloom ліній
//    [1] glow_h_center    горизонт. bloom центру
//    [2] glow_h_inner     горизонт. bloom inner
//    [3] glow_h_outer     горизонт. bloom outer
//    [4] base_lines       оригінал ліній (з metatron_base out 0)
//    [5] base_center      оригінал центру
//    [6] base_inner       оригінал inner
//    [7] base_outer       оригінал outer
//
//  Uniforms:
//  radius          float   default 20.0
//  base_strength   float   default  1.0
//  bloom_strength  float   default  2.5
//  col_lines       vec3    default (1.0, 1.0, 1.0)
//  col_center      vec3    default (1.0, 1.0, 1.0)
//  col_inner       vec3    default (1.0, 1.0, 1.0)
//  col_outer       vec3    default (1.0, 1.0, 1.0)
// ─────────────────────────────────────────────────────────────

uniform float radius;
uniform float base_strength;
uniform float bloom_strength;

uniform vec3 col_lines;
uniform vec3 col_center;
uniform vec3 col_inner;
uniform vec3 col_outer;

uniform sampler2D sTD2DInputs[8];

out vec4 fragColor;

// Вертикальний blur одного компонента
vec3 blurV(sampler2D tex, vec2 uv, float step) {
    const float INV_2SIG2 = 0.0176;
    vec4  acc    = vec4(0.0);
    float totalW = 0.0;
    for (int i = -16; i <= 16; i++) {
        float gi  = exp(-float(i * i) * INV_2SIG2);
        vec2  sUV = uv + vec2(0.0, float(i) * step);
        acc      += texture(tex, sUV) * gi;
        totalW   += gi;
    }
    return (acc / totalW).rrr;   // беремо R-канал, решта 0
}

void main() {
    vec2  uv   = vUV.st;
    float py   = abs(dFdy(uv.y));
    float step = (radius / 16.0) * py;

    // ── Bloom: вертикальний blur по кожному компоненту ────────
    vec3 bLines  = blurV(sTD2DInputs[0], uv, step);
    vec3 bCenter = blurV(sTD2DInputs[1], uv, step);
    vec3 bInner  = blurV(sTD2DInputs[2], uv, step);
    vec3 bOuter  = blurV(sTD2DInputs[3], uv, step);

    // ── Оригінали (R-канал кожного) ───────────────────────────
    float oLines  = texture(sTD2DInputs[4], uv).r;
    float oCenter = texture(sTD2DInputs[5], uv).r;
    float oInner  = texture(sTD2DInputs[6], uv).r;
    float oOuter  = texture(sTD2DInputs[7], uv).r;

    // ── Composite: base × колір + bloom × колір ───────────────
    vec3 col = vec3(0.0);

    col += oLines  * col_lines  * base_strength;
    col += oCenter * col_center * base_strength;
    col += oInner  * col_inner  * base_strength;
    col += oOuter  * col_outer  * base_strength;

    col += bLines  * col_lines  * bloom_strength;
    col += bCenter * col_center * bloom_strength;
    col += bInner  * col_inner  * bloom_strength;
    col += bOuter  * col_outer  * bloom_strength;

    // ── Tone mapping ──────────────────────────────────────────
    col = col / (1.0 + col * 0.15);

    fragColor = TDOutputSwizzle(vec4(clamp(col, 0.0, 1.0), 1.0));
}
