import requests
import time
import sys
import os

# Dodaj backend/ na sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database import run_query
from app.config import GOOGLE_MAPS_API_KEY


def provjeri_kljuc():
    """Provjeri radi li API ključ uopće."""
    print(f"API ključ (prvih 10 znakova): {str(GOOGLE_MAPS_API_KEY)[:10]}")
    if not GOOGLE_MAPS_API_KEY:
        print("GREŠKA: GOOGLE_MAPS_API_KEY je prazan u .env!")
        return False

    # Testni poziv na jedan vrh
    url = "https://places.googleapis.com/v1/places:searchText"
    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": GOOGLE_MAPS_API_KEY,
        "X-Goog-FieldMask": "places.id,places.displayName,places.photos",
    }
    body = {
        "textQuery": "Sljeme Zagreb",
        "locationBias": {
            "circle": {
                "center": {"latitude": 45.899, "longitude": 15.947},
                "radius": 5000.0,
            }
        },
    }
    print("\nTestni poziv za 'Sljeme Zagreb'...")
    resp = requests.post(url, json=body, headers=headers, timeout=10)
    print(f"HTTP status: {resp.status_code}")
    data = resp.json()
    print(f"Odgovor: {data}")
    return resp.status_code == 200


def dohvati_photo_name(naziv: str, lat: float, lng: float) -> str | None:
    url = "https://places.googleapis.com/v1/places:searchText"
    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": GOOGLE_MAPS_API_KEY,
        "X-Goog-FieldMask": "places.id,places.displayName,places.photos",
    }
    # Koristi samo prvu riječ naziva za bolji match
    kljucna_rijec = naziv.split(" - ")[0].split(" vrh")[0].strip()
    body = {
        "textQuery": f"{kljucna_rijec} Hrvatska planina",
        "locationBias": {
            "circle": {
                "center": {"latitude": lat, "longitude": lng},
                "radius": 10000.0,
            }
        },
        "languageCode": "hr",
    }
    resp = requests.post(url, json=body, headers=headers, timeout=10)
    data = resp.json()

    if "error" in data:
        print(f"  API ERROR: {data['error'].get('message', '')}")
        return None

    places = data.get("places", [])
    if not places:
        return None

    photos = places[0].get("photos", [])
    if not photos:
        return None

    return photos[0]["name"]


# U slike.py — zamijeni photo_url funkciju
def photo_url(photo_name: str, max_width: int = 800) -> str:
    """Dohvati pravi redirect URL od Googlea i spremi taj."""
    key = str(GOOGLE_MAPS_API_KEY)  # osiguraj da je string
    api_url = (
        "https://places.googleapis.com/v1/"
        + photo_name
        + "/media?maxWidthPx="
        + str(max_width)
        + "&key="
        + key
        + "&skipHttpRedirect=true"
    )
    print(f"  DEBUG photo_url: {api_url[:100]}...")
    resp = requests.get(api_url, timeout=10)
    print(f"  DEBUG status: {resp.status_code}")
    data = resp.json()
    pravi_url = data.get("photoUri", "")
    print(f"  DEBUG photoUri: {pravi_url[:80] if pravi_url else 'PRAZNO'}")
    return pravi_url

def main():
    print("=" * 50)
    print("DIJAGNOSTIKA API KLJUČA")
    print("=" * 50)

    ok = provjeri_kljuc()
    if not ok:
        print("\nAPI ključ ne radi. Provjeri:")
        print("1. Places API (New) je Enabled u Google Cloud Console")
        print("2. API ključ nema restrikciju 'Android apps'")
        print("3. .env ima ispravan GOOGLE_MAPS_API_KEY")
        return

    print("\n" + "=" * 50)
    print("DOHVAT SLIKA ZA KT")
    print("=" * 50)

    kts = run_query("""
        MATCH (kt:KontrolnaTocka)
        WHERE kt.slika_url IS NULL AND kt.lat IS NOT NULL
        RETURN kt.naziv AS naziv, kt.lat AS lat, kt.lng AS lng
        LIMIT 10
    """)
    print(f"\nTestiram prvih 10 KT od {len(kts)} bez slike:\n")

    uspjeh, neuspjeh = 0, 0
    for kt in kts:
        print(f"Tražim: {kt['naziv']}")
        try:
            photo_name = dohvati_photo_name(kt["naziv"], kt["lat"], kt["lng"])
            if photo_name:
                url = photo_url(photo_name)
                run_query(
                    "MATCH (kt:KontrolnaTocka {naziv: $naziv}) SET kt.slika_url = $url",
                    {"naziv": kt["naziv"], "url": url},
                )
                uspjeh += 1
                print(f"  OK: {url[:80]}...")
            else:
                neuspjeh += 1
                print(f"  NEMA SLIKE")
        except Exception as e:
            neuspjeh += 1
            print(f"  GREŠKA: {e}")
        time.sleep(0.3)

    print(f"\nRezultat: {uspjeh} OK, {neuspjeh} bez slike")
    if uspjeh > 0:
        print("\nNastavljam s ostalima...")
        # Pokreni za sve
        sve_kts = run_query("""
            MATCH (kt:KontrolnaTocka)
            WHERE kt.slika_url IS NULL AND kt.lat IS NOT NULL
            RETURN kt.naziv AS naziv, kt.lat AS lat, kt.lng AS lng
        """)
        for kt in sve_kts:
            try:
                photo_name = dohvati_photo_name(kt["naziv"], kt["lat"], kt["lng"])
                if photo_name:
                    url = photo_url(photo_name)
                    run_query(
                        "MATCH (kt:KontrolnaTocka {naziv: $naziv}) SET kt.slika_url = $url",
                        {"naziv": kt["naziv"], "url": url},
                    )
                    print(f"OK: {kt['naziv']}")
                time.sleep(0.3)
            except Exception as e:
                print(f"GREŠKA {kt['naziv']}: {e}")


if __name__ == "__main__":
    main()