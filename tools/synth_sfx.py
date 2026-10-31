"""Sonidos sintetizados para Mister (los que no hay en los packs de Kenney): ambiente en bucle
(viento, lluvia, río, fuego), chapoteos, latigazos de aire y los de la alomancia.
Los bucles salen de ruido con forma en frecuencia hecho por FFT: son periódicos, empalman sin corte.
Uso: python synth.py <carpeta de salida>"""
import sys
import wave
import numpy as np

SR = 44100
OUT = sys.argv[1]
rng = np.random.default_rng(7)


def save(name, x, peak=0.8):
	x = np.asarray(x, dtype=np.float64)
	m = np.max(np.abs(x)) or 1.0
	x = x / m * peak
	data = (np.clip(x, -1, 1) * 32767).astype('<i2')
	with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(data.tobytes())


def t_of(sec):
	return np.arange(int(sec * SR)) / SR


def shaped(sec, gain):
	"""Ruido periódico (empalma consigo mismo) con el espectro gain(f)."""
	n = int(sec * SR)
	f = np.fft.rfftfreq(n, 1 / SR)
	spec = gain(np.maximum(f, 1.0)) * np.exp(2j * np.pi * rng.random(f.size))
	spec[0] = 0
	x = np.fft.irfft(spec, n)
	return x / (np.max(np.abs(x)) or 1)


def band(lo, hi, slope=2.0):
	return lambda f: 1 / (1 + (lo / f) ** slope) / (1 + (f / hi) ** slope)


def burst(sec, gain):
	"""Ruido no periódico con espectro gain (para golpes cortos)."""
	return shaped(sec, gain)


def env(sec, attack, decay_tau):
	t = t_of(sec)
	a = np.clip(t / max(attack, 1e-4), 0, 1)
	return a * np.exp(-np.maximum(t - attack, 0) / decay_tau)


def periodic_am(t, sec, parts):
	return sum(a * np.sin(2 * np.pi * k * t / sec + p) for k, a, p in parts)


# --- Ambiente en bucle
sec = 8.0
t = t_of(sec)
wind = shaped(sec, lambda f: (1 / (1 + (f / 350) ** 2)) ** 0.75 * (1 / (1 + (60 / f) ** 2)))
wind *= 0.65 + periodic_am(t, sec, [(1, 0.25, 0.0), (3, 0.12, 1.3), (5, 0.06, 2.1)])
save('wind_loop', wind, 0.6)

sec = 4.0
t = t_of(sec)
fly = shaped(sec, lambda f: np.exp(-((np.log(f) - np.log(900)) ** 2) / 1.3))
fly *= 0.8 + periodic_am(t, sec, [(2, 0.12, 0.0), (7, 0.08, 1.0)])
save('fly_wind_loop', fly, 0.7)

sec = 8.0
t = t_of(sec)
rain = shaped(sec, lambda f: band(900, 9000)(f) * (f / 2000) ** 0.2) * 0.5
drops = np.zeros(t.size)
for _ in range(int(70 * sec)):
	i = rng.integers(0, t.size)
	freq = rng.uniform(2500, 6000)
	n = int(0.012 * SR)
	tt = np.arange(n) / SR
	d = np.sin(2 * np.pi * freq * tt) * np.exp(-tt / 0.003) * rng.uniform(0.2, 1.0)
	idx = (i + np.arange(n)) % t.size
	drops[idx] += d
save('rain_loop', rain + drops * 0.35, 0.55)

sec = 8.0
t = t_of(sec)
river = shaped(sec, band(150, 2200)) * (0.75 + periodic_am(t, sec, [(9, 0.1, 0.0), (13, 0.08, 1.7)]))
bubbles = np.zeros(t.size)
for _ in range(int(25 * sec)):
	i = rng.integers(0, t.size)
	n = int(rng.uniform(0.02, 0.05) * SR)
	tt = np.arange(n) / SR
	f0 = rng.uniform(300, 700)
	ph = 2 * np.pi * np.cumsum(f0 * (1 + 2.5 * tt / tt[-1])) / SR
	b = np.sin(ph) * np.sin(np.pi * tt / tt[-1]) * rng.uniform(0.2, 0.7)
	idx = (i + np.arange(n)) % t.size
	bubbles[idx] += b
save('river_loop', river + bubbles * 0.25, 0.6)

sec = 6.0
t = t_of(sec)
fire = shaped(sec, lambda f: 1 / (1 + (f / 250) ** 2)) * 0.6
crack = np.zeros(t.size)
for _ in range(int(14 * sec)):
	i = rng.integers(0, t.size)
	n = int(rng.uniform(0.004, 0.02) * SR)
	c = rng.standard_normal(n) * np.exp(-np.arange(n) / (n / 4)) * rng.uniform(0.3, 1.0)
	idx = (i + np.arange(n)) % t.size
	crack[idx] += c
