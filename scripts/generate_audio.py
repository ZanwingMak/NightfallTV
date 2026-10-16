#!/usr/bin/env python3
"""生成白、粉、棕噪音；自然声景由 import_audio.py 导入。需要 NumPy 和 FFmpeg。"""
from pathlib import Path
import subprocess
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RATE = 44100


def write_audio(kind: str, samples: np.ndarray) -> dict:
    """移除直流、匹配低响度并限制峰值，以 ALAC 保存完整 PCM 循环。"""
    samples = samples - samples.mean(axis=0)
    target = 10 ** (-25 / 20)
    ceiling = 10 ** (-8 / 20)
    for _ in range(4):
        samples *= target / float(np.sqrt(np.mean(samples ** 2)))
        samples = ceiling * np.tanh(samples / ceiling)
    rms = float(np.sqrt(np.mean(samples ** 2)))
    peak = float(np.max(np.abs(samples)))
    output = ROOT / 'NightfallTV/Resources/Audio' / f'{kind}.m4a'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '2',
                    '-i', 'pipe:0', '-c:a', 'alac', '-sample_fmt', 's16p', str(output)],
                   input=samples.astype('<f4').tobytes(), check=True)
    stats = {'duration': len(samples) / RATE, 'rmsDBFS': round(float(20 * np.log10(rms)), 2),
             'peakDBFS': round(float(20 * np.log10(peak)), 2), 'sampleRate': RATE, 'channels': 2}
    print(kind, stats)
    return stats


def generate(kind: str) -> dict:
    """用周期频谱生成 60 秒立体声白/粉/棕噪音，保留频谱斜率并避免短周期听感。"""
    count = RATE * 60
    rng = np.random.default_rng({'pink': 417, 'brown': 418, 'white': 419}[kind])
    frequencies = np.fft.rfftfreq(count, 1 / RATE)
    safe = np.maximum(frequencies, 20)
    magnitude = safe ** {'white': 0, 'pink': -0.5, 'brown': -1}[kind]
    magnitude[frequencies < 20] *= (frequencies[frequencies < 20] / 20) ** 2
    magnitude *= 1 / np.sqrt(1 + (frequencies / 12000) ** 8)
    spectrum = (rng.normal(size=(len(frequencies), 2)) + 1j * rng.normal(size=(len(frequencies), 2))) * magnitude[:, None]
    spectrum[0] = 0
    samples = np.fft.irfft(spectrum, n=count, axis=0)
    # 周期信号无需首尾淡入淡出，不会每次循环都出现静音凹陷。
    return write_audio(kind, samples)


if __name__ == '__main__':
    for name in ['white', 'pink', 'brown']:
        generate(name)
