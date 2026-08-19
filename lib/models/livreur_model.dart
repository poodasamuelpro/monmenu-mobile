// lib/models/livreur_model.dart
// Livreur — Synchronisé avec l'API /dashboard/livreurs
// Champs API : id, nom, whatsapp_number, actif, created_at
import 'dart:convert';

class LivreurModel {
  final String id;
  final String tenantId;
  final String nom;
  final String? whatsappNumber; // Champ API : whatsapp_number
  final bool actif;
  final int commandesEnCours;
  final int totalCommandes;
  final DateTime? createdAt;

  const LivreurModel({
    required this.id,
    required this.tenantId,
    required this.nom,
    this.whatsappNumber,
    this.actif = true,
    this.commandesEnCours = 0,
    this.totalCommandes = 0,
    this.createdAt,
  });

  factory LivreurModel.fromJson(Map<String, dynamic> json) {
    return LivreurModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      whatsappNumber: json['whatsapp_number'] as String?,
      actif: json['actif'] as bool? ?? true,
      commandesEnCours: (json['commandes_en_cours'] as num?)?.toInt() ?? 0,
      totalCommandes: (json['total_commandes'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'nom': nom,
    'whatsapp_number': whatsappNumber,
    'actif': actif,
  };

  LivreurModel copyWith({String? nom, String? whatsappNumber, bool? actif}) =>
      LivreurModel(
        id: id,
        tenantId: tenantId,
        nom: nom ?? this.nom,
        whatsappNumber: whatsappNumber ?? this.whatsappNumber,
        actif: actif ?? this.actif,
        commandesEnCours: commandesEnCours,
        totalCommandes: totalCommandes,
        createdAt: createdAt,
      );
}

class CodePromoModel {
  final String id;
  final String tenantId;
  final String code;
  /// Type de réduction — champ API : 'type' (valeurs: 'pourcentage' | 'montant_fixe')
  final String typeReduction;
  final double valeur;
  /// Pas supporté par le backend — toujours null côté API
  final double? minCommande;
  /// Nombre max d'utilisations — champ API : 'usage_max'
  final int? maxUtilisations;
  /// Utilisations actuelles — champ API : 'usage_actuel'
  final int utilisationsActuelles;
  /// Date de fin de validité — champ API : 'date_fin'
  final DateTime? dateExpiration;
  final bool actif;
  final DateTime? createdAt;

  const CodePromoModel({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.typeReduction,
    required this.valeur,
    this.minCommande,
    this.maxUtilisations,
    this.utilisationsActuelles = 0,
    this.dateExpiration,
    this.actif = true,
    this.createdAt,
  });

  factory CodePromoModel.fromJson(Map<String, dynamic> json) {
    return CodePromoModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      // Backend retourne 'type' (pas 'type_reduction')
      typeReduction: json['type'] as String? ?? 'pourcentage',
      valeur: _toDouble(json['valeur']),
      // 'min_commande' n'existe pas côté backend — toujours null
      minCommande: null,
      // Backend retourne 'usage_max' (pas 'max_utilisations')
      maxUtilisations: (json['usage_max'] as num?)?.toInt(),
      // Backend retourne 'usage_actuel' (pas 'utilisations_actuelles')
      utilisationsActuelles: (json['usage_actuel'] as num?)?.toInt() ?? 0,
      // Backend retourne 'date_fin' (pas 'date_expiration')
      dateExpiration: json['date_fin'] != null
          ? DateTime.tryParse(json['date_fin'] as String)
          : null,
      actif: json['actif'] as bool? ?? true,
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

  static double? _toDoubleNullable(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    // Backend attend 'type' (pas 'type_reduction')
    'type': typeReduction,
    'valeur': valeur,
    // Backend attend 'usage_max' (pas 'max_utilisations')
    if (maxUtilisations != null) 'usage_max': maxUtilisations,
    // Backend attend 'date_fin' (pas 'date_expiration')
    if (dateExpiration != null) 'date_fin': dateExpiration!.toIso8601String(),
    'actif': actif,
    // 'min_commande' n'est pas supporté côté backend — ne pas l'envoyer
  };

  String get reductionFormatee => typeReduction == 'pourcentage'
      ? '${valeur.toStringAsFixed(0)}%'
      : '${valeur.toStringAsFixed(0)} FCFA';

  bool get isExpire =>
      dateExpiration != null && dateExpiration!.isBefore(DateTime.now());

  bool get isEpuise =>
      maxUtilisations != null && utilisationsActuelles >= maxUtilisations!;
}

class PointDeVenteModel {
  final String id;
  final String tenantId;
  final String nom;
  final String adresse;
  final String? telephone;
  final String? email;
  final String? slogan;
  final String? slug;
  final double? latitude;
  final double? longitude;
  final double? tarifLivraisonBase;
  final double? tarifParKm;
  final bool actif;
  final Map<String, dynamic>? horaires;
  final DateTime? createdAt;

  const PointDeVenteModel({
    required this.id,
    required this.tenantId,
    required this.nom,
    required this.adresse,
    this.telephone,
    this.email,
    this.slogan,
    this.slug,
    this.latitude,
    this.longitude,
    this.tarifLivraisonBase,
    this.tarifParKm,
    this.actif = true,
    this.horaires,
    this.createdAt,
  });

  factory PointDeVenteModel.fromJson(Map<String, dynamic> json) {
    return PointDeVenteModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      adresse: json['adresse'] as String? ?? '',
      telephone: json['telephone'] as String?,
      email: json['email'] as String?,
      slogan: json['slogan'] as String?,
      slug: json['slug'] as String?,
      latitude: CodePromoModel._toDoubleNullable(json['latitude']),
      longitude: CodePromoModel._toDoubleNullable(json['longitude']),
      tarifLivraisonBase: CodePromoModel._toDoubleNullable(json['tarif_livraison_base']),
      tarifParKm: CodePromoModel._toDoubleNullable(json['tarif_par_km']),
      actif: json['actif'] as bool? ?? true,
      horaires: _parseHoraires(json['horaires']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'nom': nom,
    'adresse': adresse,
    if (telephone != null) 'telephone': telephone,
    if (email != null) 'email': email,
    if (slogan != null) 'slogan': slogan,
    'latitude': latitude,
    'longitude': longitude,
    'tarif_livraison_base': tarifLivraisonBase,
    'tarif_par_km': tarifParKm,
    'actif': actif,
    'horaires': horaires,
  };
}

/// FIX — parsing robuste des horaires d'un PDV.
/// Supabase renvoie la colonne jsonb soit en objet, soit en chaîne JSON.
/// Le cast direct `as Map<String, dynamic>?` faisait planter l'écran
/// Restaurant (TypeCastException après le succès de la réponse, sans
/// try/catch → spinner infini).
Map<String, dynamic>? _parseHoraires(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? decoded.map((k, v) => MapEntry(k.toString(), v)) : null;
    } catch (_) {
      return null;
    }
  }
  return null;
}
