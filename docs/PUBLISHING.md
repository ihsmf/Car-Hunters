# CAR HUNTERS — публикация в Roblox

Что уже сделано в проекте (v9) и что нужно сделать вам. Шаги идут по порядку; всё, что помечено **(вы)**, делается
руками в Roblox Studio или в Creator Dashboard (create.roblox.com) — у меня туда доступа нет.

## Уже готово в плейсе

- Весь текст в игре на английском, названия машин — пародии (без настоящих брендов).
- Сохранения через DataStore (`CarHunters_Profiles_v1`), сессионная блокировка, сохранение при выходе и при выключении сервера.
- Все покупки проверяются на сервере (`ProcessReceipt`, `UserOwnsGamePassAsync`).
- Донат-товары, которых ещё нет на Roblox (id = 0), **скрыты** в опубликованной игре; в Studio покупка симулируется.
- Платные «случайные» товары (Sure Shot, Lucky Hour) скрываются и не продаются там, где Roblox их запрещает
  (`PolicyService.ArePaidRandomItemsRestricted`). Шансы ловушки показаны в меню THROW.
- HTTP-запросы не нужны (Allow HTTP Requests можно оставить выключенным).
- Иконка и обложки страницы игры: `docs/store/icon.png` (1024×1024), `docs/store/thumb_1.png`, `docs/store/thumb_2.png`
  (1920×1080) — рендер в Blender из моделей игры (`blender/make_store_art.py`, текст — `tools/store_art_text.py`).

## 1. Проверить аккаунт (вы)

Модели Blender, звуки и иконки загружены от аккаунта Roblox **userId 1221663569**. Опубликованная игра может загружать
такие ассеты (`InsertService:LoadAsset`, звуки) только если она принадлежит **тому же аккаунту**.

- Публикуете от этого аккаунта — ничего делать не нужно.
- Хотите публиковать от группы — скажите мне id группы: я перезалью ассеты командой
  `python3 tools/roblox_open_cloud.py models|sounds|icons --creator-group <id>`.
  Без этого игра будет работать на процедурных моделях и стандартных звуках.

## 2. Подготовить плейс в Studio (вы)

1. Открыть `CarHunters.rbxlx` в свежем Roblox Studio.
2. View → Command Bar, выполнить (ставит модели машин из Creator Store, ~2–5 мин):
   ```lua
   require(game.ServerStorage.Tools.CarStoreTool).InstallAll()
   ```
3. File → Save (чтобы установленные модели остались в файле).

## 3. Первая публикация (вы)

1. File → **Publish to Roblox** → *New experience*.
   - Name: `CAR HUNTERS`
   - Description: см. раздел «Текст для страницы» ниже.
   - Genre: *Simulator* (или *Town and City*), Devices: Computer, Phone, Tablet, Console.
2. После публикации: Home → **Game Settings**:
   - Security → **Enable Studio Access to API Services** — ВКЛ (сохранения в Studio-тестах).
   - Security → Allow HTTP Requests — можно оставить выключенным.
   - Avatar → оставить по умолчанию (R15).
   - Monetization → Private Servers — по желанию (например 100 Robux).
   - Нажать Save.

## 4. Создать донат-товары и геймпассы (вы + я)

В игре 14 товаров (Developer Products) и 7 геймпассов. Их можно создать двумя способами:

**A. Автоматически (рекомендую).**
1. Creator Dashboard → ваша игра → в адресной строке или на странице Overview скопировать **Universe ID**
   (не Place ID).
2. Creator Dashboard → Open Cloud → API Keys → открыть ключ, которым пользуется эта сессия, и добавить права:
   **Developer Products: write**, **Game Passes: write**, в Access — эту игру.
3. Прислать мне Universe ID — я выполню `python3 tools/roblox_open_cloud.py products --universe <ID>`,
   id запишутся в `ProductIds.lua`, плейс пересоберётся. Повторный запуск не создаёт дубликатов.

**B. Вручную.** Creator Dashboard → игра → Monetization → Developer Products / Passes → создать по списку из
`src/ReplicatedStorage/Shared/DonateConfig.lua` (имя, описание, цена) и вписать id в
`src/ReplicatedStorage/Shared/ProductIds.lua`.

После этого: открыть свежий `CarHunters.rbxlx` → снова `InstallAll()` → **File → Publish to Roblox As → выбрать эту игру**.

## 5. Страница игры (вы)

Creator Dashboard → игра → Configure → Places/Experience:
- **Icon**: `docs/store/icon.png`.
- **Thumbnails**: `docs/store/thumb_1.png`, `docs/store/thumb_2.png` (можно добавить скриншоты из игры).
- Иконки геймпассов (по желанию): любые 512×512 PNG, например рендеры из `assets/icons/`.

### Текст для страницы (EN)

> **CAR HUNTERS** — run into busy city districts, grab glowing car parts and dodge the traffic! Carry your loot home,
> throw it into your garage trap and win one of **80 cars** from Common to Legendary. Park your best cars to earn cash,
> upgrade and tune them, unlock deeper districts with better parts and beat the monster-truck bosses.
>
> ⭐ 80 cars, 5 rarities · 🏁 12 districts and 3 boss arenas · 🔧 upgrades and tuning · 🔁 rebirths ·
> 🎁 daily streak and playtime gifts · 🤝 trade cars, cash and parts with friends

## 6. Анкета зрелости и комплаенс (вы, обязательно перед открытием)

Creator Dashboard → игра → **Experience Questionnaire** (Maturity & Compliance). Ответы по содержанию игры:
- Violence: машины сбивают персонажа, без крови → *Mild / unrealistic violence*.
- Blood, gore, crude humor, romance, alcohol, drugs, gambling: **нет**.
- **Paid random items: да** (Sure Shot — следующий бросок Epic или выше; Lucky Hour — повышенный шанс). Шансы видны в игре.
- Free-form user chat: стандартный чат Roblox (своего чата нет). Player-generated content: нет.

Без анкеты игра не появится в поиске и рекомендациях.

## 7. Тест перед открытием (вы)

- Studio → Test → **Clients and Servers**, 2 игрока: гаражи, бросок, ролик машины (экран полностью темнеет, HUD скрыт),
  трейд (оба READY → обмен), подарки, смерть от машины во время забега.
- Device Emulator (телефон): HUD над джойстиком, текст не вылезает за рамки.
- В опубликованной игре (Play на сайте): F9 → Developer Console → Server/Client — без красных ошибок;
  выйти и зайти снова — деньги и машины сохранились; купить дешёвый товар (Insurance, 19 R$) — пришёл.

## 8. Открыть игру (вы)

Creator Dashboard → игра → Overview/Settings → **Privacy: Public**. Если Roblox попросит подтвердить аккаунт
(телефон или документ) — следуйте подсказке на странице.

## Обновления после выхода

1. Я меняю код → `python3 tools/build_place.py` → новый `CarHunters.rbxlx` в ветке.
2. Вы: открыть его → `InstallAll()` → **File → Publish to Roblox As → эта игра** (перезаписывает плейс).
3. Если менялась карта, поднимается `MapConfig.Version` — сервер перестроит карту сам.
4. Сохранения игроков не теряются: ключ DataStore не меняется, старые профили мигрируют при входе.
