// lib/screens/dashboard/dashboard_screen.dart
// Vue d'ensemble: cartes stats, graphique 30j, commandes en attente
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/commandes_provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/realtime_service.dart';
import '../../models/plan_model.dart';
import '../../models/commande_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/loading_widget.dart' as lw;
import '../../widgets/payment_alert_banner.dart';
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      final tenant = auth.tenant;

      // Démarrer Realtime + Notifications
      if (tenant != null) {
        context.read<RealtimeService>().subscribe(tenant.id);
        context.read<NotificationService>().subscribe(tenant.id);
      }

      // Charger données
      context.read<DashboardProvider>().loadAll();
      context.read<DashboardProvider>().loadAbonnement();
      context.read<CommandesProvider>().loadCommandes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final tenant = auth.tenant;
    final dashboard = context.watch<DashboardProvider>();
    final commandes = context.watch<CommandesProvider>();
    final realtime = context.watch<RealtimeService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          // Indicateur Realtime
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: realtime.isConnected
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.gray100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: realtime.isConnected
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.gray200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: realtime.isConnected
                        ? AppColors.success
                        : AppColors.gray300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  realtime.isConnected ? 'En direct' : 'Hors ligne',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: realtime.isConnected
                        ? AppColors.success
                        : AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          final dashboard = context.read<DashboardProvider>();
          final commandes = context.read<CommandesProvider>();
          await dashboard.loadAll();
          await dashboard.loadAbonnement();
          await commandes.loadCommandes();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Bandeau alerte paiement ───────────────────────────────
              const PaymentAlertBanner(),

              // ── Essai Banner (legacy — remplacé par PaymentAlertBanner) ──
              // Maintenu pour les essais normaux (> 3 jours)
              if (tenant?.isEssai == true && !(tenant?.essaiExpireBientot ?? false))
                _EssaiBanner(tenant: tenant!),

              // ── Bonjour ──────────────────────────────────────────────────
              if (tenant != null) ...[
                Text(
                  'Bonjour 👋',
                  style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800,
                    color: AppColors.gray900,
                  ),
                ),
                Text(
                  tenant.nom,
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Stats cards ───────────────────────────────────────────────
              _StatsGrid(stats: dashboard.stats, isLoading: dashboard.isLoadingStats),
              const SizedBox(height: 20),

              // ── Graphique 30 jours ────────────────────────────────────────
              if (dashboard.stats?.statsJournalieres.isNotEmpty == true) ...[
                _buildSectionHeader('Commandes — 30 derniers jours'),
                const SizedBox(height: 12),
                _ChartCard(stats: dashboard.stats!.statsJournalieres),
                const SizedBox(height: 20),
              ],

              // ── Commandes en attente ──────────────────────────────────────
              Row(
                children: [
                  Expanded(child: _buildSectionHeader('Commandes en attente')),
                  if (commandes.pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${commandes.pendingCount}',
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => context.go('/dashboard/commandes'),
                    child: const Text('Voir tout'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (commandes.isLoading)
                const lw.ShimmerList(count: 2)
              else ...[
                ...commandes.commandes
                    .where((c) => c.statut == 'en_attente')
                    .take(5)
                    .map((c) => _MiniCommandeCard(
                          commande: c,
                          onTap: () => context.go(
                            '/dashboard/commandes/${c.id}',
                          ),
                        )),
                if (commandes.commandes
                    .where((c) => c.statut == 'en_attente')
                    .isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gray100),
                    ),
                    child: const Center(
                      child: Text(
                        'Aucune commande en attente 🎉',
                        style: TextStyle(
                          color: AppColors.gray400, fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16, fontWeight: FontWeight.w700,
        color: AppColors.gray900,
      ),
    );
  }
}

// ── Stats Grid ─────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final StatsModel? stats;
  final bool isLoading;

  const _StatsGrid({this.stats, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: List.generate(4, (_) => const lw.ShimmerCard(height: 80)),
      );
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _StatCard(
          icon: Icons.receipt_long_rounded,
          label: 'Total commandes',
          value: '${stats?.totalCommandes ?? 0}',
          color: AppColors.primary,
        ),
        _StatCard(
          icon: Icons.trending_up_rounded,
          label: 'Chiffre d\'affaires',
          value: '${(stats?.chiffreAffaires ?? 0).toStringAsFixed(0)} FCFA',
          color: AppColors.secondary,
          valueSmall: true,
        ),
        _StatCard(
          icon: Icons.today_rounded,
          label: 'Aujourd\'hui',
          value: '${stats?.commandesAujourdhui ?? 0} cmd',
          color: AppColors.success,
        ),
        _StatCard(
          icon: Icons.access_time_rounded,
          label: 'En attente',
          value: '${stats?.commandesPendantes ?? 0}',
          color: AppColors.warning,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool valueSmall;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.valueSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: valueSmall ? 13 : 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gray900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11, color: AppColors.gray400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Graphique ─────────────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final List<StatJournaliere> stats;
  const _ChartCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    final spots = stats.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.nbCommandes.toDouble())).toList();

    final maxY = stats.map((s) => s.nbCommandes.toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
      ),
      child: SizedBox(
        height: 160,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.gray100, strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (stats.length / 5).roundToDouble(),
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= stats.length) return const SizedBox.shrink();
                    final d = stats[idx].date;
                    return Text(
                      '${d.day}/${d.month}',
                      style: const TextStyle(fontSize: 9, color: AppColors.gray400),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0, maxX: (stats.length - 1).toDouble(),
            minY: 0, maxY: maxY == 0 ? 10 : maxY * 1.2,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mini commande card ────────────────────────────────────────────────────────
class _MiniCommandeCard extends StatelessWidget {
  final CommandeModel commande;
  final VoidCallback onTap;

  const _MiniCommandeCard({required this.commande, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray100),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.statusEnAttenteBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.statusEnAttente, size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commande.nomClient ?? 'Client anonyme',
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.gray800,
                    ),
                  ),
                  Text(
                    commande.heureCommande,
                    style: const TextStyle(
                      fontSize: 11, color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              commande.montantFormate,
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: AppColors.gray900,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.gray300),
          ],
        ),
      ),
    );
  }
}

// ── Essai Banner ──────────────────────────────────────────────────────────────
class _EssaiBanner extends StatelessWidget {
  final dynamic tenant;
  const _EssaiBanner({required this.tenant});

  @override
  Widget build(BuildContext context) {
    final jours = tenant.joursEssaiRestants;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded,
              color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              jours != null
                  ? 'Période d\'essai : $jours jour${jours > 1 ? 's' : ''} restant${jours > 1 ? 's' : ''}'
                  : 'Période d\'essai gratuite',
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/dashboard/plans'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Passer Pro',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
