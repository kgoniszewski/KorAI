# M2 Materiały — specyfikacja dla implementacji

Źródło nadrzędne: [`../../architektura.md`](../../architektura.md) (zasady projektowe, model danych, plan etapów).
Ta specyfikacja opisuje, co dokładnie ma powstać w etapie M2. Gdy coś tu jest sprzeczne z `architektura.md`, pierwszeństwo ma `architektura.md` i trzeba to zgłosić zamiast zgadywać.

Stan wyjściowy: M1 scalony do `main` ([kgoniszewski/KorAI#1](https://github.com/kgoniszewski/KorAI/pull/1)), testy jednostkowe przechodzą na symulatorach iPhone'a i iPada. Odbiór M1 na urządzeniach (punkt 12 `M1-spec.md`) trzeba zakończyć przed odbiorem M2. Decyzje M1 (punkt 14 `M1-spec.md`) obowiązują dalej.

## 1. Cel etapu

Uczennica robi zdjęcie zeszytu, skanuje kartkę albo dodaje PDF od nauczyciela, przypisuje materiał do przedmiotu i sprawdzianu, a potem znajduje go po słowie z treści. Tekst ze zdjęć i PDF-ów rozpoznaje się na urządzeniu, bez sieci. Wszystko synchronizuje się przez iCloud.

**Gotowe, gdy** (kryterium z `architektura.md`, M2):
- zdjęcie zeszytu i plik PDF są widoczne na obu urządzeniach,
- oba da się znaleźć po słowie z treści (z tekstu rozpoznanego na urządzeniu).

## 2. Zakres

### W zakresie
1. Notatki tekstowe: tworzenie, edycja, usuwanie.
2. Zdjęcia: aparat i galeria (jedno lub kilka zdjęć naraz, każde jako osobny materiał).
3. Skaner dokumentów (VisionKit): wiele stron zapisanych jako jeden PDF.
4. Import plików PDF (Pliki / iCloud Drive, „Udostępnij” jest poza zakresem).
5. Podgląd: notatka, zdjęcie z powiększaniem, PDF z przewijaniem stron.
6. Rozpoznawanie tekstu na urządzeniu: Vision dla zdjęć i skanów, PDFKit dla PDF z warstwą tekstową, Vision dla stron PDF bez tekstu.
7. Ręczna poprawa rozpoznanego tekstu.
8. Przypisanie do przedmiotu (wymagane) i do sprawdzianów (opcjonalne, wiele).
9. Wyszukiwanie po tytule, treści notatki i rozpoznanym tekście, bez rozróżniania wielkości liter i polskich znaków.
10. Materiały sprawdzianu widoczne w edytorze sprawdzianu (z Planera i ekranu Dziś).
11. Testy jednostkowe dla logiki (repozytorium, wyszukiwanie, przetwarzanie obrazów i PDF, rozpoznawanie tekstu).

### Poza zakresem (nie implementować)
- AI: streszczenia (`summary` zostaje puste), czytanie odręcznych notatek przez Claude, quizy i fiszki (M4).
- Rysowanie i Apple Pencil w notatkach, formatowanie tekstu (M7).
- Udostępnianie materiałów z innych aplikacji (rozszerzenie „Udostępnij”) i eksport.
- Foldery, tagi, ulubione.
- Dopracowanie układu iPada (M7); na iPadzie M2 działa w tym samym układzie co M1.

## 3. Zasady projektowe, które obowiązują tutaj

- Materiał dodaje się szybko: domyślny przedmiot to ostatnio użyty, tytuł powstaje automatycznie (np. „Zdjęcie 16 lis”), pola opcjonalne nie blokują zapisu.
- Rozpoznawanie tekstu nie blokuje zapisu: materiał jest od razu widoczny, tekst dochodzi w tle.
- Słabe rozpoznanie nie jest błędem użytkowniczki: komunikat mówi, że tekst można poprawić ręcznie, a w przyszłości pomoże AI.
- Wszystko działa offline. Brak zgody na aparat nie blokuje galerii, plików ani notatek.
- Materiały należą do uczennicy: aplikacja nie wysyła ich nigdzie poza iCloud (AI dopiero w M4, za zgodą wynikającą z użycia funkcji).
- Kod po angielsku, teksty po polsku w `App/Localizable.xcstrings`, klucze z kropkami (`materials.…`).

## 4. Model danych

Schemat pozostaje `SchemaV1`. **Nie zmieniaj istniejących pól ani typów i nie dodawaj nowych pól** (ta sama przyczyna co decyzja M1 14.5: zmiana `SchemaV1` w miejscu przy podanym planie migracji grozi błędem 134504). Gdyby pole było naprawdę niezbędne, zatrzymaj się i zgłoś to jako decyzję do `SchemaV2`.

Encje używane w M2: `StudyMaterial`, `Subject`, `Assessment`.

| Pole `StudyMaterial` | Użycie w M2 |
| --- | --- |
| `kindRaw` | `note` (notatka), `photo` (jedno zdjęcie, JPEG), `pdf` (import PDF albo skan wielu stron) |
| `title` | wymagany po przycięciu spacji, max 80 znaków; domyślny tytuł automatyczny |
| `content` | treść notatki; dla zdjęć i PDF pusty |
| `fileData` | JPEG dla `photo`, PDF dla `pdf`, `nil` dla `note`; `externalStorage`, synchronizowany jako zasób CloudKit |
| `recognizedText` | `nil` — jeszcze nie rozpoznano; `""` — rozpoznano, nic nie znaleziono; tekst — wynik albo poprawka ręczna |
| `summary` | nieużywane w M2 (M4) |
| `subject` | wymagany przy zapisie z UI; w danych może być `nil` (synchronizacja, `.nullify`) |
| `assessments` | wiele-do-wielu, opcjonalne |

Ręczna poprawa nadpisuje `recognizedText`. Ponowne rozpoznanie nie może nadpisać poprawki: rozpoznawanie działa tylko dla `recognizedText == nil` (patrz punkt 6).

Wartości enumu `MaterialKind` są w `Core/Models/Enums.swift`. Nie zmieniaj ich `rawValue`.

## 5. Warstwa Core (bez UI, testowalna)

Nowe pliki w `Packages/Core/Sources/Core/`:

- `Repositories/MaterialRepository.swift`
  - `materials(subject:assessment:) throws -> [StudyMaterial]` — od najnowszego (`createdAt`).
  - `search(_ query: String, subject:) throws -> [StudyMaterial]` — patrz punkt 7.
  - `addNote(title:content:subject:assessments:)`, `addPhoto(imageData:title:subject:assessments:)`, `addPDF(data:title:subject:assessments:)`.
  - `update(_:title:content:subject:assessments:)`, `delete(_:)`.
  - `storeRecognitionResult(_:text:) throws -> Bool` — wynik automatyczny; zapisuje tylko przy `recognizedText == nil`, zwraca, czy zapisał.
  - `correctRecognizedText(_:text:)` — ręczna poprawa; zapisuje zawsze.
  - `pendingRecognition() throws -> [StudyMaterial]` — `photo`/`pdf` z `recognizedText == nil`.
  - Walidacja tytułu (pusty, za długi) jako `MaterialRepositoryError`, jak w `SubjectRepository`.
- `Materials/MaterialSearch.swift` — czysta funkcja dopasowania: normalizacja (`SubjectCatalog.normalizedKey` lub wspólna funkcja wyciągnięta z niej), podział zapytania na słowa, wszystkie słowa muszą wystąpić w tytule, treści lub rozpoznanym tekście. Zwraca też fragment tekstu wokół pierwszego trafienia (do wiersza wyników).
- `Materials/ImageProcessing.swift` — zmniejszenie zdjęcia (najdłuższy bok 2560 px, JPEG jakość 0,75, z zachowaniem orientacji), miniatura. `#if canImport(UIKit)`.
- `Materials/PDFProcessing.swift` — złożenie stron skanu w jeden PDF, odczyt warstwy tekstowej (PDFKit), wyrenderowanie strony do obrazu (dla Vision), liczba stron, miniatura pierwszej strony.
- `Materials/TextRecognizer.swift` — rozpoznawanie tekstu z obrazu (Vision, `RecognizeTextRequest` lub `VNRecognizeTextRequest`, poziom `accurate`, język `pl-PL` z korektą językową). Dla PDF: najpierw warstwa tekstowa; strony bez tekstu przez Vision. Wynik to jeden `String` (strony oddzielone pustą linią).
- `Repositories/SubjectRepository.swift` — rozszerzyć zasadę usuwania o materiały (punkt 8).

Limity (stałe w Core, testowane):
- PDF: maksymalnie 25 MB; większy plik — komunikat, bez importu.
- Zdjęcie po zmniejszeniu zwykle 0,5–1,5 MB; skan: strony jako JPEG w PDF, ta sama jakość.
- Rozpoznawanie PDF: najwyżej 30 pierwszych stron przez Vision (warstwa tekstowa bez limitu).

Każda zmiana zapisuje `updatedAt` (`touch()`).

## 6. Rozpoznawanie tekstu

- Uruchamia się w tle zaraz po dodaniu zdjęcia, skanu lub PDF, poza głównym wątkiem; do kodu Vision przekazujemy `Data` i identyfikator, nie model SwiftData.
- Wynik zapisuje się tylko wtedy, gdy `recognizedText` materiału jest nadal `nil` (w międzyczasie mogła przyjść poprawka ręczna z drugiego urządzenia).
- Przy starcie, po powrocie na pierwszy plan i po zmianach z iCloud aplikacja rozpoznaje materiały z `recognizedText == nil` (np. zdjęcie dodane na drugim urządzeniu, które przerwało rozpoznawanie). Po jednym naraz, kolejka jak przypomnienia w M1 (`ReminderScheduler`).
- Oba urządzenia mogą rozpoznać ten sam materiał jednocześnie; wynik jest ten sam, więc konflikt jest nieszkodliwy.
- Materiał w trakcie rozpoznawania pokazuje stan „Rozpoznaję tekst…”; po zakończeniu z pustym wynikiem — „Nie znaleziono tekstu. Możesz go wpisać ręcznie.”
- Treść materiału nie trafia do logów.

## 7. Wyszukiwanie

- Pole wyszukiwania na liście materiałów (`.searchable`), wynik na bieżąco podczas pisania (z krótkim opóźnieniem).
- Bez rozróżniania wielkości liter i polskich znaków („zolw” znajduje „żółw”).
- Wszystkie słowa zapytania muszą wystąpić (w dowolnym z pól: tytuł, treść, rozpoznany tekst).
- Wiersz wyniku pokazuje fragment tekstu z trafieniem.
- Filtr przedmiotu działa razem z wyszukiwaniem.
- Wyszukiwanie w pamięci: materiałów jest najwyżej kilkaset. Lista nie może przy tym ładować `fileData` (pobieraj tylko potrzebne pola albo polegaj na leniwym ładowaniu zasobu zewnętrznego; sprawdzić w Instruments, punkt 12).

## 8. Przedmioty i sprawdziany

- Usuwanie przedmiotu: blokada, gdy ma sprawdziany **lub materiały**; komunikat podaje obie liczby. Rozszerza decyzję M1 14.2.
- Usunięcie sprawdzianu nie usuwa materiałów (relacja `.nullify` z M0).
- Edytor sprawdzianu (M1) dostaje sekcję „Materiały”: lista przypisanych materiałów (stuknięcie otwiera podgląd) i przycisk „Dodaj materiał”, który otwiera dodawanie z przedmiotem i sprawdzianem już wybranymi.
- Edytor materiału pozwala wybrać sprawdziany tego samego przedmiotu: najpierw nadchodzące, potem minione (najwyżej 10 ostatnich).

## 9. Ekrany

Każdy ekran korzysta z komponentów `DesignSystem`. Bez nowych kolorów poza paletą. Zastępczy ekran Materiały z M0 jest zastępowany.

### 9.1 Lista materiałów
- Pasek narzędzi: filtr przedmiotu (jak w Planerze), przycisk „+” z menu: Notatka, Zrób zdjęcie, Skanuj dokument, Wybierz z galerii, Importuj PDF.
- Lista od najnowszego; wiersz: miniatura (notatka — ikona), tytuł, przedmiot, data, ikona rodzaju, stan rozpoznawania.
- Przesunięcie w lewo: usuń (z potwierdzeniem).
- Stan pusty: `EmptyState` z zachętą i przyciskiem dodania.
- Wyszukiwanie zgodnie z punktem 7; brak wyników — osobny komunikat.

### 9.2 Dodawanie
- Notatka: edytor (tytuł, przedmiot, sprawdziany, treść wieloliniowa).
- Zdjęcie i galeria: po wybraniu zdjęć arkusz z przedmiotem, sprawdzianami i tytułem (przy wielu zdjęciach tytuł z numerem: „Zdjęcie 16 lis (2)”) i przyciskiem „Zapisz”.
- Skaner: `VNDocumentCameraViewController`; po zakończeniu ten sam arkusz, wynik jako jeden PDF.
- PDF: `fileImporter` z typem PDF; tytuł domyślnie z nazwy pliku.
- Cel: zdjęcie zeszytu zapisane w mniej niż 20 sekund od stuknięcia „+”.

### 9.3 Podgląd materiału
- Notatka: tekst z możliwością edycji.
- Zdjęcie: powiększanie gestem i podwójnym stuknięciem.
- PDF: `PDFView` (PDFKit) w opakowaniu SwiftUI, przewijanie stron.
- Sekcja „Rozpoznany tekst”: tekst do zaznaczenia i kopiowania, przycisk „Popraw” (edycja), stan rozpoznawania.
- Informacje: przedmiot, sprawdziany (stuknięcie otwiera edytor sprawdzianu), data dodania.
- Pasek narzędzi: Edytuj (tytuł, przedmiot, sprawdziany), Usuń.

### 9.4 Edytor sprawdzianu (rozszerzenie M1)
- Sekcja „Materiały” zgodnie z punktem 8 — tylko przy edycji istniejącego sprawdzianu (nowy nie ma jeszcze identyfikatora do powiązania; można dodać materiały po zapisie).

## 10. Uprawnienia i konfiguracja

- `NSCameraUsageDescription` w `Config/Info.plist` (po polsku): do zdjęć zeszytu i skanowania. Bez zgody pozycje „Zrób zdjęcie” i „Skanuj dokument” pokazują informację i przycisk do Ustawień.
- Galeria przez `PhotosPicker` (bez zgody na całą bibliotekę), pliki przez `fileImporter` — bez dodatkowych uprawnień.
- Aparat i skaner niedostępne na symulatorze: przyciski pokazują informację zamiast awarii (`UIImagePickerController.isSourceTypeAvailable`, `VNDocumentCameraViewController.isSupported`).

## 11. Testy

Swift Testing, w pamięci (`TestSupport`, `Persistence.makeInMemoryContainer()`). Porównania list w `#expect` jako osobne stałe z jawnym typem (lekcja z CI M1).

Minimalny zestaw:
- `MaterialRepository`: dodanie notatki, zdjęcia i PDF; edycja; usunięcie (sprawdziany i przedmiot zostają); przypisanie do kilku sprawdzianów i odpięcie; filtr po przedmiocie i sprawdzianie; kolejność od najnowszego; `pendingRecognition`; `storeRecognitionResult` nie nadpisuje tekstu po `correctRecognizedText` (reguła z punktu 6); walidacja tytułu.
- `MaterialSearch`: wielkość liter, polskie znaki, wiele słów (wszystkie muszą wystąpić), trafienie w każdym z trzech pól, pusty wynik, fragment wokół trafienia.
- `SubjectRepository`: odmowa usunięcia przedmiotu z materiałami.
- `ImageProcessing`: zdjęcie 4000×3000 zmniejszone do 2560 na dłuższym boku, proporcje zachowane, małe zdjęcie bez powiększania.
- `PDFProcessing`: złożenie 3 obrazów w PDF z 3 stronami; odczyt warstwy tekstowej z PDF wygenerowanego w teście; odrzucenie pliku ponad limit.
- `TextRecognizer`: obraz z wyrenderowanym tekstem („Fotosynteza zachodzi w chloroplastach”) daje tekst zawierający te słowa (test na symulatorze; jeśli Vision na symulatorze CI okaże się niestabilne, oznaczyć test `.enabled(if:)` z uzasadnieniem w punkcie 15, a nie usuwać).
- Testy M0 i M1 dalej przechodzą.

Po każdym kroku: `./scripts/test.sh` z katalogu `KorepetytorAI` przechodzi bez ostrzeżeń.

## 12. Kolejność implementacji

Każdy krok kończy się zielonymi testami i osobnym commitem. Nie łącz kroków.

1. `MaterialRepository`, `MaterialSearch`, rozszerzenie zasady usuwania przedmiotu, testy (punkty 5, 7, 8, 11).
2. Lista materiałów z filtrem, wyszukiwaniem i notatkami (dodawanie, edycja, podgląd, usuwanie) (9.1, 9.2 notatka, 9.3 notatka).
3. Zdjęcia z galerii i aparatu: zmniejszanie, zapis, podgląd z powiększaniem, miniatury (9.2, 9.3, 10).
4. Import PDF i skaner dokumentów: składanie PDF, podgląd PDFKit (9.2, 9.3).
5. Rozpoznawanie tekstu: Vision, warstwa tekstowa PDF, kolejka w tle, stany, ręczna poprawa (punkt 6, 9.3).
6. Powiązanie ze sprawdzianami: wybór w edytorze materiału, sekcja „Materiały” w edytorze sprawdzianu (8, 9.4).
7. Sprawdzenie kryteriów: zdjęcie i PDF na obu urządzeniach, wyszukiwanie po słowie z treści, czas dodania zdjęcia, pamięć i płynność listy (Instruments) przy ok. 100 materiałach.

## 13. Sprawdzenie na urządzeniach (odbiór M2)

Na iPhonie 14 i iPadzie, to samo konto iCloud:
- [ ] Zdjęcie zeszytu zrobione na iPhonie jest widoczne na iPadzie (z podglądem), i odwrotnie.
- [ ] PDF zaimportowany na iPadzie jest widoczny na iPhonie, strony się przewijają.
- [ ] Skan trzech kartek tworzy jeden PDF z trzema stronami.
- [ ] Słowo z treści zdjęcia (drukowany tekst lub wyraźne pismo) i z PDF znajduje materiał, także wpisane bez polskich znaków.
- [ ] Ręczna poprawa rozpoznanego tekstu na jednym urządzeniu jest widoczna na drugim i nie zostaje nadpisana.
- [ ] Dodanie zdjęcia zeszytu zajmuje mniej niż 20 sekund.
- [ ] Materiał przypisany do sprawdzianu widać w edytorze tego sprawdzianu.
- [ ] Przedmiotu z materiałami nie da się usunąć; komunikat podaje liczby.
- [ ] Bez zgody na aparat działa galeria, PDF i notatki; aparat pokazuje informację.
- [ ] Tryb offline: dodanie, podgląd i rozpoznawanie działają w trybie samolotowym; synchronizacja nadrabia po włączeniu sieci.
- [ ] Tryb ciemny i największy rozmiar tekstu nie psują ekranów.

## 14. Otwarte decyzje

Te punkty mają rekomendację, ale warto je potwierdzić przed kodem:

1. **Skan wielu stron.** Rekomendacja: jeden PDF (`kind = pdf`). Alternatywa: osobne zdjęcia na każdą stronę — prostsze, ale rozbija jedną notatkę na kilka materiałów.
2. **Jakość zdjęć.** Rekomendacja: najdłuższy bok 2560 px, JPEG 0,75 (czytelne dla Vision, ok. 1 MB, oszczędza miejsce w iCloud). Alternatywa: oryginał (lepszy dla AI w M4, 3–5 MB na zdjęcie).
3. **Usuwanie przedmiotu z materiałami.** Rekomendacja: blokada z komunikatem, jak dla sprawdzianów w M1. Przeniesienie materiałów — później.
4. **Miniatury.** Rekomendacja: generowane na urządzeniu i trzymane w pamięci podręcznej (`Caches`, klucz `id` + `updatedAt`), bez pola w schemacie. Alternatywa: pole `thumbnailData` w `SchemaV2`.
5. **Limit PDF.** Rekomendacja: 25 MB i rozpoznawanie Vision najwyżej 30 stron. Większe pliki to zwykle podręczniki, które w M4 i tak wymagałyby osobnego podejścia.
6. **Pismo odręczne.** Vision czyta je słabo. Rekomendacja: w M2 tylko komunikat i ręczna poprawa; czytanie przez Claude w M4 zgodnie z `architektura.md`.

Gdy któraś decyzja zmieni się w trakcie implementacji, zapisz to w punkcie 15 z datą, nie zmieniając reszty specyfikacji po cichu.

## 15. Decyzje wykonawcze

*(Uzupełniane w trakcie implementacji.)*
