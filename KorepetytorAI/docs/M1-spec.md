# M1 Planer — specyfikacja dla implementacji

Źródło nadrzędne: [`../../architektura.md`](../../architektura.md) (zasady projektowe, model danych, plan etapów).
Ta specyfikacja opisuje, co dokładnie ma powstać w etapie M1. Gdy coś tu jest sprzeczne z `architektura.md`, pierwszeństwo ma `architektura.md` i trzeba to zgłosić zamiast zgadywać.

Stan wyjściowy: M0 zaakceptowany na iPhonie 14 i iPadzie (schemat CloudKit, synchronizacja, nawigacja). Zamknięte długi M0 wymienione w `KorepetytorAI/README.md` (sekcja „Na później”) są częścią M1, patrz punkt 2.

## 1. Cel etapu

Uczennica może w mniej niż 15 sekund dodać sprawdzian, zobaczyć go w kalendarzu i na ekranie Dziś, a dzień wcześniej dostać przypomnienie. Wszystko działa offline i synchronizuje się przez iCloud.

**Gotowe, gdy** (kryteria z `architektura.md`, M1):
- da się wpisać termin w mniej niż 15 sekund (pomiar na iPhonie 14, od otwarcia formularza do zapisu),
- przychodzi powiadomienie dzień wcześniej o zadanej godzinie,
- termin dodany na jednym urządzeniu pojawia się na drugim po synchronizacji.

## 2. Zakres

### W zakresie
1. Profil i wprowadzenie przy pierwszym uruchomieniu (pseudonim, awatar).
2. Scalanie duplikatów `Profile` po synchronizacji (dług z M0: dwa urządzenia mogą utworzyć profil przed synchronizacją).
3. Przedmioty: lista z 16 przedmiotami startowymi, dodawanie, edycja nazwy, koloru i ikony, usuwanie.
4. Sprawdziany: dodawanie, edycja, usuwanie, wpisanie oceny po fakcie.
5. Planer: widok miesiąca i widok listy, filtr po przedmiocie.
6. Przypomnienia lokalne.
7. Ekran Dziś: najbliższe terminy i stan pusty dla zadań z planu nauki.
8. Testy jednostkowe dla logiki (repozytoria, scalanie profilu, wyliczanie przypomnień).

### Poza zakresem (nie implementować)
- Materiały, zdjęcia, PDF, rozpoznawanie tekstu (M2). Pole „zakres” w sprawdzianie jest zwykłym tekstem.
- Punkty XP, monety, serię, odznaki, minutnik sesji (M3). Ekran Profil pokazuje tylko pseudonim, awatar i stan iCloud.
- Quizy, fiszki, AI, proxy (M4–M5). Ekrany Nauka i Korepetytor zostają ekranami zastępczymi.
- Plan nauki i generowanie sesji (M5). Ekran Dziś pokazuje tylko miejsce na zadania.
- Strefa rodzica (M6), widżety i dopracowanie iPada (M7).
- Integracja z dziennikiem elektronicznym (poza zakresem projektu).

## 3. Zasady projektowe, które obowiązują tutaj

- Termin wpisuje się szybko: domyślne wartości (data = dziś, kind = sprawdzian, status = nadchodzący), a pola opcjonalne nie blokują zapisu.
- Pracujemy bez kar i bez porównań: ekrany pokazują terminy, nie oceny jako wynik „dobrze/źle”.
- Ocena jest opcjonalna i wpisywana po fakcie. Nie wpływa na nic poza polem `grade`.
- Wszystko działa offline. Brak zgody na powiadomienia nie blokuje żadnej funkcji, tylko pokazuje informację.
- Kod po angielsku, teksty dla użytkowniczki po polsku w `String Catalog` (`App/Localizable.xcstrings`). Klucze z kropkami, jak w M0 (np. `planner.empty.title`).

## 4. Model danych

Schemat pozostaje `SchemaV1`. **Nie zmieniaj istniejących pól ani typów.** Jeśli implementacja naprawdę wymaga nowego pola, dodaj je jako opcjonalne albo z wartością domyślną i zapisz to w sekcji „Decyzje” w tym pliku. Zmiany nie mogą być destrukcyjne (CloudKit).

Encje używane w M1: `Profile`, `Subject`, `Assessment`. Pozostałe z 15 encji zostają nietknięte.

