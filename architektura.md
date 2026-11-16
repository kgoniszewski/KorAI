# Osobisty Korepetytor AI — architektura i plan rozwoju

Nov 15, 2026 · @Krzysztof

## Cel i założenia

Aplikacja ma sprawić, że 15-latka z technikum hotelarskiego sama sięga po naukę: krótkie sesje, natychmiastowa nagroda i jasny plan przed każdą kartkówką. Powstaje jako natywna aplikacja SwiftUI na iPhone'a 14 i iPada, z danymi w iCloud i korepetytorem opartym na Claude API.

| Obszar | Decyzja |
| --- | --- |
| Technologia | Natywna aplikacja SwiftUI, jeden kod na iPhone'a i iPada, minimum iOS / iPadOS 18 |
| Dane | SwiftData lokalnie, synchronizacja przez prywatną bazę iCloud (CloudKit) |
| Funkcje AI | Quizy i fiszki z materiałów, czat-korepetytor, plan nauki przed sprawdzianem, streszczenia |
| Nagrody | Wirtualne (punkty, poziomy, serie, odznaki) oraz realne, definiowane przez rodzica |
| Język | Polski; kod i nazwy w kodzie po angielsku |

Zasady projektowe, którym podlega każda funkcja:

- **To jej aplikacja, nie narzędzie nadzoru.** Rodzic widzi podsumowanie i zatwierdza nagrody, ale nie czyta czatu ani notatek.
- **Nagradzamy wysiłek, nie oceny.** Punkty są za sesje, powtórki i quizy; ocena ze sprawdzianu daje najwyżej mały bonus.
- **Sesja trwa 5–15 minut.** Każdy ekran prowadzi do jednej, małej czynności, którą da się skończyć od razu.
- **Zero kar.** Przerwana seria nie zabiera punktów; można ją uratować „dniem wolnym”.
- **AI naprowadza, nie odrabia.** Korepetytor tłumaczy i zadaje pytania, nie podaje gotowych wypracowań ani rozwiązań zadań domowych.
- **Działa offline.** Planer, materiały i fiszki nie wymagają sieci; tylko funkcje AI jej potrzebują.

## Zakres funkcjonalny

Aplikacja ma siedem modułów; na iPhonie są to zakładki na dole, na iPadzie pasek boczny z układem dwukolumnowym.

| Moduł | Co robi |
| --- | --- |
| Dziś | Ekran startowy: najbliższe terminy, zadania na dziś z planu nauki, seria dni, jeden duży przycisk „Zacznij 10 minut” |
| Planer | Kalendarz (miesiąc i lista) z kartkówkami, sprawdzianami i pracami klasowymi; dodawanie, edycja, usuwanie, zakres materiału, przypomnienia, wpisanie oceny po fakcie |
| Materiały | Notatki tekstowe, zdjęcia (aparat, skaner dokumentów, galeria) i pliki PDF, przypisane do przedmiotu i opcjonalnie do sprawdzianu; rozpoznawanie tekstu ze zdjęć, wyszukiwanie |
| Nauka | Quizy i fiszki generowane z materiałów, powtórki rozłożone w czasie, streszczenia i lista kluczowych pojęć |
| Korepetytor | Czat z AI osadzony w kontekście wybranego materiału lub sprawdzianu; tłumaczenie krok po kroku, odpytywanie |
| Nagrody i profil | Poziom, punkty, monety, seria, odznaki, wyzwania tygodniowe, katalog nagród od rodzica |
| Strefa rodzica | Za kodem PIN: definiowanie nagród, zatwierdzanie wymian, tygodniowe podsumowanie aktywności, limit użycia AI |

Na start wgranych jest 16 przedmiotów z tego roku szkolnego, każdy z własnym kolorem i ikoną; listę można edytować. Ogólne (10): język polski, język angielski, język francuski, matematyka, biologia, historia, biznes i zarządzanie, fizyka, informatyka, EDB. Zawodowe (6): podstawy hotelarstwa, język francuski zawodowy, organizacja pracy w hotelarstwie, usługi żywieniowe, techniki pracy w hotelarstwie, pracownia obsługi gościa. Integracja z dziennikiem elektronicznym jest poza zakresem: terminy wpisuje się ręcznie, w kilku stuknięciach.

