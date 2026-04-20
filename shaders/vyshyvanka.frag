// ============================================================
// ВИШИВАНКА — процедурний орнамент для TouchDesigner GLSL TOP
// Pixel Shader (Vertex — залишити дефолтний)
// ============================================================
//
// UNIFORMS — додати в GLSL TOP → Uniforms (тип float / vec3)
//
//   float uScale      = 3.5      масштаб сітки (більше = щільніше)
//   float uBorderW    = 0.07     товщина чорної рамки ромба
//   float uRotation   = 0.0      поворот усього орнаменту (радіани)
//   float uCrossArm   = 0.042    довжина плеча хрестика фону
//   float uCrossThick = 0.013    товщина плеча хрестика
//   float uTime       = 0.0      час (для анімації; підключити Timer CHOP)
//   vec3  uBg         = 1,1,1    колір фону (біле полотно)
//   vec3  uBlack      = 0,0,0    колір рамки/хрестиків
//   vec3  uRed        = .90,.12,.10   червоний акцент
//   vec3  uYellow     = .95,.76,.00   жовтий
//   vec3  uGreen      = .10,.50,.18   зелений
//   vec3  uOrange     = .92,.42,.05   помаранчевий
//   vec3  uBlue       = .15,.25,.85   синій (центр)
//
// ============================================================

uniform float uScale;
uniform float uBorderW;
uniform float uRotation;
uniform float uCrossArm;
uniform float uCrossThick;
uniform float uTime;
uniform vec3  uBg;
uniform vec3  uBlack;
uniform vec3  uRed;
uniform vec3  uYellow;
uniform vec3  uGreen;
uniform vec3  uOrange;
uniform vec3  uBlue;

// ── SDF примітиви ────────────────────────────────────────────

float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Ромб (diamond): |x|+|y| - r
float sdRhombus(vec2 p, float r) {
    return abs(p.x) + abs(p.y) - r;
}

// Хрест-вишивка
float sdCross(vec2 p, float arm, float thick) {
    return min(sdBox(p, vec2(arm, thick)), sdBox(p, vec2(thick, arm)));
}

// Листок (vesica/lens — два кола)
float sdLeaf(vec2 p, float len, float width) {
    float r   = len * len / (4.0 * width) + width * 0.25;
    float off = r - width * 0.5;
    float d1  = length(p - vec2(0.0,  off)) - r;
    float d2  = length(p + vec2(0.0,  off)) - r;
    return max(d1, d2);
}

// ── Утиліти ─────────────────────────────────────────────────

vec2 rot(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// Поворот на 45°
vec2 rot45(vec2 p) {
    return vec2(p.x - p.y, p.x + p.y) * 0.70710678;
}

// Плавне заповнення з SDF (aa = межа антиаліасингу)
float fill(float d, float aa) {
    return smoothstep(aa, -aa, d);
}

// Кільце між двома ромбами (SDF < 0 = всередині кільця)
float sdRhombusRing(vec2 p, float rOut, float rIn) {
    return max(sdRhombus(p, rOut), -sdRhombus(p, rIn));
}

// ── Мотив всередині ромба ────────────────────────────────────
// p — нормалізовані координати ~[-1, 1]
// bg — базовий колір під мотивом

vec3 drawMotif(vec2 p, vec3 bg) {
    vec3 col = bg;
    float aa = 0.018;

    // 4 великі зелені листки (N/S/E/W)
    for (int i = 0; i < 4; i++) {
        vec2 q = rot(p, float(i) * 1.5708) - vec2(0.0, 0.54);
        float d = sdLeaf(q, 0.42, 0.16);
        col = mix(col, uGreen, fill(d, aa));
        // жовта вена
        float dv = sdLeaf(q, 0.32, 0.05);
        col = mix(col, uYellow * 1.1, fill(dv, aa));
    }

    // 4 діагональні помаранчеві пелюстки
    for (int i = 0; i < 4; i++) {
        vec2 q = rot(p, float(i) * 1.5708 + 0.7854) - vec2(0.0, 0.38);
        float d = sdLeaf(q, 0.30, 0.13);
        col = mix(col, uOrange, fill(d, aa));
    }

    // Маленькі червоні ромби по осях
    for (int i = 0; i < 4; i++) {
        vec2 q = rot(p, float(i) * 1.5708) - vec2(0.0, 0.24);
        float d = sdRhombus(q, 0.07);
        col = mix(col, uRed, fill(d, aa));
    }

    // Центральні вкладені ромби (жовтий → зелений → помаранчевий)
    col = mix(col, uYellow, fill(sdRhombus(p, 0.20), aa));
    col = mix(col, uGreen,  fill(sdRhombus(p, 0.12), aa));
    col = mix(col, uOrange, fill(sdRhombus(p, 0.065), aa));

    // Синя крапка в центрі
    col = mix(col, uBlue,   fill(length(p) - 0.035, aa));

    return col;
}

// ── MAIN ─────────────────────────────────────────────────────

out vec4 fragColor;

void main() {
    vec2 uv = vUV.st;

    // Корекція пропорцій
    vec2 res    = uTD2DInfos[0].res.zw;
    float aspect = res.x / res.y;
    uv.x *= aspect;

    // Загальний поворот
    vec2 center = vec2(aspect * 0.5, 0.5);
    uv = rot(uv - center, uRotation) + center;

    // ── Ромбічна сітка ──────────────────────────────────────
    vec2 gUV   = rot45(uv * uScale);
    vec2 cellID = floor(gUV);
    vec2 lp     = fract(gUV) - 0.5;   // локальні координати [-0.5, 0.5]

    float aa = 0.007;
    vec3 col = uBg;

    // ── Фонові хрестики (вишита канва) ──────────────────────
    // Основні вузли сітки
    float cx1 = sdCross(lp, uCrossArm, uCrossThick);
    col = mix(col, uBlack, fill(cx1, aa));

    // Проміжні (зміщені на 0.5) — дрібніші
    vec2 lp2 = fract(gUV + 0.5) - 0.5;
    float cx2 = sdCross(lp2, uCrossArm * 0.65, uCrossThick * 0.75);
    col = mix(col, uBlack, fill(cx2, aa) * 0.65);

    // ── Рамка ромба ─────────────────────────────────────────
    float outerR = 0.455;
    float innerR = outerR - uBorderW;

    // Чорна рамка (кільце між outerR та innerR)
    float borderD = sdRhombusRing(lp, outerR, innerR);
    col = mix(col, uBlack, fill(borderD, aa));

    // ── Червона лінія-акцент усередині рамки ────────────────
    float redOutR = innerR - 0.005;
    float redInR  = innerR - 0.022;
    float redLineD = sdRhombusRing(lp, redOutR, redInR);
    col = mix(col, uRed, fill(redLineD, aa));

    // ── Мотив ───────────────────────────────────────────────
    float motifR = redInR - 0.020;
    float dMotif  = sdRhombus(lp, motifR);
    float motifMask = fill(-dMotif, aa);

    if (motifMask > 0.001) {
        // Нормалізуємо до ~[-1, 1] для малювання мотиву
        vec2 motifUV  = lp / motifR;
        vec3 motifCol = drawMotif(motifUV, uBg);
        col = mix(col, motifCol, motifMask);
    }

    fragColor = vec4(col, 1.0);
}
