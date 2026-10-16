"""Rebuild the three original, seamlessly looping battle compositions."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
MELODIES = [
    [76, 0, 76, 79, 83, 79, 78, 74, 76, 79, 83, 86, 84, 83, 79, 78,
     74, 0, 74, 78, 81, 78, 76, 73, 74, 78, 81, 84, 83, 81, 78, 74,
     72, 76, 79, 84, 83, 79, 76, 72, 74, 78, 81, 86, 84, 81, 78, 74,
     76, 79, 83, 88, 86, 83, 79, 76, 75, 78, 83, 87, 83, 78, 75, 71],
    [81, 76, 79, 81, 84, 83, 81, 79, 76, 79, 81, 88, 86, 84, 83, 79,
     77, 72, 76, 77, 81, 79, 77, 76, 72, 76, 77, 84, 83, 81, 79, 76,
     79, 74, 77, 79, 83, 81, 79, 77, 74, 77, 79, 86, 84, 83, 81, 77,
     76, 71, 75, 76, 79, 78, 76, 75, 71, 75, 76, 83, 81, 79, 78, 75],
    [76, 75, 76, 83, 82, 83, 79, 78, 76, 0, 88, 87, 83, 79, 78, 75,
     72, 71, 72, 79, 78, 79, 76, 75, 72, 0, 84, 83, 79, 76, 75, 71,
     74, 73, 74, 81, 80, 81, 77, 76, 74, 0, 86, 85, 81, 77, 76, 73,
     71, 70, 71, 78, 77, 78, 75, 74, 71, 75, 78, 83, 87, 83, 78, 75],
]

def frequency(note):
    return 440 * 2 ** ((note - 69) / 12)

def compose(name, variant, bpm, roots):
    step = 60 / bpm / 2
    count = round(128 * step * RATE)
    samples = bytearray(count * 2)
    rng = random.Random(42)
    for i in range(count):
        t = i / RATE
        tick = int(t / step)
        local = t % step
        root = roots[(tick // 16) % 4]
        note = MELODIES[variant][tick % 64]
        if tick >= 64 and tick % 8 >= 4 and note:
            note += 12
        env = min(1, local / .004) * max(0, 1 - local / (step * .92)) ** .5
        lead = 0
        if note:
            phase = (local * frequency(note)) % 1
            lead = (.65 if phase < .25 else -.22) * env * .36
        bass_note = root + (12 if tick % 4 == 2 else 0)
        bass_phase = local * frequency(bass_note) % 1
        bass = (1 - 4 * abs(bass_phase - .5)) * env * .22
        chord = [root + 24, root + 27, root + 31, root + 36][tick % 4]
        arp_phase = local * frequency(chord) % 1
        arp = (1 if arp_phase < .5 else -1) * env * .065
        drum_time = t % (step * 2)
        kick = math.sin(2 * math.pi * (65 * drum_time + 6 * (1 - math.exp(-drum_time * 35)))) * math.exp(-drum_time * 25) * .28
        noise = rng.uniform(-1, 1)
        snare = noise * math.exp(-local * 24) * .18 if tick % 4 == 2 else 0
        hat = noise * math.exp(-local * 85) * .065
        seam = min(1, t / .003, (count / RATE - t) / .003)
        value = max(-1, min(1, (lead + bass + arp + kick + snare + hat) * seam))
        struct.pack_into('<h', samples, i * 2, int(value * 29000))
    with wave.open(str(Path(__file__).with_name(name + '.wav')), 'wb') as out:
        out.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        out.writeframes(samples)

if __name__ == '__main__':
    compose('wild', 0, 148, [40, 38, 36, 35])
    compose('rival', 1, 156, [45, 41, 43, 40])
    compose('guardian', 2, 168, [40, 36, 38, 35])
