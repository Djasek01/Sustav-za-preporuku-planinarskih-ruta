from fastapi import APIRouter, Query, HTTPException
from typing import Optional
from app.database import run_query
import httpx

router = APIRouter(prefix="/weather", tags=["Vrijeme – Real-time"])

# WMO Weather Codes → vremenski uvjeti

WMO_MAP = {
    0: {"opis": "Vedro", "uvjet": "suncano", "ikona": "☀️"},
    1: {"opis": "Pretežno vedro", "uvjet": "suncano", "ikona": "🌤️"},
    2: {"opis": "Djelomično oblačno", "uvjet": "suncano", "ikona": "⛅"},
    3: {"opis": "Oblačno", "uvjet": "suncano", "ikona": "☁️"},
    45: {"opis": "Magla", "uvjet": "magla", "ikona": "🌫️"},
    48: {"opis": "Magla s injem", "uvjet": "magla", "ikona": "🌫️"},
    51: {"opis": "Slaba rosulja", "uvjet": "kisovito", "ikona": "🌦️"},
    53: {"opis": "Umjerena rosulja", "uvjet": "kisovito", "ikona": "🌦️"},
    55: {"opis": "Jaka rosulja", "uvjet": "kisovito", "ikona": "🌧️"},
    56: {"opis": "Ledena rosulja", "uvjet": "kisovito", "ikona": "🌧️"},
    57: {"opis": "Jaka ledena rosulja", "uvjet": "kisovito", "ikona": "🌧️"},
    61: {"opis": "Slaba kiša", "uvjet": "kisovito", "ikona": "🌦️"},
    63: {"opis": "Umjerena kiša", "uvjet": "kisovito", "ikona": "🌧️"},
    65: {"opis": "Jaka kiša", "uvjet": "kisovito", "ikona": "🌧️"},
    66: {"opis": "Ledena kiša", "uvjet": "kisovito", "ikona": "🧊"},
    67: {"opis": "Jaka ledena kiša", "uvjet": "kisovito", "ikona": "🧊"},
    71: {"opis": "Slab snijeg", "uvjet": "kisovito", "ikona": "🌨️"},
    73: {"opis": "Umjeren snijeg", "uvjet": "kisovito", "ikona": "🌨️"},
    75: {"opis": "Jak snijeg", "uvjet": "kisovito", "ikona": "❄️"},
    77: {"opis": "Snježna zrna", "uvjet": "kisovito", "ikona": "❄️"},
    80: {"opis": "Slabi pljuskovi", "uvjet": "kisovito", "ikona": "🌦️"},
    81: {"opis": "Umjereni pljuskovi", "uvjet": "kisovito", "ikona": "🌧️"},
    82: {"opis": "Jaki pljuskovi", "uvjet": "kisovito", "ikona": "⛈️"},
    85: {"opis": "Snježni pljuskovi", "uvjet": "kisovito", "ikona": "🌨️"},
    86: {"opis": "Jaki snježni pljuskovi", "uvjet": "kisovito", "ikona": "❄️"},
    95: {"opis": "Grmljavina", "uvjet": "kisovito", "ikona": "⛈️"},
    96: {"opis": "Grmljavina s tučom", "uvjet": "kisovito", "ikona": "⛈️"},
    99: {"opis": "Grmljavina s jakom tučom", "uvjet": "kisovito", "ikona": "⛈️"},
}

# Prag za vjetar (km/h) — ako je iznad ovog, "vjetar" postaje uvjet

VJETAR_PRAG_KMH = 30.0


def _wmo_to_uvjet(code: int, wind_speed: float = 0) -> dict:
    """Pretvori WMO kod + brzinu vjetra u naš format."""
    info = WMO_MAP.get(code, {"opis": "Nepoznato", "uvjet": "suncano", "ikona": "❓"})
    # Ako je vjetar jak, pregazimo uvjet
    if wind_speed >= VJETAR_PRAG_KMH:
        return {**info, "uvjet": "vjetar", "ikona": "💨",
                "opis": f"{info['opis']}, jak vjetar ({wind_speed:.0f} km/h)"}
    return info


