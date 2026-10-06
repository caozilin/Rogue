"""Optional contact sheet of recorded shots; requires OpenCV + Pillow."""
from pathlib import Path
import json
import cv2
from PIL import Image, ImageDraw

out = Path("artifacts/promo")
shots = json.loads((out / "chapters.json").read_text(encoding="utf-8"))
source = out / "Twin_Survivors_Trailer_1080p.mp4"
encoded = source.exists()
if not encoded:
    source = out / "gameplay_master.avi"
cap = cv2.VideoCapture(str(source))
assert cap.isOpened(), source
print("Video frames:", int(cap.get(cv2.CAP_PROP_FRAME_COUNT)), "FPS:", cap.get(cv2.CAP_PROP_FPS))
sheet = Image.new("RGB", (1600, 7*204), (15, 22, 30))
draw = ImageDraw.Draw(sheet)
for i, shot in enumerate(shots):
    t = shot["start"] + min(1.25, shot["duration"] / 2)
    cap.set(cv2.CAP_PROP_POS_MSEC, t*1000)
    ok, frame = cap.read()
    assert ok, (i, t)
    if not encoded:
        frame = frame[40:760]
    im = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    im.save(out / f"shot_{i+1:02d}.jpg", quality=93)
    sheet.paste(im.resize((320, 180)), ((i%5)*320, (i//5)*204))
    draw.text(((i%5)*320+5, (i//5)*204+182), f"{i+1:02d} {shot['kind']} {t:.1f}s", fill="white")
sheet.save(out / "contact_sheet.jpg", quality=94)
cap.release()
print("All 31 representative frames decoded and contact sheet written.")
