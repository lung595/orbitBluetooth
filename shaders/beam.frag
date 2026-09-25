#version 440

// Charging energy beam: two thin light strands waving softly around the
// beam's axis (the wave dies out at both ends, so the beam stays anchored
// to the charger and the device), a white-hot core in a theme-colored glow,
// and pulses of light flowing toward the device.
// `phase` loops over 0..2*pi; every term uses a whole number of cycles per
// loop (3, 2 and 6), so the loop is seamless. Static when not animated.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;       // 0..2*pi
    float lengthPx;    // beam length (item width)
    float heightPx;    // item height
    float amplitude;   // wave height, px
    float wavelength;  // px, main strand (the others follow it)
    vec4 color;        // theme primary
} ubuf;

const float TAU = 6.28318530718;

void main() {
    float len = max(ubuf.lengthPx, 1.0);
    float u = qt_TexCoord0.x;
    float x = u * len;
    float y = (qt_TexCoord0.y - 0.5) * ubuf.heightPx;

    // The wave vanishes at both ends
    float env = sin(3.14159265 * u);
    float wl = max(ubuf.wavelength, 4.0);
    float w1 = ubuf.amplitude * env * sin(TAU * x / wl - 3.0 * ubuf.phase);
    float w2 = ubuf.amplitude * 0.6 * env * sin(TAU * x / (wl * 1.5) + 2.0 * ubuf.phase + 1.3);

    float d1 = abs(y - w1);
    float d2 = abs(y - w2);
    float core = exp(-pow(d1 / 1.1, 2.0));
    float glow = exp(-pow(d1 / 5.0, 2.0)) * 0.35;
    float strand = exp(-pow(d2 / 0.8, 2.0)) * 0.55 + exp(-pow(d2 / 4.0, 2.0)) * 0.15;

    // Pulses flowing from the charger (x = 0) to the device
    float pulse = 0.55 + 0.45 * pow(0.5 + 0.5 * sin(TAU * x / (wl * 1.8) - 6.0 * ubuf.phase), 3.0);
    // Brightest where it leaves the charger, softened at the very ends
    float fade = mix(1.0, 0.65, u) * smoothstep(0.0, 6.0, x) * (1.0 - smoothstep(len - 4.0, len, x));

    float a = clamp((core + glow + strand) * pulse * fade, 0.0, 1.0);
    vec3 rgb = mix(ubuf.color.rgb, vec3(1.0), clamp(core * 0.75, 0.0, 1.0));
    fragColor = vec4(rgb * a, a) * ubuf.qt_Opacity;
}
