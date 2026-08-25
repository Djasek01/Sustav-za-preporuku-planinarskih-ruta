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
    udaljenost_km: Optional[float] = Query(
        None,
        description="Udaljenost do polazišta u km (jednosmjerno). Ako nije zadano, procjenjuje se prema regiji."
    ),
):
    query = """
    MATCH (r:Ruta {id: $id})
    OPTIONAL MATCH (r)-[:ZAHTIJEVA_OPREMU]->(o:Oprema)
    OPTIONAL MATCH (r)-[:POLAZI_IZ]->(l:Lokacija)
    RETURN
        r.naziv        AS naziv,
        r.tezina       AS tezina,
        r.regija       AS regija,
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

    # ── ULAZNICA ──
    # trosak_rute = ulaznica NP/PP, 0 za sve ostale
    ulaznica = r.get("trosak_rute") or 0
    ulaznica_ukupno = ulaznica * broj_sudionika

    # ── OPREMA ──
    oprema_stavke = [o for o in r.get("oprema_lista", []) if o.get("naziv")]
    trosak_opreme = 0.0
    if not vlastita_oprema:
        trosak_opreme = sum((o.get("trosak") or 0) for o in oprema_stavke)

    # ── PRIJEVOZ ──
    # Realna procjena za HR:
    # - Gorivo: prosječna cijena 1.45 EUR/L (eurosuper 95, HR srpanj 2025)
    # - Potrošnja: 7 L/100 km (prosječan auto)
    # - Cestarina: procjena prema regiji
    #
    # Ako korisnik nije zadao udaljenost, procjenjujemo prema regiji
    # (prosječna udaljenost od Zagreba kao referentne točke)
    regija = r.get("regija") or ""
    if udaljenost_km is None:
        udaljenost_km = _procijeni_udaljenost(regija)

    cijena_goriva_po_litri = 1.45  # EUR/L
    potrosnja_l_na_100km = 7.0
    cijena_po_km = (potrosnja_l_na_100km / 100) * cijena_goriva_po_litri  # ~0.1015 EUR/km

    gorivo_tamo_natrag = round(udaljenost_km * 2 * cijena_po_km, 2)

    # Cestarina (procjena prema regiji)
    cestarina = _procijeni_cestarinu(regija)
    cestarina_tamo_natrag = cestarina * 2

    trosak_prijevoza = round(gorivo_tamo_natrag + cestarina_tamo_natrag, 2)

    # Dijeljenje prijevoza (max 4 osobe u autu)
    osoba_u_autu = min(broj_sudionika, 4)
    trosak_prijevoza_po_osobi = round(trosak_prijevoza / osoba_u_autu, 2)

    # ── UKUPNO ──
    ukupno_po_osobi = round(ulaznica + trosak_opreme + trosak_prijevoza_po_osobi, 2)

    # Grupa: svak plati ulaznicu + opremu, prijevoz se dijeli
    broj_auta = max(1, -(-broj_sudionika // 4))  # zaokruži na gore
    ukupno_prijevoz_grupa = round(trosak_prijevoza * broj_auta, 2)
    ukupno_grupa = round(
        ulaznica_ukupno
        + (trosak_opreme * broj_sudionika)
        + ukupno_prijevoz_grupa,
        2,
    )

    return {
        "ruta": r["naziv"],
        "tezina": r["tezina"],
        "regija": regija,
        "trajanje_h": r["trajanje_h"],
        "duljina_km": r["duljina_km"],
        "polaziste": r["polaziste"],
        "broj_sudionika": broj_sudionika,
        "vlastita_oprema": vlastita_oprema,
        "udaljenost_km": udaljenost_km,
        "troskovi": {
            "ulaznica_eur": ulaznica,
            "ulaznica_ukupno_eur": ulaznica_ukupno,
            "trosak_opreme_eur": round(trosak_opreme, 2),
            "gorivo_eur": gorivo_tamo_natrag,
            "cestarina_eur": cestarina_tamo_natrag,
            "trosak_prijevoza_eur": trosak_prijevoza,
            "trosak_prijevoza_po_osobi_eur": trosak_prijevoza_po_osobi,
            "ukupno_po_osobi_eur": ukupno_po_osobi,
            "ukupno_grupa_eur": ukupno_grupa,
        },
        "oprema": [
            {"naziv": o.get("naziv"), "trosak": o.get("trosak"), "opis": o.get("opis")}
            for o in oprema_stavke
        ],
        "napomena": _napomena_ulaznica(ulaznica, regija),
    }


def _procijeni_udaljenost(regija: str) -> float:
    """Prosječna udaljenost od Zagreba do regije (jednosmjerno, km)."""
    regija_upper = regija.upper()
    udaljenosti = {
        "MEDVEDNICA": 15,
        "HRVATSKO ZAGORJE": 50,
        "SAMOBORSKO GORJE": 30,
        "ŽUMBERAČKA GORA": 45,
        "GORSKI KOTAR": 140,
        "ISTRA": 200,
        "SJEVERNI VELEBIT": 220,
        "SREDNJI VELEBIT": 250,
        "JUŽNI VELEBIT": 280,
        "LIKA": 180,
        "SLAVONIJA": 250,
        "MOSLAVAČKA": 80,
        "KARLOVAČKO": 60,
        "DALMACIJA": 380,
        "DALMATINSKA ZAGORA": 350,
        "BIOKOVO": 420,
        "DUBROVAČKO": 600,
        "JADRANSKI OTOCI": 300,
    }
    for kljuc, km in udaljenosti.items():
        if kljuc in regija_upper:
            return float(km)
    return 100.0  # default


def _procijeni_cestarinu(regija: str) -> float:
    """Procjena cestarine od Zagreba do regije (jednosmjerno, EUR)."""
    regija_upper = regija.upper()
    cestarine = {
        "MEDVEDNICA": 0,
        "HRVATSKO ZAGORJE": 3,
        "SAMOBORSKO GORJE": 0,
        "ŽUMBERAČKA GORA": 0,
        "GORSKI KOTAR": 12,
        "ISTRA": 18,
        "SJEVERNI VELEBIT": 15,
        "SREDNJI VELEBIT": 18,
        "JUŽNI VELEBIT": 20,
        "LIKA": 12,
        "SLAVONIJA": 15,
        "MOSLAVAČKA": 5,
        "KARLOVAČKO": 4,
        "DALMACIJA": 25,
        "DALMATINSKA ZAGORA": 22,
        "BIOKOVO": 28,
        "DUBROVAČKO": 35,
        "JADRANSKI OTOCI": 20,
    }
    for kljuc, eur in cestarine.items():
        if kljuc in regija_upper:
            return float(eur)
    return 5.0  # default


def _napomena_ulaznica(ulaznica: float, regija: str) -> str:
    """Objašnjenje troška ulaznice."""
    if ulaznica > 0:
        if "PAKLENICA" in regija.upper() or "JUŽNI VELEBIT" in regija.upper():
            return "Ulaznica za NP Paklenica (obvezna za sve posjetitelje)"
        elif "RISNJAK" in regija.upper() or "GORSKI KOTAR sjeverni" in regija.upper():
            return "Ulaznica za NP Risnjak (obvezna za sve posjetitelje)"
        elif "BIOKOVO" in regija.upper():
            return "Ulaznica za PP Biokovo (obvezna za sve posjetitelje)"
        return "Ulaznica za zaštićeno područje"
    return "Besplatan pristup — ruta ne prolazi kroz nacionalni park ili park prirode"