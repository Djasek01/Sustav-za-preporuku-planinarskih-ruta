from fastapi import APIRouter, Query
from typing import Optional
from app.database import run_query

router = APIRouter(prefix="/rute", tags=["Rute"])


# ─────────────────────────────────────────
# GET /rute  — popis svih ruta s filtrima
# ─────────────────────────────────────────
@router.get("/")
def get_rute(
    tezina: Optional[str] = Query(None, description="lagana | srednja | teska"),
    regija: Optional[str] = Query(None),
    max_trajanje: Optional[float] = Query(None, description="Maksimalno trajanje u satima"),
    limit: int = Query(20, le=1300),
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
        r.id          AS id,
        r.naziv       AS naziv,
        r.tezina      AS tezina,
        r.regija      AS regija,
        r.duljinakm   AS duljina_km,
        r.trajanjeh   AS trajanje_h,
        r.visinskarazlikam AS visinska_razlika_m,
        r.trosak      AS trosak,
        p.naziv       AS podrucje,
        COLLECT(DISTINCT kt.naziv) AS kontrolne_tocke
    ORDER BY r.trajanjeh
    LIMIT $limit
    """
    return run_query(query, params)


# ─────────────────────────────────────────
# GET /rute/{id}  — detalji jedne rute
# ─────────────────────────────────────────
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
        r.id               AS id,
        r.naziv            AS naziv,
        r.tezina           AS tezina,
        r.regija           AS regija,
        r.duljinakm        AS duljina_km,
        r.trajanjeh        AS trajanje_h,
        r.visinskarazlikam AS visinska_razlika_m,
        r.trosak           AS trosak,
        p.naziv            AS podrucje,
        l.lat              AS polaziste_lat,
        l.lng              AS polaziste_lng,
        l.naziv            AS polaziste_naziv,
        COLLECT(DISTINCT kt.naziv)  AS kontrolne_tocke,
        COLLECT(DISTINCT tt.naziv)  AS tip_terena,
        COLLECT(DISTINCT o.naziv)   AS oprema,
        COLLECT(DISTINCT g.naziv)   AS godisnja_doba,
        COLLECT(DISTINCT d.naziv)   AS dobne_skupine,
        COLLECT(DISTINCT {uvjet: v.naziv}) AS vremenski_uvjeti
    """
    result = run_query(query, {"id": ruta_id})
    if not result:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Ruta nije pronađena")
    return result[0]


# ─────────────────────────────────────────
# GET /rute/preporuka  — 6 kriterija završnog rada
# Funkcionalnost 1: po dobi
# Funkcionalnost 2: po vremenskim uvjetima
# Funkcionalnost 3: po težini
# ─────────────────────────────────────────
@router.get("/preporuka/rute")
def preporuka_ruta(
    dob: Optional[int] = Query(None, description="Dob planinarа u godinama"),
    dobna_skupina: Optional[str] = Query(None, description="djeca | mladi | odrasli | starije osobe"),
    godisnje_doba: Optional[str] = Query(None, description="proljece | ljeto | jesen | zima"),
    tezina: Optional[str] = Query(None, description="lagana | srednja | teska"),
    tip_terena: Optional[str] = Query(None, description="Naziv tipa terena"),
    vremenski_uvjet: Optional[str] = Query(None, description="vjetar | magla | kisovito | suncano"),
    regija: Optional[str] = Query(None),
    limit: int = Query(10, le=50),
):
    # Ako je dob zadan, odredi dobnu skupinu automatski
    if dob and not dobna_skupina:
        if dob < 13:
            dobna_skupina = "djeca"
        elif dob < 18:
            dobna_skupina = "mladi"
        elif dob < 65:
            dobna_skupina = "odrasli"
        else:
            dobna_skupina = "starije osobe"

    params = {"limit": limit}
    where_clauses = []
    optional_matches = []
    with_clauses = ["r", "p"]

    # Baza MATCH
    base = """
    MATCH (r:Ruta)
    OPTIONAL MATCH (r)-[:PRIPADA_PODRUCJU]->(p:PodručjeHPO)
    """

    # Funkcionalnost 1 - dob/dobna skupina
    if dobna_skupina:
        optional_matches.append(
            "MATCH (r)-[:PRIKLADNA_ZA]->(d:DobnaSkupina {naziv: $dobna_skupina})"
        )
        params["dobna_skupina"] = dobna_skupina

    # Funkcionalnost 2 - vremenski uvjeti (isključi 'izbjegavati')
    if vremenski_uvjet:
        optional_matches.append(
            """
            WITH r, p
            WHERE NOT (r)-[:PREPORUCLJIVA_PO {preporuka: 'izbjegavati'}]->(:VremenskiUvjet {naziv: $vremenski_uvjet})
            """
        )
        params["vremenski_uvjet"] = vremenski_uvjet

    # Funkcionalnost 3 - težina
    if tezina:
        where_clauses.append("r.tezina = $tezina")
        params["tezina"] = tezina

    # Godišnje doba
    if godisnje_doba:
        optional_matches.append(
            "MATCH (r)-[:POGODNA_U]->(g:GodisnjeDoba {naziv: $godisnje_doba})"
        )
        params["godisnje_doba"] = godisnje_doba

    # Tip terena
    if tip_terena:
        optional_matches.append(
            "MATCH (r)-[:IMA_TIP_TERENA]->(tt:TipTerena {naziv: $tip_terena})"
        )
        params["tip_terena"] = tip_terena

    # Regija
    if regija:
        where_clauses.append("r.regija CONTAINS $regija")
        params["regija"] = regija

    where_str = "WHERE " + " AND ".join(where_clauses) if where_clauses else ""
    optional_str = "\n".join(optional_matches)

    query = f"""
    {base}
    {where_str}
    {optional_str}
    OPTIONAL MATCH (r)-[:POKRIVA]->(kt:KontrolnaTocka)
    OPTIONAL MATCH (r)-[:IMA_TIP_TERENA]->(tt2:TipTerena)
    OPTIONAL MATCH (r)-[:ZAHTIJEVA_OPREMU]->(o:Oprema)
    OPTIONAL MATCH (r)-[:POLAZI_IZ]->(l:Lokacija)
    RETURN
        r.id               AS id,
        r.naziv            AS naziv,
        r.tezina           AS tezina,
        r.regija           AS regija,
        r.duljinakm        AS duljina_km,
        r.trajanjeh        AS trajanje_h,
        r.visinskarazlikam AS visinska_razlika_m,
        r.trosak           AS trosak,
        p.naziv            AS podrucje,
        l.lat              AS polaziste_lat,
        l.lng              AS polaziste_lng,
        l.naziv            AS polaziste_naziv,
        COLLECT(DISTINCT kt.naziv)   AS kontrolne_tocke,
        COLLECT(DISTINCT tt2.naziv)  AS tip_terena,
        COLLECT(DISTINCT o.naziv)    AS oprema
    ORDER BY r.trajanjeh
    LIMIT $limit
    """
    return run_query(query, params)
