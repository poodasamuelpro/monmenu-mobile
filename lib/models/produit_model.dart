// lib/models/produit_model.dart
class ProduitModel {
  final String id;
  final String tenantId;
  final String categorieId;
  final String nom;
  final String? description;
  final double prix;
  final String? imageUrl;
  final bool actif;
  final bool disponible;
  final int? ordreAffichage;
  final List<VarianteProduitModel> variantes;
  final DateTime? createdAt;

  const ProduitModel({
    required this.id,
    required this.tenantId,
    required this.categorieId,
    required this.nom,
    required this.prix,
    this.description,
    this.imageUrl,
    this.actif = true,
    this.disponible = true,
    this.ordreAffichage,
    this.variantes = const [],
    this.createdAt,
  });

  factory ProduitModel.fromJson(Map<String, dynamic> json) {
    List<VarianteProduitModel> variantes = [];
    if (json['variantes_produits'] is List) {
      variantes = (json['variantes_produits'] as List)
          .map((e) => VarianteProduitModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return ProduitModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      categorieId: json['categorie_id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      description: json['description'] as String?,
      prix: _toDouble(json['prix']),
      // API retourne 'photo_url' (pas 'image_url')
      imageUrl: (json['photo_url'] ?? json['image_url']) as String?,
      actif: json['actif'] as bool? ?? true,
      disponible: json['disponible'] as bool? ?? true,
      ordreAffichage: (json['ordre_affichage'] as num?)?.toInt(),
      variantes: variantes,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'categorie_id': categorieId,
    'nom': nom,
    'description': description,
    'prix': prix,
    'photo_url': imageUrl, // Champ API correct
    'actif': actif,
    'disponible': disponible,
    'ordre_affichage': ordreAffichage,
  };

  String get prixFormate => '${prix.toStringAsFixed(0)} FCFA';
}

class VarianteProduitModel {
  final String id;
  final String produitId;
  final String nom;
  final double prixSupplementaire;
  final bool actif;

  const VarianteProduitModel({
    required this.id,
    required this.produitId,
    required this.nom,
    this.prixSupplementaire = 0,
    this.actif = true,
  });

  factory VarianteProduitModel.fromJson(Map<String, dynamic> json) {
    return VarianteProduitModel(
      id: json['id'] as String? ?? '',
      produitId: json['produit_id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      prixSupplementaire: ProduitModel._toDouble(json['prix_supplementaire']),
      actif: json['actif'] as bool? ?? true,
    );
  }
}

class CategorieModel {
  final String id;
  final String tenantId;
  final String nom;
  final String? description;
  final String? imageUrl;
  final bool actif;
  final int? ordreAffichage;
  final List<ProduitModel> produits;

  const CategorieModel({
    required this.id,
    required this.tenantId,
    required this.nom,
    this.description,
    this.imageUrl,
    this.actif = true,
    this.ordreAffichage,
    this.produits = const [],
  });

  factory CategorieModel.fromJson(Map<String, dynamic> json) {
    List<ProduitModel> produits = [];
    if (json['produits'] is List) {
      produits = (json['produits'] as List)
          .map((e) => ProduitModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return CategorieModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      actif: json['actif'] as bool? ?? true,
      ordreAffichage: (json['ordre_affichage'] as num?)?.toInt(),
      produits: produits,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'nom': nom,
    'description': description,
    'actif': actif,
    'ordre_affichage': ordreAffichage,
  };
}
