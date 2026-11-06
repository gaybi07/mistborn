"""Arma docs/BIBLIOTECA_ANIMACIONES.md: todos los clips de los .glb del proyecto, de dónde salen y qué usa cada
acción de los héroes (Vin, encapuchado...) según scripts/character/hero_clips.gd.

Uso (desde la carpeta del proyecto):  python tools/anim_library.py
Volver a correrlo cada vez que se cambie un clip o se agregue un .glb.
"""
import glob
import json
import re
import struct

OUT = "docs/BIBLIOTECA_ANIMACIONES.md"

# Origen de cada archivo (lo que no está acá sale como "sin clasificar").
ORIGIN = {
    "assets/meshy/": "Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo)",
    "assets/meshy/VinCorregida.glb": "Meshy: Vin re-rigueada (VIN RERIGGED 1 y 2); Vuelo_A, Vuelo_B y Vuelo_Moneda son "
                                     "clips de Meshy que venían sin nombre, solo renombrados",
    "assets/actionforge/AFClips.glb": "ActionForge y Mixamo (ver detalle por clip)",
    "assets/mixamo/Mistborn.glb": "ActionForge (rig Quaternius) + Mixamo, del modelo viejo del Mistborn",
    "assets/mixamo/MixamoSpells.glb": "Mixamo: nativas",
    "assets/mixamo/MixamoCombat.glb": "Mixamo: nativas",
    "assets/mixamo/Ninja.glb": "Mixamo: nativas",
    "assets/koloss/KolossMoves.glb": "Mixamo: nativas (packs Great Sword y Mutant)",
    "assets/skaa/": "ActionForge + Mixamo, con el esqueleto del Mistborn viejo (rig_like_mistborn.py)",
    "assets/kaykit/": "KayKit: pack nativo (personajes chibi)",
    "assets/quaternius/": "Quaternius: pack nativo",
}
# Clips de AFClips.glb, uno por uno.
CLIP_ORIGIN = {
    "punch_cross": "ActionForge, nativa",
    "punch_jab": "ActionForge, nativa",
    "overhandthrow_adjusted": "ActionForge, retocada por Claude (Adjust: pecho -20°, cabeza +20°)",
    "idle_loop_adjusted": "ActionForge, retocada por Claude (brazos, cabeza, postura y piernas juntas: pose Ironman)",
    "crouch_idle_mx": "Mixamo, nativa (Crouch Idle)",
    "spell_simple_enter": "ActionForge, nativa (sin uso por ahora)", "spell_simple_shoot": "ActionForge, nativa (sin uso por ahora)",
    "spell_simple_exit": "ActionForge, nativa (sin uso por ahora)", "push_loop": "ActionForge, nativa (sin uso por ahora)",
    "ninjajump_start": "ActionForge, nativa: despegue de los saltos del Lord Legislador",
    "ninjajump_land": "ActionForge, nativa: caída de los saltos del Lord Legislador",
    "sword_dash": "ActionForge, nativa (sin uso: trae el avance en la cadera)",
}
# Orden en que el héroe busca cada clip (Art.hero_rig): su propio modelo, el encapuchado y los donantes.
HERO_SOURCES = ["assets/meshy/VinCorregida.glb", "assets/meshy/MistbornHood.glb", "assets/meshy/Vin.glb",
                "assets/actionforge/AFClips.glb"]


