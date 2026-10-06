# 双人幸存者宣传片

成片：`artifacts/promo/Twin_Survivors_Trailer_1080p.mp4`，98 秒，1920×1080，30 FPS，H.264 / AAC。源画面由 Godot 在 1280×800 实际渲染，裁出 1280×720 后放大，非原生 1080p。

本次另保留高码率存档 `Twin_Survivors_Trailer_Master_1080p.mp4` 与原始 `gameplay_master.avi`。分享版限制视频码率为 8 Mbps，音频为 48 kHz 双声道；存档版保留初次高画质编码。重录脚本默认直接输出便于分享的版本。

## 内容

- 法师：四重成长火球、火焰地形、冰霜领域、冰锥与冰径、庇护挡弹、雷塔连锁/潮汐/裁决，以及附身配合。
- 战士：二段火焰冲刺、穿屏斩击、巨大化、人肉炮弹、震地、反甲、救援庇护与嘲讽木桩。
- 三个终局 Boss：武王五种近战技能、炮皇五种弹幕/轰炸、奶龙四种大招、重生奶蛙的四种大招与半血弱化分身。
- 保留吐息、舌鞭和狂暴切换的实际透明技能播报，保留原始游戏背景。其他演示镜头直接展示技能过程。

这是强化构筑实机展示，演示脚本设置了构筑、敌群、释放时机和录制保护。片段包含不同演示场景的剪接，不是一次正常对局的连续录像。没有修改游戏脚本或正常游戏平衡、冷却、播报频率。

## 重录

在项目根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File tools/make_trailer.ps1
```

仅重做音乐与编码（保留已录好的 `gameplay_master.avi`）：

```powershell
powershell -ExecutionPolicy Bypass -File tools/make_trailer.ps1 -EncodeOnly
```

依赖：本项目 `.tools` 内的 Godot、`.tools/ffmpeg.exe`，以及 Python + NumPy。FFmpeg 是公开的 imageio-ffmpeg 0.6.0 Windows wheel 内二进制，仅作为本地编码工具，不随游戏分发。

`trailer_capture.gd` 定义镜头、走位和真实技能释放；`trailer_overlay.gd` 画片头片尾与边缘字幕；`trailer_audio.py` 生成原创电子配乐及冲击/呼啸/电击音效；`trailer_metadata.py` 写入导航章节。所有配乐在本地合成，没有使用外部歌曲。

初次验证可将 Movie Maker 命令末尾加 `-- --preview`，只录 8 秒。输出及源 AVI 均在已忽略的 `artifacts/promo` 下，原始 AVI 体积较大，上传时只需 MP4 与封面。
