# Skybrick Lucky Block для Roblox

Золотой лаки-блок в стиле конструктора: восемь шипов на крышке,
выпуклые знаки вопроса и объёмные крылья со ступенчатыми перьями.

![Превью модели](models/skybrick/Preview.png)

**[Скачать весь комплект ZIP](https://github.com/xXxDARKFOXxXx/govnoroblox/raw/refs/heads/main/downloads/Skybrick_Lucky_Block_Complete.zip)**

В комплект входят:

- [FBX для импорта](models/skybrick/Skybrick_Lucky_Block.fbx) и [GLB](models/skybrick/Skybrick_Lucky_Block.glb).
- [Редактируемый исходник Blender](models/skybrick/Skybrick_Lucky_Block.blend).
- [Текстура](models/skybrick/Skybrick_Atlas.png) и [скрипт генерации модели](models/skybrick/build_lucky_block.py).
- [Адаптированная анимация открытия в TXT](models/skybrick/Roblox_Opening_Animation_Adapted.txt).
- [Установка и настройки новой анимации](models/skybrick/ANIMATION_ADAPTED_RU.md).
- [Автоматический установщик для Command Bar](models/skybrick/Studio_Install_CommandBar.txt)
  — если не появляется кнопка E или непонятно, куда вставлять Script.
- [Подробная инструкция на русском](models/skybrick/README_RU.txt).

## Установка

1. Импортируйте FBX через Import 3D в Roblox Studio, сохранив четыре отдельные
   части `Body`, `Lid`, `WingL`, `WingR` внутри общей `Model` в `Workspace`.
2. Создайте внутри этой модели обычный серверный `Script` и вставьте всё
   содержимое `Roblox_Opening_Animation_Adapted.txt`. Если уже установлен старый
   скрипт, замените его содержимое; оставьте только один скрипт открытия.
3. Нажмите Play, подойдите к блоку и удержите **E**.

Если E не появилась: остановите Play, выделите всю модель, скопируйте весь
`Studio_Install_CommandBar.txt` в **Command Bar** и выполните. Затем нажмите
Play / F5; в Output ожидается `[Skybrick] READY`. Подробнее —
[раздел диагностики](models/skybrick/ANIMATION_ADAPTED_RU.md#если-кнопка-e-не-появляется).

Новая анимация адаптирована из присланного пользователем `WINGED LUCKY BLOCK`:
зарядка, дрожание, пульсация, взмахи крыльев, 12 огоньков со шлейфами,
три вида частиц, световые импульсы, финальная вспышка и ударные сферы.
При вспышке крышка отлетает, блок исчезает и возрождается через 35 секунд.
Сохранены награды Tool из `ServerStorage/LuckyBlockRewards` или 25–150
`LuckyCoins`; их можно отключить через `RewardsEnabled = false`.
Звук и сохранение монет между сессиями не включены.

Предыдущая демонстрационная анимация сохранена отдельно в
`Roblox_Opening_Animation.txt`. Устанавливайте один из двух вариантов.

## Проверки

FBX и GLB проверены обратным импортом в Blender 4.3.2: четыре сетки,
доступная текстура, корректные UV и симметрия крыльев. В исходнике Blender
проверены открытие крышки, подъём крыльев и возврат в исходное положение.

Roblox Studio здесь не запускался. Проверку импорта, эффектов, управления
и работы с несколькими игроками необходимо выполнить в Studio.
Подробности: [VALIDATION.txt](models/skybrick/VALIDATION.txt).

Адаптированный TXT и установщик прошли компиляцию официальным Luau;
21 сценарий логики/запуска проверен с тестовыми объектами Roblox. Проверки в самом Studio остаются
обязательными; подробнее в [инструкции анимации](models/skybrick/ANIMATION_ADAPTED_RU.md#проверки).
