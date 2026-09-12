"""
export_baza.py — eksportira cijelu Neo4j bazu u Cypher skriptu
koju netko može pokrenuti za kreiranje identične baze.

Pokreni: python export_baza.py
Rezultat: baza_export.cypher
"""

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from app.database import run_query


def escape(val):
    """Escape apostrofa u stringovima za Cypher."""
    if val is None:
        return "null"
    if isinstance(val, str):
        return "'" + val.replace("\\", "\\\\").replace("'", "\\'") + "'"
    if isinstance(val, bool):
        return "true" if val else "false"
    return str(val)


def format_props(props):
    """Formatira rječnik kao Cypher properties string."""
    parts = []
    for k, v in props.items():
        if v is not None:
            parts.append(f"{k}: {escape(v)}")
    return "{" + ", ".join(parts) + "}"


def main():
    output = []
    output.append("// =============================================")
    output.append("// AUTOMATSKI EKSPORT NEO4J BAZE")
    output.append("// Sustav za preporuku planinarskih ruta")
    output.append("// =============================================")
    output.append("")
    output.append("// Obriši sve prije importa")
    output.append("MATCH (n) DETACH DELETE n;")
    output.append("")

    # 1. Eksport svih čvorova po labeli
    labele = run_query("CALL db.labels() YIELD label RETURN label ORDER BY label")

    for lab in labele:
        label = lab['label']
        output.append(f"// ---- {label} ----")
        cvorovi = run_query(f"MATCH (n:`{label}`) RETURN properties(n) AS props")
        for c in cvorovi:
            props = c['props']
            # Makni photo_ref i slika_url jer se regeneriraju
            props.pop('photo_ref', None)
            props.pop('slika_url', None)
            props_str = format_props(props)
            output.append(f"CREATE (:`{label}` {props_str});")
        output.append("")

    # 2. Eksport svih veza
    output.append("// =============================================")
    output.append("// VEZE")
    output.append("// =============================================")
    output.append("")

    tipovi_veza = run_query("CALL db.relationshipTypes() YIELD relationshipType RETURN relationshipType ORDER BY relationshipType")

    for tv in tipovi_veza:
        tip = tv['relationshipType']
        output.append(f"// ---- {tip} ----")

        veze = run_query(f"""
            MATCH (a)-[r:`{tip}`]->(b)
            RETURN labels(a)[0] AS labelA, properties(a) AS propsA,
                   type(r) AS tip, properties(r) AS propsR,
                   labels(b)[0] AS labelB, properties(b) AS propsB
        """)

        for v in veze:
            # Identificiraj čvorove po jedinstvenom atributu
            labelA = v['labelA']
            labelB = v['labelB']
            propsA = v['propsA']
            propsB = v['propsB']
            propsR = v['propsR'] or {}

            # Odaberi identifikacijski atribut
            idA = _id_attr(labelA, propsA)
            idB = _id_attr(labelB, propsB)

            if not idA or not idB:
                continue

            rel_props = ""
            if propsR:
                rel_props = " " + format_props(propsR)

            output.append(
                f"MATCH (a:`{labelA}` {{{idA}}}), (b:`{labelB}` {{{idB}}}) "
                f"CREATE (a)-[:`{tip}`{rel_props}]->(b);"
            )
        output.append("")

    # 3. Indeksi
    output.append("// =============================================")
    output.append("// INDEKSI")
    output.append("// =============================================")
    output.append("")
    output.append("CREATE INDEX ruta_id IF NOT EXISTS FOR (r:Ruta) ON (r.id);")
    output.append("CREATE INDEX ruta_naziv IF NOT EXISTS FOR (r:Ruta) ON (r.naziv);")
    output.append("CREATE INDEX ruta_tezina IF NOT EXISTS FOR (r:Ruta) ON (r.tezina);")
    output.append("CREATE INDEX kt_naziv IF NOT EXISTS FOR (kt:KontrolnaTocka) ON (kt.naziv);")
    output.append("CREATE INDEX lokacija_naziv IF NOT EXISTS FOR (l:Lokacija) ON (l.naziv);")
    output.append("CREATE INDEX podrucje_naziv IF NOT EXISTS FOR (p:PodručjeHPO) ON (p.naziv);")
    output.append("CREATE INDEX oprema_naziv IF NOT EXISTS FOR (o:Oprema) ON (o.naziv);")
    output.append("CREATE INDEX dobna_naziv IF NOT EXISTS FOR (d:DobnaSkupina) ON (d.naziv);")
    output.append("CREATE INDEX vremenski_naziv IF NOT EXISTS FOR (v:VremenskiUvjet) ON (v.naziv);")

    # Spremi
    filepath = os.path.join(os.path.dirname(os.path.abspath(__file__)), "baza_export.cypher")
    with open(filepath, "w", encoding="utf-8") as f:
        f.write("\n".join(output))

    print(f"Eksportirano {len(output)} linija u: {filepath}")
    print(f"Čvorovi: {sum(1 for l in output if l.startswith('CREATE (:'))}")
    print(f"Veze: {sum(1 for l in output if 'CREATE (a)-[' in l)}")


def _id_attr(label, props):
    """Vraća identifikacijski atribut za čvor."""
    if label == 'Ruta' and 'id' in props:
        return f"id: {props['id']}"
    if 'naziv' in props:
        return f"naziv: {escape(props['naziv'])}"
    if 'id' in props:
        return f"id: {props['id']}"
    if 'tip' in props:
        return f"tip: {escape(props['tip'])}"
    # Fallback — koristi prvi atribut
    for k, v in props.items():
        return f"{k}: {escape(v)}"
    return None


if __name__ == "__main__":
    main()