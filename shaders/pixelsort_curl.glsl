// ============================================================
//  PIXEL SORT — TouchDesigner GLSL TOP Shader
//  with Curl Noise direction field (swirly/vortex streaks)
// ============================================================
//
//  INPUTS:
//   0 → Source image
//   1 → Scalar noise TOP  (grayscale — warps dissolve boundary)
//   2 → Scalar noise TOP  (grayscale — curl field source)
//         Noise TOP → Sparse or Hermite, single channel is fine
//         Animate Translate X/Y over time to make swirls flow
//
//  UNIFORMS (Float, Vectors 1 tab) — add exactly these names:
//   uAngle           0–360     Base sort direction (when uVectorInfluence=0)
//   uSortLength      2–32      Sort window size in pixels
//   uSortMode        0–4       0=Luma 1=R 2=G 3=B 4=Hue
//   uSortDir         0–1       0=dark→bright  1=bright→dark
//   uDissolve        0–1       Animate to sweep dissolve front
//   uNoiseStrength   0–1       Scalar noise warp on dissolve boundary
//   uNoiseScale      0.1–10    UV scale for scalar noise (Input 1)
//   uDissolveAngle   0–360     Base dissolve direction (when uVectorInfluence=0)
//   uVectorInfluence 0–1       0=fixed angle  1=fully curl noise driven
//   uVecNoiseScale   0.1–10    UV scale for curl noise (Input 2)
//                              smaller = broader swirls, larger = tighter spirals
//   uMix             0–1       0=full sort  1=original
//
//  TIP: Wire absTime.seconds * 0.05 into the Noise TOP (Input 2) Translate X
//       to make the curl field animate and swirls drift over time.
//
// ============================================================

#define MAX_S 32

uniform float uAngle;
uniform float uSortLength;
uniform float uSortMode;
uniform float uSortDir;
uniform float uDissolve;
uniform float uNoiseStrength;
uniform float uNoiseScale;
uniform float uDissolveAngle;
uniform float uVectorInfluence;
uniform float uVecNoiseScale;
uniform float uMix;

out vec4 fragColor;

// ── Sort key functions ────────────────────────────────────────

float luma(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

float hueOf(vec3 c) {
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float d  = mx - mn;
    if (d < 0.001) return 0.0;
    float h = (mx == c.r) ? mod((c.g - c.b) / d, 6.0)
            : (mx == c.g) ? (c.b - c.r) / d + 2.0
                          : (c.r - c.g) / d + 4.0;
    return h / 6.0;
}

float getKey(vec4 col) {
    int m = int(uSortMode);
    if (m == 1) return col.r;
    if (m == 2) return col.g;
    if (m == 3) return col.b;
    if (m == 4) return hueOf(col.rgb);
    return luma(col.rgb);
}

// ── Curl noise ────────────────────────────────────────────────
// Rotate the scalar noise gradient 90° → divergence-free curl field
// curl.x =  dn/dy
// curl.y = -dn/dx

vec2 curlNoise(vec2 uvN, float eps) {
    float n0 = texture(sTD2DInputs[2], uvN + vec2(0.0,  eps)).r;
    float n1 = texture(sTD2DInputs[2], uvN - vec2(0.0,  eps)).r;
    float n2 = texture(sTD2DInputs[2], uvN + vec2(eps,  0.0)).r;
    float n3 = texture(sTD2DInputs[2], uvN - vec2(eps,  0.0)).r;
    return normalize(vec2(n0 - n1, -(n2 - n3)));
}

// ── Main ──────────────────────────────────────────────────────

void main() {
    vec2 uv     = vUV.st;
    vec2 pxSize = 1.0 / vec2(textureSize(sTD2DInputs[0], 0));

    // Eps auto-derived from noise scale: no extra uniform needed
    // smaller uVecNoiseScale → larger eps → broader, lazier swirls
    // larger  uVecNoiseScale → smaller eps → tighter, denser spirals
    float eps = 0.01 / max(uVecNoiseScale, 0.1);
    float inf = clamp(uVectorInfluence, 0.0, 1.0);

    // ── Curl direction field ──────────────────────────────────
    vec2 curl = curlNoise(uv * uVecNoiseScale, eps);

    // ── Dissolve direction ────────────────────────────────────
    vec2 globalDissolveDir = vec2(cos(radians(uDissolveAngle)), sin(radians(uDissolveAngle)));
    vec2 dissolveDir       = normalize(mix(globalDissolveDir, curl, inf));

    float grad  = dot(uv - 0.5, dissolveDir) + 0.5;
    float noise = texture(sTD2DInputs[1], uv * uNoiseScale).r;
    float mask  = mix(grad, noise, clamp(uNoiseStrength, 0.0, 1.0));

    vec4 orig = texture(sTD2DInputs[0], uv);

    if (mask > clamp(uDissolve, 0.0, 1.0)) {
        fragColor = TDOutputSwizzle(orig);
        return;
    }

    // ── Sort direction (same curl field bends the streaks) ────
    vec2 globalSortDir = vec2(cos(radians(uAngle)), sin(radians(uAngle)));
    vec2 sDir          = normalize(mix(globalSortDir, curl, inf));

    // ── Gather sort window ────────────────────────────────────
    int count = clamp(int(uSortLength), 2, MAX_S);

    vec4  smps[MAX_S];
    float keys[MAX_S];

    for (int i = 0; i < MAX_S; i++) {
        if (i >= count) break;
        float t   = float(i) - float(count - 1) * 0.5;
        vec2  suv = clamp(uv + sDir * t * pxSize, vec2(0.0), vec2(1.0));
        smps[i]   = texture(sTD2DInputs[0], suv);
        keys[i]   = getKey(smps[i]);
    }

    // ── Bubble sort ───────────────────────────────────────────
    for (int i = 0; i < MAX_S - 1; i++) {
        if (i >= count - 1) break;
        for (int j = 0; j < MAX_S - 1; j++) {
            if (j >= count - 2 - i) break;
            bool doSwap = (uSortDir < 0.5)
                ? (keys[j] > keys[j + 1])
                : (keys[j] < keys[j + 1]);
            if (doSwap) {
                float tk = keys[j];  keys[j]  = keys[j + 1];  keys[j + 1]  = tk;
                vec4  ts = smps[j];  smps[j]  = smps[j + 1];  smps[j + 1]  = ts;
            }
        }
    }

    // ── Rank lookup ───────────────────────────────────────────
    float myKey = getKey(orig);
    int rank = 0;
    for (int i = 0; i < MAX_S; i++) {
        if (i >= count) break;
        if (keys[i] < myKey) rank++;
    }
    rank = clamp(rank, 0, count - 1);

    // ── Output ────────────────────────────────────────────────
    fragColor = TDOutputSwizzle(mix(smps[rank], orig, clamp(uMix, 0.0, 1.0)));
}
