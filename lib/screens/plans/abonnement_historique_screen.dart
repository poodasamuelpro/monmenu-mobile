// lib/screens/plans/abonnement_historique_screen.dart
// Historique paginé des abonnements — GET /paiement/historique
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/plan_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_widget.dart' as lw;

class AbonnementHistoriqueScreen extends StatefulWidget {
  const AbonnementHistoriqueScreen({super.key});

  @override
  State<AbonnementHistoriqueScreen> createState() =>
      _AbonnementHistoriqueScreenState();
}

class _AbonnementHistoriqueScreenState
    extends State<AbonnementHistoriqueScreen> {
  final List<AbonnementModel> _abonnements = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _limit = 10;
  String? _error;

  late ApiService _api;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final resp =
        await _api.getHistoriqueAbonnements(page: _page, limit: _limit);

    if (!mounted) return;

    if (resp.success && resp.data != null) {
      final list = resp.data!['abonnements'] as List? ?? [];
      final totalPages = (resp.data!['total_pages'] as num?)?.toInt() ?? 1;

      final parsed = list
          .map((e) => AbonnementModel.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _abonnements.addAll(parsed);
        _hasMore = _page < totalPages;
        _page++;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = resp.error ?? 'Erreur chargement historique';
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _abonnements.clear();
      _page = 1;
      _hasMore = true;
    });
    await _loadPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Historique des abonnements')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: _abonnements.isEmpty && _isLoading
            ? const lw.ShimmerList(count: 5)
            : _abonnements.isEmpty && _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: AppColors.gray300),
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: AppColors.gray500)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _refresh,
                            child: const Text('Réessayer')),
                      ],
                    ),
                  )
                : _abonnements.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun abonnement dans l\'historique.',
                          style: TextStyle(color: AppColors.gray400),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            _abonnements.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _abonnements.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                  child: CircularProgressIndicator()),
                            );
                          }
                          return _AbonnementCard(
                              abonnement: _abonnements[index]);
                        },
                      ),
      ),
    );
  }
}

// ── Carte abonnement ──────────────────────────────────────────────────────────
class _AbonnementCard extends StatelessWidget {
  final AbonnementModel abonnement;

  const _AbonnementCard({required this.abonnement});

  @override
  Widget build(BuildContext context) {
    final statutColor = _statutColor(abonnement.statut);
    final isRejete = abonnement.isRejete;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                abonnement.plan?.nom ?? 'Plan inconnu',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray900,
                ),
              ),
              _StatutChip(statut: abonnement.statut, color: statutColor),
            ],
          ),
          const SizedBox(height: 8),

          // Référence
          if (abonnement.referencePaiement != null)
            _InfoRow(
              icon: Icons.tag_rounded,
              label: 'Référence',
              value: abonnement.referencePaiement!,
              mono: true,
            ),

          // Montant
          if (abonnement.montantPaye != null)
            _InfoRow(
              icon: Icons.payments_rounded,
              label: 'Montant',
              value:
                  '${abonnement.montantPaye!.toStringAsFixed(0)} ${abonnement.devise ?? 'XOF'}',
            ),

          // Méthode
          if (abonnement.methodePaiement != null)
            _InfoRow(
              icon: Icons.credit_card_rounded,
              label: 'Méthode',
              value: _methodLabel(abonnement.methodePaiement!),
            ),

          // Soumis le
          if (abonnement.soumisLe != null)
            _InfoRow(
              icon: Icons.upload_rounded,
              label: 'Soumis le',
              value: _formatDate(abonnement.soumisLe!),
            ),

          // Confirmé le
          if (abonnement.confirmeLe != null)
            _InfoRow(
              icon: Icons.check_circle_rounded,
              label: 'Confirmé le',
              value: _formatDate(abonnement.confirmeLe!),
              color: AppColors.success,
            ),

          // Confirmé par
          if (abonnement.confirmeParNom != null)
            _InfoRow(
              icon: Icons.person_rounded,
              label: 'Par',
              value: abonnement.confirmeParNom!,
            ),

          // Motif rejet
          if (isRejete && abonnement.motifRejet != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded,
                      color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Motif : ${abonnement.motifRejet}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Période
          if (abonnement.debutLe != null && abonnement.finLe != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Période : ${_formatDate(abonnement.debutLe!)} → ${_formatDate(abonnement.finLe!)}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.gray400),
              ),
            ),
        ],
      ),
    );
  }

  Color _statutColor(String statut) {
    switch (statut) {
      case 'actif': return AppColors.success;
      case 'en_attente_confirmation': return Colors.orange;
      case 'rejete': return AppColors.error;
      case 'expire': return AppColors.gray400;
      default: return AppColors.gray500;
    }
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'mobile_money': return 'Mobile Money';
      case 'virement': return 'Virement bancaire';
      case 'carte': return 'Carte bancaire';
      default: return method;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

class _StatutChip extends StatelessWidget {
  final String statut;
  final Color color;
  const _StatutChip({required this.statut, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _label(statut),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  String _label(String s) {
    switch (s) {
      case 'actif': return 'Actif';
      case 'en_attente_confirmation': return 'En attente';
      case 'rejete': return 'Rejeté';
      case 'expire': return 'Expiré';
      default: return s;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final bool mono;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.gray400),
          const SizedBox(width: 6),
          Text(
            '$label : ',
            style: const TextStyle(fontSize: 12, color: AppColors.gray400),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color ?? AppColors.gray700,
                fontFamily: mono ? 'monospace' : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
