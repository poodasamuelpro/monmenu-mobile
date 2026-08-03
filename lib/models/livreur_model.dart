// lib/models/livreur_model.dart
// Livreur — Synchronisé avec l'API /dashboard/livreurs
// Champs API : id, nom, whatsapp_number, actif, created_at
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
  final String typeReduction; // 'pourcentage' | 'montant_fixe'
  final double valeur;
  final double? minCommande;
  final int? maxUtilisations;
  final int utilisationsActuelles;
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
    // CORRECTION R1 (Phase F) — noms de champs alignés sur l'API réelle :
    //   'type'         (pas 'type_reduction')
    //   'usage_max'    (pas 'max_utilisations')
    //   'usage_actuel' (pas 'utilisations_actuelles')
    //   'date_fin'     (pas 'date_expiration') — l'API n'envoie pas 'date_expiration'
    // Les anciens noms sont conservés en fallback pour compatibilité ascendante.
    return CodePromoModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      typeReduction: (json['type'] ?? json['type_reduction']) as String? ?? 'pourcentage',
      valeur: _toDouble(json['valeur']),
      minCommande: _toDoubleNullable(json['min_commande']),
      maxUtilisations: ((json['usage_max'] ?? json['max_utilisations']) as num?)?.toInt(),
      utilisationsActuelles: ((json['usage_actuel'] ?? json['utilisations_actuelles']) as num?)?.toInt() ?? 0,
      dateExpiration: (json['date_fin'] ?? json['date_expiration']) != null
          ? DateTime.tryParse((json['date_fin'] ?? json['date_expiration']) as String)
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
    'type_reduction': typeReduction,
    'valeur': valeur,
    'min_commande': minCommande,
    'max_utilisations': maxUtilisations,
    'date_expiration': dateExpiration?.toIso8601String(),
    'actif': actif,
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
      horaires: json['horaires'] as Map<String, dynamic>?,
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
