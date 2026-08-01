// lib/providers/dashboard_provider.dart
import 'package:flutter/foundation.dart';
import '../models/plan_model.dart';
import '../services/api_service.dart';

/// États possibles d'un upload de preuve de paiement.
enum UploadStatut { idle, loading, success, error }

class DashboardProvider extends ChangeNotifier {
  final ApiService _api;

  StatsModel? _stats;
  ProfilModel? _profil;
  List<PlanModel> _plans = [];
  bool _isLoadingStats = false;
  bool _isLoadingProfil = false;
  bool _isLoadingPlans = false;
  String? _error;

  // ── Paiement ───────────────────────────────────────────────────────────────
  Map<String, dynamic>? _abonnementStatut;
  String? _referencePaiement;
  List<String> _referenceInstructions = [];
  bool _isLoadingAbonnement = false;
  bool _isLoadingReference = false;
  String? _abonnementError;

  /// État de l'upload de preuve en cours.
  UploadStatut _uploadStatut = UploadStatut.idle;
  String? _uploadError;
  Map<String, dynamic>? _uploadResult;

  DashboardProvider(this._api);

  // ── Getters stats/profil/plans ─────────────────────────────────────────────
  StatsModel? get stats => _stats;
  ProfilModel? get profil => _profil;
  List<PlanModel> get plans => _plans;
  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingProfil => _isLoadingProfil;
  bool get isLoadingPlans => _isLoadingPlans;
  String? get error => _error;

  // ── Getters paiement ───────────────────────────────────────────────────────

  /// Données brutes de GET /paiement/statut.
  Map<String, dynamic>? get abonnementStatut => _abonnementStatut;

  /// Statut du tenant tel que retourné par le serveur.
  String? get statutTenant => _abonnementStatut?['statut_tenant'] as String?;

  /// Données de l'abonnement en cours (imbriqué dans statut).
  Map<String, dynamic>? get abonnementEnCours =>
      _abonnementStatut?['abonnement'] as Map<String, dynamic>?;

  /// Référence de paiement active.
  String? get referencePaiement => _referencePaiement;

  /// Instructions de paiement (liste de chaînes).
  List<String> get referenceInstructions => _referenceInstructions;

  bool get isLoadingAbonnement => _isLoadingAbonnement;
  bool get isLoadingReference => _isLoadingReference;
  String? get abonnementError => _abonnementError;

  /// Vrai si le tenant a un abonnement en attente de confirmation.
  bool get hasAbonnementEnAttente =>
      statutTenant == 'en_attente_confirmation' ||
      abonnementEnCours?['statut'] == 'en_attente_confirmation';

  /// Jours d'essai restants depuis la réponse serveur.
  int? get joursEssaiRestants =>
      (_abonnementStatut?['jours_essai_restants'] as num?)?.toInt();

  // ── Upload state ───────────────────────────────────────────────────────────
  UploadStatut get uploadStatut => _uploadStatut;
  bool get isUploading => _uploadStatut == UploadStatut.loading;
  bool get uploadSuccess => _uploadStatut == UploadStatut.success;
  String? get uploadError => _uploadError;
  Map<String, dynamic>? get uploadResult => _uploadResult;

  // ── Actions stats/profil/plans ─────────────────────────────────────────────

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
    // NOTE: /dashboard/stats retourne déjà labels/values/ca_values (30 jours)
    // Ce endpoint est conservé pour compatibilité mais n'est plus nécessaire
    // si loadStats() a déjà été appelé (les données 30j sont dans StatsModel)
    // On l'appelle seulement si _stats est null
    if (_stats != null) return;
    final resp = await _api.getStatsJournalieres(jours: jours);
    if (resp.success && resp.data != null) {
      // Réutiliser les données brutes si disponibles
      final data = resp.data!;
      if (_stats == null) {
        _stats = StatsModel.fromJson(data);
        notifyListeners();
      }
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

  // ── Actions paiement ───────────────────────────────────────────────────────

  /// Charge le statut de l'abonnement actif depuis GET /paiement/statut.
  /// SEC-04 : ne jamais utiliser comme source de vérité locale pour débloquer
  /// une fonctionnalité — toujours revalider au prochain appel.
  Future<void> loadAbonnement() async {
    _isLoadingAbonnement = true;
    _abonnementError = null;
    notifyListeners();

    final resp = await _api.getAbonnementActif();
    if (resp.success && resp.data != null) {
      _abonnementStatut = resp.data;
    } else {
      _abonnementError = resp.error ?? 'Erreur chargement abonnement';
    }
    _isLoadingAbonnement = false;
    notifyListeners();
  }

  /// Charge la référence de paiement depuis GET /paiement/reference.
  Future<void> loadReferencePaiement() async {
    _isLoadingReference = true;
    notifyListeners();

    final resp = await _api.getReferencePaiement();
    if (resp.success && resp.data != null) {
      _referencePaiement = resp.data!['reference'] as String?;
      final instructions = resp.data!['instructions'];
      if (instructions is List) {
        _referenceInstructions =
            instructions.map((e) => e.toString()).toList();
      }
    }
    _isLoadingReference = false;
    notifyListeners();
  }

  /// Met à jour l'état de l'upload en cours.
  void setUploadLoading() {
    _uploadStatut = UploadStatut.loading;
    _uploadError = null;
    _uploadResult = null;
    notifyListeners();
  }

  /// Signale un upload réussi et stocke la réponse serveur.
  void setUploadSuccess(Map<String, dynamic> result) {
    _uploadStatut = UploadStatut.success;
    _uploadResult = result;
    _uploadError = null;
    // Recharger le statut abonnement après succès
    loadAbonnement();
    notifyListeners();
  }

  /// Signale une erreur d'upload.
  void setUploadError(String error) {
    _uploadStatut = UploadStatut.error;
    _uploadError = error;
    notifyListeners();
  }

  /// Réinitialise l'état de l'upload.
  void resetUpload() {
    _uploadStatut = UploadStatut.idle;
    _uploadError = null;
    _uploadResult = null;
    notifyListeners();
  }
}
