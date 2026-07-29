// lib/screens/plans/plans_screen.dart
// Plans & Paiement — écran exclusif mobile (sera ajouté plus tard au web)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/plan_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadPlans();
      context.read<DashboardProvider>().loadProfil();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final auth = context.watch<AuthService>();
    final tenant = auth.tenant;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Plans & Paiement')),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Statut actuel ────────────────────────────────────────────
            if (tenant != null) ...[
              Container(
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
                          style: TextStyle(
                            color: Colors.white70, fontSize: 13,
                          ),
                        ),
                        TenantStatutBadge(statut: tenant.statut),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dashboard.profil?.plan?.nom ?? 'Plan Gratuit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22, fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getStatutDescription(tenant),
                      style: const TextStyle(
                        color: Colors.white70, fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Toggle mensuel/annuel ─────────────────────────────────────
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

            // ── Plans ─────────────────────────────────────────────────────
            if (dashboard.isLoadingPlans)
              const lw.ShimmerList(count: 4)
            else ...[
              ...dashboard.plans.map((plan) => _PlanCard(
                plan: plan,
                annuel: _annuel,
                isCurrent: dashboard.profil?.plan?.id == plan.id,
                onSelect: () => _selectPlan(plan),
              )),
            ],

            const SizedBox(height: 20),

            // ── Info paiement ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                ),
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
                          color: AppColors.secondary, fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    '• Mobile Money (Orange Money, Wave, MTN)\n'
                    '• Virement bancaire\n'
                    '• Carte bancaire Visa/Mastercard\n\n'
                    'Contactez le support via WhatsApp pour activer votre abonnement.',
                    style: TextStyle(
                      fontSize: 12, color: AppColors.gray600,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Contact support
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Ouvrir WhatsApp support
                },
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: const Text('Contacter le support'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _getStatutDescription(dynamic tenant) {
    switch (tenant.statut) {
      case 'essai':
        final jours = tenant.joursEssaiRestants;
        return jours != null
            ? '$jours jours restants dans votre période d\'essai'
            : 'Période d\'essai gratuite de 14 jours';
      case 'actif': return 'Abonnement actif';
      case 'inactif': return 'Abonnement expiré — Renouvelez pour accéder';
      case 'suspendu': return 'Compte suspendu — Contactez le support';
      default: return '';
    }
  }

  void _selectPlan(PlanModel plan) {
    if (plan.isGratuit) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PlanSubscribeSheet(plan: plan, annuel: _annuel),
    );
  }
}

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
              : isPro
                  ? AppColors.primary
                  : AppColors.gray100,
          width: isCurrent || isPro ? 2 : 1,
        ),
        boxShadow: isPro ? [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                              fontSize: 17, fontWeight: FontWeight.w800,
                              color: AppColors.gray900,
                            ),
                          ),
                          if (isPro) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Populaire',
                                style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.success.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Text(
                                'Actuel',
                                style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (plan.description != null)
                        Text(
                          plan.description!,
                          style: const TextStyle(
                            fontSize: 12, color: AppColors.gray400,
                          ),
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
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: AppColors.gray900,
                      ),
                    ),
                    if (!isGratuit)
                      Text(
                        annuel ? '/an' : '/mois',
                        style: const TextStyle(
                          fontSize: 12, color: AppColors.gray400,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const Divider(height: 20),

            // Fonctionnalités
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Feature(
                  label: '${plan.commandesIncluses} commandes/mois',
                  active: true,
                ),
                _Feature(label: '${plan.limitePdv} PDV', active: true),
                ...plan.fonctionnalites.entries
                    .where((e) => e.value == true)
                    .take(4)
                    .map((e) => _Feature(
                          label: _featureLabel(e.key),
                          active: true,
                        )),
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
                    backgroundColor: isPro ? AppColors.primary : AppColors.gray900,
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
              fontSize: 11, fontWeight: FontWeight.w500,
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
  const _PeriodTab({required this.label, required this.isActive, required this.onTap});

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
          boxShadow: isActive ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4, offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: isActive ? AppColors.gray900 : AppColors.gray500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanSubscribeSheet extends StatelessWidget {
  final PlanModel plan;
  final bool annuel;
  const _PlanSubscribeSheet({required this.plan, required this.annuel});

  @override
  Widget build(BuildContext context) {
    final prix = annuel ? plan.prixAnnuel : plan.prixMensuel;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Souscrire au plan ${plan.nom}',
            style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800,
              color: AppColors.gray900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${prix.toStringAsFixed(0)} ${plan.devise} / ${annuel ? 'an' : 'mois'}',
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pour activer votre abonnement, contactez notre équipe support via WhatsApp. Nous acceptons Mobile Money, virement et carte bancaire.',
            style: TextStyle(fontSize: 13, color: AppColors.gray500, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('Contacter via WhatsApp'),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
        ],
      ),
    );
  }
}
