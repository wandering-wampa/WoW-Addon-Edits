# Changelog

## [3.9.58] — 2026-10-29

### English

- **New — `/conc last`** (`/conc eta`) — Print the tracked line that reaches full concentration last. LDB and minimap tooltips show it next to the soonest line. `/conc next` is unchanged.
- **New — `/conc alpha`** (`/conc opacity`) — Show or set window opacity from 0 to 100, matching the settings slider.
- **New — `/conc markme`** and **`/conc fullhl`** — Toggle the highlight for this character's rows and for rows already at cap, without opening settings.

### Українська

- **Нове — `/conc last`** (`/conc eta`) — Рядок, що досягне повної концентрації останнім. У тултіпах LDB і міні-карти він стоїть поруч із найближчим. `/conc next` без змін.
- **Нове — `/conc alpha`** (`/conc opacity`) — Непрозорість вікна від 0 до 100, як повзунок у налаштуваннях.
- **Нове — `/conc markme`** та **`/conc fullhl`** — Підсвітка рядків цього персонажа і вже повних рядків без відкриття налаштувань.

## [3.9.57] — 2026-10-25

### English

- **New — `/conc top`** (`/conc best`) — List the highest current concentration rows. Default is 5; `/conc top 10` shows up to 20.
- **New — `/conc avg`** (`/conc average`) — Average fill across tracked rows. The same percent appears in the window footer and in LDB/minimap tooltips.
- **New — `/conc scale`**, **`/conc font`**, and **`/conc showmoxie`** — Set window scale (50–150 or 0.5–1.5) and font size (10–18), or show/hide Moxie in the profession list. Ranges match the settings sliders.

### Українська

- **Нове — `/conc top`** (`/conc best`) — Рядки з найбільшою поточною концентрацією. За замовчуванням 5; `/conc top 10` показує до 20.
- **Нове — `/conc avg`** (`/conc average`) — Середнє заповнення відстежуваних рядків. Той самий відсоток є в підсумку вікна та в тултіпах LDB/міні-карти.
- **Нове — `/conc scale`**, **`/conc font`** і **`/conc showmoxie`** — Масштаб вікна (50–150 або 0.5–1.5), розмір шрифту (10–18) і показ Moxie в списку професій. Межі ті самі, що в повзунках налаштувань.

## [3.9.56] — 2026-10-21

### English

- **New — `/conc col`** (`/conc column`) — Show or hide a table column (`character`, `profession`, `moxie`, `concentration`, `time`, `exact`). With no argument, lists which columns are visible. The last visible column cannot be hidden, same as the settings checkboxes.
- **New — `/conc rate`** — Print the restore rate. `/conc rate 12` sets it, clamped to 1–25 per hour to match the settings slider.
- **New — `/conc chatlog`** and **`/conc sound`** — Toggle chat logging of concentration updates, and the notification sound, without opening settings.

### Українська

- **Нове — `/conc col`** (`/conc column`) — Показати або сховати колонку таблиці (`character`, `profession`, `moxie`, `concentration`, `time`, `exact`). Без аргумента — які колонки видимі. Останню видиму колонку сховати не можна, як і в налаштуваннях.
- **Нове — `/conc rate`** — Показати швидкість відновлення. `/conc rate 12` задає її в межах 1–25 за годину, як повзунок у налаштуваннях.
- **Нове — `/conc chatlog`** та **`/conc sound`** — Друк оновлень концентрації в чат і звук сповіщень без відкриття налаштувань.

## [3.9.55] — 2026-10-17

### English

- **New — `/conc reach`** (`/conc target`) — Time until tracked rows hit a concentration amount, for example `/conc reach 500`. Rows that already have it, and rows whose cap is lower, are counted separately.
- **New — `/conc exp`** (`/conc expansion`) — Print one expansion across characters, for example `/conc exp Midnight` or `/conc exp tww`. Does not change the window filters.
- **New — `/conc sort`** — Set the table sort (`character`, `profession`, `moxie`, `concentration`, `time`). The same column again, or `/conc sort` with no argument, flips direction. Clicking a header still works the same way.

### Українська

- **Нове — `/conc reach`** (`/conc target`) — Час, за який рядки досягнуть заданої концентрації, наприклад `/conc reach 500`. Окремо рахуються ті, хто вже має стільки, і ті, чий максимум нижчий.
- **Нове — `/conc exp`** (`/conc expansion`) — Одне доповнення на всіх персонажах, наприклад `/conc exp Midnight` або `/conc exp tww`. Фільтри вікна не змінює.
- **Нове — `/conc sort`** — Колонка сортування (`character`, `profession`, `moxie`, `concentration`, `time`). Та сама колонка ще раз, або `/conc sort` без аргумента, змінює напрям. Клік по заголовку працює як раніше.

## [3.9.54] — 2026-10-09

### English

- **New — `/conc below`** (`/conc under`) — List rows under a fill percent. Default is 25; `/conc below 50` changes it. Footer and LDB/minimap tooltips count rows under 25%.
- **New — `/conc char`** (`/conc alt`) — Print one character across professions, for example `/conc char Name`. Does not change the window filters. `/conc chars` still lists every tracked character.
- **New — `/conc autoself`** and **`/conc refreshopen`** — Toggle auto-filter to this character and sync-on-open without opening settings.

### Українська

- **Нове — `/conc below`** (`/conc under`) — Рядки нижче відсотка заповнення. За замовчуванням 25; `/conc below 50` змінює поріг. У підсумку та тултіпах LDB/міні-карти — скільки рядків нижче 25%.
- **Нове — `/conc char`** (`/conc alt`) — Один персонаж по професіях, наприклад `/conc char Ім'я`. Фільтри вікна не змінює. `/conc chars` як і раніше показує всіх персонажів.
- **Нове — `/conc autoself`** та **`/conc refreshopen`** — Автофільтр на цього персонажа і синхронізація при відкритті вікна без налаштувань.

## [3.9.53] — 2026-10-03

### English

- **New — `/conc spend`** (`/conc usable`) — List rows that already have concentration to craft with. Default is 100; `/conc spend 250` raises it. Footer and LDB/minimap tooltips show how many rows meet the default.
- **New — `/conc prof`** (`/conc profession`) — Print one profession across characters, for example `/conc prof Alchemy`. Does not change the window filters.
- **New — `/conc hidemoxie`** and **`/conc lowlight`** — Toggle Moxie-only rows and the low-concentration highlight without opening settings.

### Українська

- **Нове — `/conc spend`** (`/conc usable`) — Рядки, де вже є концентрація для крафту. За замовчуванням 100; `/conc spend 250` піднімає поріг. У підсумку та тултіпах LDB/міні-карти — скільки рядків проходять поріг.
- **Нове — `/conc prof`** (`/conc profession`) — Одна професія на всіх персонажах, наприклад `/conc prof Alchemy`. Фільтри вікна не змінює.
- **Нове — `/conc hidemoxie`** та **`/conc lowlight`** — Рядки лише з Moxie і підсвітка низької концентрації без відкриття налаштувань.

## [3.9.52] — 2026-09-26

### English

- **New — `/conc week`** (`/conc wreset`) — List rows that reach full concentration before the weekly reset. Footer and LDB/minimap tooltips show the count. `/conc weekly` still lists turn-in quests.
- **New — `/conc missing`** (`/conc gap`, `/conc deficit`) — How much concentration is still needed to cap, with the eight largest gaps.
- **New — `/conc moxiecap`** (`/conc m600`) — List tracked rows at or above 600 Moxie. Optional threshold: `/conc moxiecap 500`.

### Українська

- **Нове — `/conc week`** (`/conc wreset`) — Рядки, що досягнуть максимуму до тижневого ресету. У підсумку та тултіпах LDB/міні-карти — лічильник. `/conc weekly` як і раніше показує квести на здачу.
- **Нове — `/conc missing`** (`/conc gap`, `/conc deficit`) — Скільки концентрації бракує до максимуму, і вісім найбільших розривів.
- **Нове — `/conc moxiecap`** (`/conc m600`) — Рядки з Moxie від 600. Поріг можна змінити: `/conc moxiecap 500`.

## [3.9.51] — 2026-09-21

### English

- **New — `/conc today`** (`/conc daily`) — List rows that reach full concentration before the next daily reset. Footer and LDB/minimap tooltips show the count.
- **New — `/conc totals`** (`/conc sum`, `/conc summary`) — Account-wide snapshot: characters, concentration, Moxie, soon/reset/stale counts, and turn-ins.
- **New — `/conc focuslow`** (`/conc flo`) — Open the window on the lowest incomplete concentration line (sets character and profession, same as `/conc focus`).
- **New — `/conc hidestale`** and **`/conc highlight`** — Toggle hide-stale-rows and soon-to-fill highlight without opening settings.

### Українська

- **Нове — `/conc today`** (`/conc daily`) — Рядки, що досягнуть максимуму до добового ресету. У підсумку та тултіпах LDB/міні-карти — лічильник.
- **Нове — `/conc totals`** (`/conc sum`, `/conc summary`) — Зріз по акаунту: персонажі, концентрація, Moxie, «скоро» / до ресету / застарілі, здати квести.
- **Нове — `/conc focuslow`** (`/conc flo`) — Відкриває вікно на рядку з найнижчою неповною концентрацією (ставить персонажа й професію, як `/conc focus`).
- **Нове — `/conc hidestale`** та **`/conc highlight`** — Ховання застарілих рядків і підсвітка «скоро повні» без відкриття налаштувань.

## [3.9.50] — 2026-09-15

