param([switch]$EncodeOnly)
$ErrorActionPreference = 'Stop'
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $projectPath
$godotPath = Join-Path $projectPath '.tools/Godot_v4.5.1-stable_win64_console.exe'
$ffmpegPath = Join-Path $projectPath '.tools/ffmpeg.exe'
$promoPath = Join-Path $projectPath 'artifacts/promo'
New-Item -ItemType Directory -Force -Path $promoPath | Out-Null
if (-not (Test-Path -LiteralPath $ffmpegPath)) {
    throw 'FFmpeg is required at .tools/ffmpeg.exe. See tools/TRAILER.md.'
}
if (-not $EncodeOnly) {
    & $godotPath --path . --script res://tools/trailer_capture.gd --write-movie "$promoPath/gameplay_master.avi" --fixed-fps 30 --disable-vsync --log-file "$promoPath/capture.log"
    if ($LASTEXITCODE -ne 0) { throw 'Movie Maker capture failed.' }
}
python tools/trailer_audio.py artifacts/promo
if ($LASTEXITCODE -ne 0) { throw 'Soundtrack generation failed.' }
python tools/trailer_metadata.py artifacts/promo
if ($LASTEXITCODE -ne 0) { throw 'Chapter metadata generation failed.' }
& $ffmpegPath -hide_banner -loglevel warning -y -i "$promoPath/gameplay_master.avi" -i "$promoPath/soundtrack.wav" -i "$promoPath/chapters.ffmeta" -map 0:v:0 -map 1:a:0 -map_metadata 2 -map_chapters 2 -vf 'crop=1280:720:0:40,eq=contrast=1.045:saturation=1.07,scale=1920:1080:flags=lanczos:in_range=full:out_range=tv,unsharp=5:5:0.25:5:5:0' -c:v libx264 -preset medium -crf 22 -maxrate 8M -bufsize 16M -pix_fmt yuv420p -color_range tv -r 30 -c:a aac -b:a 192k -ar 48000 -af 'volume=-1dB' -movflags +faststart -shortest "$promoPath/Twin_Survivors_Trailer_1080p.mp4"
if ($LASTEXITCODE -ne 0) { throw 'Trailer encoding failed.' }
& $ffmpegPath -hide_banner -loglevel error -y -ss 1.6 -i "$promoPath/Twin_Survivors_Trailer_1080p.mp4" -frames:v 1 -update 1 "$promoPath/cover.jpg"
Write-Output "Trailer complete: $promoPath/Twin_Survivors_Trailer_1080p.mp4"
