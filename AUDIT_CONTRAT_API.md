# AUDIT_CONTRAT_API.md — MonMenu Manager
## Audit croisé Mobile Flutter ↔ Backend Hono.js (Cloudflare Workers)

**Date d'audit** : Phase E (session courante)  
**Commit de référence backend** : `f1060ea` (monmenu-public)  
**Commit de référence Flutter avant corrections Phase E** : `815a8dd`  
**Source de vérité** : `src/routes/api-dashboard.ts`, `api-paiement.ts`, `api-plans.ts`  
**Méthodologie** : double passe — backend → Flutter, puis Flutter → backend  

---

## Légende des statuts

| Statut | Signification |
|--------|--------------|
| ✅ OK | Champ correctement mappé, types cohérents |
| ⚠️ DÉFAUT SÛUR | Champ absent ou mal nommé côté Flutter, mais valeur par défaut sûre (pas de crash) |
| ❌ BUG | Mismatch causant crash, spinner infini ou donnée silencieusement perdue |
| 🔧 CORRIGÉ (Phase D) | Bug identifié et corrigé en Phase D (commit `815a8dd`) |
| 🔧 CORRIGÉ (Phase E) | Bug identifié et corrigé en Phase E (session courante) |
| ℹ️ INFO | Information structurelle, pas un bug |
| 🚫 NON ENVOYÉ | Champ lu côté Flutter mais non envoyé par le backend |

---

## 1. `GET /api/v1/dashboard/stats`

**Backend** (`api-dashboard.ts` l.408–507) → `StatsModel.fromJson` (`plan_model.dart`)

| Champ JSON backend | Type | Utilisé web (dashboard.js) | Attendu Dart (StatsModel) | Statut |
|--------------------|------|---------------------------|--------------------------|--------|
| `today` | `int` | ✓ | `json['today']` | ✅ OK |
| `ca_today` | `num` | ✓ | `json['ca_today']` | ✅ OK |
| `month` | `int` | ✓ | `json['month']` | ✅ OK |
| `ca_month` | `num` | ✓ | `json['ca_month']` | ✅ OK |
| `taux_livraison` | `int` (0-100) | ✓ | `json['taux_livraison']` | ✅ OK |
| `taux_annulation` | `int` (0-100) | ✓ | `json['taux_annulation']` | ✅ OK |
| `nb_produits` | `int` | ✓ | `json['nb_produits']` | ✅ OK |
| `statuts` | `Record<string,int>` | ✓ | `json['statuts'] as Map` | ✅ OK |
| `labels` | `string[]` (format MM-DD) | ✓ | `json['labels'] as List` | ✅ OK |
| `values` | `int[]` | ✓ | `json['values'] as List` | ✅ OK |
| `ca_values` | `num[]` | ✓ | `json['ca_values'] as List` | ✅ OK |

**Getters calculés côté Dart (PAS des champs JSON)** — confirmés non bugs :
- `totalCommandes` = somme des valeurs de `statuts`
- `commandesPendantes` = `statuts['en_attente'] ?? 0`
- `chiffreAffaires` = `caMonth`

**Résultat** : ✅ Aucun bug — les noms de champs correspondent exactement au backend.

---

## 2. `GET /api/v1/dashboard/profil`

**Backend** (`api-dashboard.ts` l.1118–1200) → `ProfilModel.fromJson` (`plan_model.dart`)

