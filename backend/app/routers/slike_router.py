from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse
import requests as req
from app.database import run_query
from app.config import GOOGLE_MAPS_API_KEY

router = APIRouter(prefix="/slike", tags=["Slike"])


@router.get("/kt/{naziv}")
def slika_kontrolne_tocke(naziv: str):
    """Vraća svježu sliku kontrolne točke.
    
    Dohvaća photo_ref iz baze, poziva Google Places Photo API
    za svježi URL i preusmjerava na njega. URL nikad ne istječe
    jer se generira pri svakom zahtjevu.
    """
    result = run_query(
        "MATCH (kt:KontrolnaTocka {naziv: $naziv}) "
        "RETURN kt.photo_ref AS ref",
        {"naziv": naziv},
    )
    if not result or not result[0].get("ref"):
        raise HTTPException(status_code=404, detail="Slika nije dostupna")

    photo_ref = result[0]["ref"]

    # Dohvati svježi URL od Googlea
    api_url = (
        f"https://places.googleapis.com/v1/{photo_ref}/media"
        f"?maxWidthPx=800&key={GOOGLE_MAPS_API_KEY}&skipHttpRedirect=true"
    )
    resp = req.get(api_url, timeout=10)
    data = resp.json()
    photo_uri = data.get("photoUri")

    if not photo_uri:
        raise HTTPException(status_code=404, detail="Slika nije dostupna")

    # Preusmjeri klijenta na svježi URL
    return RedirectResponse(url=photo_uri)


@router.get("/ruta/{ruta_id}")
def slike_za_rutu(ruta_id: int):
    """Vraća listu svježih URL-ova slika za sve KT jedne rute."""
    result = run_query(
        "MATCH (r:Ruta {id: $id})-[:POKRIVA]->(kt:KontrolnaTocka) "
        "WHERE kt.photo_ref IS NOT NULL "
        "RETURN kt.naziv AS naziv, kt.photo_ref AS ref",
        {"id": ruta_id},
    )

    slike = []
    for r in result:
        api_url = (
            f"https://places.googleapis.com/v1/{r['ref']}/media"
            f"?maxWidthPx=800&key={GOOGLE_MAPS_API_KEY}&skipHttpRedirect=true"
        )
        try:
            resp = req.get(api_url, timeout=10)
            data = resp.json()
            photo_uri = data.get("photoUri", "")
            slike.append({"naziv": r["naziv"], "slika_url": photo_uri})
        except Exception:
            slike.append({"naziv": r["naziv"], "slika_url": ""})

    return slike