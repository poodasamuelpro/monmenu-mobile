// lib/screens/commandes/commandes_screen.dart
// Liste commandes avec filtres par statut + Realtime
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/commandes_provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/realtime_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/commande_card.dart';
import '../../widgets/loading_widget.dart' as lw;
import '../../widgets/payment_alert_banner.dart';

class CommandesScreen extends StatefulWidget {
  const CommandesScreen({super.key});

  @override
  State<CommandesScreen> createState() => _CommandesScreenState();
}

class _CommandesScreenState extends State<CommandesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      final tenant = auth.tenant;

      // Démarrer Realtime si pas encore abonné
      if (tenant != null) {
        final realtime = context.read<RealtimeService>();
        realtime.subscribe(tenant.id);

        // Démarrer notifications
        final notif = context.read<NotificationService>();
        notif.subscribe(tenant.id);
        notif.onNouvelleCommande = (id, nomClient, montant) {
          context.read<CommandesProvider>().loadCommandes();
        };
      }

      context.read<CommandesProvider>().loadCommandes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommandesProvider>();
    final realtime = context.watch<RealtimeService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
          tooltip: 'Menu',
        ),
        title: Row(
          children: [
            const Text('Commandes'),
            if (provider.pendingCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.pendingCount}',
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: realtime.isConnected
                        ? AppColors.success
                        : AppColors.gray300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  realtime.isConnected ? 'Live' : 'Off',
                  style: TextStyle(
                    fontSize: 11,
                    color: realtime.isConnected
                        ? AppColors.success
                        : AppColors.gray400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // ── Filtres statuts ──────────────────────────────────────────────
          // ── Bandeau alerte paiement ──────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: PaymentAlertBanner(),
          ),

          _StatutFilter(
            current: provider.statutFilter,
            onChanged: (s) => provider.setFilter(s),
            commandes: provider.commandes,
          ),

          // ── Liste ────────────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => provider.loadCommandes(),
              child: provider.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: lw.ShimmerList(count: 5),
                    )
                  : provider.error != null
                      ? lw.AppErrorWidget(
                          message: provider.error!,
                          onRetry: provider.loadCommandes,
                        )
                      : provider.filteredCommandes.isEmpty
                          ? _EmptyState(filter: provider.statutFilter)
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: provider.filteredCommandes.length,
                              itemBuilder: (ctx, i) {
                                final c = provider.filteredCommandes[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: CommandeCard(
                                    commande: c,
                                    onTap: () => context.go(
                                      '/dashboard/commandes/${c.id}',
                                    ),
                                    onNextStatut: c.nextStatut != null
                                        ? () => _updateStatut(c.id, c.nextStatut!)
                                        : null,
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatut(String id, String newStatut) async {
    final result = await context.read<CommandesProvider>()
        .updateStatut(id, newStatut);
    if (!result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la mise à jour du statut'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _StatutFilter extends StatelessWidget {
  final String? current;
  final ValueChanged<String?> onChanged;
  final List commandes;

  const _StatutFilter({
    required this.current,
    required this.onChanged,
    required this.commandes,
  });

  @override
  Widget build(BuildContext context) {
    final statuts = [null, ...CommandeStatut.all];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: statuts.map((s) {
            final isActive = current == s;
            final count = s == null
                ? commandes.length
                : commandes.where((c) => c.statut == s).length;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.gray100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? AppColors.primary : AppColors.gray200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s == null ? 'Toutes' : CommandeStatut.label(s),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : AppColors.gray600,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white.withValues(alpha: 0.25)
                                : AppColors.gray200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isActive ? Colors.white : AppColors.gray600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? filter;
  const _EmptyState({this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.gray100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 38, color: AppColors.gray300,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filter == null
                ? 'Aucune commande'
                : 'Aucune commande ${CommandeStatut.label(filter!).toLowerCase()}',
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Les nouvelles commandes apparaîtront ici',
            style: TextStyle(fontSize: 12, color: AppColors.gray400),
          ),
        ],
      ),
    );
  }
}
