# KorepetytorAI — M0 Fundament

Szkielet aplikacji: projekt Xcode z lokalnymi pakietami, pełny schemat SwiftData (15 encji)
z synchronizacją przez prywatną bazę iCloud, nawigacja adaptacyjna, system wizualny i testy.
Architektura i plan etapów: [`../architektura.md`](../architektura.md).

## Wymagania

- Mac z Xcode 16 lub nowszym (projekt korzysta z folderów synchronizowanych, `objectVersion 77`).
- Płatne konto Apple Developer (CloudKit).
- iPhone i iPad zalogowane na **to samo** konto iCloud.

## Pierwsza konfiguracja (raz, na Macu)

1. Skopiuj `Config/Signing.local.xcconfig.example` jako `Config/Signing.local.xcconfig`
   i wpisz własny identyfikator pakietu (`KOR_BUNDLE_ID`) oraz Team ID (`DEVELOPMENT_TEAM`).
   Plik nie trafia do repozytorium. Kontener CloudKit nazywa się wtedy `iCloud.<KOR_BUNDLE_ID>`.
2. Otwórz `KorepetytorAI.xcodeproj`, wybierz cel **KorepetytorAI** → **Signing & Capabilities**.
   W sekcji iCloud zaznacz kontener `iCloud.<KOR_BUNDLE_ID>` (przycisk **+**, jeśli jeszcze nie istnieje).
   Uprawnienia iCloud (CloudKit), Push Notifications i Background Modes (Remote notifications)
   są już zapisane w `Config/KorepetytorAI.entitlements` i `Config/Info.plist`.
3. Uruchom aplikację na iPhonie. Na ekranie **Profil** w sekcji „Synchronizacja (test)” powinno być
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
Te same testy uruchamia GitHub Actions (`.github/workflows/ios-tests.yml`).

## Test odbioru na urządzeniach

1. Zainstaluj aplikację na iPhonie 14 i na iPadzie (to samo konto iCloud).
2. iPhone: zakładki na dole (Dziś, Planer, Materiały, Nauka, Profil), tylko w pionie.
   Na ekranie Nauka jest przycisk do Korepetytora.
3. iPad: pasek boczny z sześcioma pozycjami (w tym Korepetytor), wszystkie orientacje.
   W wąskim Split View aplikacja przechodzi na zakładki.
4. Profil na obu urządzeniach: „Przedmioty w bazie: 16”. Na drugim urządzeniu liczba może przez
   chwilę wynosić 32, zanim duplikaty z iCloud zostaną scalone (zwykle kilka sekund po synchronizacji).
5. Na iPhonie dotknij „Dodaj przedmiot testowy”. Po chwili przedmiot „Test synchronizacji · iPhone · …”
   pojawia się na iPadzie (najszybciej po przełączeniu aplikacji w tło i z powrotem).
   Przedmioty testowe usuwasz, przesuwając je w lewo.
6. Tryb ciemny i największy rozmiar tekstu (Ustawienia → Dostępność → Ekran i wielkość tekstu → Większy tekst):
   ekrany zastępcze przewijają się i nic nie jest ucięte.

## Struktura

```
App/                 punkt wejścia, AppShell, utrzymanie danych (seeder, scalanie duplikatów)
Features/            ekrany modułów (w M0 ekrany zastępcze; Profil z testem synchronizacji)
Packages/
  Core/              modele SwiftData (SchemaV1), kontener, repozytoria, przedmioty startowe
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
- **Brak iCloud:** aplikacja nie kończy działania, tylko przechodzi na osobną bazę lokalną; tryb jest widoczny na Profilu.
