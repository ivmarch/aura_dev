// ─────────────────────────────────────────────────────────────
//  glow_h.glsl  —  GLSL TOP  (Pass 2 of 3)
//  Горизонтальний Gaussian blur — одна копія на кожен компонент
//
//  Підключаєш 4 рази (або клонуєш ноду):
//    Instance A: input = metatron_base output 0  (лінії)
//    Instance B: input = metatron_base output 1  (центр)
//    Instance C: input = metatron_base output 2  (inner)
//    Instance D: input = metatron_base output 3  (outer)
//
//  Uniforms:
//  radius      float   default 20.0
//  threshold   float   default 0.04
// ─────────────────────────────────────────────────────────────

uniform float radius;
uniform float threshold;

uniform sampler2D sTD2DInputs[1];

out vec4 fragColor;

void main() {
    vec2  uv   = vUV.st;
    float px   = abs(dFdx(uv.x));
    float step = (radius / 16.0) * px;

    const float INV_2SIG2 = 0.0176;

    vec4  bloom  = vec4(0.0);
    float totalW = 0.0;

    for (int i = -16; i <= 16; i++) {
        float gi  = exp(-float(i * i) * INV_2SIG2);
        vec2  sUV = uv + vec2(float(i) * step, 0.0);
        vec4  s   = texture(sTD2DInputs[0], sUV);
        s = max(s - vec4(threshold), vec4(0.0));
        bloom  += s * gi;
        totalW += gi;
    }

    fragColor = TDOutputSwizzle(bloom / totalW);
}
