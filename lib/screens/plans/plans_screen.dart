// lib/screens/plans/plans_screen.dart
// Plans & Paiement — référence, upload preuve, état en_attente, WhatsApp, countdown
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/plan_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/payment_upload_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/loading_widget.dart' as lw;
import '../../widgets/statut_badge.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  bool _annuel = false;
  Timer? _countdownTimer;
  late PaymentUploadService _uploadService;

  @override
  void initState() {
    super.initState();
    _uploadService = PaymentUploadService(
      api: context.read<ApiService>(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dashboard = context.read<DashboardProvider>();
      dashboard.loadPlans();
      dashboard.loadProfil();
      dashboard.loadAbonnement();
      dashboard.loadReferencePaiement();
    });
    // Compte à rebours mis à jour chaque minute
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final auth = context.watch<AuthService>();
    final tenant = auth.tenant;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Plans & Paiement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Historique',
            onPressed: () => context.go('/dashboard/plans/historique'),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await dashboard.loadAbonnement();
          await dashboard.loadReferencePaiement();
          await dashboard.loadProfil();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Statut actuel ──────────────────────────────────────────
              if (tenant != null) ...[
                _CurrentSubscriptionCard(
                  tenant: tenant,
                  dashboard: dashboard,
                ),
                const SizedBox(height: 16),
              ],

              // ── Bandeau "en attente de confirmation" ───────────────────
              if (dashboard.hasAbonnementEnAttente) ...[
                _EnAttenteCard(
                  abonnement: dashboard.abonnementEnCours,
                  onUploadPreuve: () => _showUploadSheet(context, null, null),
                ),
                const SizedBox(height: 16),
              ],

              // ── Référence de paiement ──────────────────────────────────
              if (dashboard.referencePaiement != null) ...[
                _ReferenceCard(
                  reference: dashboard.referencePaiement!,
                  instructions: dashboard.referenceInstructions,
                ),
                const SizedBox(height: 16),
              ],

              // ── Toggle mensuel/annuel ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(child: _PeriodTab(
                      label: 'Mensuel',
                      isActive: !_annuel,
                      onTap: () => setState(() => _annuel = false),
                    )),
                    Expanded(child: _PeriodTab(
                      label: 'Annuel (-15%)',
                      isActive: _annuel,
                      onTap: () => setState(() => _annuel = true),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Plans ──────────────────────────────────────────────────
              if (dashboard.isLoadingPlans)
                const lw.ShimmerList(count: 4)
              else ...[
                ...dashboard.plans.map((plan) => _PlanCard(
                  plan: plan,
                  annuel: _annuel,
                  isCurrent: false, // plan.id non disponible dans ProfilModel plat (profil retourne plan_nom seulement)
                  onSelect: () => _showUploadSheet(
                    context,
                    plan,
                    _annuel ? 'annuel' : 'mensuel',
                  ),
                )),
              ],

              const SizedBox(height: 20),

              // ── Info paiement ──────────────────────────────────────────
              _PaymentInfoCard(
                whatsappNumber: tenant?.whatsappNumber,
                onWhatsApp: () => _openWhatsApp(
                  tenant?.whatsappNumber,
                  'Bonjour, je souhaite souscrire à un abonnement MonMenu. '
                  'Ma référence : ${dashboard.referencePaiement ?? "N/A"}',
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Afficher sheet upload ──────────────────────────────────────────────────
  void _showUploadSheet(
    BuildContext context,
    PlanModel? plan,
    String? periodicite,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _UploadProofSheet(
        plan: plan,
        periodicite: periodicite,
        uploadService: _uploadService,
        reference: context.read<DashboardProvider>().referencePaiement,
        whatsappNumber: context.read<AuthService>().tenant?.whatsappNumber,
      ),
    );
  }

  // ── Ouvrir WhatsApp ────────────────────────────────────────────────────────
  Future<void> _openWhatsApp(String? number, String message) async {
    final phoneNumber = (number ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Numéro WhatsApp non configuré.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final encoded = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$phoneNumber?text=$encoded');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final urlWeb = Uri.parse(
            'https://web.whatsapp.com/send?phone=$phoneNumber&text=$encoded');
        await launchUrl(urlWeb, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir WhatsApp.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ── Carte abonnement actuel ───────────────────────────────────────────────────
class _CurrentSubscriptionCard extends StatelessWidget {
  final dynamic tenant;
  final DashboardProvider dashboard;

  const _CurrentSubscriptionCard({required this.tenant, required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Votre abonnement',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              TenantStatutBadge(statut: tenant.statut),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dashboard.profil?.planNom ?? 'Plan Gratuit',
            style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _getStatutDescription(tenant, dashboard),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getStatutDescription(dynamic tenant, DashboardProvider dashboard) {
    switch (tenant.statut as String) {
      case 'essai':
        final jours = dashboard.joursEssaiRestants ?? tenant.joursEssaiRestants;
        return jours != null
            ? '$jours jour${jours > 1 ? 's' : ''} restant${jours > 1 ? 's' : ''} d\'essai'
            : 'Période d\'essai gratuite';
      case 'actif':
        return 'Abonnement actif ✓';
      case 'en_attente_confirmation':
        return '⏳ Paiement soumis — confirmation sous 48h';
      case 'inactif':
        return 'Abonnement expiré — Renouvelez pour accéder';
      case 'suspendu':
        return 'Compte suspendu — Contactez le support';
      default:
        return '';
    }
  }
}

// ── Bandeau en attente de confirmation ───────────────────────────────────────
class _EnAttenteCard extends StatelessWidget {
  final Map<String, dynamic>? abonnement;
  final VoidCallback onUploadPreuve;

  const _EnAttenteCard({this.abonnement, required this.onUploadPreuve});

  @override
  Widget build(BuildContext context) {
    final heures = (abonnement?['heures_restantes_confirmation'] as num?)?.toInt()
        ?? _calcHeuresRestantes(abonnement?['delai_confirmation_expire_le']);
    final message = abonnement?['message_confirmation'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hourglass_top_rounded,
                  color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Preuve soumise — en attente de confirmation',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (heures > 0)
            Text(
              '⏰ $heures heure${heures > 1 ? 's' : ''} restante${heures > 1 ? 's' : ''} '
              'pour la confirmation admin',
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w500),
            ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Vous avez 72h pour effectuer le paiement après réception de la référence. '
            'L\'équipe admin a 48h pour confirmer après soumission de votre preuve.',
            style: TextStyle(fontSize: 11, color: Colors.orange, height: 1.4),
          ),
        ],
      ),
    );
  }

  int _calcHeuresRestantes(dynamic expireAt) {
    if (expireAt == null) return 0;
    final dt = DateTime.tryParse(expireAt as String);
    if (dt == null) return 0;
    final diff = dt.difference(DateTime.now()).inHours;
    return diff < 0 ? 0 : diff;
  }
}

// ── Carte référence de paiement ───────────────────────────────────────────────
class _ReferenceCard extends StatelessWidget {
  final String reference;
  final List<String> instructions;

  const _ReferenceCard({required this.reference, this.instructions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tag_rounded, color: AppColors.secondary, size: 18),
              SizedBox(width: 8),
              Text(
                'Votre référence de paiement',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Référence copiable
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: reference));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Référence copiée !'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      reference,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const Icon(Icons.copy_rounded,
                      color: AppColors.secondary, size: 18),
                ],
              ),
            ),
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...instructions.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${e.key + 1}. ${e.value}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.gray600, height: 1.5),
              ),
            )),
          ],
        ],
      ),
    );
  }
}

