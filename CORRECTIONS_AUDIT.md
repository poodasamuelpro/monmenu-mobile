# CORRECTIONS_AUDIT.md — MonMenu Manager Mobile

**Projet** : MonMenu Manager (application mobile Flutter)  
**Backend source de vérité** : Cloudflare Workers + Hono v4 (`https://monmenu.poodasamuelpro.workers.dev`)  
**Date d'audit** : 2025-08-09  
**Auditeur** : Révision systématique de l'API mobile vs routes backend réelles  
**Branche** : `main`  
**Dépôt mobile** : `https://github.com/poodasamuelpro/monmenu-mobile`

---

## Résumé exécutif

8 corrections au total ont été apportées suite à un audit approfondi du code mobile Flutter contre les routes du backend Cloudflare Workers :

| # | Sévérité | Correction | Fichiers modifiés | Commit |
|---|----------|-----------|-------------------|--------|
| 4.1 | 🔴 CRITIQUE | `apiBaseUrl` incorrect | `app_config.dart`, `api_service.dart` | `2529f36` |
| 4.2 | 🔴 CRITIQUE | Champ `numero_expediteur` manquant | `api_service.dart`, `payment_upload_service.dart`, `plans_screen.dart` | `9111668` |
| 4.3 | 🔴 CRITIQUE | Codes promo : clé et champs incorrects | `livreur_model.dart`, `codes_promo_screen.dart` | `2681a61` |
| 4.4 | 🟡 MOYEN | Livreur : édition illusoire | `livreurs_screen.dart` | `3b04622` |
| 4.5 | 🟢 MINEUR | Textes "38h" → "48h" / `message_38h` | 5 fichiers | `58eb09a` |
| 4.6 | 🟢 MINEUR | "Plan inconnu" dans l'historique | `plan_model.dart`, `abonnement_historique_screen.dart` | `ecb8334` |
| S5-A | 🔴 CRITIQUE | `updateCodePromo()` → endpoint inexistant | `api_service.dart`, `codes_promo_screen.dart` | `2b7ddcf` |
| S5-B | 🟡 MOYEN | `getCategories()` → endpoint inexistant | `api_service.dart` | `2b7ddcf` |

---

## 4.1 — `apiBaseUrl` incorrect (🔴 CRITIQUE)

### Problème
`AppConfig.apiBaseUrl` pointait vers `https://monmenu.app` (domaine front-end statique Cloudflare Pages) au lieu de `https://monmenu.poodasamuelpro.workers.dev` (endpoint API Cloudflare Workers). Toutes les requêtes API échouaient silencieusement car l'erreur `http.ClientException` n'était pas capturée, masquant la cause racine.

### Preuve
```dart
// AVANT (lib/config/app_config.dart)
static const String apiBaseUrl = 'https://monmenu.app';
```

```typescript
// Source de vérité (src/index.tsx)
app.route('/api/v1/dashboard', dashboardRouter)
app.route('/api/v1/paiement', paiementRouter)
// → toutes les routes sont sur workers.dev, pas sur monmenu.app
```

### Correction
```dart
// APRÈS (lib/config/app_config.dart)
static const String apiBaseUrl = 'https://monmenu.poodasamuelpro.workers.dev';
```

Ajout également d'un `catch` explicite pour `http.ClientException` dans `_request()` d'`api_service.dart` pour exposer les erreurs réseau.

### Vérification
```bash
grep "apiBaseUrl" lib/config/app_config.dart
# → static const String apiBaseUrl = 'https://monmenu.poodasamuelpro.workers.dev';
grep -rn "monmenu\.app" lib/ --include="*.dart"
# → 0 résiduel API (uniquement boutique URLs dans apparence_screen.dart et qrcode_screen.dart — correct)
```

---

## 4.2 — Champ `numero_expediteur` manquant dans la soumission de preuve (🔴 CRITIQUE)

### Problème
Le formulaire de soumission de preuve de paiement n'envoyait pas le champ `numero_expediteur` qui est **obligatoire** côté backend (validation stricte min. 8 chiffres). Résultat : 100% des soumissions retournaient HTTP 400.