| Champ JSON backend | Type | Utilisé web | Attendu Dart (ProfilModel) | Statut |
|--------------------|------|------------|--------------------------|--------|
| `id` | `string` | ✓ | `json['id']` | ✅ OK |
| `nom` | `string` | ✓ | `json['nom']` | ✅ OK |
| `slug` | `string` | ✓ | `json['slug']` | ✅ OK |
| `logo_url` | `string?` | ✓ | `json['logo_url']` | ✅ OK |
| `banniere_url` | `string?` | ✓ | `json['banniere_url']` | ✅ OK |
| `couleur_primaire` | `string?` | ✓ | `json['couleur_primaire']` | ✅ OK |
| `couleur_secondaire` | `string?` | ✓ | `json['couleur_secondaire']` | ✅ OK |
| `whatsapp_number` | `string?` | ✓ | `json['whatsapp_number']` | ✅ OK |
| `domaine_perso` | `string?` | ✓ | `json['domaine_perso']` | ✅ OK |
| `statut` | `string` | ✓ | `json['statut']` | ✅ OK |
| `created_at` | `string` | ✓ | `json['created_at']` | ✅ OK |
| `plan_nom` | `string?` | ✓ | `json['plan_nom']` | ✅ OK |
| `plan_features` | `object?` | ✓ | `json['plan_features']` | ✅ OK |
| `commandes_incluses` | `int?` | ✓ | `json['commandes_incluses']` | ✅ OK |
| `prix_mensuel` | `num?` | ✓ | `json['prix_mensuel']` | ✅ OK |
| `pdv_id` | `string?` | ✓ | `json['pdv_id']` | ✅ OK |
| `pdv_nom` | `string?` | ✓ | `json['pdv_nom']` | ✅ OK |
| `pdv_adresse` | `string?` | ✓ | `json['pdv_adresse']` | ✅ OK |
| `pdv_latitude` | `num?` | ✓ | `json['pdv_latitude']` | ✅ OK |
| `pdv_longitude` | `num?` | ✓ | `json['pdv_longitude']` | ✅ OK |
| `horaires` | `object?` | ✓ | `json['horaires']` | ✅ OK |
| `boutique_url` | `string` (`/slug`) | ✓ | `json['boutique_url']` | ✅ OK |
| `total_commandes` | `int` | ✓ | `json['total_commandes']` | ✅ OK |
| `mode_acces` | `string` | ✓ | `json['mode_acces']` | ✅ OK |
| `plan_id` | `string?` (UUID Supabase) | — | `json['plan_id']` | ✅ OK (nullable) |

**Note** : `ProfilModel.fromJson` en JSON plat corrigé en Phase D — plus de tentative d'accès à `json['tenant']` ou `json['plan']` imbriqués.

**Résultat** : ✅ Aucun bug résiduel.

---

## 3. `GET /api/v1/dashboard/commandes`

**Backend** (`api-dashboard.ts` l.216–249) → `CommandeModel.fromJson` (`commande_model.dart`)

```
SELECT id, client_nom, client_telephone, client_adresse, items_json (STRING),
       montant_total, frais_livraison, mode_paiement, statut, notes,
       livreur_id, created_at, updated_at
```

**Réponse** : `{ commandes: [...], page, limit, total }`

| Champ JSON backend | Type | Attendu Dart (CommandeModel) | Statut |
|--------------------|------|------------------------------|--------|
| `id` | `string` | `json['id']` | ✅ OK |
| `client_nom` | `string?` | `json['client_nom']` | ✅ OK 🔧 (Phase D) |
| `client_telephone` | `string?` | `json['client_telephone']` | ✅ OK 🔧 (Phase D) |
| `client_adresse` | `string?` | `json['client_adresse']` | ✅ OK 🔧 (Phase D) |
| `items_json` | `string` (JSON encodé) | `jsonDecode(json['items_json'])` | ✅ OK 🔧 (Phase D) |
| `montant_total` | `num` | `json['montant_total']` | ✅ OK |
| `frais_livraison` | `num?` | `json['frais_livraison']` | ✅ OK |
| `mode_paiement` | `string?` | `json['mode_paiement']` | ✅ OK 🔧 (Phase D) |
| `statut` | `string` | `json['statut']` | ✅ OK |
| `notes` | `string?` | `json['notes']` | ✅ OK 🔧 (Phase D) |
| `livreur_id` | `string?` | `json['livreur_id']` | ✅ OK |
| `created_at` | `string` | `DateTime.parse(json['created_at'])` | ✅ OK |
| `updated_at` | `string?` | `DateTime.tryParse(json['updated_at'])` | ✅ OK |
| `page` | `int` | Lu dans `loadCommandes()` (ignoré) | ℹ️ INFO |
| `limit` | `int` | Lu dans `loadCommandes()` (ignoré) | ℹ️ INFO |
| `total` | `int` | Lu dans `loadCommandes()` (ignoré) | ℹ️ INFO |

**Champs non envoyés par l'API, lus par CommandeModel avec valeurs par défaut sûres** :

| Champ Dart | Valeur par défaut | Impact |
|-----------|------------------|--------|
| `tenant_id` | `json['tenant_id'] ?? ''` | ⚠️ DÉFAUT SÛUR — non envoyé, fallback `''` |
| `numero_commande` | `json['numero_commande']` nullable | ⚠️ DÉFAUT SÛUR — non envoyé, `null` |
| `point_de_vente_id` | `json['point_de_vente_id']` nullable | ⚠️ DÉFAUT SÛUR — non envoyé, `null` |

**Résultat** : ✅ Aucun bug résiduel. Isolation per-element ajoutée en Phase E.

