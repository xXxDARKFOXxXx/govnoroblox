# Studfish · 30 новых моделей

Расширение исходной коллекции Studfish. В наборе 20 рыб и других обитателей моря и 10 страшных рыб. Все модели выполнены в блочном стиле с рельефными квадратными шипами и пиксельными глазами. Скелет, текстуры и циклическая анимация на месте уже внутри каждого GLB.

[Превью морских обитателей](Studfish-SeaLife-preview.png) · [Превью страшных рыб](Studfish-Scary-preview.png)

## Установка в Roblox Studio

1. Распакуй ZIP. В Roblox Studio открой **File → Import** и выбери GLB из `Models/SeaLife` или `Models/Scary`. В окне импорта выбери **Rig Type → Custom** и **Scale Unit → Studs**, затем добавь модель в **Workspace**.
2. В **Explorer** раскрой модель. Выбери её **MeshPart**. В строке поиска панели **Properties** введи `Anchored` и поставь галочку, чтобы модель висела на месте.
3. Открой [StudfishRuntime.txt](StudfishRuntime.txt) в Блокноте и скопируй весь текст. В **StarterPlayer → StarterPlayerScripts** открой существующий LocalScript Studfish и полностью замени его текст. Если скрипта ещё нет, нажми **+** рядом со строкой **StarterPlayerScripts** и добавь **LocalScript**.
4. Нажми **F5** и подойди к модели. Движения, частицы и свет включатся рядом с камерой. У страшных рыб есть отдельное движение челюсти и периодические вспышки.

Обновлённый скрипт распознаёт все 50 моделей Studfish, включая первые 20, уже размещённые в твоём проекте. `StudfishRuntime.rbxmx` содержит тот же код. Достаточно одной копии LocalScript.

Размеры ниже указаны в студах в исходной позе.

## Морские обитатели · 20 моделей

| Модель | Название | Файл | Длина × ширина × высота | Цикл | Эффекты |
| --- | --- | --- | --- | --- | --- |
| Королевский хирург | Blue Circuit | [RegalTang.glb](Models/SeaLife/RegalTang.glb) | 4,7 × 3,2 × 3,6 | 3,3 с | Кобальтовые пузырьки и лимонные блики |
| Рыба-бабочка | Sunbeam Zip | [Butterflyfish.glb](Models/SeaLife/Butterflyfish.glb) | 4,2 × 2,6 × 2,8 | 2,7 с | Солнечные блёстки и тёплые кольца |
| Мавританский идол | Ivory Pennant | [MoorishIdol.glb](Models/SeaLife/MoorishIdol.glb) | 5,2 × 3,3 × 4,5 | 4,2 с | Жемчужные пузырьки и янтарные искры |
| Рыба-мандаринка | Confetti Reef | [Mandarin.glb](Models/SeaLife/Mandarin.glb) | 3,5 × 2,5 × 1,5 | 2,6 с | Коралловые и бирюзовые конфетти |
| Лосось | Silver Current | [Salmon.glb](Models/SeaLife/Salmon.glb) | 7,2 × 4,1 × 2,6 | 3,6 с | Серебряные блики и розовые пузырьки |
| Радужная форель | Berry Brook | [RibbonTrout.glb](Models/SeaLife/RibbonTrout.glb) | 6,4 × 3,6 × 2,3 | 3,0 с | Розовые частицы и лиловые кольца |
| Карликовый бычок | Moss Bean | [PygmyGoby.glb](Models/SeaLife/PygmyGoby.glb) | 2,4 × 1,6 × 1,0 | 2,3 с | Лаймовые искры и мелкие пузырьки |
| Рыба-попугай | Candy Beak | [Parrotfish.glb](Models/SeaLife/Parrotfish.glb) | 5,7 × 3,6 × 2,8 | 3,4 с | Розовые и зелёные искры |
| Сом | Twilight Whisker | [Catfish.glb](Models/SeaLife/Catfish.glb) | 8,0 × 4,6 × 2,4 | 4,4 с | Лиловые пузырьки и серебряная пыль |
| Сардина | Silver Chip | [Sardine.glb](Models/SeaLife/Sardine.glb) | 3,9 × 2,1 × 1,2 | 2,4 с | Мелкие серебристые блики и пузырьки |
| Камбала | Sand Pancake | [Flounder.glb](Models/SeaLife/Flounder.glb) | 4,9 × 3,3 × 1,0 | 3,8 с | Песчаные частицы и блики |
| Рыба-луна | Moon Button | [Sunfish.glb](Models/SeaLife/Sunfish.glb) | 4,3 × 3,7 × 6,4 | 5,0 с | Лунные кольца и серебристые искры |
| Морская черепаха | Mint Voyager | [SeaTurtle.glb](Models/SeaLife/SeaTurtle.glb) | 6,2 × 6,8 × 2,5 | 4,7 с | Мятные пузырьки и зелёные блики |
| Рак-отшельник | Shell Cottage | [HermitCrab.glb](Models/SeaLife/HermitCrab.glb) | 4,0 × 2,6 × 2,0 | 3,6 с | Персиковые пузырьки и золотые искры |
| Омар | Crimson Tongs | [Lobster.glb](Models/SeaLife/Lobster.glb) | 7,2 × 4,0 × 2,2 | 4,2 с | Коралловые искры и красные частицы |
| Наутилус | Ivory Spiral | [Nautilus.glb](Models/SeaLife/Nautilus.glb) | 3,6 × 2,2 × 2,8 | 4,3 с | Жемчужные кольца и персиковые блики |
| Морская звезда | Sunny Star | [Starfish.glb](Models/SeaLife/Starfish.glb) | 3,4 × 3,6 × 1,0 | 3,3 с | Золотистые звёздочки и коралловые конфетти |
| Морской ёж | Lilac Button | [SeaUrchin.glb](Models/SeaLife/SeaUrchin.glb) | 2,2 × 2,3 × 1,8 | 3,9 с | Сиреневые искры и блёстки |
| Креветка | Coral Comet | [Shrimp.glb](Models/SeaLife/Shrimp.glb) | 3,1 × 1,3 × 1,3 | 3,0 с | Персиковые пиксели и мелкие пузырьки |
| Каракатица | Jade Ink | [Cuttlefish.glb](Models/SeaLife/Cuttlefish.glb) | 4,9 × 3,2 × 1,6 | 4,2 с | Нефритовые искры и фиолетовая взвесь |