async def _fetch_weather(lat: float, lng: float) -> dict:
    """Dohvati vrijeme s Open-Meteo API."""
    url = "https://api.open-meteo.com/v1/forecast"
    params = {
        "latitude": lat,
        "longitude": lng,
        "current": "temperature_2m,relative_humidity_2m,wind_speed_10m,"
                   "wind_gusts_10m,weather_code,precipitation,apparent_temperature",
        "daily": "weather_code,temperature_2m_max,temperature_2m_min,"
                 "precipitation_sum,wind_speed_10m_max,sunrise,sunset",
        "timezone": "Europe/Zagreb",
        "forecast_days": 7,
    }
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, params=params, timeout=10.0)
        if resp.status_code != 200:
            raise HTTPException(status_code=502, detail="Open-Meteo API nedostupan")
        return resp.json()


# ─────────────────────────────────────────
# GET /weather/lokacija
# Trenutno vrijeme + 7-dnevna prognoza za koordinate
# ─────────────────────────────────────────
@router.get("/lokacija")
async def weather_lokacija(
    lat: float = Query(..., description="Latitude"),
    lng: float = Query(..., description="Longitude"),
):
    data = await _fetch_weather(lat, lng)
    current = data.get("current", {})
    daily = data.get("daily", {})

    wmo_code = current.get("weather_code", 0)
    wind_speed = current.get("wind_speed_10m", 0)
    info = _wmo_to_uvjet(wmo_code, wind_speed)

    # Trenutno stanje
    trenutno = {
        "temperatura": current.get("temperature_2m"),
        "osjet_temperature": current.get("apparent_temperature"),
        "vlaznost": current.get("relative_humidity_2m"),
        "vjetar_kmh": wind_speed,
        "udari_vjetra_kmh": current.get("wind_gusts_10m"),
        "oborine_mm": current.get("precipitation"),
        "wmo_kod": wmo_code,
        "opis": info["opis"],
        "ikona": info["ikona"],
        "uvjet": info["uvjet"],
    }

    # 7-dnevna prognoza
    prognoza = []
    dates = daily.get("time", [])
    for i, datum in enumerate(dates):
        daily_wmo = daily.get("weather_code", [])[i] if i < len(daily.get("weather_code", [])) else 0
        daily_wind = daily.get("wind_speed_10m_max", [])[i] if i < len(daily.get("wind_speed_10m_max", [])) else 0
        d_info = _wmo_to_uvjet(daily_wmo, daily_wind)
        prognoza.append({
            "datum": datum,
            "temp_min": daily.get("temperature_2m_min", [])[i] if i < len(daily.get("temperature_2m_min", [])) else None,
            "temp_max": daily.get("temperature_2m_max", [])[i] if i < len(daily.get("temperature_2m_max", [])) else None,
            "oborine_mm": daily.get("precipitation_sum", [])[i] if i < len(daily.get("precipitation_sum", [])) else None,
            "vjetar_max_kmh": daily_wind,
            "wmo_kod": daily_wmo,
            "opis": d_info["opis"],
            "ikona": d_info["ikona"],
            "uvjet": d_info["uvjet"],
            "izlazak_sunca": daily.get("sunrise", [])[i] if i < len(daily.get("sunrise", [])) else None,
            "zalazak_sunca": daily.get("sunset", [])[i] if i < len(daily.get("sunset", [])) else None,
        })

    return {"trenutno": trenutno, "prognoza": prognoza}


