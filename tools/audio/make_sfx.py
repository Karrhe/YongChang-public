"""Synthesize the six sound effects (TEAM-001 §4 event names) as original 16-bit mono WAVs.
No samples are used, so the sounds are this project's own CC BY 4.0 assets.
Usage: python make_sfx.py OUTDIR   (writes gong.wav, tide.wav, hit.wav, repair.wav, beacon.wav, lantern.wav)"""
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 22050
RNG = np.random.default_rng(1558)  # fixed seed: the files come out the same every time


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack, decay):
    """attack in seconds, decay = time constant in seconds"""
    x = np.arange(n) / RATE
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / decay)


def lowpass(x, cutoff):
    """one-pole low-pass, cutoff in Hz (a number, or one value per sample for a sweep)"""
    k = np.broadcast_to(np.exp(-2 * np.pi * np.asarray(cutoff, dtype=float) / RATE), x.shape)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - k[i]) * v + k[i] * acc
        y[i] = acc
    return y


def gong():
    x = t(2.6)
    partials = [(110, 1.0, 1.8), (163, 0.6, 1.4), (227, 0.45, 1.1), (302, 0.3, 0.8), (391, 0.2, 0.6), (518, 0.12, 0.4)]
    s = sum(a * np.sin(2 * np.pi * f * x * (1 + 0.004 * np.exp(-x * 3))) * np.exp(-x / d) for f, a, d in partials)
    s += 0.25 * RNG.standard_normal(len(x)) * env(len(x), 0.001, 0.03)  # mallet strike
    return s * env(len(x), 0.003, 3.0)


def tide():
    x = t(2.2)
    noise = lowpass(RNG.standard_normal(len(x)), 500)
    swell = np.sin(np.pi * x / x[-1]) ** 2
    return noise * swell * 3.0


def hit():
    x = t(0.35)
    thump = np.sin(2 * np.pi * (90 - 40 * x) * x) * env(len(x), 0.002, 0.08)
    crack = lowpass(RNG.standard_normal(len(x)), 2500) * env(len(x), 0.001, 0.03) * 2
    return thump + crack


def knock(f):
    x = t(0.18)
    body = np.sin(2 * np.pi * f * x) * env(len(x), 0.001, 0.04)
    tick = lowpass(RNG.standard_normal(len(x)), 3000) * env(len(x), 0.0005, 0.01)
    return body + tick


def repair():
    gap = np.zeros(int(RATE * 0.12))
    return np.concatenate([knock(220), gap, knock(190)])


def beacon():
    x = t(1.6)
    roar = lowpass(RNG.standard_normal(len(x)), 300 + 900 * x / x[-1]) * 2.5
    crackle = (RNG.random(len(x)) < 0.004) * RNG.standard_normal(len(x)) * 3
    shape = np.clip(x / 0.4, 0, 1) * np.exp(-np.clip(x - 1.0, 0, None) / 0.3)
    return (roar + crackle) * shape


def lantern():
    x = t(1.8)
    s = sum(a * np.sin(2 * np.pi * f * x) for f, a in [(880, 1.0), (1320, 0.35), (1760, 0.2)])
    return s * env(len(x), 0.005, 0.6) * 0.6


def write(path, data, peak=0.7):
    data = data / (np.max(np.abs(data)) + 1e-9) * peak
    pcm = (data * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main(outdir):
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    for name, fn, peak in [("gong", gong, 0.8), ("tide", tide, 0.45), ("hit", hit, 0.7),
                           ("repair", repair, 0.6), ("beacon", beacon, 0.55), ("lantern", lantern, 0.5)]:
        write(out / f"{name}.wav", fn(), peak)
    print("ok")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
