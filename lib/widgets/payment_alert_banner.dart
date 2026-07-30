// lib/widgets/payment_alert_banner.dart
// Bandeau d'alerte paiement selon statut tenant
// Affiché en haut du dashboard pour : essai < 3j, en_attente_confirmation, inactif
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Bandeau contextuel affiché en haut du dashboard selon le statut de paiement.
///
/// États couverts :
/// - essai avec < 3 jours restants → warning orange
/// - en_attente_confirmation → info bleue avec compte à rebours
/// - inactif / suspendu → erreur rouge (accès bloqué)
///
/// Tap sur le bandeau → navigation vers /dashboard/plans
class PaymentAlertBanner extends StatelessWidget {
  const PaymentAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final dashboard = context.watch<DashboardProvider>();
    final tenant = auth.tenant;

    if (tenant == null) return const SizedBox.shrink();

    final statut = tenant.statut;

    // ── Essai qui expire bientôt ──────────────────────────────────────────
    if (statut == 'essai' && tenant.essaiExpireBientot) {
      final jours = tenant.joursEssaiRestants ?? 0;
      return _Banner(
        color: AppColors.warning,
        icon: Icons.access_time_rounded,
        message: jours == 0
            ? 'Votre essai expire aujourd\'hui ! Activez votre abonnement.'
            : 'Plus que $jours jour${jours > 1 ? 's' : ''} d\'essai gratuit.',
        actionLabel: 'Activer',
        onTap: () => context.go('/dashboard/plans'),
      );
    }

    // ── En attente de confirmation ────────────────────────────────────────
    if (statut == 'en_attente_confirmation') {
      final abonnement = dashboard.abonnementEnCours;
      final heures = (abonnement?['heures_restantes_confirmation'] as num?)
              ?.toInt() ??
          _calcHeures(abonnement?['delai_confirmation_expire_le']);
      return _Banner(
        color: AppColors.secondary,
        icon: Icons.hourglass_top_rounded,
        message: heures > 0
            ? '⏳ Preuve soumise — confirmation admin sous $heures h'
            : '⏳ Preuve soumise — en attente de confirmation',
        actionLabel: 'Détails',
        onTap: () => context.go('/dashboard/plans'),
      );
    }

    // ── Inactif / Suspendu ────────────────────────────────────────────────
    if (statut == 'inactif' || statut == 'suspendu') {
      return _Banner(
        color: AppColors.error,
        icon: Icons.block_rounded,
        message: statut == 'suspendu'
            ? 'Compte suspendu. Contactez le support.'
            : 'Abonnement expiré. Renouvelez pour continuer.',
        actionLabel: 'Renouveler',
        onTap: () => context.go('/dashboard/plans'),
      );
    }

    return const SizedBox.shrink();
  }

  int _calcHeures(dynamic expireAt) {
    if (expireAt == null) return 0;
    final dt = DateTime.tryParse(expireAt as String);
    if (dt == null) return 0;
    final diff = dt.difference(DateTime.now()).inHours;
    return diff < 0 ? 0 : diff;
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  const _Banner({
    required this.color,
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