## Architektura techniczna

System ma trzy części: aplikację na urządzeniach, prywatną bazę iCloud i małe proxy, które jako jedyne zna klucz do Claude API.

&#91;embedded content: architektura · aplikacja, iCloud, proxy AI, Claude API\]

Aplikacja rozmawia z AI wyłącznie przez proxy, a dane ucznia synchronizują się bezpośrednio z iCloud, z pominięciem proxy.

| Warstwa | Wybór | Uzasadnienie |
| --- | --- | --- |
| Interfejs | SwiftUI, Swift 6, wzorzec MVVM z `@Observable` | Jeden kod, układ adaptacyjny: zakładki na iPhonie, `NavigationSplitView` na iPadzie |
| Dane | SwiftData + CloudKit (baza prywatna) | Synchronizacja bez własnego serwera i bez logowania |
| Pliki | Zdjęcia i PDF jako atrybuty z zewnętrznym przechowywaniem | Trafiają do iCloud razem z rekordami |
| Import | PhotosUI, VisionKit (skaner dokumentów), PDFKit, Vision (rozpoznawanie tekstu na urządzeniu) | Tekst z materiałów powstaje lokalnie, co obniża koszt AI |
| Przypomnienia | UserNotifications, powiadomienia lokalne | Nie wymagają serwera |
| Wykresy i widżety | Swift Charts, WidgetKit | Postępy i seria na ekranie głównym |
| Proxy AI | Cloudflare Worker (TypeScript) | Ukrywa klucz, pilnuje limitów, trzyma prompty systemowe, przekazuje strumień odpowiedzi |
| Modele | Claude Haiku 5.5 do quizów, fiszek i streszczeń; Claude Sonnet 5.5 do czatu | Tańszy model do zadań masowych, mocniejszy do rozmowy; zmiana w konfiguracji proxy |

Struktura kodu to jeden projekt Xcode z lokalnymi pakietami Swift: `Core` (modele, repozytoria), `AIClient`, `Gamification`, `DesignSystem` oraz foldery funkcji (`Today`, `Planner`, `Materials`, `Study`, `Tutor`, `Rewards`, `ParentZone`). Logika punktów i planu nauki jest czystym Swiftem bez UI, więc da się ją pokryć testami jednostkowymi.

Ograniczenia SwiftData z CloudKit, które obowiązują od pierwszego modelu: każda właściwość ma wartość domyślną lub jest opcjonalna, relacje są opcjonalne, nie ma atrybutów unikalnych.

## Model danych

Model ma 15 encji SwiftData; punkty są zapisywane jako dziennik zdarzeń, a nie jedna liczba, żeby synchronizacja między urządzeniami nigdy ich nie gubiła.

| Encja | Najważniejsze pola | Powiązania |
| --- | --- | --- |
| `Subject` | nazwa, kolor, ikona, typ (ogólny / zawodowy) | ma wiele sprawdzianów i materiałów |
| `Assessment` | typ (kartkówka, sprawdzian, praca klasowa, inne), data, zakres, status, ocena | przedmiot, materiały, sesje nauki |
| `StudyMaterial` | typ (notatka, zdjęcie, PDF), tytuł, treść, plik, rozpoznany tekst, streszczenie | przedmiot, sprawdziany |
| `FlashcardDeck` | tytuł, źródło (AI / ręcznie) | materiał, fiszki |
| `Flashcard` | przód, tył, termin powtórki, interwał, współczynnik łatwości | talia |
| `Quiz` | tytuł, pytania (JSON), poziom trudności | materiał lub sprawdzian |
| `QuizAttempt` | data, wynik, odpowiedzi | quiz |
| `StudySession` | planowana data, czas, rodzaj (quiz, fiszki, czytanie, czat), wykonana | sprawdzian |
| `ChatThread` / `ChatMessage` | tytuł, rola, treść, data | materiał lub sprawdzian jako kontekst |
| `XPEvent` | data, powód, punkty XP, monety | profil |
| `Badge` | identyfikator, data zdobycia | profil |
| `Reward` | nazwa, koszt w monetach, aktywna | definiuje rodzic |
| `RewardRedemption` | data, status (zgłoszona, zatwierdzona, odebrana, odrzucona) | nagroda |
| `Profile` | pseudonim, awatar, ustawienia, liczba „dni wolnych” | jeden na konto iCloud |

