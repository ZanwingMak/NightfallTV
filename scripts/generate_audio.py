#!/usr/bin/env python3
"""生成原创离线循环声景；只依赖 Python 标准库。"""
from array import array
import math
from pathlib import Path
import random
import wave

ROOT = Path(__file__).resolve().parents[1] / "NightfallTV/Resources/Audio"


def generate(kind: str) -> None:
    """合成自然声纹理或有色噪音，用重叠交叉淡化消除循环接缝。"""
    rate, length, overlap = 22050, 12 * 22050, 2 * 22050
    rng = random.Random(417 + sum(map(ord, kind)))
    values = []
    low, brown, b0, b1, b2 = 0.0, 0.0, 0.0, 0.0, 0.0
    for index in range(length + overlap):
        t = index / rate
        white = rng.uniform(-1, 1)
        low = 0.985 * low + 0.015 * white
        brown = (brown + 0.018 * white) / 1.018
        b0 = 0.99765 * b0 + white * 0.099046
        b1 = 0.963 * b1 + white * 0.2965164
        b2 = 0.57 * b2 + white * 1.0526913
        pink = (b0 + b1 + b2 + white * 0.1848) * 0.08
        if kind == "pink":
            sample = pink
        elif kind == "brown":
            sample = brown * 3.8
        elif kind == "rain":
            sample = pink * 0.65 + white * 0.065 + low * 0.6
        elif kind == "ocean":
            swell = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 0.65)) ** 2
            sample = (pink * 0.7 + brown * 3.2) * swell
        elif kind == "stream":
            sample = pink * 0.4 + low * 1.3 + math.sin(t * 1700 + math.sin(t * 22) * 18) * 0.005
        else:
            crackle = white * (0.12 if rng.random() > 0.999 else 0.008)
            sample = brown * 1.7 + pink * 0.15 + crackle
        values.append(sample)
    for index in range(overlap):
        alpha = index / overlap
        values[index] = values[length + index] * (1 - alpha) + values[index] * alpha
    peak = max(abs(value) for value in values[:length]) or 1
    samples = array("h", (int(value / peak * 18000) for value in values[:length]))
    ROOT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(ROOT / f"{kind}.wav"), "wb") as output:
        output.setparams((1, 2, rate, length, "NONE", "not compressed"))
        output.writeframes(samples.tobytes())
    print(f"Generated {kind}: 12 seconds, mono PCM")


if __name__ == "__main__":
    for name in ["rain", "ocean", "stream", "fire", "pink", "brown"]:
        generate(name)
