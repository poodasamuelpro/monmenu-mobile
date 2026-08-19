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

  // ── M5 — champs GET /paiement/statut consommés (api-paiement.ts l.103-174) ──

  /// SLA de confirmation admin en heures (serveur, défaut web = 48).
  int? get slaAdminHeures =>
      (_abonnementStatut?['sla_admin_heures'] as num?)?.toInt();

  /// Fenêtre d'accès post-expiration en heures (serveur, défaut web = 72).
  int? get fenetreAccesHeures =>
      (_abonnementStatut?['fenetre_acces_heures'] as num?)?.toInt();

  /// Nom du plan initial (avant changement en attente de confirmation).
  String? get planInitialNom =>
      _abonnementStatut?['plan_initial_nom'] as String?;

  /// Prix mensuel du plan initial.
  double? get planInitialPrix {
    final v = _abonnementStatut?['plan_initial_prix_mensuel'];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Date de fin de l'abonnement en cours (abonnement.date_fin).
  DateTime? get dateFin {
    final raw = abonnementEnCours?['date_fin'] as String?;
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  /// Mode d'accès calculé côté serveur (source de vérité).
  String? get modeAccesServeur => _abonnementStatut?['mode_acces'] as String?;

  /// Heures restantes de confirmation depuis le serveur (prioritaire sur
  /// tout calcul local — M5).
  int? get heuresRestantesServeur =>
      (abonnementEnCours?['heures_restantes_confirmation'] as num?)?.toInt();

  // ── Upload state ───────────────────────────────────────────────────────────
  UploadStatut get uploadStatut => _uploadStatut;
  bool get isUploading => _uploadStatut == UploadStatut.loading;
  bool get uploadSuccess => _uploadStatut == UploadStatut.success;
  String? get uploadError => _uploadError;
  Map<String, dynamic>? get uploadResult => _uploadResult;

  // ── Actions stats/profil/plans ─────────────────────────────────────────────

  Future<void> loadStats() async {
    _isLoadingStats = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await _api.getStats();
      if (resp.success && resp.data != null) {
        _stats = StatsModel.fromJson(resp.data!);
      } else {
        _error = resp.error ?? 'Erreur chargement statistiques';
        if (kDebugMode) debugPrint('[DashboardProvider] loadStats error: ${resp.error}');
      }
    } catch (e, st) {
      _error = 'Erreur inattendue lors du chargement des statistiques';
      if (kDebugMode) {
        debugPrint('[DashboardProvider] loadStats exception: $e');
        debugPrint('$st');
      }
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  Future<void> loadStatsJournalieres({int jours = 30}) async {
    // NOTE: /dashboard/stats retourne déjà labels/values/ca_values (30 jours)
    // Ce endpoint est conservé pour compatibilité mais n'est plus nécessaire
    // si loadStats() a déjà été appelé (les données 30j sont dans StatsModel)
    // On l'appelle seulement si _stats est null
    if (_stats != null) return;
    try {
      final resp = await _api.getStatsJournalieres(jours: jours);
      if (resp.success && resp.data != null) {
        final data = resp.data!;
        if (_stats == null) {
          _stats = StatsModel.fromJson(data);
          notifyListeners();
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[DashboardProvider] loadStatsJournalieres exception: $e');
        debugPrint('$st');
      }
    }
  }

  Future<void> loadProfil() async {
    _isLoadingProfil = true;
    notifyListeners();

    try {
      final resp = await _api.getProfil();
      if (resp.success && resp.data != null) {
        _profil = ProfilModel.fromJson(resp.data!);
      } else if (!resp.success) {
        if (kDebugMode) debugPrint('[DashboardProvider] loadProfil error: ${resp.error}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[DashboardProvider] loadProfil exception: $e');
        debugPrint('$st');
      }
    } finally {
      _isLoadingProfil = false;
      notifyListeners();
    }
  }

  Future<void> loadPlans() async {
    _isLoadingPlans = true;
    notifyListeners();

    try {
      final resp = await _api.getPlans();
      if (resp.success) {
        final rawList = resp.data?['plans'] as List? ?? [];
        final parsed = <PlanModel>[];
        for (final e in rawList) {
          try {
            parsed.add(PlanModel.fromJson(e as Map<String, dynamic>));
          } catch (parseErr) {
            if (kDebugMode) {
              debugPrint('[DashboardProvider] loadPlans: erreur parsing plan: $parseErr');
              debugPrint('  payload: $e');
            }
          }
        }
        _plans = parsed;
        _plans.sort((a, b) => a.ordreAffichage.compareTo(b.ordreAffichage));
      } else {
        if (kDebugMode) debugPrint('[DashboardProvider] loadPlans error: ${resp.error}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[DashboardProvider] loadPlans exception: $e');
        debugPrint('$st');
      }
    } finally {
      _isLoadingPlans = false;
      notifyListeners();
    }
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

    try {
      final resp = await _api.getAbonnementActif();
      if (resp.success && resp.data != null) {
        _abonnementStatut = resp.data;
      } else {
        _abonnementError = resp.error ?? 'Erreur chargement abonnement';
        if (kDebugMode) debugPrint('[DashboardProvider] loadAbonnement error: ${resp.error}');
      }
    } catch (e, st) {
      _abonnementError = 'Erreur inattendue lors du chargement de l\'abonnement';
      if (kDebugMode) {
        debugPrint('[DashboardProvider] loadAbonnement exception: $e');
        debugPrint('$st');
      }
    } finally {
      _isLoadingAbonnement = false;
      notifyListeners();
    }
  }

  /// Charge la référence de paiement depuis GET /paiement/reference.
  Future<void> loadReferencePaiement() async {
    _isLoadingReference = true;
    notifyListeners();

    try {
      final resp = await _api.getReferencePaiement();
      if (resp.success && resp.data != null) {
        _referencePaiement = resp.data!['reference'] as String?;
        final instructions = resp.data!['instructions'];
        if (instructions is List) {
          _referenceInstructions =
              instructions.map((e) => e.toString()).toList();
        }
      } else {
        if (kDebugMode) debugPrint('[DashboardProvider] loadReferencePaiement error: ${resp.error}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[DashboardProvider] loadReferencePaiement exception: $e');
        debugPrint('$st');
      }
    } finally {
      _isLoadingReference = false;
      notifyListeners();
    }
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
