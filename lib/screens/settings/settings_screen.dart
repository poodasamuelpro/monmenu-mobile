// lib/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/payment_alert_banner.dart';
import '../../widgets/statut_badge.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final tenant = auth.tenant;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paramètres'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard/commandes'),
          tooltip: 'Retour',
        ),
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
            _SettingsTile(
              icon: Icons.workspace_premium_rounded,
              label: 'Plans & Paiement',
              onTap: () => context.go('/dashboard/plans'),
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
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
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
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: AppColors.gray800,
                    ),
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
