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

  /// Délai d'expiration de la confirmation (48h SLA après soumission).
  final DateTime? delaiConfirmationExpireLe;

  /// Heures restantes avant expiration du délai.
  final int? heuresRestantesConfirmation;

  /// Nom du plan depuis le champ plat 'plan_nom' (endpoint /historique)
  /// ou depuis l'objet imbriqué plan.nom (autres endpoints si disponible).
  final String? planNomPlat;

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
    this.planNomPlat,
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
      // Objet imbriqué plan (si présent sur d'autres endpoints)
      plan: json['plans'] != null
          ? PlanModel.fromJson(json['plans'] as Map<String, dynamic>)
          : json['plan'] != null
              ? PlanModel.fromJson(json['plan'] as Map<String, dynamic>)
              : null,
      // Champ plat 'plan_nom' retourné par /paiement/historique
      planNomPlat: json['plan_nom'] as String?,
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

  /// Nom du plan résolu : champ plat plan_nom (/historique) en priorité,
  /// puis plan.nom (objet imbriqué si disponible sur d'autres endpoints).
  String? get planNomEffectif => planNomPlat ?? plan?.nom;

  int? get joursRestants {
    if (finLe == null) return null;
    return finLe!.difference(DateTime.now()).inDays;
  }

  /// Heures avant expiration du délai de confirmation admin (48h SLA).
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
// API retourne JSON PLAT — aucun objet imbriqué 'tenant' ou 'plan'
// Champs directs: id, nom, slug, logo_url, banniere_url, couleur_primaire,
//   whatsapp_number, statut, plan_nom, pdv_id, pdv_nom, pdv_adresse,
//   horaires, boutique_url, total_commandes, mode_acces
class ProfilModel {
  final String id;
  final String nom;
  final String slug;
  final String statut;
  final String? couleurPrimaire;
  final String? couleurSecondaire;
  final String? logoUrl;
  final String? banniereUrl;
  final String? whatsappNumber;
  final String? domainPerso;
  // M1 — email du restaurant (exposé par GET /dashboard/profil via ...tenantFinal)
  final String? email;
  final String? planNom;
  // M4 — plan_id exposé par GET /dashboard/profil (spread ...tenantFinal,
  // déjà présent à web HEAD 98223df) → surlignage fiable du plan actuel
  final String? planId;
  final int commandesIncluses;
  final double? prixMensuel;
  final String? pdvId;
  final String? pdvNom;
  final String? pdvAdresse;
  final dynamic horaires;
  final String? boutiqueUrl;
  final int totalCommandes;
  final String? modeAcces;
  final DateTime? createdAt;

  const ProfilModel({
    required this.id,
    required this.nom,
    required this.slug,
    required this.statut,
    this.couleurPrimaire,
    this.couleurSecondaire,
    this.logoUrl,
    this.banniereUrl,
    this.whatsappNumber,
    this.domainPerso,
    this.email,
    this.planNom,
    this.planId,
    this.commandesIncluses = 0,
    this.prixMensuel,
    this.pdvId,
    this.pdvNom,
    this.pdvAdresse,
    this.horaires,
    this.boutiqueUrl,
    this.totalCommandes = 0,
    this.modeAcces,
    this.createdAt,
  });