Wartości enumów (`AssessmentKind`, `AssessmentStatus`, `SubjectKind`) są już zdefiniowane w `Core/Models/Enums.swift`. Nie zmieniaj ich `rawValue`.

## 5. Warstwa Core (bez UI, testowalna)

Nowe pliki w `Packages/Core/Sources/Core/`:

- `Repositories/ProfileRepository.swift`
  - `currentProfile() throws -> Profile?` — zwraca najstarszy profil (wg `createdAt`), a jeśli jest ich więcej, scala je (patrz punkt 6).
  - `createProfile(nickname:avatarID:) throws -> Profile`.
- `Repositories/AssessmentRepository.swift`
  - `assessments(from:to:subject:) throws -> [Assessment]` — posortowane po dacie.
  - `upcoming(limit:from:) throws -> [Assessment]` — nadchodzące, status `upcoming`.
  - `add(...)`, `update(...)`, `delete(...)`, `markCompleted(_:grade:)`.
- `Repositories/SubjectRepository.swift` — rozszerzyć o `update(_:name:colorName:iconName:)` i o zasadę usuwania (punkt 7).
- `Reminders/ReminderPlanner.swift` — czysta funkcja: dla sprawdzianu zwraca datę i godzinę przypomnienia albo `nil`, gdy przypomnienie już minęło lub sprawdzian nie jest nadchodzący. Domyślna godzina przypomnienia: 18:00 dnia poprzedzającego sprawdzian.

Każda zmiana zapisuje `updatedAt` (użyj `touch()` z `TimestampedModel`).

## 6. Profil i scalanie duplikatów

- Przy starcie aplikacji (`DataMaintenance`) wywołaj scalenie profili: zostaje najstarszy (`createdAt`, a przy remisie najmniejszy `id.uuidString`), a pozostałe są usuwane. Relacje `xpEvents` i `badges` przepinamy na zachowany profil przed usunięciem.
- Scalanie musi być idempotentne i nie może zależeć od kolejności urządzeń.
- Wprowadzenie tworzy profil tylko wtedy, gdy `currentProfile()` zwraca `nil`. Ekran Profil nie tworzy profilu sam.

## 7. Przedmioty

- Lista z sekcją „Ogólne” i „Zawodowe”, sortowana wg `sortOrder`.
- Edycja: nazwa (wymagana, max 40 znaków), kolor (paleta `SubjectPalette`), ikona (SF Symbols z krótkiej listy w `DesignSystem`).
- Dodawanie: nowy przedmiot dostaje rodzaj ogólny, kolejny `sortOrder`.
- Usuwanie: przedmiot z sprawdzianami nie może być usunięty od ręki. Pokaż komunikat z liczbą sprawdzianów i opcją przeniesienia ich na inny przedmiot albo anulowania. Jeśli to zbyt duże na M1, zablokuj usuwanie i zostaw komunikat — to decyzja do potwierdzenia (patrz „Otwarte decyzje”).
- Przedmioty startowe (16) są wgrywane przez `SubjectSeeder` i nie wracają po usunięciu. Nie zmieniaj tego zachowania.

## 8. Ekrany

Każdy ekran korzysta z komponentów `DesignSystem` (`Card`, `PrimaryButton`, `SubjectChip`, `EmptyState`, `ProgressRing`). Nie dodawaj nowych kolorów poza paletą.

### 8.1 Wprowadzenie (pierwsze uruchomienie)
- Pokazuje się, gdy `currentProfile()` zwraca `nil`. Jest pełnoekranowe.
- Krok 1: pseudonim (pole tekstowe, domyślnie puste, przycisk „Dalej” nieaktywny bez pseudonimu).
- Krok 2: wybór awatara z 8 zestawionych awatarów (`AvatarID` w `DesignSystem`, każdy to symbol SF Symbols na kolorowym tle).
- Krok 3: „Gotowe” tworzy profil. Potem użytkowniczka trafia na Dziś.
- Można wrócić do kroku 1 i zmienić pseudonim (przycisk „Wstecz”).

