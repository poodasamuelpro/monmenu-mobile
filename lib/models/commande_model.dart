// lib/models/commande_model.dart
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
  final String? modesPaiementId;
  final String? notesClient;
  final String? codePromoId;
  final double? reductionAppliquee;
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
    this.modesPaiementId,
    this.notesClient,
    this.codePromoId,
    this.reductionAppliquee,
    this.livreurId,
    this.updatedAt,
    this.items = const [],
    this.numeroCommande,
  });

  factory CommandeModel.fromJson(Map<String, dynamic> json) {
    List<CommandeItemModel> items = [];
    if (json['commandes_items'] is List) {
      items = (json['commandes_items'] as List)
          .map((e) => CommandeItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return CommandeModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      pointDeVenteId: json['point_de_vente_id'] as String?,
      statut: json['statut'] as String? ?? 'en_attente',
      nomClient: json['nom_client'] as String?,
      telephoneClient: json['telephone_client'] as String?,
      adresseLivraison: json['adresse_livraison'] as String?,
      montantTotal: _toDouble(json['montant_total']),
      fraisLivraison: _toDoubleNullable(json['frais_livraison']),
      modesPaiementId: json['modes_paiement_id'] as String?,
      notesClient: json['notes_client'] as String?,
      codePromoId: json['code_promo_id'] as String?,
      reductionAppliquee: _toDoubleNullable(json['reduction_appliquee']),
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
    'nom_client': nomClient,
    'telephone_client': telephoneClient,
    'adresse_livraison': adresseLivraison,
    'montant_total': montantTotal,
    'frais_livraison': fraisLivraison,
    'notes_client': notesClient,
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
  final String id;
  final String commandeId;
  final String produitId;
  final String? varianteProduitId;
  final int quantite;
  final double prixUnitaire;
  final String? nomProduit;
  final String? notesItem;

  const CommandeItemModel({
    required this.id,
    required this.commandeId,
    required this.produitId,
    required this.quantite,
    required this.prixUnitaire,
    this.varianteProduitId,
    this.nomProduit,
    this.notesItem,
  });

  factory CommandeItemModel.fromJson(Map<String, dynamic> json) {
    return CommandeItemModel(
      id: json['id'] as String? ?? '',
      commandeId: json['commande_id'] as String? ?? '',
      produitId: json['produit_id'] as String? ?? '',
      varianteProduitId: json['variante_produit_id'] as String?,
      quantite: (json['quantite'] as num?)?.toInt() ?? 1,
      prixUnitaire: CommandeModel._toDouble(json['prix_unitaire']),
      nomProduit: json['nom_produit'] as String?,
      notesItem: json['notes_item'] as String?,
    );
  }

  double get sousTotal => quantite * prixUnitaire;
}
