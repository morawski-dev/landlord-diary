# Zadania cykliczne — projekt

Data: 2026-06-16
Plik aplikacji: `index.html` (root), backend Supabase (`ld_tasks`).

## Problem

Zadania w aplikacji noszą nazwę „cykliczne" i toast po odhaczeniu obiecuje „wróci
w kolejnym cyklu", ale w kodzie **nie ma żadnej logiki cykliczności**. Po odhaczeniu
pole `done` zostaje `true` i zadanie nie wraca. Użytkownik chce definiować zadanie
**raz** i mieć je powtarzane automatycznie — co miesiąc tego samego dnia (czynsz,
liczniki) oraz co rok / co kilka lat (przegląd gazowy, PIT, instalacja elektryczna co 5 lat).

## Decyzje (z brainstormingu)

- **Zakres cyklu:** miesięczne **i** roczne (model pokrywa też „co X lat").
- **Po odhaczeniu:** przeskok terminu na następny cykl **+ log historii** odhaczeń.
- **Model danych:** podejście A — interwał (`freq_n`) + jednostka (`freq_unit`),
  reużywa istniejący w projekcie wzorzec kolumny `log` (JSONB) z `ld_issues`.
- **Edycja:** dodać edycję istniejących zadań (żeby ustawić cykl na już zaseedowanych
  obowiązkach rocznych).

## Model danych — nowe kolumny w `ld_tasks`

| Kolumna     | Typ    | Domyślnie | Znaczenie                                            |
|-------------|--------|-----------|------------------------------------------------------|
| `freq_n`    | int    | `null`    | Krotność interwału, np. `1`, `5`.                    |
| `freq_unit` | text   | `null`    | `null` = jednorazowe; `'month'`; `'year'`.           |
| `log`       | jsonb  | `[]`      | Historia odhaczeń: `[{ when, date }]`.               |

`log` wpis: `{ when: 'YYYY-MM-DD' (dzień odhaczenia), date: 'YYYY-MM-DD' (termin, którego dotyczyło) }`.

Mapowanie `rowToTask` rozszerzone o `freqN`, `freqUnit`, `log`.

## Logika nawrotu (`toggleTask`)

1. **Zadanie jednorazowe** (`freqUnit` puste) → zachowanie jak dziś: `done = true`,
   zostaje na liście jako wykonane. Ponowne kliknięcie cofa (`done = false`).
2. **Zadanie cykliczne** (`freqUnit` ustawione) przy odhaczaniu na „done":
   - dopisz wpis do `log`: `{ when: dziś, date: bieżący termin }`;
   - policz `nextDate = addInterval(date, freqN, freqUnit)`;
   - zapisz `date = nextDate`, `done = false`, `log = [...log, wpis]`;
   - zadanie natychmiast wraca jako „do zrobienia" z nowym terminem;
   - toast: „Odhaczone — następny termin: <data>".

### Obliczanie następnego terminu — kotwica na dzień miesiąca

`nextDate` liczony **od dotychczasowego terminu**, nie od dnia kliknięcia — czynsz
„10-tego" pozostaje 10-tego, nawet przy odhaczeniu z opóźnieniem.

`addInterval(date, n, unit)`:
- `unit === 'year'` → dodaj `n` lat do roku.
- `unit === 'month'` → dodaj `n` miesięcy.

**Edge case 31. dnia:** docelowy miesiąc może nie mieć dnia źródłowego (31 → luty).
Przytnij do **ostatniego dnia miesiąca docelowego** (28/29 lut), ale zachowaj
pierwotny dzień miesiąca jako kotwicę, by w kolejnych miesiącach wrócić do 31, gdy
miesiąc go ma. Implementacja: trzymaj dzień docelowy = dzień z pierwotnej `date`,
clampuj do `daysInMonth(rok, miesiąc)` tylko przy budowie konkretnej daty.

## UI

### Modal zadania (tryb tworzenia i edycji)

Modal obsługuje teraz **create** i **edit**. Stan trybu trzymany w zmiennej
(np. `taskModalEditId` = `null` dla nowego, `id` dla edycji).

Nowe pole `select` „Powtarzalność":

```
Jednorazowo      → freq_n=null, freq_unit=null
Co miesiąc       → freq_n=1,   freq_unit=month   (domyślne dla nowych)
Co rok           → freq_n=1,   freq_unit=year
Co 5 lat         → freq_n=5,   freq_unit=year
```

Wartość selecta kodowana jako jeden string (np. `none` / `1m` / `1y` / `5y`),
parsowana do `freq_n`/`freq_unit` przy zapisie i odwrotnie przy otwarciu edycji.

- Tytuł modala / przycisk: „Dodaj" (create) vs „Zapisz" (edit).
- Pole „Termin" dla cyklicznych oznacza pierwszy / najbliższy termin.
- `openTaskModal(id?)`: bez `id` → reset pól, tryb create; z `id` → wypełnij pola
  danymi zadania, tryb edit.
- `saveTask()`: insert (create) albo update `.eq('id', id)` (edit); aktualizuje
  lokalną tablicę `tasks` i re-renderuje.

### Kafelek zadania

- Wejście w edycję: dyskretny przycisk/ikona „edytuj" na kafelku (klik nie może
  kolidować z `toggleTask` — `stopPropagation`).
- Plakietka cyklu przy kategorii: `↻ co miesiąc` / `↻ co rok` / `↻ co 5 lat`.
  Zadania jednorazowe — bez plakietki.
- `task-date` (data po prawej) bez zmian.

### Historia odhaczeń

Minimalnie: jeśli `log` niepuste, pod opisem dyskretna linijka z ostatnimi ~3–4
cyklami, np. „Wykonane: mar, kwi, maj 2026". Bez osobnego ekranu i bez rozwijania
(pełny wzorzec rozwijanej historii istnieje w `ld_issues`, ale tu celowo lekko —
dziennik najmu, nie system ticketowy).

## Migracja / dane startowe

- `seedTasks()` — przypisać cykle do dziesięciu zadań:
  - przeglądy gazowy / kominowy / czujnik czadu / AGD / polisa / PIT → `co rok`;
  - instalacja elektryczna → `co 5 lat`;
  - decyzja o przedłużeniu umowy → `jednorazowo`;
  - przegląd stawki czynszu vs rynek, aktualizacja zaliczek na media → `co rok`
    (realnie powtarzalne; użytkownik może zmienić edycją).
  - Seed leci tylko gdy tabela pusta (`seedIfEmpty`), więc nie nadpisze danych użytkownika.
- **Istniejące wiersze** w bazie użytkownika dostaną `freq_unit = null` z domyślki
  kolumny → działają jak jednorazowe, dopóki użytkownik nie ustawi cyklu edycją.
  Brak regresji, nic nie znika.
- Wymagany jednorazowy ALTER TABLE w Supabase (poza plikiem HTML) — udokumentować
  SQL do uruchomienia przez użytkownika.

## Poza zakresem (YAGNI)

- Pełny RRULE (co drugi wtorek itp.).
- Generowanie osobnych instancji na każdy miesiąc.
- Powiadomienia push / e-mail o terminach (osobny temat).
