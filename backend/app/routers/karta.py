from fastapi import APIRouter, Query, HTTPException
from typing import Optional
from app.database import run_query
from app.config import GOOGLE_MAPS_API_KEY
import requests as req

router = APIRouter(prefix="/karta", tags=["Karta"])


def _svjezi_url(photo_ref: str) -> str:
    """Dohvati svježi URL iz photo_ref."""
    if not photo_ref:
        return ""
    try:
        api_url = (
            f"https://places.googleapis.com/v1/{photo_ref}/media"
            f"?maxWidthPx=800&key={GOOGLE_MAPS_API_KEY}&skipHttpRedirect=true"
        )
        resp = req.get(api_url, timeout=10)
        data = resp.json()
        return data.get("photoUri", "")
    except Exception:
        return ""


@router.get("/ruta/{ruta_id}")
def karta_rute(ruta_id: int):
    query = """
    MATCH (r:Ruta {id: $id})
    OPTIONAL MATCH (r)-[:POLAZI_IZ]->(pol:Lokacija)
    OPTIONAL MATCH (r)-[:POKRIVA]->(kt:KontrolnaTocka)
    RETURN
        r.naziv       AS naziv,
        r.tezina      AS tezina,
        r.duljinakm   AS duljina_km,
        r.trajanjeh   AS trajanje_h,
        pol.naziv     AS polaziste_naziv,
        pol.lat       AS polaziste_lat,
        pol.lng       AS polaziste_lng,
        COLLECT(DISTINCT {
            naziv:  kt.naziv,
            lat:    kt.lat,
            lng:    kt.lng,
            visina: kt.visinam,
            tezina: kt.tezina,
            photo_ref: kt.photo_ref
        }) AS kontrolne_tocke
    """
    result = run_query(query, {"id": ruta_id})
    if not result:
        raise HTTPException(status_code=404, detail="Ruta nije pronađena")

    r = result[0]
    waypoints = []
    if r.get("polaziste_lat"):
        waypoints.append({
            "tip": "polaziste",
            "naziv": r["polaziste_naziv"],
            "lat": r["polaziste_lat"],
            "lng": r["polaziste_lng"],
            "slika_url": None,
        })

    for kt in r.get("kontrolne_tocke", []):
        if kt.get("lat"):
            slika = _svjezi_url(kt.get("photo_ref")) if kt.get("photo_ref") else None
            waypoints.append({
                "tip": "kontrolna_tocka",
                "naziv": kt["naziv"],
                "lat": kt["lat"],
                "lng": kt["lng"],
                "visina_m": kt["visina"],
                "tezina": kt.get("tezina"),
                "slika_url": slika,
            })

    maps_url = None
    if waypoints:
        origin = f"{waypoints[0]['lat']},{waypoints[0]['lng']}"
        destination = f"{waypoints[-1]['lat']},{waypoints[-1]['lng']}"
        maps_url = (
            f"https://www.google.com/maps/dir/?api=1"
            f"&origin={origin}&destination={destination}&travelmode=walking"
        )

    return {
        "ruta": r["naziv"],
        "tezina": r["tezina"],
        "duljina_km": r.get("duljina_km"),
        "trajanje_h": r.get("trajanje_h"),
        "waypoints": waypoints,
        "maps_url": maps_url,
    }


@router.get("/kontrolne-tocke")
def sve_kontrolne_tocke(
    podrucje_id: Optional[int] = Query(None),
    tezina: Optional[str] = Query(None),
):
    where = []
    params = {}
    if tezina:
        where.append("kt.tezina = $tezina")
        params["tezina"] = tezina

    where_str = "WHERE " + " AND ".join(where) if where else ""

    podrucje_match = ""
    if podrucje_id:
        podrucje_match = "MATCH (kt)-[:PRIPADA_PODRUCJU]->(p:PodručjeHPO {id: $podrucje_id})"
        params["podrucje_id"] = podrucje_id

    query = f"""
    MATCH (kt:KontrolnaTocka)
    {podrucje_match}
    {where_str}
    RETURN
        kt.naziv     AS naziv,
        kt.lat       AS lat,
        kt.lng       AS lng,
        kt.visinam   AS visina_m,
        kt.tezina    AS tezina,
        kt.photo_ref AS photo_ref
    ORDER BY kt.visinam DESC
    """
    return run_query(query, params)


@router.get("/sve-rute")
def sve_rute_za_kartu(
    regija: Optional[str] = Query(None),
):
    where = "WHERE kt.lat IS NOT NULL"
    params = {}
    if regija:
        where += " AND r.regija CONTAINS $regija"
        params["regija"] = regija

    query = f"""
    MATCH (r:Ruta)
    OPTIONAL MATCH (r)-[:POLAZI_IZ]->(l:Lokacija)
    OPTIONAL MATCH (r)-[:POKRIVA]->(kt:KontrolnaTocka)
    {where}
    RETURN
        r.id        AS id,
        r.naziv     AS naziv,
        r.tezina    AS tezina,
        r.regija    AS regija,
        l.lat       AS polaziste_lat,
        l.lng       AS polaziste_lng,
        l.naziv     AS polaziste_naziv,
        COLLECT(DISTINCT {{
            naziv:  kt.naziv,
            lat:    kt.lat,
            lng:    kt.lng,
            visina: kt.visinam,
            tezina: kt.tezina,
            photo_ref: kt.photo_ref
        }}) AS tocke
    ORDER BY r.id
    """
    results = run_query(query, params)

    # Dohvati svježe URL-ove za sve tocke
    for ruta in results:
        for t in ruta.get("tocke", []):
            ref = t.get("photo_ref")
            t["slika_url"] = _svjezi_url(ref) if ref else None
            t.pop("photo_ref", None)

    return results