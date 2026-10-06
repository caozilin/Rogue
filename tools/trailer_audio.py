"""Original procedural trailer score and effects. No external audio assets.

Usage: python tools/trailer_audio.py artifacts/promo
Creates a stereo PCM soundtrack matching the Movie Maker shot manifest.
"""
from pathlib import Path
import json
import sys
import wave
import numpy as np

out = Path(sys.argv[1] if len(sys.argv) > 1 else "artifacts/promo")
shots = json.loads((out / "shots.json").read_text(encoding="utf-8"))
duration = sum(s["duration"] for s in shots) + 1 / 30
sr = 44100
rng = np.random.default_rng(20261005)
mix = np.zeros((int(duration * sr), 2), dtype=np.float32)

def add(sound, at, gain=1, pan=0):
    start = max(0, int(at * sr))
    n = min(len(sound), len(mix) - start)
    if n <= 0:
        return
    sound = np.asarray(sound[:n], dtype=np.float32) * gain
    mix[start:start+n, 0] += sound * np.sqrt((1-pan)/2)
    mix[start:start+n, 1] += sound * np.sqrt((1+pan)/2)

def clock(seconds):
    return np.arange(int(seconds * sr), dtype=np.float32) / sr

def tone(freq, seconds, bright=6, decay=2.8):
    t = clock(seconds)
    signal = np.zeros_like(t)
    for harmonic in range(1, bright+1):
        signal += np.sin(2*np.pi*freq*harmonic*t) / (harmonic**1.5)
    return signal * np.minimum(1, t/.006) * np.exp(-t*decay) * np.minimum(1, (seconds-t)/.04)

def kick():
    t = clock(.35)
    phase = 2*np.pi*(48*t + 105*.027*(1-np.exp(-t/.027)))
    return np.sin(phase)*np.exp(-t*13) + rng.normal(0, .06, len(t))*np.exp(-t*95)

def snare():
    t = clock(.22)
    noise = rng.normal(0, 1, len(t)).astype(np.float32)
    noise = (noise - np.roll(noise, 1)) * .4
    return noise*np.exp(-t*21) + .23*np.sin(2*np.pi*185*t)*np.exp(-t*25)

def hat(opened=False):
    t = clock(.16 if opened else .065)
    noise = rng.normal(0, 1, len(t)).astype(np.float32)
    return (noise - np.roll(noise, 1)) * np.exp(-t*(30 if opened else 85)) * .23

def impact(at, weight=.8):
    t = clock(.8)
    freq = 34*t + 115*.045*(1-np.exp(-t/.045))
    sub = np.sin(2*np.pi*freq) * np.exp(-t*6)
    noise = rng.normal(0, 1, len(t)).astype(np.float32)
    smooth = np.convolve(noise, np.ones(13)/13, mode="same")
    add(.65*sub + .65*smooth*np.exp(-t*8), at, weight)
    add(.35*smooth*np.exp(-t*7), at+.08, weight*.5, -.5)
    add(.35*smooth*np.exp(-t*7), at+.16, weight*.3, .5)

def sweep(at, seconds=.6, gain=.18):
    t = clock(seconds)
    noise = rng.normal(0, 1, len(t)).astype(np.float32)
    envelope = np.sin(np.pi*t/seconds)**2
    sweep_phase = 2*np.pi*(160*t + 950*t*t)
    add((noise*.12 + np.sin(sweep_phase)*.25)*envelope, at, gain, -.3)
    add((noise*.12 + np.sin(sweep_phase)*.25)*envelope, at+.05, gain*.7, .4)

# 150 BPM, D minor: driving bass, percussive arpeggios and broad harmonic pads.
beat = .4
roots = [73.416, 58.270, 87.307, 65.406]
for step in range(int(duration / (beat/2))):
    at = step*beat/2
    section = .62 if at < 3 else (.87 if at < 38.3 else 1.0)
    if 72.5 < at < 75:
        section = .16  # Leave space for the second-life reveal.
    root = roots[(step//32) % 4]
    bass = tone(root * (2 if step%8 in [3, 7] else 1), .24, 7, 12)
    add(bass, at, .115*section)
    add(hat(step%4 == 3), at, .092*section, -.28 if step%2 else .28)
    if step % 2 == 0:
        add(kick(), at, .44*section)
    if step % 4 == 2:
        add(snare(), at, .23*section)
    if at > 3:
        scale = [0, 7, 12, 15, 19, 15, 12, 7]
        freq = root*4*2**(scale[step%8]/12)
        arp = tone(freq, .19, 4, 20)
        add(arp, at, .035*section, .35*np.sin(step*.5))
        add(arp, at+.3, .010*section, -.5)

for bar in range(int(duration/(beat*8))+1):
    at = bar*beat*8
    root = roots[bar%4]
    t = clock(3.4)
    env = np.minimum(1, t/.45)*np.minimum(1, (3.4-t)/.65)
    chord = np.zeros_like(t)
    for offset in [0, 3 if bar%4 in [0, 1] else 4, 7, 12]:
        f = root*2*2**(offset/12)
        chord += np.sin(2*np.pi*f*t)*.32 + np.sin(2*np.pi*f*1.004*t)*.20
    add(chord*env, at, .045, -.3)
    add(chord*env, at+.04, .040, .3)

at = 0
chapters = []
for s in shots:
    chapters.append({"start": round(at, 3), **s})
    if s["kind"] in ["king", "artillery", "dragon", "frog"]:
        impact(at+.6, .40)
        sweep(at+.05, .5, .35)
    elif s["kind"] in ["giant", "dash", "rebirth", "finale"]:
        impact(at+.2, .75)
        sweep(at+.05, .5, .40)
    elif s["kind"] in ["fire", "frost", "possession", "rescue"]:
        sweep(at+.1, .7, .34)
        impact(at+.7, .3)
    if s["kind"] == "lightning":
        for offset in [.25, 2.3, 4.8, 5.6]:
            t = clock(.32)
            crack = rng.normal(0, .24, len(t)).astype(np.float32)*np.exp(-t*26)
            add(crack, at+offset, .35)
            impact(at+offset, .22)
    at += s["duration"]

sweep(73.2, 2.6, .35)
impact(75.8, .85)
impact(95, .6)
timeline = np.arange(len(mix))/sr
mix *= (np.minimum(1, timeline/1.0)*np.minimum(1, (duration-timeline)/2.4))[:, None]
# Gentle saturation, safe peak and a finished stereo soundtrack.
mix = np.tanh(mix*1.3)
mix *= .90/max(.9, np.max(np.abs(mix)))
pcm = (mix*32767).astype("<i2")
with wave.open(str(out / "soundtrack.wav"), "wb") as wav:
    wav.setnchannels(2)
    wav.setsampwidth(2)
    wav.setframerate(sr)
    wav.writeframes(pcm.tobytes())
(out / "chapters.json").write_text(json.dumps(chapters, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Original score: {duration:.3f}s, stereo {sr} Hz; peak {np.max(np.abs(mix)):.3f}")
