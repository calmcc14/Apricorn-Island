"""Render three original, seamless PCM loops with synthesized computer sounds."""

from array import array
from math import exp, sin, tanh, tau
from pathlib import Path
import random
import wave


RATE = 22050
HERE = Path(__file__).resolve().parent
RANDOM = random.Random(2368)


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def add(buffer, start, duration, voice, gain):
    offset = round(start * RATE)
    count = round(duration * RATE)
    for index in range(count):
        t = index / RATE
        edge = min(1, index / 190, (count - 1 - index) / 340)
        buffer[(offset + index) % len(buffer)] += voice(t) * gain * edge


def sine(t, frequency):
    return sin(tau * t * frequency)


def chord_pad(t, note, duration):
    modulation = 1 + 0.003 * sine(t, .21)
    shimmer = sine(t, note * 2 * modulation) * (.16 + .10 * sine(t, .38))
    breath = min(1, t / 1.5, max(0, duration - t) / 1.8)
    return breath * (sine(t, note) + .28 * sine(t, note * .998) + shimmer)


def boot(t):
    frequencies = (196, 370, 554, 831, 1108)
    step = int(t * 6)
    return sine(t, frequencies[step % len(frequencies)]) * exp(-(t * 6 % 1) * 2.8)


def modem(t):
    carrier = (980, 1180, 1650, 1850)[int(t * 27) % 4]
    sweep = sin(tau * (1100 * t + 150 * t * t) + 2.2 * sine(t, 80))
    handshake = sine(t, carrier) + .45 * sine(t, carrier / 1.47)
    return (.57 * sweep + .30 * handshake + .13 * RANDOM.uniform(-1, 1)) * (0.7 + .3 * sine(t, 12))


def crash(t):
    decaying_frequency = 1500 * (1 - exp(-4 * t))
    return (0.55 * sine(t, max(33, 1610 - decaying_frequency)) + .45 * RANDOM.uniform(-1, 1)) * exp(-1.7 * t)


def static(t):
    return RANDOM.uniform(-1, 1) * (.28 + .72 * (sine(t, 33) > 0))


def computer_bass(t, frequency):
    wobble = 1.8 * sine(t, 31)
    return tanh(1.7 * sin(tau * t * frequency + wobble)) * exp(-3.3 * t)


def arp(t, frequency):
    carrier = sin(tau * t * frequency + 1.1 * sine(t, frequency * 2.03))
    return carrier * exp(-7 * t)


def ambient():
    loop = [0.0] * (RATE * 48)
    chords = [(45, 52, 57, 60), (41, 48, 55, 57), (48, 55, 59, 64),
              (43, 50, 57, 62), (46, 53, 57, 60), (40, 47, 55, 59)]
    for index, chord in enumerate(chords):
        start = index * 8
        for note in chord:
            frequency = hz(note)
            add(loop, start - 1.1, 10.2, lambda t, f=frequency: chord_pad(t, f, 10.2), .105)
        for melody_index, offset in enumerate((1.2, 3.0, 5.75)):
            frequency = hz(chord[(melody_index * 2 + index) % 4] + 24)
            for echo, volume in enumerate((.13, .062, .027)):
                add(loop, start + offset + echo * .43, 2.1,
                    lambda t, f=frequency: (sine(t, f) + .22 * sine(t, f * 2.02)) * exp(-2.8 * t), volume)
    return loop


def interference():
    loop = [0.0] * (RATE * 48)
    for start, voice, duration, gain in [
        (2.5, static, .43, .32), (5.2, boot, .85, .21), (9.9, modem, 1.8, .25),
        (16.8, crash, 1.3, .21), (19.2, static, .27, .34), (24.8, boot, 1.1, .22),
        (29.4, modem, 1.55, .18), (34.2, static, .62, .26), (38.6, crash, 1.35, .23),
        (45.2, modem, 1.2, .19), (47.8, static, .7, .2),
    ]:
        add(loop, start, duration, voice, gain)
    return loop


def battle():
    beat = 60 / 144
    loop = [0.0] * round(RATE * beat * 96)
    roots = (33, 33, 36, 34, 33, 33, 29, 31, 33, 33, 36, 37,
             38, 34, 31, 28, 33, 33, 36, 34, 38, 34, 28, 32)
    motif = (0, 12, 7, 15, 0, 19, 10, 7, 0, 12, 3, 15, 0, 22, 10, 19)
    for bar, root in enumerate(roots):
        start = bar * beat * 4
        for step in (0, 3, 6, 8, 11, 14):
            frequency = hz(root + (12 if step == 14 else 0))
            add(loop, start + step * beat / 4, .24, lambda t, f=frequency: computer_bass(t, f), .25)
        for step, interval in enumerate(motif):
            if (bar + step) % 7 == 5:
                continue
            frequency = hz(root + 24 + interval + (12 if 12 <= bar < 16 and step % 2 else 0))
            add(loop, start + step * beat / 4, .21, lambda t, f=frequency: arp(t, f), .10)
        for pulse in range(4):
            add(loop, start + pulse * beat, .22,
                lambda t: sin(tau * (44 * t + 10 * (1 - exp(-30 * t)))) * exp(-14 * t), .34)
            if pulse % 2:
                add(loop, start + pulse * beat, .17, lambda t: (.78 * static(t) + .22 * sine(t, 165)) * exp(-16 * t), .25)
        for step in (2, 4, 7, 10, 12, 15):
            add(loop, start + step * beat / 4, .054, lambda t: static(t) * exp(-60 * t), .15)
        if bar % 4 == 0:
            add(loop, start + .25 * beat, 1.27, boot, .11)
        if bar % 4 == 2:
            add(loop, start + beat, .85, modem, .13)
        if bar % 4 == 3:
            add(loop, start + beat * 3.5, .48, crash, .22)
    return loop


def render(name, samples):
    encoded = array("h", (round(31000 * tanh(value)) for value in samples))
    with wave.open(str(HERE / (name + ".wav")), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(encoded.tobytes())


if __name__ == "__main__":
    render("glitch_ambient", ambient())
    render("glitch_interference", interference())
    render("glitch_battle", battle())
