#!/usr/bin/env python3
"""Synthesises the game's two original background loops (no samples, no third-party music).

- winter_lights.ogg: music box melody over warm pads, soft bass and, in the second half,
  a faint sleigh-bell shimmer. Slow (78 bpm) and quiet so it never tires.
- summer_breeze.ogg: the same tune on a soft marimba with a light shaker, a little
  livelier (90 bpm).

Both loop seamlessly: the piece ends on the dominant and every voice's tail is wrapped
back onto the start before encoding.

Run from the repo root:  python3 tools/compose_music.py
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "audio"
NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}

# One chord per 4/4 bar: A section, B section (repeated with variation).
CHORDS = ["C", "Am", "F", "G", "C", "Am", "Dm", "G",
          "F", "G", "Em", "Am", "F", "G", "C", "C"]
CHORD_TONES = {"C": ["C", "E", "G"], "Am": ["A", "C", "E"], "F": ["F", "A", "C"], "G": ["G", "B", "D"],
               "Dm": ["D", "F", "A"], "Em": ["E", "G", "B"]}
# (note, beats) per bar; "-" is a rest.
MELODY = [
    [("E5", 1), ("G5", 1), ("C6", 1.5), ("B5", 0.5)],
    [("A5", 2), ("E5", 1), ("C5", 1)],
    [("F5", 1), ("A5", 1), ("C6", 1), ("A5", 1)],
    [("G5", 3), ("D5", 1)],
    [("E5", 1), ("G5", 1), ("C6", 1), ("D6", 1)],
    [("E6", 2), ("C6", 1), ("A5", 1)],
    [("F5", 1), ("A5", 1), ("D6", 1), ("C6", 1)],
    [("B5", 2), ("G5", 2)],
    [("A5", 1.5), ("G5", 0.5), ("F5", 1), ("A5", 1)],
    [("B5", 1.5), ("A5", 0.5), ("G5", 1), ("D5", 1)],
    [("G5", 1), ("B5", 1), ("E6", 1.5), ("D6", 0.5)],
    [("C6", 2), ("A5", 2)],
    [("A5", 1), ("C6", 1), ("F6", 1), ("E6", 1)],
    [("D6", 1), ("B5", 1), ("G5", 1), ("A5", 0.5), ("B5", 0.5)],
    [("C6", 3), ("G5", 1)],
    [("E5", 2), ("C5", 2)],
]
LAST_BAR_SECOND_PASS = [("D5", 2), ("G5", 2)]


def freq(note: str) -> float:
    name, octave = note[:-1], int(note[-1])
    midi = 12 * (octave + 1) + NOTE_INDEX[name]
    return 440.0 * 2 ** ((midi - 69) / 12)


def envelope(n: int, attack: float, decay: float) -> np.ndarray:
    t = np.arange(n) / RATE
    env = np.exp(-t / decay)
    a = max(1, int(attack * RATE))
    env[:a] *= np.linspace(0, 1, a)
    return env


def music_box(f: float, seconds: float) -> np.ndarray:
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    tone = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / 0.5)
            + 0.18 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t / 0.25)
            + 0.08 * np.sin(2 * np.pi * f * 4.17 * t) * np.exp(-t / 0.12))
    return tone * envelope(n, 0.004, 1.1)


def marimba(f: float, seconds: float) -> np.ndarray:
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    tone = (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t / 0.08)
            + 0.08 * np.sin(2 * np.pi * f * 9.8 * t) * np.exp(-t / 0.03))
    return tone * envelope(n, 0.003, 0.45)


def pad(notes: list, seconds: float) -> np.ndarray:
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for note in notes:
        f = freq(note)
        for detune in (-0.004, 0.0, 0.004):
            out += np.sin(2 * np.pi * f * (1 + detune) * t) + 0.2 * np.sin(2 * np.pi * 2 * f * (1 + detune) * t)
    fade = min(n // 3, int(0.9 * RATE))
    env = np.ones(n)
    env[:fade] = np.linspace(0, 1, fade) ** 2
    env[-fade:] = np.linspace(1, 0, fade) ** 2
    return out * env / (len(notes) * 3)


def bass(f: float, seconds: float) -> np.ndarray:
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    return (np.sin(2 * np.pi * f * t) + 0.15 * np.sin(4 * np.pi * f * t)) * envelope(n, 0.02, 1.4)


def shimmer(seconds: float, rng: np.random.Generator, centre: float) -> np.ndarray:
    """A soft burst of high band-limited noise: sleigh bells or a shaker."""
    n = int(seconds * RATE)
    noise = rng.standard_normal(n)
    spectrum = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(n, 1 / RATE)
    spectrum *= np.exp(-((freqs - centre) / (centre * 0.25)) ** 2)
    return np.fft.irfft(spectrum, n) * envelope(n, 0.002, 0.07)


def reverb(signal: np.ndarray, seconds: float, mix: float, rng: np.random.Generator) -> np.ndarray:
    n = int(seconds * RATE)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / RATE / (seconds / 5))
    ir[0] = 0
    size = len(signal) + n
    wet = np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(ir, size), size)
    wet = wet / (np.max(np.abs(wet)) + 1e-9) * np.max(np.abs(signal))
    out = np.zeros(size)
    out[:len(signal)] += signal * (1 - mix)
    out += wet * mix
    return out


def add(track: np.ndarray, start: float, sound: np.ndarray, gain: float) -> None:
    i = int(start * RATE)
    end = min(len(track), i + len(sound))
    track[i:end] += sound[:end - i] * gain


def compose(bpm: float, instrument, seed: int, shimmer_centre: float, shimmer_gain: float, pad_gain: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar = 4 * beat
    bars = len(CHORDS) * 2
    length = bars * bar
    tail = 4.0
    melody = np.zeros(int((length + tail) * RATE))
    backing = np.zeros_like(melody)
    for index in range(bars):
        start = index * bar
        chord = CHORDS[index % len(CHORDS)]
        if index == bars - 1:
            chord = "G"
        tones = CHORD_TONES[chord]
        add(backing, start, pad([t + "3" for t in tones] + [tones[0] + "4"], bar + 0.6), pad_gain)
        add(backing, start, bass(freq(tones[0] + "2"), bar * 0.9), 0.32)
        add(backing, start + 2 * beat, bass(freq(tones[0] + "2"), bar * 0.45), 0.2)
        line = MELODY[index % len(MELODY)]
        if index == bars - 1:
            line = LAST_BAR_SECOND_PASS
        second_pass = index >= len(CHORDS)
        t = start
        for note, beats in line:
            if note != "-":
                add(melody, t, instrument(freq(note), beats * beat + 1.2), 0.42)
            t += beats * beat
        if second_pass:
            for step in range(8):
                arp = tones[step % 3] + ("4" if step < 4 else "5")
                add(melody, start + step * beat / 2, instrument(freq(arp), beat), 0.12)
            for step in range(8):
                if step % 2 == 1:
                    add(backing, start + step * beat / 2, shimmer(0.25, rng, shimmer_centre), shimmer_gain)
    mix = melody + backing
    mix = reverb(mix, 2.6, 0.28, rng)
    loop_samples = int(length * RATE)
    looped = mix[:loop_samples].copy()
    spill = mix[loop_samples:]
    looped[:len(spill)] += spill[:loop_samples]
    looped /= np.max(np.abs(looped)) + 1e-9
    return looped * 0.8


def stereo(mono: np.ndarray) -> np.ndarray:
    delay = int(0.011 * RATE)
    left = mono
    right = np.roll(mono, delay)
    return np.stack([left * 0.92 + right * 0.08, right * 0.92 + left * 0.08], axis=1)


def write_ogg(samples: np.ndarray, path: Path) -> None:
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as handle:
        wav_path = Path(handle.name)
    pcm = (np.clip(samples, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(wav_path), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "4", str(path)], check=True)
    wav_path.unlink()


def main() -> None:
    winter = compose(78, music_box, 7, 7500.0, 0.05, 0.16)
    write_ogg(stereo(winter), OUT / "winter_lights.ogg")
    summer = compose(90, marimba, 11, 5000.0, 0.035, 0.12)
    write_ogg(stereo(summer), OUT / "summer_breeze.ogg")
    print("wrote", OUT / "winter_lights.ogg", OUT / "summer_breeze.ogg")


if __name__ == "__main__":
    main()
