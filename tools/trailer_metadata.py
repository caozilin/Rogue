"""Embed useful navigation chapters without changing the rendered picture."""
import json
import sys
from pathlib import Path

out = Path(sys.argv[1] if len(sys.argv) > 1 else "artifacts/promo")
shots = json.loads((out / "chapters.json").read_text(encoding="utf-8"))
lines = [";FFMETADATA1", "title=双人幸存者 · 实机战斗宣传片", "artist=Twin Survivors", "comment=Godot 实机渲染；强化构筑演示；原创程序化配乐与音效"]
last_kind = None
for index, shot in enumerate(shots):
    if shot["kind"] == last_kind:
        continue
    last_kind = shot["kind"]
    end = shot["start"] + shot["duration"]
    for following in shots[index+1:]:
        if following["kind"] != last_kind:
            break
        end += following["duration"]
    title = shot["title"].replace("=", "\\=")
    lines += ["[CHAPTER]", "TIMEBASE=1/1000", f"START={round(shot['start']*1000)}", f"END={round(end*1000)}", f"title={title}"]
(out / "chapters.ffmeta").write_text("\n".join(lines)+"\n", encoding="utf-8")
print("Navigation chapters written.")
