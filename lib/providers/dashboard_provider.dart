// lib/providers/dashboard_provider.dart
import 'package:flutter/foundation.dart';
import '../models/plan_model.dart';
import '../services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiService _api;

  StatsModel? _stats;
  ProfilModel? _profil;
  List<PlanModel> _plans = [];
  bool _isLoadingStats = false;
  bool _isLoadingProfil = false;
  bool _isLoadingPlans = false;
  String? _error;

  DashboardProvider(this._api);

  StatsModel? get stats => _stats;
  ProfilModel? get profil => _profil;
  List<PlanModel> get plans => _plans;
  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingProfil => _isLoadingProfil;
  bool get isLoadingPlans => _isLoadingPlans;
  String? get error => _error;

  Future<void> loadStats() async {
    _isLoadingStats = true;
    notifyListeners();

    final resp = await _api.getStats();
    if (resp.success && resp.data != null) {
      _stats = StatsModel.fromJson(resp.data!);
    }
    _isLoadingStats = false;
    notifyListeners();
  }

  Future<void> loadStatsJournalieres({int jours = 30}) async {
    final resp = await _api.getStatsJournalieres(jours: jours);
    if (resp.success && resp.data != null) {
      final list = resp.data!['stats'] as List? ?? [];
      final statsJ = list
          .map((e) => StatJournaliere.fromJson(e as Map<String, dynamic>))
          .toList();
      _stats = StatsModel(
        totalCommandes: _stats?.totalCommandes ?? 0,
        chiffreAffaires: _stats?.chiffreAffaires ?? 0,
        commandesAujourdhui: _stats?.commandesAujourdhui ?? 0,
        caAujourdhui: _stats?.caAujourdhui ?? 0,
        commandesPendantes: _stats?.commandesPendantes ?? 0,
        statsJournalieres: statsJ,
      );
      notifyListeners();
    }
  }

  Future<void> loadProfil() async {
    _isLoadingProfil = true;
    notifyListeners();

    final resp = await _api.getProfil();
    if (resp.success && resp.data != null) {
      _profil = ProfilModel.fromJson(resp.data!);
    }
    _isLoadingProfil = false;
    notifyListeners();
  }

  Future<void> loadPlans() async {
    _isLoadingPlans = true;
    notifyListeners();

    final resp = await _api.getPlans();
    if (resp.success) {
      final list = resp.data?['plans'] as List? ?? [];
      _plans = list
          .map((e) => PlanModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _plans.sort((a, b) => a.ordreAffichage.compareTo(b.ordreAffichage));
    }
    _isLoadingPlans = false;
    notifyListeners();
  }

  Future<void> loadAll() async {
    await Future.wait([loadStats(), loadProfil()]);
    await loadStatsJournalieres();
  }
}
