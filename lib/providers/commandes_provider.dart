// lib/providers/commandes_provider.dart
import 'package:flutter/foundation.dart';
import '../models/commande_model.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';

class CommandesProvider extends ChangeNotifier {
  final ApiService _api;
  final RealtimeService _realtime;

  List<CommandeModel> _commandes = [];
  bool _isLoading = false;
  String? _error;
  String? _statutFilter;
  int _pendingCount = 0;

  CommandesProvider(this._api, this._realtime) {
    _realtime.onNouvelleCommande = _onNouvelleCommande;
    _realtime.onStatutChange = _onStatutChange;
  }

  List<CommandeModel> get commandes => _commandes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get statutFilter => _statutFilter;
  int get pendingCount => _pendingCount;

  List<CommandeModel> get filteredCommandes {
    if (_statutFilter == null) return _commandes;
    return _commandes.where((c) => c.statut == _statutFilter).toList();
  }

  void setFilter(String? statut) {
    _statutFilter = statut;
    notifyListeners();
  }

  Future<void> loadCommandes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final resp = await _api.getCommandes();
    if (resp.success) {
      final list = resp.data?['commandes'] as List? ?? [];
      _commandes = list
          .map((e) => CommandeModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _updatePendingCount();
    } else {
      _error = resp.error;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateStatut(String commandeId, String newStatut) async {
    final resp = await _api.updateCommandeStatut(commandeId, newStatut);
    if (resp.success) {
      final idx = _commandes.indexWhere((c) => c.id == commandeId);
      if (idx != -1) {
        // Mise à jour locale optimiste
        _onStatutChange(commandeId, newStatut);
      }
      return true;
    }
    _error = resp.error;
    notifyListeners();
    return false;
  }

  void _onNouvelleCommande(CommandeModel cmd) {
    final exists = _commandes.any((c) => c.id == cmd.id);
    if (!exists) {
      _commandes.insert(0, cmd);
      _updatePendingCount();
      notifyListeners();
    }
  }

  void _onStatutChange(String id, String statut) {
    final idx = _commandes.indexWhere((c) => c.id == id);
    if (idx != -1) {
      final old = _commandes[idx];
      _commandes[idx] = CommandeModel(
        id: old.id,
        tenantId: old.tenantId,
        statut: statut,
        montantTotal: old.montantTotal,
        createdAt: old.createdAt,
        nomClient: old.nomClient,
        telephoneClient: old.telephoneClient,
        adresseLivraison: old.adresseLivraison,
        fraisLivraison: old.fraisLivraison,
        notesClient: old.notesClient,
        items: old.items,
        updatedAt: DateTime.now(),
      );
      _updatePendingCount();
      notifyListeners();
    }
  }

  void _updatePendingCount() {
    _pendingCount = _commandes
        .where((c) => c.statut == 'en_attente')
        .length;
  }

  CommandeModel? getById(String id) =>
      _commandes.where((c) => c.id == id).firstOrNull;
}
