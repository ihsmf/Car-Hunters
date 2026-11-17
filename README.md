# 🎱 Billiard Hunters (Roblox)

Механика как в «Throw Food to Animals», только с бильярдом. Зажимаешь **SHOOT**, кий бьёт биток, тот разбивает пирамиду и катится по длинному столу. В какой зоне биток упадёт в лузу, такой редкости персонаж-профи и выпадет. Профи встаёт у бильярдного стола на твоей базе и приносит доход. На этот доход прокачиваешь кий и силу удара: сила растёт от гантели у базы, а гантелю тоже можно прокачать.

Весь текст в игре на английском.

## Что где
| Путь | Что внутри |
|---|---|
| **`BilliardHunters.rbxlx`** | готовый плейс: открыть в Studio и нажать Play |
| Figma: [Billiard Hunters — UI](https://www.figma.com/design/mE9bTdXWf52Fk2fC8KF6dn) | дизайн интерфейса: HUD, компоненты MenuButton/Card, 5 окон (скриншоты в `docs/`) |
| `blender/build_models.py` | модели PoolTable, Cue, Ball, Dumbbell, Fence → `src/shared/Meshes.luau` + FBX + рендер `docs/blender-models.png` |
| `src/shared/MeshBuilder.luau` | собирает MeshPart из геометрии Blender через EditableMesh, без загрузки ассетов |
| `src/shared/Config.luau` | 25 редкостей, 100 персонажей, кии, гейм-пассы, бонусы, UI-токены из Figma |
| `src/server/Main.server.luau` | данные, базы, бросок, доход, прокачка, ежедневный бонус и бонус за время в игре, покупки |
| `src/server/Map.luau` | объекты карты и их анимации |
| `src/client/UI.client.luau` | HUD и окна по макету Figma: Settings, Inventory, Bonus, Shop, Cues |
| `src/client/Throw.client.luau` | бросок: физика разлёта шаров по лузам, кинокамера, окно с выпавшим персонажем |
| `src/client/Visuals.client.luau` | заменяет модели из деталей на меши Blender |
| `tools/place.py` | генерирует `.rbxlx`: карта (~4800 деталей) прямо в Workspace + все скрипты |
| `tools/lint_luau.py` | проверка Luau: баланс блоков и скобок, необъявленные имена, несуществующие ключи Config |
| `tools/preview.py` | рендер карты через Blender (`tools/preview.png`) |

## Запуск
1. Открыть `BilliardHunters.rbxlx` в Roblox Studio. Карта видна сразу.
2. Нажать **Play (F5)**. Вас перенесёт на свою базу. Слева 4 кнопки, внизу кнопка SHOOT.
3. Сохранения: опубликовать плейс и включить Game Settings → Security → **API Services**. Без этого игра работает, но прогресс не сохраняется.
4. Вписать ID гейм-пассов и продуктов в `C.GamePasses` / `C.Products` (`src/shared/Config.luau`), затем пересобрать.

Меши из Blender создаются через **EditableMesh**. Если в вашем Studio или опыте эта функция недоступна, в Output будет предупреждение `[MeshBuilder]`, и останутся модели из деталей той же формы.

## Пересборка
```
pip install bpy                    # Blender как Python-модуль, один раз
python3 blender/build_models.py    # модели → Meshes.luau
python3 tools/lint_luau.py         # проверка кода
python3 tools/place.py             # → BilliardHunters.rbxlx
```