### Preuve
```typescript
// Source de vérité (src/routes/api-paiement.ts)
// POST /api/v1/paiement/soumettre
const numeroExpediteur = formData.get('numero_expediteur') as string | null
if (!numeroExpediteur || !/^\+?[0-9\s\-]{8,}$/.test(numeroExpediteur.replace(/\s/g, ''))) {
  return c.json({ error: 'Numéro de l\'expéditeur requis (min. 8 chiffres).' }, 400)
}
```

### Correction
**`lib/services/api_service.dart`** — ajout du paramètre :
```dart
Future<ApiResponse> soumettrePreuvePaiement({
  required String filePath,
  required String planId,
  required String methodePaiement,
  required String periodicite,
  required String numeroExpediteur,  // ← AJOUTÉ
}) async {
  // ...
  request.fields['numero_expediteur'] = numeroExpediteur;  // ← AJOUTÉ
}
```

**`lib/services/payment_upload_service.dart`** — propagation complète :
```dart
class PendingUpload {
  final String numeroExpediteur;  // ← AJOUTÉ
  // ...
}
```

**`lib/screens/plans/plans_screen.dart`** — champ UI + validation :
```dart
TextField(
  controller: _numeroExpediteurCtrl,
  decoration: InputDecoration(
    labelText: 'Numéro utilisé pour le paiement',
    helperText: 'Ex: +226 70 00 00 00 (min. 8 chiffres)',
  ),
),
// Validation
if (numeroPropre.length < 8) {
  _showSnack('Numéro trop court (8 chiffres minimum)', isError: true);
  return;
}
```

### Vérification
```bash
grep -n "numero_expediteur" lib/services/api_service.dart
# → request.fields['numero_expediteur'] = numeroExpediteur;
grep -n "numeroExpediteur" lib/services/payment_upload_service.dart
# → 4 occurrences (champ, toJson, fromJson, _attemptUpload, retry)
```

---

## 4.3 — Codes promo : clé de réponse et noms de champs incorrects (🔴 CRITIQUE)

### Problème
Trois bugs distincts dans la gestion des codes promo :

1. **Clé de réponse** : le mobile lisait `resp.data?['codes_promo']` mais le backend retourne `{ codes: [...] }`
2. **Champs POST** : les noms de champs envoyés ne correspondaient pas à ceux attendus par le backend
3. **Champ inexistant** : `min_commande` envoyé mais inexistant côté backend

### Preuve
```typescript
// Source de vérité (src/routes/api-dashboard.ts)
// GET /api/v1/dashboard/codes-promo
return c.json({ codes: promos })  // ← 'codes', pas 'codes_promo'

// POST /api/v1/dashboard/codes-promo — body attendu :
// code, type (pas type_reduction), valeur, date_fin (pas date_expiration),
// usage_max (pas max_utilisations) — min_commande inexistant
```

### Correction

**Champ → Avant → Après** :

| Champ mobile (avant) | Champ backend réel (après) |
|---|---|
| `codes_promo` (clé réponse) | `codes` |
| `type_reduction` | `type` |
| `max_utilisations` | `usage_max` |
| `utilisations_actuelles` | `usage_actuel` |
| `date_expiration` | `date_fin` |
| `min_commande` | *(supprimé — inexistant)* |

**`lib/models/livreur_model.dart`** — `CodePromoModel.fromJson()` et `toJson()` corrigés.

**`lib/screens/restaurant/codes_promo_screen.dart`** — payload `_save()` corrigé, champ `min_commande` remplacé par une note informatique "Fonctionnalité à venir".

### Vérification
```bash
grep "codes_promo\|type_reduction\|max_utilisations\|date_expiration\|min_commande" \
  lib/screens/restaurant/codes_promo_screen.dart lib/models/livreur_model.dart
# → 0 résultats
```

---

## 4.4 — Édition livreur : sauvegarde illusoire (🟡 MOYEN)

