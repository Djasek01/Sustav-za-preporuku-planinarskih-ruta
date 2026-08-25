# Sustav za preporuku planinarskih ruta temeljen na grafovskoj bazi podataka

## O projektu

Sustav predlaže optimalne planinarske rute na temelju dobi sudionika, vremenskih uvjeta i težine staze, uz prikaz staza na karti, preporuku opreme i procjenu troška izleta. Temelji se na Neo4j grafovskoj bazi podataka s 65 detaljno opisanih ruta i 142 HPO kontrolnih točaka.

## Arhitektura

```
Flutter (mobilna aplikacija)
    ↓ HTTP/JSON
FastAPI (REST API poslužitelj)
    ↓ Bolt/Cypher
Neo4j (grafovska baza podataka)
```

## Funkcionalnosti

- Preporuka ruta prema dobi sudionika (graduirana skala)
- Filtriranje prema vremenskim uvjetima (vjetar, magla, kiša)
- Filtriranje prema težini staze (lagana, srednja, teška)
- Prikaz ruta na Google Maps karti s fotografijama
- Preporuka opreme s cijenama (Decathlon HR)
- Procjena troška izleta (ulaznica, oprema, gorivo, cestarina)
- Omiljene rute, dark mode, dijeljenje ruta

## Tehnologije

| Sloj | Tehnologija |
|------|------------|
| Baza podataka | Neo4j 5.x, Cypher |
| Backend | Python 3.12, FastAPI, Uvicorn |
| Frontend | Flutter 3.44, Dart 3.12 |
| Karta | Google Maps SDK for Android, Places API |

## Pokretanje

### Preduvjeti

- [Neo4j Desktop](https://neo4j.com/download/) s kreiranom bazom "planinarske-rute"
- [Python 3.12+](https://www.python.org/downloads/)
- [Flutter 3.44+](https://docs.flutter.dev/get-started/install)
- [JDK 17+](https://adoptium.net/temurin/releases/?version=17)
- Google Maps API ključ

### 1. Konfiguracija

Kopiraj `.env.example` u `.env` i popuni vrijednosti:

```bash
cp .env.example .env
```

### 2. Backend

```bash
cd backend
python -m venv venv

# Windows
.\venv\Scripts\Activate.ps1
# Linux/Mac
source venv/bin/activate

pip install -r requirements.txt
uvicorn app.main:app --reload
```

API dokumentacija dostupna na: http://localhost:8000/docs

### 3. Mobilna aplikacija

```bash
cd mobile
flutter pub get

# Na Android emulatoru
flutter run -d emulator-5554

# Na Chrome webu
flutter run -d chrome
```

**Napomena:** Za Android emulator dodaj Google Maps API ključ u `mobile/android/app/src/main/AndroidManifest.xml`.

## Struktura projekta

```
Sustav-za-preporuku-planinarskih-ruta/
├── backend/
│   ├── app/
│   │   ├── config.py          # konfiguracija
│   │   ├── database.py        # Neo4j veza
│   │   ├── main.py            # FastAPI aplikacija
│   │   └── routers/
│   │       ├── rute.py        # rute i preporuka
│   │       ├── oprema.py      # oprema i trošak
│   │       ├── karta.py       # kartografski podaci
│   │       └── vrijeme.py     # vremenski uvjeti
│   ├── slike.py               # skripta za dohvat fotografija
│   └── requirements.txt
├── mobile/
│   └── lib/
│       ├── main.dart
│       ├── config/config.dart
│       ├── models/
│       ├── screens/
│       ├── services/
│       └── widgets/
└── .env.example
```

## Baza podataka

- **356 čvorova:** 65 Ruta, 142 KontrolnaTocka, 95 Lokacija, 20 PodručjeHPO, 10 Oprema, 8 VremenskiUvjet, 8 TipTerena, 4 GodisnjeDoba, 4 DobnaSkupina
- **1095+ veza:** PRIPADA_PODRUCJU, POKRIVA, PREPORUCLJIVA_PO, POGODNA_U, ZAHTIJEVA_OPREMU, PRIKLADNA_ZA, IMA_TIP_TERENA, POLAZI_IZ, POLAZISTE_ZA, ODREDISTE_ZA

## Licenca

@ 2026.