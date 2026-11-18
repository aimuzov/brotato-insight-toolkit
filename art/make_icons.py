#!/usr/bin/env python3
"""Рисует иконки статов в стиле интерфейса Brotato: один набор и для панели
«Параметры», и для карточек улучшений.

Стиль: плоская заливка цветом стата, контур и внутренние линии — тёмный оттенок
того же цвета (не чёрный), блики — светлый оттенок. Фигуры сначала обводятся,
потом заливаются без обводки, поэтому пересечения сливаются в один силуэт.

Выход: art/icons/<стат>.svg, 96x96, рендерятся в 4x.
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "icons")
INK = "#141414"
WHITE = "#ffffff"
GREEN = "#3dff3d"
SHADE = "#cfe0dc"
OUTLINE = 8


def star(cx, cy, outer, inner, spikes, rotation=0.0):
    points = []
    for i in range(spikes * 2):
        r = outer if i % 2 == 0 else inner
        a = rotation + math.pi * i / spikes
        points.append("%.1f %.1f" % (cx + r * math.sin(a), cy - r * math.cos(a)))
    return "M" + " L".join(points) + " Z"


HEART = "M48 84 C20 64 9 49 9 33 C9 19 18 11 30 11 C38 11 44 16 48 23 C52 16 58 11 66 11 C78 11 87 19 87 33 C87 49 76 64 48 84 Z"

# Каждая иконка: shapes — [(тег, атрибуты, заливка)], details — сырой SVG поверх
ICONS = {
    "max_hp": {
        "shapes": [("path", 'd="%s"' % HEART, GREEN)],
        "details": '<ellipse cx="29" cy="30" rx="8" ry="5" transform="rotate(-35 29 30)" fill="%s"/>' % WHITE,
    },
    "hp_regeneration": {
        "shapes": [
            ("path", 'd="%s" transform="translate(2 18) scale(0.74)"' % HEART, WHITE),
            ("path", 'd="M64 6 h14 v14 h14 v14 h-14 v14 h-14 v-14 h-14 v-14 h14 z"', GREEN),
        ],
        "details": "",
    },
    "lifesteal": {
        "shapes": [
            ("path", 'd="M12 16 Q48 34 84 16 L84 30 Q48 48 12 30 Z"', WHITE),
            ("path", 'd="M27 34 L34 54 L41 38 Z"', WHITE),
            ("path", 'd="M55 38 L62 54 L69 34 Z"', WHITE),
            ("path", 'd="M48 50 C48 50 32 67 32 75 C32 84 39 90 48 90 C57 90 64 84 64 75 C64 67 48 50 48 50 Z"', GREEN),
        ],
        "details": '<ellipse cx="42" cy="76" rx="3" ry="5" fill="%s"/>' % WHITE,
    },
    "percent_damage": {
        "shapes": [
            ("rect", 'x="14" y="30" width="56" height="44" rx="14"', WHITE),
            ("rect", 'x="16" y="16" width="15" height="26" rx="7"', WHITE),
            ("rect", 'x="30" y="14" width="15" height="28" rx="7"', WHITE),
            ("rect", 'x="44" y="14" width="15" height="28" rx="7"', WHITE),
            ("rect", 'x="58" y="18" width="14" height="26" rx="7"', WHITE),
            ("rect", 'x="68" y="34" width="20" height="34" rx="5"', GREEN),
        ],
        "details": '<path d="M30 42 V30 M44 42 V28 M58 42 V30" fill="none" stroke="%s" stroke-width="4" stroke-linecap="round"/>' % INK,
    },
    "melee_damage": {
        "shapes": [
            ("path", 'd="M66 12 L86 10 L84 30 L38 76 L20 58 Z"', WHITE),
            ("path", 'd="M10 50 L46 86 L54 78 L18 42 Z"', GREEN),
            ("path", 'd="M30 70 L16 84 L12 80 L26 66 Z"', GREEN),
            ("circle", 'cx="11" cy="85" r="7"', WHITE),
        ],
        "details": '<path d="M78 18 L34 62" stroke="%s" stroke-width="4" stroke-linecap="round"/>' % SHADE,
    },
    "ranged_damage": {
        "shapes": [
            ("path", 'd="M26 8 Q92 48 26 88 L34 82 Q76 48 34 14 Z"', WHITE),
            ("path", 'd="M74 38 L92 48 L74 58 Z"', GREEN),
            ("rect", 'x="10" y="44" width="68" height="8" rx="3"', GREEN),
            ("path", 'd="M6 36 L20 48 L6 60 L14 48 Z"', GREEN),
        ],
        "details": '<path d="M30 12 L30 84" stroke="%s" stroke-width="3"/>' % INK,
    },
    "elemental_damage": {
        "shapes": [
            ("path", 'd="M48 90 C25 90 13 75 13 58 C13 40 29 31 31 12 C42 21 46 30 46 41 C52 34 54 26 54 16 C71 29 83 44 83 61 C83 77 70 90 48 90 Z"', GREEN),
        ],
        "details": '<path d="M48 83 C38 83 31 75 31 66 C31 56 40 52 42 42 C48 50 50 56 50 62 C54 58 56 54 56 49 C62 55 66 62 66 69 C66 77 58 83 48 83 Z" fill="%s"/>' % WHITE,
    },
    "attack_speed": {
        "shapes": [
            ("rect", 'x="24" y="8" width="60" height="11" rx="4"', WHITE),
            ("rect", 'x="24" y="77" width="60" height="11" rx="4"', WHITE),
            ("path", 'd="M31 18 L77 18 C77 37 60 42 60 48 C60 54 77 59 77 78 L31 78 C31 59 48 54 48 48 C48 42 31 37 31 18 Z"', WHITE),
        ],
        "details": (
            '<path d="M36 76 L72 76 C70 66 60 60 54 58 C48 60 38 66 36 76 Z" fill="%s"/>'
            '<path d="M40 26 L68 26 C64 34 56 38 54 41 C52 38 44 34 40 26 Z" fill="%s"/>'
            '<path d="M5 34 L17 34 M3 48 L19 48 M5 62 L17 62" stroke="%s" stroke-width="5" stroke-linecap="round"/>'
        ) % (GREEN, GREEN, INK),
    },
    "crit_chance": {
        "shapes": [("path", 'd="%s"' % star(48, 48, 44, 19, 8, 0.2), GREEN)],
        "details": '<path d="%s" fill="%s"/>' % (star(48, 48, 20, 9, 8, 0.2), WHITE),
    },
    "engineering": {
        "shapes": [
            ("path", 'd="M42 30 L54 30 L54 80 C54 86 42 86 42 80 Z" transform="rotate(45 48 48)"', WHITE),
            ("path", 'd="M33 10 L33 24 C33 33 40 38 48 38 C56 38 63 33 63 24 L63 10 L55 10 L55 22 L41 22 L41 10 Z" transform="rotate(45 48 48)"', WHITE),
            ("path", 'd="M42 30 L54 30 L54 80 C54 86 42 86 42 80 Z" transform="rotate(-45 48 48)"', GREEN),
            ("path", 'd="M33 10 L33 24 C33 33 40 38 48 38 C56 38 63 33 63 24 L63 10 L55 10 L55 22 L41 22 L41 10 Z" transform="rotate(-45 48 48)"', GREEN),
        ],
        "details": "",
    },
    "range": {
        "shapes": [("circle", 'cx="48" cy="48" r="36"', WHITE)],
        "details": (
            '<circle cx="48" cy="48" r="23" fill="%s" stroke="%s" stroke-width="5"/>'
            '<circle cx="48" cy="48" r="10" fill="%s" stroke="%s" stroke-width="5"/>'
            '<path d="M48 4 V24 M48 72 V92 M4 48 H24 M72 48 H92" stroke="%s" stroke-width="6" stroke-linecap="round"/>'
        ) % (WHITE, INK, GREEN, INK, INK),
    },
    "armor": {
        "shapes": [("path", 'd="M48 8 L84 19 C84 52 71 75 48 89 C25 75 12 52 12 19 Z"', WHITE)],
        "details": '<path d="M48 8 L84 19 C84 52 71 75 48 89 Z" fill="%s"/><path d="M48 10 V86" stroke="%s" stroke-width="4"/>' % (GREEN, INK),
    },
    "dodge": {
        "shapes": [
            ("rect", 'x="6" y="29" width="40" height="10" rx="5"', GREEN),
            ("rect", 'x="2" y="43" width="44" height="10" rx="5"', GREEN),
            ("rect", 'x="6" y="57" width="40" height="10" rx="5"', GREEN),
            ("circle", 'cx="62" cy="48" r="24"', WHITE),
        ],
        "details": '<path d="M52 36 Q62 28 72 36" fill="none" stroke="%s" stroke-width="4" stroke-linecap="round"/><circle cx="70" cy="46" r="4" fill="%s"/>' % (SHADE, INK),
    },
    "speed": {
        "shapes": [
            ("path", 'd="M34 12 L56 12 L56 54 L80 62 C87 64 90 70 90 77 L90 84 L26 84 L26 70 L34 60 Z"', WHITE),
            ("rect", 'x="24" y="78" width="68" height="10" rx="4"', GREEN),
            ("path", 'd="M34 28 C18 22 8 28 5 37 C13 35 19 37 23 41 C13 42 8 48 8 55 C17 51 25 51 34 54 Z"', GREEN),
        ],
        "details": '<path d="M56 54 L44 54 M40 26 H52" stroke="%s" stroke-width="4" stroke-linecap="round"/>' % INK,
    },
    "luck": {
        "shapes": [
            ("circle", 'cx="35" cy="35" r="17"', GREEN),
            ("circle", 'cx="61" cy="35" r="17"', GREEN),
            ("circle", 'cx="35" cy="61" r="17"', GREEN),
            ("circle", 'cx="61" cy="61" r="17"', GREEN),
        ],
        "details": (
            '<path d="M60 70 Q66 84 80 92" fill="none" stroke="%s" stroke-width="10" stroke-linecap="round"/>'
            '<path d="M60 70 Q66 84 80 92" fill="none" stroke="%s" stroke-width="4" stroke-linecap="round"/>'
            '<circle cx="48" cy="48" r="7" fill="%s" stroke="%s" stroke-width="4"/>'
            '<path d="M48 41 V28 M48 55 V68 M41 48 H28 M55 48 H68" stroke="%s" stroke-width="3" stroke-linecap="round"/>'
        ) % (INK, GREEN, WHITE, INK, INK),
    },
    "harvesting": {
        "shapes": [
            ("rect", 'x="44" y="30" width="8" height="62" rx="4"', WHITE),
            ("ellipse", 'cx="48" cy="17" rx="8" ry="13"', GREEN),
            ("ellipse", 'cx="35" cy="34" rx="8" ry="13" transform="rotate(-35 35 34)"', GREEN),
            ("ellipse", 'cx="61" cy="34" rx="8" ry="13" transform="rotate(35 61 34)"', GREEN),
            ("ellipse", 'cx="35" cy="52" rx="8" ry="13" transform="rotate(-35 35 52)"', GREEN),
            ("ellipse", 'cx="61" cy="52" rx="8" ry="13" transform="rotate(35 61 52)"', GREEN),
        ],
        "details": "",
    },
}


# Цвет каждого стата, близкий к его цвету в игре
STAT_COLORS = {
    "max_hp": "#6ad06a",
    "hp_regeneration": "#6ad06a",
    "lifesteal": "#e0505a",
    "percent_damage": "#ef6a50",
    "melee_damage": "#f2dc8c",
    "ranged_damage": "#ee82d8",
    "elemental_damage": "#f08a5a",
    "attack_speed": "#f2df4a",
    "crit_chance": "#ea4646",
    "engineering": "#6ec8f0",
    "range": "#b98be6",
    "armor": "#f2cc3a",
    "dodge": "#8ecff0",
    "speed": "#c88a5c",
    "luck": "#9edc6a",
    "harvesting": "#f0dc96",
}


def mix(color, target, amount):
    c = [int(color[i:i + 2], 16) for i in (1, 3, 5)]
    t = [int(target[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join("%02x" % round(c[i] + (t[i] - c[i]) * amount) for i in range(3))


# Палитра одной иконки из цвета стата: заливка, светлая часть, контур, блик
def palette(main):
    return {
        "main": main,
        "mid": mix(main, "#ffffff", 0.22),
        "dark": mix(main, "#000000", 0.55),
        "light": mix(main, "#ffffff", 0.65),
    }


def render(spec, main):
    pal = palette(main)
    # В описаниях фигур зелёный — основная часть, белый — вторая, светлее
    fill_of = {GREEN: pal["main"], WHITE: pal["mid"]}
    outline = "".join(
        '<%s %s fill="%s" stroke="%s" stroke-width="%d" stroke-linejoin="round"/>' % (tag, attrs, pal["dark"], pal["dark"], OUTLINE)
        for tag, attrs, _ in spec["shapes"]
    )
    fill = "".join('<%s %s fill="%s"/>' % (tag, attrs, fill_of.get(color, color)) for tag, attrs, color in spec["shapes"])
    details = (
        spec["details"]
        .replace(GREEN, "@MAIN@")
        .replace(WHITE, pal["light"])
        .replace(SHADE, pal["light"])
        .replace(INK, pal["dark"])
        .replace("@MAIN@", pal["main"])
    )
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="384" height="384" viewBox="-2 -2 100 100">'
        + outline + fill + details + "</svg>"
    )


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, spec in ICONS.items():
        with open(os.path.join(OUT, name + ".svg"), "w") as f:
            f.write(render(spec, STAT_COLORS[name]))
    print("wrote %d icons to %s" % (len(ICONS), OUT))


if __name__ == "__main__":
    main()