---

## 4. `PATCH /api/v1/dashboard/commandes/:id/statut`

**Backend** (`api-dashboard.ts` l.251–349)  
**Corps accepté** : `{ statut, livreur_id?, note? }`  
**Réponse** : `{ success, statut, lien_whatsapp_livreur? }`

| Champ envoyé Flutter (`api_service.dart`) | Champ attendu backend | Statut |
|------------------------------------------|----------------------|--------|
| `statut` | `statut` | ✅ OK |
| `livreur_id` (optionnel) | `livreur_id` | ✅ OK |
| `note` (optionnel) | `note` | ✅ OK |

**Réponse lue par `commandes_provider.dart`** :

| Champ JSON réponse | Lu par Dart | Statut |
|--------------------|------------|--------|
| `success` | via `resp.success` | ✅ OK |
| `lien_whatsapp_livreur` | `resp.data?['lien_whatsapp_livreur']` | ✅ OK |

**Résultat** : ✅ Aucun bug.

---

## 5. `GET /api/v1/dashboard/menu`

**Backend** (`api-dashboard.ts` l.508–556)  
**Réponse** : `{ categories: [{id, nom, ordre_affichage, produits: [{id, categorie_id, nom, prix, photo_url, disponible, ordre_affichage}]}], stats }`

| Champ backend | Attendu Dart (CategorieModel / ProduitModel) | Statut |
|--------------|---------------------------------------------|--------|
| `categories[].id` | `json['id']` | ✅ OK |
| `categories[].nom` | `json['nom']` | ✅ OK |
| `categories[].ordre_affichage` | `json['ordre_affichage']` | ✅ OK |
| `categories[].produits[]` | extrait depuis `categories[i]['produits']` | ✅ OK 🔧 (Phase D) |
| `produits[].id` | `json['id']` | ✅ OK |
| `produits[].categorie_id` | `json['categorie_id']` | ✅ OK |
| `produits[].nom` | `json['nom']` | ✅ OK |
| `produits[].prix` | `json['prix']` | ✅ OK |
| `produits[].photo_url` | `json['photo_url'] ?? json['image_url']` | ✅ OK |
| `produits[].disponible` | `json['disponible']` | ✅ OK |

**Résultat** : ✅ Aucun bug résiduel.

---

## 6. `GET /api/v1/dashboard/pdv`

**Backend** (`api-dashboard.ts` l.918–936)  
**Réponse** : `{ pdv: {id, nom, adresse, latitude, longitude, tarif_livraison_base, tarif_par_km, horaires, actif} | null }`

| Champ backend | Attendu Dart (`restaurant_screen.dart`) | Statut |
|--------------|----------------------------------------|--------|
| `pdv` (objet ou null) | `data['pdv']` (single object) | ✅ OK 🔧 (Phase D) |
| `pdv.id` | `pdv['id']` | ✅ OK |
| `pdv.nom` | `pdv['nom']` | ✅ OK |
| `pdv.adresse` | `pdv['adresse']` | ✅ OK |
| `pdv.latitude` | `pdv['latitude']` | ✅ OK |
| `pdv.longitude` | `pdv['longitude']` | ✅ OK |
| `pdv.tarif_livraison_base` | `pdv['tarif_livraison_base']` | ✅ OK |
| `pdv.tarif_par_km` | `pdv['tarif_par_km']` | ✅ OK |
| `pdv.horaires` | `pdv['horaires']` | ✅ OK |
| `pdv.actif` | (non lu côté Flutter — display only) | ℹ️ INFO |

**Résultat** : ✅ Aucun bug résiduel.

---

## 7. `PATCH /api/v1/dashboard/pdv`

**Backend** (`api-dashboard.ts` l.940–995) — URL sans `:id`  
**Corps accepté** : `{ nom?, adresse?, latitude?, longitude?, tarif_livraison_base?, tarif_par_km?, horaires? }`  
**Réponse** : `{ success, pdv_id?, created?, warning? }`

| Champ envoyé Flutter (`api_service.dart`) | Accepté backend | Statut |
|------------------------------------------|----------------|--------|
| `nom` | ✓ | ✅ OK |
| `adresse` | ✓ | ✅ OK |
| `latitude` | ✓ | ✅ OK |
| `longitude` | ✓ | ✅ OK |
| `tarif_livraison_base` | ✓ | ✅ OK |
| `tarif_par_km` | ✓ | ✅ OK |
| `horaires` | ✓ | ✅ OK |
| URL sans `:id` (`PATCH /dashboard/pdv`) | ✓ | ✅ OK 🔧 (Phase D) |

