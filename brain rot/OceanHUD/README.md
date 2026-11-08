# OceanHUD v3.4 — интерфейс игры

![HUD в Roblox Studio](OceanHUD-preview.png)

Слева четыре кнопки: **Перерождение**, **Подарки**, **Магазин** и **Индекс**.
Внизу слева монеты и скорость (иконка — ласты; число показывает, сколько скорости прокачано).
Внизу по центру рюкзак **[G]** — инвентарь. Внизу справа кнопки **Рыбы** и **Яйца**: они открывают инвентарь на нужной вкладке.
Все иконки — PNG-картинки с прозрачным фоном, показанные через `ImageLabel`.

![Открытый инвентарь](OceanHUD-inventory-preview.png)

![Иконки](OceanHUD-icons.png)

## Быстрый запуск в Studio

1. Один раз выполни `tools\install-studio-textures.ps1`. Скрипт копирует иконки в папку Studio,
   чтобы они показывались без загрузки на Roblox.
2. Открой **OceanMap-with-HUD.rbxl** и нажми **Play (F5)**.
   В Studio скрипт `OceanHUDTestData` сразу выставляет тестовые значения:
   монеты 125,430, скорость 18, в инвентаре 3 обычных яйца, золотое яйцо и акула; акула в слоте 1, золотое яйцо в слоте 2.

Во время игры можно выполнить в **Command Bar** (переключатель Server):

```lua
local S = require(game.ServerScriptService.OceanHUDStats)
local I = require(game.ServerScriptService.OceanInventory)
local p = game.Players:GetPlayers()[1]
S.addCoins(p, 5000)  S.addSpeed(p, 1)
I.add(p, "BasicEgg", {Name = "Обычное яйцо", Category = "Eggs", Icon = "Egg"})
```

## Инвентарь

- **Закрыт:** внизу по центру одна ячейка с рюкзаком и подписью `[G]`.
- **Открыт** (клавиша **G**, клик по рюкзаку или кнопки «Рыбы»/«Яйца»):
  - рюкзак встаёт в начало хотбара и получает белую рамку, рядом появляются ячейки **1–8**;
  - над хотбаром появляется окно: вкладки **Все / Яйца / Рыбы**, поиск и сетка предметов;
  - если ничего не найдено, показывается надпись «Здесь пока ничего нет».
- **Поиск** не учитывает регистр, в том числе для русских букв.
- **Хотбар:** клавиши **1–8** или клик выбирают ячейку, повторное нажатие снимает выбор.
  Выбор приходит событием `PlayerGui.OceanHUD.SafeArea.HotbarSelected` (номер ячейки и id предмета).
  Экипировку предметов к этому событию нужно подключить отдельно.
- Закрывается клавишами **G** или **Esc**. Инвентарь и меню слева не открываются одновременно.

**Данные инвентаря** хранит сервер (`OceanInventory`), клиент только показывает их.
Каждый предмет — это `Folder` внутри `Player.Inventory` с атрибутами
`DisplayName`, `Category` (`Eggs` / `Fish`), `Icon`, `Count`, `HotbarSlot` (1–8, необязательно).
Методы: `add`, `remove`, `count`, `setHotbar`.

## Иконки для опубликованной игры (обязательно)

Путь `rbxasset://textures/OceanHUD/...` работает **только в Studio на этом компьютере**.
Чтобы иконки увидели другие игроки:

1. В Studio открой **Window → Asset Manager → Bulk Import** и загрузи все PNG из папки `assets`:
   `Rebirth`, `Gifts`, `Shop`, `Index`, `Coin`, `Flippers`, `SharkFin`, `Egg`, `Sparkle`, `Backpack`.
2. Скопируй ID каждой картинки и вставь его в `src/modules/UIAssets.luau` → `UIAssets.Uploaded`,
   например `Coin = "rbxassetid://1234567890"`.
3. Пересобери проект (см. ниже).

Выдуманные ID в коде не используются: пока поле пустое, берётся локальная картинка.
После обновления Studio ещё раз запусти `install-studio-textures.ps1`: у новой версии Studio своя папка.

## Как устроено

