# CAR HUNTERS — публикация в Roblox (v15)

Цель: с вашей стороны — несколько разовых действий, дальше обновления выкладываю я сам.

## Что уже готово в плейсе

- `CarHunters.rbxl` — готовый плейс: весь код и **120 встроенных моделей** (44 модели из Blender + 76 машин из
  Creator Store, без их скриптов). Ничего запускать в Studio не нужно.
- Сохранения (DataStore `CarHunters_Profiles_v1`): блокировка сессии, автосейв, сохранение при выходе и выключении
  сервера, миграции старых сейвов. Глобальный лидерборд.
- Покупки проверяются на сервере (`ProcessReceipt` не выдаёт товар дважды, геймпассы через `UserOwnsGamePassAsync`).
  Товары, которых ещё нет на Roblox (id = 0), в игре скрыты. Платные «случайные» товары скрываются там, где их
  запрещает Roblox (`PolicyService`).
- Весь текст на английском, все 80 машин с **вымышленными названиями**, без логотипов. Своего чата нет.
- Новый игрок видит превью карты и вопрос «NEED A TUTORIAL?» (YES — ролик + пошаговое обучение, SKIP — сразу играть).

## Разовые шаги (вы), ~10 минут

1. **Создать игру.** Войти в Roblox Studio аккаунтом **userId 1221663569** (ему принадлежат модели, звуки и иконки),
   открыть `CarHunters.rbxl` → File → **Publish to Roblox** → *New experience*, имя `CAR HUNTERS`,
   жанр Simulator, устройства: Computer, Phone, Tablet, Console.
2. **Game Settings → Security → Enable Studio Access to API Services** — включить (нужно только для тестов в Studio).
3. **API-ключ.** Creator Dashboard → Open Cloud → API Keys → ключ этой сессии → добавить права
   **Developer Products: write**, **Game Passes: write**, **universe-places: write**, в Access — эту игру.
4. **Прислать мне Universe ID и Place ID** (Creator Dashboard → игра → Overview / адресная строка).

После этого я сам: создаю 14 товаров и 7 геймпассов, вписываю их id, пересобираю плейс и публикую его
(`python3 tools/roblox_open_cloud.py products --universe U`, затем `publish --universe U --place P`).

## Страница игры и открытие (вы)

5. **Страница:** иконка (ваша, 512×512), обложки `docs/store/thumb_1.png`, `docs/store/thumb_2.png`, описание ниже.
6. **Experience Questionnaire** (Maturity & Compliance): насилие — *Mild/unrealistic* (персонажа сбивает машина, без
   крови); кровь, алкоголь, наркотики, романтика, азарт — нет; **Paid random items — да** (Sure Shot, Lucky Hour,
   шансы видны в игре); свой чат и пользовательский контент — нет.
7. **Проверка:** зайти в опубликованную игру, F9 → без красных ошибок; выйти/зайти — прогресс сохранился.
8. **Privacy: Public.**

### Описание (EN)

> **CAR HUNTERS** — run into busy city districts, grab glowing car parts and dodge the traffic! Carry your loot home,
> throw it into your garage trap and catch one of **80 cars** from Common to Legendary. Park your best cars to earn
> cash, upgrade and tune them, unlock deeper districts with better parts and beat the monster-truck bosses.
>
> ⭐ 80 cars, 5 rarities · 🏁 12 districts and 3 boss arenas · 🔧 upgrades and tuning · 🔁 rebirths ·
> 🎁 daily streak and playtime gifts · 🤝 trade cars, cash and parts with friends

## Обновления

Я меняю код → `tools/build_place.py` → `roblox_open_cloud.py publish --universe U --place P` — игра обновляется
без вас. Запасной путь: открыть свежий `CarHunters.rbxl` → File → **Publish to Roblox As** → эта игра.
Сейвы игроков сохраняются (ключ DataStore не меняется, старые профили мигрируют при входе).
