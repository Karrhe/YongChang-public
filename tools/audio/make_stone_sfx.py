"""Reconstruct the AUD-2 stone sounds from the documented synthesis design.

Requires NumPy. Run `python make_stone_sfx.py OUTDIR` to write
stone_place.wav and stone_bite.wav as 16-bit mono PCM at 22,050 Hz.
The reconstruction uses original synthesis and differs from the shipped WAVs.
"""

import argparse
import wave
from pathlib import Path

import numpy as np

RATE = 22050
SEED = 1558
FADE_FRAMES = round(0.018 * RATE)


def mix_impact(sound, rng, delay, partials, noise_band, noise_gain, noise_decay, attack):
    offset = round(delay * RATE)
    tail = sound[offset:]
    time = np.arange(len(tail)) / RATE
    impact = np.zeros_like(time)

    # Each partial specifies frequency, amplitude and exponential decay time.
    for frequency, gain, decay in partials:
        impact += gain * np.sin(2 * np.pi * frequency * time) * np.exp(-time / decay)

    bins = np.fft.rfftfreq(len(tail), 1 / RATE)
    spectrum = np.fft.rfft(rng.standard_normal(len(tail)))
    low, high = noise_band
    spectrum[(bins < low) | (bins > high)] = 0
    noise = np.fft.irfft(spectrum, n=len(tail))
    impact += noise_gain * noise * np.exp(-time / noise_decay)
    tail += impact * np.minimum(time / attack, 1)


def stone_place():
    sound = np.zeros(round(0.300 * RATE))
    rng = np.random.default_rng(SEED)
    mix_impact(
        sound, rng, 0,
        [(133, 1.0, 0.032), (209, 0.65, 0.036), (367, 0.45, 0.020),
         (684, 0.55, 0.020), (1128, 0.36, 0.013)],
        (350, 4400), 0.55, 0.008, 0.0015,
    )
    mix_impact(
        sound, rng, 0.036,
        [(133, 0.18, 0.027), (209, 0.17, 0.024), (554, 0.19, 0.022),
         (1017, 0.11, 0.013)],
        (350, 2600), 0.17, 0.006, 0.001,
    )
    return sound


def stone_bite():
    sound = np.zeros(round(0.160 * RATE))
    rng = np.random.default_rng(SEED + 1)
    mix_impact(
        sound, rng, 0,
        [(698, 0.24, 0.013), (1427, 0.69, 0.012), (2371, 0.57, 0.010),
         (3752, 0.42, 0.008), (5210, 0.17, 0.005)],
        (1400, 5400), 0.85, 0.009, 0.0006,
    )
    mix_impact(
        sound, rng, 0.021,
        [(334, 0.49, 0.021), (631, 0.46, 0.024), (1187, 0.62, 0.020),
         (1994, 0.49, 0.015), (3011, 0.31, 0.010)],
        (700, 4400), 0.68, 0.008, 0.0008,
    )
    return sound


def write(path, sound, peak_dbfs):
    sound[-FADE_FRAMES:] *= 0.5 * (1 + np.cos(np.linspace(0, np.pi, FADE_FRAMES)))
    peak = 32768 * 10 ** (peak_dbfs / 20)
    pcm = np.rint(sound * (peak / np.max(np.abs(sound)))).astype("<i2")
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("outdir", type=Path, help="directory for the generated WAVs")
    args = parser.parse_args()
    args.outdir.mkdir(parents=True, exist_ok=True)
    write(args.outdir / "stone_place.wav", stone_place(), -6.0)
    write(args.outdir / "stone_bite.wav", stone_bite(), -1.5)


if __name__ == "__main__":
    main()
