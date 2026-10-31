# Concentration Tracker

Addon for **World of Warcraft: The War Within / Midnight** that tracks **profession concentration** and **Artisan's Moxie** across all your characters.

---

## Short description (CurseForge / Wago, max 256 characters)

**English** (243 characters):

```
Tracks profession concentration and Midnight Artisan's Moxie across all characters. Shows restore timers, optional cap and 600 Moxie alerts, live currency sync, sort and filter. Twelve languages. /conc, /conclanguage.
```

**Українська** (248 символів):

```
Відстежує концентрацію професій і Artisan's Moxie (Midnight) на всіх персонажах. Таймери відновлення, сповіщення про повну концентрацію та 600 Moxie, синхронізація в реальному часі. 12 мов. /conc, /conclanguage.
```

---

## Full description

### English

**Concentration Tracker** helps crafters monitor **concentration** and **Artisan's Moxie** for every profession on every character, without opening the profession window each time.

Open the main list with **`/conc`**, refresh data with **`/conc refresh`**, and open settings (language, notifications, display) with **`/conclanguage`**.

#### What it tracks

- **Concentration** — current amount, maximum, time until full, and estimated restore date/time.
- **Artisan's Moxie (Midnight)** — balance per profession; optional listing of professions that have Moxie but no concentration.
- **All characters & realms** — data is stored per character, profession skill line, and realm.

Concentration updates when you open a profession, craft items, enter the world, or when the game fires currency events. Use **Refresh** or **`/conc refresh`** to pull the latest values from the API for the current character.

#### Features

- **Multi-character overview** — sort by character, profession, concentration, or time to full; filter by character, profession, or expansion; optionally hide rows already at full concentration; show or hide realm names.
- **Row shortcuts** — Right-click filters by character, Shift+Right-click by profession, Alt+Right-click by expansion, Ctrl+Right-click copies the row to chat.
- **Hide in combat** — optional setting to hide the main window when combat starts and restore it after (does not reopen if you closed the window yourself).
- **Soon to fill** — `/conc soon` lists rows that cap within 2 hours; footer/tooltips show the count; optional yellow row tint.
- **Search** — type in the toolbar or `/conc search` to filter by character, realm, or profession.
- **Idiot Alert** — reminds you when a weekly profession quest is finished but not turned in (`/conc weekly`; click the banner to list, Ctrl+click to copy).
- **Focus next / lowest** — `/conc focus` opens the window on the line closest to full; `/conc focuslow` on the lowest incomplete line.
- **Today / totals** — `/conc today` lists rows that fill before daily reset; `/conc totals` prints an account-wide snapshot.
- **Week / missing / Moxie cap** — `/conc week` lists rows that fill before weekly reset; `/conc missing` shows concentration still needed to cap; `/conc moxiecap` lists rows at 600 Moxie or above.
- **Spend / profession** — `/conc spend` lists rows ready to craft with; `/conc prof Alchemy` prints that profession on every character.
- **Below / character** — `/conc below` lists rows under 25% full; `/conc char Name` prints that character across professions.
- **Reach / expansion / sort** — `/conc reach 500` estimates time to an amount; `/conc exp Midnight` lists one expansion; `/conc sort time` sets the table sort.
- **Columns / rate** — `/conc col time` shows or hides a column; `/conc rate 12` sets how fast concentration is estimated to return.
- **Top / average** — `/conc top` lists the fullest rows; `/conc avg` prints the account fill percent. `/conc scale` and `/conc font` match the settings sliders.
- **Last to fill** — `/conc last` prints the line that caps last. `/conc alpha 80` sets window opacity.
- **Restoration forecast** — target concentration calculator in the main window.
- **Notifications** — optional alerts when concentration is full and when Moxie reaches **600** (raid warning, chat, sound).
- **Ignored profession variants** — stop tracking a specific expansion skill line (e.g. Dragon Isles vs Midnight) without deleting other data.
- **Live sync** — `CURRENCY_DISPLAY_UPDATE` and login refresh keep the current character accurate while offline regeneration is estimated from your restore-rate setting.
- **Minimap & LDB** — broker summary and minimap button (can be hidden in settings).
- **Interface** — adjustable transparency, font size, window scale; movable main and settings windows; scrollable settings panel.
- **Localization** — Ukrainian, English, Deutsch, Español, Français, Italiano, Polski, Português, Русский, 简体中文, 繁體中文, 한국어.

#### Commands

