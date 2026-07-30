// lib/models/plan_model.dart
class PlanModel {
  final String id;
  final String nom;
  final String? description;
  final double prixMensuel;
  final double prixAnnuel;
  final String devise;
  final int commandesIncluses;
  final double fraisParCommande;
  final int limitePdv;
  final Map<String, dynamic> fonctionnalites;
  final bool actif;
  final int ordreAffichage;

  const PlanModel({
    required this.id,
    required this.nom,
    required this.prixMensuel,
    required this.prixAnnuel,
    this.description,
    this.devise = 'XOF',
    this.commandesIncluses = 100,
    this.fraisParCommande = 0,
    this.limitePdv = 1,
    this.fonctionnalites = const {},
    this.actif = true,
    this.ordreAffichage = 0,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> fonctionnalites = {};
    if (json['fonctionnalites'] is Map) {
      fonctionnalites = Map<String, dynamic>.from(json['fonctionnalites'] as Map);
    }
    return PlanModel(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      description: json['description'] as String?,
      prixMensuel: _toDouble(json['prix_mensuel']),
      prixAnnuel: _toDouble(json['prix_annuel']),
      devise: json['devise'] as String? ?? 'XOF',
      commandesIncluses: (json['commandes_incluses'] as num?)?.toInt() ?? 100,
      fraisParCommande: _toDouble(json['frais_par_commande']),
      limitePdv: (json['limite_pdv'] as num?)?.toInt() ?? 1,
      fonctionnalites: fonctionnalites,
      actif: json['actif'] as bool? ?? true,
      ordreAffichage: (json['ordre_affichage'] as num?)?.toInt() ?? 0,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  bool get isGratuit => prixMensuel == 0;

  String get prixMensuelFormate =>
      isGratuit ? 'Gratuit' : '${prixMensuel.toStringAsFixed(0)} $devise/mois';

  String get prixAnnuelFormate =>
      isGratuit ? 'Gratuit' : '${prixAnnuel.toStringAsFixed(0)} $devise/an';

  bool hasFeature(String feature) =>
      fonctionnalites[feature] == true;

  List<String> get featuresActives =>
      fonctionnalites.entries
          .where((e) => e.value == true)
          .map((e) => e.key)
          .toList();
}

class AbonnementModel {
  final String id;
  final String tenantId;
  final String planId;
  final String statut;
  final String periodicite;
  final DateTime? debutLe;
  final DateTime? finLe;
  final bool autoRenouvellement;
  final PlanModel? plan;

  /// Montant payé (depuis l'historique).
  final double? montantPaye;

  /// Devise (XOF, EUR, etc.).
  final String? devise;

  /// Méthode de paiement utilisée (mobile_money, virement, carte).
  final String? methodePaiement;

  /// URL de la preuve de paiement soumise.
  final String? preuveUrl;

  /// Référence unique de paiement (ex: "MNMENU-2024-XXXXX").
  final String? referencePaiement;

  /// Nom de l'admin qui a confirmé le paiement.
  final String? confirmeParNom;

  /// Date de confirmation par l'admin.
  final DateTime? confirmeLe;

  /// Date de soumission de la preuve par le tenant.
  final DateTime? soumisLe;

  /// Date de rejet (si rejeté par l'admin).
  final DateTime? rejeteLe;

  /// Motif du rejet.
  final String? motifRejet;

  /// Délai d'expiration de la confirmation (38h après soumission).
  final DateTime? delaiConfirmationExpireLe;

  /// Heures restantes avant expiration du délai.
  final int? heuresRestantesConfirmation;

  const AbonnementModel({
    required this.id,
    required this.tenantId,
    required this.planId,
    required this.statut,
    this.periodicite = 'mensuel',
    this.debutLe,
    this.finLe,
    this.autoRenouvellement = true,
    this.plan,
    this.montantPaye,
    this.devise,
    this.methodePaiement,
    this.preuveUrl,
    this.referencePaiement,
    this.confirmeParNom,
    this.confirmeLe,
    this.soumisLe,
    this.rejeteLe,
    this.motifRejet,
    this.delaiConfirmationExpireLe,
    this.heuresRestantesConfirmation,
  });

  factory AbonnementModel.fromJson(Map<String, dynamic> json) {
    return AbonnementModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      planId: json['plan_id'] as String? ?? '',
      statut: json['statut'] as String? ?? 'actif',
      periodicite: json['periodicite'] as String? ?? 'mensuel',
      debutLe: _parseDate(json['debut_le'] ?? json['date_debut']),
      finLe: _parseDate(json['fin_le'] ?? json['date_fin']),
      autoRenouvellement: json['auto_renouvellement'] as bool? ?? true,
      plan: json['plans'] != null
          ? PlanModel.fromJson(json['plans'] as Map<String, dynamic>)
          : json['plan'] != null
              ? PlanModel.fromJson(json['plan'] as Map<String, dynamic>)
              : null,
      montantPaye: _toDouble(json['montant_paye']),
      devise: json['devise'] as String?,
      methodePaiement: json['methode_paiement'] as String?,
      preuveUrl: json['preuve_url'] as String?,
      referencePaiement: json['reference_paiement'] as String?,
      confirmeParNom: json['confirme_par_nom'] as String?,
      confirmeLe: _parseDate(json['confirme_le']),
      soumisLe: _parseDate(json['soumis_le']),
      rejeteLe: _parseDate(json['rejete_le']),
      motifRejet: json['motif_rejet'] as String?,
      delaiConfirmationExpireLe:
          _parseDate(json['delai_confirmation_expire_le']),
      heuresRestantesConfirmation:
          (json['heures_restantes_confirmation'] as num?)?.toInt(),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v as String);
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  bool get isActif => statut == 'actif';
  bool get isEnAttente => statut == 'en_attente_confirmation';
  bool get isRejete => statut == 'rejete';

  int? get joursRestants {
    if (finLe == null) return null;
    return finLe!.difference(DateTime.now()).inDays;
  }

  /// Heures avant expiration du délai de confirmation admin (38h).
  int get heuresAvantExpirationAdmin {
    if (heuresRestantesConfirmation != null) {
      return heuresRestantesConfirmation!;
    }
    if (delaiConfirmationExpireLe == null) return 0;
    final diff =
        delaiConfirmationExpireLe!.difference(DateTime.now()).inHours;
    return diff < 0 ? 0 : diff;
  }

  String get statutLibelle {
    switch (statut) {
      case 'actif': return 'Actif';
      case 'en_attente_confirmation': return 'En attente de confirmation';
      case 'rejete': return 'Rejeté';
      case 'expire': return 'Expiré';
      case 'inactif': return 'Inactif';
      default: return statut;
    }
  }
}

// Profil complet (endpoint /dashboard/profil)
class ProfilModel {
  final TenantInfo tenant;
  final PlanModel? plan;
  final int totalCommandes;
  final List<PointDeVenteInfo> pointsDeVente;

  const ProfilModel({
    required this.tenant,
    this.plan,
    this.totalCommandes = 0,
    this.pointsDeVente = const [],
  });

  factory ProfilModel.fromJson(Map<String, dynamic> json) {
    return ProfilModel(
      tenant: TenantInfo.fromJson(json['tenant'] as Map<String, dynamic>? ?? {}),
      plan: json['plan'] != null
          ? PlanModel.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
      totalCommandes: (json['total_commandes'] as num?)?.toInt() ?? 0,
      pointsDeVente: json['points_de_vente'] is List
          ? (json['points_de_vente'] as List)
              .map((e) => PointDeVenteInfo.fromJson(e as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

class TenantInfo {
  final String id;
  final String nom;
  final String slug;
  final String statut;
  final String? couleurPrimaire;
  final String? logoUrl;
  final String? whatsappNumber;
  final DateTime? essaiExpireLe;

  const TenantInfo({
    required this.id,
    required this.nom,
    required this.slug,
    required this.statut,
    this.couleurPrimaire,
    this.logoUrl,
    this.whatsappNumber,
    this.essaiExpireLe,
  });

  factory TenantInfo.fromJson(Map<String, dynamic> json) => TenantInfo(
    id: json['id'] as String? ?? '',
    nom: json['nom'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    statut: json['statut'] as String? ?? 'essai',
    couleurPrimaire: json['couleur_primaire'] as String?,
    logoUrl: json['logo_url'] as String?,
    whatsappNumber: json['whatsapp_number'] as String?,
    essaiExpireLe: json['essai_expire_le'] != null
        ? DateTime.tryParse(json['essai_expire_le'] as String)
        : null,
  );
}

class PointDeVenteInfo {
  final String id;
  final String nom;
  final String adresse;
  final bool actif;

  const PointDeVenteInfo({
    required this.id,
    required this.nom,
    required this.adresse,
    this.actif = true,
  });

  factory PointDeVenteInfo.fromJson(Map<String, dynamic> json) => PointDeVenteInfo(
    id: json['id'] as String? ?? '',
    nom: json['nom'] as String? ?? '',
    adresse: json['adresse'] as String? ?? '',
    actif: json['actif'] as bool? ?? true,
  );
}

class StatsModel {
  final int totalCommandes;
  final double chiffreAffaires;
  final int commandesAujourdhui;
  final double caAujourdhui;
  final int commandesPendantes;
  final List<StatJournaliere> statsJournalieres;

  const StatsModel({
    this.totalCommandes = 0,
    this.chiffreAffaires = 0,
    this.commandesAujourdhui = 0,
    this.caAujourdhui = 0,
    this.commandesPendantes = 0,
    this.statsJournalieres = const [],
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    List<StatJournaliere> stats = [];
    if (json['stats_journalieres'] is List) {
      stats = (json['stats_journalieres'] as List)
          .map((e) => StatJournaliere.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return StatsModel(
      totalCommandes: (json['total_commandes'] as num?)?.toInt() ?? 0,
      chiffreAffaires: _toDouble(json['chiffre_affaires']),
      commandesAujourdhui: (json['commandes_aujourd_hui'] as num?)?.toInt() ?? 0,
      caAujourdhui: _toDouble(json['ca_aujourd_hui']),
      commandesPendantes: (json['commandes_pendantes'] as num?)?.toInt() ?? 0,
      statsJournalieres: stats,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class StatJournaliere {
  final DateTime date;
  final int nbCommandes;
  final double chiffreAffaires;

  const StatJournaliere({
    required this.date,
    this.nbCommandes = 0,
    this.chiffreAffaires = 0,
  });

  factory StatJournaliere.fromJson(Map<String, dynamic> json) {
    return StatJournaliere(
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      nbCommandes: (json['nb_commandes'] as num?)?.toInt() ?? 0,
      chiffreAffaires: StatsModel._toDouble(json['chiffre_affaires']),
    );
  }
}