### 8.2 Dziś
- Nagłówek z pseudonimem.
- Sekcja „Najbliższe terminy”: do 3 nadchodzących sprawdzianów (przedmiot, rodzaj, data, odliczanie „za N dni”).
- Sekcja „Zadania na dziś”: w M1 stan pusty z `EmptyState` i tekstem, że plan pojawi się w kolejnych wersjach. Nie implementuj planu nauki.
- Przycisk „Dodaj sprawdzian” otwiera edytor (punkt 8.4).
- Gdy brak nadchodzących sprawdzianów: `EmptyState` z zachęceniem do dodania pierwszego.

### 8.3 Planer
- Przełącznik segmentowy: **Miesiąc** / **Lista**.
- Miesiąc: siatka dni tygodnia zaczynająca się w poniedziałek, nawigacja poprzedni/następny miesiąc, przycisk „Dziś”. Dni ze sprawdzianami mają kropki w kolorach przedmiotów (maks. 3 kropki, reszta jako „+N”). Stuknięcie dnia pokazuje listę sprawdzianów tego dnia pod siatką.
- Lista: sprawdziany pogrupowane po dacie, najbliższe na górze. Przesunięcie w lewo: usuń (z potwierdzeniem). Przesunięcie w prawo: oznacz jako zakończony.
- Filtr po przedmiocie (menu w pasku narzędzi), domyślnie „Wszystkie”.
- Przycisk „+” otwiera edytor sprawdzianu.
- Przycisk „Przedmioty” prowadzi do listy przedmiotów (punkt 8.5).
- Stan pusty: `EmptyState` z zachęceniem do dodania sprawdzianu.

### 8.4 Edytor sprawdzianu (szybki wpis)
- Pola w kolejności: przedmiot (wymagany, domyślnie ostatnio użyty), rodzaj (kartkówka, sprawdzian, praca klasowa, inne; domyślnie sprawdzian), data (domyślnie za 7 dni), zakres (opcjonalny, wieloliniowy), przypomnienie (przełącznik, domyślnie włączony).
- Edycja istniejącego: te same pola plus status i ocena. Ocena to tekst (np. „4+”), opcjonalna, dostępna po zmianie statusu na „zakończony”.
- „Zapisz” jest aktywny, gdy wybrany jest przedmiot. Data w przeszłości jest dozwolona (wpis po fakcie).
- Po zapisie: planowane lub odwołane przypomnienie (punkt 9) i zamknięcie arkusza.
- Cel: od otwarcia do zapisu w mniej niż 15 sekund dla typowego wpisu.

### 8.5 Lista przedmiotów
- Sekcje „Ogólne” i „Zawodowe”. Stuknięcie wiersza otwiera edycję (nazwa, kolor, ikona).
- Przycisk „+” dodaje przedmiot (rodzaj ogólny).
- Usuwanie zgodnie z punktem 7.

### 8.6 Profil (z M0)
- Zmiana pseudonimu i awatara. Pozostałe elementy (stan iCloud, lista przedmiotów do testu synchronizacji) można usunąć, bo przeszły odbiór M0; zostaw stan iCloud, bo przyda się w M6.

## 9. Przypomnienia

- Używamy `UNUserNotificationCenter`, powiadomienia lokalne, bez serwera.
- Zgodę prosimy dopiero przy pierwszym włączeniu przypomnienia w edytorze, nie przy starcie aplikacji. Bez zgody przełącznik jest wyłączony, a obok pokazuje się informacja, jak ją włączyć w Ustawieniach.
- Treść: „Jutro: sprawdzian z <przedmiot>” albo „Jutro: kartkówka z <przedmiot>” (wg rodzaju), w zależności od kontekstu daty. Bez treści z zakresu materiału.
- Identyfikator żądania: `assessment.<UUID>`. Zmiana daty lub przedmiotu zastępuje przypomnienie; usunięcie lub anulowanie sprawdzianu je usuwa; zakończenie sprawdzianu też je usuwa.
- Przy każdym starcie aplikacji przeplanuj przypomnienia dla wszystkich nadchodzących sprawdzianów (dane mogły przyjść z iCloud z innego urządzenia).
- Logika wyliczania daty jest w `ReminderPlanner` (Core), a wywołania systemowe w warstwie aplikacji (`App/` lub `Features/Planner/`).

## 10. Testy

Swift Testing, w pamięci (`TestSupport`, `Persistence.makeInMemoryContainer()`).

