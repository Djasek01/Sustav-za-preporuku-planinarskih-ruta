from fastapi import APIRouter, Query
from typing import Optional
from app.database import run_query
from app.config import GOOGLE_MAPS_API_KEY

router = APIRouter(prefix="/karta", tags=["Karta"])


# ─────────────────────────────────────────
# GET /karta/ruta/{ruta_id}
# Funkcionalnost 4: prikaz rute na karti
# Vraća koordinate za Google Maps u Flutteru
# ─────────────────────────────────────────
@router.get("/ruta/{ruta_id}")
def karta_rute(ruta_id: int):
    query = """
    MATCH (r:Ruta {id: $id})
    OPTIONAL MATCH (r)-[:POLAZI_IZ]->(pol:Lokacija)
    OPTIONAL MATCH (r)-[:POKRIVA]->(kt:KontrolnaTocka)
    OPTIONAL MATCH (kt)-[:ODREDISTE_ZA]-(odred:Lokacija)
    RETURN
        r.naziv       AS naziv,
        r.tezina      AS tezina,
        pol.naziv     AS polaziste_naziv,
        pol.lat       AS polaziste_lat,
        pol.lng       AS polaziste_lng,
        COLLECT(DISTINCT {
            naziv: kt.naziv,
            lat:   kt.lat,
            lng:   kt.lng,
            visina: kt.visinam,
            tezina: kt.tezina
        }) AS kontrolne_tocke
    """
    result = run_query(query, {"id": ruta_id})
    if not result:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Ruta nije pronađena")

    r = result[0]

    # Sve točke za Google Maps polyline
    waypoints = []
    if r.get("polaziste_lat"):
        waypoints.append({
            "tip": "polaziste",
            "naziv": r["polaziste_naziv"],
            "lat": r["polaziste_lat"],
            "lng": r["polaziste_lng"],
        })

    for kt in r.get("kontrolne_tocke", []):
        if kt.get("lat"):
            waypoints.append({
                "tip": "kontrolna_tocka",
                "naziv": kt["naziv"],
                "lat": kt["lat"],
                "lng": kt["lng"],
                "visina_m": kt["visina"],
            })

    # Google Maps Directions URL za Flutter WebView
    maps_url = None
    if waypoints:
        origin = f"{waypoints[0]['lat']},{waypoints[0]['lng']}"
        destination = f"{waypoints[-1]['lat']},{waypoints[-1]['lng']}"
        maps_url = (
            f"https://www.google.com/maps/dir/?api=1"
            f"&origin={origin}"
            f"&destination={destination}"
            f"&travelmode=walking"
        )

    return {
        "ruta": r["naziv"],
        "tezina": r["tezina"],
        "waypoints": waypoints,
        "maps_url": maps_url,
        "google_maps_api_key": GOOGLE_MAPS_API_KEY,
    }


# ─────────────────────────────────────────
# GET /karta/kontrolne-tocke
# Sve KT s koordinatama za prikaz na karti
# ─────────────────────────────────────────
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
        kt.naziv    AS naziv,
        kt.lat      AS lat,
        kt.lng      AS lng,
        kt.visinam  AS visina_m,
        kt.tezina   AS tezina
    ORDER BY kt.visinam DESC
    """
    return run_query(query, params)