### Problème
Le dialogue d'édition d'un livreur envoyait `nom` + `whatsapp_number` + `actif` lors d'un PATCH, mais le backend ignore silencieusement `nom` et `whatsapp_number` — seul `actif` est sauvegardé. L'UI donnait une fausse impression de succès pour les champs nom/téléphone.

### Preuve
```typescript
// Source de vérité (src/routes/api-dashboard.ts)
// PATCH /api/v1/dashboard/livreurs/:id
const { actif } = body  // ← seul actif est lu
// nom et whatsapp_number ne sont jamais lus côté backend
await supabase.from('livreurs').update({ actif }).eq('id', id)
```

### Correction
**`lib/screens/restaurant/livreurs_screen.dart`** — mode édition :
- Champs `nom` et `whatsapp_number` masqués (en lecture seule, non éditables)
- Message explicatif : *"Seul le statut actif/inactif peut être modifié. Pour changer le nom ou le numéro, supprimez et recréez le livreur."*
- `_save()` envoie uniquement `{'actif': _actif}`

### Limitation connue
Il n'est pas possible de modifier le nom/WhatsApp d'un livreur via l'API mobile actuelle. La fonctionnalité complète nécessite un endpoint backend dédié (non encore implémenté).

---

## 4.5 — Textes "38h" → "48h" et `message_38h` → `message_confirmation` (🟢 MINEUR)

### Problème
Le SLA de confirmation avait été renommé de 38h à 48h côté backend (Cycle-4 FIX-D). Le champ `message_38h` avait été renommé `message_confirmation`. 9 occurrences de "38h" et 3 occurrences de `message_38h` subsistaient dans le code mobile.

### Preuve
```typescript
// Source de vérité (src/routes/api-paiement.ts)
const SLA_ADMIN_HEURES = 48  // ← 48, pas 38
const message_confirmation = `...`  // ← message_confirmation, pas message_38h
```

### Fichiers modifiés (9 occurrences "38h" + 3 occurrences `message_38h`)
- `lib/screens/plans/plans_screen.dart` — 5 occurrences
- `lib/models/tenant_model.dart` — 3 occurrences + `message38h` → `messageConfirmation`
- `lib/models/plan_model.dart` — 2 commentaires
- `lib/services/api_service.dart` — 1 commentaire
- `lib/services/notification_service.dart` — 1 occurrence dans le corps de notification

### Vérification
```bash
grep -rn "38h\|message_38h\|message38h" lib/ --include="*.dart"
# → 0 résiduel
```

---

## 4.6 — "Plan inconnu" dans l'historique des abonnements (🟢 MINEUR)

### Problème
L'écran d'historique affichait systématiquement "Plan inconnu" car le code lisait `abonnement.plan?.nom` (objet imbriqué) alors que le backend retourne un champ plat `plan_nom`.

### Preuve
```typescript
// Source de vérité (src/routes/api-paiement.ts)
// GET /api/v1/paiement/historique
// La réponse contient : { ...ab, plan_nom: string, plan_prix_mensuel: number }
// PAS d'objet plan imbriqué
```

### Correction
**`lib/models/plan_model.dart`** — `AbonnementModel` :
```dart
final String? planNomPlat;  // ← AJOUTÉ — champ plat depuis /historique

factory AbonnementModel.fromJson(Map<String, dynamic> json) {
  return AbonnementModel(
    // ...
    planNomPlat: json['plan_nom'] as String?,  // ← AJOUTÉ
  );
}

String? get planNomEffectif => planNomPlat ?? plan?.nom;  // ← AJOUTÉ
```

**`lib/screens/plans/abonnement_historique_screen.dart`** :
```dart
// AVANT
abonnement.plan?.nom ?? 'Plan inconnu'
// APRÈS
abonnement.planNomEffectif ?? 'Plan inconnu'
```

---

## S5-A — `updateCodePromo()` : endpoint inexistant (🔴 CRITIQUE — Audit Section 5)

### Découverte
Audit systématique de tous les endpoints `ApiService` vs routes backend réelles.

