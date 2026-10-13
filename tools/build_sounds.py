"""Converts the game's sound effects into Playdate-ready WAVs.

Run from the repo root:  python3 tools/build_sounds.py   (needs ffmpeg)

Sources are Kenney packs (CC0), vendored in assets/kenney-sounds/. Output is
mono, 22.05 kHz, 16-bit WAV in source/sounds/, which pdc compiles into the
game. SOUNDS maps each name the game plays (see source/audio.lua) to its
source file; footsteps get five variations per surface.
"""

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/kenney-sounds"
OUT = ROOT / "source/sounds"

SOUNDS = {
    "sword": "knifeSlice",
    "shield": "metalPot1",
    "hit": "impactPunch_medium_000",
    "hurt": "retro2_hurt1",
    "chest": "creak1",
    "pickup": "retro2_upgrade1",
    "coin": "handleCoins",
    "unlock": "metalLatch",
    "door": "doorOpen_2",
    "locked": "doorOpen_1",
    "faint": "retro2_gameover1",
    "win": "retro2_secret1",
}
SURFACES = ("grass", "wood", "concrete")
STEP_VARIATIONS = 5


def convert(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", str(src), "-ac", "1", "-ar", "22050", "-c:a", "pcm_s16le", str(dst)],
        check=True,
    )


def main():
    for name, src in SOUNDS.items():
        convert(SRC / f"{src}.ogg", OUT / f"{name}.wav")
    for surface in SURFACES:
        for i in range(STEP_VARIATIONS):
            convert(SRC / f"footstep_{surface}_{i:03d}.ogg", OUT / f"steps/{surface}_{i}.wav")
    print(f"{len(SOUNDS)} effects, {len(SURFACES) * STEP_VARIATIONS} footsteps")


if __name__ == "__main__":
    main()
