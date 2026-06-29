from fastapi import APIRouter, Query
from typing import Optional
from app.database import run_query

router = APIRouter(prefix="/oprema", tags=["Oprema"])


# ─────────────────────────────────────────
# GET /oprema  — sva oprema
# ─────────────────────────────────────────
@router.get("/")
def get_oprema():
    query = """
    MATCH (o:Oprema)
    RETURN o.naziv AS naziv, o.opis AS opis, o.trosak AS trosak
    ORDER BY o.naziv
    """
    return run_query(query)


# ─────────────────────────────────────────
# GET /oprema/za-rutu/{ruta_id}
# Funkcionalnost 5: preporuka opreme
# ─────────────────────────────────────────
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
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Ruta nema definiranu opremu ili ne postoji")

    # Ukupni trošak opreme
    ukupno = sum(r.get("trosak_kn") or 0 for r in result)
    return {
        "ruta": result[0]["ruta"] if result else None,
        "tezina": result[0]["tezina"] if result else None,
        "oprema": result,
        "ukupni_trosak_eur": round(ukupno, 2)
    }


# ─────────────────────────────────────────
# GET /oprema/procjena-troska/{ruta_id}
# Funkcionalnost 6: procjena troška izleta
# ─────────────────────────────────────────
@router.get("/procjena-troska/{ruta_id}")
def procjena_troska(
    ruta_id: int,
    broj_sudionika: int = Query(1, ge=1, le=50, description="Broj sudionika"),
    vlastita_oprema: bool = Query(False, description="Ima li vlastitu opremu"),
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
        COLLECT(DISTINCT {naziv: o.naziv, trosak: o.trosak}) AS oprema_lista
    """
    result = run_query(query, {"id": ruta_id})
    if not result:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Ruta nije pronađena")

    r = result[0]
    trosak_rute = r.get("trosak_rute") or 0
    trosak_opreme = 0 if vlastita_oprema else sum(
        (o.get("trosak") or 0) for o in r.get("oprema_lista", []) if o.get("naziv")
    )

    # Procjena goriva: ~0.15 EUR/km, prosječna udaljenost do polazišta 50km
    trosak_prijevoza = round(50 * 0.15 * 2, 2)  # tamo-natrag

    ukupno_po_osobi = round(trosak_rute + trosak_opreme + trosak_prijevoza, 2)
    ukupno_grupa = round(ukupno_po_osobi * broj_sudionika, 2)

    return {
        "ruta": r["naziv"],
        "tezina": r["tezina"],
        "trajanje_h": r["trajanje_h"],
        "duljina_km": r["duljina_km"],
        "polaziste": r["polaziste"],
        "broj_sudionika": broj_sudionika,
        "vlastita_oprema": vlastita_oprema,
        "troskovi": {
            "trosak_rute_eur": trosak_rute,
            "trosak_opreme_eur": trosak_opreme,
            "procjena_prijevoza_eur": trosak_prijevoza,
            "ukupno_po_osobi_eur": ukupno_po_osobi,
            "ukupno_grupa_eur": ukupno_grupa,
        },
        "oprema": r["oprema_lista"]
    }
