from fastapi import APIRouter, Query
from app.database import run_query

router = APIRouter(prefix="/vrijeme", tags=["Vremenski uvjeti"])


@router.get("/uvjeti")
def get_uvjeti():
    query = """
    MATCH (v:VremenskiUvjet)
    RETURN v.naziv AS naziv
    ORDER BY v.naziv
    """
    return run_query(query)


@router.get("/preporuka")
def rute_po_uvjetu(
    uvjet: str = Query(..., description="vjetar | magla | kisovito | suncano"),
    tezina: str = Query(None, description="lagana | srednja | teska"),
):
    params = {"uvjet": uvjet}
    tezina_filter = "AND r.tezina = $tezina" if tezina else ""
    if tezina:
        params["tezina"] = tezina

    query = f"""
    MATCH (v:VremenskiUvjet {{naziv: $uvjet}})
    MATCH (r:Ruta)
    WHERE NOT (r)-[:PREPORUCLJIVA_PO {{preporuka: 'izbjegavati'}}]->(v)
    {tezina_filter}
    OPTIONAL MATCH (r)-[:PRIPADA_PODRUCJU]->(p:PodručjeHPO)
    OPTIONAL MATCH (r)-[:IMA_TIP_TERENA]->(tt:TipTerena)
    RETURN
        r.id        AS id,
        r.naziv     AS naziv,
        r.tezina    AS tezina,
        r.regija    AS regija,
        r.trajanjeh AS trajanje_h,
        p.naziv     AS podrucje,
        COLLECT(DISTINCT tt.naziv) AS tip_terena
    ORDER BY r.trajanjeh
    LIMIT 20
    """
    return run_query(query, params)


@router.get("/rute-izbjegavati")
def rute_izbjegavati(
    uvjet: str = Query(..., description="vjetar | magla | kisovito"),
):
    query = """
    MATCH (r:Ruta)-[rel:PREPORUCLJIVA_PO]->(v:VremenskiUvjet {naziv: $uvjet})
    WHERE rel.preporuka = 'izbjegavati'
    RETURN
        r.naziv     AS naziv,
        r.tezina    AS tezina,
        r.regija    AS regija,
        rel.preporuka AS preporuka
    ORDER BY r.tezina
    """
    return run_query(query, {"uvjet": uvjet})