### English

- **New — `/conc focus`** (`/conc jump`) — Opens the window on the next line to fill (clears other filters, then sets that character and profession; does not toggle the profession filter).
- **New — `/conc hidefull`**, **`/conc percent`**, **`/conc compact`** — Toggle hide-full rows, concentration percent, and compact time format without opening settings.
- **UI** — Idiot Alert banner is clickable: click lists ready weeklies in chat, Ctrl+click copies them into the chat box.

### Українська

- **Нове — `/conc focus`** (`/conc jump`) — Відкриває вікно на рядку, що найближче до повної концентрації (скидає інші фільтри, ставить цього персонажа й професію; фільтр професії не перемикається).
- **Нове — `/conc hidefull`**, **`/conc percent`**, **`/conc compact`** — Перемикають ховання повних рядків, відсоток концентрації та компактний час без відкриття налаштувань.
- **UI** — Банер Idiot Alert клікабельний: клік друкує список у чат, Ctrl+клік копіює в поле чату.

## [3.9.49] — 2026-09-10

### English

- **Fix** — Idiot Alert no longer errors on open (`MAIN_HEADER_HEIGHT` was a nil global inside the banner updater).

### Українська

- **Виправлення** — Idiot Alert більше не падає при відкритті вікна (`MAIN_HEADER_HEIGHT` була порожньою глобальною в оновленні банера).

## [3.9.48] — 2026-09-10

### English

- **New — Idiot Alert** — Warns when a weekly profession quest is in your log, complete, and not yet turned in (banner, raid warning / sound if notifications are on). Thanks GaitaofThrall.
- **New — `/conc weekly`** (`/conc turnin`, `/conc idiot`) — List those ready-to-turn-in profession weeklies.
- **Settings** — Optional checkbox (on by default). Footer, title, and LDB/minimap tooltips show the turn-in count.

### Українська

- **Нове — Idiot Alert** — Попереджає, якщо тижневий квест професії вже виконано в журналі, але ще не здано (банер і сповіщення, якщо нотифікації увімкнені). Подяка GaitaofThrall.
- **Нове — `/conc weekly`** (`/conc turnin`, `/conc idiot`) — Список таких квестів.
- **Налаштування** — Опція (увімкнена за замовчуванням). У підсумку, заголовку та тултіпах LDB/міні-карти — скільки квестів здати.

## [3.9.47] — 2026-09-10

### English

- **New — search** — Toolbar box and **`/conc search text`** filter the table by character, realm, or profession (session-only; Clear / empty search resets it).
- **New — `/conc export`** — Copy currently visible rows into the chat edit box.
- **New — `/conc oldest`** — Print the least recently synced tracked row.
- **New — `/conc ignored`** — List ignored profession variants.
- **New — `/conc notify`** and **`/conc realm`** — Toggle notifications and realm names.
- **UI** — When stale rows are visible, the footer also shows the oldest sync age.

### Українська

- **Нове — пошук** — Поле на панелі та **`/conc search текст`** фільтрують таблицю за персонажем, реалмом або професією (лише для сесії; Скинути / порожній пошук очищує).
- **Нове — `/conc export`** — Копіює видимі рядки в поле чату.
- **Нове — `/conc oldest`** — Найдавніше синхронізований рядок.
- **Нове — `/conc ignored`** — Список ігнорованих варіантів професій.
- **Нове — `/conc notify`** та **`/conc realm`** — Перемикають сповіщення та назви реалмів.
- **UI** — Якщо є застарілі рядки, у підсумку також вік найстарішої синхронізації.

## [3.9.46] — 2026-09-01

### English

- **New — `/conc soon`** (`/conc 2h`) — List rows that reach full concentration within 2 hours. Optional hours: `/conc soon 4`.
- **New — `/conc list`** (`/conc visible`) — Print the currently visible table rows (respects filters).
- **New — `/conc combat`** — Toggle hide-in-combat without opening settings.
- **New — highlight soon-to-fill** — Optional yellow tint for rows that fill within 2 hours (off by default).
- **UI** — Footer and LDB/minimap tooltips show how many rows fill soon.

### Українська

- **Нове — `/conc soon`** (`/conc 2h`) — Рядки, що досягнуть максимуму за 2 год. Можна вказати години: `/conc soon 4`.
- **Нове — `/conc list`** (`/conc visible`) — Друкує видимі рядки таблиці (з урахуванням фільтрів).
- **Нове — `/conc combat`** — Перемикає ховання в бою без відкриття налаштувань.
- **Нове — підсвітка «скоро повні»** — Опційний жовтий відтінок для рядків, що заповняться за 2 год (вимкнено за замовчуванням).
- **UI** — У підсумку та тултіпах LDB/міні-карти кількість рядків, що скоро заповняться.

## [3.9.45] — 2026-08-26

### English

- **Fix** — Split the event handler so it stays under Lua's 60-upvalue limit (`function has more than 60 upvalues`). Slash commands, LDB, and combat hide behave the same.

### Українська

- **Виправлення** — Обробник подій розбито, щоб не перевищувати ліміт Lua у 60 upvalues (`function has more than 60 upvalues`). Slash-команди, LDB і ховання в бою працюють як раніше.

## [3.9.44] — 2026-08-26

### English

- **New — hide in combat** — Optional setting to hide the main window when combat starts and restore it after (off by default). Closing the window yourself during combat cancels the restore.
- **New — Alt+Right-click** — Filter the list to that row's expansion (click again to clear to All).
- **New — `/conc full`** — List every row already at maximum concentration.
- **New — `/conc copy`** — Insert this character's status into the chat edit box.
- **New — `/conc minimap`** (`/conc mm`) and **`/conc lock`** — Toggle the minimap button and window lock.
- **LDB / minimap** — Tooltips also show the lowest incomplete line (`Lowest: …`).

### Українська

- **Нове — ховати в бою** — Опція ховає головне вікно на початку бою і повертає після нього (вимкнено за замовчуванням). Якщо закрити вікно вручну під час бою, після бою воно не відкриється знову.
- **Нове — Alt+ПКМ** — Фільтр на доповнення цього рядка (повторний клік повертає «Усі»).
- **Нове — `/conc full`** — Усі рядки вже на максимумі концентрації.
- **Нове — `/conc copy`** — Вставляє статус цього персонажа в поле чату.
- **Нове — `/conc minimap`** (`/conc mm`) та **`/conc lock`** — Перемикають кнопку міні-карти та блокування вікна.
- **LDB / міні-карта** — У тултіпах також рядок «Найнижча: …».

## [3.9.43] — 2026-08-20

### English

- **New — hide stale rows** — Optional setting to hide lines not synced in over 24 hours (off by default).
- **New — hide Moxie-only rows** — Optional setting to hide professions that have Moxie but no concentration (off by default).
- **New — `/conc stale`** — Print every stale tracked row (character, profession, last sync age).
- **New — `/conc chars`** — List tracked characters with profession counts (and stale counts when any).
- **UI** — Title shows the active expansion / profession / character filters; footer adds visible row count and stale count; empty list explains when filters hid everything.

### Українська

- **Нове — приховати застарілі рядки** — Опція ховає рядки без синхронізації понад 24 год (вимкнено за замовчуванням).
- **Нове — приховати рядки лише з Moxie** — Опція ховає професії без концентрації (вимкнено за замовчуванням).
- **Нове — `/conc stale`** — Друкує всі застарілі рядки (персонаж, професія, вік даних).
- **Нове — `/conc chars`** — Список відстежуваних персонажів із кількістю професій (і застарілих, якщо є).
- **UI** — У заголовку активні фільтри доповнення / професії / персонажа; у підсумку кількість видимих і застарілих рядків; порожній список пояснює, що все сховали фільтри.

## [3.9.42] — 2026-08-15

### English

- **New — mark this character** — Gold bar on rows that belong to the logged-in character (on by default; Settings).
- **New — `/conc lowest`** (`/conc lo`) — Print the lowest incomplete concentration line (character, profession, %, time to full).
- **New — copy row** — Ctrl+Right-click inserts that row into the chat edit box.
- **New — lock window** — Settings option to prevent dragging/resizing; **`/conc resetui`** recenters the window.
- **New — `/conc settings`** — Opens settings (same as `/conclanguage`). LDB broker right-click also opens settings.

### Українська

- **Нове — позначка цього персонажа** — Золота смужка на рядках залогіненого персонажа (увімкнено за замовчуванням; Налаштування).
- **Нове — `/conc lowest`** (`/conc lo`) — Найнижча неповна концентрація в чат (персонаж, професія, %, час до повної).
- **Нове — копіювання рядка** — Ctrl+ПКМ вставляє рядок у поле чату.
- **Нове — блокування вікна** — Опція в Налаштуваннях забороняє перетягування/ресайз; **`/conc resetui`** повертає вікно в центр.
- **Нове — `/conc settings`** — Відкриває налаштування (як `/conclanguage`). ПКМ по LDB-брокеру теж відкриває налаштування.

## [3.9.41] — 2026-08-09

### English

- **New — Shift+Right-click** — Filter the list to that row's profession (click again to clear to All). Right-click still filters by character.
- **New — `/conc moxie`** (`/conc mx`) — Print this character's Artisan's Moxie balances (and total) to chat.
- **New — highlight low concentration** — Optional red tint for rows below 25% fill (Settings; off by default).
- **New — refresh on open** — Optional setting to sync the logged-in character from the API whenever the main window opens.
- **UI** — Footer summary shows total Moxie for the currently visible rows when Moxie is enabled.

