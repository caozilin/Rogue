# 基础占位贴图

使用内置 image_gen 生成，仅用一张透明 PNG 快速提供基础风格；没有外部素材依赖。

文件：`survivors-atlas.png`。四个等大的象限由 `scripts/art.gd` 自动切分：左上人物、右上普通蘑菇怪、左下紫色精英、右下经验晶体。两名玩家共用人物切片，通过外部 P1/P2 标记和青色/橙色脚下圈区分。

只影响绘制；所有角色半径、伤害、速度及其它玩法数值保留。保留几何图形回退以便以后替换素材。

最终生成提示词（内置工具，非 CLI）：

```text
Use case: stylized-concept. Asset type: a production 2D game sprite atlas, ONE square PNG with true transparent background, for a top-down local co-op roguelite in Godot. Primary request: cohesive charming dark-fantasy chunky pixel art sprites with strong readable silhouettes, clean 1-bit-style dark outlines and a limited jewel-tone palette, designed to read at 40 to 60 on-screen pixels. Composition: EXACT 2 by 2 equal grid on 1024 x 1024 canvas, no gutters drawn and no borders drawn. Each quadrant is exactly 512 x 512, its one sprite is centered at its quadrant center, fully contained within a centered 360 x 360 region, generous empty transparent margins. Top-left quadrant: ONE neutral ivory-hooded tiny adventurer wearing a slate-blue tunic, small brown boots, carrying a short wooden wand with a pale blue tip; full body front-facing three-quarter top-down view, feet visible, symmetrical compact friendly heroic silhouette. Top-right quadrant: ONE squat malicious rose-magenta mushroom monster with two bright pale eyes and short stubby feet, no accessories, full body front-facing top-down view. Bottom-left quadrant: ONE chunky purple horned imp elite monster with lavender horns, broad compact silhouette, tiny folded bat wings, pale eyes, full body front-facing top-down view. Bottom-right quadrant: ONE emerald-green faceted experience crystal with bright mint highlights, diamond silhouette. Consistent perspective, outline weight and pixel scale across all four sprites. Actual blocky square-pixel edges, no soft painting or realistic materials. Constraints: genuine alpha transparency around every sprite, NO ground, NO backdrop, NO drop shadows, NO checkerboard baked in, NO text, labels, watermark or user interface; only these four isolated sprites in exactly the specified quadrants, no sprite crossing a quadrant boundary. This is an asset sheet, not a screenshot.
```