// ── Carte info paiement + WhatsApp ────────────────────────────────────────────
class _PaymentInfoCard extends StatelessWidget {
  final String? whatsappNumber;
  final VoidCallback onWhatsApp;

  const _PaymentInfoCard({this.whatsappNumber, required this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.secondary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Comment payer ?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                '1. Notez votre référence de paiement ci-dessus\n'
                '2. Effectuez le paiement via :\n'
                '   • Mobile Money (Orange Money, Wave, MTN)\n'
                '   • Virement bancaire\n'
                '   • Carte bancaire Visa/Mastercard\n'
                '3. Prenez une photo de votre reçu\n'
                '4. Cliquez sur "J\'ai effectué le paiement" et uploadez la preuve\n'
                '5. L\'équipe confirme sous 48h',
                style: TextStyle(
                    fontSize: 12, color: AppColors.gray600, height: 1.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            onPressed: onWhatsApp,
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('Contacter le support'),
          ),
        ),
      ],
    );
  }
}

// ── Plan Card ─────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final PlanModel plan;
  final bool annuel;
  final bool isCurrent;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.annuel,
    required this.isCurrent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isPro = plan.nom == 'Pro';
    final prix = annuel ? plan.prixAnnuel : plan.prixMensuel;
    final isGratuit = plan.isGratuit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? AppColors.success
              : isPro ? AppColors.primary : AppColors.gray100,
          width: isCurrent || isPro ? 2 : 1,
        ),
        boxShadow: isPro
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.nom,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gray900,
                            ),
                          ),
                          if (isPro) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Populaire',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.success
                                        .withValues(alpha: 0.3)),
                              ),
                              child: const Text(
                                'Actuel',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (plan.description != null)
                        Text(
                          plan.description!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.gray400),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isGratuit
                          ? 'Gratuit'
                          : '${prix.toStringAsFixed(0)} ${plan.devise}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gray900,
                      ),
                    ),
                    if (!isGratuit)
                      Text(
                        annuel ? '/an' : '/mois',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.gray400),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Feature(
                    label: '${plan.commandesIncluses} commandes/mois',
                    active: true),
                _Feature(label: '${plan.limitePdv} PDV', active: true),
                ...plan.fonctionnalites.entries
                    .where((e) => e.value == true)
                    .take(4)
                    .map((e) =>
                        _Feature(label: _featureLabel(e.key), active: true)),
              ],
            ),
            if (!isCurrent && !isGratuit) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed: onSelect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isPro ? AppColors.primary : AppColors.gray900,
                  ),
                  child: Text('Choisir ${plan.nom}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _featureLabel(String key) {
    const labels = {
      'boutique_en_ligne': 'Boutique en ligne',
      'whatsapp_notifications': 'Notif. WhatsApp',
      'qrcode': 'QR Code',
      'qrcode_custom': 'QR personnalisé',
      'stats_basiques': 'Stats de base',
      'stats_avancees': 'Stats avancées',
      'support_email': 'Support email',
      'livreurs': 'Gestion livreurs',
      'codes_promo': 'Codes promo',
      'export_csv': 'Export CSV',
      'domaine_perso': 'Domaine perso',
      'api_access': 'Accès API',
      'webhooks': 'Webhooks',
    };
    return labels[key] ?? key;
  }
}