### Problème
`ApiService.updateCodePromo()` appelait `PATCH /dashboard/codes-promo/:id` qui n'existe **pas** côté backend. Le backend ne fournit que :
- `GET /dashboard/codes-promo` — lister
- `POST /dashboard/codes-promo` — créer
- `DELETE /dashboard/codes-promo/:id` — supprimer

Pas de PATCH. Les appels auraient retourné 404 à l'exécution.

### Correction
- `ApiService.updateCodePromo()` **supprimée**
- `_toggleActif()` dans `codes_promo_screen.dart` adapté : le bouton switch est désactivé (`onChanged: null`) et un message explicatif est affiché
- Tooltip sur le Switch : *"Modification non disponible via l'API actuelle"*

### Limitation connue
Le toggle actif/inactif des codes promo n'est pas supporté par l'API actuelle. Pour désactiver un code, il faut le supprimer et le recréer.

---

## S5-B — `getCategories()` : endpoint inexistant (🟡 MOYEN — Audit Section 5)

### Découverte
Audit systématique de tous les endpoints `ApiService` vs routes backend réelles.

### Problème
`ApiService.getCategories()` appelait `GET /dashboard/categories` qui n'existe **pas** côté backend. Le backend expose uniquement :
- `GET /dashboard/menu` → retourne `{ categories: [...], produits: [...] }`

`getCategories()` n'était appelé nulle part dans le code (méthode déclarée mais inutilisée), donc pas d'impact fonctionnel immédiat, mais potentiellement un problème si utilisé dans le futur.

### Correction
- `ApiService.getCategories()` **supprimée**
- Commentaire de migration ajouté : `// Utiliser getMenu() → GET /dashboard/menu`

---

## Tableau récapitulatif des routes backend vérifiées

### Routes `/api/v1/plans`
| Endpoint | Backend | Mobile | Statut |
|---|---|---|---|
| `GET /plans` | `{ plans: [...], devise: 'FCFA' }` | `getPlans()` | ✅ Conforme |

### Routes `/api/v1/auth`
| Endpoint | Backend | Mobile | Statut |
|---|---|---|---|
| `POST /auth/login` | `{ access_token, refresh_token, tenant }` | `login()` dans AuthService | ✅ Conforme |
| `POST /auth/register` | `{ success, access_token, ... }` | `register()` dans AuthService | ✅ Conforme |
| `POST /auth/logout` | `{ success }` | `logout()` dans AuthService | ✅ Conforme |
| `POST /auth/refresh` | `{ access_token, refresh_token }` | `refreshToken()` dans AuthService | ✅ Conforme |
| `POST /auth/forgot-password` | `{ message }` | Non utilisé côté mobile | ℹ️ N/A |
| `POST /auth/verify-otp` | `{ access_token, ... }` | Non utilisé côté mobile | ℹ️ N/A |
| `POST /auth/reset-password` | `{ success }` | Non utilisé côté mobile | ℹ️ N/A |