| Command | Action |
|--------|--------|
| `/conc` | Open main window |
| `/conc toggle` or `/conc t` | Open or close main window |
| `/conc refresh` or `/conc r` | Sync current character from API |
| `/conc status` or `/conc s` | Print this character's concentration and Moxie to chat |
| `/conc me` | Open window filtered to this character |
| `/conc next` or `/conc n` | Print which tracked line fills next |
| `/conc clear` | Reset expansion, profession, and character filters |
| `/conc moxie` or `/conc mx` | Print this character's Artisan's Moxie |
| `/conc lowest` or `/conc lo` | Print the lowest incomplete concentration line |
| `/conc stale` | List rows not synced in over 24 hours |
| `/conc chars` | List tracked characters |
| `/conc full` | List rows already at maximum concentration |
| `/conc soon` or `/conc 2h` | List rows that fill within 2 hours (`/conc soon 4` for 4 hours) |
| `/conc list` or `/conc visible` | Print currently visible table rows |
| `/conc combat` | Toggle hiding the window in combat |
| `/conc search` | Filter table by name (`/conc search` clears) |
| `/conc export` | Copy visible rows into the chat box |
| `/conc oldest` | Print the least recently synced row |
| `/conc ignored` | List ignored profession variants |
| `/conc notify` | Toggle cap / Moxie notifications |
| `/conc weekly` | List profession weeklies ready to turn in |
| `/conc focus` or `/conc jump` | Open the window on the next line to fill |
| `/conc hidefull` | Hide or show full concentration rows |
| `/conc percent` | Show or hide concentration percent |
| `/conc compact` | Toggle compact time format |
| `/conc today` or `/conc daily` | List rows that fill before daily reset |
| `/conc totals` or `/conc sum` | Account-wide concentration and Moxie totals |
| `/conc focuslow` or `/conc flo` | Open the window on the lowest concentration line |
| `/conc hidestale` | Hide or show stale rows |
| `/conc highlight` | Toggle soon-to-fill row highlight |
| `/conc week` or `/conc wreset` | List rows that fill before weekly reset |
| `/conc missing` or `/conc gap` | Concentration still needed to reach cap |
| `/conc moxiecap` or `/conc m600` | Rows at or above 600 Moxie (`/conc moxiecap 500`) |
| `/conc spend` or `/conc usable` | Rows ready to spend (default 100; `/conc spend 250`) |
| `/conc prof` or `/conc profession` | One profession across characters (`/conc prof Alchemy`) |
| `/conc hidemoxie` | Hide or show Moxie-only rows |
| `/conc lowlight` | Toggle low-concentration row highlight |
| `/conc below` or `/conc under` | Rows under a fill percent (default 25; `/conc below 50`) |
| `/conc char` or `/conc alt` | One character across professions (`/conc char Name`) |
| `/conc autoself` | Open the window filtered to this character |
| `/conc refreshopen` | Sync this character when the window opens |
| `/conc reach` or `/conc target` | Time until rows hit an amount (`/conc reach 500`) |
| `/conc exp` or `/conc expansion` | One expansion across characters (`/conc exp Midnight`) |
| `/conc sort` | Set or flip table sort (`/conc sort time`) |
| `/conc col` or `/conc column` | Show or hide a table column (`/conc col time`) |
| `/conc rate` | Show or set restore rate per hour (`/conc rate 12`) |
| `/conc chatlog` | Print concentration updates to chat |
| `/conc sound` | Play a sound with notifications |
| `/conc top` or `/conc best` | Highest concentration rows (default 5; `/conc top 10`) |
| `/conc avg` or `/conc average` | Average fill across tracked rows |
| `/conc scale` | Window scale (`/conc scale 100` or `/conc scale 1`) |
| `/conc font` | Font size (`/conc font 14`) |
| `/conc showmoxie` | Show or hide Moxie in the profession list |
| `/conc last` or `/conc eta` | The tracked line that fills last |
| `/conc alpha` or `/conc opacity` | Window opacity, 0–100 (`/conc alpha 80`) |
| `/conc markme` | Mark this character's rows |
| `/conc fullhl` | Tint rows that are already full |
| `/conc realm` | Show or hide realm names |
| `/conc copy` | Copy this character's status into the chat box |
| `/conc minimap` or `/conc mm` | Show or hide the minimap button |
| `/conc lock` | Lock or unlock the main window |
| `/conc settings` | Open settings |
| `/conc resetui` | Reset window position and size |
| `/conc version` or `/conc v` | Print addon version |
| `/conc help` or `/conc ?` | List slash commands |
| `/conc close` / `/conc hide` | Close main window |
| `/conclanguage` | Settings (language, notifications, display) |

#### Requirements

- **Retail** WoW (Midnight / The War Within profession APIs).
- Optional: **LibDataBroker-1.1** for broker display.

