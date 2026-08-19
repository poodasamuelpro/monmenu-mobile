# PRÉ-REQUIS BACKEND — monmenu-mobile

Ce document liste les dépendances backend (monmenu web, Cloudflare Workers + Supabase)
dont l'application mobile a besoin pour fonctionner à parité. **Aucune modification côté
web n'est requise** : tous les contrats listés existent déjà à HEAD `98223df`.

## 1. Reset mot de passe — OTP 8 chiffres (P0)
- Le template email Supabase **« Reset Password »** doit contenir `{{ .Token }}`
  (code numérique) et **non** `{{ .ConfirmationURL }}` (lien).
- Supabase Dashboard → Authentication → Email Templates → Reset Password.
- Longueur OTP : 8 chiffres (config Supabase `otp_length = 8` ou valeur projet actuelle).
- Routes utilisées par le mobile :
  - `POST /api/v1/auth/forgot-password` `{ email }`
  - `POST /api/v1/auth/verify-otp` `{ email, token }` (token = 8 chiffres, type `recovery`)
  - `POST /api/v1/auth/reset-password` `{ password }` + `Authorization: Bearer <token étape 2>`

## 2. Accès tenant 6 modes (P1)
- Contrat `src/lib/acces-tenant.ts` : modes `actif`, `essai`, `grace_confirmation` (<72h),
  `paiement_initial`, `bloque`, `suspendu`, `introuvable`.
- Le mobile réplique cette logique côté client à partir de `GET /dashboard/profil`
  (statut + abonnement en attente). Aucun endpoint supplémentaire requis.

## 3. Suppléments (P2)
- Routes `src/routes/api-supplements.ts` (Bearer exempté de CSRF) :
  `GET /dashboard/supplements`, `GET /dashboard/supplements/limite`,
  `POST /dashboard/supplements`, `PATCH|DELETE /dashboard/supplements/:id`,
  `POST /dashboard/supplements/:id/image` (multipart `file`, 5 Mo max).
- La purge R2 de l'ancienne photo est faite **côté serveur** lors du remplacement.

## 4. Suppression de compte (P3)
- `POST /dashboard/compte/demander-suppression` (429 si >3/24h)
- `POST /dashboard/compte/annuler-suppression`
- La **confirmation finale** passe par le lien email
  (`GET /dashboard/compte/confirmer-suppression?token=`) — hors application mobile,
  le mobile informe l'utilisateur qu'un email de confirmation a été envoyé.

## 5. Upload apparence (P4)
- `POST /dashboard/upload-image` : multipart `file` + champ optionnel `ancienne_cle`
  (doit commencer par `${tenant_id}/`) pour purge R2 de l'ancien fichier.
- `PATCH /dashboard/apparence` : `{ couleur_primaire?, couleur_secondaire?, logo_url?, banniere_url? }`
  (couleurs au format `#RRGGBB`).

## 6. Stats (P5)
- `GET /dashboard/stats` : `statuts = { livree, annulee }` uniquement.
  Le mobile calcule « en cours » = `total − livree − annulee`.

## 7. Notifications paiement (P6)
- `GET /api/v1/paiement/notifications` → `{ notifications[], count, non_lues }`
  (notifications planifiées essai-expire / paiement-attente + notifications DB non lues).

## 8. X-Tenant-Slug (P8)
- Les routes commandes acceptent `X-Tenant-Slug` (header) ou `body.slug`
  (`src/routes/api-commandes.ts` l.138, 589). Le mobile envoie désormais le header
  sur toutes les requêtes authentifiées (inoffensif sur les routes qui l'ignorent).

## 9. Purge R2 des photos produits (M2 — correction web recommandée)
**Constat (HEAD 98223df)** : `PATCH /dashboard/produits/:id` (`src/routes/api-dashboard.ts`
l.804-840) met à jour `photo_url`/`photo_r2_key` **sans purger l'ancien objet R2**,
contrairement à `PATCH /dashboard/supplements/:id` (l.1042) qui lit `photo_r2_key`
avant l'UPDATE et supprime l'ancien fichier.

**Côté mobile (déjà fait, M2)** : l'upload d'une nouvelle photo produit passe par
`POST /dashboard/upload-image` avec `ancienne_cle` extraite de `photo_url`
(`GET /dashboard/menu` ne renvoie pas `photo_r2_key`) → la purge est effectuée
au moment de l'upload. La clé n'est PAS envoyée si l'URL est suspecte
(absence du marqueur `/dashboard/media/`, clé vide ou contenant `..`).

**Correction web recommandée** : répliquer dans `PATCH /produits/:id` le pattern
de `PATCH /supplements/:id` l.1042 (lire `photo_r2_key` avant UPDATE, purger R2
si la photo change) pour couvrir aussi les mises à jour effectuées depuis le
dashboard web.

## 10. plan_id dans GET /dashboard/profil (M4 — aucun changement web requis)
**Constat (HEAD 98223df)** : `GET /dashboard/profil` (`src/routes/api-dashboard.ts`
l.1495-1541) retourne déjà `plan_id` (et `email`) via le spread `...tenantFinal`
dont le select inclut ces colonnes. **Aucune modification web nécessaire** :
le mobile consomme directement `plan_id` (surlignage du plan actuel dans
l'écran Plans, fallback `plan_nom` si `plan_id` est null).

## 11. Magic bytes sur setup-restaurant (M9 — correction web recommandée)
**Constat (HEAD 98223df)** : `POST /dashboard/setup-restaurant`
(`src/routes/api-dashboard.ts` l.2225-2262) écrit logo/bannière dans R2 avec
`contentType: file.type` (MIME déclaré par le client) **sans validation des
magic bytes**, alors que les autres routes d'upload valident le contenu réel :
- `POST /dashboard/upload-image` → `validerMimeImageUnifie` (import l.116)
- `POST /paiement/upload-preuve` → `validerMimeImageUnifie`
  (`api-paiement.ts` l.294, pattern A-04)

**Risque** : un fichier non-image (HTML/SVG avec script, exécutable) peut être
stocké et servi avec un Content-Type image détourné.

**Correction web recommandée** : dans setup-restaurant (~l.2228-2260), avant
chaque `R2.put`, lire le buffer et appeler `validerMimeImageUnifie(buffer)`
(`src/lib/validation.ts` l.54) ; si retour `null` → réponse 415, sinon utiliser
le MIME détecté (pas `file.type`) comme `contentType`. Répliquer exactement le
pattern d'`api-paiement.ts` l.294.

**Côté mobile** : aucun impact — le mobile n'appelle pas setup-restaurant
(onboarding effectué sur le web).

## Récapitulatif
| Pré-requis | État backend | Action requise |
|---|---|---|
| Template email OTP 8 chiffres | À vérifier dans Supabase Dashboard | ✅ Vérifier `{{ .Token }}` |
| Toutes les routes API listées | Présentes à HEAD 98223df | Aucune |
| CSRF exemption Bearer | En place (api-supplements.ts) | Aucune |
| Purge R2 photos produits (PATCH produits/:id) | Absente à HEAD 98223df | Copier pattern supplements l.1042 |
| Magic bytes setup-restaurant | Absents à HEAD 98223df | validerMimeImageUnifie avant R2.put (pattern api-paiement l.294) |
