#!/usr/bin/env python3
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


root = Path(__file__).resolve().parents[1]
engine = os.environ.get("GODOT", "/tmp/brotato-insight-toolkit-test/engine/Godot")
if not Path(engine).is_file():
    raise SystemExit("Set GODOT to a standalone Godot 3 executable without the game PCK")

with tempfile.TemporaryDirectory(prefix="insight-toolkit-choice-tests-") as directory:
    project = Path(directory)
    core = project / "core"
    core.mkdir()
    source = root / "mods-unpacked/aimuzov-InsightToolkit/core"
    for name in ("choice_state.gd", "choice_model.gd", "choice_planner.gd", "stat_dependencies.gd"):
        if (source / name).exists():
            shutil.copyfile(source / name, core / name)
    shutil.copyfile(root / "tools/tests/choice_test.gd", project / "test.gd")
    (project / "project.godot").write_text(
        'config_version=4\n[application]\nconfig/name="InsightToolkitChoiceTests"\n'
        'config/use_custom_user_dir=true\nconfig/custom_user_dir_name="InsightToolkit-choice-tests"\n'
        'run/main_scene="res://test.tscn"\n[rendering]\nquality/driver/driver_name="GLES2"\n'
    )
    (project / "test.tscn").write_text(
        '[gd_scene load_steps=2 format=2]\n'
        '[ext_resource path="res://test.gd" type="Script" id=1]\n'
        '[node name="Test" type="Node"]\nscript = ExtResource( 1 )\n'
    )
    result = subprocess.run(
        [engine, "--no-window", "--path", directory, "--quit"],
        capture_output=True, text=True, timeout=45,
    )
    output = result.stdout + result.stderr
    print(output, end="")
    failed = "SCRIPT ERROR" in output or "ERROR:" in output or "Choice engine:" not in output
    raise SystemExit(result.returncode or (1 if failed else 0))