### Routes `/api/v1/dashboard`
| Endpoint | Backend | Mobile | Statut |
|---|---|---|---|
| `GET /dashboard/commandes` | `{ commandes, total, page }` | `getCommandes()` | ✅ Conforme |
| `PATCH /dashboard/commandes/:id/statut` | body: `{statut, livreur_id?, note?}` | `updateCommandeStatut()` | ✅ Conforme |
| `GET /dashboard/stats` | `{ stats }` | `getStats()` | ✅ Conforme |
| `GET /dashboard/stats-journalieres` | `{ stats[] }` | `getStatsJournalieres()` | ✅ Conforme |
| `GET /dashboard/menu` | `{ categories, produits }` | `getMenu()` | ✅ Conforme |
| `GET /dashboard/categories` | **N'EXISTE PAS** | `getCategories()` | ✅ Corrigé (S5-B) |
| `POST /dashboard/categories` | body: `{nom, description?}` | `createCategorie()` | ✅ Conforme |
| `PATCH /dashboard/categories/:id` | body: `{nom?, description?}` | `updateCategorie()` | ✅ Conforme |
| `DELETE /dashboard/categories/:id` | — | `deleteCategorie()` | ✅ Conforme |
| `POST /dashboard/produits` | body: `{nom, prix, ...}` | `createProduit()` | ✅ Conforme |
| `PATCH /dashboard/produits/:id` | body: `{nom?, prix?, ...}` | `updateProduit()` | ✅ Conforme |
| `DELETE /dashboard/produits/:id` | — | `deleteProduit()` | ✅ Conforme |
| `GET /dashboard/livreurs` | `{ livreurs }` | `getLivreurs()` | ✅ Conforme |
| `POST /dashboard/livreurs` | body: `{nom, whatsapp_number}` | `createLivreur()` | ✅ Conforme |
| `PATCH /dashboard/livreurs/:id` | body: `{actif}` seulement | `updateLivreur()` | ✅ Corrigé (4.4) |
| `DELETE /dashboard/livreurs/:id` | — | `deleteLivreur()` | ✅ Conforme |
| `GET /dashboard/pdv` | `{ pdv }` | `getPdv()` | ✅ Conforme |
| `PATCH /dashboard/pdv` | body: `{...pdv fields}` | `updatePdv()` | ✅ Conforme |
| `GET /dashboard/profil` | `{ tenant, utilisateur }` | `getProfil()` | ✅ Conforme |
| `PATCH /dashboard/apparence` | body: `{couleur_primaire?, logo_url?, ...}` | `updateApparence()` | ✅ Conforme |
| `PATCH /dashboard/parametres` | body: `{...}` | `updateParametres()` | ✅ Conforme |
| `GET /dashboard/codes-promo` | `{ codes: [...] }` | `getCodesPromo()` | ✅ Corrigé (4.3) |
| `POST /dashboard/codes-promo` | body: `{code, type, valeur, date_fin?, usage_max?}` | `createCodePromo()` | ✅ Corrigé (4.3) |
| `PATCH /dashboard/codes-promo/:id` | **N'EXISTE PAS** | `updateCodePromo()` | ✅ Corrigé (S5-A) |
| `DELETE /dashboard/codes-promo/:id` | — | `deleteCodePromo()` | ✅ Conforme |
| `GET /dashboard/qrcode` | `{ url, qr_api_url, ... }` | `getQrCode()` | ✅ Conforme |
| `POST /dashboard/upload-image` | champ: `file` | `uploadImage()` | ✅ Conforme |
| `GET /dashboard/notifications` | `{ notifications, count }` | `getNotificationsListe()`¹ | ✅ Conforme |
| `GET /dashboard/notifications/liste` | `{ notifications[], total, nb_non_lues }` | `getNotificationsListe()` | ✅ Conforme |
| `PATCH /dashboard/notifications/:id` | body: `{lue}` | `marquerNotificationLue()` | ✅ Conforme |
| `PATCH /dashboard/notifications/tout-lire` | — | `marquerToutesLues()` | ✅ Conforme |

¹ `getNotificationsListe()` appelle `/dashboard/notifications/liste` (la route paginée).  
`/dashboard/notifications` (alias non paginé) n'est pas appelé directement.

### Routes `/api/v1/paiement`
| Endpoint | Backend | Mobile | Statut |
|---|---|---|---|
| `GET /paiement/statut` | `{ statut_tenant, abonnement: { message_confirmation, ... } }` | `getAbonnementActif()` | ✅ Corrigé (4.5) |
| `POST /paiement/soumettre` | multipart: `preuve, plan_id, methode_paiement, periodicite, numero_expediteur` | `soumettrePreuvePaiement()` | ✅ Corrigé (4.2) |
| `GET /paiement/historique` | `{ abonnements: [...{ plan_nom, plan_prix_mensuel }] }` | `getHistoriqueAbonnements()` | ✅ Corrigé (4.6) |
| `GET /paiement/notifications` | `{ notifications, count, non_lues }` | `getPaiementNotifications()` | ✅ Conforme |
| `GET /paiement/reference` | `{ reference, instructions[] }` | `getReferencePaiement()` | ✅ Conforme |

---

## Fichiers modifiés — récapitulatif complet

