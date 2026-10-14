import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('O aplikaciji')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.terrain,
                size: 64,
                color: Color(0xFF2E7D32),
              )
            ),

            const SizedBox(height: 20),

            const Text(
              'Plan&GO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Sustav za preporuku planinarskih ruta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),

            const SizedBox(height: 4),

            Text(
              'Verzija 1.0.0',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),

            const SizedBox(height: 32),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: Color(0xFF2E7D32)),
                        SizedBox(width: 8),
                        Text('O sustavu',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Plan&GO predlaže optimalne planinarske rute na temelju '
                      'kriterija kao što su dob sudionika, vremenska prognoza i '
                      'težina staze, uz prikaz staza na karti, preporuku '
                      'opreme i procjenu troška izleta. Temelji se na Neo4j '
                      'grafovskoj bazi podataka s 65 detaljno opisanih ruta i '
                      '142 kontrolne točke Hrvatske planinarske obilaznice '
                      'diljem Hrvatske.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Što aplikacija nudi',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            _infoKartica(
              Icons.recommend,
              'Preporuka ruta',
              'Pronađi idealnu rutu po dobi, težini, vremenu i godišnjem dobu.',
              isDark,
            ),

            const SizedBox(height: 12),

            _infoKartica(
              Icons.hiking,
              'Sve rute',
              'Pregledaj sve planinarske rute u bazi s mogućnošću pretrage i filtriranja.',
              isDark,
            ),

            const SizedBox(height: 12),

            _infoKartica(
              Icons.map,
              'Karta ruta',
              'Prikaz svih ruta na interaktivnoj karti s markerima po težini.',
              isDark,
            ),

            const SizedBox(height: 12),

            _infoKartica(
              Icons.backpack,
              'Preporuka opreme',
              'Predložena oprema ovisno o težini i tipu terena odabrane rute.',
              isDark,
            ),

            const SizedBox(height: 12),

            _infoKartica(
              Icons.wb_sunny,
              'Vremenska prognoza',
              'Prikazuje idealno vrijeme za određene rute.',
              isDark,
            ),

            const SizedBox(height: 24),

            
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Korištene tehnologije',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _TechChip(label: 'Flutter', ikona: Icons.phone_android),
                _TechChip(label: 'FastAPI', ikona: Icons.api),
                _TechChip(label: 'Neo4j', ikona: Icons.hub),
                _TechChip(label: 'Google Maps', ikona: Icons.map),
                _TechChip(label: 'Python', ikona: Icons.code),
                _TechChip(label: 'Dart', ikona: Icons.code),
                _TechChip(label: 'Cypher', ikona: Icons.storage),
              ],
            ),

            const SizedBox(height: 24),

            _infoKartica(
              Icons.person,
              'Autor',
              'David Jasek',
              isDark,
            ),

            const SizedBox(height: 24),

            Text(
              '© 2026 David Jasek',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoKartica(
      IconData ikona, String naslov, String tekst, bool isDark) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(ikona, color: const Color(0xFF2E7D32), size: 24),
        ),
        title: Text(naslov,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(tekst, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _TechChip extends StatelessWidget {
  final String label;
  final IconData ikona;

  const _TechChip({required this.label, required this.ikona});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(ikona, size: 16, color: const Color(0xFF2E7D32)),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.08),
      side: BorderSide.none,
    );
  }
}