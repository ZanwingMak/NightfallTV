"""Import openly licensed real footage listed in the bundled credit manifest."""
import hashlib
import json
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "NightfallTV/Resources/Media"
RETRY = ROOT / "artifacts/media-source/retry-after"


def import_clip(credit):
    """Download one source, create a silent HD excerpt and its actual preview frame."""
    source = ROOT / "artifacts/media-source" / (credit["scene"] + ".source")
    source.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(credit["downloadURL"], headers={"User-Agent": "NightfallTV/1.0 (github.com/ZanwingMak/NightfallTV)"})
    digest = hashlib.sha256()
    try:
        with urllib.request.urlopen(request, timeout=60) as response, source.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                output.write(chunk)
                if output.tell() > 300 * 1024 * 1024:
                    raise ValueError("Source exceeds the import size limit")
    except urllib.error.HTTPError as error:
        if error.code == 429:
            RETRY.write_text(str(time.time() + int(error.headers.get("Retry-After", "600"))))
        raise
    if source.stat().st_size != credit["sourceBytes"]:
        raise ValueError("Source size differs from reviewed metadata")
    credit["sourceSHA256"] = digest.hexdigest()
    video = MEDIA / (credit["scene"] + ".mp4")
    subprocess.run(["ffmpeg", "-v", "error", "-ss", str(credit["start"]), "-i", str(source), "-t", str(credit["duration"]),
                    "-an", "-vf", "scale='min(1920,iw)':-2,fps=24,format=yuv420p", "-c:v", "libx264", "-preset", "medium", "-crf", "22",
                    "-movflags", "+faststart", "-y", str(video)], check=True)
    subprocess.run(["ffmpeg", "-v", "error", "-ss", "2", "-i", str(video), "-frames:v", "1", "-vf", "scale=1280:-2",
                    "-pix_fmt", "rgb24", "-y", str(MEDIA / (credit["scene"] + "-poster.png"))], check=True)
    credit["assetSHA256"] = hashlib.sha256(video.read_bytes()).hexdigest()
    source.unlink()
    print("Imported real footage:", credit["scene"], flush=True)


def main():
    """Import sequentially, respect server backoff and skip only verified complete assets."""
    if RETRY.exists():
        deadline = float(RETRY.read_text())
        if deadline > time.time():
            print("Respecting Wikimedia Retry-After before downloading further footage.", flush=True)
        while deadline > time.time():
            time.sleep(min(30, deadline - time.time()))
        RETRY.unlink()
    manifest = MEDIA / "credits.json"
    credits = json.loads(manifest.read_text())
    for credit in credits:
        video = MEDIA / (credit["scene"] + ".mp4")
        poster = MEDIA / (credit["scene"] + "-poster.png")
        if video.exists() and poster.exists() and credit.get("assetSHA256") == hashlib.sha256(video.read_bytes()).hexdigest():
            continue
        import_clip(credit)
        manifest.write_text(json.dumps(credits, ensure_ascii=False, indent=2) + "\n")
        time.sleep(60)


if __name__ == "__main__":
    main()