# ─────────────────────────────────────────
# GET /weather/ruta/{ruta_id}
# Vrijeme za polazište konkretne rute
# ─────────────────────────────────────────
@router.get("/ruta/{ruta_id}")
async def weather_rute(ruta_id: int):
    query = """
    MATCH (r:Ruta {id: $id})
    OPTIONAL MATCH (r)-[:POLAZI_IZ]->(l:Lokacija)
    OPTIONAL MATCH (r)-[:POKRIVA]->(kt:KontrolnaTocka)
    WHERE kt.lat IS NOT NULL
    RETURN
        r.naziv AS naziv,
        l.lat   AS polaziste_lat,
        l.lng   AS polaziste_lng,
        l.naziv AS polaziste_naziv,
        COLLECT(DISTINCT {naziv: kt.naziv, lat: kt.lat, lng: kt.lng})[0] AS prva_kt
    """
    result = run_query(query, {"id": ruta_id})
    if not result:
        raise HTTPException(status_code=404, detail="Ruta nije pronađena")

    r = result[0]
    lat = r.get("polaziste_lat")
    lng = r.get("polaziste_lng")

    # Ako nema polazišta, koristi prvu kontrolnu točku
    if not lat or not lng:
        kt = r.get("prva_kt")
        if kt:
            lat = kt.get("lat")
            lng = kt.get("lng")

    if not lat or not lng:
        raise HTTPException(status_code=404, detail="Ruta nema koordinate za praćenje vremena")

    weather = await _fetch_weather(lat, lng)
    current = weather.get("current", {})
    daily = weather.get("daily", {})

    wmo_code = current.get("weather_code", 0)
    wind_speed = current.get("wind_speed_10m", 0)
    info = _wmo_to_uvjet(wmo_code, wind_speed)

    # Provjera je li ruta sigurna za trenutni uvjet
    safety_query = """
    MATCH (r:Ruta {id: $id})
    OPTIONAL MATCH (r)-[rel:PREPORUCLJIVA_PO]->(v:VremenskiUvjet {naziv: $uvjet})
    RETURN rel.preporuka AS preporuka
    """
    safety = run_query(safety_query, {"id": ruta_id, "uvjet": info["uvjet"]})
    izbjegavati = False
    if safety and safety[0].get("preporuka") == "izbjegavati":
        izbjegavati = True

    trenutno = {
        "temperatura": current.get("temperature_2m"),
        "osjet_temperature": current.get("apparent_temperature"),
        "vlaznost": current.get("relative_humidity_2m"),
        "vjetar_kmh": wind_speed,
        "udari_vjetra_kmh": current.get("wind_gusts_10m"),
        "oborine_mm": current.get("precipitation"),
        "wmo_kod": wmo_code,
        "opis": info["opis"],
        "ikona": info["ikona"],
        "uvjet": info["uvjet"],
    }

    # 7-dnevna prognoza
    prognoza = []
    dates = daily.get("time", [])
    for i, datum in enumerate(dates):
        daily_wmo = daily.get("weather_code", [])[i] if i < len(daily.get("weather_code", [])) else 0
        daily_wind = daily.get("wind_speed_10m_max", [])[i] if i < len(daily.get("wind_speed_10m_max", [])) else 0
        d_info = _wmo_to_uvjet(daily_wmo, daily_wind)
        prognoza.append({
            "datum": datum,
            "temp_min": daily.get("temperature_2m_min", [])[i] if i < len(daily.get("temperature_2m_min", [])) else None,
            "temp_max": daily.get("temperature_2m_max", [])[i] if i < len(daily.get("temperature_2m_max", [])) else None,
            "oborine_mm": daily.get("precipitation_sum", [])[i] if i < len(daily.get("precipitation_sum", [])) else None,
            "vjetar_max_kmh": daily_wind,
            "wmo_kod": daily_wmo,
            "opis": d_info["opis"],
            "ikona": d_info["ikona"],
            "uvjet": d_info["uvjet"],
        })

    return {
        "ruta": r["naziv"],
        "lokacija": r.get("polaziste_naziv"),
        "lat": lat,
        "lng": lng,
        "trenutno": trenutno,
        "prognoza": prognoza,
        "sigurnost": {
            "sigurno": not izbjegavati,
            "poruka": f"⚠️ Ova ruta se preporučuje izbjegavati pri uvjetima: {info['opis']}"
                      if izbjegavati else f"✅ Ruta je prikladna za trenutne uvjete ({info['opis']})",
        },
    }


