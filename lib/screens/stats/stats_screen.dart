// lib/screens/stats/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/plan_model.dart';
import '../../providers/dashboard_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/loading_widget.dart' as lw;

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final stats = dashboard.stats;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Statistiques')),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => dashboard.loadAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dashboard.isLoadingStats)
                const lw.ShimmerList(count: 3)
              else if (stats == null)
                const Center(child: Text('Aucune statistique disponible'))
              else ...[
                // KPI cards
                Row(
                  children: [
                    Expanded(child: _KpiCard(
                      label: 'Total commandes',
                      value: '${stats.totalCommandes}',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.primary,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _KpiCard(
                      label: 'Chiffre d\'affaires',
                      value: '${stats.chiffreAffaires.toStringAsFixed(0)} F',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.success,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _KpiCard(
                      label: 'Aujourd\'hui',
                      value: '${stats.commandesAujourdhui}',
                      icon: Icons.today_rounded,
                      color: AppColors.secondary,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _KpiCard(
                      label: 'CA aujourd\'hui',
                      value: '${stats.caAujourdhui.toStringAsFixed(0)} F',
                      icon: Icons.payments_rounded,
                      color: AppColors.warning,
                    )),
                  ],
                ),
                const SizedBox(height: 24),

                // Graphique commandes
                if (stats.statsJournalieres.isNotEmpty) ...[
                  _buildSectionTitle('Commandes — 30 jours'),
                  const SizedBox(height: 12),
                  _buildLineChart(
                    stats.statsJournalieres,
                    (s) => s.nbCommandes.toDouble(),
                    AppColors.primary,
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Chiffre d\'affaires — 30 jours'),
                  const SizedBox(height: 12),
                  _buildLineChart(
                    stats.statsJournalieres,
                    (s) => s.chiffreAffaires,
                    AppColors.success,
                  ),
                  const SizedBox(height: 24),

                  // Table des données
                  _buildSectionTitle('Détails par jour'),
                  const SizedBox(height: 12),
                  _StatsTable(stats: stats.statsJournalieres.reversed.take(14).toList()),
                ],
              ],
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w700,
        color: AppColors.gray800,
      ),
    );
  }

  Widget _buildLineChart(
    List<StatJournaliere> data,
    double Function(StatJournaliere) valueGetter,
    Color color,
  ) {
    if (data.isEmpty) return const SizedBox.shrink();
    final spots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), valueGetter(e.value)))
        .toList();
    final maxY = data.map(valueGetter).fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
      ),
      child: SizedBox(
        height: 180,
        child: LineChart(LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppColors.gray100, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 9, color: AppColors.gray400),
                ),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 7,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                  final d = data[idx].date;
                  return Text(
                    '${d.day}/${d.month}',
                    style: const TextStyle(fontSize: 9, color: AppColors.gray400),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0, maxX: (data.length - 1).toDouble(),
          minY: 0, maxY: maxY == 0 ? 10 : maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.07),
              ),
            ),
          ],
        )),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800,
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
          ),
        ],
      ),
    );
  }
}

class _StatsTable extends StatelessWidget {
  final List<StatJournaliere> stats;
  const _StatsTable({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                Expanded(child: Text('Date', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.gray600,
                ))),
                SizedBox(
                  width: 80,
                  child: Text('Commandes', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.gray600,
                  ), textAlign: TextAlign.center),
                ),
                SizedBox(
                  width: 100,
                  child: Text('CA (FCFA)', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.gray600,
                  ), textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          ...stats.map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.gray100, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(
                  '${s.date.day.toString().padLeft(2, '0')}/${s.date.month.toString().padLeft(2, '0')}/${s.date.year}',
                  style: const TextStyle(fontSize: 13, color: AppColors.gray700),
                )),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${s.nbCommandes}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.gray800),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    s.chiffreAffaires.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.primary),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