**Résultat** : ✅ Aucun bug résiduel.

---

## 8. `GET /api/v1/dashboard/livreurs`

**Backend** (`api-dashboard.ts` l.805–821)  
**Réponse** : `{ livreurs: [{id, nom, whatsapp_number, actif, created_at}] }`

| Champ backend | Attendu Dart (LivreurModel) | Statut |
|--------------|----------------------------|--------|
| `id` | `json['id']` | ✅ OK |
| `nom` | `json['nom']` | ✅ OK |
| `whatsapp_number` | `json['whatsapp_number']` | ✅ OK |
| `actif` | `json['actif']` | ✅ OK |
| `created_at` | `json['created_at']` | ✅ OK |

**Champs lus par LivreurModel mais NON envoyés par l'API** :

| Champ Dart | Valeur par défaut | Impact |
|-----------|------------------|--------|
| `tenant_id` | `json['tenant_id'] ?? ''` | ⚠️ DÉFAUT SÛUR — non envoyé par GET /livreurs, fallback `''` |
| `commandes_en_cours` | `json['commandes_en_cours'] ?? 0` | ⚠️ DÉFAUT SÛUR — non envoyé, toujours `0` |
| `total_commandes` | `json['total_commandes'] ?? 0` | ⚠️ DÉFAUT SÛUR — non envoyé, toujours `0` |

**Note** : Ces valeurs par défaut sont sûres, pas de crash. Si l'affichage de `commandes_en_cours` est nécessaire côté UI, il faudrait étendre le SELECT backend — **à valider avec l'utilisateur avant modification backend**.

**Résultat** : ⚠️ Pas de crash, données affichées mais `commandes_en_cours` et `total_commandes` toujours à 0.

---

## 9. `GET /api/v1/dashboard/codes-promo`

**Backend** (`api-dashboard.ts` l.1238–1256)  
**Réponse** : `{ codes: [{id, code, type, valeur, date_debut, date_fin, usage_max, usage_actuel, actif, created_at}] }`

| Champ backend | Type | Attendu Dart (CodePromoModel) | Statut |
|--------------|------|------------------------------|--------|
| `id` | `string` | `json['id']` | ✅ OK |
| `code` | `string` | `json['code']` | ✅ OK |
| `type` | `string` | `json['type_reduction']` — **MISMATCH !** | ❌ BUG |
| `valeur` | `num` | `json['valeur']` | ✅ OK |
| `date_debut` | `string?` | `json['date_expiration']` — **MISMATCH !** backend envoie `date_debut`/`date_fin`, Dart lit `date_expiration` | ❌ BUG |
| `date_fin` | `string?` | `json['date_expiration']` lit `date_fin` ? | ❌ BUG — à confirmer |
| `usage_max` | `int?` | `json['max_utilisations']` — **MISMATCH !** | ❌ BUG |
| `usage_actuel` | `int` | `json['utilisations_actuelles']` — **MISMATCH !** | ❌ BUG |
| `actif` | `bool` | `json['actif']` | ✅ OK |
| `created_at` | `string?` | `json['created_at']` | ✅ OK |

**⚠️ BUGS CÔTÉ DART identifiés pour codes-promo (NON corrigés en Phase E — non prioritaires dans ce sprint) :**
- `type_reduction` vs `type` → toujours `'pourcentage'` (valeur par défaut)
- `date_expiration` vs `date_fin` → date d'expiration toujours `null`
- `max_utilisations` vs `usage_max` → toujours `null`
- `utilisations_actuelles` vs `usage_actuel` → toujours `0`

**Impact** : L'écran codes-promo s'affiche mais avec données incorrectes (type toujours "pourcentage", dates absentes, compteurs à 0).

