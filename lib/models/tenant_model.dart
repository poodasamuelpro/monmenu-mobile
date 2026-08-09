// lib/models/tenant_model.dart
import 'dart:convert';

/// Objet imbriqué représentant un paiement en attente de confirmation admin.
/// Champs tirés de la réponse GET /paiement/statut.
class PaiementEnAttenteModel {
  /// Statut de l'abonnement, ici toujours 'en_attente_confirmation'.
  final String statut;

  /// Date de soumission de la preuve de paiement.
  final DateTime soumisLe;

  /// Délai d'expiration de la confirmation admin (48h SLA après soumission).
  final DateTime? delaiConfirmationExpireLe;

  /// Nombre d'heures restantes avant expiration du délai de confirmation.
  final int? heuresRestantes;

  /// Message explicatif envoyé par le serveur.
  final String? messageConfirmation;

  /// ID de l'abonnement en cours de traitement.
  final String? abonnementId;

  const PaiementEnAttenteModel({
    required this.statut,
    required this.soumisLe,
    this.delaiConfirmationExpireLe,
    this.heuresRestantes,
    this.messageConfirmation,
    this.abonnementId,
  });

  factory PaiementEnAttenteModel.fromJson(Map<String, dynamic> json) {
    return PaiementEnAttenteModel(
      statut: json['statut'] as String? ?? 'en_attente_confirmation',
      soumisLe: json['soumis_le'] != null
          ? DateTime.tryParse(json['soumis_le'] as String) ?? DateTime.now()
          : DateTime.now(),
      delaiConfirmationExpireLe: json['delai_confirmation_expire_le'] != null
          ? DateTime.tryParse(json['delai_confirmation_expire_le'] as String)
          : null,
      heuresRestantes: (json['heures_restantes_confirmation'] as num?)?.toInt(),
      messageConfirmation: json['message_confirmation'] as String?,
      abonnementId: json['id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'statut': statut,
    'soumis_le': soumisLe.toIso8601String(),
    'delai_confirmation_expire_le': delaiConfirmationExpireLe?.toIso8601String(),
    'heures_restantes_confirmation': heuresRestantes,
    'message_confirmation': messageConfirmation,
    'id': abonnementId,
  };

  /// Heures restantes calculées localement si le serveur ne les fournit pas.
  int get heuresRestantesCalculees {
    if (heuresRestantes != null) return heuresRestantes!;
    if (delaiConfirmationExpireLe == null) return 0;
    final diff = delaiConfirmationExpireLe!.difference(DateTime.now()).inHours;
    return diff < 0 ? 0 : diff;
  }

  bool get estExpire {
    if (delaiConfirmationExpireLe == null) return false;
    return DateTime.now().isAfter(delaiConfirmationExpireLe!);
  }
}

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

  /// Référence de paiement active du tenant (ex: "MNMENU-2024-XXXXX").
  final String? referencePaiement;

  /// Objet présent lorsque le tenant a un abonnement en attente de confirmation.
  final PaiementEnAttenteModel? paiementEnAttente;

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
    this.referencePaiement,
    this.paiementEnAttente,
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
      referencePaiement: json['reference_paiement'] as String?,
      paiementEnAttente: json['paiement_en_attente'] != null
          ? PaiementEnAttenteModel.fromJson(
              json['paiement_en_attente'] as Map<String, dynamic>)
          : null,
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
    'reference_paiement': referencePaiement,
    'paiement_en_attente': paiementEnAttente?.toJson(),
  };

  String toJsonString() => jsonEncode(toJson());

  factory TenantModel.fromJsonString(String s) =>
      TenantModel.fromJson(jsonDecode(s) as Map<String, dynamic>);

  bool get isActif => statut == 'actif';
  bool get isEssai => statut == 'essai';
  bool get isSuspendu => statut == 'suspendu';
  bool get isInactif => statut == 'inactif';
  bool get isEnAttenteConfirmation => statut == 'en_attente_confirmation';

  /// SEC-04 : le statut 'en_attente_confirmation' donne accès à l'app
  /// (le restaurant peut continuer à opérer pendant les 48h SLA de traitement).
  bool get canAccess =>
      statut == 'actif' ||
      statut == 'essai' ||
      statut == 'en_attente_confirmation';

  int? get joursEssaiRestants {
    if (essaiExpireLe == null) return null;
    final diff = essaiExpireLe!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Vrai si l'essai expire dans moins de 3 jours.
  bool get essaiExpireBientot {
    final jours = joursEssaiRestants;
    return isEssai && jours != null && jours <= 3;
  }

  String get boutiqueUrl => 'https://monmenu.app/$slug';

  TenantModel copyWith({
    String? nom,
    String? slug,
    String? statut,
    String? couleurPrimaire,
    String? logoUrl,
    String? referencePaiement,
    PaiementEnAttenteModel? paiementEnAttente,
  }) =>
      TenantModel(
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
        referencePaiement: referencePaiement ?? this.referencePaiement,
        paiementEnAttente: paiementEnAttente ?? this.paiementEnAttente,
      );
}
