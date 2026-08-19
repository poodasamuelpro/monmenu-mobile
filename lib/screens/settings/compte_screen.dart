// lib/screens/settings/compte_screen.dart
// Gestion du compte — suppression de compte (parité web api-dashboard.ts l.2547-2790)
//
// FLUX WEB RÉPLIQUÉ :
//   1. POST /dashboard/compte/demander-suppression
//      → { success, message, suppression_prevue_le } (429 si >3 demandes/24h)
//      → Un email de confirmation est envoyé ; la suppression n'est effective
//        qu'après clic sur le lien email (GET /compte/confirmer-suppression?token=)
//   2. POST /dashboard/compte/annuler-suppression
//      → { success, message } (422 si aucune demande en cours)
//
// Le mobile ne gère PAS la confirmation finale (lien email uniquement) :
// il informe l'utilisateur qu'un email a été envoyé.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/nav_buttons.dart';
import '../../theme/app_theme.dart';

class CompteScreen extends StatefulWidget {
  const CompteScreen({super.key});

  @override
  State<CompteScreen> createState() => _CompteScreenState();
}

class _CompteScreenState extends State<CompteScreen> {
  bool _isSubmitting = false;

  /// Date de suppression prévue renvoyée par la demande (état local de session).
  DateTime? _suppressionPrevueLe;

  /// Vrai après une demande réussie dans cette session.
  bool _demandeEnCours = false;

  Future<void> _demanderSuppression() async {
    // Double confirmation avant l'appel API (action grave)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon compte'),
        content: const Text(
          'Cette action déclenchera la suppression définitive de votre '
          'restaurant, de votre menu, de vos commandes et de toutes vos '
          'données.\n\n'
          'Un email de confirmation vous sera envoyé : la suppression ne '
          'sera effective qu\'après avoir cliqué sur le lien de confirmation.\n\n'
          'Voulez-vous continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Demander la suppression'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isSubmitting = true);
    final api = context.read<ApiService>();
    final resp = await api.demanderSuppressionCompte();
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (resp.success) {
      final prevueLe = resp.data?['suppression_prevue_le'] as String?;
      setState(() {
        _demandeEnCours = true;
        _suppressionPrevueLe =
            prevueLe != null ? DateTime.tryParse(prevueLe) : null;
      });
      _showSnack(
        resp.data?['message'] as String? ??
            'Demande enregistrée. Vérifiez votre email pour confirmer.',
      );
    } else if (resp.isRateLimited) {
      _showSnack(
        'Trop de demandes. Réessayez dans 24 heures.',
        isError: true,
      );
    } else {
      _showSnack(resp.error ?? 'Erreur lors de la demande.', isError: true);
    }
  }

  Future<void> _annulerSuppression() async {
    setState(() => _isSubmitting = true);
    final api = context.read<ApiService>();
    final resp = await api.annulerSuppressionCompte();
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (resp.success) {
      setState(() {
        _demandeEnCours = false;
        _suppressionPrevueLe = null;
      });
      _showSnack(
        resp.data?['message'] as String? ?? 'Demande de suppression annulée.',
      );
    } else {
      // 422 = aucune demande en cours (message backend exact affiché)
      _showSnack(resp.error ?? 'Erreur lors de l\'annulation.', isError: true);
      if (resp.statusCode == 422) {
        setState(() {
          _demandeEnCours = false;
          _suppressionPrevueLe = null;
        });
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon compte'),
        leadingWidth: 104,
        leading: const NavButtons(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Zone danger : suppression de compte ──────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 20, color: AppColors.error),
                      SizedBox(width: 8),
                      Text(
                        'Zone dangereuse',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'La suppression de votre compte est définitive : votre '
                    'restaurant, votre menu, vos commandes et toutes vos '
                    'données seront supprimés.\n\n'
                    'Après votre demande, un email de confirmation vous sera '
                    'envoyé. La suppression ne devient effective qu\'après '
                    'confirmation par le lien reçu.',
                    style: TextStyle(
                      fontSize: 13, color: AppColors.gray600, height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_demandeEnCours) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_read_outlined,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _suppressionPrevueLe != null
                                  ? 'Demande enregistrée. Suppression prévue le '
                                    '${DateFormat('dd/MM/yyyy', 'fr_FR').format(_suppressionPrevueLe!)} '
                                    'après confirmation par email.'
                                  : 'Demande enregistrée. Vérifiez votre email '
                                    'pour confirmer la suppression.',
                              style: const TextStyle(
                                fontSize: 12, color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _annulerSuppression,
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text('Annuler la demande de suppression'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gray700,
                          side: const BorderSide(color: AppColors.gray300),
                        ),
                      ),
                    ),
                  ] else
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _demanderSuppression,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_forever_rounded, size: 18),
                        label: const Text('Supprimer mon compte'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