**Action recommandée** : Corriger `CodePromoModel.fromJson` pour lire les bons noms de champs — **à appliquer dans un prochain sprint** (hors scope Phase E défini par l'utilisateur).

---

## 10. `GET /api/v1/dashboard/notifications` (count/unread)

**Backend** (`api-dashboard.ts` l.147–213)  
**Réponse** : `{ notifications: [{id, type, titre, message, lue, lien, created_at}], count }`

| Champ backend | Attendu Dart (NotificationService / `notifications_screen.dart`) | Statut |
|--------------|----------------------------------------------------------------|--------|
| `notifications[].id` | `json['id']` | ✅ OK |
| `notifications[].type` | `json['type']` | ✅ OK |
| `notifications[].titre` | `json['titre']` | ✅ OK |
| `notifications[].message` | `json['message']` | ✅ OK |
| `notifications[].lue` | `json['lue']` | ✅ OK |
| `notifications[].lien` | `json['lien']` | ✅ OK |
| `notifications[].created_at` | `json['created_at']` | ✅ OK |
| `count` | `json['count']` | ✅ OK |

**Résultat** : ✅ Aucun bug connu.

---

## 11. `GET /api/v1/dashboard/notifications/liste`

**Backend** (`api-dashboard.ts` l.1706+)  
**Réponse** : `{ notifications: [...], page, limit, total, nb_non_lues, has_more }`

**Mapping `api_service.dart`** : `getNotificationsListe(page, limit, nonLuesSeulement)` → `GET /dashboard/notifications/liste?page=&limit=&non_lues=true`

**Résultat** : ✅ Paramètres et réponse cohérents.

---

## 12. `PATCH /api/v1/dashboard/notifications/:id`

**Backend** → `{ success }`  
**Corps attendu** : `{ lue: bool }`  
**Mapping Dart** : `marquerNotificationLue(id, lue: true)` envoie `{'lue': lue}`

**Résultat** : ✅ OK.

---

## 13. `PATCH /api/v1/dashboard/notifications/tout-lire`

**Backend** → `{ success }`  
**Mapping Dart** : `marquerToutesLues()` envoie `{}`

**Résultat** : ✅ OK.

---

## 14. `GET /api/v1/plans`

**Backend** (`api-plans.ts` l.36–82)  
**Réponse** : `{ plans: [{id, nom, prix_mensuel, devise, commandes_incluses, limite_pdv, fonctionnalites, ordre_affichage, actif, ...commandes_incluses_affichage, limite_pdv_affichage}], devise }`

| Champ backend | Attendu Dart (PlanModel) | Statut |
|--------------|--------------------------|--------|
| `id` | `json['id']` | ✅ OK |
| `nom` | `json['nom']` | ✅ OK |
| `prix_mensuel` | `json['prix_mensuel']` | ✅ OK |
| `devise` | `json['devise']` (hardcodé 'FCFA') | ✅ OK |
| `commandes_incluses` | `json['commandes_incluses']` | ✅ OK |
| `limite_pdv` | `json['limite_pdv']` | ✅ OK |
| `fonctionnalites` | `json['fonctionnalites']` (objet parsé) | ✅ OK |
| `ordre_affichage` | `json['ordre_affichage']` | ✅ OK |
| `actif` | (filtré côté backend, toujours `actif=1`) | ℹ️ INFO |
| `commandes_incluses_affichage` | non lu côté Flutter | ℹ️ INFO |
| `limite_pdv_affichage` | non lu côté Flutter | ℹ️ INFO |

**Résultat** : ✅ Aucun bug. Isolation per-element ajoutée en Phase E.

---

## 15. `GET /api/v1/paiement/statut`

**Backend** (`api-paiement.ts` l.171–249)  
**Réponse** : `{ statut_tenant, plan_initial_id, plan_initial_id_d1, plan_initial_nom, plan_initial_prix_mensuel, abonnement{id, statut, date_fin, plan_id, periodicite, reference_paiement, methode_paiement, numero_expediteur, soumis_le, delai_confirmation_expire_le, heures_restantes_confirmation, message_confirmation}, essai_expire_le, jours_essai_restants, reference_active, sla_admin_heures, fenetre_acces_heures, mode_acces }`

| Champ backend | Attendu Dart (DashboardProvider / TenantModel) | Statut |
|--------------|----------------------------------------------|--------|
| `statut_tenant` | `_abonnementStatut?['statut_tenant']` | ✅ OK |
| `abonnement` | `_abonnementStatut?['abonnement']` | ✅ OK |
| `abonnement.heures_restantes_confirmation` | `PaiementEnAttenteModel.fromJson['heures_restantes_confirmation']` | ✅ OK |
| `abonnement.message_confirmation` | `PaiementEnAttenteModel.fromJson['message_confirmation']` | ✅ OK |
| `abonnement.delai_confirmation_expire_le` | `PaiementEnAttenteModel.fromJson['delai_confirmation_expire_le']` | ✅ OK |
| `jours_essai_restants` | `DashboardProvider.joursEssaiRestants` | ✅ OK |
| `sla_admin_heures` | Non lu côté Flutter | ℹ️ INFO |
| `fenetre_acces_heures` | Non lu côté Flutter | ℹ️ INFO |
| `plan_initial_id_d1` | Non lu côté Flutter (FIX-C web seulement) | ℹ️ INFO |

**Résultat** : ✅ Aucun bug. try/catch ajouté en Phase E.

---

## 16. `GET /api/v1/paiement/reference`

**Backend** (`api-paiement.ts` l.261–293)  
**Réponse** : `{ reference: string, instructions: string[] }`

| Champ backend | Attendu Dart (DashboardProvider) | Statut |
|--------------|----------------------------------|--------|
| `reference` | `resp.data!['reference']` | ✅ OK |
| `instructions` | `resp.data!['instructions']` as List | ✅ OK |

**Résultat** : ✅ Aucun bug. try/catch ajouté en Phase E.

---

## 17. `POST /api/v1/paiement/soumettre`

**Backend** (`api-paiement.ts` l.314–558) — multipart/form-data  
**Corps attendu** : `{ preuve (File), plan_id, methode_paiement, numero_expediteur }` (CYCLE-3 : periodicite supprimé)  
**Réponse** : `{ success, abonnement_id, reference, delai_confirmation, heures_delai, sla_admin_heures, message, plan{nom, montant, devise} }`

| Champ envoyé Flutter (`api_service.dart`) | Accepté backend | Statut |
|------------------------------------------|----------------|--------|
| `plan_id` | ✓ | ✅ OK |
| `methode_paiement` | ✓ | ✅ OK |
| `periodicite` | ❌ IGNORÉ (CYCLE-3) | ⚠️ DÉFAUT SÛUR — champ ignoré côté backend, toujours 'mensuel' |
| `numero_expediteur` | ✓ (REQUIS depuis FIX-3) | ❌ BUG — Flutter n'envoie PAS `numero_expediteur` ! |

**⚠️ BUG IDENTIFIÉ : `numero_expediteur` manquant** :  
Le backend retourne `400 "Le numéro utilisé pour le paiement est requis"` si `numero_expediteur` est absent ou < 8 chiffres. Flutter (`soumettrePreuvePaiement`) n'envoie que `plan_id`, `methode_paiement`, `periodicite` — pas `numero_expediteur`.  
→ **Toute soumission de preuve depuis l'app Flutter échoue avec 400.**  
→ **Correction requise dans `api_service.dart` + UI screen paiement pour collecter ce champ.**  
→ **NON corrigé en Phase E** (modification UI non triviale — à valider avec l'utilisateur).

---

## 18. `GET /api/v1/paiement/historique`

**Backend** (`api-paiement.ts` l.570–610)  
**Réponse** : `{ abonnements: [{id, statut, plan_id, date_debut, date_fin, montant_paye, devise, methode_paiement, numero_expediteur, reference_paiement, soumis_le, confirme_le, rejete_le, motif_rejet, created_at, plan_nom, plan_prix_mensuel}], total, page, limit, total_pages }`

| Champ backend | Attendu Dart (`abonnement_historique_screen.dart`) | Statut |
|--------------|--------------------------------------------------|--------|
| `abonnements` | `resp.data?['abonnements']` | ✅ OK (à vérifier si screen lit bien cette clé) |
| `plan_nom` | présent dans réponse | ✅ OK |
| `plan_prix_mensuel` | présent dans réponse | ✅ OK |

**Résultat** : ✅ Présumé OK (screen non lu en détail — pas dans scope Phase E).

---

## 19. `GET /api/v1/paiement/notifications`

**Backend** (`api-paiement.ts` l.623–714)  
**Réponse** : `{ notifications: [{id, type, titre, message, action?, created_at}], count, non_lues }`

**Mapping Dart** : `getPaiementNotifications()` → `get('/paiement/notifications')`

**Résultat** : ✅ Mapping simple, réponse brute utilisée pour bandeaux.

---

## 20. `POST /api/v1/dashboard/upload-image`

**Backend** (`api-dashboard.ts` l.1421+) — multipart  
**Corps** : `file` (image JPEG/PNG/WebP/GIF, max 5MB)  
**Réponse** : `{ success, url, key }`

**Mapping Dart** : `uploadImage(filePath)` envoie le champ `file` 

**Résultat** : ✅ Cohérent.

---

## 21. Realtime Supabase — Canal `commandes` (INSERT)

**Source** : `notification_service.dart` + `realtime_service.dart`  
**Table Supabase écoutée** : `commandes`  
**Payload Realtime** : colonnes réelles de la table DB (pas les alias API)

| Champ DB Supabase réel | Lu par `notification_service.dart` | Statut avant Phase E | Statut après Phase E |
|------------------------|-------------------------------------|---------------------|---------------------|
| `id` | `record['id']` | ✅ OK | ✅ OK |
| `client_nom` | `record['nom_client']` | ❌ BUG — retourne null | ✅ CORRIGÉ (`record['client_nom']`) 🔧 |
| `montant_total` | `record['montant_total']` | ✅ OK | ✅ OK |
| `numero_commande` | `record['numero_commande']` | ✅ OK (nullable) | ✅ OK |
| `tenant_id` | utilisé pour filtre, pas affiché | ✅ OK | ✅ OK |

---

## 22. `auth_service.dart` — Restauration de session

| Élément | Avant Phase E | Après Phase E |
|---------|--------------|--------------|
| `setSession(accessToken)` | ❌ BUG — arg incorrect, session jamais restaurée | ✅ CORRIGÉ — `setSession(refreshToken)` |
| `FlutterAuthClientOptions` dans `main.dart` | Commentaire `persistSession` trompeur mais pas de bug fonctionnel | ℹ️ INFO — pas de `persistSession` dans supabase_flutter ^2.x, géré automatiquement |

---

## Résumé des corrections Phase E

| # | Fichier | Correction appliquée | Type |
|---|---------|---------------------|------|
| 1 | `dashboard_provider.dart` | try/catch/finally sur `loadStats()` | ❌→✅ |
| 2 | `dashboard_provider.dart` | try/catch/finally sur `loadStatsJournalieres()` | ❌→✅ |
| 3 | `dashboard_provider.dart` | try/catch/finally sur `loadProfil()` | ❌→✅ |
| 4 | `dashboard_provider.dart` | try/catch/finally + isolation per-element sur `loadPlans()` | ❌→✅ |
| 5 | `dashboard_provider.dart` | try/catch/finally sur `loadAbonnement()` | ❌→✅ |
| 6 | `dashboard_provider.dart` | try/catch/finally sur `loadReferencePaiement()` | ❌→✅ |
| 7 | `commandes_provider.dart` | try/catch/finally + isolation per-element sur `loadCommandes()` | ❌→✅ |
| 8 | `commandes_provider.dart` | try/catch sur `updateStatut()` | ❌→✅ |
| 9 | `auth_service.dart` | `setSession(accessToken)` → `setSession(refreshToken)` | ❌→✅ |
| 10 | `notification_service.dart` | `record['nom_client']` → `record['client_nom']` (colonne DB réelle) | ❌→✅ |

---

## Bugs résiduels identifiés (NON corrigés en Phase E — à valider avec l'utilisateur)

| # | Endpoint | Fichier Dart | Bug | Impact | Priorité |
|---|---------|-------------|-----|--------|----------|
| R1 | `GET /dashboard/codes-promo` | `livreur_model.dart (CodePromoModel)` | `type_reduction` vs `type` ; `date_expiration` vs `date_fin` ; `max_utilisations` vs `usage_max` ; `utilisations_actuelles` vs `usage_actuel` | Données codes-promo mal affichées (types incorrects, dates absentes) | MOYEN |
| R2 | `POST /paiement/soumettre` | `api_service.dart` + screen paiement | Champ `numero_expediteur` manquant — backend retourne 400 | **Soumission de preuve échoue systématiquement** | CRITIQUE |
| R3 | `GET /dashboard/livreurs` | `livreur_model.dart` | `commandes_en_cours` et `total_commandes` jamais envoyés par l'API | Compteurs toujours à 0 dans l'UI | FAIBLE |

### Détail R2 — `numero_expediteur` manquant (CRITIQUE)

Le backend `POST /paiement/soumettre` exige le champ `numero_expediteur` depuis FIX-3 (numéro utilisé pour le paiement). Flutter ne le collecte pas et ne l'envoie pas → `400 "Le numéro utilisé pour le paiement est requis"`.

**Correction requise** :
1. Ajouter un champ `numero_expediteur` dans l'UI du screen de soumission de preuve
2. Passer ce champ à `soumettrePreuvePaiement()` dans `api_service.dart`
3. L'inclure dans le `request.fields` du MultipartRequest

**Modification backend requise** : Aucune — le backend est correct.  
**Modification UI requise** : OUI — à valider avec l'utilisateur.

---

## Notes architecturales

### persistSession dans main.dart
`FlutterAuthClientOptions` dans `supabase_flutter ^2.8.0` ne supporte pas de paramètre `persistSession` explicite — la persistance de session est gérée automatiquement par le SDK via `SharedPreferences`. Le commentaire dans `main.dart` est trompeur mais sans impact fonctionnel.

### Realtime vs API — noms de champs
Les payloads Supabase Realtime Postgres Changes utilisent **les vrais noms de colonnes DB**, pas les alias définis dans les SELECT API. Toute correction de nom de champ côté API (ex: renommage via alias) n'affecte **pas** les payloads Realtime. Tenir compte de cette distinction pour tout futur changement d'alias backend.

### Codes promo — wrapping de la réponse
L'API retourne `{ codes: [...] }` mais `CodePromoModel` semble être instancié directement. À vérifier dans le provider correspondant si la clé `codes` est bien extraite.

---

*Audit généré en Phase E — commit de référence à créer avec toutes les corrections ci-dessus.*

---

## Corrections Phase F — Session audit croisé complet ($(date +%Y-%m-%d))

Suite à l'audit complet réalisé avec lecture simultanée des deux dépôts (monmenu + monmenu-mobile) et du JS dashboard web (référence de vérité), les bugs résiduels R1 et R2 de Phase E ont été corrigés, ainsi qu'un bug R3 supplémentaire identifié.

### Corrections appliquées en Phase F

| # | Fichier | Correction | Type |
|---|---------|-----------|------|
| F1 | `lib/models/livreur_model.dart` (CodePromoModel) | `json['type_reduction']` → `json['type'] ?? json['type_reduction']` | R1 ❌→✅ |
| F2 | `lib/models/livreur_model.dart` (CodePromoModel) | `json['max_utilisations']` → `json['usage_max'] ?? json['max_utilisations']` | R1 ❌→✅ |
| F3 | `lib/models/livreur_model.dart` (CodePromoModel) | `json['utilisations_actuelles']` → `json['usage_actuel'] ?? json['utilisations_actuelles']` | R1 ❌→✅ |
| F4 | `lib/models/livreur_model.dart` (CodePromoModel) | `json['date_expiration']` → `json['date_fin'] ?? json['date_expiration']` | R1 ❌→✅ |
| F5 | `lib/services/api_service.dart` | Ajout paramètre `required String numeroExpediteur` + `request.fields['numero_expediteur']` | R2 ❌→✅ |
| F6 | `lib/services/payment_upload_service.dart` | Ajout `numeroExpediteur` dans `PendingUpload`, `uploadPreuve()`, `_attemptUpload()`, `retryPendingUploadIfNeeded()` | R2 ❌→✅ |
| F7 | `lib/screens/plans/plans_screen.dart` | Ajout champ TextFormField "Numéro utilisé pour le paiement" dans `_UploadProofSheet` + bouton désactivé si vide | R2 ❌→✅ |
| F8 | `lib/models/plan_model.dart` | `json['actif'] as bool? ?? true` → `_toBool(json['actif'])` (robustesse entiers D1) | R3 ❌→✅ |
| F9 | `lib/screens/plans/plans_screen.dart` | Messages SLA "38h" → "48h" (cohérence avec backend `SLA_ADMIN_HEURES`) | INFO ✅ |
| F10 | `lib/services/notification_service.dart` | Message "Confirmation sous 38h" → "Confirmation sous 48h" | INFO ✅ |

### Statut des bugs après Phase F

| # | Endpoint | Bug | Statut |
|---|---------|-----|--------|
| R1 | `GET /dashboard/codes-promo` | Noms de champs `type`, `usage_max`, `usage_actuel`, `date_fin` | ✅ CORRIGÉ (F1-F4) |
| R2 | `POST /paiement/soumettre` | `numero_expediteur` manquant | ✅ CORRIGÉ (F5-F7) |
| R3 (ex-note) | `GET /dashboard/livreurs` | `commandes_en_cours`, `total_commandes` absents API | ⚠️ DÉFAUT SÛUR — fallback 0, pas de crash |
| R4 | `GET /api/v1/plans` | `actif` retourné comme entier D1 (1/0) pas bool | ✅ CORRIGÉ (F8) |

### Résultat flutter analyze après Phase F

```
9 issues found (0 erreurs, 3 warnings non-bloquants, 6 infos de style)
- warnings : dossiers assets/ manquants (pubspec.yaml), unused_element_parameter
- infos : use_build_context_synchronously, curly_braces_in_flow_control_structures
```

**Aucune erreur de compilation. Build APK autorisé.**

