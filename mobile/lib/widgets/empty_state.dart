import 'package:flutter/material.dart';


class EmptyState extends StatelessWidget {
  final IconData ikona;
  final String naslov;
  final String? opis;

  const EmptyState({
    super.key,
    this.ikona = Icons.terrain,
    required this.naslov,
    this.opis,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                ikona,
                size: 64,
                color: Colors.green.shade300,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              naslov,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (opis != null) ...[
              const SizedBox(height: 8),
              Text(
                opis!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}