| Fichier | Corrections appliquées |
|---------|----------------------|
| `lib/config/app_config.dart` | 4.1 : apiBaseUrl |
| `lib/services/api_service.dart` | 4.1 : ClientException, 4.2 : numeroExpediteur, 4.5 : commentaire, S5-A : updateCodePromo supprimé, S5-B : getCategories supprimé |
| `lib/services/payment_upload_service.dart` | 4.2 : numeroExpediteur dans PendingUpload/uploadPreuve/_attemptUpload/retry |
| `lib/services/notification_service.dart` | 4.5 : "38h"→"48h" dans body notification |
| `lib/screens/plans/plans_screen.dart` | 4.2 : champ UI + validation, 4.5 : textes 38h→48h, message_38h→message_confirmation |
| `lib/screens/plans/abonnement_historique_screen.dart` | 4.6 : planNomEffectif |
| `lib/screens/restaurant/codes_promo_screen.dart` | 4.3 : clé réponse, S5-A : toggle désactivé |
| `lib/screens/restaurant/livreurs_screen.dart` | 4.4 : édition mode limité, _save() actif seulement |
| `lib/models/livreur_model.dart` | 4.3 : CodePromoModel.fromJson/toJson champs |
| `lib/models/tenant_model.dart` | 4.5 : message38h→messageConfirmation, 38h→48h |
| `lib/models/plan_model.dart` | 4.5 : commentaires, 4.6 : planNomPlat+planNomEffectif |

---

## État du build

```
flutter analyze → 1 warning bénin (unused_element_parameter, non bloquant)
flutter build apk --release → ✅ Succès
APK : build/app/outputs/flutter-apk/app-release.apk (60.3 MB)
Package : com.monmenumanager.manage
Signing : release-key.jks (RSA 2048, validité 10 000 jours)
```

---

## Limitations connues (non corrigibles sans modification backend)

1. **Toggle actif codes promo** : `PATCH /dashboard/codes-promo/:id` n'existe pas côté backend. Le switch actif/inactif est désactivé dans l'UI. Solution : le backend devrait implémenter cet endpoint ou l'UI pourrait proposer un workflow delete+recreate.

2. **Édition nom/WhatsApp livreur** : `PATCH /dashboard/livreurs/:id` ne lit que `actif`. Modifier le nom ou le numéro nécessite de supprimer le livreur et d'en créer un nouveau.

3. **Montant minimum commande (codes promo)** : le champ `min_commande` n'est pas supporté par le backend. La fonctionnalité est signalée comme "à venir" dans l'UI.

4. **Réinitialisation mot de passe** : les routes `/auth/forgot-password`, `/auth/verify-otp`, `/auth/reset-password` existent côté backend mais ne sont pas encore implémentées dans l'application mobile.

---

## Session du 2025-01-10 — Corrections 2.1 · 2.2 · 3.1 · 3.2

### Contexte
Corrections rendues possibles après l'ajout de deux nouvelles routes backend
(déployées côté Cloudflare Workers entre les sessions) et audit complet du
mécanisme OTP de Supabase Auth utilisé par le backend.

**Routes nouvellement disponibles confirmées en production (HTTP 401 avec header
CSRF = route existe) :**
- `PATCH /api/v1/dashboard/codes-promo/:id` — activer/désactiver un code promo
- `PATCH /api/v1/dashboard/livreurs/:id` (élargi) — modifier nom, whatsapp_number, actif
- `POST /api/v1/dashboard/profil/change-password` — déjà présente, désormais câblée

**Audit OTP confirmé (lecture de api-auth.ts) :**
- Backend utilise `supabase.auth.signInWithOtp()` → envoie un **code à 6 chiffres**, jamais un lien
- `verify-otp` attend `{ email, token }` avec `type: 'email'` (non `OtpType.recovery`)
- `reset-password` attend `Authorization: Bearer <access_token>` renvoyé par `verify-otp`

---

### Correction 2.1 — Réactivation toggle actif codes promo

**Fichiers modifiés :**
- `lib/services/api_service.dart`
- `lib/screens/restaurant/codes_promo_screen.dart`

