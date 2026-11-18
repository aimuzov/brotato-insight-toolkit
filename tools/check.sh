#!/usr/bin/env bash
# Грузит скрипты мода в Godot 3.5 на восстановленном проекте игры.
# Ловит то, что пропускает проверка синтаксиса: типы, необъявленные имена, preload.
# GODOT — бинарник Godot 3.5, GAME_PROJECT — проект, восстановленный GDRE и импортированный.
# В project.godot копии задай свой config/custom_user_dir_name, иначе автозагрузки игры
# будут писать в профиль настоящей Brotato.
set -euo pipefail

cd "$(dirname "$0")/.."

: "${GODOT:?set GODOT to a Godot 3.5 binary}"
: "${GAME_PROJECT:?set GAME_PROJECT to the recovered Brotato project}"

MOD_ID="aimuzov-DpsCheck"
BASE_ONLY="Script isn't fully loaded (cyclic preload?): res://"

if ! grep -q '^config/custom_user_dir_name=' "$GAME_PROJECT/project.godot"; then
	echo "Set config/custom_user_dir_name in $GAME_PROJECT/project.godot first" >&2
	exit 2
fi

mkdir -p "$GAME_PROJECT/mods-unpacked" "$GAME_PROJECT/zz_tools"
rm -rf "${GAME_PROJECT:?}/mods-unpacked/$MOD_ID"
cp -R "mods-unpacked/$MOD_ID" "$GAME_PROJECT/mods-unpacked/"
cp tools/load_check.gd "$GAME_PROJECT/zz_tools/"
rm -rf "$GAME_PROJECT/zz_tools/stubs" "$GAME_PROJECT/zz_tools/ext"
cp -R tools/stubs "$GAME_PROJECT/zz_tools/stubs"

scripts=()
while IFS= read -r script; do
	scripts+=("res://$script")
done < <(cd "$GAME_PROJECT" && find "mods-unpacked/$MOD_ID" -name "*.gd" | sort)

# Копии расширений поверх заглушек базовых скриптов: так парсер проверит их тела
while IFS= read -r ext; do
	case "$ext" in
		*/extensions/main.gd) stub="main_stub.gd" ;;
		*/extensions/ui/menus/shop/*) stub="shop_stub.gd" ;;
		*/extensions/global/my_camera.gd) stub="camera_stub.gd" ;;
		*) continue ;;
	esac
	target="$GAME_PROJECT/zz_tools/ext/${ext#mods-unpacked/$MOD_ID/extensions/}"
	mkdir -p "$(dirname "$target")"
	sed "1s#^extends .*#extends \"res://zz_tools/stubs/$stub\"#" "$GAME_PROJECT/$ext" > "$target"
	scripts+=("res://zz_tools/ext/${ext#mods-unpacked/$MOD_ID/extensions/}")
done < <(cd "$GAME_PROJECT" && find "mods-unpacked/$MOD_ID/extensions" -name "*.gd" | sort)

out=$("$GODOT" --no-window --path "$GAME_PROJECT" -s res://zz_tools/load_check.gd "${scripts[@]}" 2>&1 \
	| sed $'s/\x1b\\[[0-9;]*m//g' || true)

errors=$(printf '%s\n' "$out" | grep -A1 "SCRIPT ERROR" | grep -v '^--$' | paste - - \
	| grep -E "res://(mods-unpacked/$MOD_ID|zz_tools/ext)" || true)
real_errors=$(printf '%s\n' "$errors" | grep -vF "$BASE_ONLY" || true)
[ -n "$real_errors" ] && printf '%s\n' "$real_errors"

# Расширения наследуют main.gd/shop.gd игры, а те вне игры не грузятся из-за
# циклических ссылок в декомпиляте. Такие файлы помечаем skip, а не fail
failed=0
while IFS= read -r line; do
	path=${line#DCCHECK }
	status=${path:0:4}
	path=${path:5}
	if [ "$status" != "FAIL" ]; then
		echo "ok   $path"
	elif printf '%s\n' "$errors" | grep -F "$BASE_ONLY" | grep -qF "$path" \
		&& ! printf '%s\n' "$real_errors" | grep -qF "$path"; then
		echo "skip $path (base game script doesn't load outside the game)"
	else
		echo "FAIL $path"
		failed=1
	fi
done < <(printf '%s\n' "$out" | grep "^DCCHECK")

exit $failed
