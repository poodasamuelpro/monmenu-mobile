// lib/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/payment_alert_banner.dart';
import '../../widgets/statut_badge.dart';
import '../../widgets/nav_buttons.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // M1 — charger le profil pour disposer de l'email du restaurant
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dashboard = context.read<DashboardProvider>();
      if (dashboard.profil == null) dashboard.loadProfil();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final tenant = auth.tenant;
    final dashboard = context.watch<DashboardProvider>();
    final profil = dashboard.profil;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paramètres'),
        leadingWidth: 104,

        leading: const NavButtons(),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Bandeau alerte paiement ────────────────────────────────────
            const PaymentAlertBanner(),

            // ── Profil ──────────────────────────────────────────────────
            if (tenant != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gray100),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: AppColors.primary, size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenant.nom,
                            style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: AppColors.gray900,
                            ),
                          ),
                          Text(
                            'monmenu.app/${tenant.slug}',
                            style: const TextStyle(
                              fontSize: 12, color: AppColors.gray400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TenantStatutBadge(statut: tenant.statut),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ── Section Compte ─────────────────────────────────────────────
            _SectionTitle(title: 'Compte'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              label: 'Changer le mot de passe',
              onTap: () => context.go('/dashboard/change-password'),
            ),
            // M1 — e-mail du restaurant (parité web dashboard/parametres)
            _SettingsTile(
              icon: Icons.alternate_email_rounded,
              label: 'E-mail',
              subtitle: (profil?.email?.isNotEmpty ?? false)
                  ? profil!.email!
                  : 'Non défini',
              onTap: () => _editEmail(context, dashboard),
            ),
            _SettingsTile(
              icon: Icons.workspace_premium_rounded,
              label: 'Plans & Paiement',
              onTap: () => context.go('/dashboard/plans'),
            ),
            // P3 — suppression de compte (parité web dashboard/parametres)
            _SettingsTile(
              icon: Icons.person_remove_rounded,
              label: 'Mon compte (suppression)',
              onTap: () => context.go('/dashboard/settings/compte'),
            ),

            const SizedBox(height: 16),

            // ── Section Restaurant ─────────────────────────────────────────
            _SectionTitle(title: 'Restaurant'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.store_rounded,
              label: 'Mon restaurant',
              onTap: () => context.go('/dashboard/restaurant'),
            ),
            _SettingsTile(
              icon: Icons.palette_rounded,
              label: 'Apparence',
              onTap: () => context.go('/dashboard/apparence'),
            ),
            _SettingsTile(
              icon: Icons.qr_code_rounded,
              label: 'QR Code',
              onTap: () => context.go('/dashboard/qrcode'),
            ),

            const SizedBox(height: 16),

            // ── Section Aide ───────────────────────────────────────────────
            _SectionTitle(title: 'Aide'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.chat_rounded,
              label: 'Support WhatsApp',
              onTap: () async {
                const numero = '22677980264'; // Numéro WhatsApp support MonMenu
                final uri = Uri.parse('https://wa.me/$numero?text=Bonjour%2C%20j%27ai%20besoin%20d%27aide%20avec%20MonMenu.');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            _SettingsTile(
              icon: Icons.email_outlined,
              label: 'contact.monmenu@gmail.com',
              onTap: () async {
                final uri = Uri.parse('mailto:contact.monmenu@gmail.com?subject=Support%20MonMenu');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),

            const SizedBox(height: 24),

            // ── Déconnexion ────────────────────────────────────────────────
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, auth),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Se déconnecter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),

            const SizedBox(height: 12),

            const Center(
              child: Text(
                'MonMenu v1.0.0',
                style: TextStyle(fontSize: 12, color: AppColors.gray400),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // M1 — édition de l'e-mail du restaurant via PATCH /dashboard/parametres
  // Contrainte web : `nom` est REQUIS (≥ 2 caractères) même pour ne changer
  // que l'email → on renvoie le nom actuel du profil. Email vide → null côté web.
  Future<void> _editEmail(
      BuildContext context, DashboardProvider dashboard) async {
    var profil = dashboard.profil;
    if (profil == null) {
      await dashboard.loadProfil();
      profil = dashboard.profil;
    }
    if (profil == null || profil.nom.trim().length < 2) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profil indisponible, réessayez plus tard.'),
        ));
      }
      return;
    }
    if (!context.mounted) return;

    final api = context.read<ApiService>();
    final controller = TextEditingController(text: profil.email ?? '');
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    final formKey = GlobalKey<FormState>();

    final nouveau = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('E-mail du restaurant'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'contact@restaurant.com',
              helperText: 'Laisser vide pour supprimer l\'e-mail',
            ),
            validator: (v) {
              final val = (v ?? '').trim();
              if (val.isEmpty) return null; // vide autorisé → null côté web
              if (!emailRegex.hasMatch(val)) return 'Adresse e-mail invalide';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (nouveau == null) return; // annulé
    if (nouveau == (profil.email ?? '')) return; // inchangé

    final resp = await api.updateParametres({
      'nom': profil.nom, // requis par le web (422 sinon)
      'email': nouveau, // '' → null côté web
    });
    if (!context.mounted) return;
    if (resp.success) {
      await dashboard.loadProfil();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('E-mail mis à jour'),
          backgroundColor: AppColors.success,
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resp.error ?? 'Erreur lors de la mise à jour'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _confirmLogout(BuildContext context, AuthService auth) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await auth.logout();
      if (context.mounted) context.go('/login');
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: AppColors.gray400, letterSpacing: 0.8,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.gray500),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: AppColors.gray800,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12, color: AppColors.gray400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18, color: AppColors.gray300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