**Problème :** `PATCH /dashboard/codes-promo/:id` n'existait pas lors de l'audit S5.
Le switch était désactivé (`onChanged: null`) avec un tooltip d'explication.
La route a depuis été ajoutée côté backend.

**Correction :**
1. Ajout de `updateCodePromoActif(String id, bool actif)` dans `ApiService` :
   ```dart
   Future<ApiResponse> updateCodePromoActif(String id, bool actif) async =>
       patch('/dashboard/codes-promo/$id', {'actif': actif});
   ```
2. `_toggleActif()` : réécriture avec **optimistic update** + rollback en cas d'erreur.
3. Suppression du `Tooltip` et restauration de `onChanged: (_) => onToggle()`.
4. Récupération de `api` en début de méthode (lint `use_build_context_synchronously`).

**Triple-vérification :**
- `grep "onChanged: null"` → 0 résultat ✅
- `grep "Modification non disponible"` → 0 résultat ✅
- Body backend vérifié : `{ actif: bool|0|1 }` → réponse `{ success, actif: 0|1 }` ✅

---

### Correction 2.2 — Restauration édition complète des livreurs

**Fichiers modifiés :**
- `lib/screens/restaurant/livreurs_screen.dart`

**Problème :** En mode édition, le dialogue `_LivreurDialog` masquait les champs
`nom` et `whatsapp_number`, affichait un message de limitation, et envoyait uniquement
`{'actif': _actif}`. La route PATCH était limitée à `actif` seulement.
La route backend a depuis été élargie pour accepter `nom`, `whatsapp_number` et `actif`
indépendamment.

**Correction :**
1. Suppression du bloc `if (!_isEdit) ... else ...` conditionnel.
2. Champs `nom` (requis) et `WhatsApp` (optionnel en édition) présents dans **les deux modes**.
3. `_save()` en mode édition : envoi sélectif — seuls les champs modifiés sont inclus :
   ```dart
   if (nomTrimmed != widget.livreur!.nom) payload['nom'] = nomTrimmed;
   if (waTrimmed != (widget.livreur!.whatsappNumber ?? '')) payload['whatsapp_number'] = waTrimmed;
   ```
4. Validation côté client conforme aux règles backend :
   - `nom` : minimum 2 caractères
   - `whatsapp_number` : regex `^\+?[0-9\s\-]{8,20}$`
5. Suppression du message de limitation.

**Triple-vérification :**
- `grep "Seul le statut actif/inactif"` → 0 résultat ✅
- `grep "supprimez et recréez"` → 0 résultat ✅
- Validation regex identique à celle du backend (api-dashboard.ts ligne 911) ✅

---

### Correction 3.1 — Changement MDP utilisateur connecté

**Fichiers modifiés :**
- `lib/screens/auth/change_password_screen.dart`
- `lib/services/auth_service.dart`

**Problème :** `AuthService.changePassword()` appelait directement le SDK Supabase
(`signInWithPassword` + `updateUser`) au lieu de passer par le backend Workers.
La route `POST /api/v1/dashboard/profil/change-password` existait mais n'était pas utilisée.

**Body confirmé (api-dashboard.ts ligne 1236) :**
```json
{ "current_password": "...", "new_password": "..." }
```
Réponse : `{ "success": true, "message": "Mot de passe mis à jour." }`

**Correction :**
1. `AuthService.changePassword()` réduite à la validation côté client uniquement
   (éviter la dépendance circulaire `AuthService ↔ ApiService`).
2. `change_password_screen.dart` : appel `ApiService.post('/dashboard/profil/change-password', {...})`
   directement après la validation. Le Bearer token est ajouté automatiquement par `ApiService._headers`.
3. Gestion des codes d'erreur : 401 = mdp actuel incorrect, 422 = format invalide.
4. `context.read<ApiService>()` déplacé avant le premier gap async.

**Triple-vérification :**
- Route testée en production → HTTP 401 (authentification requise, route existe) ✅
- Body fields `current_password` / `new_password` conformes à api-dashboard.ts ✅
- Aucun appel `signInWithPassword` / `updateUser` résiduel ✅

---

