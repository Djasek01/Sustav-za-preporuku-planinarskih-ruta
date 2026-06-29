from neo4j import GraphDatabase
from app.config import NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD

driver = GraphDatabase.driver(
    NEO4J_URI,
    auth=(NEO4J_USER, NEO4J_PASSWORD),
    max_connection_pool_size=50
)

def run_query(query: str, parameters: dict | None = None):
    with driver.session() as session:
        result = session.run(query, parameters or {})
        return [record.data() for record in result]

def close_driver():
    driver.close()