  factory ProfilModel.fromJson(Map<String, dynamic> json) {
    return ProfilModel(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      statut: json['statut'] as String? ?? 'essai',
      couleurPrimaire: json['couleur_primaire'] as String?,
      couleurSecondaire: json['couleur_secondaire'] as String?,
      logoUrl: json['logo_url'] as String?,
      banniereUrl: json['banniere_url'] as String?,
      whatsappNumber: json['whatsapp_number'] as String?,
      domainPerso: json['domaine_perso'] as String?,
      email: json['email'] as String?,
      planNom: json['plan_nom'] as String?,
      planId: json['plan_id'] as String?,
      commandesIncluses: (json['commandes_incluses'] as num?)?.toInt() ?? 0,
      prixMensuel: _toDoubleNullable(json['prix_mensuel']),
      pdvId: json['pdv_id'] as String?,
      pdvNom: json['pdv_nom'] as String?,
      pdvAdresse: json['pdv_adresse'] as String?,
      horaires: json['horaires'],
      boutiqueUrl: json['boutique_url'] as String?,
      totalCommandes: (json['total_commandes'] as num?)?.toInt() ?? 0,
      modeAcces: json['mode_acces'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  static double? _toDoubleNullable(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  bool get isEssai => statut == 'essai';
  bool get isActif => statut == 'actif';
}

// TenantInfo conservé pour compatibilité avec tenant_model.dart et auth_service.dart
// mais n'est plus utilisé par ProfilModel (qui lit JSON plat depuis /profil)
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

class StatsModel {
  // Champs API /dashboard/stats (noms corrects):
  //   today, ca_today, month, ca_month, taux_livraison, taux_annulation,
  //   nb_produits, statuts (map), labels (list strings), values (list int),
  //   ca_values (list double)
  final int commandesAujourdhui;    // 'today'
  final double caAujourdhui;         // 'ca_today'
  final int commandesMois;           // 'month'
  final double caMois;               // 'ca_month'
  final int tauxLivraison;           // 'taux_livraison'
  final int tauxAnnulation;          // 'taux_annulation'
  final int nbProduits;              // 'nb_produits'
  final Map<String, dynamic> statuts; // 'statuts'
  final List<String> labels;         // 'labels' (ex: ["06-01","06-02",...])
  final List<int> values;            // 'values' (nb commandes/jour)
  final List<double> caValues;       // 'ca_values' (CA/jour)

  // Propriétés calculées pour compatibilité avec l'UI existante.
  // Contrat web GET /dashboard/stats (api-dashboard.ts) :
  // statuts = { livree, annulee } uniquement — pas de champ 'en_attente'.
  int get commandesLivrees => (statuts['livree'] as num?)?.toInt() ?? 0;
  int get commandesAnnulees => (statuts['annulee'] as num?)?.toInt() ?? 0;
  int get totalCommandes => (statuts.values.fold<int>(0, (sum, v) {
    return sum + ((v as num?)?.toInt() ?? 0);
  }));
  double get chiffreAffaires => caValues.fold(0.0, (a, b) => a + b);

  /// [P5] Commandes en cours (ni livrées ni annulées) : total serveur exact
  /// (GET /dashboard/commandes → total) − livree − annulee, borné ≥ 0.
  /// Remplace commandesPendantes (statuts['en_attente'] : champ inexistant
  /// dans le contrat web → affichait toujours 0).
  int commandesEnCours(int totalServeur) {
    final restant = totalServeur - commandesLivrees - commandesAnnulees;
    return restant < 0 ? 0 : restant;
  }

  // Conversion en StatJournaliere pour les graphiques
  List<StatJournaliere> get statsJournalieres {
    final result = <StatJournaliere>[];
    final now = DateTime.now();
    final len = labels.length;
    for (int i = 0; i < len; i++) {
      final labelStr = labels[i]; // format "MM-DD"
      DateTime date;
      try {
        final parts = labelStr.split('-');
        if (parts.length == 2) {
          date = DateTime(now.year, int.parse(parts[0]), int.parse(parts[1]));
        } else {
          date = DateTime.tryParse(labelStr) ?? now;
        }
      } catch (_) {
        date = now;
      }
      result.add(StatJournaliere(
        date: date,
        nbCommandes: i < values.length ? values[i] : 0,
        chiffreAffaires: i < caValues.length ? caValues[i] : 0.0,
      ));
    }
    return result;
  }

  const StatsModel({
    this.commandesAujourdhui = 0,
    this.caAujourdhui = 0,
    this.commandesMois = 0,
    this.caMois = 0,
    this.tauxLivraison = 0,
    this.tauxAnnulation = 0,
    this.nbProduits = 0,
    this.statuts = const {},
    this.labels = const [],
    this.values = const [],
    this.caValues = const [],
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    final labelsList = (json['labels'] as List?)
        ?.map((e) => e.toString())
        .toList() ?? <String>[];
    final valuesList = (json['values'] as List?)
        ?.map((e) => (e as num?)?.toInt() ?? 0)
        .toList() ?? <int>[];
    final caValuesList = (json['ca_values'] as List?)
        ?.map((e) => _toDouble(e))
        .toList() ?? <double>[];
    final statutsMap = json['statuts'] is Map
        ? Map<String, dynamic>.from(json['statuts'] as Map)
        : <String, dynamic>{};

    return StatsModel(
      commandesAujourdhui: (json['today'] as num?)?.toInt() ?? 0,
      caAujourdhui: _toDouble(json['ca_today']),
      commandesMois: (json['month'] as num?)?.toInt() ?? 0,
      caMois: _toDouble(json['ca_month']),
      tauxLivraison: (json['taux_livraison'] as num?)?.toInt() ?? 0,
      tauxAnnulation: (json['taux_annulation'] as num?)?.toInt() ?? 0,
      nbProduits: (json['nb_produits'] as num?)?.toInt() ?? 0,
      statuts: statutsMap,
      labels: labelsList,
      values: valuesList,
      caValues: caValuesList,
    );
  }

  /// M8 — Parse le contrat RÉEL de GET /dashboard/stats-journalieres
  /// (api-dashboard.ts l.2115-2145) :
  /// { stats: [{date, nb_commandes, nb_commandes_livrees,
  ///            nb_commandes_annulees, chiffre_affaires,
  ///            frais_livraison_total, top_produits}],
  ///   totaux: {nb_commandes, chiffre_affaires, nb_jours_actifs,
  ///            moyenne_journaliere},
  ///   periode_jours }
  /// `stats` est trié DESCENDANT par date côté web → remis en ASC ici pour
  /// que les graphiques (labels/values/caValues) soient chronologiques.
  factory StatsModel.fromStatsJournalieres(Map<String, dynamic> json) {
    final rawStats = (json['stats'] as List?) ?? const [];
    final items = rawStats
        .whereType<Map>()
        .map((e) => StatJournaliere.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date)); // ASC chronologique

    final labels = items
        .map((s) =>
            '${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}')
        .toList();
    final values = items.map((s) => s.nbCommandes).toList();
    final caValues = items.map((s) => s.chiffreAffaires).toList();

    final totaux = json['totaux'] is Map
        ? Map<String, dynamic>.from(json['totaux'] as Map)
        : <String, dynamic>{};

    return StatsModel(
      // Totaux de la période (nb_commandes / chiffre_affaires)
      commandesMois: (totaux['nb_commandes'] as num?)?.toInt() ?? 0,
      caMois: _toDouble(totaux['chiffre_affaires']),
      labels: labels,
      values: values,
      caValues: caValues,
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