def clips_of(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    return [a.get("name", "") for a in json.loads(b[20:20 + n]).get("animations", [])]


def origin_of(path):
    path = path.replace("\\", "/")
    best = max((k for k in ORIGIN if path.startswith(k)), key=len, default=None)
    return ORIGIN[best] if best else "sin clasificar"


def dicts(src):
    """const NOMBRE := { "clave": [valores], ... } de hero_clips.gd -> {NOMBRE: {clave: [valores]}}."""
    out = {}
    for m in re.finditer(r"const (\w+) := \{(.*?)\}[ \t]*\n", src, re.S):  # la llave que cierra queda sola al final
        body = re.sub(r"#[^\n]*", "", m.group(2))
        out[m.group(1)] = {k: [v.strip().strip('"') for v in vals.split(",") if v.strip()]
                           for k, vals in re.findall(r'"(\w+)":\s*\[([^\]]*)\]', body)}
    return out


def main():
    files = {}
    for f in sorted(glob.glob("assets/**/*.glb", recursive=True)):
        try:
            names = clips_of(f)
        except (OSError, ValueError, struct.error):
            continue
        if names:
            files[f.replace("\\", "/")] = names
    d = dicts(open("scripts/character/hero_clips.gd", encoding="utf8").read())
    states = {}
    for name in ["STATES", "STANCES", "FISTS", "TOP_SPEED", "HITS"]:
        states.update(d.get(name, {}))
    cuts = {**d.get("HIT_CUTS", {}), **d.get("CUTS", {})}
    holds = re.search(r"const HOLDS := \{(.*?)\}", open("scripts/character/hero_clips.gd", encoding="utf8").read())
    holds = dict(re.findall(r'"(\w+)":\s*([\d.]+)', holds.group(1))) if holds else {}

    def where(clip):
        for f in HERO_SOURCES:
            if clip in files.get(f, []):
                return f
        return None

    def origin_clip(clip, f):
        if f and f.endswith("AFClips.glb"):
            return CLIP_ORIGIN.get(clip, "ActionForge")
        return origin_of(f).split(":")[0] + ", nativa" if f else "¿no está?"

    L = ["# Biblioteca de animaciones", "",
         "Generada con `python tools/anim_library.py` (no editar a mano: volver a correrlo).", "",
         "**Origen:** *nativa* = el clip tal cual vino (Meshy, Mixamo, ActionForge o pack). *Retocada por Claude* = editada",
         "en ActionForge (Adjust, rotaciones de huesos) o recortada en el juego (tramo, velocidad, pose fija).",
         "*Hecha por Claude* = generada por código: **ninguna** de los héroes; solo el cuerpo de reserva hecho con",
         "primitivas (`HumanoidRig`, `Art._procedural`) se anima por código, y no lo usa ningún personaje elegible.", "",
         "Encima de cualquier clip el juego suma capas en vivo: mano cerrada sin arma (`Punch_Pose`), IK de pies, y las",
         "mezclas entre clips (`ModelRig._begin_fade`). No cambian el clip.", "",
         "## Qué usa cada acción de los héroes (Vin y los demás de `Art.HEROES`)", "",
         "El clip se busca en este orden: el modelo del héroe (para Vin, `VinCorregida.glb`), el encapuchado,",
         "`Vin.glb` y `AFClips.glb`. La columna *Archivo* es donde lo encuentra Vin.", "",
         "| Acción (estado) | Clip | Archivo | Origen | Retoque en el juego |", "|---|---|---|---|---|"]
    for state, clip_list in sorted(states.items()):
        clip = clip_list[0] if clip_list else ""
        f = where(clip)
        tweak = []
        if state in cuts:
            c = cuts[state]
            tweak.append(f"tramo {float(c[0]):.0%}–{float(c[1]):.0%}" + (f", golpe {float(c[2]):.0%}" if len(c) > 2 else ""))
        if state in holds:
            tweak.append(f"pose fija en el {float(holds[state]):.0%}")
        L.append(f"| `{state}` | `{clip}` | {f.split('/')[-1] if f else '—'} | {origin_clip(clip, f)} | "
                 f"{'retocada: ' + '; '.join(tweak) if tweak else 'entera'} |")
    L += ["", "## Gestos de poderes (mitad de arriba del cuerpo)", "",
          "| Poder | Clip | Archivo | Origen | Retoque en el juego |", "|---|---|---|---|---|"]
    for skill, v in sorted(d.get("SKILLS", {}).items()):
        f = where(v[0])
        tweak = f"tramo {float(v[1]):.0%}–{float(v[2]):.0%}, suelta en {float(v[3]):.0%}"
        if len(v) > 4:
            tweak += f", velocidad {v[4]}"
        L.append(f"| `{skill}` | `{v[0]}` | {f.split('/')[-1] if f else '—'} | {origin_clip(v[0], f)} | retocada: {tweak} |")
    L += ["", "## Todos los archivos y sus clips", ""]
    for f, names in files.items():
        L += [f"### `{f}` ({len(names)})", "", f"Origen: {origin_of(f)}.", ""]
        if f.endswith("AFClips.glb"):
            L += [f"- `{n}`: {CLIP_ORIGIN.get(n, 'ActionForge')}" for n in names]
        else:
            L.append(", ".join(f"`{n}`" for n in names))
        L.append("")
    L += ["## Fuentes fuera del repo", "",
          "- `Escritorio/Mistborn/MESHY 3D/*.zip`: los FBX de Meshy de cada personaje (VIN 1 a 15 = `Vin.glb`;",
          "  VIN RERIGGED 1 y 2 = `VinCorregida.glb`). Todo lo que traen ya está en el juego.",
          "- `Escritorio/Mistborn/ActionForge/*.fbx`: lo que va en `AFClips.glb` (se arma con `tools/blender/anim_fbx_to_glb.py`).",
          "- `Descargas/*.fbx`: clips de Mixamo bajados (golpes, espada y escudo, agachado...). Solo `Crouch Idle` está en uso.", ""]
    open(OUT, "w", encoding="utf8").write("\n".join(L))
    print("escrito", OUT, sum(len(v) for v in files.values()), "clips en", len(files), "archivos")


if __name__ == "__main__":
    main()
