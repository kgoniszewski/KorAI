# M2 Materiały — specyfikacja dla implementacji

Źródło nadrzędne: [`../../architektura.md`](../../architektura.md) (zasady projektowe, model danych, plan etapów).
Ta specyfikacja opisuje, co dokładnie ma powstać w etapie M2. Gdy coś tu jest sprzeczne z `architektura.md`, pierwszeństwo ma `architektura.md` i trzeba to zgłosić zamiast zgadywać.

Stan wyjściowy: M1 scalony do `main` ([kgoniszewski/KorAI#1](https://github.com/kgoniszewski/KorAI/pull/1)), testy jednostkowe przechodzą na symulatorach iPhone'a i iPada. Decyzje M1 (punkt 14 `M1-spec.md`) obowiązują dalej.

**Świadomy wyjątek od procesu:** `architektura.md` zamyka każdy etap testem na urządzeniach. Implementacja M2 może ruszyć przed zakończeniem odbioru M1 na urządzeniach (punkt 12 `M1-spec.md`), ale odbiór M1 musi się zakończyć przed odbiorem M2. Błędy znalezione przy odbiorze M1 mają pierwszeństwo przed krokami M2.

Wersja 2 (2026-11-16): po przeglądzie Fable 5.2. Zmiany względem wersji 1 są wpisane w treść; podsumowanie w punkcie 15.

## 1. Cel etapu

Uczennica robi zdjęcie zeszytu, skanuje kartkę albo dodaje PDF od nauczyciela, przypisuje materiał do przedmiotu i sprawdzianu, a potem znajduje go po słowie z treści. Tekst ze zdjęć i PDF-ów rozpoznaje się na urządzeniu, bez sieci. Wszystko synchronizuje się przez iCloud.

**Gotowe, gdy** (kryterium z `architektura.md`, M2):
- zdjęcie zeszytu i plik PDF są widoczne na obu urządzeniach,
- oba da się znaleźć po słowie z treści (z tekstu rozpoznanego na urządzeniu).

## 2. Zakres

### W zakresie
1. Notatki tekstowe: tworzenie, edycja, usuwanie.
2. Zdjęcia: aparat i galeria (do 10 zdjęć naraz, każde jako osobny materiał).
3. Skaner dokumentów (VisionKit): wiele stron zapisanych jako jeden PDF.
4. Import plików PDF (Pliki / iCloud Drive; rozszerzenie „Udostępnij” jest poza zakresem).
5. Podgląd: notatka, zdjęcie z powiększaniem, PDF z przewijaniem stron.
6. Rozpoznawanie tekstu na urządzeniu: Vision dla zdjęć i skanów, PDFKit dla PDF z warstwą tekstową, Vision dla stron PDF bez tekstu.
7. Ręczna poprawa i ręczne wpisanie rozpoznanego tekstu.
8. Przypisanie do przedmiotu (wymagane) i do sprawdzianów (opcjonalne, wiele).
9. Wyszukiwanie po tytule, treści notatki i rozpoznanym tekście, bez rozróżniania wielkości liter i polskich znaków.
10. Materiały sprawdzianu widoczne w edytorze sprawdzianu (z Planera i ekranu Dziś).
11. Informacja o pełnym iCloud na ekranie Profil.
12. Testy jednostkowe dla logiki (repozytorium, wyszukiwanie, kolejka rozpoznawania, przetwarzanie obrazów i PDF).

### Poza zakresem (nie implementować)
- AI: streszczenia (`summary` zostaje puste), czytanie odręcznych notatek przez Claude, quizy i fiszki (M4).
- Ocena jakości rozpoznania („słabe rozpoznanie”) — M4 (wymaga pola w `SchemaV2`, punkt 4).
- Rysowanie i Apple Pencil w notatkach, formatowanie tekstu (M7).
- Udostępnianie materiałów z innych aplikacji i eksport.
- Foldery, tagi, ulubione, przenoszenie materiałów między przedmiotami hurtem.
- Dopracowanie układu iPada (M7); na iPadzie M2 działa w tym samym układzie co M1.

## 3. Zasady projektowe, które obowiązują tutaj

- Materiał dodaje się szybko: pola opcjonalne nie blokują zapisu, tytuł powstaje automatycznie (punkt 9.2).
- **Przedmiot domyślny:** aktywny filtr przedmiotu na liście materiałów, a bez filtra ostatnio użyty przy materiale (`UserDefaults`, klucz `materials.lastSubjectID`, osobny od `planner.lastSubjectID`), o ile nadal istnieje. Bez żadnego przedmiotu „Zapisz” jest nieaktywne.
- Rozpoznawanie tekstu nie blokuje zapisu: materiał jest od razu widoczny, tekst dochodzi w tle.
- Słabe rozpoznanie nie jest błędem użytkowniczki. W sekcji „Rozpoznany tekst” jest stała podpowiedź, że tekst można poprawić ręcznie (pismo odręczne Vision czyta słabo); przy pustym wyniku — osobny komunikat.
- Wszystko działa offline. Brak zgody na aparat nie blokuje galerii, plików ani notatek.
- **Prywatność:** materiały nie opuszczają urządzenia poza iCloud (AI dopiero w M4). Zapisane zdjęcia i strony skanu nie zawierają metadanych EXIF (w tym lokalizacji GPS); orientacja jest „wypalona” w pikselach. Treść materiałów nie trafia do logów.
- **Wzorzec kodu jak w M1:** widoki czytają dane przez `@Query`, zapisują przez repozytoria z Core; logika bez UI jest w Core i ma testy. (`architektura.md` mówi o MVVM z `@Observable` — M1 przyjął ten uproszczony wariant i M2 go trzyma.)
- Kod po angielsku, teksty po polsku w `App/Localizable.xcstrings`, klucze z kropkami (`materials.…`).

## 4. Model danych

Schemat pozostaje `SchemaV1`. **Nie zmieniaj istniejących pól ani typów i nie dodawaj nowych pól** (ta sama przyczyna co decyzja M1 14.5: zmiana `SchemaV1` w miejscu przy podanym planie migracji grozi błędem 134504). Gdyby pole było naprawdę niezbędne, zatrzymaj się i dopisz je do listy długu poniżej.

Encje używane w M2: `StudyMaterial` (`Packages/Core/Sources/Core/Models/SchemaV1+School.swift`), `Subject`, `Assessment`.

| Pole `StudyMaterial` | Użycie w M2 |
| --- | --- |
| `kindRaw` | `note` (notatka), `photo` (jedno zdjęcie, JPEG), `pdf` (import PDF albo skan wielu stron — w M2 bez rozróżnienia) |
| `title` | wymagany po przycięciu spacji, max 80 znaków; tytuł automatyczny lub z nazwy pliku jest obcinany do 80 znaków, nie odrzucany |
| `content` | treść notatki; dla zdjęć i PDF pusta |
| `fileData` | JPEG dla `photo`, PDF dla `pdf`, `nil` dla `note`; `externalStorage`, synchronizowany jako zasób CloudKit |
| `recognizedText` | `nil` — nie rozpoznano; `""` — rozpoznano bez wyniku albo wyczyszczono ręcznie; tekst — wynik albo wpis ręczny; max 200 000 znaków (obcięcie) |
| `summary` | nieużywane w M2 (M4) |
| `subject` | wymagany przy zapisie z UI; w danych może być `nil` (synchronizacja, `.nullify`) |
| `assessments` | wiele-do-wielu, opcjonalne; tylko sprawdziany przedmiotu materiału (punkt 8) |

Stan rozpoznawania (w kolejce, w trakcie, błąd) **nie jest zapisywany w bazie** — trzyma go koordynator w pamięci (punkt 6), a liczniki prób lokalnie w `UserDefaults`.

### Dług `SchemaV2` (jedno miejsce dla wszystkich etapów)
- `Assessment.reminderEnabled: Bool = true` — decyzja M1 14.5.
- `StudyMaterial.recognizedTextSource` (auto / ręczne) — usuwa ryzyko nadpisania poprawki (punkt 6, ograniczenie 16.2).
- `StudyMaterial.recognitionConfidence: Double?` — potrzebne w M4 do wykrycia słabego rozpoznania (krok 2 przetwarzania w `architektura.md`).
- Ewentualnie `StudyMaterial.thumbnailData` — tylko jeśli miniatury lokalne okażą się za wolne (decyzja 14.4).

Wartości enumu `MaterialKind` są w `Core/Models/Enums.swift`. Nie zmieniaj ich `rawValue`.

## 5. Warstwa Core (bez UI, testowalna)

Nowe pliki w `Packages/Core/Sources/Core/`:

### `Repositories/MaterialRepository.swift`
- `materials(subject: Subject?, assessment: Assessment?) throws -> [StudyMaterial]` — od najnowszego (`createdAt`). `nil` w parametrze oznacza „bez filtra”. Materiały z `subject == nil` są zwracane tylko bez filtra przedmiotu.
- `search(_ query: String, subject: Subject?) throws -> [MaterialSearchResult]` — punkt 7.
- `addNote(title:content:subject:assessments:)`, `addPhoto(imageData:title:subject:assessments:)`, `addPDF(data:title:subject:assessments:)` — zwracają materiał. Dane obrazu i PDF przychodzą już przetworzone (punkt `ImageProcessing`, `PDFProcessing`).
- `update(_:title:content:subject:assessments:)` — **zmiana przedmiotu odpina sprawdziany innego przedmiotu** (także te przekazane w `assessments`).
- `delete(_:)` — usuwa materiał; sprawdziany i przedmiot zostają.
- `material(withID:) throws -> StudyMaterial?`.
- `pendingRecognition(createdBefore: Date?) throws -> [StudyMaterial]` — `photo`/`pdf` z `recognizedText == nil` **i `fileData != nil`**; z datą — tylko utworzone przed nią (reguła 10 minut, punkt 6).
- `storeRecognitionResult(materialID: UUID, text: String) throws -> Bool` — wynik automatyczny: odczytuje rekord po ID tuż przed zapisem, zapisuje tylko przy `recognizedText == nil`, obcina do 200 000 znaków; zwraca `false`, gdy rekordu nie ma albo ma już tekst.
- `correctRecognizedText(_:text:)` — ręczna poprawa lub wpis; zapisuje zawsze (puste pole zapisuje `""`, nigdy `nil`).
- Walidacja tytułu: `MaterialRepositoryError.emptyTitle`, `.titleTooLong` (jak `SubjectRepository`). Zapis bez przedmiotu: `.missingSubject`.

### `Materials/MaterialSearch.swift`
Czysta funkcja dopasowania i typ wyniku:
```swift
public struct MaterialSearchResult { public let material: StudyMaterial; public let snippet: String? }
```
- Normalizacja: wspólna funkcja wyciągnięta z `SubjectCatalog.normalizedKey` (bez wielkości liter i znaków diakrytycznych) **plus jawna zamiana „ł”/„Ł” na „l”/„L”** (ta litera nie ma rozkładu Unicode, więc `diacriticInsensitive` jej nie zmienia — sprawdzić testem i zostawić zamianę niezależnie od wyniku).
- Zapytanie dzielone na słowa; **każde słowo musi wystąpić jako podciąg** („foto” znajduje „fotosynteza”) w tytule, treści lub rozpoznanym tekście (słowa mogą być w różnych polach).
- Puste zapytanie (po przycięciu) zwraca pełną listę bez fragmentów.
- Fragment (`snippet`): do 80 znaków wokół pierwszego trafienia pierwszego słowa, białe znaki zwinięte do pojedynczej spacji, „…” na obciętych końcach; `nil`, gdy trafienie jest tylko w tytule. Wycinany z **oryginalnego** tekstu przez mapowanie pozycji znak po znaku (normalizacja może zmienić długość tekstu), nie przez indeks w tekście znormalizowanym.
- Założenie wydajności: do 500 materiałów, wyszukiwanie poniżej 100 ms na iPhonie 14. Znormalizowany tekst materiału może być trzymany w pamięci podręcznej (klucz `id` + `updatedAt`).

### `Materials/ImageProcessing.swift`
- Oparte na **ImageIO** (`CGImageSourceCreateThumbnailAtIndex` z `kCGImageSourceThumbnailMaxPixelSize` i `kCGImageSourceCreateThumbnailWithTransform`), bez UIKit: nie dekoduje pełnej bitmapy, działa poza głównym aktorem, kompiluje się też na macOS (pakiet `Core` deklaruje macOS).
- `downscaledJPEG(from data: Data, maxPixelSize: Int = 2560, quality: Double = 0.75) throws -> Data` — orientacja wypalona w pikselach, **bez EXIF/GPS** (zapis przez `CGImageDestination` bez kopiowania metadanych), małe zdjęcie nie jest powiększane.
- `thumbnail(from data: Data, maxPixelSize: Int) throws -> CGImage`.
- Rozmiary liczone w **pikselach**, nie punktach.

### `Materials/PDFProcessing.swift`
- `makePDF(fromJPEGPages: [Data]) throws -> Data` — skan: strony najpierw przez `downscaledJPEG` (2560 px, 0,75), potem składane do PDF z obrazem JPEG (bez ponownej kompresji bezstratnej; np. `PDFPage(image:options:)` z `compressionQuality` 0,75 albo rysowanie JPEG przez `CGContext` PDF). Wynik ponad limit rozmiaru → błąd „podziel na dwa skany”.
- `validate(data:) throws -> PDFInfo` — odrzuca z osobnymi błędami: dokument, którego `PDFDocument(data:)` nie otwiera (`.unreadable`), zabezpieczony hasłem (`isLocked`, `.locked`), bez stron (`.empty`); zwraca liczbę stron.
- `textLayer(of data:) -> [String?]` — tekst każdej strony (`page.string`); strona „bez tekstu”, gdy ma mniej niż 20 znaków niebiałych (skany miewają warstwę z samym numerem strony) → `nil`.
- `renderPage(_ index: Int, of data: Data, maxPixelSize: Int = 2560) throws -> CGImage` — białe tło, jedna strona naraz.
- `thumbnail(of data: Data, maxPixelSize:) throws -> CGImage` — pierwsza strona.
- `PDFDocument` i `PDFPage` nie przekraczają granicy aktora: każda funkcja przyjmuje `Data` i zwraca wartości.

### `Materials/TextRecognizer.swift`
- `public protocol TextRecognizing: Sendable { func recognizeText(in image: CGImage) async throws -> String }` — wstrzykiwany, żeby kolejkę dało się testować z fałszywym rozpoznawaczem.
- Implementacja `VisionTextRecognizer` na **`RecognizeTextRequest`** (Vision, API async z iOS 18; nie `VNRecognizeTextRequest`, które wymaga obejść dla typów nie-`Sendable` w Swift 6), poziom `accurate`, korekta językowa włączona.
- **Języki:** preferowane `pl-PL`, `en-US`, `fr-FR` (polski, angielski, dwa francuskie), przecięte w czasie działania z `supportedRecognitionLanguages`; gdy przecięcie jest puste — automatyczne wykrywanie języka. Nie wpisywać języków na sztywno bez tej kontroli (obsługa polskiego zależy od wersji systemu — sprawdzić na iOS 18 i na symulatorze CI).
- `MaterialTextExtractor` — łączy powyższe: dla `photo` rozpoznaje obraz; dla `pdf` bierze warstwę tekstową, a strony bez tekstu przez Vision, **najwyżej 30 stron wymagających Vision** (kolejne pomija i zwraca informację o części rozpoznanych stron). Wynik: strony oddzielone pustą linią, obcięty do 200 000 znaków.

### `Materials/RecognitionQueue.swift`
Logika kolejki bez UI (wzorzec pary `ReminderPlanner` / `ReminderScheduler` z M1), opisana w punkcie 6. Przyjmuje `TextRecognizing`, repozytorium (przez domknięcia na `MainActor`) i `UserDefaults` dla liczników prób.

### `Repositories/SubjectRepository.swift`
- Nowy przypadek `SubjectRepositoryError.hasContent(assessments: Int, materials: Int)` **zastępuje** `hasAssessments(count:)` z M1. Zablokowane, gdy którakolwiek liczba > 0. Testy M1 i komunikat w `SubjectListView` trzeba dostosować (komunikat podaje obie liczby, z odmianą).

### Limity (stałe w Core, przekazywane jako parametry funkcji, żeby testy nie tworzyły plików 25 MB)
- PDF i skan: maksymalnie 25 MB; rozmiar importowanego pliku sprawdzany **przed wczytaniem** (`URLResourceValues.fileSize`).
- Zdjęcie i strona skanu: 2560 px na dłuższym boku, JPEG 0,75 (zwykle 0,5–1,5 MB).
- Vision dla PDF: 30 stron bez warstwy tekstowej.
- `recognizedText`: 200 000 znaków.
- Galeria: 10 zdjęć w jednej paczce.

Każda zmiana zapisuje `updatedAt` (`touch()`).

## 6. Rozpoznawanie tekstu

### Kolejka
- Jeden koordynator `@MainActor @Observable` w warstwie aplikacji (`App/RecognitionCoordinator.swift`), oparty na `RecognitionQueue` z Core: **jedno aktywne zadanie naraz** i zbiór ID w kolejce. Ponowne skanowanie zaległych tylko dopisuje brakujące ID — nie uruchamia drugiego przetwarzania tego samego materiału.
- **Kiedy rozpoznaje:**
  - od razu po dodaniu zdjęcia, skanu lub PDF — **tylko na urządzeniu, które dodało materiał**;
  - przy starcie, po powrocie na pierwszy plan i po zmianach z iCloud (z opóźnieniem 2 s jak w M1) — zaległe materiały (`pendingRecognition(createdBefore: teraz − 10 min)`), np. gdy urządzenie dodające przerwało rozpoznawanie. Okno 10 minut zmniejsza szansę, że drugie urządzenie rozpozna materiał równolegle z pierwszym.
  - Zapis własnego wyniku może wywołać powiadomienie o zmianie magazynu; to tylko ponowny skan, który nic nie znajdzie (wynik już zapisany) — nie może wywołać pętli.
- **Izolacja:** `ModelContext` i modele zostają na `MainActor`. Do funkcji `nonisolated async` idzie `Data` i identyfikator, wraca `String`. Odczyt `fileData` (do 25 MB) na głównym wątku jest dopuszczalny w M2, ale do zmierzenia (punkt 12, krok 3). Rozpoznawanie owinięte w `beginBackgroundTask`, bo 30 stron trwa dłużej niż przejście aplikacji w tło.
- **Zapis wyniku:** `storeRecognitionResult(materialID:text:)` — ponowny odczyt rekordu tuż przed zapisem; zapis tylko przy `recognizedText == nil`. Usunięcie materiału w trakcie rozpoznawania anuluje zadanie (albo wynik jest odrzucony, bo rekordu nie ma).
- **Błąd** (Vision rzuca, PDF uszkodzony, brak pliku): materiał trafia do zbioru nieudanych w tej sesji i nie jest ponawiany do następnego startu aplikacji. Licznik prób w `UserDefaults` (klucz `materials.recognitionAttempts`, słownik ID → liczba, czyszczony przy usunięciu materiału jak `ReminderPreferences`); **po 3 nieudanych próbach zapisujemy `""`** i materiał wychodzi z kolejki na stałe (można wpisać tekst ręcznie).

### Stany w UI
Stan pochodzi z koordynatora, nie z samego `recognizedText == nil`:

| Stan | Warunek | Tekst |
| --- | --- | --- |
| w kolejce | ID w kolejce | „Czeka na rozpoznanie tekstu” |
| rozpoznaję | aktywne zadanie | „Rozpoznaję tekst…” |
| nie udało się | ID w zbiorze nieudanych | „Nie udało się rozpoznać tekstu” + „Spróbuj ponownie” |
| brak tekstu | `recognizedText == ""` | „Nie znaleziono tekstu. Możesz go wpisać ręcznie.” |
| część stron | PDF z pominiętymi stronami (informacja z ostatniego rozpoznania w tej sesji) | „Rozpoznano tekst z części stron” |
| gotowe | tekst | sam tekst |
| nierozpoznane | `nil`, poza kolejką (np. materiał z drugiego urządzenia młodszy niż 10 min) | „Tekst zostanie rozpoznany wkrótce” |

### Konflikt poprawki ręcznej z wynikiem automatycznym
Warunek „nadal `nil`” jest sprawdzany tylko lokalnie. Jeśli urządzenie B ma materiał z `nil` i jest offline, a A w tym czasie zapisze poprawkę ręczną, późniejszy wynik automatyczny z B może po synchronizacji wygrać (scalanie `NSPersistentCloudKitContainer` nie gwarantuje, które pole przeważy; może też dotknąć innych pól tego rekordu — do sprawdzenia na urządzeniach). Bez pola w schemacie da się to tylko ograniczyć (reguły „rozpoznaje urządzenie dodające” i „10 minut”). Pełne rozwiązanie: `recognizedTextSource` w `SchemaV2`. Wyniki Vision mogą się różnić między wersjami systemu, więc równoległe rozpoznanie nie jest „z definicji nieszkodliwe”.

## 7. Wyszukiwanie

- Pole wyszukiwania na liście materiałów (`.searchable`), wynik na bieżąco z opóźnieniem 250 ms.
- Reguły dopasowania i fragmentu — punkt 5 (`MaterialSearch`).
- Filtr przedmiotu działa razem z wyszukiwaniem.
- **Lista i wyszukiwanie nigdy nie czytają `material.fileData`.** Lista pobiera dane przez `FetchDescriptor.propertiesToFetch` bez `fileData` (albo równoważnie — sprawdzone pomiarem). Leniwe ładowanie `externalStorage` w SwiftData nie jest udokumentowane, dlatego pomiar jest w kroku 3, nie na końcu (punkt 12).

## 8. Przedmioty i sprawdziany

- **Usuwanie przedmiotu:** blokada, gdy ma sprawdziany lub materiały (`hasContent`); komunikat podaje obie liczby. Rozszerza decyzję M1 14.2. Blokada jest lokalna: drugie urządzenie może w tym samym czasie dodać materiał, a po synchronizacji usunięcia powstanie materiał z `subject == nil` — to oczekiwane (ograniczenie 16.3).
- **Materiał bez przedmiotu** (`subject == nil`): widoczny tylko bez filtra, jako „Bez przedmiotu” (szary, jak M1 14.16); przy edycji trzeba wybrać przedmiot przed zapisem.
- **Spójność przedmiot ↔ sprawdziany:**
  - zmiana przedmiotu materiału odpina sprawdziany innego przedmiotu (repozytorium, punkt 5);
  - zmiana przedmiotu sprawdzianu (edytor M1) nie rusza materiałów; edytor materiału pokazuje wtedy już przypisane sprawdziany także spoza bieżącego przedmiotu, z możliwością odpięcia (bez możliwości przypięcia nowych spoza przedmiotu).
- Usunięcie sprawdzianu nie usuwa materiałów (relacja `.nullify` z M0).
- Edytor materiału pozwala wybrać sprawdziany przedmiotu materiału: najpierw nadchodzące, potem minione (najwyżej 10 ostatnich).

## 9. Ekrany

Każdy ekran korzysta z komponentów `DesignSystem`. Bez nowych kolorów poza paletą. Zastępczy ekran Materiały z M0 jest zastępowany.

**Prezentacje:** na każdym ekranie jeden stan `enum` dla aktywnego arkusza / importu / aparatu, a modyfikatory (`sheet`, `fileImporter`, `fullScreenCover`) przypięte do korzenia ekranu, nie do pozycji `Menu` w pasku narzędzi (prezentacja z `Menu` i kilka `fileImporter` na jednym widoku bywają zawodne).

### 9.1 Lista materiałów
- Pasek narzędzi: filtr przedmiotu (jak w Planerze), przycisk „+” z menu: Notatka, Zrób zdjęcie, Skanuj dokument, Wybierz z galerii, Importuj PDF.
- Lista od najnowszego; wiersz: miniatura (notatka — ikona), tytuł, przedmiot, data, ikona rodzaju, stan rozpoznawania (punkt 6); w trybie wyszukiwania fragment z trafieniem.
- Przesunięcie w lewo: usuń (z potwierdzeniem).
- Stan pusty: `EmptyState` z zachętą i przyciskiem dodania; brak wyników wyszukiwania — osobny komunikat.
- **Miniatury:** generowane leniwie przy pojawieniu się wiersza, poza głównym wątkiem, najwyżej 2 naraz; pamięć podręczna w `Caches/Thumbnails/<id>.jpg` (klucz: samo `id`, bo plik materiału w M2 się nie zmienia) plus pamięć operacyjna; plik usuwany przy `delete`.

### 9.2 Dodawanie
- **Tytuł automatyczny** tworzy warstwa aplikacji (teksty są w `App/Localizable.xcstrings`): „Notatka 16 lis”, „Zdjęcie 16 lis”, „Skan 16 lis”; przy kilku zdjęciach z jednej paczki numer: „Zdjęcie 16 lis (2)” (numeracja tylko w obrębie paczki). PDF: tytuł z nazwy pliku bez rozszerzenia, obcięty do 80 znaków.
- **Notatka:** edytor (tytuł, przedmiot, sprawdziany, treść wieloliniowa).
- **Galeria:** `PhotosPicker` z filtrem `.images`, `maxSelectionCount` 10, przetwarzanie zdjęć po kolei (`downscaledJPEG`), potem arkusz z przedmiotem, sprawdzianami i tytułem oraz „Zapisz”.
- **Aparat:** `UIImagePickerController` (`.camera`), dalej jak galeria.
- **Skaner:** `VNDocumentCameraViewController`; po zakończeniu ten sam arkusz, wynik jako jeden PDF (`makePDF`).
- **PDF:** `fileImporter` z typem PDF: `startAccessingSecurityScopedResource()` z `defer stopAccessing…`, sprawdzenie rozmiaru przed wczytaniem, odczyt przez `NSFileCoordinator` poza głównym wątkiem (plik z iCloud Drive może nie być jeszcze pobrany), `validate(data:)`, osobne komunikaty dla błędów odczytu, hasła, pustego i zbyt dużego pliku.
- **Cel:** zdjęcie zeszytu w mniej niż 20 sekund — od stuknięcia „+” do pojawienia się materiału na liście (bez czasu rozpoznawania).

### 9.3 Podgląd materiału
- Wejście: push w stosie nawigacji listy materiałów.
- Notatka: tekst z możliwością edycji.
- Zdjęcie: powiększanie gestem i podwójnym stuknięciem.
- PDF: `PDFView` (PDFKit) w opakowaniu SwiftUI, przewijanie stron.
- Sekcja „Rozpoznany tekst”: tekst do zaznaczenia i kopiowania, stan (punkt 6), stała podpowiedź o pismie odręcznym, przycisk **„Popraw” dostępny zawsze** — także przy `nil` i `""` (wpis ręczny); wyczyszczenie tekstu zapisuje `""`.
- Informacje: przedmiot, sprawdziany (stuknięcie otwiera edytor sprawdzianu jako arkusz — tylko gdy podgląd nie został otwarty z edytora sprawdzianu, patrz 9.4), data dodania.
- Pasek narzędzi: Edytuj (tytuł, przedmiot, sprawdziany), Usuń.
- **Usunięcie na drugim urządzeniu:** podgląd i edytor poprawki obserwują rekord po `id` (`@Query` z predykatem) i zamykają się, gdy rekord zniknie (odczyt pól usuniętego modelu SwiftData kończy się awarią).

### 9.4 Edytor sprawdzianu (rozszerzenie M1)
- Sekcja „Materiały” tylko przy edycji istniejącego sprawdzianu (nowy nie ma jeszcze identyfikatora do powiązania; materiały można dodać po zapisie).
- Lista przypisanych materiałów; stuknięcie otwiera podgląd **jako push w stosie nawigacji arkusza edytora**; w tak otwartym podglądzie sprawdziany nie są klikalne (bez zapętlenia edytor → podgląd → edytor).
- „Dodaj materiał” otwiera dodawanie z przedmiotem i sprawdzianem już wybranymi; używa **zapisanego** przedmiotu sprawdzianu i jest nieaktywne, gdy w edytorze jest niezapisana zmiana przedmiotu.

### 9.5 Profil (rozszerzenie M1)
- W sekcji iCloud informacja o pełnym miejscu w iCloud: obserwacja `NSPersistentCloudKitContainer.eventChangedNotification`, błąd `CKError.quotaExceeded` przy eksporcie → „Brak miejsca w iCloud — nowe materiały nie synchronizują się” (z podpowiedzią, gdzie zwolnić miejsce). Bez tego wysyłanie zdjęć przestaje działać po cichu (darmowe konto ma 5 GB).

## 10. Uprawnienia i konfiguracja

- `NSCameraUsageDescription` w `Config/Info.plist` (po polsku): do zdjęć zeszytu i skanowania.
- Stan zgody: `AVCaptureDevice.authorizationStatus(for: .video)`. `.notDetermined` — prośba przy pierwszym użyciu aparatu lub skanera; `.denied` — informacja i przycisk do Ustawień; `.restricted` (np. Czas przed ekranem) — informacja bez przycisku.
- Galeria przez `PhotosPicker` (bez zgody na całą bibliotekę), pliki przez `fileImporter` — bez dodatkowych uprawnień.
- Aparat i skaner niedostępne na symulatorze: informacja zamiast awarii (`UIImagePickerController.isSourceTypeAvailable(.camera)`, `VNDocumentCameraViewController.isSupported`).

## 11. Testy

Swift Testing, w pamięci (`TestSupport`, `Persistence.makeInMemoryContainer()`). Porównania list w `#expect` jako osobne stałe z jawnym typem (lekcja z CI M1).

Minimalny zestaw:
- **`MaterialRepository`:** dodanie notatki, zdjęcia i PDF; edycja; **zmiana przedmiotu odpina sprawdziany innego przedmiotu**; usunięcie (sprawdziany i przedmiot zostają); przypisanie do kilku sprawdzianów i odpięcie; filtr po przedmiocie i sprawdzianie; materiał bez przedmiotu tylko bez filtra; kolejność od najnowszego; `pendingRecognition` (pomija `fileData == nil`, reguła `createdBefore`); `storeRecognitionResult` nie nadpisuje tekstu po `correctRecognizedText` i zwraca `false` dla usuniętego materiału; obcięcie do 200 000 znaków; walidacja tytułu i brak przedmiotu.
- **`MaterialSearch`:** wielkość liter; polskie znaki **z „ł”** („zolw” → „żółw”, „lodz” → „Łódź”); podciąg („foto” → „fotosynteza”); wiele słów w różnych polach; trafienie w każdym z trzech pól; puste zapytanie; brak wyniku; fragment z „ł” i ze zmianą długości po normalizacji (fragment z oryginalnego tekstu); fragment `nil` przy trafieniu tylko w tytule.
- **`RecognitionQueue`** z fałszywym rozpoznawaczem: jedno zadanie naraz; ponowny skan nie dubluje materiału w kolejce; pominięcie zapisu, gdy w trakcie przyszła poprawka ręczna; usunięty materiał w trakcie; błąd → zbiór nieudanych, brak ponowienia w sesji; po 3 nieudanych próbach zapis `""`; reguła 10 minut.
- **`SubjectRepository`:** odmowa usunięcia przedmiotu z materiałami i ze sprawdzianami (`hasContent` z obiema liczbami); testy M1 dostosowane do nowego przypadku błędu.
- **`ImageProcessing`:** obraz 4000×3000 (tworzony ze `scale = 1`) zmniejszony do 2560 na dłuższym boku, mierzony w pikselach przez `CGImageSource`; proporcje zachowane; małe zdjęcie bez powiększania; **brak EXIF GPS** w wyniku (wejście z wpisanym GPS).
- **`PDFProcessing`:** 3 strony 2560×1920 dają PDF z 3 stronami **poniżej 5 MB**; warstwa tekstowa z PDF wygenerowanego w teście (porównanie `contains` po normalizacji białych znaków); PDF mieszany (strona z tekstem i bez) → `nil` dla strony bez tekstu; PDF z hasłem, uszkodzony i pusty — właściwe błędy; limit rozmiaru i stron przez parametry (bez pliku 25 MB).
- **`VisionTextRecognizer` (prawdziwe Vision)** — osobny test, `.serialized`, `.timeLimit(.minutes(1))`, `.enabled(if:)` wyłączający go, gdy ustawiona jest zmienna środowiskowa `CI` (modele Vision na maszynach wirtualnych GitHub Actions bywają niestabilne, a `scripts/test.sh` uruchamia iPhone'a i iPada równolegle). Asercja po normalizacji, bez wymagania polskich znaków: obraz z tekstem „Fotosynteza zachodzi w chloroplastach” zawiera „fotosynteza” i „chloroplastach”. Uruchamiany lokalnie na Macu.
- Testy M0 i M1 dalej przechodzą. Leniwego ładowania `fileData` nie da się sprawdzić w kontenerze w pamięci — zostaje pomiar na urządzeniu (punkt 12).
- CI używa najnowszego Xcode i symulatora (iOS 26), a minimum to iOS 18 — kolejny powód, by języki Vision sprawdzać w czasie działania.

Po każdym kroku: `./scripts/test.sh` z katalogu `KorepetytorAI` przechodzi bez ostrzeżeń.

## 12. Kolejność implementacji

Każdy krok kończy się zielonymi testami i osobnym commitem. Nie łącz kroków.

1. `MaterialRepository`, `MaterialSearch`, `SubjectRepositoryError.hasContent` (z dostosowaniem M1), testy (punkty 5, 7, 8, 11).
2. Lista materiałów z filtrem, wyszukiwaniem i notatkami (dodawanie, edycja, podgląd, usuwanie, obserwacja usunięcia) (9.1, 9.2 notatka, 9.3 notatka).
3. `ImageProcessing`, zdjęcia z galerii i aparatu, podgląd z powiększaniem, miniatury, uprawnienia (9.2, 9.3, 10). **Pomiar na urządzeniu:** 100 zdjęć, przewijanie listy i wyszukiwanie — przyrost pamięci poniżej 50 MB, płynne przewijanie; potwierdzenie, że lista nie ładuje `fileData`. Wynik zapisać w punkcie 15.
4. `PDFProcessing`, import PDF i skaner dokumentów, podgląd PDFKit (9.2, 9.3).
5. Rozpoznawanie tekstu: `TextRecognizing`, `VisionTextRecognizer`, `MaterialTextExtractor`, `RecognitionQueue`, koordynator, stany w UI, ręczna poprawa (punkt 6, 9.3).
6. Powiązanie ze sprawdzianami: wybór w edytorze materiału, sekcja „Materiały” w edytorze sprawdzianu, nawigacja (8, 9.4).
7. Informacja o pełnym iCloud na Profilu (9.5).
8. Sprawdzenie kryteriów: zdjęcie i PDF na obu urządzeniach, wyszukiwanie po słowie z treści, czas dodania zdjęcia, odbiór z punktu 13.

## 13. Sprawdzenie na urządzeniach (odbiór M2)

Na iPhonie 14 i iPadzie, to samo konto iCloud. Zasoby (zdjęcia, PDF) synchronizują się z opóźnieniem — do kilku minut, przy aplikacji otwartej na obu urządzeniach.
- [ ] Zdjęcie zeszytu zrobione na iPhonie jest widoczne na iPadzie (z podglądem), i odwrotnie.
- [ ] PDF zaimportowany na iPadzie jest widoczny na iPhonie, strony się przewijają.
- [ ] Skan trzech kartek tworzy jeden PDF z trzema stronami (poniżej 5 MB).
- [ ] Słowo z treści zdjęcia (drukowany tekst lub wyraźne pismo) i z PDF znajduje materiał, także wpisane bez polskich znaków (w tym „ł”).
- [ ] Ręczna poprawa rozpoznanego tekstu na jednym urządzeniu jest widoczna na drugim i nie zostaje nadpisana — **przy obu urządzeniach online** (wariant offline: znane ograniczenie 16.2).
- [ ] Dodanie zdjęcia zeszytu zajmuje mniej niż 20 sekund (do pojawienia się na liście).
- [ ] Materiał przypisany do sprawdzianu widać w edytorze tego sprawdzianu; podgląd z edytora wraca do edytora.
- [ ] Przedmiotu z materiałami nie da się usunąć; komunikat podaje liczby.
- [ ] Bez zgody na aparat działa galeria, PDF i notatki; aparat pokazuje informację.
- [ ] Tryb offline: dodanie, podgląd i rozpoznawanie działają w trybie samolotowym; synchronizacja nadrabia po włączeniu sieci.
- [ ] Zdjęcie z galerii z lokalizacją: zapisany materiał nie ma lokalizacji w metadanych.
- [ ] 100 materiałów: lista przewija się płynnie, wyszukiwanie odpowiada od razu (wynik pomiaru z kroku 3).
- [ ] Tryb ciemny i największy rozmiar tekstu nie psują ekranów.

## 14. Decyzje (rozstrzygnięte po przeglądzie Fable 5.2)

1. **Skan wielu stron:** jeden PDF (`kind = pdf`), strony zmniejszone do 2560 px i skompresowane JPEG 0,75, limit 25 MB (powyżej: komunikat „podziel na dwa skany”).
2. **Jakość zdjęć:** 2560 px na dłuższym boku, JPEG 0,75, bez EXIF; to samo dla stron skanu. Oryginał nie pomógłby w M4 (API Claude i tak zmniejsza obrazy — potwierdzić w dokumentacji przy M4).
3. **Usuwanie przedmiotu z materiałami:** blokada z komunikatem (`hasContent` z obiema liczbami), jak dla sprawdzianów w M1. Przeniesienie materiałów — później.
4. **Miniatury:** generowane na urządzeniu, pamięć podręczna w `Caches` z kluczem **`id`** (bez `updatedAt` — plik w M2 się nie zmienia, a `touch()` przy zmianie tytułu lub zapisie tekstu niepotrzebnie unieważniałby miniaturę); leniwie, poza głównym wątkiem, najwyżej 2 naraz, usuwane przy `delete`. Bez pola w schemacie.
5. **Limity PDF:** 25 MB (sprawdzane przed wczytaniem), Vision najwyżej 30 stron bez warstwy tekstowej, strona „bez tekstu” poniżej 20 znaków niebiałych, tekst do 200 000 znaków; UI informuje o rozpoznaniu części stron.
6. **Pismo odręczne:** w M2 bez oceny jakości — stała podpowiedź w sekcji „Rozpoznany tekst” i komunikat przy pustym wyniku; czytanie przez Claude w M4.

## 15. Decyzje wykonawcze

### Zmiany w wersji 2 (przegląd Fable 5.2, 2026-11-16)
- Stany rozpoznawania z koordynatora w pamięci zamiast samego `recognizedText == nil`; limit 3 prób; kolejka testowalna w Core z wstrzykiwanym `TextRecognizing` (punkty 5, 6, 11).
- Ograniczenie konfliktu poprawki ręcznej: rozpoznaje urządzenie dodające, zaległe po 10 minutach, odczyt rekordu przed zapisem; ryzyko offline jako znane ograniczenie; `recognizedTextSource` do `SchemaV2` (punkty 4, 6, 13).
- Spójność przedmiot ↔ sprawdziany, materiały bez przedmiotu, `hasContent` zamiast `hasAssessments` (punkty 5, 8).
- Przypadki brzegowe PDF, parametry renderowania i kompresji skanu, limit tekstu 200 000 znaków (punkty 5, 14).
- Kontrakt wyszukiwania: `MaterialSearchResult` z fragmentem, podciąg, puste zapytanie, jawna obsługa „ł” (punkty 5, 7, 11).
- ImageIO zamiast UIKit, brak EXIF, `RecognizeTextRequest` z językami pl/en/fr sprawdzanymi w czasie działania, izolacja aktorów i `beginBackgroundTask`.
- Pomiar pamięci listy przeniesiony do kroku 3 z progiem 50 MB; nawigacja edytor ↔ podgląd; obserwacja usunięcia; informacja o pełnym iCloud; zgoda na aparat przez `AVCaptureDevice`; prezentacje z jednego stanu `enum`.
- Test prawdziwego Vision wyłączony w CI (`.enabled(if:)` + zmienna `CI`), uruchamiany lokalnie.
- Świadomy wyjątek: M2 przed zakończeniem odbioru M1 na urządzeniach.

*(Dalsze decyzje dopisywane w trakcie implementacji.)*

## 16. Znane ograniczenia

1. Przełącznik przypomnienia i liczniki prób rozpoznawania są lokalne dla urządzenia (M1 14.5, punkt 6).
2. Poprawka ręczna może zostać nadpisana wynikiem automatycznym, gdy drugie urządzenie było offline z nierozpoznanym materiałem (punkt 6); rozwiązanie: `recognizedTextSource` w `SchemaV2`.
3. Blokada usuwania przedmiotu jest lokalna; materiał dodany równolegle na drugim urządzeniu może po synchronizacji zostać bez przedmiotu („Bez przedmiotu”, punkt 8).
4. `kind = pdf` nie odróżnia skanu od importu.
5. Duże PDF-y (podręczniki) są rozpoznawane częściowo (30 stron Vision, 200 000 znaków).