class _Feature extends StatelessWidget {
  final String label;
  final bool active;
  const _Feature({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.gray100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_rounded : Icons.close_rounded,
            size: 12,
            color: active ? AppColors.success : AppColors.gray400,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: active ? AppColors.gray700 : AppColors.gray400,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _PeriodTab(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.gray900 : AppColors.gray500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sheet upload preuve ───────────────────────────────────────────────────────
class _UploadProofSheet extends StatefulWidget {
  final PlanModel? plan;
  final String? periodicite;
  final PaymentUploadService uploadService;
  final String? reference;
  final String? whatsappNumber;

  const _UploadProofSheet({
    this.plan,
    this.periodicite,
    required this.uploadService,
    this.reference,
    this.whatsappNumber,
  });

  @override
  State<_UploadProofSheet> createState() => _UploadProofSheetState();
}

class _UploadProofSheetState extends State<_UploadProofSheet> {
  String _selectedMethod = 'mobile_money';
  bool _isUploading = false;
  String? _error;
  String? _selectedImagePath;
  int? _imageSizeBytes;
  final TextEditingController _numeroExpediteurCtrl = TextEditingController();

  static const _methods = [
    ('mobile_money', 'Mobile Money (Orange Money, Wave, MTN)'),
    ('virement', 'Virement bancaire'),
    ('carte', 'Carte bancaire Visa/Mastercard'),
  ];

  @override
  void dispose() {
    _numeroExpediteurCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prix = widget.plan != null
        ? (widget.periodicite == 'annuel'
            ? widget.plan!.prixAnnuel
            : widget.plan!.prixMensuel)
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            if (widget.plan != null) ...[
              Text(
                'Souscrire au plan ${widget.plan!.nom}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gray900,
                ),
              ),
              if (prix != null)
                Text(
                  '${prix.toStringAsFixed(0)} ${widget.plan!.devise} '
                  '/ ${widget.periodicite == 'annuel' ? 'an' : 'mois'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
            ] else ...[
              const Text(
                'Soumettre une preuve de paiement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gray900,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Référence
            if (widget.reference != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tag_rounded,
                        color: AppColors.secondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Référence : ${widget.reference}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded,
                          size: 16, color: AppColors.secondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.reference!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Référence copiée !'),
                              duration: Duration(seconds: 2)),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Méthode de paiement
            const Text(
              'Méthode de paiement',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.gray700),
            ),
            const SizedBox(height: 8),
            ...(_methods.map((m) => RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: m.$1,
              // ignore: deprecated_member_use
              groupValue: _selectedMethod,
              title: Text(m.$2,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.gray700)),
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _selectedMethod = v!),
              activeColor: AppColors.primary,
            ))),

            const SizedBox(height: 12),

            // Numéro utilisé pour le paiement
            const Text(
              'Numéro utilisé pour le paiement *',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.gray700),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _numeroExpediteurCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Ex : +22612345678',
                prefixIcon: const Icon(Icons.phone_rounded,
                    size: 18, color: AppColors.gray400),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                helperText:
                    'Numéro Mobile Money / compte utilisé pour ce paiement (min 8 chiffres)',
                helperMaxLines: 2,
              ),
            ),

            const SizedBox(height: 12),

            // Sélection image
            const Text(
              'Preuve de paiement (photo du reçu)',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.gray700),
            ),
            const SizedBox(height: 8),
            if (_selectedImagePath != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedImagePath!.split('/').last,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.gray700),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_imageSizeBytes != null)
                            Text(
                              '${(_imageSizeBytes! / 1024).toStringAsFixed(0)} Ko',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.gray400),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedImagePath = null;
                        _imageSizeBytes = null;
                      }),
                      child: const Text('Changer'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Caméra'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Galerie'),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Bouton "J'ai effectué le paiement"
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.upload_rounded, size: 18),
                label: Text(_isUploading
                    ? 'Envoi en cours…'
                    : 'J\'ai effectué le paiement'),
                onPressed: _isUploading || _selectedImagePath == null
                    ? null
                    : _submitProof,
              ),
            ),

            const SizedBox(height: 10),

            // WhatsApp support
            OutlinedButton.icon(
              onPressed: () => _openWhatsApp(context),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('Contacter le support WhatsApp'),
            ),

            const SizedBox(height: 10),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Plus tard'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final result = await widget.uploadService.pickAndCompressImage(
        source: source);
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _selectedImagePath = result.filePath;
        _imageSizeBytes = result.fileSizeBytes;
        _error = null;
      });
    } else {
      setState(() {
        _error = result.error;
      });
    }
  }

  Future<void> _submitProof() async {
    if (_selectedImagePath == null) return;

    // Validation client du numéro expéditeur (cohérente avec backend : min 8 chiffres)
    final numeroRaw = _numeroExpediteurCtrl.text.trim();
    final numeroPropre = numeroRaw.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeroPropre.length < 8) {
      setState(() {
        _error =
            'Le numéro utilisé pour le paiement est requis (8 chiffres minimum).';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final dashboard = context.read<DashboardProvider>();
      dashboard.setUploadLoading();

      final result = await widget.uploadService.uploadPreuve(
        filePath: _selectedImagePath!,
        planId: widget.plan?.id ?? '',
        methodePaiement: _selectedMethod,
        periodicite: widget.periodicite ?? 'mensuel',
        numeroExpediteur: numeroRaw,
      );

      if (!mounted) return;

      if (result.success) {
        dashboard.setUploadSuccess(result.rawResponse ?? {});
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ Preuve envoyée ! Confirmation sous 48h.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        dashboard.setUploadError(result.error ?? 'Erreur upload');
        setState(() {
          _error = result.error;
          _isUploading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur inattendue. Réessayez.';
        _isUploading = false;
      });
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final number =
        (widget.whatsappNumber ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) return;

    final message = 'Bonjour, je souhaite souscrire à un abonnement MonMenu. '
        'Ma référence : ${widget.reference ?? "N/A"}. '
        'Plan : ${widget.plan?.nom ?? "N/A"}.';
    final encoded = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$number?text=$encoded');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
