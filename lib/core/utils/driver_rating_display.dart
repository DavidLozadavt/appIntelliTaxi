import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Parsea calificación del conductor (API puede enviar 5, 5.0, "5.0000").
double parseDriverRating(dynamic value, {double fallback = 5.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble().clamp(0, 5);
  final parsed = double.tryParse(value.toString().trim());
  if (parsed == null) return fallback;
  return parsed.clamp(0, 5);
}

/// Etiqueta legible: una decimal, sin parecer precio ("5.0", no "5.0000").
String formatDriverRatingLabel(dynamic value, {double fallback = 5.0}) {
  return parseDriverRating(value, fallback: fallback).toStringAsFixed(1);
}

/// Chip compacto ★ 5.0 — claramente calificación, no precio.
class DriverRatingChip extends StatelessWidget {
  const DriverRatingChip({
    super.key,
    required this.rating,
    this.fallback = 5.0,
    this.compact = false,
  });

  final dynamic rating;
  final double fallback;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = formatDriverRatingLabel(rating, fallback: fallback);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const amber = Color(0xFFF59E0B);
    const amberDeep = Color(0xFF92400E);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? amber.withValues(alpha: 0.18)
            : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: amber.withValues(alpha: isDark ? 0.35 : 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Iconsax.star_1_copy,
            size: compact ? 12 : 13,
            color: amber,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFFCD34D) : amberDeep,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