### Українська

- **Нове — Shift+ПКМ** — Фільтр на професію цього рядка (повторний клік повертає «Усі»). Звичайний ПКМ як і раніше — фільтр персонажа.
- **Нове — `/conc moxie`** (`/conc mx`) — Artisan's Moxie поточного персонажа (і сума) в чат.
- **Нове — підсвітка низької концентрації** — Опційний червонуватий відтінок для рядків нижче 25% (Налаштування; вимкнено за замовчуванням).
- **Нове — оновлення при відкритті** — Опція синхронізувати поточного персонажа з API щоразу при відкритті головного вікна.
- **UI** — У підсумку сума Moxie по видимих рядках (якщо колонка Moxie увімкнена).

## [3.9.40] — 2026-08-03

### English

- **Bugfix — Moxie currency IDs** — Corrected the profession → Artisan Moxie mapping for **Inscription** (Scribe's), **Jewelcrafting**, **Leatherworking**, and **Mining**. Those professions could show `0` (or another profession's Moxie) because the fallback IDs were swapped.
- **Data** — On load, stored rows with a mismatched Moxie currency ID are reconciled and quantities are cleared so the live API can refill the correct value after `/reload` or logging in on that character.

### Українська

- **Виправлення — ID валют Moxie** — Виправлено мапу професія → Artisan Moxie для **Напису** (Scribe's), **Ювелірної справи**, **Шкірництва** та **Гірництва**. Через переплутані fallback-ID ці професії могли показувати `0` (або чужу Moxie).
- **Дані** — При завантаженні рядки з невірним `moxieCurrencyID` узгоджуються, кількість скидається; актуальне значення підтягнеться з API після `/reload` або входу на персонажа.

## [3.9.39] — 2026-08-02

### English

- **New — highlight full rows** — Optional green tint for rows already at max concentration (on by default; Settings).
- **New — auto-filter this character** — Optional setting to filter the list to the logged-in character when opening the main window.
- **New — `/conc version`** (`/conc v`) — Print the addon version to chat.
- **UI** — Summary shows unique character count when more than one char is visible; right-click a row to filter to that character.
- **LDB / minimap** — Tooltips show the soonest line to fill (`Next: …`).

### Українська

- **Нове — підсвітка повних рядків** — Опційний зелений відтінок для рядків на максимумі (увімкнено за замовчуванням; Налаштування).
- **Нове — автофільтр на цього персонажа** — Опція одразу фільтрувати список на залогіненого персонажа при відкритті вікна.
- **Нове — `/conc version`** (`/conc v`) — Версія аддона в чат.
- **UI** — У підсумку кількість унікальних персонажів (якщо більше одного); ПКМ по рядку — фільтр на цього персонажа.
- **LDB / міні-карта** — У тултіпах рядок «Далі: …» (найближче до повної).

## [3.9.38] — 2026-07-27

### English

- **UI** — Removed the redundant **Sort Ascending / Descending** button (column headers already sort and toggle direction).
- **UI** — Filter action buttons (**This char**, **Hide full**, **Clear**) moved to a second toolbar row under the dropdowns so they no longer overflow the window.

### Українська

- **UI** — Прибрано зайву кнопку **Сортувати за зростанням/спаданням** (сортування вже є через заголовки колонок).
- **UI** — Кнопки фільтрів (**Цей перс.**, **Сховати повні**, **Скинути**) перенесено на другий рядок під dropdown, щоб не виходили за межі вікна.

## [3.9.37] — 2026-07-27

### English

- **New — next to fill** — Footer summary shows the soonest incomplete line (`Next: Name (Profession) 2h 15m`); **`/conc next`** (`/conc n`) prints the same for all tracked data to chat.
- **New — clear filters** — Main-window **Clear filters** button and **`/conc clear`** reset expansion, profession, and character filters to All.
- **New — Hide full toggle** — Quick button on the main window (same setting as in Settings).
- **UI** — **This char** button text turns gold while that filter is active.
- **Sort** — Stable tie-breakers (character → profession → row key) so equal values no longer reshuffle every refresh.

### Українська

- **Нове — наступна до повної** — У підсумку показується найближчий неповний рядок (`Далі: Ім’я (Професія) 2 год 15 хв`); **`/conc next`** (`/conc n`) друкує те саме по всіх даних у чат.
- **Нове — скинути фільтри** — Кнопка **Скинути фільтри** та **`/conc clear`** повертають доповнення, професію й персонажа на «Усі».
- **Нове — Сховати повні** — Швидка кнопка в головному вікні (те саме налаштування, що в Settings).
- **UI** — Кнопка **Цей перс.** підсвічується золотим, поки фільтр активний.
- **Сортування** — Стабільні запасні ключі (персонаж → професія → ключ рядка), щоб однакові значення не «стрибали» при кожному оновленні.

## [3.9.36] — 2026-07-21

### English

- **New — This character** — Button on the main window toggles the character filter to the logged-in character; **`/conc me`** opens the window already filtered.
- **New — concentration %** — Optional setting to show fill percentage (e.g. `750/1000 · 75%`).
- **New — compact time** — Optional setting to hide seconds in the time-to-full column.
- **UI** — Full concentration shows localized **Full** instead of `0 h 0 m 0 s` / current datetime.
- **Forecast** — Target forecast respects the same character / profession / expansion filters as the table (no longer jumps to an unrelated alt).
- **LDB** — Broker text shows live `not-full/total` count when LibDataBroker is present.

### Українська

- **Нове — Цей персонаж** — Кнопка в головному вікні вмикає фільтр на залогіненого персонажа; **`/conc me`** відкриває вікно вже з цим фільтром.
- **Нове — % концентрації** — Опція в налаштуваннях показує відсоток заповнення (напр. `750/1000 · 75%`).
- **Нове — компактний час** — Опція ховає секунди в колонці «час до повного».
- **UI** — Повна концентрація показує локалізоване **Повна** замість `0 год 0 хв 0 сек` / поточної дати.
- **Прогноз** — Прогноз до цілі враховує ті самі фільтри персонажа / професії / доповнення, що й таблиця.
- **LDB** — Текст брокера показує актуальний лічильник `неповні/всього`, якщо є LibDataBroker.

## [3.9.35] — 2026-07-16

### English

- **New — character filter** — Dropdown on the main window to show only one character (All Characters by default); sanitized on login like other filters.
- **New — hide full concentration** — Settings option to hide rows already at maximum concentration (focus on what still needs regen).
- **New — `/conc status`** (`/conc s`) — Prints the current character’s concentration and Moxie to chat; **`/conc help`** (`/conc ?`) lists commands.
- **UI** — Summary shows how many tracked rows are full; row tooltips include last sync age; stale data (>24h) dims time columns and adds a refresh hint.
- **UI** — Time-to-full text uses the same green/yellow/red fill colors as the concentration bar.

### Українська

- **Нове — фільтр персонажа** — Випадаючий список у головному вікні: лише один персонаж або «Усі персонажі»; санітизація при логіні як у інших фільтрів.
- **Нове — приховати повну концентрацію** — Опція в налаштуваннях ховає рядки вже на максимумі (зручніше бачити, що ще відновлюється).
- **Нове — `/conc status`** (`/conc s`) — Друкує концентрацію та Moxie поточного персонажа в чат; **`/conc help`** (`/conc ?`) — список команд.
- **UI** — У підсумку кількість повних рядків; у тултіпі вік синхронізації; застарілі дані (>24 год) приглушують колонки часу та підказують оновити.
- **UI** — Текст «час до повного» забарвлюється так само, як смужка концентрації (зелений / жовтий / червоний).

## [3.9.34] — 2026-07-10

### English

- **Bugfix — Moxie upsert** — `UpsertMoxieOnlyRow` no longer always reports a change (`return changed or true`). Stops unnecessary UI/dropdown rebuilds on the 8s Moxie poll when values are unchanged.
- **Performance** — `EnsureLocalization()` caches the active language table instead of rebuilding all locales on every currency sync, refresh, and tooltip.
- **Performance** — Skill-line resolve from the open profession window reuses the active-profession cache; `AfterConcentrationDataChanged` skips dropdown refresh when both windows are hidden.
- **Robustness** — `SanitizeSettings()` fills missing keys and clamps font size, scale, transparency, and restore rate; validates language code. One-shot login/world timers are cancelled on `/reload` and logout (no duplicate sync after reload).
- **Robustness** — Guards for missing `C_TradeSkillUI` before profession/Moxie API calls; removed unused `CheckMoxieForCurrentCharacter` wrapper; `GetEffectiveMaxQuantity` uses `MAX_CONCENTRATION`.

### Українська

- **Виправлення — upsert Moxie** — `UpsertMoxieOnlyRow` більше не завжди повертає «змінено» (`return changed or true`). Менше зайвих оновлень UI/dropdown під час опитування Moxie кожні 8 с, якщо значення не змінились.
- **Швидкодія** — `EnsureLocalization()` кешує таблицю поточної мови замість повної перебудови локалей на кожній синхронізації валют, refresh і тултіпі.
- **Швидкодія** — Визначення skill line з відкритого вікна професії використовує кеш активних професій; `AfterConcentrationDataChanged` не оновлює dropdown, якщо обидва вікна закриті.
- **Стійкість** — `SanitizeSettings()` заповнює відсутні ключі та обмежує розмір шрифту, масштаб, прозорість і швидкість відновлення; перевіряє код мови. Одноразові таймери логіну/входу у світ скасовуються при `/reload` і виході (без подвійної синхронізації після reload).
- **Стійкість** — Перевірки на відсутній `C_TradeSkillUI` перед викликами API; прибрано невикористовуваний `CheckMoxieForCurrentCharacter`; `GetEffectiveMaxQuantity` використовує `MAX_CONCENTRATION`.

## [3.9.33] — 2026-07-04

### English

- **Bugfix — notifications & LDB** — Full-concentration alerts and the broker “not at cap” count now skip abandoned profession rows for the logged-in character (same rules as the main table).
- **Performance** — Active profession cache also stores Moxie currency IDs; `GetCurrentPlayerMoxieCurrencySet()` reuses one scan instead of duplicating `GetProfessions`.
- **Cleanup** — Removed unused `notificationTracker` table (`notifiedAtFull` on each row is the source of truth); dropped duplicate `varId` assignment in `RecordConcentration()`.

### Українська

- **Виправлення — сповіщення та LDB** — Сповіщення про повну концентрацію та лічильник «не на максимумі» у брокері більше не враховують покинуті професії поточного персонажа (ті самі правила, що й у головній таблиці).
- **Швидкодія** — Кеш активних професій також зберігає ID валют Moxie; `GetCurrentPlayerMoxieCurrencySet()` використовує один прохід замість повторного `GetProfessions`.
- **Прибирання коду** — Видалено невикористовувану таблицю `notificationTracker` (стан зберігається в `notifiedAtFull` кожного рядка); прибрано дубльоване присвоєння `varId` у `RecordConcentration()`.

## [3.9.32] — 2026-06-26

### English

- **Bugfix — professions disappearing / wrong prof on login** — Active professions are now matched by **profession type** (Blacksmithing, Tailoring, etc.), not only the exact skill line ID. Fixes rows vanishing when opening a profession window, Tailoring missing on some characters, and old expansion skill lines being treated as abandoned.
- **Bugfix — RecordConcentration** — Uses the **child skill line** from the open profession window (`GetProfessionChildSkillLineID` / `GetProfessions`), not the parent `professionID`. Legacy parent-ID rows migrate automatically when you open that profession.
- **Bugfix — abandoned professions** — Dead professions (e.g. unlearned Mining) are still filtered out by profession type; Moxie tracking uses the same enum-based matching.
- **After updating:** `/reload`, then `/conc refresh`, then open each profession window once.



### Українська

- **Виправлення — зникнення професій / неправильна prof при логіні** — Активні професії тепер зіставляються за **типом професії** (Ковальство, Шиття тощо), а не лише за точним skill line ID. Виправлено зникнення рядків при відкритті вікна професії, відсутність Шиття на деяких персонажах і помилкове приховування старих ліній навичок.
- **Виправлення — RecordConcentration** — Використовується **child skill line** з відкритого вікна (`GetProfessionChildSkillLineID` / `GetProfessions`), а не батьківський `professionID`. Старі записи з parent-ID мігрують при відкритті професії.
- **Виправлення — покинуті професії** — Невивчені професії (напр. Mining) як і раніше фільтруються за типом; Moxie використовує те саме enum-зіставлення.
- **Після оновлення:** `/reload`, `/conc refresh`, потім один раз відкрийте кожне вікно професії.



## [3.9.31] — 2026-06-25



### English

- **Release — Moxie & login fixes** — Bundles 3.9.29–3.9.30: Moxie resolves from the current skill line (not stale saved currency IDs), abandoned profession rows are hidden for your character, opening a profession window refreshes Moxie quantity from the API, and the login `attempt to call a nil value` crash is fixed.
- **After updating:** run `/reload`, then `/conc refresh`.



### Українська

- **Реліз — Moxie та логін** — Об’єднує 3.9.29–3.9.30: Moxie прив’язується до поточної skill line (не до застарілого currency ID), рядки покинутих професій приховуються, відкриття вікна професії оновлює кількість Moxie з API, виправлено краш `attempt to call a nil value` при вході в гру.
- **Після оновлення:** `/reload`, потім `/conc refresh`.



## [3.9.30] — 2026-06-25



### English

- **Bugfix** — Fixed `attempt to call a nil value` on login (`HasKnownActiveProfessionsForCurrentPlayer` called `GetCurrentPlayerProfessionSkillLineSet` before it was defined).



### Українська

- **Виправлення** — Виправлено `attempt to call a nil value` при вході в гру (forward-reference: функція викликалась до оголошення).



## [3.9.29] — 2026-06-02



### English

- **Bugfix — Moxie (login / abandoned professions)** — Fixed stale Moxie still showing after opening a profession window. Moxie currency is now resolved from the **current skill line**, not a leftover stored currency ID. Opening a profession window refreshes both Moxie currency and quantity from the API. Abandoned profession rows are hidden for the current character on login and during sync.
- **After updating:** run `/reload`, then `/conc refresh`.



### Українська

- **Виправлення — Moxie (логін / покинуті професії)** — Виправлено застарілий Moxie після відкриття вікна професії. Валюта Moxie тепер береться з **поточної skill line**, а не зі старого збереженого ID. Відкриття вікна професії оновлює валюту та кількість Moxie з API. Рядки покинутих професій приховуються для поточного персонажа при вході та під час синхронізації.
- **Після оновлення:** `/reload`, потім `/conc refresh`.



## [3.9.28] — 2026-06-25



### English

- **Bugfix — Moxie (abandoned professions)** — Fixed wrong Moxie values when you had unlearned professions that still hold Artisan's Moxie in the game. The addon now tracks Moxie only for your **two active professions** (`GetProfessions`). Stale Moxie rows are removed on sync; old concentration rows no longer show Moxie from abandoned professions.
- **After updating:** run `/reload`, then `/conc refresh` (or open the main window once).



### Українська

- **Виправлення — Moxie (покинуті професії)** — Виправлено некоректний Moxie, якщо у вас були невивчені професії з балансом Artisan's Moxie в грі. Аддон тепер відстежує Moxie лише для **двох активних професій** (`GetProfessions`). Застарілі рядки Moxie прибираються при синхронізації; старі рядки концентрації більше не показують Moxie від покинутих професій.
- **Після оновлення:** `/reload`, потім `/conc refresh` (або один раз відкрийте головне вікно).



## [3.9.27] — 2026-06-25



### English

- **Bugfix — Moxie** — Current character Moxie is tracked only for **active** professions (via `GetProfessions`), not abandoned ones that still hold a currency balance in the game.
- **Bugfix — Moxie** — Background sync no longer polls Moxie currencies from old DB rows for unlearned professions.
- **Bugfix — Moxie** — Stale Moxie is cleared from concentration rows and Moxie-only rows when a profession was abandoned (`PurgeAbandonedProfessionMoxieForCurrentPlayer`).



### Українська

- **Виправлення — Moxie** — Moxie поточного персонажа відстежується лише для **активних** професій (`GetProfessions`), а не для покинутих, де в грі ще залишився баланс валюти.
- **Виправлення — Moxie** — Фонова синхронізація більше не опитує валюти Moxie зі старих записів БД для невивчених професій.
- **Виправлення — Moxie** — Застарілий Moxie прибирається з рядків концентрації та рядків лише з Moxie після відмови від професії (`PurgeAbandonedProfessionMoxieForCurrentPlayer`).



## [3.9.26] — 2026-06-19



### English

- **Bugfix** — Saved profession and expansion filters are sanitized on login so stale values do not hide rows before the window is opened.
- **Bugfix** — Stop-tracking and clear-ignored actions refresh filters and the table via `AfterConcentrationDataChanged`.
- **UI** — Shared `ApplyMainWindowVisualSettings()` applies scale and transparency when opening the window, changing language, or resetting settings.
- **Locales** — Time-to-full strings in the table use localized hour/minute/second labels via `LOr()`.
- **TOC** — Interface 120007, 120005 (Midnight + prior 12.0.x build).



### Українська

- **Виправлення** — Збережені фільтри професії та доповнення перевіряються при вході в гру, щоб застарілі значення не ховали рядки до відкриття вікна.
- **Виправлення** — Дії «припинити відстеження» та «очистити ігнор» оновлюють фільтри та таблицю через `AfterConcentrationDataChanged`.
- **UI** — Спільна функція `ApplyMainWindowVisualSettings()` застосовує масштаб і прозорість при відкритті вікна, зміні мови або скиданні налаштувань.
- **Локалізація** — Рядки «час до повного» у таблиці використовують локалізовані позначки год/хв/с через `LOr()`.
- **TOC** — Interface 120007, 120005 (Midnight + попередній білд 12.0.x).



## [3.9.25] — 2026-06-19



### English

- **TOC** — Interface updated to 120007.



### Українська

- **TOC** — Оновлено Interface до 120007.



## [3.9.24] — 2026-06-19



### English

- **Bugfix** — Fixed «attempt to call a nil value» when opening the main window (`SanitizeSelectedExpansionFilter` is now defined before `InitializeExpansionDropdown`).



### Українська

- **Виправлення** — Виправлено «attempt to call a nil value» при відкритті головного вікна (`SanitizeSelectedExpansionFilter` тепер оголошено перед `InitializeExpansionDropdown`).



## [3.9.23] — 2026-06-19



### English

- **Bugfix** — Deleting a table row now refreshes profession/expansion filters and the list (via `AfterConcentrationDataChanged`), so an empty filter no longer hides all rows.
- **Bugfix** — Invalid saved expansion filter values reset to «All expansions» when no longer in the dropdown list.
- **Bugfix** — Profession cache refreshes when switching profession skill lines in the craft window (`TRADE_SKILL_DATA_SOURCE_CHANGED`).
- **UI** — Main window transparency from settings is reapplied each time the window is opened.
- **UI** — Clearing the ignored-professions list refreshes the main table immediately.



### Українська

- **Виправлення** — Після видалення рядка таблиці оновлюються фільтри професії/доповнення та список (через `AfterConcentrationDataChanged`), тому порожній фільтр більше не ховає всі рядки.
- **Виправлення** — Некоректне збережене значення фільтра доповнення скидається на «Усі доповнення», якщо його більше немає у списку.
- **Виправлення** — Кеш професій оновлюється при перемиканні лінії навичок у вікні крафту (`TRADE_SKILL_DATA_SOURCE_CHANGED`).
- **UI** — Прозорість головного вікна з налаштувань застосовується щоразу при відкритті вікна.
- **UI** — Очищення списку ігнорованих професій одразу оновлює головну таблицю.



## [3.9.22] — 2026-06-14



### English

- **Bugfix** — Profession filter resets to «All Professions» when the selected profession no longer exists in saved data (e.g. after deleting all rows or changing the expansion filter).
- **Bugfix** — Profession cache refreshes when opening the profession window so Moxie tracking stays accurate after learning or switching professions.
- **Bugfix** — Transparency slider in settings uses the correct default (80%) when reopening after a language change.
- **UI** — Main window table height syncs when reopening the window.
- **Locales** — Forecast panel (target input placeholder and calculate button) updates when switching language.
- **Refactor** — Shared `FormatDurationHoursMinutes()` for target-forecast time strings.



### Українська

- **Виправлення** — Фільтр професії скидається на «Усі професії», якщо обрана професія більше не є в збережених даних (наприклад, після видалення рядків або зміни фільтра доповнення).
- **Виправлення** — Кеш професій оновлюється при відкритті вікна професії — відстеження Moxie коректне після вивчення або зміни професій.
- **Виправлення** — Слайдер прозорості в налаштуваннях показує правильне значення за замовчуванням (80%) після зміни мови.
- **UI** — Висота таблиці синхронізується при повторному відкритті головного вікна.
- **Локалізація** — Панель прогнозу (підказка цілі та кнопка розрахунку) оновлюється при зміні мови.
- **Рефакторинг** — Спільна функція `FormatDurationHoursMinutes()` для рядків прогнозу до цілі.



## [3.9.21] — 2026-06-08



### English

- **Bugfix** — Changing language no longer resets the profession filter dropdown to «Select Profession» when «All Professions» or a specific profession is selected.
- **Bugfix** — Expansion filter dropdown refreshes its label when opening the main window or switching language.
- **UI** — Main window content area resizes live while dragging the resize handle (`OnSizeChanged` + shared height helper).
- **Locales** — English fallbacks via `LOr()` helper instead of hardcoded Ukrainian strings in the main window, settings, and confirm dialogs.
- **Refactor** — Single `GetProfessionInfo` call per slot when resolving profession expansion.



### Українська

- **Виправлення** — Зміна мови більше не скидає фільтр професії на «Виберіть професію», якщо обрано «Усі професії» або конкретну професію.
- **Виправлення** — Випадаючий список доповнень оновлює підпис при відкритті головного вікна або зміні мови.
- **UI** — Область таблиці змінює висоту в реальному часі під час перетягування ручки зміни розміру (`OnSizeChanged` + спільний хелпер).
- **Локалізація** — Англійські резервні рядки через `LOr()` замість захардкодженої української в головному вікні, налаштуваннях і діалогах підтвердження.
- **Рефакторинг** — Один виклик `GetProfessionInfo` на слот при визначенні доповнення професії.



## [3.9.20] — 2026-06-02



### English

- **UI — compact header** — Title moved from centered to top-left with a slightly smaller font; close button tucked closer to the corner.
- **UI — filters row** — Expansion, profession, and sort controls sit directly under the title (was ~48 px lower); gaps between controls reduced.
- **UI — controls size** — Expansion dropdown 120 px, profession dropdown 140 px, sort button height 22 px (was 130 / 150 / 25).
- **UI — table area** — Scroll frame starts 56 px from the top instead of 120 px; the profession list gains ~64 px of vertical space.



### Українська

- **UI — компактний заголовок** — Заголовок перенесено з центру вліво зверху, шрифт трохи менший; кнопку закриття зсунуто ближче до кута.
- **UI — ряд фільтрів** — Доповнення, професія та сортування одразу під заголовком (раніше на ~48 px нижче); зменшено проміжки між елементами.
- **UI — розмір елементів** — Випадаючий список доповнень 120 px, професії 140 px, висота кнопки сортування 22 px (було 130 / 150 / 25).
- **UI — область таблиці** — Прокрутка починається на 56 px від верху замість 120 px; список професій отримує ~64 px додаткової висоти.



## [3.9.19] — 2026-06-02



### English

- **Locales** — Translated column visibility settings (`section_columns`, `col_keep_one_visible`) and the Moxie column header for de, es, fr, it, pl, pt, ru, zhCN, zhTW, and ko (previously fell back to English).
- **UI** — Table header and settings fallbacks now use English instead of Ukrainian when a locale key is missing.
- **Robustness** — LibDataBroker object is registered only once; floating and minimap buttons are not recreated if they already exist.
- **Bugfix** — Profession expansion detection stops scanning empty profession slots instead of iterating fixed indices blindly.



### Українська

- **Локалізація** — Перекладено налаштування видимості колонок (`section_columns`, `col_keep_one_visible`) та заголовок колонки Moxie для de, es, fr, it, pl, pt, ru, zhCN, zhTW та ko (раніше показувалась англійська).
- **UI** — Резервні рядки заголовків таблиці та налаштувань тепер англійською, а не українською, якщо ключ локалізації відсутній.
- **Надійність** — Об'єкт LibDataBroker реєструється лише один раз; плаваюча кнопка та кнопка міні-карти не створюються повторно, якщо вже існують.
- **Виправлення** — Визначення доповнення професії припиняє сканування на порожніх слотах професій замість сліпого перебору фіксованих індексів.



## [3.9.18] — 2026-05-30

Підсумок оновлень **3.9.11 → 3.9.18** (один день розробки).

### English

- **Settings — table columns** — Show or hide each column (Character, Profession, Moxie, Concentration, Time to full, Restores at). At least one column must stay visible.
- **Settings & main window — expansion** — Filter the list by expansion (All, Midnight, Khaz Algar, …) via dropdown in settings and on the main window.
- **UI** — Moxie in its own column before Concentration; profession icons from the correct skill line / Moxie currency.
- **UI** — The logged-in character's rows always appear at the top; column sorting applies within your character and among others.
- **Notifications** — Alert at 600 Moxie without opening the profession window (background sync every 8s, currency events, login).
- **Bugfix** — No longer creates rows for every Artisan's Moxie currency at 0 for professions you do not have (only learned professions or Moxie > 0).
- **Bugfix** — No duplicate Moxie-only rows when a concentration row already exists for the same profession.
- **Bugfix** — Expansion dropdown no longer causes «attempt to call a nil value» when opening the window or changing the filter.



### Українська

- **Налаштування — колонки таблиці** — Увімкнення/вимкнення колонок (Персонаж, Професія, Moxie, Концентрація, Час до повного, Відновиться о). Має залишатись видимою хоча б одна колонка.
- **Налаштування та головне вікно — доповнення** — Фільтр списку за доповненням (Усі, Midnight, Khaz Algar, …) у налаштуваннях і в головному вікні.
- **UI** — Moxie в окремій колонці перед «Концентрація»; коректні іконки професій (skill line / валюта Moxie).
- **UI** — Рядки залогіненого персонажа завжди зверху; сортування по колонках — спочатку ваші професії, потім інші.
- **Сповіщення** — Сповіщення при 600 Moxie без відкриття вікна професії (фонова синхронізація кожні 8 с, події валюти, вхід у світ).
- **Виправлення** — Більше не створюються рядки для всіх 11 валют Moxie з нулем, якщо професії немає (лише ваші професії або Moxie > 0).
- **Виправлення** — Немає дублікатів рядків лише з Moxie, якщо вже є рядок з концентрацією для тієї ж професії.
- **Виправлення** — Випадаючий список доповнень більше не викликає «attempt to call a nil value» при відкритті вікна або зміні фільтра.



### Versions (3.9.11 – 3.9.18)


| Version | Summary                                  |
| ------- | ---------------------------------------- |
| 3.9.18  | Column visibility in settings            |
| 3.9.17  | Expansion dropdown selection fix         |
| 3.9.16  | Moxie rows only for real professions     |
| 3.9.15  | Expansion dropdown on window open        |
| 3.9.14  | Moxie 600 notifications without craft UI |
| 3.9.13  | Current character pinned to top          |
| 3.9.12  | Expansion filter (Midnight / Khaz Algar) |
| 3.9.11  | Moxie column; duplicate row cleanup      |




## [3.9.11] — 2026-05-29



### English

- **UI** — Moxie moved to its own column before Concentration (no longer under the profession name).
- **Bugfix** — Duplicate Moxie-only rows for the same profession are removed when a concentration row already exists; Moxie sync updates the existing row instead.



### Українська

- **UI** — Moxie винесено в окрему колонку перед «Концентрація» (більше не під назвою професії).
- **Виправлення** — Прибрано дублікати рядків лише з Moxie, якщо вже є рядок з концентрацією для тієї ж професії; синхронізація оновлює існуючий запис.



## [3.9.10] — 2026-05-29



### English

- **UI** — The floating **Conc. Tracker** button shows a tooltip with the current character's concentration and Moxie per tracked profession (sorted by name).



### Українська

- **UI** — Плаваюча кнопка **Conc. Tracker** показує тултіп з концентрацією та Moxie поточного персонажа по кожній відстежуваній професії (за назвою).



## [3.9.9] — 2026-05-29



### English

- **UI** — Profession row icons use `C_TradeSkillUI.GetProfessionInfoBySkillLineID`, Moxie currency mapping, or currency icon instead of always falling back to the Alchemy icon.



### Українська

- **UI** — Іконки професій у таблиці: `GetProfessionInfoBySkillLineID`, прив’язка до валюти Moxie або іконка валюти; більше не підставляється завжди алхімія.



## [3.9.8] — 2026-05-29



### English

- **Bugfix** — `EnsureMoxieNotifiedTable` / `MoxieNotifySettingsKey` are defined before `UpsertMoxieOnlyRow` (fixes line 467 «attempt to call a nil value» when syncing Moxie).



### Українська

- **Виправлення** — `EnsureMoxieNotifiedTable` та `MoxieNotifySettingsKey` оголошені до `UpsertMoxieOnlyRow` (усуває помилку на рядку 467 «attempt to call a nil value» при синхронізації Moxie).



## [3.9.7] — 2026-05-29



### English

- **Moxie** — When «Show Moxie in profession list» is enabled, professions that have Artisan's Moxie but no concentration appear in the main window (concentration columns show «—»). Rows are created when you open the profession, on `/conc` refresh, when entering the world, and when Moxie currency updates.
- **Settings** — Turning Moxie display on scans the current character's Moxie currencies so existing balances show up without reopening each profession.



### Українська

- **Moxie** — Якщо увімкнено «Показувати Moxie у списку професій», у головному вікні з’являються професії з Artisan's Moxie без концентрації (у стовпцях концентрації — «—»). Рядки створюються при відкритті професії, оновленні `/conc`, вході в світ і при зміні валюти Moxie.
- **Налаштування** — Увімкнення показу Moxie сканує валюти Moxie поточного персонажа, щоб баланси з’явились без повторного відкриття кожної професії.



## [3.9.6] — 2026-05-29



### English

- **Bugfix** — Settings panel no longer appears empty after `/reload` or when opening `/conclanguage`.
- **Settings UI** — Scroll child gets a **default height (820px)** until layout is measured, so options are visible immediately; content height is then updated from the bottom of the ignored-professions section.
- **Settings UI** — Scroll viewport is anchored to the **window** (fixed top/bottom insets for header and Reset/Close footer), not to the language dropdown.
- **Settings UI** — Incomplete or legacy settings frames are detected (`LanguageSettingsWindowIsComplete`) and destroyed; the root frame is created as `**ConcentrationTrackerSettingsRoot`** so a stale global `LanguageSettingsWindow` from an older build cannot block recreation.
- **Settings UI** — Scroll range is refreshed on show and shortly after open (`OnShow` + deferred timer) so the mouse wheel works on first open.



### Українська

- **Виправлення** — Вікно налаштувань більше не порожнє після `/reload` або при відкритті `/conclanguage`.
- **Налаштування** — Контент прокрутки одразу має **початкову висоту 820 px**, доки UI не виміряє розкладку; потім висота оновлюється від низу секції ігнорованих професій.
- **Налаштування** — Область прокрутки прив’язана до **вікна** (фіксовані відступи зверху для заголовка/мови та знизу для «Скинути»/«Закрити»), а не до випадаючого списку мови.
- **Налаштування** — Неповні або застарілі фрейми виявляються (`LanguageSettingsWindowIsComplete`) і знищуються; кореневий фрейм — `**ConcentrationTrackerSettingsRoot`**, щоб старий глобальний `LanguageSettingsWindow` не блокував створення нового UI.
- **Налаштування** — Діапазон прокрутки оновлюється при показі вікна та коротко після відкриття (`OnShow` + відкладений таймер), щоб коліщатко миші працювало з першого разу.



## [3.9.5] — 2026-05-29



### English

- **Bugfix** — `GetMoxieCurrencyIDForSkillLine` and related Moxie helpers are defined before `RecordConcentration()` (fixes line 376 «attempt to call a nil value» and empty settings after reload).



### Українська

- **Виправлення** — функції Moxie оголошені до `RecordConcentration()` (усуває помилку на рядку 376 «attempt to call a nil value» і порожні налаштування після `/reload`).



## [3.9.4] — 2026-05-29



### English

- **Settings** — Scrollable settings panel: header (title, language) and footer (Reset/Close) stay fixed; all options scroll with mouse wheel.



### Українська

- **Налаштування** — Прокручувана панель: заголовок (назва, мова) і кнопки внизу зафіксовані; усі опції прокручуються коліщатком миші.



## [3.9.3] — 2026-05-29



### English

- **Moxie UI** — Artisan's Moxie balance shown under each profession in the main window (current character uses live currency data).
- **Settings** — «Show Moxie in profession list» and «Notify at 600 Moxie» toggles; window transparency moved to the Display section so it no longer overlaps the ignored-professions controls.



### Українська

- **Moxie в інтерфейсі** — баланс Artisan's Moxie під назвою професії в головному вікні (для поточного персонажа — актуальні дані з API валют).
- **Налаштування** — перемикачі «Показувати Moxie у списку професій» та «Сповіщати при 600 Moxie»; слайдер прозорості перенесено в блок «Відображення», щоб не перекривати секцію ігнорованих професій.



## [3.9.2] — 2026-05-29



### English

- **Moxie** — Notifies when the current character reaches **600** Artisan's Moxie for a profession (Midnight currency IDs 3256–3266). Uses the same notification settings as concentration (raid banner, optional chat, sound). Tracks via profession rows when available, or currency events alone; does not re-alert after `/reload` while still at or above 600 until balance drops below the threshold.



### Українська

- **Moxie** — Сповіщення, коли на поточному персонажі набирається **600** Artisan's Moxie для професії (валюти Midnight, ID 3256–3266). Ті самі налаштування, що для концентрації (банер рейду, чат, звук). Працює через збережені рядки професій або лише події валюти; після `/reload` не повторює сповіщення, поки баланс не впаде нижче порогу.



## [3.9.1] — 2026-05-27



### English

- **Bugfix** — `ApplyCurrencyUpdateToRow` no longer uses `tonumber(maxQuantity) or fallback`: in Lua, `0` is truthy for `or`, so a zero `maxQuantity` from the API could produce an invalid cap; caps now require `>= 1` before trusting the API value.
- **Slash** — `/conc` subcommands match the **first** word only (`/conc refresh`, `/conc r …`, `/conc toggle …`), so extra text after the keyword does not fall through to opening the window.



### Українська

- **Виправлення** — `ApplyCurrencyUpdateToRow` більше не використовує `tonumber(maxQuantity) or запасний`: у Lua `0 or x` залишає `0`, тож нульовий `maxQuantity` з API міг дати некоректну межу; значення з API приймається лише якщо `>= 1`.
- **Слеш** — підкоманди `/conc` зіставляються з **першим** словом (`/conc refresh`, `/conc r …`, `/conc toggle …`), зайвий текст після ключового слова не відкриває вікно замість дії.



## [3.9.0] — 2026-05-21



### English

- **Refactor** — Single `GetDefaultSettings()` source for first load and factory reset; `EnsureMinimapSettings()` guards incomplete saved minimap tables.
- **Sync** — Shared `ApplyCurrencyUpdateToRow()` and `AfterConcentrationDataChanged()` unify currency API updates and UI refresh (less duplicated code in record/sync/refresh paths).
- **Notifications** — Rows store `notifiedAtFull` in SavedVariables so “concentration full” alerts no longer re-fire after `/reload` while still at cap; flag clears when concentration drops below max.
- **Record** — `RecordConcentration()` uses `GetEffectiveMaxQuantity()` instead of a hardcoded 1000 fallback.
- **UI** — Settings stay open when changing language; profession/language dropdown frames use addon-prefixed global names to avoid collisions with other addons.
- **TOC** — Added `OptionalDeps: LibDataBroker-1.1` for more reliable LDB broker registration order.



### Українська

- **Рефакторинг** — Єдине джерело `GetDefaultSettings()` для першого завантаження та скидання; `EnsureMinimapSettings()` захищає від неповних збережених таблиць міні-карти.
- **Синхронізація** — Спільні `ApplyCurrencyUpdateToRow()` та `AfterConcentrationDataChanged()` об’єднують оновлення з API валют і оновлення UI (менше дубльованого коду).
- **Сповіщення** — У записах зберігається `notifiedAtFull`, тож «концентрація повна» більше не з’являється після `/reload`, поки ліміт не витрачено; прапорець скидається при падінні нижче максимуму.
- **Запис** — `RecordConcentration()` використовує `GetEffectiveMaxQuantity()` замість жорстко заданих 1000.
- **UI** — Вікно налаштувань не закривається при зміні мови; глобальні імена dropdown-фреймів мають префікс аддона.
- **TOC** — Додано `OptionalDeps: LibDataBroker-1.1` для надійнішого порядку завантаження LDB.



## [3.8.9] — 2026-05-14



### English

- **Robustness** — `UpdateConcentrationTimes` returns early if `ConcentrationTrackerSettings` is missing, avoiding rare errors when the main window is shown before settings are ready or after corrupted saves.
- **LDB** — `LDBConcentrationSummary` returns `0 / 0` when settings are missing so broker tooltips do not run ignore-list logic without a valid settings table.
- **Minimap** — `UpdatePosition` no longer assumes `minimap` exists; avoids a nil index if saved settings are incomplete.



### Українська

- **Стійкість** — `UpdateConcentrationTimes` завершується одразу, якщо немає `ConcentrationTrackerSettings`, щоб уникнути рідкісних помилок, коли вікно ще відкрилося до ініціалізації налаштувань або після пошкоджених SavedVariables.
- **LDB** — `LDBConcentrationSummary` повертає `0 / 0`, якщо немає налаштувань, щоб підказка брокера не обходила список ігнору без валідної таблиці.
- **Міні-карта** — `UpdatePosition` перевіряє наявність `minimap`, щоб не звертатися до полів відсутньої таблиці.



## [3.8.8] — 2026-05-07



### English

- **Bugfix** — `CURRENCY_DISPLAY_UPDATE` now reads the currency ID from the event’s **first** argument (`arg1`). The handler was defined as `OnEvent(self, event, arg1, ...)`, so using `tonumber((...))` parsed the **quantity** (second payload field) as an ID; live currency sync could update the wrong row or no row.
- **Refresh** — Main window **Refresh** and new slash `**/conc refresh`** / `**/conc r`** call `RefreshCurrentCharacterConcentrationFromAPI()` so quantities update **without** opening the profession UI; if the profession window is open, `RecordConcentration()` still runs as before. Chat confirmation uses `msg_refresh_done` when using the slash command.
- **Settings** — Version string from the TOC is shown in the settings panel (`version_label`). Tooltips (LDB, minimap) include `slash_refresh`.
- **Locales** — Updated `refresh_tooltip` (en/uk); new keys fall back to English for other languages via existing merge.



### Українська

- **Виправлення** — `CURRENCY_DISPLAY_UPDATE`: ID валюти береться з **першого** аргументу події (`arg1`). Раніше `tonumber((...)`) використовував другий параметр (кількість), через що синхронізація могла звертатися не до того запису.
- **Оновлення** — Кнопка **Оновити** та команди `**/conc refresh`** / `**/conc r`** підтягують дані через API для поточного персонажа без обов’язкового відкриття професії; з відкритим вікном професії як і раніше викликається `RecordConcentration()`. У чат виводиться підтвердження для slash-команди.
- **Налаштування** — У панелі налаштувань показується версія з TOC; у підказках LDB та міні-карти додано рядок `slash_refresh`.
- **Локалізація** — Оновлено `refresh_tooltip` (en/uk); інші мови підтягують нові ключі з англійської.