### Correction 3.2 — Mot de passe oublié (flux OTP 6 chiffres)

**Fichiers modifiés :**
- `lib/screens/auth/forgot_password_screen.dart` (réécriture complète de la logique)
- `lib/services/auth_service.dart`
- `lib/services/api_service.dart` (ajout de `postPublic()` et `postWithBearer()`)

**Problème (double) :**
1. `AuthService.sendPasswordResetOtp()` appelait `supabase.auth.resetPasswordForEmail()`
   qui envoie un **lien** — alors que le backend envoie un **code à 6 chiffres**.
2. `AuthService.resetPasswordWithOtp()` appelait `verifyOTP` avec `OtpType.recovery`
   alors que le backend utilise `type: 'email'`.
3. L'étape 2 de `forgot_password_screen.dart` n'appelait **pas le backend** — elle
   passait directement à l'étape 3 sans vérifier le code.
4. L'`access_token` nécessaire pour l'étape 3 n'était jamais récupéré.

**Flux correct confirmé (lecture api-auth.ts) :**
```
Étape 1 : POST /auth/forgot-password { email }
          → supabase.signInWithOtp() → code 6 chiffres envoyé
          → réponse neutre (ne révèle pas l'existence du compte)

Étape 2 : POST /auth/verify-otp { email, token }   ← token = /^\d{6}$/
          → supabase.verifyOtp({ type: 'email' })
          → réponse : { access_token, refresh_token, message }

Étape 3 : POST /auth/reset-password { password }
          → Authorization: Bearer <access_token de l'étape 2>
          → réponse : { success, message }
```

**Correction :**
1. `ApiService.postPublic()` : POST sans Bearer (routes /auth/* publiques).
2. `ApiService.postWithBearer(bearer: token)` : POST avec Bearer personnalisé (étape 3).
3. `forgot_password_screen.dart` totalement réécrit :
   - Étape 2 `_verifyOtp()` : appel réel `POST /auth/verify-otp` → récupère `access_token`.
   - `_otpAccessToken` stocké **en mémoire uniquement** (jamais sur disque, jamais loggé).
   - Étape 3 `_resetPassword()` : utilise `postWithBearer(bearer: _otpAccessToken!)`.
   - Token effacé après utilisation (`_otpAccessToken = null`).
   - Cooldown 60s sur bouton "Renvoyer" (rate-limit backend : 5/heure/IP).
4. `AuthService` : méthodes OTP réduites à de la validation côté client uniquement.
   Ajout de `validateEmailForOtp()`, `validateOtpCode()`, `validateNewPassword()`.

**Sécurité :**
- OTP jamais loggé ni persisté ✅
- `access_token` temporaire uniquement en mémoire, effacé après usage ✅
- Messages d'erreur génériques (ne révèle pas l'existence d'un compte) ✅
- Cooldown UI 60s aligné sur le rate-limit backend ✅

**Triple-vérification :**
- `grep "OtpType.recovery"` → 0 occurrence en code actif ✅
- `grep "resetPasswordForEmail"` → 0 occurrence en code actif ✅
- `grep "redirectTo"` → 0 résultat ✅
- `_otpAccessToken` ne figure dans aucun `debugPrint` ✅

---

### Résultat de la session

**flutter analyze :**
```
4 issues (warning + 3 info) — tous préexistants, aucun dans les fichiers modifiés
Nos fichiers : 0 erreur, 0 warning ✅
```

**APK release :**
```
flutter build apk --release → ✅ Succès
APK : build/app/outputs/flutter-apk/app-release.apk (60.3 MB)
Package : com.monmenumanager.manage
Signing : release-key.jks (RSA 2048, alias: monmenu, validité 10 000 jours)
```

**Limitations corrigées (étaient dans la section ci-dessus) :**
1. ~~Toggle actif codes promo~~ → **corrigé** (2.1)
2. ~~Édition nom/WhatsApp livreur~~ → **corrigé** (2.2)
3. ~~Réinitialisation mot de passe~~ → **corrigé** (3.2)
4. Montant minimum commande (codes promo) — toujours en attente backend