save('fire_loop', fire + crack * 0.5, 0.55)

# --- Chapoteos (pasos en el agua)
for k in range(4):
	sec = 0.4
	t = t_of(sec)
	s = burst(sec, band(400, 4000)) * env(sec, 0.01, 0.07)
	for _ in range(3):
		st = rng.uniform(0.03, 0.15)
		n = int(0.04 * SR)
		tt = np.arange(n) / SR
		f0 = rng.uniform(400, 800)
		b = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 1.5 * tt / tt[-1])) / SR) * np.sin(np.pi * tt / tt[-1]) * 0.4
		i = int(st * SR)
		s[i:i + n] += b[: max(0, min(n, s.size - i))]
	save(f'splash_{k}', s, 0.7)

# --- Latigazos de aire (golpes al aire, capa, voltereta)
for k in range(3):
	sec = 0.4
	t = t_of(sec)
	lo = burst(sec, band(200, 900))
	hi = burst(sec, band(900, 4500))
	mix = np.clip(t / sec, 0, 1)
	s = (lo * (1 - mix) + hi * mix) * np.sin(np.pi * np.clip(t / sec, 0, 1)) ** 1.5
	save(f'whoosh_{k}', s, 0.6)

# --- Alomancia
def metal_bar(sec, f0, decay, glide=0.0):
	t = t_of(sec)
	f = f0 * (1 + glide * t / sec)
	ph = 2 * np.pi * np.cumsum(f) / SR
	s = 0
	for ratio, amp, d in [(1, 1.0, 1.0), (2.76, 0.6, 0.6), (5.40, 0.35, 0.4), (8.93, 0.2, 0.3)]:
		s = s + amp * np.sin(ph * ratio) * np.exp(-t / (decay * d))
	return s


for k in range(3):
	sec = 0.8
	t = t_of(sec)
	f0 = 190 + 25 * k
	thrum = metal_bar(sec, f0, 0.35, glide=-0.06)
	thump = np.sin(2 * np.pi * 62 * t) * np.exp(-t / 0.12)
	air = burst(sec, band(300, 2500)) * env(sec, 0.005, 0.08)
	save(f'steel_push_{k}', thrum * 0.7 + thump * 0.8 + air * 0.5, 0.8)
	# Tirón: el mismo metal, pero crece y sube (como si viniera hacia vos).
	swell = np.clip(t / 0.45, 0, 1) ** 2 * np.exp(-np.maximum(t - 0.45, 0) / 0.06)
	f = (f0 * 0.9) * (1 + 0.12 * t / sec)
	ph = 2 * np.pi * np.cumsum(f) / SR
	pull = sum(a * np.sin(ph * r) for r, a in [(1, 1.0), (2.76, 0.5), (5.4, 0.25)]) * swell
	save(f'iron_pull_{k}', pull + air[::-1] * 0.3, 0.8)

sec = 2.0
t = t_of(sec)
hum = sum(a * np.sin(2 * np.pi * f * t) for f, a in [(90, 1.0), (91.5, 0.6), (180, 0.4), (271, 0.2)])
hum *= 0.8 + 0.2 * np.sin(2 * np.pi * 2 * t / sec)
save('steel_hum_loop', hum, 0.5)

sec = 0.6
t = t_of(sec)
f = 58 * (1 - 0.25 * t / sec)
pulse = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.13) + burst(sec, band(60, 300)) * env(sec, 0.003, 0.05) * 0.4
save('bronze_pulse', pulse, 0.8)

for name, up in [('burn_on', True), ('burn_off', False)]:
	sec = 0.45
	t = t_of(sec)
	g = t / sec if up else 1 - t / sec
	s = sum(a * np.sin(2 * np.pi * np.cumsum(f * (0.85 + 0.3 * g)) / SR) for f, a in [(900, 1.0), (1350, 0.6), (2020, 0.4)])
	s *= np.sin(np.pi * t / sec) ** 2
	save(name, s, 0.45)

sec = 0.7
t = t_of(sec)
flare = burst(sec, lambda f: 1 / (1 + (f / 400) ** 2)) * env(sec, 0.02, 0.18) + np.sin(2 * np.pi * 70 * t) * env(sec, 0.01, 0.2)
save('flare', flare, 0.8)

sec = 2.2
t = t_of(sec)
bell = sum(a * np.sin(2 * np.pi * 660 * r * t) * np.exp(-t / d) for r, a, d in [(1, 1.0, 1.2), (2.0, 0.5, 0.8), (2.76, 0.45, 0.6), (4.07, 0.3, 0.4), (5.4, 0.2, 0.3)])
save('atium', bell * np.clip(t / 0.005, 0, 1), 0.6)
print('ok')
