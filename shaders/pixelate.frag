// ============================================================
// PIXELATE — піксельний ефект для TouchDesigner GLSL TOP
// Вхід: sTD2DInputs[0] — будь-яке зображення
// ============================================================
//
// UNIFORMS:
//   float uPixelSize   = 8.0    розмір "пікселя" у екранних пікселях
//   float uColorBits   = 3.0    глибина кольору на канал (3 = 8 рівнів, 4 = 16, 8 = 256)
//   float uDither      = 1.0    дизеринг (0 = вимк, 1 = увімк)
//   float uDitherStr   = 0.5    сила дизерингу (0.0–1.0)
//   float uAspectFix   = 1.0    виправлення пропорцій пікселя (1.0 = квадрат)
//   float uAngle       = 0.0    кут нахилу пікселної сітки (радіани)
//
// ============================================================

uniform float uPixelSize;
uniform float uColorBits;
uniform float uDither;
uniform float uDitherStr;
uniform float uAspectFix;
uniform float uAngle;

// ── Bayer 8×8 матриця для ordered dithering ────────────────

float bayer8(ivec2 p) {
    const int m[64] = int[64](
         0,32, 8,40, 2,34,10,42,
        48,16,56,24,50,18,58,26,
        12,44, 4,36,14,46, 6,38,
        60,28,52,20,62,30,54,22,
         3,35,11,43, 1,33, 9,41,
        51,19,59,27,49,17,57,25,
        15,47, 7,39,13,45, 5,37,
        63,31,55,23,61,29,53,21
    );
    return float(m[(p.y & 7) * 8 + (p.x & 7)]) / 64.0 - 0.5;
}

// ── Квантизація кольору ─────────────────────────────────────

vec3 quantize(vec3 col, float bits) {
    float levels = pow(2.0, bits) - 1.0;
    return floor(col * levels + 0.5) / levels;
}

// ── Поворот 2D ──────────────────────────────────────────────

vec2 rot(vec2 p, float a) {
    float c = cos(a), s = sin(a);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// ── MAIN ────────────────────────────────────────────────────

out vec4 fragColor;

void main() {
    vec2 res = uTD2DInfos[0].res.zw;
    vec2 uv  = vUV.st;

    // Розмір пікселя у UV-просторі
    vec2 pxSize = vec2(uPixelSize, uPixelSize * uAspectFix) / res;

    // Кут нахилу сітки (опційно)
    vec2 uvRot = rot(uv - 0.5, uAngle) + 0.5;

    // Прив'язати UV до сітки (quantize UV)
    vec2 snapped = floor(uvRot / pxSize) * pxSize;

    // Повернути назад і семплювати
    vec2 sampleUV = rot(snapped + pxSize * 0.5 - 0.5, -uAngle) + 0.5;
    vec4 col = texture(sTD2DInputs[0], sampleUV);

    // ── Dithering (Bayer ordered) ───────────────────────────
    if (uDither > 0.5) {
        // Координати в пікселях поточної "мега-клітинки"
        ivec2 ditherCoord = ivec2(mod(floor(uv * res), 8.0));
        float noise = bayer8(ditherCoord) * uDitherStr;

        // Додаємо шум до кольору перед квантизацією
        float levels = pow(2.0, uColorBits) - 1.0;
        col.rgb += noise / levels;
    }

    // ── Квантизація кольору ─────────────────────────────────
    col.rgb = quantize(col.rgb, uColorBits);

    fragColor = col;
}
