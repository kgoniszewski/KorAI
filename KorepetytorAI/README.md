# KorepetytorAI — M1 Planer

Aplikacja SwiftUI z danymi w iCloud: wprowadzenie z pseudonimem i awatarem, przedmioty,
kartkówki, sprawdziany i prace klasowe (widok miesiąca i listy), lokalne przypomnienia
dzień wcześniej o 18:00 i ekran Dziś. Fundament (M0): pełny schemat SwiftData (15 encji)
z synchronizacją przez prywatną bazę iCloud, nawigacja adaptacyjna, system wizualny i testy.
Architektura i plan etapów: [`../architektura.md`](../architektura.md);
specyfikacja i decyzje M1: [`docs/M1-spec.md`](docs/M1-spec.md).

## Wymagania

- Mac z Xcode 16 lub nowszym (projekt korzysta z folderów synchronizowanych, `objectVersion 77`).
- Płatne konto Apple Developer (CloudKit).
- iPhone i iPad zalogowane na **to samo** konto iCloud.

## Pierwsza konfiguracja (raz, na Macu)

1. Skopiuj `Config/Signing.local.xcconfig.example` jako `Config/Signing.local.xcconfig`
   i wpisz własny identyfikator pakietu (`KOR_BUNDLE_ID`) oraz Team ID (`DEVELOPMENT_TEAM`).
   Plik nie trafia do repozytorium. Kontener CloudKit nazywa się wtedy `iCloud.<KOR_BUNDLE_ID>`.
2. Otwórz `KorepetytorAI.xcodeproj` i w celu **KorepetytorAI** → **Signing & Capabilities** tylko **sprawdź**,
   że zespół i kontener `iCloud.<KOR_BUNDLE_ID>` są widoczne bez błędów. Jeśli kontenera jeszcze nie ma,
   utwórz go w [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list/cloudContainer)
   pod tą samą nazwą. Nie wybieraj zespołu ani kontenera w tym panelu: Xcode zapisałby je na sztywno w pliku projektu
   i w `Config/KorepetytorAI.entitlements` (zamiast zmiennej `$(CLOUDKIT_CONTAINER_IDENTIFIER)`).
   Uprawnienia iCloud (CloudKit), Push Notifications i Background Modes (Remote notifications)
   są już zapisane w `Config/KorepetytorAI.entitlements` i `Config/Info.plist`.
   Przy pierwszym otwarciu Xcode może uporządkować `project.pbxproj`; tę zmianę warto zacommitować.
3. Uruchom aplikację na iPhonie i przejdź wprowadzenie. Na ekranie **Profil** w sekcji „iCloud” powinno być
   „Konto iCloud: Zalogowano” i „Baza danych: iCloud (prywatna baza)”.

## Schemat w CloudKit Console

SwiftData tworzy typy rekordów w CloudKit dopiero przy pierwszym zapisie danego typu.
Żeby od razu wysłać pełny schemat (15 typów `CD_*`):