# ─────────────────────────────────────────
# GET /weather/pametna-preporuka
# Pametna preporuka: kombinira real-time vrijeme
# s lokacijom ruta i vraća samo sigurne rute
# ─────────────────────────────────────────
@router.get("/pametna-preporuka")
async def pametna_preporuka(
    lat: float = Query(45.815, description="Lat korisnika (default Zagreb)"),
    lng: float = Query(15.982, description="Lng korisnika (default Zagreb)"),
    dob: Optional[int] = Query(None),
    tezina: Optional[str] = Query(None),
    limit: int = Query(10, le=50),
):
    # 1. Dohvati trenutno vrijeme za lokaciju korisnika
    weather = await _fetch_weather(lat, lng)
    current = weather.get("current", {})
    wmo_code = current.get("weather_code", 0)
    wind_speed = current.get("wind_speed_10m", 0)
    info = _wmo_to_uvjet(wmo_code, wind_speed)
    uvjet = info["uvjet"]

    # 2. Odredi godišnje doba automatski
    from datetime import date
    today = date.today()
    month = today.month
    if month in (3, 4, 5):
        godisnje_doba = "proljece"
    elif month in (6, 7, 8):
        godisnje_doba = "ljeto"
    elif month in (9, 10, 11):
        godisnje_doba = "jesen"
    else:
        godisnje_doba = "zima"

    # 3. Dobna ograničenja
    dobna_filter = ""
    params = {"uvjet": uvjet, "godisnje_doba": godisnje_doba, "limit": limit}

    if dob:
        if dob < 13:
            dobna_skupina = "djeca"
        elif dob < 18:
            dobna_skupina = "mladi"
        elif dob < 65:
            dobna_skupina = "odrasli"
        else:
            dobna_skupina = "starije osobe"
        dobna_filter = "MATCH (r)-[:PRIKLADNA_ZA]->(d:DobnaSkupina {naziv: $dobna_skupina})"
        params["dobna_skupina"] = dobna_skupina

    tezina_filter = ""
    if tezina:
        tezina_filter = "AND r.tezina = $tezina"
        params["tezina"] = tezina

    # 4. Nađi rute sigurne za trenutno vrijeme + godišnje doba
    query = f"""
    MATCH (r:Ruta)
    {dobna_filter}
    MATCH (r)-[:POGODNA_U]->(g:GodisnjeDoba {{naziv: $godisnje_doba}})
    WHERE NOT (r)-[:PREPORUCLJIVA_PO {{preporuka: 'izbjegavati'}}]->(:VremenskiUvjet {{naziv: $uvjet}})
    {tezina_filter}
    OPTIONAL MATCH (r)-[:PRIPADA_PODRUCJU]->(p:PodručjeHPO)
    OPTIONAL MATCH (r)-[:POLAZI_IZ]->(l:Lokacija)
    OPTIONAL MATCH (r)-[:POKRIVA]->(kt:KontrolnaTocka)
    OPTIONAL MATCH (r)-[:IMA_TIP_TERENA]->(tt:TipTerena)
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
        COLLECT(DISTINCT kt.naziv) AS kontrolne_tocke,
        COLLECT(DISTINCT tt.naziv) AS tip_terena
    ORDER BY r.trajanjeh
    LIMIT $limit
    """
    rute = run_query(query, params)

    return {
        "vrijeme": {
            "temperatura": current.get("temperature_2m"),
            "opis": info["opis"],
            "ikona": info["ikona"],
            "uvjet": uvjet,
            "vjetar_kmh": wind_speed,
        },
        "godisnje_doba": godisnje_doba,
        "filtri": {
            "dob": dob,
            "tezina": tezina,
        },
        "ukupno_ruta": len(rute),
        "rute": rute,
    }


