vec2 cursorCenter(vec4 rect) {
    return vec2(rect.x + rect.z * 0.5, rect.y - rect.w * 0.5);
}

float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    vec3 color = base.rgb;

    float t = iTime - iTimeCursorChange;
    const float DURATION = 0.34;
    if (t >= 0.0 && t <= DURATION) {
        float progress = clamp(t / DURATION, 0.0, 1.0);

        vec2 prev = cursorCenter(iPreviousCursor);
        vec2 curr = cursorCenter(iCurrentCursor);
        vec2 seg = curr - prev;
        float segLenSq = max(dot(seg, seg), 1.0);
        float segLen = sqrt(segLenSq);

        vec2 pa = fragCoord - prev;
        float h = clamp(dot(pa, seg) / segLenSq, 0.0, 1.0);
        vec2 closest = prev + seg * h;
        float across = length(fragCoord - closest);

        float width = mix(8.0, 2.4, progress);
        float blade = gaussian(across, width);

        float sweep = gaussian(h - smoothstep(0.0, 0.8, progress), 0.09) * gaussian(across, 11.0);

        float burst = gaussian(length(fragCoord - curr), 34.0) * (1.0 - smoothstep(0.0, 0.5, progress));
        float fade = 1.0 - smoothstep(0.2, 1.0, progress);

        float lengthBoost = smoothstep(0.0, 26.0, segLen);

        color += vec3(1.00, 0.94, 0.80) * blade * fade * lengthBoost;
        color += vec3(1.00, 0.36, 0.10) * sweep * 1.15 * lengthBoost;
        color += vec3(1.00, 1.00, 1.00) * (sweep * 0.55 + burst * 0.90);
    }

    fragColor = vec4(clamp(color, 0.0, 1.0), base.a);
}