1. **Product → Scheme → Edit Scheme… → Run → Arguments** i włącz `-initializeCloudKitSchema`.
2. Uruchom aplikację raz na prawdziwym urządzeniu (wersja Debug).
3. Wyłącz argument z powrotem.
4. W [CloudKit Console](https://icloud.developer.apple.com) → kontener → **Development → Schema → Record Types**
   powinny być m.in. `CD_Subject`, `CD_Assessment`, `CD_StudyMaterial`, `CD_Profile`.

Do diagnozy synchronizacji służy wyłączony domyślnie argument `-com.apple.CoreData.CloudKitDebug 1`.

## Testy

```bash
./scripts/test.sh
```

Skrypt buduje aplikację i uruchamia testy (Swift Testing) na pierwszym dostępnym symulatorze
iPhone'a i iPada. Ostrzeżenia kompilacji traktuje jako błędy (`STRICT=0` to wyłącza).
Symulatory można wskazać ręcznie zmiennymi `IPHONE_DESTINATION` i `IPAD_DESTINATION`.
Te same testy uruchamia GitHub Actions (`.github/workflows/ios-tests.yml`) przy zmianach na `main` i w pull requestach.
Testy nie mają aplikacji-hosta, więc działają na symulatorze, a nie na fizycznym urządzeniu.

## Test odbioru M1 na urządzeniach

iPhone 14 i iPad, to samo konto iCloud (lista kontrolna: `docs/M1-spec.md`, punkt 12).

1. **Wprowadzenie.** Pierwsze uruchomienie na iPhonie: pseudonim → awatar → Gotowe → ekran Dziś.
   Na iPadzie: jeśli profil z iPhone'a już dotarł, wprowadzenie kończy się samo; jeśli nie, po przejściu
   wprowadzenia i synchronizacji zostaje jeden profil (starszy). Profil → „Zmień pseudonim i awatar” działa.
2. **Czas wpisu (< 15 s).** Dziś → „Dodaj sprawdzian” (albo Planer → „+”), stoper od otwarcia arkusza:
   wybierz przedmiot (przy kolejnym wpisie jest już ostatnio użyty), rodzaj, datę → „Zapisz”.
   Przy pierwszym zapisie pojawi się prośba o zgodę na powiadomienia — po zamknięciu arkusza, więc nie liczy się do czasu.
3. **Widoki.** Termin jest w Planerze w widoku Miesiąc (kropka w kolorze przedmiotu, stuknięcie dnia pokazuje termin),
   w widoku Lista i na ekranie Dziś (do 3 najbliższych). Filtr przedmiotu (ikona lejka) działa w obu widokach.
   Na liście: przesunięcie w prawo kończy termin, w lewo usuwa (z potwierdzeniem).
4. **Synchronizacja.** Termin dodany na iPhonie pojawia się na iPadzie (najszybciej po przełączeniu aplikacji
   w tło i z powrotem), i odwrotnie. Ocena wpisana po fakcie (edycja → Stan: Zakończony → Ocena) też.
5. **Przypomnienie.** Dodaj termin z datą **jutro**, przed 18:00 — w edytorze pod przełącznikiem widać
   „Przypomnimy Ci: dziś … 18:00”. O 18:00 przychodzi „Jutro: sprawdzian” z nazwą przedmiotu (także przy
   otwartej aplikacji). Żeby nie czekać: przed 18:00 przestaw na chwilę zegar urządzenia na 17:59
   (Ustawienia → Ogólne → Data i czas) albo zablokuj ekran i poczekaj. Po usunięciu terminu przypomnienie nie przychodzi.
   Uwaga: na dwóch urządzeniach przyjdą dwa powiadomienia (decyzja 14.1).
6. **Przedmioty.** Planer → „Przedmioty”: edycja nazwy, koloru i ikony, dodawanie, usuwanie (przesunięcie w lewo).
   Przedmiot z terminami nie daje się usunąć i pokazuje komunikat z ich liczbą.
7. **iPad.** Filtr i przełącznik Miesiąc/Lista w pełnym ekranie i w wąskim Split View.
8. **Tryb ciemny i największy rozmiar tekstu** (Ustawienia → Dostępność → Ekran i wielkość tekstu → Większy tekst):
   siatka miesiąca, edytor (rodzaj zmienia się wtedy z segmentów na menu) i ekran Dziś są czytelne.

## Struktura

```
App/                 punkt wejścia, RootView, AppShell, utrzymanie danych (seeder, scalanie
                     przedmiotów i profili), przypomnienia (ReminderScheduler)
Features/            ekrany modułów: Onboarding, Today, Planner (kalendarz, edytory), Rewards (Profil);
                     pozostałe moduły to ekrany zastępcze
Packages/
  Core/              modele SwiftData (SchemaV1), kontener, repozytoria, przedmioty startowe,
                     logika kalendarza (PlannerCalendar) i przypomnień (ReminderPlanner)
  DesignSystem/      kolory (jasne i ciemne), typografia, odstępy, komponenty
  Gamification/      pusty w M0 (M3)
  AIClient/          pusty w M0 (M4)
KorepetytorAITests/  testy jednostkowe
Config/              Info.plist, uprawnienia, identyfikatory i podpis
proxy/               miejsce na Cloudflare Worker (M4)
scripts/test.sh      testy na symulatorze iPhone'a i iPada
```

## Decyzje M0

- **Schemat:** wszystkie encje w `SchemaV1` z pustym planem migracji; nazwy w kodzie to aliasy
  (`Subject = SchemaV1.Subject`), więc `SchemaV2` zmieni tylko aliasy. Typy wyliczeniowe są zapisane jako tekst,
  a test pilnuje, żeby ich wartości się nie zmieniały.
- **Przedmioty startowe:** wgrywane raz na instalację (usunięty przedmiot nie wraca). Duplikaty z dwóch urządzeń
  scalają się przy starcie, powrocie na pierwszy plan i po zmianach z iCloud; zostaje zawsze najstarszy rekord,
  więc oba urządzenia wybierają ten sam.
- **Przedmioty startowe c.d.:** flaga „wgrano” jest osobna dla magazynu iCloud i lokalnego i zapisuje się dopiero po udanym zapisie;
  baza w pamięci (`-inMemoryStore`) wgrywa listę zawsze.
- **Brak iCloud:** w wersji Release aplikacja nie kończy działania, tylko przechodzi na osobną bazę lokalną; tryb jest widoczny
  na Profilu. W wersji Debug błąd CloudKit zatrzymuje aplikację asercją, żeby błąd schematu lub uprawnień był widoczny od razu.
  Dług: dane z bazy lokalnej nie przechodzą później do iCloud.

## Na później

- ~~`Profile` może powstać na dwóch urządzeniach przed synchronizacją~~ — scalanie zrobione w M1 (`ProfileRepository.mergeDuplicates`).
- Pole `reminderEnabled` w `Assessment` przy pierwszym `SchemaV2` (w M1 przełącznik jest lokalny, decyzja 14.5).
- Przed TestFlight: `PrivacyInfo.xcprivacy` (użycie `UserDefaults`, powód `CA92.1`) — M7.