# ─────────────────────────────────────────
# GET /weather/karta-overlay
# Vrijeme za sve rute (polazišta) — za kartu
# ─────────────────────────────────────────
@router.get("/karta-overlay")
async def weather_karta_overlay():
    """Dohvati vrijeme za sve regije ruta (grupirano po regijama da se smanji broj API poziva)."""
    # Dohvati jedinstvene lokacije (po regiji)
    query = """
    MATCH (r:Ruta)-[:POLAZI_IZ]->(l:Lokacija)
    WHERE l.lat IS NOT NULL
    WITH r.regija AS regija, COLLECT(DISTINCT {lat: l.lat, lng: l.lng})[0] AS loc
    RETURN regija, loc.lat AS lat, loc.lng AS lng
    """
    regije = run_query(query)
    if not regije:
        return []

    results = []
    async with httpx.AsyncClient() as client:
        for reg in regije:
            lat = reg.get("lat")
            lng = reg.get("lng")
            if not lat or not lng:
                continue
            try:
                url = "https://api.open-meteo.com/v1/forecast"
                params = {
                    "latitude": lat,
                    "longitude": lng,
                    "current": "temperature_2m,weather_code,wind_speed_10m",
                    "timezone": "Europe/Zagreb",
                }
                resp = await client.get(url, params=params, timeout=10.0)
                if resp.status_code == 200:
                    data = resp.json()
                    curr = data.get("current", {})
                    wmo = curr.get("weather_code", 0)
                    wind = curr.get("wind_speed_10m", 0)
                    info = _wmo_to_uvjet(wmo, wind)
                    results.append({
                        "regija": reg["regija"],
                        "lat": lat,
                        "lng": lng,
                        "temperatura": curr.get("temperature_2m"),
                        "opis": info["opis"],
                        "ikona": info["ikona"],
                        "uvjet": info["uvjet"],
                    })
            except Exception:
                continue

            # ─────────────────────────────────────────
# GET /weather/prognoza
# Za Flutter WeatherKartica widget (camelCase format)
# ─────────────────────────────────────────
DANI_HR = ["Pon", "Uto", "Sri", "Čet", "Pet", "Sub", "Ned"]

@router.get("/prognoza")
async def weather_prognoza(
    lat: float = Query(...),
    lon: float = Query(...),
):
    data = await _fetch_weather(lat, lon)
    current = data.get("current", {})
    daily = data.get("daily", {})

    wmo_code = current.get("weather_code", 0)
    wind_speed = current.get("wind_speed_10m", 0)
    oborine = current.get("precipitation", 0)
    info = _wmo_to_uvjet(wmo_code, wind_speed)

    sigurno = True
    poruka = ""
    if wind_speed and wind_speed > 50:
        sigurno = False
        poruka = f"Jak vjetar ({wind_speed} km/h). Nije preporučljivo planinariti."
    elif oborine and oborine > 5:
        sigurno = False
        poruka = f"Obilne oborine ({oborine} mm). Staze mogu biti skliske."
    elif wmo_code >= 95:
        sigurno = False
        poruka = "Grmljavinsko nevrijeme. Odgodite planinarenje."

    prognoza = []
    dates = daily.get("time", [])
    codes = daily.get("weather_code", [])
    maxs = daily.get("temperature_2m_max", [])
    mins = daily.get("temperature_2m_min", [])
    for i, datum in enumerate(dates):
        from datetime import date as dt_date
        d = dt_date.fromisoformat(datum)
        daily_wmo = codes[i] if i < len(codes) else 0
        d_info = _wmo_to_uvjet(daily_wmo)
        prognoza.append({
            "danSkraceni": DANI_HR[d.weekday()],
            "datum": datum,
            "ikona": d_info["ikona"],
            "tempMax": maxs[i] if i < len(maxs) else None,
            "tempMin": mins[i] if i < len(mins) else None,
            "opis": d_info["opis"],
        })

    return {
        "sigurno": sigurno,
        "sigurnostPoruka": poruka,
        "lokacija": None,
        "trenutno": {
            "temperatura": current.get("temperature_2m"),
            "osjetTemperature": current.get("apparent_temperature"),
            "opis": info["opis"],
            "ikona": info["ikona"],
            "vlaznost": current.get("relative_humidity_2m"),
            "vjetarKmh": wind_speed,
            "oborineMm": oborine,
        },
        "prognoza": prognoza,
    }

    return results