---

### Українська

**Concentration Tracker** — зручний огляд **концентрації** та **Artisan's Moxie** для всіх професій на всіх персонажах без постійного відкриття вікна професії.

Головне вікно — **`/conc`**, оновлення даних — **`/conc refresh`**, налаштування — **`/conclanguage`**.

#### Що відстежується

- **Концентрація** — поточне значення, максимум, час до повного відновлення, орієнтовна дата/час.
- **Artisan's Moxie (Midnight)** — баланс по професії; за бажанням — професії лише з Moxie без концентрації.
- **Усі персонажі та реалми** — окремі записи для кожної лінії навичок.

Дані оновлюються при відкритті професії, крафті, вході в світ і при подіях валют. Кнопка **Оновити** або **`/conc refresh`** підтягує актуальні значення з API для поточного персонажа.

#### Можливості

- **Огляд по персонажах** — сортування за персонажем, професією, концентрацією, часом; фільтр за персонажем, професією або доповненням; опція приховати вже повні рядки; показ реалму.
- **Шорткати рядка** — ПКМ фільтрує за персонажем, Shift+ПКМ за професією, Alt+ПКМ за доповненням, Ctrl+ПКМ копіює рядок у чат.
- **Ховати в бою** — опція ховає головне вікно на початку бою і повертає після нього (не відкриває знову, якщо ви закрили вікно самі).
- **Скоро повні** — `/conc soon` показує рядки, що заповняться за 2 год; у підсумку/тултіпах лічильник; опційна жовта підсвітка.
- **Пошук** — поле на панелі або `/conc search` фільтрує за персонажем, реалмом чи професією.
- **Idiot Alert** — нагадує, якщо тижневий квест професії виконано, але не здано (`/conc weekly`; клік по банеру — список, Ctrl+клік — копія).
- **Фокус на наступний / найнижчий** — `/conc focus` відкриває вікно на рядку, найближчому до повної; `/conc focuslow` — на найнижчому неповному.
- **Сьогодні / підсумок** — `/conc today` — рядки до добового ресету; `/conc totals` — зріз по акаунту.
- **Тиждень / брак / Moxie** — `/conc week` — рядки до тижневого ресету; `/conc missing` — скільки бракує до максимуму; `/conc moxiecap` — рядки з Moxie від 600.
- **Витратити / професія** — `/conc spend` — рядки, готові до крафту; `/conc prof Alchemy` — ця професія на всіх персонажах.
- **Нижче / персонаж** — `/conc below` — рядки нижче 25%; `/conc char Ім'я` — цей персонаж по професіях.
- **Досягти / доповнення / сортування** — `/conc reach 500` оцінює час до кількості; `/conc exp Midnight` показує одне доповнення; `/conc sort time` задає сортування.
- **Топ / середнє** — `/conc top` показує найповніші рядки; `/conc avg` — середнє заповнення. `/conc scale` і `/conc font` збігаються з повзунками налаштувань.
- **Останній до повної** — `/conc last` показує рядок, що заповниться останнім. `/conc alpha 80` задає непрозорість вікна.
- **Колонки / швидкість** — `/conc col time` показує або ховає колонку; `/conc rate 12` задає оцінку відновлення за годину.
- **Прогноз** — калькулятор цільової концентрації в головному вікні.
- **Сповіщення** — повна концентрація та **600 Moxie** (банер рейду, чат, звук).
- **Ігнор варіантів професії** — вимкнути збір для окремої лінії навичок (наприклад, Dragon Isles vs Midnight).
- **Синхронізація** — події валют і вхід у світ; оцінка регену за налаштованою швидкістю відновлення.
- **Міні-карта та LDB** — брокер і кнопка на міні-карті (можна приховати).
- **Інтерфейс** — прозорість, шрифт, масштаб вікна; прокручувані налаштування.
- **12 мов** — uk, en, de, es, fr, it, pl, pt, ru, zhCN, zhTW, ko.

#### Команди

