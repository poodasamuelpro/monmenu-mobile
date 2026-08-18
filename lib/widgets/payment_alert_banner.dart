// lib/widgets/payment_alert_banner.dart
// Bandeau d'alerte paiement selon statut tenant — aligné sur logique web
//
// Référence web : monmenu/src/routes/api-paiement.ts lignes 646-688
//
// États couverts :
// - essai <= 2j restants → error rouge   (aligne sur web : joursRestants <= 2 → 'error')
// - essai 3-5j restants  → warning orange (aligne sur web : joursRestants <= 5 → 'warning')
// - en_attente_confirmation, heures < 10  → warning orange
// - en_attente_confirmation, heures >= 10 → info bleue
// - inactif / suspendu → error rouge
//
// SLA annoncé à l'utilisateur : 48h (délai admin affiché)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Bandeau contextuel affiché selon le statut de paiement du tenant.
/// Aligné sur la logique du backend web (api-paiement.ts /notifications).
class PaymentAlertBanner extends StatelessWidget {
  const PaymentAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final dashboard = context.watch<DashboardProvider>();
    final tenant = auth.tenant;

    if (tenant == null) return const SizedBox.shrink();

    final statut = tenant.statut;

    // ── Essai qui expire bientôt (seuil 5j aligné sur web) ─────────────────
    if (statut == 'essai' && tenant.essaiExpireBientot) {
      final jours = tenant.joursEssaiRestants ?? 0;

      // Web : joursRestants <= 2 → type 'error', sinon 'warning'
      final estCritique = jours <= 2;

      String message;
      if (jours <= 0) {
        // Web exact : 'Votre période d'essai est terminée. Activez votre abonnement pour continuer.'
        message = 'Votre période d\'essai est terminée. Activez votre abonnement pour continuer.';
      } else {
        // Web exact : `Il vous reste ${joursRestants} jour(s) d'essai gratuit.`
        message = 'Il vous reste $jours jour${jours > 1 ? 's' : ''} d\'essai gratuit.';
      }

      return _Banner(
        color: estCritique ? AppColors.error : AppColors.warning,
        icon: estCritique
            ? Icons.error_outline_rounded
            : Icons.access_time_rounded,
        message: message,
        actionLabel: 'Activer',
        onTap: () => context.go('/dashboard/plans'),
      );
    }

    // ── En attente de confirmation ────────────────────────────────────────
    // Web : heures < 10 → type 'warning', sinon 'info'
    // SLA annoncé : 48h max
    if (statut == 'en_attente_confirmation') {
      final paiement = tenant.paiementEnAttente;
      final heures = paiement?.heuresRestantesCalculees ??
          _calcHeures(
            (dashboard.abonnementEnCours?['delai_confirmation_expire_le']) as String?,
          );

      // Web exact : heuresRestantes < 10 → 'warning'
      final isUrgent = heures > 0 && heures < 10;

      final message = isUrgent
          ? 'Confirmation sous 48h max ($heures h restantes avant coupure)'
          : 'Confirmation sous 48h max — paiement en cours de vérification';

      return _Banner(
        color: isUrgent ? AppColors.warning : AppColors.secondary,
        icon: isUrgent
            ? Icons.warning_amber_rounded
            : Icons.hourglass_top_rounded,
        message: message,
        actionLabel: 'Détails',
        onTap: () => context.go('/dashboard/plans'),
      );
    }

    // ── Inactif / Suspendu / tout mode bloqué (parité acces-tenant.ts) ──────
    // tenant.modeAcces == 'bloque' couvre inactif, essai expiré et tout statut
    // legacy inconnu → accès abonnement seul, bandeau de régularisation.
    if (statut == 'suspendu' || tenant.modeAcces == 'bloque') {
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

  int _calcHeures(String? expireAt) {
    if (expireAt == null) return 0;
    final dt = DateTime.tryParse(expireAt);
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
