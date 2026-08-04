# backend/skripta_slike.py
# Pokreni JEDNOM: python skripta_slike.py
# Dohvaća Google Places fotografije za sve KT i sprema URL u Neo4j

import requests
import time
from app.database import run_query
from app.config import GOOGLE_MAPS_API_KEY

def dohvati_place_id(naziv: str, lat: float, lng: float) -> str | None:
    """Text Search (New) - nađi place_id za vrh."""
    url = "https://places.googleapis.com/v1/places:searchText"
    headers = {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": GOOGLE_MAPS_API_KEY,
        "X-Goog-FieldMask": "places.id,places.photos",
    }
    body = {
        "textQuery": naziv.split(" - ")[0],  # "Sljeme - vrh" -> "Sljeme"
        "locationBias": {
            "circle": {
                "center": {"latitude": lat, "longitude": lng},
                "radius": 5000.0
            }
        },
        "languageCode": "hr",
    }
    resp = requests.post(url, json=body, headers=headers, timeout=10)
    data = resp.json()
    places = data.get("places", [])
    if not places:
        return None
    photos = places[0].get("photos", [])
    if not photos:
        return None
    # Vrati photo resource name (koristi se za Photo URL)
    return photos[0]["name"]


def photo_url(photo_name: str, max_width: int = 640) -> str:
    """Generira direktni URL fotografije."""
    return (
        f"https://places.googleapis.com/v1/{photo_name}/media"
        f"?maxWidthPx={max_width}&key={GOOGLE_MAPS_API_KEY}"
    )


def main():
    # Sve KT bez slike
    kts = run_query("""
        MATCH (kt:KontrolnaTocka)
        WHERE kt.slika_url IS NULL
        RETURN kt.naziv AS naziv, kt.lat AS lat, kt.lng AS lng
    """)
    print(f"KT bez slike: {len(kts)}")

    uspjeh, neuspjeh = 0, 0
    for kt in kts:
        try:
            photo_name = dohvati_place_id(kt["naziv"], kt["lat"], kt["lng"])
            if photo_name:
                url = photo_url(photo_name)
                run_query(
                    "MATCH (kt:KontrolnaTocka {naziv: $naziv}) SET kt.slika_url = $url",
                    {"naziv": kt["naziv"], "url": url},
                )
                uspjeh += 1
                print(f"OK: {kt['naziv']}")
            else:
                neuspjeh += 1
                print(f"NEMA SLIKE: {kt['naziv']}")
        except Exception as e:
            neuspjeh += 1
            print(f"GREŠKA {kt['naziv']}: {e}")
        time.sleep(0.2)  # rate limiting

    print(f"\nGotovo. Uspjeh: {uspjeh}, bez slike: {neuspjeh}")


if __name__ == "__main__":
    main()