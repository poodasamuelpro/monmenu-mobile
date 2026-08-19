# AUDIT AVANT CORRECTION — monmenu-mobile

Date : 2026-02-27
Baseline mobile : HEAD `1b79ac4` (branche main) — `flutter analyze` = **No issues found!** (baseline_analyze.txt)
Référence web (lecture seule) : monmenu HEAD `98223df`

---

## PASSE A — Contrats web (source de vérité, avec numéros de lignes)

### A.1 Reset mot de passe (P0) — `src/routes/api-auth.ts`
- l.557-608 `POST /auth/forgot-password` : `resetPasswordForEmail()`, réponse générique
  « Si ce compte existe, un code de récupération à 8 chiffres a été envoyé à votre adresse. »
- l.610-668 `POST /auth/verify-otp` : validation `!/^\d{8}$/.test(body.token)` → 422
  « Email et code à 8 chiffres requis. » ; `supabase.auth.verifyOtp({ email, token, type: 'recovery' })` ;
  réponse `{ access_token, refresh_token, message }`.
- l.670-726 `POST /auth/reset-password` : Bearer (token issu du verify-otp), `new_password` ≥ 8,
  rejet si identique à l'ancien (422), signout global après succès, réponse
  `{ success: true, message: 'Mot de passe mis à jour avec succès. Veuillez vous reconnecter.' }`.
- **Contrat : OTP = 8 chiffres** (le mobile en attend 6).

### A.2 Accès tenant 6 modes (P1) — `src/lib/acces-tenant.ts` (fichier entier)
Ordre de priorité web :
1. `statut === 'actif'` → mode `actif`, accès complet.
2. `statut === 'essai'` ET essai non expiré → mode `essai`, accès complet
   (essai expiré → continue vers les vérifications suivantes).
3. `statut === 'suspendu'` → mode `suspendu`, **aucun accès**.
4. Abonnement `en_attente_confirmation` avec `delai_confirmation_expire_le` valide (<72h)
   → mode `grace_confirmation`, accès complet.
5. Abonnement `en_attente_paiement_initial` → mode `paiement_initial`, accès abonnement seul.
6. Sinon (`inactif`/autre) → mode `bloque`, accès abonnement seul.
`introuvable` si tenant absent.
**Résultat web : `accesComplet` vs `accesAbonnementSeul`** — un tenant bloqué peut TOUJOURS
accéder aux pages plans/paiement (jamais éjecté de la session).

### A.3 Suppléments (P2)
- `docs/API-SUPPLEMENTS.md` (entier) : spec Dart `SupplementGeneral{id, nom, prix double, photoUrl?}`,
  `supplement_ids` max 10 côté commande, jamais de prix calculés côté client.
- `src/routes/api-supplements.ts` :
  - l.111+ `GET /dashboard/supplements` → `{ supplements: [{id, nom, prix, photo_url, photo_r2_key, actif, ordre_affichage, created_at, updated_at}] }`
  - `GET /dashboard/supplements/limite` → `{ actif, limite, utilises }`
  - `POST /dashboard/supplements` `{nom (1-100), prix (0-999999), actif=true, ordre=0}` → 201 `{ success, id }`
  - `PATCH /dashboard/supplements/:id` (au moins un champ) → `{ success }`
  - `DELETE /dashboard/supplements/:id` → soft-delete + purge R2
  - `POST /dashboard/supplements/:id/image` multipart champ `file` (5 Mo max, jpeg/png/webp/gif)
    → `{ success, url, key }` — **le serveur purge automatiquement l'ancienne photo_r2_key**.
  - Middleware CSRF : requêtes `Authorization: Bearer` **exemptées** → OK pour le mobile.
- `src/pages/dashboard.ts` l.40-64 : sidebar web — Suppléments = **3e entrée, après Menu**
  (`/dashboard/supplements`).
- Nuance importante : `GET /dashboard/menu` (api-dashboard.ts l.565-618) ne renvoie **pas**
  de `supplements[]` — seule la route publique `GET /tenants/:slug/menu` l'ajoute. L'écran
  admin mobile utilisera donc `GET /dashboard/supplements` (contrat backend réel).

### A.4 Suppression de compte (P3) — `src/routes/api-dashboard.ts` l.2547-2790
- `POST /dashboard/compte/demander-suppression` → `{ success, message, suppression_prevue_le }` ;
  429 si >3 demandes/24h.
- `GET /dashboard/compte/confirmer-suppression?token=` : lien HTML **email uniquement** (hors mobile).
- `POST /dashboard/compte/annuler-suppression` → `{ success, message }` ;
  422 « Aucune demande de suppression en cours. » si aucune demande.
