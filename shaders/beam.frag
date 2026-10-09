#version 440

// Charging beam, Filament style: three thin strands that leave the charger
// together, weave around each other as sine waves of different heights and
// meet again at the device, shifting from the host's colour to the device's.
// Strand heights go 1 : 5/3 : 7/3 of `amplitude`, they are thinner and fainter
// the wider they swing, and each is a quarter turn or so out of step with the
// next, so they cross.
// `phase` loops over 0..2*pi and every strand makes one cycle per loop, so the
// loop is seamless. Static when not animated.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;       // 0..2*pi
    float lengthPx;    // beam length (item width)
    float heightPx;    // item height: room for the widest strand
    float amplitude;   // wave height of the first strand, px
    float wavelength;  // px
    vec4 color;        // colour at the host
    vec4 endColor;     // colour at the device: the strands shift from one to the other
    float whiteCore;   // 1: the first strand glows white-hot, 0: it stays its colour (light cards)
} ubuf;

const float TAU = 6.28318530718;
const int STRANDS = 3;
// Per strand: height (share of amplitude), width (px), alpha, offset (rad)
const vec4 STRAND[STRANDS] = vec4[](vec4(1.0, 1.6, 0.95, 0.0), vec4(5.0 / 3.0, 1.0, 0.5, 2.1), vec4(7.0 / 3.0, 0.8, 0.3, 4.2));

void main() {
    float len = max(ubuf.lengthPx, 1.0);
    float u = qt_TexCoord0.x;
    float x = u * len;
    float y = (qt_TexCoord0.y - 0.5) * ubuf.heightPx;
    float wl = max(ubuf.wavelength, 4.0);
    float k = TAU / wl;

    // Pinned at both ends: the swing is zero at the host and at the device
    float env = sin(3.14159265 * u);
    float denv = 3.14159265 / len * cos(3.14159265 * u);

    float a = 0.0;
    float core = 0.0;
    for (int i = 0; i < STRANDS; i++) {
        float amp = ubuf.amplitude * STRAND[i].x;
        float arg = k * x - ubuf.phase + STRAND[i].w;
        float centre = amp * env * sin(arg);
        // Distance to the curve, not to its height at this x: a steep strand stays as thin as a flat one
        float slope = amp * (denv * sin(arg) + env * k * cos(arg));
        float d = abs(y - centre) / sqrt(1.0 + slope * slope);
        float half_ = STRAND[i].y * 0.5;
        float line = (1.0 - smoothstep(half_ - 0.5, half_ + 0.7, d)) * STRAND[i].z;
        a += line;
        if (i == 0)
            core = line;
    }

    // Softened at the very ends
    float fade = smoothstep(0.0, 6.0, x) * (1.0 - smoothstep(len - 4.0, len, x));
    a = clamp(a * fade, 0.0, 1.0);
    vec3 tint = mix(ubuf.color.rgb, ubuf.endColor.rgb, u);
    vec3 hot = mix(tint * 0.55, vec3(1.0), ubuf.whiteCore);
    vec3 rgb = mix(tint, hot, clamp(core * 0.5, 0.0, 1.0));
    fragColor = vec4(rgb * a, a) * ubuf.qt_Opacity;
}
