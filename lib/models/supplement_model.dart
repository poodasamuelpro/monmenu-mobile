// lib/models/supplement_model.dart
// Modèle Supplément — parité stricte avec le web :
//   - src/routes/api-supplements.ts (contrat dashboard CRUD)
//   - docs/API-SUPPLEMENTS.md (spec Dart SupplementGeneral)
//
// Contrat GET /dashboard/supplements :
//   { supplements: [{ id, nom, prix, photo_url, photo_r2_key,
//                     actif, ordre_affichage, created_at, updated_at }] }
//
// Règles web à respecter côté client :
//   - nom : 1 à 100 caractères
//   - prix : 0 à 999 999 (jamais recalculé côté client)
//   - max 10 supplement_ids par ligne de commande (côté commande publique)
class SupplementModel {
  final String id;
  final String nom;
  final double prix;
  final String? photoUrl;
  final String? photoR2Key;
  final bool actif;
  final int ordreAffichage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SupplementModel({
    required this.id,
    required this.nom,
    required this.prix,
    this.photoUrl,
    this.photoR2Key,
    this.actif = true,
    this.ordreAffichage = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory SupplementModel.fromJson(Map<String, dynamic> json) {
    return SupplementModel(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      prix: _toDouble(json['prix']),
      photoUrl: json['photo_url'] as String?,
      photoR2Key: json['photo_r2_key'] as String?,
      // Le backend peut renvoyer bool ou 0/1 (SQLite/D1)
      actif: _toBool(json['actif'], defaut: true),
      ordreAffichage: (json['ordre_affichage'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'prix': prix,
        'photo_url': photoUrl,
        'photo_r2_key': photoR2Key,
        'actif': actif,
        'ordre_affichage': ordreAffichage,
      };

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static bool _toBool(dynamic v, {bool defaut = false}) {
    if (v == null) return defaut;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return defaut;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  SupplementModel copyWith({
    String? nom,
    double? prix,
    String? photoUrl,
    bool? actif,
    int? ordreAffichage,
  }) =>
      SupplementModel(
        id: id,
        nom: nom ?? this.nom,
        prix: prix ?? this.prix,
        photoUrl: photoUrl ?? this.photoUrl,
        photoR2Key: photoR2Key,
        actif: actif ?? this.actif,
        ordreAffichage: ordreAffichage ?? this.ordreAffichage,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// Réponse GET /dashboard/supplements/limite → { actif, limite, utilises }
class SupplementLimiteModel {
  final bool actif;
  final int limite;
  final int utilises;

  const SupplementLimiteModel({
    this.actif = true,
    this.limite = 0,
    this.utilises = 0,
  });

  factory SupplementLimiteModel.fromJson(Map<String, dynamic> json) {
    return SupplementLimiteModel(
      actif: SupplementModel._toBool(json['actif'], defaut: true),
      limite: (json['limite'] as num?)?.toInt() ?? 0,
      utilises: (json['utilises'] as num?)?.toInt() ?? 0,
    );
  }

  /// Limite atteinte : création désactivée (0 = illimité côté web).
  bool get limiteAtteinte => limite > 0 && utilises >= limite;
}
