// ============================================================
//  PIXEL SORT — TouchDesigner GLSL TOP Shader
// ============================================================
//
//  SETUP IN TOUCHDESIGNER:
//   1. Create a GLSL TOP
//   2. Input 0 → your source image (any TOP)
//   3. Input 1 → Noise TOP (Alligator or Sparse recommended)
//   4. In GLSL TOP → "Vectors 1" tab add all uniforms below
//   5. Paste this code into the "Pixel Shader" panel
//
//  UNIFORMS (add as Float type in Vectors 1 tab):
//   uAngle          0–360     Sort direction (0=right, 90=up, 45=diagonal)
//   uSortLength     2–32      Sort window size in pixels
//   uSortMode       0–4       Key: 0=Luma  1=Red  2=Green  3=Blue  4=Hue
//   uSortDir        0–1       0=dark→bright  1=bright→dark
//   uDissolve       0–1       ANIMATE THIS — sweeps the sort boundary across image
//   uNoiseStrength  0–1       0=hard linear gradient  1=fully noise-driven boundary
//   uNoiseScale     0.1–10    UV scale for noise texture lookup
//   uDissolveAngle  0–360     Direction of the dissolve gradient sweep
//   uMix            0–1       0=full sort  1=original (blend sorted back)
//
//  TIP: Pipe uDissolve through a LFO CHOP or Constant CHOP for live control.
//  TIP: For chained effect, feed this output back into itself with a Feedback TOP.
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
uniform float uMix;

out vec4 fragColor;

// ── Utility: sort key functions ───────────────────────────────

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
    return luma(col.rgb);  // default: luminance
}

// ── Main ──────────────────────────────────────────────────────

void main() {
    vec2 uv     = vUV.st;
    vec2 pxSize = uTD.res.zw;   // 1/width, 1/height in UV space

    // ── Dissolve mask ─────────────────────────────────────────
    // A directional gradient across the image, warped by noise texture.
    // uDissolve sweeps this threshold to reveal/hide the sort effect.

    float dAngle = radians(uDissolveAngle);
    vec2  dDir   = vec2(cos(dAngle), sin(dAngle));
    float grad   = dot(uv - 0.5, dDir) + 0.5;           // 0..1 linear gradient

    float noise  = texture(sTD2DInputs[1], uv * uNoiseScale).r;

    // Blend between linear gradient and noise
    float mask   = mix(grad, noise, clamp(uNoiseStrength, 0.0, 1.0));

    // Fetch original pixel
    vec4 orig = texture(sTD2DInputs[0], uv);

    // Pixels outside the dissolve boundary → pass through unchanged
    if (mask > clamp(uDissolve, 0.0, 1.0)) {
        fragColor = TDOutputSwizzle(orig);
        return;
    }

    // ── Gather sort window ────────────────────────────────────
    // Sample MAX_S pixels centered on this pixel along sort direction.

    float sAngle = radians(uAngle);
    vec2  sDir   = vec2(cos(sAngle), sin(sAngle));
    int   count  = clamp(int(uSortLength), 2, MAX_S);

    vec4  smps[MAX_S];
    float keys[MAX_S];

    for (int i = 0; i < MAX_S; i++) {
        if (i >= count) break;

        float t   = float(i) - float(count - 1) * 0.5;  // centered offset
        vec2  suv = clamp(uv + sDir * t * pxSize, vec2(0.0), vec2(1.0));

        smps[i] = texture(sTD2DInputs[0], suv);
        keys[i] = getKey(smps[i]);
    }

    // ── Bubble sort ───────────────────────────────────────────
    // O(N²) but N ≤ 32 → max ~512 iterations per pixel, GPU-feasible.

    for (int i = 0; i < MAX_S - 1; i++) {
        if (i >= count - 1) break;
        for (int j = 0; j < MAX_S - 1; j++) {
            if (j >= count - 2 - i) break;

            bool doSwap = (uSortDir < 0.5)
                ? (keys[j] > keys[j + 1])   // ascending: dark → bright
                : (keys[j] < keys[j + 1]);  // descending: bright → dark

            if (doSwap) {
                float tk  = keys[j];  keys[j]  = keys[j + 1];  keys[j + 1]  = tk;
                vec4  ts  = smps[j];  smps[j]  = smps[j + 1];  smps[j + 1]  = ts;
            }
        }
    }

    // ── Rank lookup ───────────────────────────────────────────
    // Find where this pixel's sort key lands in the sorted window,
    // then output the sample at that rank. Bright pixels receive
    // the brightest neighbor, dark pixels receive the darkest → streaks form.

    float myKey = getKey(orig);
    int rank = 0;
    for (int i = 0; i < MAX_S; i++) {
        if (i >= count) break;
        if (keys[i] < myKey) rank++;
    }
    rank = clamp(rank, 0, count - 1);

    // ── Output ────────────────────────────────────────────────
    vec4 sorted = smps[rank];
    fragColor = TDOutputSwizzle(mix(sorted, orig, clamp(uMix, 0.0, 1.0)));
}
