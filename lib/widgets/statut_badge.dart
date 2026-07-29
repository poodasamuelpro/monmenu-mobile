// lib/widgets/statut_badge.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatutBadge extends StatelessWidget {
  final String statut;
  final bool small;

  const StatutBadge({super.key, required this.statut, this.small = false});

  @override
  Widget build(BuildContext context) {
    final bg = CommandeStatut.background(statut);
    final fg = CommandeStatut.foreground(statut);
    final label = CommandeStatut.label(statut);
    final icon = CommandeStatut.icon(statut);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: small ? 10 : 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: small ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class TenantStatutBadge extends StatelessWidget {
  final String statut;
  const TenantStatutBadge({super.key, required this.statut});

  @override
  Widget build(BuildContext context) {
    final color = TenantStatut.color(statut);
    final label = TenantStatut.label(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color,
            ),
          ),
        ],
      ),
    );
  }
}