Minimalny zestaw:
- `AssessmentRepository`: dodanie, edycja, usunięcie, zakończenie z oceną, zakres dat, nadchodzące posortowane, filtr po przedmiocie.
- `ProfileRepository`: `currentProfile` zwraca najstarszy; scalanie dwóch profili przenosi `xpEvents` i `badges` (w M1 zwykle puste, test sprawdza przepięcie relacji) i usuwa nadmiarowe; scalanie idempotentne.
- `SubjectRepository`: edycja, dodawanie na końcu, odmowa usunięcia przedmiotu z sprawdzianami (zgodnie z decyzją z punktu 7).
- `ReminderPlanner`: dzień wcześniej o 18:00; `nil` dla sprawdzianu w przeszłości; `nil` dla zakończonego lub odwołanego; poprawne przejście przez granicę miesiąca i roku.
- `SubjectSeederTests` i `SchemaTests` z M0 dalej przechodzą.

Po każdym etapie implementacji: `./scripts/test.sh` z katalogu `KorepetytorAI` przechodzi bez ostrzeżeń.

## 11. Kolejność implementacji

Każdy krok kończy się zielonymi testami i osobnym commitem. Nie łącz kroków.

1. Repozytoria i testy Core (punkty 5 i 10, bez UI).
2. Scalanie profili w `DataMaintenance` i testy (punkt 6).
3. Lista przedmiotów: edycja, dodawanie, usuwanie (punkt 7, 8.5).
4. Edytor sprawdzianu i widok listy w Planerze (punkty 8.3, 8.4).
5. Widok miesiąca w Planerze (punkt 8.3).
6. Przypomnienia: planowanie, anulowanie, przeplanowanie przy starcie (punkt 9).
7. Wprowadzenie i Profil (punkty 8.1, 8.6).
8. Ekran Dziś (punkt 8.2).
9. Sprawdzenie kryteriów: pomiar czasu wpisu, przypomnienie na urządzeniu, synchronizacja.

## 12. Sprawdzenie na urządzeniach (odbiór M1)

Na iPhonie 14 i iPadzie, to samo konto iCloud:
- [ ] Wprowadzenie przy pierwszym uruchomieniu tworzy jeden profil, także gdy drugie urządzenie ma już profil.
- [ ] Dodanie sprawdzianu zajmuje mniej niż 15 sekund (zmierz stoperem).
- [ ] Sprawdzian pojawia się w widoku miesiąca, listy i na ekranie Dziś.
- [ ] Sprawdzian dodany na iPhonie widać na iPadzie po synchronizacji, i odwrotnie.
- [ ] Przypomnienie przychodzi dzień wcześniej o 18:00 (do sprawdzenia na krótkiej dacie testowej, np. data jutro z przypomnieniem o odpowiedniej godzinie).
- [ ] Usunięcie sprawdzianu usuwa też jego przypomnienie.
- [ ] Ocena wpisana po fakcie jest widoczna na obu urządzeniach.
- [ ] Filtr po przedmiocie i przełącznik Miesiąc/Lista działają na iPadzie w obu układach.
- [ ] Tryb ciemny i największy rozmiar tekstu nie psują ekranów.

## 13. Otwarte decyzje

Te punkty zostały rozstrzygnięte w tej specyfikacji, ale warto je potwierdzić, zanim pojawią się w kodzie:

1. **Przypomnienia na dwóch urządzeniach.** Każde urządzenie planuje powiadomienia z tych samych danych, więc przy dwóch telefonach przyjdą dwa powiadomienia. Rekomendacja: w M1 zostawić tak, a w M7 dodać ustawienie „przypominaj na tym urządzeniu”. Alternatywa: planować tylko na urządzeniu ustawionym przez użytkowniczkę już teraz.
2. **Usuwanie przedmiotu z sprawdzianami.** Rekomendacja: blokada z komunikatem (najprostsze i bezpieczne). Przeniesienie sprawdzianów można dodać później.
3. **Godzina przypomnienia.** Rekomendacja: stała 18:00 w M1, bez ustawienia.
4. **Awatary.** Rekomendacja: 8 symboli SF Symbols na kolorowym tle, bez grafik własnych.

Gdy któraś decyzja zmieni się w trakcie implementacji, zapisz to tutaj w sekcji „Decyzje” z datą, nie zmieniając reszty specyfikacji po cichu.

## 14. Decyzje wykonawcze

*(Uzupełniane w trakcie implementacji.)*
