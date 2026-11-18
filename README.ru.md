<p align="center">
	<a href="README.md"><img src="https://img.shields.io/badge/English-555?logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA2MCAzMCI+PGNsaXBQYXRoIGlkPSJ0Ij48cGF0aCBkPSJNMzAsMTVoMzB2MTV6djE1aC0zMHpoLTMwdi0xNXp2LTE1aDMweiIvPjwvY2xpcFBhdGg+PHBhdGggZD0iTTAsMHYzMGg2MHYtMzB6IiBmaWxsPSIjMDEyMTY5Ii8+PHBhdGggZD0iTTAsMCA2MCwzME02MCwwIDAsMzAiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSI2Ii8+PHBhdGggZD0iTTAsMCA2MCwzME02MCwwIDAsMzAiIGNsaXAtcGF0aD0idXJsKCN0KSIgc3Ryb2tlPSIjQzgxMDJFIiBzdHJva2Utd2lkdGg9IjQiLz48cGF0aCBkPSJNMzAsMHYzME0wLDE1aDYwIiBzdHJva2U9IiNmZmYiIHN0cm9rZS13aWR0aD0iMTAiLz48cGF0aCBkPSJNMzAsMHYzME0wLDE1aDYwIiBzdHJva2U9IiNDODEwMkUiIHN0cm9rZS13aWR0aD0iNiIvPjwvc3ZnPg==" alt="English"></a>
	<img src="https://img.shields.io/badge/%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9-638b3c?logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA5IDYiPjxwYXRoIGZpbGw9IiNmZmYiIGQ9Ik0wIDBoOXYzSDB6Ii8+PHBhdGggZmlsbD0iIzAwMzlhNiIgZD0iTTAgMmg5djJIMHoiLz48cGF0aCBmaWxsPSIjZDUyYjFlIiBkPSJNMCA0aDl2MkgweiIvPjwvc3ZnPg==" alt="Русский">
</p>


<p align="center">
  <img src=".github/banner.png" alt="Brotato Insight Toolkit" width="100%">
</p>

<p align="center">
  <img src=".github/badges.svg" alt="Godot 3, ModLoader 6.3, локальная сборка">
</p>

<h3 align="center">Статистика боя, рекомендации по сборке и удобный интерфейс</h3>

Мод для Steam-версии **Brotato** с отдельными переключателями функций.

[Возможности](#возможности) · [Настройки](#настройки) · [Управление](#управление) · [Сборка](#сборка) · [Разработка](#разработка)

## Возможности

| Раздел | Что добавляет мод |
| --- | --- |
| **Статистика боя** | Урон по оружию, объединение одинакового оружия в одну строку и сравнение с прошлой волной. Отдельная вкладка с убийствами, нанесённым и полученным уроном по врагам. |
| **Выбор улучшений** | Анализ покупок, прокачки, реролла и продажи с учётом персонажа и текущего билда. На экране повышения уровня рекомендация появляется рядом с карточкой в фокусе. |
| **Предпросмотр характеристик** | Итоговые значения после покупки, косвенные изменения от других предметов, источники бонусов и пороги. |
| **Читаемый интерфейс** | Широкие подсказки, компактные иконки, короткие названия и сокращения больших чисел: `12.5k`, `1.2kk`, `3kkk`. |
| **Русский перевод** | Исправленные описания и короткие названия: «ХП», «Реген», «Кража», «Крит». Обычный формат можно вернуть в настройках. |
| **Удобства** | Обратный порядок улучшений «Опухоли», отметка новых улучшений, ускорение волн ×1–×4, закрепление камеры в одиночке и круги дальности оружия. |

Разница с прошлой волной показывается после превышения её урона или в последние пять игровых секунд. Рост отмечается зелёным, снижение — красным.

Анализатор оценивает бой и реролл приближённо и помечает неучтённые эффекты. История боя накапливается в текущем запуске игры. В коопе рекомендации улучшений сохраняют прежний вывод внутри карточек.

## Настройки

**Настройки игры → Геймплей → Brotato Insight Toolkit**

Функции включаются отдельно. Например:

- **Короткие числа** — переключение между `12.5k` и обычным отображением точного значения.
- **Короткие названия** и **Исправленный перевод** — независимые настройки локализации.
- **Итоговые значения статов** — предпросмотр покупки и прокачки.
- **Анализатор выбора** — рекомендации; по умолчанию выключен.
- **Широкие подсказки**, **Статистика крипов**, **Урон от оружия на экране** — настройка интерфейса под себя.

## Управление

Кнопки работают во время активной волны. При переключении на экране ненадолго появляется текущее состояние.

| Действие | Клавиатура | DualSense / DualShock 4 |
| --- | --- | --- |
| Уменьшить скорость | `-` | `□` |
| Увеличить скорость | `=` | `△` |
| Показать или скрыть цифры урона | `\` | `○` |

Скорость меняет ход игрового времени: при ×2 волна на 60 игровых секунд занимает примерно 30 реальных секунд.

## Сборка

Локальная сборка для Steam-версии Brotato. Нужны **Bash** и **ZIP**.

Закройте игру через её меню перед заменой архива мода:

```sh
./build.sh
```

Скрипт собирает ZIP и копирует его в локальную папку существующей подписки Workshop. Назначение можно изменить через `WORKSHOP_ITEM` или `OUT_DIR`.

Для сборки **без установки в игру**:

```sh
mkdir -p /tmp/brotato-insight-toolkit-build
OUT_DIR=/tmp/brotato-insight-toolkit-build ./build.sh
```

<details>
<summary>Технический ID и сохранение настроек</summary>

Технический ID `aimuzov-DpsCheck`, архив `dist/aimuzov-DpsCheck.zip` и файл настроек `user://aimuzov-dpscheck.json` сохранены для совместимости с установленным модом.

Название проекта и репозитория: `brotato-insight-toolkit`.

</details>

## Разработка

Нужны Python 3 и отдельный исполняемый файл **Godot 3.7 без игрового PCK**. Исполняемый файл Brotato запускает настоящую игру и использует её профиль, поэтому для тестов нужен отдельный движок.

```sh
GODOT=/path/to/standalone/Godot python3 tools/check_analyzer.py
GODOT=/path/to/standalone/Godot python3 tools/check_analyzer_game.py
python3 tools/check_localization.py
```

Проверки используют изолированные проекты и отдельные профили. Контракты игры проверяются на заглушках; реальное отображение проверяется отдельно в Brotato. Для интерфейсных макетов используется Arial из системных шрифтов macOS.
