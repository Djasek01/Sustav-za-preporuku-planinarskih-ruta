import requests
import time
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from app.database import run_query
from app.config import GOOGLE_MAPS_API_KEY


def dohvati_photo_ref(naziv: str, lat: float, lng: float) -> str | None:
    url = "https://places.googleapis.com/v1/places:searchText"
    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": GOOGLE_MAPS_API_KEY,
        "X-Goog-FieldMask": "places.id,places.displayName,places.photos",
    }
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
    # Spremi SAMO referencu (npr. "places/ChIJ.../photos/AelY...")
    return photos[0]["name"]


def main():
    print("=" * 50)
    print("DOHVAT PHOTO REFERENCI (ne URL-ova)")
    print("=" * 50)

    # Testiraj API ključ
    print(f"API ključ: {str(GOOGLE_MAPS_API_KEY)[:10]}...")

    # Obriši sve stare slika_url
    run_query("MATCH (kt:KontrolnaTocka) REMOVE kt.slika_url, kt.photo_ref")
    print("Obrisane stare slike.\n")

    kts = run_query("""
        MATCH (kt:KontrolnaTocka)
        WHERE kt.lat IS NOT NULL
        RETURN kt.naziv AS naziv, kt.lat AS lat, kt.lng AS lng
        ORDER BY kt.naziv
    """)
    print(f"Tražim slike za {len(kts)} KT...\n")

    uspjeh, neuspjeh = 0, 0
    for i, kt in enumerate(kts, 1):
        try:
            ref = dohvati_photo_ref(kt["naziv"], kt["lat"], kt["lng"])
            if ref:
                run_query(
                    "MATCH (kt:KontrolnaTocka {naziv: $naziv}) SET kt.photo_ref = $ref",
                    {"naziv": kt["naziv"], "ref": ref},
                )
                uspjeh += 1
                print(f"[{i}/{len(kts)}] OK: {kt['naziv']}")
            else:
                neuspjeh += 1
                print(f"[{i}/{len(kts)}] NEMA: {kt['naziv']}")
        except Exception as e:
            neuspjeh += 1
            print(f"[{i}/{len(kts)}] GREŠKA: {kt['naziv']} — {str(e)[:50]}")
        time.sleep(0.3)

    print(f"\nGotovo. Uspjeh: {uspjeh}, bez slike: {neuspjeh}")


if __name__ == "__main__":
    main()