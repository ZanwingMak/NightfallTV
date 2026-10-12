#!/usr/bin/env python3
"""按署名清单导入公开自然录音，生成保持立体声与动态的离线循环。"""
import hashlib
import json
import subprocess
import urllib.request
import numpy as np
from generate_audio import RATE, ROOT, write_audio

MANIFEST = ROOT / 'NightfallTV/Resources/Audio/audio-credits.json'
CACHE = ROOT / 'artifacts/audio-sources'


def import_recording(credit: dict) -> None:
    """验证源文件，去掉超低频杂音，并以三秒等增益交叉淡化连接循环边界。"""
    source = CACHE / (credit['sound'] + '.' + credit['downloadURL'].rsplit('.', 1)[-1])
    CACHE.mkdir(parents=True, exist_ok=True)
    if not source.exists():
        request = urllib.request.Request(credit['downloadURL'], headers={'User-Agent': 'NightfallTV/1.0.2 (open-source audio; attribution included)'})
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read(40_000_001)
        if len(data) > 40_000_000:
            raise ValueError('Source exceeds 40 MB')
        source.write_bytes(data)
    data = source.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if credit.get('sourceSHA256') and credit['sourceSHA256'] != digest:
        raise ValueError('Source hash mismatch: ' + credit['sound'])
    credit['sourceSHA256'] = digest
    decoded = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(source), '-ss', str(credit['start']),
                              '-t', str(credit['maxSeconds']), '-af', 'highpass=f=30',
                              '-ar', str(RATE), '-ac', '2', '-f', 'f32le', 'pipe:1'],
                             check=True, capture_output=True).stdout
    samples = np.frombuffer(decoded, dtype='<f4').reshape(-1, 2).astype(np.float64)
    overlap = RATE * 3
    if len(samples) < RATE * 20:
        raise ValueError('Recording is too short')
    length = len(samples) - overlap
    alpha = (0.5 - 0.5 * np.cos(np.linspace(0, np.pi, overlap)))[:, None]
    samples[:overlap] = samples[length:] * (1 - alpha) + samples[:overlap] * alpha
    credit.update(write_audio(credit['sound'], samples[:length]))
    credit['assetSHA256'] = hashlib.sha256((MANIFEST.parent / (credit['sound'] + '.m4a')).read_bytes()).hexdigest()


def main() -> None:
    """顺序导入清单中的实录，保存可复核的文件散列和音频规格。"""
    credits = json.loads(MANIFEST.read_text())
    for credit in credits:
        import_recording(credit)
    MANIFEST.write_text(json.dumps(credits, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main()
