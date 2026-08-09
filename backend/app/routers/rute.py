from fastapi import APIRouter, Query, HTTPException
from typing import Optional
from app.database import run_query

router = APIRouter(prefix="/rute", tags=["Rute"])


def dobna_ogranicenja(dob: int) -> dict:
    """Graduirana skala ograničenja po dobi — kalibrirano za HR uvjete."""
    if dob < 7:
        return {"max_duljina_km": 5, "max_visinska_m": 300, "tezine": ["lagana"]}
    elif dob < 12:
        return {"max_duljina_km": 10, "max_visinska_m": 600, "tezine": ["lagana", "srednja"]}
    elif dob < 16:
        return {"max_duljina_km": 15, "max_visinska_m": 1000, "tezine": ["lagana", "srednja", "teska"]}
    elif dob < 65:
        # Odrasli — bez ograničenja
        return {"max_duljina_km": None, "max_visinska_m": None, "tezine": ["lagana", "srednja", "teska"]}
    else:
        return {"max_duljina_km": 12, "max_visinska_m": 800, "tezine": ["lagana", "srednja"]}


@router.get("/")
def get_rute(
    tezina: Optional[str] = Query(None),
    regija: Optional[str] = Query(None),
    max_trajanje: Optional[float] = Query(None),
    limit: int = Query(65, le=1300),
):
    where_clauses = []
    params = {"limit": limit}

    if tezina:
        where_clauses.append("r.tezina = $tezina")
        params["tezina"] = tezina
    if regija:
        where_clauses.append("r.regija CONTAINS $regija")
        params["regija"] = regija
    if max_trajanje:
        where_clauses.append("r.trajanjeh <= $max_trajanje")
        params["max_trajanje"] = max_trajanje

    where_str = "WHERE " + " AND ".join(where_clauses) if where_clauses else ""

    query = f"""
    MATCH (r:Ruta)
    {where_str}
    OPTIONAL MATCH (r)-[:PRIPADA_PODRUCJU]->(p:PodručjeHPO)
    OPTIONAL MATCH (r)-[:POKRIVA]->(kt:KontrolnaTocka)
    RETURN
        r.id AS id, r.naziv AS naziv, r.tezina AS tezina,
        r.regija AS regija, r.duljinakm AS duljina_km,
        r.trajanjeh AS trajanje_h, r.visinskarazlikam AS visinska_razlika_m,
        r.trosak AS trosak, p.naziv AS podrucje,
        COLLECT(DISTINCT kt.naziv) AS kontrolne_tocke
    ORDER BY r.trajanjeh
    LIMIT $limit
    """
    return run_query(query, params)


