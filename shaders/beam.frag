#version 440

// Charging beam drawn as magnetic field lines: many faint, thin lines that
// leave the charger together, fan out into a spindle and meet again at the
// device, like iron filings around a magnet. Each line waves softly at its
// own pace and faint pulses flow toward the device. Lots of lines, each one
// barely visible: the field is felt more than seen.
// `phase` loops over 0..2*pi; every term uses a whole number of cycles per
// loop, so the loop is seamless. Static when not animated.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;       // 0..2*pi
    float lengthPx;    // beam length (item width)
    float heightPx;    // item height: the spindle's widest opening
    float amplitude;   // wave height of each line, px
    float wavelength;  // px
    vec4 color;        // theme primary
    float whiteCore;   // 1: lines glow white-hot, 0: they deepen (light cards)
} ubuf;

const float TAU = 6.28318530718;
const int LINES = 11;

void main() {
    float len = max(ubuf.lengthPx, 1.0);
    float u = qt_TexCoord0.x;
    float x = u * len;
    float y = (qt_TexCoord0.y - 0.5) * ubuf.heightPx;

    // Every line is pinned at both ends and opens widest in the middle
    float env = sin(3.14159265 * u);
    // (a short beam opens less, so it stays a spindle and never a bulb)
    float open = pow(env, 0.8) * min(ubuf.heightPx * 0.5 - ubuf.amplitude - 1.5, len * 0.2);
    float wl = max(ubuf.wavelength, 4.0);

    float a = 0.0;
    float core = 0.0;
    for (int i = 0; i < LINES; i++) {
        float t = float(i) / float(LINES - 1) * 2.0 - 1.0;    // -1..1 across the spindle
        float speed = 1.0 + mod(float(i), 3.0);                       // 1, 2 or 3 cycles per loop
        float wave = ubuf.amplitude * env * sin(TAU * x / (wl * (1.0 + 0.25 * abs(t))) - speed * ubuf.phase + float(i) * 1.7);
        float d = abs(y - (t * open + wave));
        float centre = 1.0 - abs(t);                          // the middle lines are a bit brighter
        float line = exp(-pow(d / 0.7, 2.0)) * (0.16 + 0.34 * centre) + exp(-pow(d / 3.0, 2.0)) * 0.05;
        // A faint pulse travelling along each line toward the device
        float pulse = 0.6 + 0.4 * pow(0.5 + 0.5 * sin(TAU * x / (wl * 2.2) - (3.0 + mod(float(i), 2.0)) * ubuf.phase + float(i)), 4.0);
        a += line * pulse;
        core += exp(-pow(d / 0.6, 2.0)) * centre * centre;
    }

    // Brightest where it leaves the charger, softened at the very ends
    float fade = mix(1.0, 0.7, u) * smoothstep(0.0, 6.0, x) * (1.0 - smoothstep(len - 4.0, len, x));
    a = clamp(a * fade, 0.0, 1.0);
    vec3 hot = mix(ubuf.color.rgb * 0.55, vec3(1.0), ubuf.whiteCore);
    vec3 rgb = mix(ubuf.color.rgb, hot, clamp(core * 0.5, 0.0, 1.0));
    fragColor = vec4(rgb * a, a) * ubuf.qt_Opacity;
}
