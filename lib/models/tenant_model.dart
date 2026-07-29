// lib/models/tenant_model.dart
import 'dart:convert';

class TenantModel {
  final String id;
  final String nom;
  final String slug;
  final String statut;
  final String? couleurPrimaire;
  final String? couleurSecondaire;
  final String? logoUrl;
  final String? banniereUrl;
  final String? whatsappNumber;
  final String? domainePerso;
  final String? planId;
  final DateTime? createdAt;
  final DateTime? essaiExpireLe;
  final Map<String, dynamic>? metadata;

  const TenantModel({
    required this.id,
    required this.nom,
    required this.slug,
    required this.statut,
    this.couleurPrimaire,
    this.couleurSecondaire,
    this.logoUrl,
    this.banniereUrl,
    this.whatsappNumber,
    this.domainePerso,
    this.planId,
    this.createdAt,
    this.essaiExpireLe,
    this.metadata,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      statut: json['statut'] as String? ?? 'essai',
      couleurPrimaire: json['couleur_primaire'] as String?,
      couleurSecondaire: json['couleur_secondaire'] as String?,
      logoUrl: json['logo_url'] as String?,
      banniereUrl: json['banniere_url'] as String?,
      whatsappNumber: json['whatsapp_number'] as String?,
      domainePerso: json['domaine_perso'] as String?,
      planId: json['plan_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      essaiExpireLe: json['essai_expire_le'] != null
          ? DateTime.tryParse(json['essai_expire_le'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'slug': slug,
    'statut': statut,
    'couleur_primaire': couleurPrimaire,
    'couleur_secondaire': couleurSecondaire,
    'logo_url': logoUrl,
    'banniere_url': banniereUrl,
    'whatsapp_number': whatsappNumber,
    'domaine_perso': domainePerso,
    'plan_id': planId,
    'created_at': createdAt?.toIso8601String(),
    'essai_expire_le': essaiExpireLe?.toIso8601String(),
    'metadata': metadata,
  };

  String toJsonString() => jsonEncode(toJson());

  factory TenantModel.fromJsonString(String s) =>
      TenantModel.fromJson(jsonDecode(s) as Map<String, dynamic>);

  bool get isActif => statut == 'actif';
  bool get isEssai => statut == 'essai';
  bool get isSuspendu => statut == 'suspendu';
  bool get isInactif => statut == 'inactif';
  bool get canAccess => statut == 'actif' || statut == 'essai';

  int? get joursEssaiRestants {
    if (essaiExpireLe == null) return null;
    final diff = essaiExpireLe!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  String get boutiqueUrl => 'https://monmenu.app/$slug';

  TenantModel copyWith({
    String? nom, String? slug, String? statut,
    String? couleurPrimaire, String? logoUrl,
  }) => TenantModel(
    id: id,
    nom: nom ?? this.nom,
    slug: slug ?? this.slug,
    statut: statut ?? this.statut,
    couleurPrimaire: couleurPrimaire ?? this.couleurPrimaire,
    couleurSecondaire: couleurSecondaire,
    logoUrl: logoUrl ?? this.logoUrl,
    banniereUrl: banniereUrl,
    whatsappNumber: whatsappNumber,
    domainePerso: domainePerso,
    planId: planId,
    createdAt: createdAt,
    essaiExpireLe: essaiExpireLe,
    metadata: metadata,
  );
}