@router.get("/preporuka/rute")
def preporuka_ruta(
    dob: Optional[int] = Query(None, ge=1, le=110),
    godisnje_doba: Optional[str] = Query(None),
    tezina: Optional[str] = Query(None),
    tip_terena: Optional[str] = Query(None),
    vremenski_uvjet: Optional[str] = Query(None),
    regija: Optional[str] = Query(None),
    limit: int = Query(50, le=100),
):
    params = {"limit": limit}
    where_clauses = []
    extra_matches = []

    if dob is not None:
        og = dobna_ogranicenja(dob)
        where_clauses.append("r.tezina IN $dozvoljene_tezine")
        params["dozvoljene_tezine"] = og["tezine"]

        if og["max_duljina_km"] is not None:
            where_clauses.append("COALESCE(r.duljinakm, 0) <= $max_duljina")
            params["max_duljina"] = og["max_duljina_km"]

        if og["max_visinska_m"] is not None:
            where_clauses.append("COALESCE(r.visinskarazlikam, 0) <= $max_visinska")
            params["max_visinska"] = og["max_visinska_m"]

    if tezina:
        where_clauses.append("r.tezina = $tezina")
        params["tezina"] = tezina

    if regija:
        where_clauses.append("r.regija CONTAINS $regija")
        params["regija"] = regija

    if vremenski_uvjet:
        where_clauses.append(
            "NOT (r)-[:PREPORUCLJIVA_PO {preporuka: 'izbjegavati'}]->(:VremenskiUvjet {naziv: $vremenski_uvjet})"
        )
        params["vremenski_uvjet"] = vremenski_uvjet

    if godisnje_doba:
        extra_matches.append("MATCH (r)-[:POGODNA_U]->(:GodisnjeDoba {naziv: $godisnje_doba})")
        params["godisnje_doba"] = godisnje_doba

    if tip_terena:
        extra_matches.append("MATCH (r)-[:IMA_TIP_TERENA]->(:TipTerena {naziv: $tip_terena})")
        params["tip_terena"] = tip_terena

    where_str = "WHERE " + " AND ".join(where_clauses) if where_clauses else ""
    extra_str = "\n    ".join(extra_matches)

    query = f"""
    MATCH (r:Ruta)
    {extra_str}
    {where_str}
    OPTIONAL MATCH (r)-[:PRIPADA_PODRUCJU]->(p:PodručjeHPO)
    OPTIONAL MATCH (r)-[:POKRIVA]->(kt:KontrolnaTocka)
    OPTIONAL MATCH (r)-[:IMA_TIP_TERENA]->(tt2:TipTerena)
    OPTIONAL MATCH (r)-[:ZAHTIJEVA_OPREMU]->(o:Oprema)
    OPTIONAL MATCH (r)-[:POLAZI_IZ]->(l:Lokacija)
    RETURN
        r.id AS id, r.naziv AS naziv, r.tezina AS tezina,
        r.regija AS regija, r.duljinakm AS duljina_km,
        r.trajanjeh AS trajanje_h, r.visinskarazlikam AS visinska_razlika_m,
        r.trosak AS trosak, p.naziv AS podrucje,
        l.lat AS polaziste_lat, l.lng AS polaziste_lng,
        l.naziv AS polaziste_naziv,
        COLLECT(DISTINCT kt.naziv) AS kontrolne_tocke,
        COLLECT(DISTINCT tt2.naziv) AS tip_terena,
        COLLECT(DISTINCT o.naziv) AS oprema
    ORDER BY r.tezina DESC, r.trajanjeh
    LIMIT $limit
    """
    rezultati = run_query(query, params)

    meta = {}
    if dob is not None:
        og = dobna_ogranicenja(dob)
        meta = {
            "dob": dob,
            "dozvoljene_tezine": og["tezine"],
            "max_duljina_km": og["max_duljina_km"],
            "max_visinska_m": og["max_visinska_m"],
        }

    return {"ogranicenja": meta, "broj_rezultata": len(rezultati), "rute": rezultati}


@router.get("/{ruta_id}")
def get_ruta(ruta_id: int):
    query = """
    MATCH (r:Ruta {id: $id})
    OPTIONAL MATCH (r)-[:PRIPADA_PODRUCJU]->(p:PodručjeHPO)
    OPTIONAL MATCH (r)-[:POKRIVA]->(kt:KontrolnaTocka)
    OPTIONAL MATCH (r)-[:IMA_TIP_TERENA]->(tt:TipTerena)
    OPTIONAL MATCH (r)-[:ZAHTIJEVA_OPREMU]->(o:Oprema)
    OPTIONAL MATCH (r)-[:POGODNA_U]->(g:GodisnjeDoba)
    OPTIONAL MATCH (r)-[:PRIKLADNA_ZA]->(d:DobnaSkupina)
    OPTIONAL MATCH (r)-[:POLAZI_IZ]->(l:Lokacija)
    OPTIONAL MATCH (r)-[:PREPORUCLJIVA_PO]->(v:VremenskiUvjet)
    RETURN
        r.id AS id, r.naziv AS naziv, r.tezina AS tezina,
        r.regija AS regija, r.duljinakm AS duljina_km,
        r.trajanjeh AS trajanje_h, r.visinskarazlikam AS visinska_razlika_m,
        r.trosak AS trosak, p.naziv AS podrucje,
        l.lat AS polaziste_lat, l.lng AS polaziste_lng,
        l.naziv AS polaziste_naziv,
        COLLECT(DISTINCT kt.naziv) AS kontrolne_tocke,
        COLLECT(DISTINCT tt.naziv) AS tip_terena,
        COLLECT(DISTINCT o.naziv) AS oprema,
        COLLECT(DISTINCT g.naziv) AS godisnja_doba,
        COLLECT(DISTINCT d.naziv) AS dobne_skupine,
        COLLECT(DISTINCT {uvjet: v.naziv}) AS vremenski_uvjeti
    """
    result = run_query(query, {"id": ruta_id})
    if not result:
        raise HTTPException(status_code=404, detail="Ruta nije pronađena")
    return result[0]