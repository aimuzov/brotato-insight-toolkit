#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


root = Path(__file__).resolve().parents[1]
engine = os.environ.get("GODOT", "/tmp/dps-localization-test/engine/Godot")
with tempfile.TemporaryDirectory(prefix="dps-game-contract-") as directory:
    project = Path(directory)
    shutil.copytree(root / "tools/tests/game", project, dirs_exist_ok=True)
    shutil.copytree(
        root / "mods-unpacked/aimuzov-DpsCheck",
        project / "mods-unpacked/aimuzov-DpsCheck",
    )
    shutil.copyfile(project / "forecast.gd", project / "mods-unpacked/aimuzov-DpsCheck/core/wave_forecast.gd")
    target = project / "ui/menus/shop"
    target.mkdir(parents=True)
    shutil.copyfile(project / "popup.gd", target / "item_popup.gd")
    shutil.copyfile(project / "icon_panel.gd", target / "icon_panel.gd")
    (target / "icon_panel.tscn").write_text(
        '[gd_scene load_steps=2 format=2]\n'
        '[ext_resource path="res://ui/menus/shop/icon_panel.gd" type="Script" id=1]\n'
        '[node name="IconPanel" type="Panel"]\nscript=ExtResource( 1 )\n'
    )
    fonts = project / "resources/fonts/actual/base"
    fonts.mkdir(parents=True)
    shutil.copyfile("/System/Library/Fonts/Supplemental/Arial.ttf", project / "test-font.ttf")
    (fonts / "font_26_outline.tres").write_text(
        '[gd_resource type="DynamicFont" load_steps=2 format=2]\n'
        '[ext_resource path="res://test-font.ttf" type="DynamicFontData" id=1]\n'
        '[resource]\nsize=26\nfont_data=ExtResource( 1 )\n'
    )
    shutil.copyfile(root / "tools/tests/choice_game_test.gd", project / "test.gd")
    classes = [("Effect", "effect.gd", "Resource"), ("ItemParentData", "item.gd", "Resource"),
               ("WeaponData", "weapon.gd", "Resource"), ("EffectLine", "line.gd", "Control")]
    configuration = 'config_version=4\n_global_script_classes = ' + json.dumps([
        {"base": base, "class": name, "language": "GDScript", "path": "res://" + filename}
        for name, filename, base in classes
    ])
    configuration += '\n_global_script_class_icons={}\n[application]\nconfig/name="DpsGameContract"\n'
    configuration += 'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="DpsCheck-game-contract"\n'
    configuration += 'run/main_scene="res://test.tscn"\n[autoload]\n'
    for name, filename in [("Keys", "keys"), ("RunData", "run"), ("Utils", "utils"),
                           ("ItemService", "item_service"), ("ProgressData", "progress"), ("TempStats", "temp"), ("Text", "text")]:
        configuration += name + '="*res://' + filename + '.gd"\n'
    configuration += '[rendering]\nquality/driver/driver_name="GLES2"\n'
    (project / "project.godot").write_text(configuration)
    (project / "test.tscn").write_text(
        '[gd_scene load_steps=2 format=2]\n[ext_resource path="res://test.gd" type="Script" id=1]\n'
        '[node name="Test" type="Node"]\nscript = ExtResource( 1 )\n'
    )
    result = subprocess.run([engine, "--no-window", "--path", directory, "--quit"],
                            capture_output=True, text=True, timeout=45)
    output = result.stdout + result.stderr
    print(output, end="")
    failed = "SCRIPT ERROR" in output or "ERROR:" in output or "Game contract:" not in output
    raise SystemExit(result.returncode or (1 if failed else 0))