Poziom, saldo monet i seria są wyliczane z `XPEvent` i `RewardRedemption`. Powtórki fiszek działają według algorytmu SM-2 (interwały rosną po poprawnych odpowiedziach).

## Warstwa AI

Wszystkie funkcje AI przechodzą przez jedno proxy z czterema punktami końcowymi; aplikacja nie zna klucza API ani treści promptów systemowych.

| Funkcja | Wejście | Wynik | Model |
| --- | --- | --- | --- |
| Quiz i fiszki | Tekst materiału, liczba pytań, poziom | JSON o stałym schemacie (wymuszony przez tool use), dekodowany do `Codable` | Haiku 5.5 |
| Streszczenie | Tekst materiału | Krótkie podsumowanie i lista pojęć | Haiku 5.5 |
| Plan nauki | Data sprawdzianu, zakres, lista materiałów, dostępne dni | Lista sesji 10–15 min rozłożonych do terminu | Haiku 5.5 |
| Czat-korepetytor | Wiadomości i wybrany materiał jako kontekst | Odpowiedź strumieniowana (SSE) | Sonnet 5.5 |

Przetwarzanie materiałów przebiega w trzech krokach:

1. Tekst powstaje na urządzeniu: PDFKit dla plików PDF, Vision dla zdjęć i skanów.
2. Gdy rozpoznanie jest słabe (odręczne notatki, schematy), aplikacja wysyła obraz lub strony PDF do Claude, który czyta je bezpośrednio.
3. Tekst zostaje przy materiale, więc kolejne quizy i czat nie wymagają ponownego przetwarzania.

Plan nauki ma dwie warstwy: rozkład sesji w kalendarzu liczy deterministyczny algorytm w aplikacji (działa offline), a AI tylko proponuje, co robić w każdej sesji.

Proxy odpowiada za:

- uwierzytelnienie urządzenia (App Attest lub token nadany przy pierwszej konfiguracji),
- dzienny limit zapytań i miesięczny limit kosztów: ostrzeżenie przy 100 zł, twarda blokada przy 200 zł,
- prompty systemowe: język polski, ton życzliwy i konkretny, metoda naprowadzania pytaniami, odmowa pisania gotowych prac, treści odpowiednie dla 15-latki,
- buforowanie tekstu materiału (prompt caching), żeby dłuższa rozmowa o jednym pliku była tańsza,
- brak zapisu treści rozmów w logach.

## Grywalizacja i nagrody

Są dwie waluty: punkty XP budują poziom i nigdy nie maleją, a monety wymienia się na realne nagrody ustalone przez rodzica.

Motyw przewodni nawiązuje do szkoły: córka prowadzi własny hotel, który rośnie razem z poziomem, od pensjonatu z jedną gwiazdką do pięciogwiazdkowego resortu, a tytuły idą od stażystki do dyrektorki. To propozycja; motyw warto wybrać razem z nią.