- Pas de route dédiée « statut-suppression » : l'état vit sur les champs tenant
  (`suppression_demandee_le`, `suppression_prevue_le`) — le mobile lira les réponses
  demander/annuler et le profil.

### A.5 Apparence + upload (P4) — `src/routes/api-dashboard.ts`
- l.1374-1415 `PATCH /dashboard/apparence` : `{couleur_primaire?, couleur_secondaire?, logo_url?, banniere_url?}`,
  regex couleur `^#[0-9A-Fa-f]{6}$`.
- l.1940-2060 `POST /dashboard/upload-image` : multipart champs `file` + `ancienne_cle` (optionnel,
  validée : commence par `${tenant_id}/`, pas de `..`) → purge R2 de l'ancienne clé.

### A.6 Stats (P5) — `src/routes/api-dashboard.ts` l.505-563
`GET /dashboard/stats` : `statuts = { livree, annulee }` **uniquement** (pas de `en_attente`),
champs `today, ca_today, month, ca_month, taux_livraison, taux_annulation, nb_produits, labels, values, ca_values`.
→ « commandes en cours » web = `total - livree - annulee`.

### A.7 Notifications paiement (P6) — `src/routes/api-paiement.ts` l.561-680
`GET /paiement/notifications` → `{ notifications: [{id, type, titre, message, action?: {label, href}, created_at}], count, non_lues }`.
Notifications planifiées : `essai-expire` (error ≤2 j, warning ≤5 j), `paiement-attente`
(warning <10 h, info sinon). Les `href` web (ex. `/dashboard/parametres`) diffèrent des routes mobiles.

### A.8 Change-password (P7) — `src/routes/api-dashboard.ts` l.1543-1659
`POST /dashboard/profil/change-password` `{current_password, new_password}` : révoque **toutes les
sessions** (signout global), crée une notification lien `/dashboard/parametres`, réponse
`{ success, message: 'Mot de passe mis à jour.' }`. Comportement web après succès :
message « Mot de passe modifié. Veuillez vous reconnecter. » + retour login.

### A.9 X-Tenant-Slug (P8) — `src/routes/api-commandes.ts` l.138, 589
`c.req.header('X-Tenant-Slug') || body.slug` — le tenant est résolu par header ou body.slug,
jamais par body.tenant_id (FINDING-05).

### A.10 Sidebar web (P9) — `src/pages/dashboard.ts` l.40-64
Ordre : Commandes, Menu, **Suppléments**, Statistiques, Livreurs, QR Code, Codes promo, PDV…
Historique paiements accessible depuis la zone Plans & Paiement.

---

## PASSE B — Cartographie mobile (points d'insertion + risques de régression)

### B.1 `lib/services/api_service.dart` (504 l.)
- `_headers` l.19-27 → **P8** : ajouter `X-Tenant-Slug` (slug lu depuis AuthService/secure storage).
- `uploadImage(String filePath)` l.375-420 → **P4** : param optionnel `ancienneCle` →
  `request.fields['ancienne_cle']`.
- `getPaiementNotifications()` l.458 : méthode morte → **P6** : à câbler.
- À ajouter : `getSupplements`, `getSupplementLimite`, `createSupplement`, `updateSupplement`,
  `deleteSupplement`, `uploadSupplementImage` (**P2**) ; `demanderSuppressionCompte`,
  `annulerSuppressionCompte` (**P3**).
- Risque régression : `_headers` est utilisé par tous les appels — l'ajout du header doit être
  inoffensif si slug absent (header omis).

### B.2 `lib/services/auth_service.dart` (432 l.)
- `validateOtpCode` l.289-296 : regex 6 chiffres → **P0** : 8 chiffres.
- Bloc commentaire l.261-276 décrivant flux 6 chiffres → **P0** : mettre à jour.
- `login`/`_fetchTenantForUser` l.149-244 : vérifie `suspendu` mais aucun routage inactif →
  **P1** : exposer le mode d'accès pour rediriger vers `/dashboard/plans`.
- Sécurité à préserver : token jamais loggé, OTP jamais persisté (mémoire seulement).

### B.3 `lib/models/tenant_model.dart` (220 l.)
- `canAccess` l.173-176 : 3 modes seulement → **P1** : aligner sur les 6 modes web
  (actif, essai non expiré, grace_confirmation <72h, paiement_initial/bloque → accès abonnement seul,
  suspendu → aucun accès). Champs disponibles : `statut`, `essaiExpireLe`,
  `paiementEnAttente.delaiConfirmationExpireLe/estExpire`, getters `isActif/isEssai/isSuspendu/...`.

