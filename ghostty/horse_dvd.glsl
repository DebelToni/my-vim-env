float cross2(vec2 a, vec2 b) {
    return a.x * b.y - a.y * b.x;
}

vec2 rotate2(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float h = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
    return length((p - a) - ab * h);
}

vec3 triangleLayer(vec2 fragCoord, vec2 center, float radius, float angle, float t) {
    vec2 v0 = center + rotate2(vec2(0.0, -radius), angle);
    vec2 v1 = center + rotate2(vec2(0.8660254 * radius, 0.5 * radius), angle);
    vec2 v2 = center + rotate2(vec2(-0.8660254 * radius, 0.5 * radius), angle);

    float area = cross2(v1 - v0, v2 - v0);
    float invArea = 1.0 / area;
    vec3 bary;
    bary.x = cross2(v1 - fragCoord, v2 - fragCoord) * invArea;
    bary.y = cross2(v2 - fragCoord, v0 - fragCoord) * invArea;
    bary.z = 1.0 - bary.x - bary.y;

    float s = sign(area);
    vec3 wb = bary * s;
    float inside = step(0.0, min(wb.x, min(wb.y, wb.z)));

    float d0 = sdSegment(fragCoord, v0, v1);
    float d1 = sdSegment(fragCoord, v1, v2);
    float d2 = sdSegment(fragCoord, v2, v0);
    float edgeDist = min(d0, min(d1, d2));

    vec3 triRgb = clamp(vec3(wb.x, wb.y, wb.z), 0.0, 1.0);
    float edge = exp(-edgeDist / 2.0);
    float glow = exp(-edgeDist / 28.0);
    float centerPulse = exp(-length(fragCoord - center) / 110.0) * (0.65 + 0.35 * sin(t * 5.0));

    return triRgb * inside * 0.75 + triRgb * glow * 0.55 + vec3(1.0) * edge * 0.45 + vec3(0.7, 0.9, 1.0) * centerPulse * 0.22;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    vec2 res = iResolution.xy;
    float sizeControl = clamp(iSelectionBackgroundColor.r, 0.0, 1.0);
    int triCount = int(floor(clamp(iSelectionForegroundColor.r, 0.0, 1.0) * 8.999)) + 1;

    float countNorm = float(triCount - 1) / 8.0;
    float radius = min(res.x, res.y) * mix(0.08, 0.34, sizeControl) * mix(1.0, 0.45, countNorm);
    float margin = max(radius * 1.15, min(res.x, res.y) * 0.08);
    vec2 roam = max(res - 2.0 * vec2(margin), vec2(1.0));

    vec3 color = base.rgb;

    const int MAX_TRIANGLES = 9;
    for (int i = 0; i < MAX_TRIANGLES; i++) {
        if (i >= triCount) {
            continue;
        }

        float fi = float(i);
        float phase = fi / float(max(triCount, 1));
        float tx = abs(fract(iTime * (0.14 + 0.07 * phase) + phase * 0.31) * 2.0 - 1.0);
        float ty = abs(fract(iTime * (0.11 + 0.06 * phase) + phase * 0.73) * 2.0 - 1.0);
        vec2 center = vec2(margin) + roam * vec2(tx, ty);
        float angle = iTime * (1.2 + 0.9 * phase) + phase * 6.283185;

        float layerGain = 0.95 / sqrt(float(triCount));
        color += triangleLayer(fragCoord, center, radius, angle, iTime + phase * 3.0) * layerGain;
    }

    fragColor = vec4(clamp(color, 0.0, 1.0), base.a);
}