| Mechanika | Jak działa |
| --- | --- |
| XP i poziomy | XP za ukończoną sesję, quiz (z bonusem za wynik), powtórkę fiszek, dodanie materiału i wykonanie planu dnia |
| Monety | Naliczane razem z XP w mniejszej liczbie; wydawane w katalogu nagród |
| Seria dni | Rośnie za co najmniej jedną sesję dziennie; jeden „dzień wolny” w tygodniu chroni ją przed zerwaniem |
| Odznaki | Za kamienie milowe: pierwszy quiz na 100%, 7 dni serii, komplet powtórek przed sprawdzianem |
| Wyzwania tygodniowe | Trzy małe cele na tydzień, losowane z puli i dopasowane do nadchodzących terminów |
| Bonus za przygotowanie | Dodatkowe monety za wykonanie całego planu nauki przed sprawdzianem, niezależnie od oceny |
| Efekty | Animacje, konfetti i haptyka po każdej zakończonej czynności |

Realne nagrody działają w czterech krokach:

1. Rodzic w Strefie rodzica (kod PIN) dodaje nagrody z kosztem w monetach, na przykład kino lub późniejszy powrót w sobotę.
2. Córka zgłasza wymianę monet na wybraną nagrodę.
3. Rodzic zatwierdza lub odrzuca zgłoszenie; monety schodzą z salda dopiero po zatwierdzeniu.
4. Po wręczeniu nagroda dostaje status „odebrana”.

Zabezpieczenia przed nabijaniem punktów: dzienny limit XP z jednego rodzaju aktywności, punkty za quiz zależne od poprawnych odpowiedzi, brak punktów za powtarzanie tego samego quizu w krótkim odstępie.

