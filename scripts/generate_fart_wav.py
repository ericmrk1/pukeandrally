#!/usr/bin/env python3
"""Generate a short fart-like WAV file for the UltraRunner bathroom sound."""
import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100
DURATION = 0.24  # seconds
# Output next to UltraRunner app (parent of scripts/)
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "UltraRunner")
FILENAME = os.path.join(OUT_DIR, "fart.wav")

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    n_frames = int(SAMPLE_RATE * DURATION)
    # Noise with decay envelope and slight low-pass (smoothing)
    r = 0.0
    samples = []
    for i in range(n_frames):
        r = r * 0.96 + (random.random() - 0.5) * 0.35
        t = i / SAMPLE_RATE
        envelope = math.exp(-t * 14) * (1 - math.exp(-t * 90))
        sample = r * envelope * 0.7
        sample = max(-1.0, min(1.0, sample))
        samples.append(sample)
    # Convert to 16-bit PCM
    with wave.open(FILENAME, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        for s in samples:
            pcm = int(s * 32767)
            wav.writeframes(struct.pack("<h", pcm))
    print(f"Wrote {os.path.abspath(FILENAME)} ({DURATION}s, {SAMPLE_RATE} Hz mono)")

if __name__ == "__main__":
    main()
