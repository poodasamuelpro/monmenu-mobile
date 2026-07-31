// lib/widgets/app_drawer.dart
// Sidebar identique au web: bg-gray-900, nav-links, hover:bg-gray-800
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final tenant = auth.tenant;
    final route = GoRouterState.of(context).uri.path;

    // Badge paiement en attente
    final showPaymentBadge = tenant != null &&
        (tenant.statut == 'en_attente_confirmation' ||
            tenant.statut == 'inactif' ||
            tenant.essaiExpireBientot);

    return Drawer(
      backgroundColor: AppColors.sidebar,
      width: 260,
      child: SafeArea(
        child: Column(
          children: [
            // ── Logo + tenant name ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.sidebarBorder, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: AppColors.primary, size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MonMenu',
                          style: TextStyle(
                            color: Color(0xFFF87171), // red-400
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        if (tenant != null)
                          Text(
                            tenant.nom,
                            style: const TextStyle(
                              color: AppColors.gray400,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Navigation ────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _NavItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Commandes',
                    route: '/dashboard/commandes',
                    currentRoute: route,
                  ),
                  _NavItem(
                    icon: Icons.menu_book_rounded,
                    label: 'Menu',
                    route: '/dashboard/menu',
                    currentRoute: route,
                  ),
                  _NavItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Statistiques',
                    route: '/dashboard/stats',
                    currentRoute: route,
                  ),
                  _NavItem(
                    icon: Icons.delivery_dining_rounded,
                    label: 'Livreurs',
                    route: '/dashboard/livreurs',
                    currentRoute: route,
                  ),
                  _NavItem(
                    icon: Icons.qr_code_rounded,
                    label: 'QR Code',
                    route: '/dashboard/qrcode',
                    currentRoute: route,
                  ),
                  _NavItem(
                    icon: Icons.local_offer_rounded,
                    label: 'Codes promo',
                    route: '/dashboard/codes-promo',
                    currentRoute: route,
                  ),
                  _NavItem(
                    icon: Icons.store_rounded,
                    label: 'Mon restaurant',
                    route: '/dashboard/restaurant',
                    currentRoute: route,
                  ),
                  _NavItem(
                    icon: Icons.palette_rounded,
                    label: 'Apparence',
                    route: '/dashboard/apparence',
                    currentRoute: route,
                  ),
                  _NavItem(
                    icon: Icons.workspace_premium_rounded,
                    label: 'Plans & Paiement',
                    route: '/dashboard/plans',
                    currentRoute: route,
                    badge: showPaymentBadge,
                  ),
                  _NavItem(
                    icon: Icons.notifications_rounded,
                    label: 'Notifications',
                    route: '/dashboard/notifications',
                    currentRoute: route,
                  ),
                  _NavItem(
                    icon: Icons.settings_rounded,
                    label: 'Paramètres',
                    route: '/dashboard/settings',
                    currentRoute: route,
                  ),
                ],
              ),
            ),

            // ── Déconnexion ───────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.sidebarBorder, width: 1),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.gray400,
                  size: 20,
                ),
                title: const Text(
                  'Déconnexion',
                  style: TextStyle(
                    color: AppColors.gray400,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () async {
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
                          child: const Text('Déconnecter'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await context.read<AuthService>().logout();
                    if (context.mounted) context.go('/login');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;
  final bool badge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentRoute.startsWith(route);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isActive ? AppColors.sidebarHover : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppColors.sidebarHover,
          onTap: () {
            context.go(route);
            Navigator.of(context).pop(); // Fermer le drawer sur mobile
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? Colors.white : AppColors.sidebarText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.sidebarText,
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge && !isActive)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (isActive)
                  Container(
                    width: 4, height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
