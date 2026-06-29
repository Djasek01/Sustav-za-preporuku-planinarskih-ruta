from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import run_query, close_driver
from app.routers import rute, oprema, karta, vrijeme

app = FastAPI(
    title="Sustav za preporuku planinarskih ruta",
    description="""
    API za preporuku planinarskih ruta temeljen na Neo4j grafovskoj bazi podataka.
    
    ## Funkcionalnosti
    1. **Preporuka ruta po dobi** — `/rute/preporuka/rute?dob=35`
    2. **Preporuka po vremenskim uvjetima** — `/vrijeme/preporuka?uvjet=vjetar`
    3. **Preporuka po težini** — `/rute/preporuka/rute?tezina=lagana`
    4. **Prikaz rute na karti** — `/karta/ruta/{id}`
    5. **Preporuka opreme** — `/oprema/za-rutu/{id}`
    6. **Procjena troška** — `/oprema/procjena-troska/{id}`
    """,
    version="1.0.0"
)

# CORS za Flutter (Android emulator koristi 10.0.2.2, iOS simulator localhost)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Registracija routera
app.include_router(rute.router)
app.include_router(oprema.router)
app.include_router(karta.router)
app.include_router(vrijeme.router)


@app.on_event("shutdown")
def shutdown():
    close_driver()


@app.get("/", tags=["Status"])
def root():
    return {
        "status": "online",
        "poruka": "Sustav za preporuku planinarskih ruta",
        "verzija": "1.0.0",
        "dokumentacija": "/docs"
    }


@app.get("/zdravlje", tags=["Status"])
def zdravlje():
    """Provjera konekcije na Neo4j bazu."""
    try:
        result = run_query("MATCH (r:Ruta) RETURN COUNT(r) AS ukupno_ruta")
        kt_result = run_query("MATCH (kt:KontrolnaTocka) RETURN COUNT(kt) AS ukupno_kt")
        return {
            "status": "ok",
            "neo4j": "spojen",
            "ukupno_ruta": result[0]["ukupno_ruta"] if result else 0,
            "ukupno_kt": kt_result[0]["ukupno_kt"] if kt_result else 0,
        }
    except Exception as e:
        return {"status": "greška", "detalji": str(e)}