| Команда | Дія |
|--------|-----|
| `/conc` | Відкрити головне вікно |
| `/conc toggle` / `/conc t` | Відкрити або закрити |
| `/conc refresh` / `/conc r` | Синхронізувати поточного персонажа |
| `/conc status` / `/conc s` | Статус поточного персонажа в чат |
| `/conc me` | Вікно з фільтром на цього персонажа |
| `/conc next` / `/conc n` | Яка лінія найближче до повної |
| `/conc clear` | Скинути фільтри |
| `/conc moxie` / `/conc mx` | Artisan's Moxie поточного персонажа |
| `/conc lowest` / `/conc lo` | Найнижча неповна концентрація |
| `/conc stale` | Застарілі рядки (>24 год) |
| `/conc chars` | Список відстежуваних персонажів |
| `/conc full` | Рядки вже на максимумі |
| `/conc soon` / `/conc 2h` | Рядки, що заповняться за 2 год (`/conc soon 4`) |
| `/conc list` / `/conc visible` | Видимі рядки таблиці |
| `/conc combat` | Ховати вікно в бою |
| `/conc search` | Фільтр за ім'ям (порожнє скидає) |
| `/conc export` | Скопіювати видимі рядки в чат |
| `/conc oldest` | Найдавніша синхронізація |
| `/conc ignored` | Ігноровані варіанти професій |
| `/conc notify` | Сповіщення вкл/викл |
| `/conc weekly` | Тижневі квести професій, готові здати |
| `/conc focus` / `/conc jump` | Вікно на рядку, що найближче до повної |
| `/conc hidefull` | Сховати або показати повні рядки |
| `/conc percent` | Показати або сховати відсоток |
| `/conc compact` | Компактний формат часу |
| `/conc today` / `/conc daily` | Рядки, що заповняться до добового ресету |
| `/conc totals` / `/conc sum` | Підсумок концентрації та Moxie по акаунту |
| `/conc focuslow` / `/conc flo` | Вікно на рядку з найнижчою концентрацією |
| `/conc hidestale` | Сховати або показати застарілі рядки |
| `/conc highlight` | Підсвітка рядків, що скоро заповняться |
| `/conc week` / `/conc wreset` | Рядки, що заповняться до тижневого ресету |
| `/conc missing` / `/conc gap` | Скільки концентрації бракує до максимуму |
| `/conc moxiecap` / `/conc m600` | Рядки з Moxie від 600 (`/conc moxiecap 500`) |
| `/conc spend` / `/conc usable` | Рядки, готові до крафту (за замовчуванням 100; `/conc spend 250`) |
| `/conc prof` / `/conc profession` | Одна професія на всіх персонажах (`/conc prof Alchemy`) |
| `/conc hidemoxie` | Сховати або показати рядки лише з Moxie |
| `/conc lowlight` | Підсвітка низької концентрації |
| `/conc below` / `/conc under` | Рядки нижче відсотка (за замовчуванням 25; `/conc below 50`) |
| `/conc char` / `/conc alt` | Один персонаж по професіях (`/conc char Ім'я`) |
| `/conc autoself` | Відкривати вікно з фільтром на цього персонажа |
| `/conc refreshopen` | Синхронізувати цього персонажа при відкритті |
| `/conc reach` / `/conc target` | Час до заданої концентрації (`/conc reach 500`) |
| `/conc exp` / `/conc expansion` | Одне доповнення на всіх персонажах (`/conc exp Midnight`) |
| `/conc sort` | Колонка або напрям сортування (`/conc sort time`) |
| `/conc col` / `/conc column` | Показати або сховати колонку (`/conc col time`) |
| `/conc rate` | Швидкість відновлення за годину (`/conc rate 12`) |
| `/conc chatlog` | Друкувати оновлення концентрації в чат |
| `/conc sound` | Звук разом зі сповіщеннями |
| `/conc top` / `/conc best` | Найбільша концентрація (за замовчуванням 5; `/conc top 10`) |
| `/conc avg` / `/conc average` | Середнє заповнення відстежуваних рядків |
| `/conc scale` | Масштаб вікна (`/conc scale 100` або `/conc scale 1`) |
| `/conc font` | Розмір шрифту (`/conc font 14`) |
| `/conc showmoxie` | Показати або сховати Moxie в списку професій |
| `/conc last` / `/conc eta` | Рядок, що заповниться останнім |
| `/conc alpha` / `/conc opacity` | Непрозорість вікна, 0–100 (`/conc alpha 80`) |
| `/conc markme` | Позначати рядки цього персонажа |
| `/conc fullhl` | Підсвітка вже повних рядків |
| `/conc realm` | Показати або сховати реалм |
| `/conc copy` | Скопіювати статус цього персонажа в чат |
| `/conc minimap` / `/conc mm` | Показати або сховати кнопку міні-карти |
| `/conc lock` | Заблокувати або розблокувати вікно |
| `/conc settings` | Відкрити налаштування |
| `/conc resetui` | Скинути позицію та розмір вікна |
| `/conc version` / `/conc v` | Версія аддона |
| `/conc help` / `/conc ?` | Список команд |
| `/conc close` / `/conc hide` | Закрити вікно |
| `/conclanguage` | Налаштування |

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
