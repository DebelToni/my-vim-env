float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);

    float t = iTime;
    vec3 color = base.rgb;

    // CRT dim + green tint base.
    color *= vec3(0.18, 0.95, 0.22);

    // Horizontal scanlines.
    float scan = 0.85 + 0.15 * sin(fragCoord.y * 1.9 + t * 22.0);
    color *= scan;

    // Vertical rolling glow stripe.
    float roll = fract(t * 0.18);
    float stripe = exp(-pow((uv.y - roll) * 12.0, 2.0));
    color += vec3(0.0, 0.65, 0.1) * stripe * 0.32;

    // Matrix rain columns.
    float cols = 120.0;
    float colId = floor(uv.x * cols);
    float colSeed = hash12(vec2(colId, 19.0));
    float speed = mix(0.35, 1.25, colSeed);
    float yHead = fract(1.0 - (t * speed + colSeed));
    float distHead = abs(uv.y - yHead);
    float head = exp(-distHead * 90.0);
    float trail = exp(-max(0.0, uv.y - yHead) * 30.0) * step(yHead, uv.y);
    float glyphMask = step(0.72, hash12(floor(vec2(uv.x * cols, uv.y * 95.0 + t * 18.0))));
    float rain = (head + trail * 0.6) * glyphMask;
    color += vec3(0.1, 1.0, 0.3) * rain * 0.65;

    // RGB glitch offset bands.
    float gBand = step(0.92, fract(uv.y * 13.0 + t * 0.9));
    float offset = (hash12(vec2(floor(t * 35.0), floor(uv.y * 24.0))) - 0.5) * 0.012 * gBand;
    float r = texture(iChannel0, uv + vec2(offset, 0.0)).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - vec2(offset, 0.0)).b;
    vec3 glitch = vec3(r, g, b) * vec3(0.22, 0.9, 0.22);
    color = mix(color, glitch, 0.45 * gBand);

    // Terminal vignette for extra drama.
    vec2 p = uv * 2.0 - 1.0;
    float vig = 1.0 - dot(p, p) * 0.28;
    color *= clamp(vig, 0.45, 1.0);

    // Pulse flash on cursor movement events.
    float dt = iTime - iTimeCursorChange;
    float pulse = exp(-max(dt, 0.0) * 18.0);
    color += vec3(0.08, 0.25, 0.08) * pulse;

    fragColor = vec4(clamp(color, 0.0, 1.0), base.a);
}
