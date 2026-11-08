# OceanHUD v3 — интерфейс игры

![HUD в Roblox Studio](OceanHUD-preview.png)

Слева четыре кнопки: **Перерождение**, **Подарки**, **Магазин** и **Индекс**.
Внизу слева — монеты и скорость, внизу по центру — шкала опыта: звезда с текущим уровнем и корона со следующим.
Все иконки — PNG-картинки с прозрачным фоном, показанные через `ImageLabel`.

![Меню магазина](OceanHUD-menu-preview.png)

## Быстрый запуск в Studio

1. Один раз выполни `tools\install-studio-textures.ps1`. Скрипт копирует иконки в папку Studio,
   чтобы они показывались без загрузки на Roblox.
2. Открой **OceanMap-with-HUD.rbxl** и нажми **Play (F5)**.
   В Studio скрипт `OceanHUDTestData` сразу выставляет тестовые значения:
   монеты 125,430, скорость 18, уровень 24, опыт 7,850 / 10,000.

Чтобы посмотреть анимации, во время игры выполни в **Command Bar** (переключатель Server):

```lua
local S = require(game.ServerScriptService.OceanHUDStats)
local p = game.Players:GetPlayers()[1]
S.addCoins(p, 5000)  S.addXP(p, 3000)  S.setSpeedLevel(p, 19)
```

## Иконки для опубликованной игры (обязательно)

Путь `rbxasset://textures/OceanHUD/...` работает **только в Studio на этом компьютере**.
Чтобы иконки увидели другие игроки:

1. В Studio открой **Window → Asset Manager → Bulk Import** и загрузи все PNG из папки `assets`:
   `Rebirth`, `Gifts`, `Shop`, `Index`, `Coin`, `Speed`, `LevelStar`, `Crown`, `Sparkle`, `Stripes`.
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
| `src/modules/UIDataController.luau` | модуль | читает данные игрока и сообщает об изменениях |
| `src/modules/MenuController.luau` | модуль | окна меню: появление через Scale + Fade, одно окно за раз |
| `src/server/OceanHUDStats.luau` | ServerScriptService → **OceanHUDStats** | серверные методы `addCoins`, `addXP`, `setSpeedLevel`, `setLevel` |
| `src/server/OceanHUDTestData.server.luau` | ServerScriptService | тестовые значения, работает **только в Studio** |
| `tools/draw_icons.py` | — | рисует иконки в `assets` (Python + Pillow) |

**Данные.** Сервер записывает атрибуты игрока: `Coins`, `SpeedLevel`, `Level`, `XP`, `XPRequired`.
Если атрибута нет, используются одноимённые значения из `leaderstats`.
Клиент ничего не начисляет, он только показывает данные. `OceanHUDStats.addXP` переносит остаток опыта на следующий уровень
(уровню 24 нужно 10,000 XP, формула `1000 + уровень × 375`).

**Анимации.**
- Кнопки: при наведении увеличиваются на 7 % и подсвечиваются (0,17 с), при нажатии сжимаются до 93 % и проигрывают звук.
- Монеты: число плавно досчитывается до нового значения, монета подпрыгивает и вспыхивает.
- Скорость: при повышении текст увеличивается, молния покачивается.
- Опыт: шкала плавно заполняется. При новом уровне звезда подпрыгивает с вспышкой, шкала доходит до конца и начинается заново с остатком.

Постоянных циклов нет: анимации запускаются только при изменениях. При удалении интерфейса все соединения отключаются.

**Меню.** Повторное нажатие той же кнопки закрывает меню. Закрыть можно также крестиком, кликом по фону или клавишей Esc.
Своё содержимое добавляй в `ScrollingFrame` **Content**:
`PlayerGui.OceanHUD.SafeArea.MenuBackdrop.ShopMenu.Panel.Body.Content`.
Чтобы открывать свои окна вместо встроенных, задай атрибут `UseExternalMenus = true` у `PlayerGui.OceanHUD`
и слушай событие `OpenMenu` (приходит `"Rebirth"`, `"Gifts"`, `"Shop"` или `"Index"`).

**Экран.** Размеры заданы для 1648×928 и масштабируются под размер экрана с учётом безопасной зоны Roblox.
На узких экранах счётчики встают над шкалой опыта. Элементы не перекрывают друг друга:
это проверено на 10 размерах, от 360×580 до 1920×1140.

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
`check.luau` прогоняет 96 офлайн-проверок: данные, анимации, меню, раскладку и серверный перенос опыта.
Интерфейс также проверен вживую в Roblox Studio (скриншоты выше).

Чтобы встроить интерфейс в другой плейс: вставь `OceanHUD.rbxmx` в **StarterPlayerScripts**,
а `OceanHUD-Server.rbxmx` — в **ServerScriptService** (через **Insert from File…**).
