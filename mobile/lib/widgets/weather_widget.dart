import 'package:flutter/material.dart';
import '../models/weather.dart';

class WeatherKartica extends StatelessWidget {
  final WeatherRuta weather;

  const WeatherKartica({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final trenutno = weather.trenutno;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: weather.sigurno
          ? (isDark ? const Color(0xFF1B3A2D) : Colors.blue.shade50)
          : (isDark ? const Color(0xFF3A1B1B) : Colors.red.shade50),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Naslov + sigurnost
            Row(
              children: [
                const Icon(Icons.cloud, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Trenutno vrijeme',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: weather.sigurno ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    weather.sigurno ? 'Sigurno' : 'Oprez',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Temperatura i opis
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trenutno.ikona,
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trenutno.temperatura?.toStringAsFixed(1) ?? '?'}°C',
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        trenutno.opis,
                        style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700),
                      ),
                      if (trenutno.osjetTemperature != null)
                        Text(
                          'Osjet: ${trenutno.osjetTemperature!.toStringAsFixed(1)}°C',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Detalji
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _detalj(
                    '💧', '${trenutno.vlaznost ?? '?'}%', 'Vlažnost'),
                _detalj(
                    '💨',
                    '${trenutno.vjetarKmh?.toStringAsFixed(0) ?? '?'} km/h',
                    'Vjetar'),
                _detalj(
                    '🌧️',
                    '${trenutno.oborineMm?.toStringAsFixed(1) ?? '0'} mm',
                    'Oborine'),
              ],
            ),

            // Sigurnosna poruka
            if (!weather.sigurno) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        weather.sigurnostPoruka,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 7-dnevna prognoza
            if (weather.prognoza.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Prognoza (7 dana)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: weather.prognoza.length,
                  itemBuilder: (context, index) {
                    final dan = weather.prognoza[index];
                    return Container(
                      width: 70,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            isDark ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dan.danSkraceni,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(dan.ikona,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(height: 2),
                            Text(
                              '${dan.tempMax?.toStringAsFixed(0) ?? '?'}°',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${dan.tempMin?.toStringAsFixed(0) ?? '?'}°',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Lokacija info
            if (weather.lokacija != null) ...[
              const SizedBox(height: 8),
              Text(
                '📍 ${weather.lokacija}',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detalj(String ikona, String vrijednost, String label) {
    return Column(
      children: [
        Text(ikona, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(vrijednost,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }
}