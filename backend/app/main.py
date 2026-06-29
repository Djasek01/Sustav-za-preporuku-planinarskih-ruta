from fastapi import FastAPI
from app.database import run_query

app = FastAPI(
    title="Hiking Routes Recommendation API",
    version="1.0.0"
)

@app.get("/")
def root():
    return {"message": "Backend radi i spojen je na FastAPI"}

@app.get("/routes")
def get_routes():
    query = """
    MATCH (r:Ruta)
    RETURN 
        r.id AS id,
        r.naziv AS naziv,
        r.tezina AS tezina,
        r.duljinaKm AS duljinaKm,
        r.trajanjeH AS trajanjeH,
        r.trosak AS trosak
    ORDER BY r.id
    LIMIT 20
    """
    return run_query(query)