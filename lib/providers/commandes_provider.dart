// lib/providers/commandes_provider.dart
import 'package:flutter/foundation.dart';
import '../models/commande_model.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';

/// Résultat de updateStatut — inclut le lien WhatsApp livreur si applicable
class UpdateStatutResult {
  final bool success;
  final String? lienWhatsappLivreur;
  const UpdateStatutResult({required this.success, this.lienWhatsappLivreur});
}

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

    try {
      final resp = await _api.getCommandes();
      if (resp.success) {
        final rawList = resp.data?['commandes'] as List? ?? [];
        final parsed = <CommandeModel>[];
        for (final e in rawList) {
          try {
            parsed.add(CommandeModel.fromJson(e as Map<String, dynamic>));
          } catch (parseErr) {
            // Isolation par élément : une commande mal formée ne bloque pas les autres
            if (kDebugMode) {
              debugPrint('[CommandesProvider] loadCommandes: erreur parsing commande: $parseErr');
              debugPrint('  payload brut: $e');
            }
          }
        }
        _commandes = parsed;
        _updatePendingCount();
      } else {
        _error = resp.error;
        if (kDebugMode) debugPrint('[CommandesProvider] loadCommandes error: ${resp.error}');
      }
    } catch (e, st) {
      _error = 'Erreur inattendue lors du chargement des commandes';
      if (kDebugMode) {
        debugPrint('[CommandesProvider] loadCommandes exception: $e');
        debugPrint('$st');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Met à jour le statut d'une commande
  /// [livreurId] — si fourni ET statut == 'en_preparation', l'API génère le lien WhatsApp livreur
  /// Retourne [UpdateStatutResult] avec success + lienWhatsappLivreur si applicable
  Future<UpdateStatutResult> updateStatut(
    String commandeId,
    String newStatut, {
    String? livreurId,
  }) async {
    try {
      final resp = await _api.updateCommandeStatut(
        commandeId,
        newStatut,
        livreurId: livreurId,
      );
      if (resp.success) {
        final idx = _commandes.indexWhere((c) => c.id == commandeId);
        if (idx != -1) {
          _onStatutChange(commandeId, newStatut);
        }
        // Récupérer lien WhatsApp livreur si retourné par l'API
        final lien = resp.data?['lien_whatsapp_livreur'] as String?;
        return UpdateStatutResult(success: true, lienWhatsappLivreur: lien);
      }
      _error = resp.error;
      if (kDebugMode) debugPrint('[CommandesProvider] updateStatut error: ${resp.error}');
      notifyListeners();
      return UpdateStatutResult(success: false);
    } catch (e, st) {
      _error = 'Erreur inattendue lors de la mise à jour du statut';
      if (kDebugMode) {
        debugPrint('[CommandesProvider] updateStatut exception: $e');
        debugPrint('$st');
      }
      notifyListeners();
      return UpdateStatutResult(success: false);
    }
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
        modePaiement: old.modePaiement,
        notesClient: old.notesClient,
        livreurId: old.livreurId,
        items: old.items,
        updatedAt: DateTime.now(),
        numeroCommande: old.numeroCommande,
        pointDeVenteId: old.pointDeVenteId,
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