### B.4 `lib/screens/auth/forgot_password_screen.dart` (634 l.) — P0
Points 6→8 chiffres : l.2-15 (en-tête), l.41-44 (`List.generate(6,...)` controllers/focus),
l.118 (snack « 6 chiffres »), l.307 (label), l.357 (texte), l.373 (`List.generate(6,...)` UI),
l.377 (`i < 5`), l.395 (`length == 6`).
À conserver (conforme) : token mémoire seulement l.55/163, postWithBearer reset l.202-206.

### B.5 `lib/widgets/app_drawer.dart` (287 l.) — P2/P9
Item Menu se termine l.97 → insérer **Suppléments** juste après (3e position, parité web).
Plans & Paiement l.134-140 → insérer **Historique paiements** juste après.
`_NavItem` l.211-287 réutilisable tel quel.

### B.6 `lib/main.dart` (361 l.) — P2/P3
Router l.109-224 : ajouter `GoRoute /dashboard/supplements` et `/dashboard/settings/compte`.
`/dashboard/plans/historique` existe déjà l.184-189. Redirect l.112-120 : hook P1 possible
mais la redirection post-login sera gérée dans le flux de login (moins invasif).

### B.7 `lib/screens/restaurant/apparence_screen.dart` (511 l.) — P4
`_showUploadInfo` l.170-218 : faux dialogue redirigeant vers monmenu.app → remplacer par
vrai flux `ImagePicker` + compression + `uploadImage(ancienneCle: ...)` + `PATCH /dashboard/apparence`.
`_save` l.103-126 n'envoie que `couleur_primaire` → envoyer aussi logo_url/banniere_url après upload.
Pattern de référence éprouvé : `menu_screen.dart` l.633-700 (`ImagePicker` + `FlutterImageCompress`
+ `api.uploadImage`). Dépendances présentes dans pubspec : `image_picker ^1.1.2` ✔.

### B.8 `lib/models/plan_model.dart` (482 l.) — P5
`StatsModel.commandesPendantes` l.383 : `statuts['en_attente']` — champ **inexistant** dans le
contrat web (statuts = {livree, annulee}) → toujours 0. Corriger en
`totalCommandes - livree - annulee` (borné ≥ 0).

### B.9 `lib/screens/notifications/notifications_screen.dart` (621 l.) — P6
Whitelist l.165-179 : routes mobiles uniquement — les liens web
(`/dashboard/parametres`, `/dashboard/supplements`, etc.) ne matchent pas → navigation ignorée.
**P6** : table d'alias web→mobile + ajout des nouvelles routes ; câbler
`getPaiementNotifications()` (onglet/section Paiement).

### B.10 `lib/screens/auth/change_password_screen.dart` (267 l.) — P7
l.73-82 : snack + `context.pop()` — la session reste active alors que le web révoque toutes
les sessions → le token mobile devient invalide silencieusement. Correction : message
« Mot de passe modifié. Veuillez vous reconnecter. » + `auth.logout()` propre + `context.go('/login')`.

### B.11 `lib/screens/settings/settings_screen.dart` (271 l.) — P3
Section « Compte » l.89-101 : insérer l'entrée « Supprimer mon compte » → `/dashboard/settings/compte`.

### B.12 `lib/screens/commandes/commande_detail_screen.dart` — P9
Scaffold l.311 : pas de `drawer:` ; leading = back only → ajouter `drawer: const AppDrawer()`.

### B.13 `lib/screens/plans/abonnement_historique_screen.dart` — P9
Scaffold l.99 : pas de `drawer:` → ajouter `drawer: const AppDrawer()`.

### B.14 Hive (P10) — `lib/config/app_config.dart` l.49-52 + `lib/main.dart` l.72
Boxes déclarées (`commandes_cache`, `menu_cache`, `stats_cache`) + `Hive.initFlutter()` appelé,
mais **aucune box n'est ouverte ni utilisée** (grep `Hive.` = 1 seul hit : initFlutter).
Décision retenue (argumentée) : **retrait du code mort** — pas de cache offline exigé par le
périmètre, retirer `initFlutter()` + constantes réduit la surface et le poids ; les dépendances
pubspec sont conservées pour éviter un churn de lockfile (dead deps inoffensives, retrait
documenté comme suite possible).

### B.15 Risques de régression généraux (A1–A9 à ne pas casser)
- Méthodes de paiement dynamiques, référence paiement, preuve 8+ chiffres (plans_screen.dart) :
  ne pas toucher.
- Statuts commandes, realtime Supabase : ne pas toucher.
- Navigation notifications existante : la table d'alias doit être **additive** (les routes
  actuelles restent permises).
- `_headers` : header additionnel uniquement, aucune suppression.
- Sécurité : token jamais loggé, OTP en mémoire uniquement, HTTPS only — inchangé.

---

## Ordre d'exécution : P0 → P11, commits atomiques conventionnels, `flutter analyze` = 0 issue après chaque incrément.

