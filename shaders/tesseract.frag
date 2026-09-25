#version 440

// "Three-dimensional shadow of a four-dimensional bubble": the Hidden
// black hole in its tesseract style, drawn in one pass:
//  1. gravitational lensing: the starfield behind is sampled through a thin
//     lens (beta = theta - E^2 / theta), so stars smear into an Einstein ring
//     and a mirrored inner image, and fade back to undistorted at the edge;
//  2. the event horizon, a disc darker than the sky;
//  3. a thin photon ring swirling between two theme colors;
//  4. a white wireframe tesseract (4D hypercube) turning inside the horizon,
//     a nod to the hypercube Finn shows off in Adventure Time.
// Nothing here animates by itself: `spin` only changes while the scene is
// awake, so a still scene costs no frames.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float sizePx;      // side of the square item, in px
    float horizon;     // event horizon radius, px
    float strength;    // 1 at rest, higher while a device is pulled in
    float spin;        // tesseract rotation phase, radians
    float lens;        // 1 = bend the sky, 0 = no lensing (translucent desktop sky)
    vec4 rimA;         // theme primary
    vec4 rimB;         // theme tertiary
    vec4 backdrop;     // sky color behind the stars (premultiplied)
} ubuf;

layout(binding = 1) uniform sampler2D source;

const float TAU = 6.28318530718;

// Bit k of a vertex index, as 0 or 1 (plain arithmetic: older GLSL
// targets have no integer bit operators)
float bit(float i, float k) {
    return mod(floor(i / exp2(k)), 2.0);
}

// Tesseract vertex i (bits = sign of x, y, z, w), rotated and projected to px
vec2 vertex(float i, float s, float scale) {
    vec4 v = vec4(bit(i, 0.0), bit(i, 1.0), bit(i, 2.0), bit(i, 3.0)) * 2.0 - 1.0;
    // Rotations in the XW and YZ planes turn the hypercube "inside out"
    float c1 = cos(s), s1 = sin(s);
    float c2 = cos(s * 0.45), s2 = sin(s * 0.45);
    v = vec4(c1 * v.x - s1 * v.w, v.y, v.z, s1 * v.x + c1 * v.w);
    v = vec4(v.x, c2 * v.y - s2 * v.z, s2 * v.y + c2 * v.z, v.w);
    // Fixed tilt (about Y, then X) so the nested cubes read in depth
    const float cy = 0.956, sy = 0.292;   // 17 degrees
    const float cx = 0.978, sx = 0.208;   // 12 degrees
    v = vec4(cy * v.x + sy * v.z, v.y, -sy * v.x + cy * v.z, v.w);
    v = vec4(v.x, cx * v.y - sx * v.z, sx * v.y + cx * v.z, v.w);
    // 4D -> 3D -> 2D perspective
    vec3 p = v.xyz / (3.0 - v.w);
    vec2 q = p.xy / (2.6 - p.z);
    return q * scale;
}

float segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * h);
}

void main() {
    float half_ = ubuf.sizePx * 0.5;
    vec2 p = (qt_TexCoord0 - 0.5) * ubuf.sizePx;   // px from the center
    float r = max(length(p), 1e-3);
    float rs = ubuf.horizon;

    // 1. Lensing, faded out toward the edge of the item
    float einstein = rs * 1.55 * ubuf.strength;
    float fade = 1.0 - smoothstep(half_ * 0.5, half_ * 0.98, r);
    vec2 q = p * (1.0 - fade * einstein * einstein / (r * r));
    vec4 sky = texture(source, clamp(q / ubuf.sizePx + 0.5, 0.0, 1.0));
    vec4 col = sky + ubuf.backdrop * (1.0 - sky.a);

    // Covers the plain sky below only where it differs from it
    float cover = (1.0 - smoothstep(half_ * 0.82, half_, r)) * ubuf.lens;
    col *= cover;

    // 3. Photon ring and a soft glow just outside the horizon
    float ang = atan(p.y, p.x);
    vec3 rim = mix(ubuf.rimA.rgb, ubuf.rimB.rgb, 0.5 + 0.5 * sin(ang + ubuf.spin * 0.7));
    float ring = exp(-pow((r - rs * 1.08) / 0.8, 2.0));
    float glow = exp(-max(r - rs, 0.0) / (rs * 0.3)) * 0.12 * (0.8 + 0.2 * ubuf.strength);
    col.rgb += rim * (ring * 0.55 + glow);
    col.a = max(col.a, clamp(ring * 0.55 + glow, 0.0, 1.0));

    // 2. Event horizon
    float disc = 1.0 - smoothstep(rs - 1.0, rs + 0.5, r);
    col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), disc);

    // 4. Tesseract, only inside the horizon
    if (r < rs) {
        float scale = rs * 2.7;
        // 32 edges: each vertex links to the ones differing in one bit
        float d = 1e3;
        for (int i = 0; i < 16; i++) {
            float fi = float(i);
            vec2 a = vertex(fi, ubuf.spin, scale);
            for (int k = 0; k < 4; k++) {
                float fk = float(k);
                if (bit(fi, fk) < 0.5)
                    d = min(d, segment(p, a, vertex(fi + exp2(fk), ubuf.spin, scale)));
            }
        }
        float line = 1.0 - smoothstep(0.2, 0.9, d);
        float inside = 1.0 - smoothstep(rs - 2.0, rs - 0.5, r);
        col.rgb = mix(col.rgb, vec3(0.95), line * inside * 0.9);
    }

    fragColor = col * ubuf.qt_Opacity;
}
