#version 330

// ============================================================================
//  Custom DARKER lightmap  -  based on the VANILLA Minecraft 26.2 core shader
//  Path inside a pack: assets/minecraft/shaders/core/lightmap.fsh
//
//  MY CHANGES (search for them near the bottom of main):
//    1. Brightness slider disabled: the vanilla notGamma step is commented
//       out, so lighting is always forced to the darkest ("Moody") setting.
//    2. pow(color, darknessIntensity) at the very end crushes everything
//       darker. Raise darknessIntensity for darker, lower toward 1.0 for
//       closer to vanilla.
//    (There is also a tiny mix(color, vec3(0.75), 0.04) desaturation wash.)
//
//  HOW THIS CAN BREAK WHEN MINECRAFT UPDATES  (read before updating!):
//    This is a CORE SHADER - an internal interface Mojang can change in any
//    version with no warning. The "LightmapInfo" uniform block below, and the
//    in/out declarations, must match EXACTLY what the game feeds this shader
//    for the version you actually run. If a future version adds, removes,
//    renames or reorders a field in that block, this file goes stale and the
//    lightmap will render wrong (bad colours, broken night vision / darkness)
//    or fail to compile so the pack silently does nothing.
//    This already happened once: 1.21.10 had AmbientLightFactor + 
//    DarkenWorldFactor; by 26.x those were gone, replaced with
//    BossOverlayWorldDarkeningFactor, BlockLightTint and NightVisionColor, and
//    the lighting maths was rewritten (block light is warmer now). When the
//    look breaks after an update, re-extract the new vanilla file and re-apply
//    the two changes above.
//    NOTE: 26.3 is identical to this 26.2 file EXCEPT it adds, at the top,
//      #extension GL_ARB_separate_shader_objects : require
//    and uses  layout(location = 0) in/out  instead of plain in/out. This 26.2
//    file still loads on 26.3, but if a version ever hard-requires those, copy
//    them in from the new vanilla file.
//
//  WHERE TO FIND THE VANILLA FILE (to re-base after an update):
//    It lives inside the Minecraft client .jar at:
//        assets/minecraft/shaders/core/lightmap.fsh
//    A .jar is just a .zip - open with 7-Zip / unzip and pull that file out.
//      Prism (this setup):
//        PrismLauncher/libraries/com/mojang/minecraft/<ver>/minecraft-<ver>-client.jar
//      Official launcher:
//        .minecraft/versions/<ver>/<ver>.jar
//    Online mirror (latest release, no download):
//        github.com/misode/mcmeta  ->  branch "assets"
//        -> assets/minecraft/shaders/core/lightmap.fsh
// ============================================================================

layout(std140) uniform LightmapInfo {
    float SkyFactor;
    float BlockFactor;
    float NightVisionFactor;
    float DarknessScale;
    float BossOverlayWorldDarkeningFactor;
    float BrightnessFactor;
    vec3 BlockLightTint;
    vec3 SkyLightColor;
    vec3 AmbientColor;
    vec3 NightVisionColor;
} lightmapInfo;

in vec2 texCoord;

out vec4 fragColor;

float get_brightness(float level) {
    return level / (4.0 - 3.0 * level);
}

vec3 notGamma(vec3 color) {
    float maxComponent = max(max(color.x, color.y), color.z);
    float maxInverted = 1.0f - maxComponent;
    float maxScaled = 1.0f - maxInverted * maxInverted * maxInverted * maxInverted;
    return color * (maxScaled / maxComponent);
}

float parabolicMixFactor(float level) {
    return (2.0 * level - 1.0) * (2.0 * level - 1.0);
}

void main() {
    // Calculate block and sky brightness levels based on texture coordinates
    float block_level = floor(texCoord.x * 16) / 15;
    float sky_level = floor(texCoord.y * 16) / 15;

    float block_brightness = get_brightness(block_level) * lightmapInfo.BlockFactor;
    float sky_brightness = get_brightness(sky_level) * lightmapInfo.SkyFactor;

    // Calculate ambient color with or without night vision
    vec3 nightVisionColor = lightmapInfo.NightVisionColor * lightmapInfo.NightVisionFactor;
    vec3 color = max(lightmapInfo.AmbientColor, nightVisionColor);

    // Add sky light
    color += lightmapInfo.SkyLightColor * sky_brightness;

    // Add block light
    vec3 BlockLightColor = mix(lightmapInfo.BlockLightTint, vec3(1.0), 0.9 * parabolicMixFactor(block_level));
    color += BlockLightColor * block_brightness;

    // Apply boss overlay darkening effect
    color = mix(color, color * vec3(0.7, 0.6, 0.6), lightmapInfo.BossOverlayWorldDarkeningFactor);

    // Apply darkness effect scale
    color = color - vec3(lightmapInfo.DarknessScale);

    color = clamp(color, 0.0, 1.0);

    // Ignore "BrightnessFactor" slider in settings, forcing it to the lowest setting >:)
    // OLD LINE: vec3 notGamma = notGamma(color);
    // OLD LINE: color = mix(color, notGamma, lightmapInfo.BrightnessFactor);

    color = mix(color, vec3(0.75), 0.04);

    // Intensify darkness >:) (Adjust this float)
    float darknessIntensity = 2.2;
    color = pow(color, vec3(darknessIntensity));

    fragColor = vec4(color, 1.0);
}