| Файл | Где в игре | Что делает |
|---|---|---|
| `src/OceanHUD.client.luau` | StarterPlayerScripts → **OceanHUD** (LocalScript) | HUDController: создаёт интерфейс один раз, раскладку и связь с данными |
| `src/modules/UITheme.luau` | модуль внутри OceanHUD | цвета, размеры для экрана 1648×928, длительности анимаций |
| `src/modules/UIAssets.luau` | модуль | все картинки и звук клика в одном месте |
| `src/modules/UIComponents.luau` | модуль | объёмные плашки: тень, нижняя грань, градиент, блик, обводки |
| `src/modules/UIAnimations.luau` | модуль | TweenService: наведение, нажатие, «подпрыгивание», вспышка, покачивание |
| `src/modules/UIDataController.luau` | модуль | читает монеты и скорость игрока и сообщает об изменениях |
| `src/modules/MenuController.luau` | модуль | окна меню: появление через Scale + Fade, одно окно за раз |
| `src/modules/InventoryController.luau` | модуль | рюкзак [G], хотбар 1–8, окно инвентаря с вкладками и поиском |
| `src/server/OceanHUDStats.luau` | ServerScriptService → **OceanHUDStats** | серверные методы `setCoins`, `addCoins`, `setSpeed`, `addSpeed` |
| `src/server/OceanInventory.luau` | ServerScriptService → **OceanInventory** | серверный инвентарь: `add`, `remove`, `count`, `setHotbar` |
| `src/server/OceanHUDTestData.server.luau` | ServerScriptService | тестовые значения и предметы, работает **только в Studio** |
| `tools/draw_icons.py` | — | рисует иконки в `assets` (Python + Pillow) |

**Данные.** Сервер записывает атрибуты игрока: `Coins` и `SpeedLevel` (прокачанная скорость, просто число).
Если атрибута нет, используются одноимённые значения из `leaderstats`.
Клиент ничего не начисляет, он только показывает данные.

**Анимации.**
- Кнопки: при наведении увеличиваются на 7 % и подсвечиваются (0,17 с), при нажатии сжимаются до 93 % и проигрывают звук.
- Монеты: число плавно досчитывается до нового значения, монета подпрыгивает и вспыхивает.
- Скорость: при повышении текст увеличивается, ласты покачиваются.
- Инвентарь: окно и хотбар плавно появляются, рюкзак переезжает в начало хотбара.

Постоянных циклов нет: анимации запускаются только при изменениях. При удалении интерфейса все соединения отключаются.

**Меню.** Повторное нажатие той же кнопки закрывает меню. Закрыть можно также крестиком, кликом по фону или клавишей Esc.
Своё содержимое добавляй в `ScrollingFrame` **Content**:
`PlayerGui.OceanHUD.SafeArea.MenuBackdrop.ShopMenu.Panel.Body.Content`.
Чтобы открывать свои окна вместо встроенных, задай атрибут `UseExternalMenus = true` у `PlayerGui.OceanHUD`
и слушай событие `OpenMenu` (приходит `"Rebirth"`, `"Gifts"`, `"Shop"` или `"Index"`).

**Экран.** Размеры заданы для 1648×928 и масштабируются под размер экрана с учётом безопасной зоны Roblox.
На узких экранах хотбар поднимается над счётчиками, а окно инвентаря уменьшается.
Ни в закрытом, ни в открытом виде элементы не перекрывают друг друга: это проверено на 10 размерах, от 360×580 до 1920×1140.

## Сборка и проверка

Из папки `brain rot\OceanHUD`:

```powershell
python tools/draw_icons.py assets
..\..\tools\lune\lune.exe run tools/check.luau
..\..\tools\lune\lune.exe run tools/build.luau
.\tools\install-studio-textures.ps1
```

`build.luau` создаёт `OceanHUD.rbxmx` (клиентский LocalScript с модулями), `OceanHUD-Server.rbxmx`
(серверные скрипты) и `OceanMap-with-HUD.rbxl` — копию `OceanMap-v4` с интерфейсом. Сами файлы OceanMap не меняются.
`check.luau` прогоняет 160 офлайн-проверок: данные, анимации, меню, инвентарь, раскладку и серверные модули.
Версия 3.3 проверена вживую в Roblox Studio (скриншоты выше).

Чтобы встроить интерфейс в другой плейс: вставь `OceanHUD.rbxmx` в **StarterPlayerScripts**,
а `OceanHUD-Server.rbxmx` — в **ServerScriptService** (через **Insert from File…**).
