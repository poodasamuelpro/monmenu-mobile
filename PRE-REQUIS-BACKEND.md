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

## Récapitulatif
| Pré-requis | État backend | Action requise |
|---|---|---|
| Template email OTP 8 chiffres | À vérifier dans Supabase Dashboard | ✅ Vérifier `{{ .Token }}` |
| Toutes les routes API listées | Présentes à HEAD 98223df | Aucune |
| CSRF exemption Bearer | En place (api-supplements.ts) | Aucune |