---

# SESSION 7 — Double audit M1–M9 (avant correction)

## Passe A — Contrats web (HEAD 98223df, read-only)

- **M1/M4 — GET /dashboard/profil** (api-dashboard.ts l.1495-1541) : select tenants inclut
  `id, nom, slug, email, ..., plan_id` puis `c.json({ ...tenantFinal, plan_nom, ... })`.
  → **DÉCOUVERTE : `email` ET `plan_id` sont DÉJÀ exposés** par le spread à HEAD 98223df.
  La modif web M4 documentée dans le prompt est donc DÉJÀ EFFECTIVE — à consigner dans
  PRE-REQUIS-BACKEND.md comme "déjà présent, aucun changement requis".
- **M1 — PATCH /dashboard/parametres** (l.1420-1459) : body `{nom (REQUIS ≥2 chars),
  whatsapp_number?, email?}` ; email regex `^[^\s@]+@[^\s@]+\.[^\s@]+$`, 422 sinon ;
  email vide → null. ⚠️ `nom` toujours requis, même pour ne changer que l'email.
- **M2 — GET /dashboard/menu** (l.587) : select produits SANS `photo_r2_key`
  → le mobile DOIT extraire la clé depuis `photo_url` (fallback prompt). Pattern purge
  supplements PATCH l.1042 (photo_r2_key lu avant UPDATE) ; produits PATCH l.804-840 : pas de purge.
- **M3 — PATCH /dashboard/pdv** (l.1290+) : si aucun PDV → INSERT (nom défaut 'Mon restaurant',
  tarifs 500/200) → utilisable sans distinction création/édition. GET /pdv → { pdv: {...}|null }.
- **M5 — GET /paiement/statut** (api-paiement.ts l.103-174) : retourne `plan_initial_nom`,
  `plan_initial_prix_mensuel`, `abonnement.date_fin`, `sla_admin_heures` (=48),
  `fenetre_acces_heures` (=72), `mode_acces` (constantes src/lib/paiement.ts l.36/39).
- **M8 — GET /dashboard/stats-journalieres** (l.2115-2145) : retourne
  `{ stats: [{date, nb_commandes, nb_commandes_livrees, nb_commandes_annulees,
  chiffre_affaires, frais_livraison_total, top_produits}], totaux: {nb_commandes,
  chiffre_affaires, nb_jours_actifs, moyenne_journaliere}, periode_jours }`
  — ordre DESCENDANT par date. (Pas de clé "journalieres" : le contrat réel est {stats, totaux}.)
- **M9 — POST /dashboard/setup-restaurant** (l.2225-2262) : R2.put logo/bannière avec
  `contentType: file.type` SANS validerMimeImageUnifie → à documenter (web only).

## Passe B — État mobile (HEAD 88e21f4)

- **M1** : ProfilModel (plan_model.dart l.239-313) : PAS de champ `email` ni `planId`.
  settings_screen.dart l.146-147 : tile email = support MonMenu (statique).
- **M2** : menu_screen.dart `_uploadImage` l.658 : `api.uploadImage(filePath)` sans
  `ancienneCle` ; `_photoUrl` (l.606) contient l'URL actuelle du produit → source d'extraction.
- **M3** : restaurant_screen.dart l.186 : bouton Sauvegarder seulement si `_pdv != null` ;
  l.203 : `_pdv == null` → Center('Aucun point de vente configuré') FIGÉ (aucune action).
- **M4** : plans_screen.dart l.123 : `isCurrent: false` hardcodé (commentaire "plan.id non dispo").
- **M5** : dashboard_provider expose `_abonnementStatut` brut ; payment_alert_banner.dart
  l.65-78 : "48h" hardcodé + `heuresRestantesCalculees` local. Aucun champ M5 consommé.
- **M6** : retryPendingUploadIfNeeded (payment_upload_service.dart l.257) jamais appelé —
  PaymentUploadService instancié uniquement dans plans_screen. connectivity_plus ^6.1.3
  déjà dans pubspec (inutilisé).
- **M7** : notification_service (notif_tenant_, notif_commandes_) ET realtime_service
  (commandes_realtime_, tenant_statut_) écoutent les MÊMES tables (commandes, tenants) —
  4 souscriptions pour 2 tables. Usages distincts : toasts locaux vs refresh providers.
- **M8** : loadStatsJournalieres (dashboard_provider l.109-130) passe la réponse
  `{stats, totaux, periode_jours}` à `StatsModel.fromJson` qui attend
  `{labels, values, ca_values}` → parsing silencieusement vide (garde null masque).
  StatJournaliere.fromJson lui-même est correct champ à champ, c'est l'enveloppe qui est fausse.
