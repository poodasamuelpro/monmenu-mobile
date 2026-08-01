// lib/models/commande_model.dart
// Champs API /dashboard/commandes (Hono.js/Cloudflare Workers):
//   id, client_nom, client_telephone, client_adresse, items_json (STRING JSON),
//   montant_total, frais_livraison, mode_paiement, statut, notes,
//   livreur_id, created_at, updated_at
import 'dart:convert';

class CommandeModel {
  final String id;
  final String tenantId;
  final String? pointDeVenteId;
  final String statut;
  final String? nomClient;
  final String? telephoneClient;
  final String? adresseLivraison;
  final double montantTotal;
  final double? fraisLivraison;
  final String? modePaiement;
  final String? notesClient;
  final String? livreurId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<CommandeItemModel> items;
  final String? numeroCommande;

  const CommandeModel({
    required this.id,
    required this.tenantId,
    required this.statut,
    required this.montantTotal,
    required this.createdAt,
    this.pointDeVenteId,
    this.nomClient,
    this.telephoneClient,
    this.adresseLivraison,
    this.fraisLivraison,
    this.modePaiement,
    this.notesClient,
    this.livreurId,
    this.updatedAt,
    this.items = const [],
    this.numeroCommande,
  });

  factory CommandeModel.fromJson(Map<String, dynamic> json) {
    // items_json est une STRING JSON dans la réponse API (pas un tableau direct)
    List<CommandeItemModel> items = [];
    final rawItems = json['items_json'];
    if (rawItems is String && rawItems.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems);
        if (decoded is List) {
          items = decoded
              .map((e) => CommandeItemModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {
        // items_json malformé — ignorer
      }
    } else if (rawItems is List) {
      // Cas où l'API renverrait déjà un tableau (robustesse)
      items = rawItems
          .map((e) => CommandeItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return CommandeModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      pointDeVenteId: json['point_de_vente_id'] as String?,
      statut: json['statut'] as String? ?? 'en_attente',
      // Noms corrects API: client_nom, client_telephone, client_adresse, notes
      nomClient: json['client_nom'] as String?,
      telephoneClient: json['client_telephone'] as String?,
      adresseLivraison: json['client_adresse'] as String?,
      montantTotal: _toDouble(json['montant_total']),
      fraisLivraison: _toDoubleNullable(json['frais_livraison']),
      modePaiement: json['mode_paiement'] as String?,
      notesClient: json['notes'] as String?,
      livreurId: json['livreur_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      items: items,
      numeroCommande: json['numero_commande'] as String?,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static double? _toDoubleNullable(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'statut': statut,
    'client_nom': nomClient,
    'client_telephone': telephoneClient,
    'client_adresse': adresseLivraison,
    'montant_total': montantTotal,
    'frais_livraison': fraisLivraison,
    'notes': notesClient,
    'created_at': createdAt.toIso8601String(),
  };

  String get montantFormate {
    final m = montantTotal.toStringAsFixed(0);
    return '$m FCFA';
  }

  String get heureCommande {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final min = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  String get dateCommande {
    return '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/'
        '${createdAt.year}';
  }

  bool get isPending =>
      statut == 'en_attente' || statut == 'confirmee' || statut == 'en_preparation';

  String? get nextStatut {
    switch (statut) {
      case 'en_attente': return 'confirmee';
      case 'confirmee': return 'en_preparation';
      case 'en_preparation': return 'en_livraison';
      case 'en_livraison': return 'livree';
      default: return null;
    }
  }

  String? get nextStatutLabel {
    switch (statut) {
      case 'en_attente': return 'Confirmer';
      case 'confirmee': return 'En préparation';
      case 'en_preparation': return 'En livraison';
      case 'en_livraison': return 'Marquer livrée';
      default: return null;
    }
  }
}

class CommandeItemModel {
  // Structure items_json: {nom, quantite, prix, produit_id?, notes?}
  final String? id;
  final String? produitId;
  final int quantite;
  final double prixUnitaire;
  final String? nomProduit;
  final String? notesItem;

  const CommandeItemModel({
    this.id,
    this.produitId,
    required this.quantite,
    required this.prixUnitaire,
    this.nomProduit,
    this.notesItem,
  });

  factory CommandeItemModel.fromJson(Map<String, dynamic> json) {
    return CommandeItemModel(
      id: json['id'] as String?,
      produitId: json['produit_id'] as String?,
      quantite: (json['quantite'] as num?)?.toInt() ?? 1,
      // items_json utilise 'prix' (pas 'prix_unitaire')
      prixUnitaire: CommandeModel._toDouble(json['prix'] ?? json['prix_unitaire']),
      // items_json utilise 'nom' (pas 'nom_produit')
      nomProduit: (json['nom'] ?? json['nom_produit']) as String?,
      notesItem: json['notes'] as String?,
    );
  }

  double get sousTotal => quantite * prixUnitaire;
}
