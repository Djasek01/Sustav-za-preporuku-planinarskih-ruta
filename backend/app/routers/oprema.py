from fastapi import APIRouter, Query, HTTPException
from typing import Optional
from app.database import run_query

router = APIRouter(prefix="/oprema", tags=["Oprema"])


@router.get("/")
def get_oprema():
    query = """
    MATCH (o:Oprema)
    RETURN o.naziv AS naziv, o.opis AS opis, o.trosak AS trosak
    ORDER BY o.trosak DESC
    """
    return run_query(query)


@router.get("/za-rutu/{ruta_id}")
def oprema_za_rutu(ruta_id: int):
    query = """
    MATCH (r:Ruta {id: $id})-[:ZAHTIJEVA_OPREMU]->(o:Oprema)
    RETURN
        r.naziv   AS ruta,
        r.tezina  AS tezina,
        o.naziv   AS oprema,
        o.opis    AS opis,
        o.trosak  AS trosak_kn
    ORDER BY o.trosak DESC
    """
    result = run_query(query, {"id": ruta_id})
    if not result:
        raise HTTPException(status_code=404, detail="Ruta nema definiranu opremu ili ne postoji")

    ukupno = sum(r.get("trosak_kn") or 0 for r in result)
    return {
        "ruta": result[0]["ruta"] if result else None,
        "tezina": result[0]["tezina"] if result else None,
        "oprema": result,
        "ukupni_trosak_eur": round(ukupno, 2)
    }


@router.get("/procjena-troska/{ruta_id}")
def procjena_troska(
    ruta_id: int,
    broj_sudionika: int = Query(1, ge=1, le=50),
    vlastita_oprema: bool = Query(False),
    udaljenost_km: Optional[float] = Query(None, description="Udaljenost do polazišta u km (ako nije zadano, procjenjuje se 50 km)"),
):
    query = """
    MATCH (r:Ruta {id: $id})
    OPTIONAL MATCH (r)-[:ZAHTIJEVA_OPREMU]->(o:Oprema)
    OPTIONAL MATCH (r)-[:POLAZI_IZ]->(l:Lokacija)
    RETURN
        r.naziv        AS naziv,
        r.tezina       AS tezina,
        r.duljinakm    AS duljina_km,
        r.trajanjeh    AS trajanje_h,
        r.trosak       AS trosak_rute,
        l.naziv        AS polaziste,
        COLLECT(DISTINCT {naziv: o.naziv, trosak: o.trosak, opis: o.opis}) AS oprema_lista
    """
    result = run_query(query, {"id": ruta_id})
    if not result:
        raise HTTPException(status_code=404, detail="Ruta nije pronađena")

    r = result[0]
    trosak_rute = r.get("trosak_rute") or 0

    # Oprema — ako nema vlastitu, zbroji cijene svih potrebnih komada
    oprema_stavke = [o for o in r.get("oprema_lista", []) if o.get("naziv")]
    trosak_opreme = 0.0
    if not vlastita_oprema:
        trosak_opreme = sum((o.get("trosak") or 0) for o in oprema_stavke)

    # Prijevoz — realna procjena
    # Prosječna cijena goriva: 1.50 EUR/L, prosječna potrošnja: 7L/100km
    # Tamo + natrag = x2
    km = udaljenost_km or 50.0  # default 50 km ako nije zadano
    cijena_po_km = 0.105  # 7L/100km * 1.50 EUR/L = 0.105 EUR/km
    trosak_prijevoza = round(km * cijena_po_km * 2, 2)  # tamo-natrag

    # Ako dijele prijevoz, cijena se dijeli
    trosak_prijevoza_po_osobi = round(trosak_prijevoza / min(broj_sudionika, 4), 2)  # max 4 u autu

    ukupno_po_osobi = round(trosak_rute + trosak_opreme + trosak_prijevoza_po_osobi, 2)
    ukupno_grupa = round((trosak_rute + trosak_opreme) * broj_sudionika + trosak_prijevoza, 2)

    return {
        "ruta": r["naziv"],
        "tezina": r["tezina"],
        "trajanje_h": r["trajanje_h"],
        "duljina_km": r["duljina_km"],
        "polaziste": r["polaziste"],
        "broj_sudionika": broj_sudionika,
        "vlastita_oprema": vlastita_oprema,
        "udaljenost_km": km,
        "troskovi": {
            "trosak_rute_eur": trosak_rute,
            "trosak_opreme_eur": round(trosak_opreme, 2),
            "trosak_prijevoza_eur": trosak_prijevoza,
            "trosak_prijevoza_po_osobi_eur": trosak_prijevoza_po_osobi,
            "ukupno_po_osobi_eur": ukupno_po_osobi,
            "ukupno_grupa_eur": ukupno_grupa,
        },
        "oprema": [
            {
                "naziv": o.get("naziv"),
                "trosak": o.get("trosak"),
                "opis": o.get("opis"),
            }
            for o in oprema_stavke
        ],
    }