W pierwszej wersji Strefa rodzica działa na urządzeniu córki. Podgląd na telefonie rodzica (inne konto Apple) wymaga współdzielenia CloudKit, którego SwiftData nie obsługuje ([forum Apple Developer](https://developer.apple.com/forums/thread/794600)), dlatego jest osobnym, opcjonalnym etapem M8.

## Prywatność i bezpieczeństwo

Użytkowniczką jest osoba niepełnoletnia, więc aplikacja nie ma kont, reklam ani analityki, a dane opuszczają urządzenie tylko w dwóch kierunkach.

- **iCloud:** notatki, pliki, postępy i czat leżą w prywatnej bazie CloudKit na koncie Apple córki; twórca aplikacji nie ma do nich wglądu.
- **Claude API:** treść materiału i wiadomości czatu są wysyłane przez proxy tylko wtedy, gdy używa funkcji AI. Proxy nie zapisuje treści.
- **Klucz API** istnieje wyłącznie jako sekret w konfiguracji proxy, nigdy w kodzie ani w repozytorium.
- **PIN rodzica** jest przechowywany w pęku kluczy (Keychain) i nie synchronizuje się z innymi danymi.
- **Czat** ma widoczny przycisk zgłoszenia odpowiedzi oraz stałą informację, że AI może się mylić i warto sprawdzić odpowiedź w podręczniku.

Dystrybucja odbywa się przez TestFlight lub bezpośrednio z Xcode, bez publikacji w App Store. CloudKit wymaga płatnego członkostwa w Apple Developer Program.

Anthropic dopuszcza produkty oparte na API, z których korzystają niepełnoletni, pod warunkiem dodatkowych zabezpieczeń: filtrowania treści, zgodności z przepisami o ochronie dzieci i jasnej informacji, że rozmówcą jest AI ([wytyczne Anthropic](https://support.claude.com/en/articles/9307344-responsible-use-of-anthropic-s-models-guidelines-for-organizations-serving-minors)). Wytyczne są adresowane do organizacji; ten projekt stosuje je w tej samej formie: zasady bezpieczeństwa w prompcie systemowym proxy, stała etykieta „AI” w czacie i tygodniowe podsumowanie dla rodzica.

## Plan rozwoju (Milestones)

Plan ma osiem etapów głównych i jeden opcjonalny; aplikacja nadaje się do codziennego użytku po M3, a komplet zamówionych funkcji jest gotowy po M6. Każdy etap kończy się wersją działającą na obu urządzeniach.

| Etap | Zakres | Gotowe, gdy |
| --- | --- | --- |
| M0 Fundament | Projekt Xcode i pakiety, modele SwiftData z CloudKit, system wizualny (kolory, typografia, komponenty), nawigacja adaptacyjna, testy jednostkowe w CI | Aplikacja uruchamia się na iPhonie 14 i iPadzie, a rekord testowy dodany na jednym urządzeniu pojawia się na drugim |
| M1 Planer | Wprowadzenie przy pierwszym uruchomieniu z wyborem pseudonimu i awatara, przedmioty, dodawanie i edycja kartkówek, sprawdzianów i prac klasowych, widok miesiąca i listy, przypomnienia, ekran Dziś | Da się wpisać termin w mniej niż 15 sekund i przychodzi powiadomienie dzień wcześniej |
| M2 Materiały | Notatki, zdjęcia z aparatu i skanera, import PDF, podgląd, rozpoznawanie tekstu, przypisanie do przedmiotu i sprawdzianu, wyszukiwanie | Zdjęcie zeszytu i plik PDF są widoczne na obu urządzeniach i da się je znaleźć po słowie z treści |
| M3 Grywalizacja | Dziennik XP, poziomy, monety, seria z „dnia wolnym”, odznaki, ręczne fiszki z powtórkami, minutnik sesji, animacje | Sesja z minutnikiem i powtórka fiszek dają XP, poziom i seria liczą się poprawnie po synchronizacji |
| M4 AI: quizy, fiszki, streszczenia | Proxy na Cloudflare, klient AI, generowanie quizów i fiszek z materiału, streszczenia, obsługa błędów i braku sieci | Z dodanego PDF powstaje quiz na 10 pytań i talia fiszek; klucza API nie ma w aplikacji |
| M5 AI: czat i plan nauki | Czat strumieniowany z kontekstem materiału, generator planu nauki, sesje z planu na ekranie Dziś i w kalendarzu | Po dodaniu sprawdzianu za 7 dni powstaje plan sesji, a czat odpowiada na pytania z wybranej notatki |
| M6 Strefa rodzica | PIN, katalog nagród, zgłoszenia i zatwierdzanie wymian, podsumowanie tygodnia, limity AI, wyzwania tygodniowe | Pełny obieg nagrody: zdefiniowanie, zgłoszenie, zatwierdzenie, odbiór |
| M7 Szlif i wydanie | Widżety, dopracowanie układu iPada (Split View, klawiatura, Apple Pencil w notatkach), dostępność, tryb ciemny, TestFlight | Córka instaluje wersję z TestFlight i przechodzi konfigurację bez pomocy |
| M8 Rodzic na własnym urządzeniu (opcjonalnie) | Współdzielenie podsumowania i nagród z kontem Apple rodzica przez CloudKit Sharing | Rodzic zatwierdza nagrodę na swoim telefonie |

Grywalizacja (M3) jest celowo przed AI: pętla „zrób małą rzecz, dostań nagrodę” ma działać od pierwszej wersji, którą córka dostanie do ręki. Po M3 i po M5 warto zrobić tydzień testów z nią i poprawić to, co ją nudzi lub irytuje, zanim powstaną kolejne funkcje.

## Podział pracy, ryzyka i otwarte pytania

Fable 5.2 odpowiada za architekturę, specyfikację każdego etapu i przegląd kodu; Opus 5.5 pisze kod według tych specyfikacji.

1. Przed każdym etapem Fable przygotowuje specyfikację: ekrany, modele, interfejsy między modułami, przypadki testowe.
2. Opus 5.5 implementuje etap w repozytorium projektu.
3. Fable robi przegląd pod kątem zgodności z architekturą, a etap zamyka test na prawdziwym iPhonie i iPadzie.

Kod iOS trzeba kompilować w Xcode na Macu. Środowisko tej rozmowy to Linux bez Xcode, więc kod napisany tutaj byłby niesprawdzony kompilacją. Najpewniejsza droga to praca Opusa 5.5 w Claude Code na Macu, bezpośrednio w repozytorium, z budowaniem i testami po każdej zmianie.

| Ryzyko | Skutek | Jak ograniczamy |
| --- | --- | --- |
| SwiftData z CloudKit bywa kapryśne przy zmianach schematu | Utrata lub rozjazd danych między urządzeniami | Schemat wersjonowany od M0, zmiany tylko addytywne, test synchronizacji w każdym etapie |
| Odręczne notatki źle się rozpoznają | Słabe quizy z błędnego tekstu | Zapasowa ścieżka: obraz czytany bezpośrednio przez Claude; możliwość poprawienia tekstu ręcznie |
| AI poda błędną informację | Nauka złych odpowiedzi | Odpowiedzi oparte na dodanych materiałach, przycisk zgłoszenia, informacja o możliwych błędach |
| Koszt API rośnie | Nieprzewidziany rachunek | Limity w proxy, tańszy model do zadań masowych, buforowanie materiału |
| Grywalizacja nudzi się po kilku tygodniach | Powrót do braku motywacji | Rotacja wyzwań, realne nagrody, testy z córką po M3 i M5 |
| Wersje z TestFlight wygasają po 90 dniach | Aplikacja przestaje się uruchamiać | Nowa wersja co najmniej raz na kwartał |

Ustalenia przed M0 i jedno pytanie, które zostało:

- **Środowisko:** Mac z Xcode na macOS 27 i konto deweloperskie Apple są dostępne.
- **Konto Apple:** iPhone i iPad córki przechodzą na jedno wspólne konto iCloud. Prywatna baza CloudKit synchronizuje się tylko w obrębie jednego konta, więc to warunek synchronizacji bez dodatkowego kodu.
- **Koszt AI:** 100–200 zł miesięcznie; proxy ostrzega przy 100 zł i blokuje funkcje AI przy 200 zł do końca miesiąca.
- **Przedmioty:** 16 przedmiotów wgranych na start (lista w sekcji Zakres funkcjonalny).
- **Awatar:** wybór przy pierwszym uruchomieniu, w ramach M1.
- **Zasady Anthropic:** sprawdzone, opis w sekcji Prywatność i bezpieczeństwo.

* [ ] Jaki to model iPada i jaką ma wersję iPadOS? Od tego zależy minimalna wersja systemu (roboczo iOS / iPadOS 18).

## Specyfikacja M0: Fundament (dla Opusa 5.5)

M0 dostarcza pusty, ale kompletny szkielet: projekt Xcode, pełny schemat danych z synchronizacją iCloud, nawigację na iPhonie i iPadzie oraz system wizualny. Nie zawiera jeszcze żadnej funkcji użytkowej.

### Środowisko i konfiguracja

- Xcode na macOS 27, Swift 6 z pełną kontrolą współbieżności, SwiftUI, cel: iOS / iPadOS 18.0 (do podniesienia po ustaleniu modelu iPada).
- Jedna aplikacja uniwersalna na iPhone'a i iPada; iPhone tylko pionowo, iPad we wszystkich orientacjach i w Split View.
- Nazwa robocza `KorepetytorAI`; identyfikator pakietu i kontener CloudKit (`iCloud.<identyfikator>`) ustala właściciel konta deweloperskiego.
- Uprawnienia: iCloud z CloudKit, Push Notifications, Background Modes (Remote notifications).
- Brak zewnętrznych zależności. Język interfejsu: polski, teksty w String Catalog.

### Struktura repozytorium

```
KorepetytorAI/
  App/                 punkt wejścia, AppShell, konfiguracja ModelContainer
  Features/
    Today/ Planner/ Materials/ Study/ Tutor/ Rewards/ ParentZone/
  Packages/
    Core/              modele SwiftData, schemat, repozytoria, dane startowe
    DesignSystem/      kolory, typografia, odstępy, komponenty
    Gamification/      pusta w M0 (logika XP w M3)
    AIClient/          pusta w M0 (klient proxy w M4)
  KorepetytorAITests/
  proxy/               pusty katalog na Cloudflare Worker (M4)
```

### Schemat danych

1. Zadeklaruj w `Core` wszystkie 15 encji z sekcji Model danych jako `SchemaV1` (`VersionedSchema`) z pustym `SchemaMigrationPlan`. Pełny schemat od początku ogranicza późniejsze migracje w CloudKit.
2. Każda encja ma `id: UUID`, `createdAt: Date`, `updatedAt: Date` z wartościami domyślnymi.
3. Reguły CloudKit: wszystkie właściwości z wartością domyślną lub opcjonalne, wszystkie relacje opcjonalne z jawną relacją odwrotną, bez `@Attribute(.unique)`, bez reguły usuwania `.deny`.
4. Typy wyliczeniowe (typ sprawdzianu, typ materiału, status wymiany) zapisuj jako `String` z właściwością obliczaną zwracającą enum.
5. Dane plików w `StudyMaterial` oznacz `@Attribute(.externalStorage)`.
6. `ModelContainer` z `cloudKitDatabase: .private(...)`; osobna konfiguracja w pamięci dla testów i podglądów.
7. `SubjectSeeder` wgrywa 16 przedmiotów z sekcji Zakres funkcjonalny (nazwa, typ ogólny lub zawodowy, kolor, ikona SF Symbols). Musi być idempotentny: przy starcie scala duplikaty o tej samej nazwie, bo oba urządzenia mogą wgrać listę przed pierwszą synchronizacją.

### Nawigacja

- `AppShell` wybiera układ według `horizontalSizeClass`: `TabView` z pięcioma zakładkami (Dziś, Planer, Materiały, Nauka, Profil) w układzie wąskim, `NavigationSplitView` z paskiem bocznym w szerokim.
- Korepetytor jest w M0 pozycją paska bocznego na iPadzie i przyciskiem na ekranie Nauka na iPhonie; Strefa rodzica otwiera się z Profilu.
- Każdy moduł ma ekran zastępczy z komponentem `EmptyState`.
- Ekran Profil pokazuje w M0 stan iCloud (zalogowano / brak konta) i listę przedmiotów z bazy, co służy do testu synchronizacji.

### System wizualny

- Kolory w Asset Catalog z wariantem jasnym i ciemnym: tło, powierzchnia, tekst, akcent oraz paleta 16 kolorów przedmiotów.
- Typografia oparta na stylach systemowych z Dynamic Type; odstępy 4, 8, 12, 16, 24.
- Komponenty: `PrimaryButton`, `Card`, `SubjectChip`, `EmptyState`, `ProgressRing`, każdy z podglądem SwiftUI.
- Styl: nowoczesny, duże zaokrąglenia, wyraźne kolory, wygląd dla nastolatki, a nie dziennik szkolny.

### Testy

- Swift Testing: utworzenie kontenera w pamięci ze wszystkimi encjami, zapis i odczyt każdej encji, relacje odwrotne, idempotentność `SubjectSeeder`.
- Skrypt `scripts/test.sh` uruchamiający `xcodebuild test` na symulatorze iPhone'a i iPada.

### Kryteria odbioru

- [x] Projekt buduje się bez ostrzeżeń i testy przechodzą.
- [x] Aplikacja uruchamia się na iPhonie 14 i na iPadzie, z właściwym układem nawigacji na każdym.
- [x] Po pierwszym uruchomieniu w bazie jest dokładnie 16 przedmiotów, także po uruchomieniu na drugim urządzeniu.
- [x] Przedmiot dodany testowo na jednym urządzeniu pojawia się na drugim (ten sam Apple ID, prawdziwe urządzenia).
- [x] Schemat CloudKit jest widoczny w CloudKit Console w środowisku Development.
- [x] Tryb ciemny i największy rozmiar tekstu nie psują układu ekranów zastępczych.

M0 zaakceptowany na urządzeniach. Specyfikacja etapu M1: [`KorepetytorAI/docs/M1-spec.md`](KorepetytorAI/docs/M1-spec.md).

### Poza zakresem M0

Wprowadzenie z awatarem, planer, materiały, punkty, proxy i wszystkie funkcje AI należą do etapów M1–M6 i dostaną własne specyfikacje.
