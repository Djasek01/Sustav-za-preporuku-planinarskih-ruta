"""
backend/app/routers/regije_api.py
API za pretraživanje ruta po regijama i HPS podacima.
"""
from fastapi import APIRouter, Query, HTTPException
from typing import Any, Optional, Union
from app.database import run_query

router = APIRouter(prefix="/regije", tags=["Regije i HPS putovi"])


@router.get("/sve")
async def sve_regije():
    """Dohvati sve regije s brojem ruta."""
    query = """
    MATCH (r:Ruta)
    WITH r.regija AS regija, COUNT(r) AS broj_ruta
    ORDER BY broj_ruta DESC
    RETURN regija, broj_ruta
    """
    return run_query(query)


@router.get("/podregije/{regija}")
async def podregije(regija: str):
    """Dohvati podregije za danu regiju."""
    query = """
    MATCH (r:Ruta)
    WHERE r.regija = $regija AND r.podregija IS NOT NULL AND r.podregija <> ''
    WITH r.podregija AS podregija, COUNT(r) AS broj_ruta
    ORDER BY broj_ruta DESC
    RETURN podregija, broj_ruta
    """
    return run_query(query, {"regija": regija})


@router.get("/rute")
async def rute_po_regiji(
    regija: Optional[str] = Query(None, description="Naziv regije"),
    podregija: Optional[str] = Query(None, description="Naziv podregije"),
    tezina: Optional[str] = Query(None, description="lagana/srednja/teska"),
    min_trajanje: Optional[float] = Query(None, description="Min trajanje (h)"),
    max_trajanje: Optional[float] = Query(None, description="Max trajanje (h)"),
    hpd: Optional[str] = Query(None, description="Naziv planinarskog društva"),
    pretraga: Optional[str] = Query(None, description="Pretraži po nazivu rute"),
    sortiraj: Optional[str] = Query("naziv", description="naziv/trajanje/duljina"),
    limit: int = Query(50, le=200),
    offset: int = Query(0),
):
    """Pretraži rute s raznim filterima."""
    filters: list[str] = []
    params: dict[str, Any] = {"limit": limit, "offset": offset}

    if regija:
        filters.append("r.regija = $regija")
        params["regija"] = regija
    if podregija:
        filters.append("r.podregija = $podregija")
        params["podregija"] = podregija
    if tezina:
        filters.append("r.tezina = $tezina")
        params["tezina"] = tezina
    if min_trajanje is not None:
        filters.append("r.trajanjeh >= $min_trajanje")
        params["min_trajanje"] = min_trajanje
    if max_trajanje is not None:
        filters.append("r.trajanjeh <= $max_trajanje")
        params["max_trajanje"] = max_trajanje
    if hpd:
        filters.append("r.hpd CONTAINS $hpd")
        params["hpd"] = hpd
    if pretraga:
        filters.append("toLower(r.naziv) CONTAINS toLower($pretraga)")
        params["pretraga"] = pretraga

    where = "WHERE " + " AND ".join(filters) if filters else ""

    order_map = {
        "naziv": "r.naziv",
        "trajanje": "r.trajanjeh",
        "duljina": "r.duljinakm",
    }
    order_by = order_map.get(sortiraj or "naziv", "r.naziv")

    query = f"""
    MATCH (r:Ruta)
    {where}
    OPTIONAL MATCH (r)-[:POLAZI_IZ]->(l:Lokacija)
    OPTIONAL MATCH (r)-[:IMA_TIP_TERENA]->(tt:TipTerena)
    RETURN
        r.id               AS id,
        r.naziv            AS naziv,
        r.hps_broj         AS hps_broj,
        r.hpd              AS hpd,
        r.tezina           AS tezina,
        r.regija           AS regija,
        r.podregija        AS podregija,
        r.duljinakm        AS duljina_km,
        r.trajanjeh        AS trajanje_h,
        r.visinskarazlikam AS visinska_razlika_m,
        l.lat              AS polaziste_lat,
        l.lng              AS polaziste_lng,
        l.naziv            AS polaziste_naziv,
        COLLECT(DISTINCT tt.naziv) AS tip_terena
    ORDER BY {order_by}
    SKIP $offset
    LIMIT $limit
    """

    rute = run_query(query, params)

    # Ukupan broj za paginaciju
    count_query = f"""
    MATCH (r:Ruta) {where}
    RETURN COUNT(r) AS ukupno
    """
    count = run_query(count_query, params)
    ukupno = count[0]["ukupno"] if count else 0

    return {
        "ukupno": ukupno,
        "offset": offset,
        "limit": limit,
        "rute": rute,
    }


@router.get("/statistika")
async def statistika():
    """Statistika baze — ukupni brojevi po svemu."""
    query = """
    MATCH (r:Ruta)
    WITH COUNT(r) AS ukupno_ruta,
         COUNT(CASE WHEN r.tezina = 'lagana' THEN 1 END) AS lagane,
         COUNT(CASE WHEN r.tezina = 'srednja' THEN 1 END) AS srednje,
         COUNT(CASE WHEN r.tezina = 'teska' THEN 1 END) AS teske,
         COUNT(CASE WHEN r.izvor = 'HPS' THEN 1 END) AS hps_rute,
         COLLECT(DISTINCT r.regija) AS regije
    RETURN ukupno_ruta, lagane, srednje, teske, hps_rute,
           SIZE(regije) AS broj_regija
    """
    result = run_query(query)
    if result:
        return result[0]
    return {}