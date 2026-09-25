#version 440

// "Black hole": the Hidden black hole in its realistic style, after the
// Gargantua look from Interstellar. Drawn analytically in one pass (no ray
// marching), from back to front:
//  1. the starfield bent by the same thin lens as the tesseract style;
//  2. the far side of the accretion disk, whose light is bent over and under
//     the shadow into a halo (brighter above: the primary image);
//  3. the shadow, then a thin photon ring hugging it;
//  4. the thin disk itself, seen almost edge-on, crossing in front of the
//     shadow and hidden by it behind.
// The disk turns faster near the middle (differential rotation) and its
// approaching side is brighter (Doppler beaming). Colors go from warm white
// in the hot inner disk to the theme's primary color outside.
// Nothing here animates by itself: `spin` only changes while the scene is
// awake, so a still scene costs no frames.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// Same block as tesseract.frag, so the two styles swap without other changes
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float sizePx;      // side of the square item, in px
    float horizon;     // shadow radius, px
    float strength;    // 1 at rest, higher while a device is pulled in
    float spin;        // disk rotation phase, radians
    float lens;        // 1 = bend the sky, 0 = no lensing (translucent desktop sky)
    vec4 rimA;         // theme primary: outer disk tint
    vec4 rimB;         // theme tertiary: unused here, kept for the shared block
    vec4 backdrop;     // sky color behind the stars (premultiplied)
} ubuf;

layout(binding = 1) uniform sampler2D source;

// Disk geometry, in shadow radii
const float R_IN = 1.55;     // innermost stable orbit, roughly
const float R_OUT = 2.85;    // stays inside the item (3 radii)
const float FLAT = 0.2;      // cos of the viewing angle: nearly edge-on
const float ROLL = -0.14;    // a slight tilt, radians

// Brightness of the disk at radius r (shadow radii) and angle a
float emission(float r, float a) {
    // Inside the inner edge there is no disk (and pow() of a negative
    // radius would be NaN, which renders as a white blotch)
    if (r < R_IN - 0.15)
        return 0.0;
    float edge = smoothstep(R_IN - 0.12, R_IN + 0.2, r) * (1.0 - smoothstep(R_OUT - 0.7, R_OUT, r));
    // Inner orbits turn faster (Kepler: angular speed ~ r^-1.5)
    float phase = a + ubuf.spin * 1.7 * pow(r, -1.5);
    float streaks = 0.72 + 0.16 * sin(phase * 5.0 + r * 11.0) + 0.12 * sin(phase * 9.0 - r * 17.0 + 1.7);
    return edge * pow(R_IN / r, 2.0) * streaks;
}

// Warm white where hot, theme color where cool
vec3 heat(float i) {
    return mix(ubuf.rimA.rgb * 0.9, vec3(1.0, 0.96, 0.9), smoothstep(0.3, 1.1, i)) * i;
}

void main() {
    float half_ = ubuf.sizePx * 0.5;
    vec2 p = (qt_TexCoord0 - 0.5) * ubuf.sizePx;   // px from the center, y down
    float r = max(length(p), 1e-3);
    float rs = ubuf.horizon;

    // 1. Lensed sky, faded out toward the edge of the item
    float einstein = rs * 1.55 * ubuf.strength;
    float fade = 1.0 - smoothstep(half_ * 0.5, half_ * 0.98, r);
    vec2 q = p * (1.0 - fade * einstein * einstein / (r * r));
    vec4 sky = texture(source, clamp(q / ubuf.sizePx + 0.5, 0.0, 1.0));
    vec4 col = (sky + ubuf.backdrop * (1.0 - sky.a)) * (1.0 - smoothstep(half_ * 0.82, half_, r)) * ubuf.lens;

    // Disk frame: rolled slightly, in shadow radii
    float cr = cos(ROLL), sr = sin(ROLL);
    vec2 u = vec2(cr * p.x - sr * p.y, sr * p.x + cr * p.y) / rs;
    float ur = length(u);
    float shadow = 1.0 - smoothstep(1.0 - 1.2 / rs, 1.0 + 0.4 / rs, ur);

    // Doppler: the disk turns counterclockwise seen from above, so its
    // left side comes toward us
    float feed = 0.85 + 0.15 * ubuf.strength;

    // 2. Far side of the disk, lensed into a halo around the shadow
    float ang = atan(u.y, u.x);
    float lensedR = R_IN + (ur - 1.08) * 2.3;
    float above = 0.55 - 0.45 * sin(ang);          // top image brighter than the bottom one
    float halo = emission(lensedR, -ang) * above * (1.0 - smoothstep(0.0, 0.25, -(ur - 1.05)));
    halo *= 1.0 - 0.45 * cos(ang);                 // left brighter
    col.rgb += heat(halo * 0.8 * feed);

    // 3. Shadow, then the photon ring
    col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), shadow);
    float ring = exp(-pow((ur - 1.04) * rs / 0.7, 2.0)) * 0.55;
    col.rgb += heat(ring);

    // 4. The thin disk, in front of the shadow on the near (lower) half
    vec2 d = vec2(u.x, u.y / FLAT);
    float dr = length(d);
    float front = step(0.0, u.y);
    float disk = emission(dr, atan(d.y, d.x)) * (1.0 - 0.55 * d.x / max(dr, 1e-3));
    disk *= mix(1.0 - shadow, 1.0, front);
    col.rgb += heat(disk * feed);

    col.rgb = min(col.rgb, vec3(1.0));
    col.a = max(col.a, max(col.r, max(col.g, col.b)));
    fragColor = col * ubuf.qt_Opacity;
}