## [3.8.7] — 2026-05-02



### English

- **Bugfix** — `CURRENCY_DISPLAY_UPDATE` handler now parses the first event argument with `tonumber((...))` instead of `tonumber(select(1, ...))`. In Lua, `select(1, ...)` returns all varargs, so the second value was wrongly passed as `tonumber`’s base and triggered “base out of range”.
- **Bugfix** — Row and settings tooltips that used `GameTooltip:SetText(text, nil, nil, nil, true)` switched to a single-argument `SetText(text)` so optional color/alpha/wrap arguments match the retail API (fixes “bad argument #5 to 'SetText'” on hover for delete/stop-tracking, minimap hide, and clear-ignore controls).



### Українська

- **Виправлення** — обробник `CURRENCY_DISPLAY_UPDATE` бере перший аргумент події через `tonumber((...))` замість `tonumber(select(1, ...))`. У Lua `select(1, ...)` повертає всі зайві аргументи, тож другий потрапляв у `base` для `tonumber` і викликав помилку діапазону основи.
- **Виправлення** — підказки рядків та налаштувань з `GameTooltip:SetText(..., nil, nil, nil, true)` замінено на виклик лише з текстом, щоб узгодитися з API retail (прибирає помилку `SetText` при наведенні на видалення/зупинку відстеження, приховування міні-карти та очищення ігнору).



## [3.8.6] — 2026-05-02



### English

- **Live sync** — Each stored row now keeps the profession **concentration currency ID**. When the game fires `CURRENCY_DISPLAY_UPDATE`, the addon updates matching rows for the **current character only**, so passive regeneration stays accurate without reopening the profession window (after at least one successful record on this addon version).
- **Entering world** — Debounced refresh (~0.75s) on `PLAYER_ENTERING_WORLD` pulls currency from the API for the current character’s tracked lines (fills missing `currencyID` when the API allows).
- **Slash** — `/conc toggle` or `/conc t` opens or closes the main window; `/conc close` / `/conc hide` closes only. Plain `/conc` still opens the window (same as before).
- **Tooltips** — LDB and minimap tooltips show the new slash line when localized (`slash_toggle`); other locales fall back to English for that key.



### Українська

- **Синхронізація** — У кожному записі зберігається **ID валюти концентрації**. Подія `CURRENCY_DISPLAY_UPDATE` оновлює відповідні рядки лише для **поточного персонажа**, щоб пасивний реген відображався без повторного відкриття вікна професії (після хоча б одного успішного збору на цій версії).
- **Вхід у світ** — Відкладене оновлення (~0.75 с) при `PLAYER_ENTERING_WORLD` підтягує дані валюти для відстежуваних ліній поточного персонажа (доповнює `currencyID`, якщо API дозволяє).
- **Слеш** — `/conc toggle` або `/conc t` — відкрити/закрити вікно; `/conc close` / `/conc hide` — лише закрити. `/conc` без аргументів як раніше відкриває вікно.
- **Підказки** — Другий рядок у LDB та на міні-карті з новою підказкою для команд (`slash_toggle`).



## [3.8.5] — 2026-04-24



### English

- **Main window** — Each time you open the window (`/conc`), strings are refreshed from the current language (title, buttons, sort direction, profession filter label, forecast field and button). Avoids stale text if the language was changed while the window was hidden.
- **Static popups** — Delete-entry confirmation dialog text is re-registered when updating language texts (same pattern as stop-tracking / clear-ignore dialogs).
- **Forecast** — Hour/minute labels in target time strings use safe fallbacks if locale keys are missing; `time_to_target` format string is guarded when `L` is unset.
- **Locales** — Native `settings_window_title`, `hide_minimap`, and `hide_minimap_tooltip` for **de, es, fr, it, pl, pt, ru, zhCN, zhTW, ko** (previously only explicit **en**/**uk**; others relied on English merge).



### Українська

- **Головне вікно** — При кожному відкритті (`/conc`) підписи беруться з поточної мови (заголовок, кнопки, напрям сортування, підпис фільтра професій, поле та кнопка прогнозу), щоб не залишатися старою мовою після зміни мови, поки вікно було сховане.
- **Діалоги** — Текст підтвердження видалення рядка оновлюється разом з іншими StaticPopup при зміні мови в налаштуваннях.
- **Прогноз** — Підписи год/хв для часу до цілі з запасними значеннями; безпечний доступ до рядка `time_to_target`.
- **Локалізація** — Рідні рядки `settings_window_title`, `hide_minimap`, `hide_minimap_tooltip` для **de, es, fr, it, pl, pt, ru, zhCN, zhTW, ko**.



## [3.8.4] — 2026-04-17



### English

- **Performance** — ignored profession skill lines are indexed in a small in-memory set rebuilt on load and when the ignore list changes; lookups stay O(1) instead of scanning the saved array on every UI tick and notification pass (saved variables unchanged).
- **Load** — `ADDON_LOADED` compares against the addon folder name from the TOC (`addonName`) instead of a hardcoded string.
- **Code** — removed redundant second `sortOrder` / `sortAscending` locals in `UpdateConcentrationTimes`; tightened `GetEntryIdentity` key checks before string operations.



### Українська

- **Швидкодія** — ігноровані лінії навичок індексуються в невеликій множині в пам’яті (перебудова при завантаженні та змінах списку); перевірки O(1) замість лінійного проходу збереженого масиву на кожному тіку UI і в нотифікаціях (формат SavedVariables той самий).
- **Завантаження** — `ADDON_LOADED` порівнює з ім’ям папки аддона з TOC (`addonName`), а не з захардкодженим рядком.
- **Код** — прибрано зайве повторне оголошення `sortOrder` / `sortAscending` у `UpdateConcentrationTimes`; безпечніші перевірки ключа в `GetEntryIdentity`.



## [3.8.3] — 2026-04-11



### English

- **Craft updates** — listen for `TRADE_SKILL_ITEM_CRAFTED_RESULT` so `RecordConcentration()` runs after you craft an item; concentration usage updates without closing and reopening the profession window.



### Українська

- **Оновлення після крафту** — підписка на `TRADE_SKILL_ITEM_CRAFTED_RESULT`, щоб після створення предмета викликався `RecordConcentration()`; використання концентрації оновлюється без закриття та повторного відкриття вікна професії.



## [3.8.2] — 2026-04-07



### English

- **Trade skill events** — `RecordConcentration` runs only on `TRADE_SKILL_SHOW` and `TRADE_SKILL_DATA_SOURCE_CHANGED`, not on `TRADE_SKILL_CLOSE`, so the profession API is not queried after the window is torn down (fewer spurious errors and chat messages).
- **Target forecast** — manual “Forecast” (`CalculateTimeToTarget`) skips ignored profession skill lines, matching the main table and summary logic.
- **Profession filter** — dropdown list ignores empty or missing profession names when building unique entries.



### Українська

- **Події професії** — `RecordConcentration` викликається лише на `TRADE_SKILL_SHOW` та `TRADE_SKILL_DATA_SOURCE_CHANGED`, не на `TRADE_SKILL_CLOSE`, щоб не звертатися до API після закриття вікна (менше помилкових повідомлень у чаті).
- **Прогноз до цілі** — ручний «Прогноз» ігнорує ті самі лінії професій, що й таблиця (список ігнору).
- **Фільтр професій** — у випадаючому списку не додаються порожні або відсутні назви професій.



## [3.8.1] — 2026-04-01



### English

- **Bugfix** — `GetRestorationTimes` could throw `attempt to compare nil with number` when saved rows had no valid `maxQuantity` (or very old installs without `MAX_CONCENTRATION`). All caps now go through `GetEffectiveMaxQuantity()` (`tonumber` + minimum 1, then fallback 1000).
- **Robustness** — `lastUpdate` / `lastKnownQuantity` are sanitized (`tonumber`, clamp `lastUpdate` to not be in the future, non-negative elapsed time) so ticker/notifications do not error on bad data.



### Українська

- **Виправлення** — `GetRestorationTimes` міг падати з `attempt to compare nil with number`, якщо у збережених рядках не було коректного `maxQuantity`. Усі межі тепер через `GetEffectiveMaxQuantity()` (`tonumber`, мінімум 1, потім запас 1000).
- **Стійкість** — `lastUpdate` та кількість санітизовані (щоб тікер/сповіщення не ламалися на некоректних даних).



## [3.8] — 2026-04-01



### English

- **MAX_CONCENTRATION** — explicit fallback constant (1000) when `maxQuantity` is missing from saved/API data, avoiding nil math.
- **Notifications** — profession fallback in notification text uses localized `L["profession"]` instead of a hardcoded Ukrainian string.
- **Minimap** — `minimap.hide` is now wired: checkbox in Settings (“Hide minimap icon”), `ApplyMinimapButtonVisibility()` on load and on toggle; migration sets `hide` if absent.
- **UX** — main window and settings window registered with `UISpecialFrames` so **Escape** closes them like standard UI.
- **Locales** — new strings `hide_minimap`, `hide_minimap_tooltip` (English + Ukrainian; other locales fall back to English via existing merge).
- **UpdateLanguageTexts** — always reloads `L` from current language so settings-only updates get correct strings.
- **Reset to defaults** — minimap checkbox and visibility stay in sync after a full settings reset.



### Українська

- **MAX_CONCENTRATION** — явна константа-запасний варіант (1000), якщо немає `maxQuantity`, щоб уникнути некоректної математики.
- **Нотифікації** — резервна назва професії в тексті сповіщення через локалізований `L["profession"]`, а не захардкоджений рядок.
- **Міні-карта** — налаштування `minimap.hide` підключено: чекбокс у налаштуваннях, застосування при завантаженні та перемиканні; міграція для `hide`.
- **UX** — головне вікно та вікно налаштувань у `UISpecialFrames`, закриття клавішею **Esc**.
- **Локалізація** — нові рядки `hide_minimap`, `hide_minimap_tooltip` (uk + en; інші мови — fallback з англійської).
- **UpdateLanguageTexts** — завжди перезавантажує `L` за поточною мовою.
- **Скидання налаштувань** — чекбокс міні-карти та видимість іконки узгоджені після повного скидання.



## [3.7] — 2026-03-20



### English (settings window layout)

- **Settings panel** — transparency slider anchored from the bottom with reserved footer for **Reset / Close**; title **settings_window_title**; frame height **800px**; `SetSize` reapplied on each open so old saved frames resize.
- **Ignored profession variants** — minus button on each row stops auto-tracking that **skill line** (e.g. Dragon Isles vs base profession); **Clear ignore list** in settings; tooltips for minus vs delete (X). **Locales** — all nine new strings translated for **uk, de, es, fr, it, pl, pt, ru, zhCN, zhTW, ko** (not only `en` fallback).



### English

- **Locales** — strings moved to `Locales.lua`; missing keys fall back to English; v3.7 UI strings fully translated for **uk, de, es, fr, it, pl, pt, ru, zhCN, zhTW, ko** (not only English fallback)
- **Storage keys** — entries use a safe separator + migration from old `name_realm_id` keys; `entryChar` / `entryRealm` / `entrySkillLine` stored on each row
- **Floating button** — position saved after drag (`buttonPosition`)
- **Restore rate** — slider in settings (default 10/hour); all forecasts and notifications use it
- **Chat spam** — optional “Print updates to chat” (default off)
- **Notifications** — separate toggles: raid banner, chat line, sound
- **Sort** — column “Time to full” is sortable
- **Layout** — column width recalculation only when data/layout signature changes (less work each tick)
- **LDB & minimap tooltip** — shows count not at cap + slash hint
- **Fonts** — `GetLocaleFont()` picks paths for koKR / zhCN / zhTW
- **Ticker** — notification ticker cancelled on logout; recreated on load
- **TOC** — Notes list `/conc` and `/conclanguage`



### Українська

- **Вікно налаштувань** — слайдер прозорості закріплено знизу з відступом від кнопок «Скинути / Закрити»; висота **800px**; заголовок «Налаштування Concentration Tracker».
- **Ігнор варіантів професії** — кнопка «мінус» у рядку вимикає автозбір для цієї лінії навичок; у налаштуваннях — очистити список ігнору; підказки для мінуса та хрестика (видалити рядок). **Локалізація** — усі 9 нових рядків перекладені для **uk, de, es, fr, it, pl, pt, ru, zhCN, zhTW, ko**.
- **Локалізація** — винесено в `Locales.lua`; відсутні ключі підтягуються з англійської; рядки інтерфейсу 3.7 перекладені для всіх підтримуваних мов
- **Ключі БД** — безпечний роздільник + міграція зі старого формату; на кожному записі зберігаються ім’я/сервер/skill line
- **Плаваюча кнопка** — позиція зберігається після перетягування
- **Швидкість відновлення** — слайдер у налаштуваннях (дефолт 10/год)
- **Чат** — опційні повідомлення про оновлення (за замовчуванням вимкнено)
- **Нотифікації** — окремо: банер рейду, чат, звук
- **Сортування** — стовпець часу до повного відновлення



### Removed (3.7 follow-up)

- **Export / Import** — removed (unreliable in-game); related strings dropped from locales.



## [3.6] — 2026-03-16

---



### English



#### Added

- **Localization** — 10 new languages: Deutsch, Español, Français, Italiano, Polski, Português, Русский, 简体中文, 繁體中文, 한국어
- **Localization** — added keys `hide_button`, `summary_total`, `toggle_button`, `addon_name`, `right_click`, `minimap_open` for all languages
- **Hide Button** — translation "Приховати головну кнопку" / "Hide main button" (Lorenzo)
- **Default language** — English instead of Ukrainian
- **Position saving** — settings window remembers its position between sessions



#### Fixed

- **hideFloatingButton** — setting now persists between reloads: default value, migration for existing users, load-time check (Lorenzo)
- **Reset dialog** — after reset `hideFloatingButton = false` and main button is shown (Lorenzo)
- **Language dropdown** — displays current language name instead of "Select Language" (Lorenzo)
- **Window height** — settings window height 460 → 480 px to fix slider label overlap with buttons (Lorenzo)
- **Window width** — auto-adjusts to fit table content
- **Column widths** — dynamic calculation based on text (headers and data)
- **Text overflow** — profession and date text no longer overflows when font size increases
- **Row height** — scales with font size
- **Alignment** — text in clipped cells, even display in columns and rows
- **Row highlight** — fixed width on hover



#### Changed

- **Row structure** — each column in separate frame-cell with `SetClipsChildren(true)`
- **Headers** — spacer for profession icon to align with data
- **Tooltip** — full profession name on row hover

---



### Українська



#### Додано

- **Локалізація** — додано 10 нових мов: Deutsch, Español, Français, Italiano, Polski, Português, Русский, 简体中文, 繁體中文, 한국어
- **Локалізація** — додано ключі `hide_button`, `summary_total`, `toggle_button`, `addon_name`, `right_click`, `minimap_open` для всіх мов
- **Hide Button** — переклад "Приховати головну кнопку" / "Hide main button" (Lorenzo)
- **Мова за замовчуванням** — англійська замість української
- **Збереження позиції** — вікно налаштувань зберігає своє місце розташування між сесіями



#### Виправлено

- **hideFloatingButton** — налаштування тепер зберігається між перезавантаженнями: дефолтне значення, міграція для існуючих користувачів, перевірка при завантаженні (Lorenzo)
- **Reset dialog** — після скидання налаштувань `hideFloatingButton = false` та головна кнопка показується (Lorenzo)
- **Language dropdown** — відображає назву поточної мови замість "Select Language" (Lorenzo)
- **Window height** — висота вікна налаштувань 460 → 480 px для уникнення накладання слайдера та кнопок (Lorenzo)
- **Ширина вікна** — автоматично підлаштовується під контент таблиці
- **Ширина стовпців** — динамічний розрахунок під текст (заголовки та дані)
- **Текст за межами** — при збільшенні шрифту текст професій та дат більше не виходить за межі
- **Висота рядків** — масштабується з розміром шрифту
- **Вирівнювання** — текст у клітинках з обрізанням, рівне відображення в стовпцях та рядках
- **Підсвітка рядка** — фіксована ширина при наведенні



#### Зміни

- **Структура рядків** — кожен стовпець у окремому фреймі-клітинці з `SetClipsChildren(true)`
- **Заголовки** — відступ під іконку професії для вирівнювання з даними
- **Тултіп** — при наведенні на рядок показується повна назва професії