## Страшные рыбы · 10 моделей

| Модель | Название | Файл | Длина × ширина × высота | Цикл | Эффекты |
| --- | --- | --- | --- | --- | --- |
| Саблезуб | Ivory Gnash | [Fangtooth.glb](Models/Scary/Fangtooth.glb) | 6,1 × 4,7 × 3,3 | 3,7 с | Лиловые кольца и вспышки у клыков |
| Глубоководный дракон | Ember Thread | [Dragonfish.glb](Models/Scary/Dragonfish.glb) | 7,8 × 3,8 × 2,8 | 3,9 с | Багровая приманка, свет и искры |
| Мурена | Moss Bite | [Moray.glb](Models/Scary/Moray.glb) | 9,6 × 2,3 × 2,7 | 4,3 с | Зелёные частицы и пузырьки у пасти |
| Акула-гоблин | Hook Nose | [GoblinShark.glb](Models/Scary/GoblinShark.glb) | 10,0 × 5,6 × 3,1 | 4,3 с | Розовые вспышки и холодные частицы |
| Плащеносная акула | Ragged Collar | [FrilledShark.glb](Models/Scary/FrilledShark.glb) | 9,6 × 4,8 × 2,7 | 4,6 с | Медные кольца и ржавые искры |
| Рыба-пила | Razor Rail | [Sawfish.glb](Models/Scary/Sawfish.glb) | 10,3 × 6,4 × 2,9 | 4,2 с | Стальные искры и бирюзовые вспышки |
| Зубатка | Frost Molar | [Wolffish.glb](Models/Scary/Wolffish.glb) | 7,0 × 5,1 × 3,0 | 4,0 с | Ледяные искры и холодные кольца |
| Большерот | Pocket Void | [GulperEel.glb](Models/Scary/GulperEel.glb) | 9,6 × 4,8 × 3,4 | 4,9 с | Фиолетовая взвесь и вспышки у пасти |
| Рыба-камень | Basalt Crown | [Stonefish.glb](Models/Scary/Stonefish.glb) | 5,8 × 5,7 × 3,5 | 4,7 с | Янтарные искры и каменная взвесь |
| Пиранья | Red Snap | [Piranha.glb](Models/Scary/Piranha.glb) | 4,3 × 3,5 × 3,1 | 2,8 с | Красные вспышки и мятные искры |

[Документация Roblox Studio по импорту](https://create.roblox.com/docs/studio/importer)
