# RAPPORT D'AUDIT — SESSION 7 (M1–M9)

**Projet** : monmenu-mobile (branche `main`)
**Source de vérité** : monmenu web (read-only, HEAD `98223df`, jamais modifié)
**Base de session** : `88e21f4` (fin session P0-P11) → audit `4255f42` → corrections `8a0f6b7..441f72b`
**Méthodologie** : double audit avant (audit-avant.md § Session 7) → correction atomique → push immédiat après chaque tâche → triple audit après.

---

## Tableau récapitulatif par tâche

| Tâche | Sévérité | Statut | Commit | Fichiers / lignes clés | Preuve |
|---|---|---|---|---|---|
| **M1** — Email restaurant éditable | MAJEUR | ✅ Corrigé | `8a0f6b7` | `plan_model.dart` (ProfilModel + `email`), `settings_screen.dart` (tile E-mail section Compte, dialog + regex web, PATCH /parametres avec `nom` requis) | analyze 0, tests OK |
| **M2** — Upload menu avec `ancienne_cle` | MAJEUR | ✅ Corrigé | `3642862` | `menu_screen.dart` `_uploadImage` + `_extraireCleR2` (clé après `/dashboard/media/`, rejet `..`/vide) ; doc web PRE-REQUIS §9 | analyze 0 |
| **M3** — restaurant_screen jamais figé | MAJEUR | ✅ Corrigé | `88b2e37` | `restaurant_screen.dart` : gardes `_pdv != null` retirées (AppBar + body), pré-remplissage nom tenant, 401 → bandeau warning non bloquant + Réessayer, champ `_pdv` supprimé | analyze 0, tests OK |
| **M4** — Plan actuel surligné | MOYEN | ✅ Corrigé | `5fe81cd` | `plan_model.dart` (+`planId`), `plans_screen.dart` l.123 : `isCurrent = planId == plan.id` fallback `planNom` ; PRE-REQUIS §10 (plan_id **déjà exposé** par le web) | analyze 0 |
| **M5** — Champs /paiement/statut consommés | MOYEN | ✅ Corrigé | `0e3d207` | `dashboard_provider.dart` (getters `slaAdminHeures`, `fenetreAccesHeures`, `planInitialNom/Prix`, `dateFin`, `modeAccesServeur`, `heuresRestantesServeur`), `payment_alert_banner.dart` (serveur-first, plus de « 48h » hardcodé), `plans_screen.dart` (_EnAttenteCard + date_fin sur abonnement actif) | analyze 0 |
| **M6** — Retry file upload | MOYEN | ✅ Corrigé | `d2c8e75` | `main.dart` : `retryPendingUploadIfNeeded()` au démarrage (garde `isAuthenticated`) + regain réseau (`connectivity_plus` onConnectivityChanged), anti-réentrance, SEC-07 conservé | analyze 0, tests OK |
| **M7** — Souscriptions Realtime | MINEUR | ✅ Documenté | `5a10547` | Notes d'architecture dans `realtime_service.dart` + `notification_service.dart` : 4 channels / 2 tables assumés (providers vs toasts, cycles de vie distincts, channels uniques) | analyze 0 |
| **M8** — Parsing stats-journalières | MINEUR | ✅ Corrigé | `320c272` | `plan_model.dart` : `StatsModel.fromStatsJournalieres` parse le contrat réel `{stats[], totaux{}, periode_jours}` (DESC→ASC) ; `dashboard_provider.loadStatsJournalieres` l'utilise | analyze 0, tests OK |
| **M9** — Magic bytes setup-restaurant | doc only | ✅ Documenté | `441f72b` | PRE-REQUIS §11 : `validerMimeImageUnifie(buffer)` avant `R2.put` (~l.2228-2260), 415 si null, pattern `api-paiement.ts` l.294 — aucun impact mobile | analyze 0 |

---

## Découvertes de l'audit avant (consignées dans audit-avant.md, commit `4255f42`)

1. **`email` et `plan_id` déjà exposés** par `GET /dashboard/profil` (spread `...tenantFinal`) à web HEAD `98223df` → la « modif web M4 » du prompt était déjà effective ; M1/M4 mobile consomment directement.
2. **Contrat M8 réel** : `{stats, totaux, periode_jours}` (pas de clé `journalieres`) — le bug était l'enveloppe passée à `StatsModel.fromJson`, pas `StatJournaliere.fromJson`.
3. **Piège PATCH /parametres** : `nom` requis (≥2 chars, 422 sinon) même pour éditer l'email seul → le mobile renvoie toujours le nom actuel.
4. **GET /dashboard/menu sans `photo_r2_key`** : confirmé → extraction de la clé depuis `photo_url` (seul chemin possible).

## Corrections web documentées (web JAMAIS modifié)

| # | Section PRE-REQUIS-BACKEND.md | Nature |
|---|---|---|
| 1 | §9 — Purge R2 photos produits | `PATCH /produits/:id` (l.804-840) ne purge pas R2 → copier pattern supplements l.1042 |
| 2 | §10 — plan_id dans /profil | **Aucun changement requis** (déjà exposé à HEAD 98223df) |
| 3 | §11 — Magic bytes setup-restaurant | `validerMimeImageUnifie` absent avant `R2.put` → 415 si invalide, pattern api-paiement l.294 |

---

## Checklist finale (6 points)

- [x] **1. `flutter analyze` = 0 issue** — vérifié après chaque tâche et en final (« No issues found! »)
- [x] **2. Écrans jamais figés** — restaurant_screen affiche toujours le formulaire (pdv null → pré-rempli nom tenant ; 401 → bandeau non bloquant + Réessayer)
- [x] **3. MIME/uploads** — `ancienne_cle` validée avant envoi (préfixe `/dashboard/media/`, rejet `..`) ; magic bytes web documentés (M9)
- [x] **4. Régression P0-P11 : AUCUNE** — marqueurs vérifiés : verify-otp (P0), accesAbonnementSeul (P1), ancienneCle apparence (P4), commandesEnCours (P5), X-Tenant-Slug (P8) tous intacts ; `flutter test` OK
- [x] **5. PRE-REQUIS-BACKEND.md à jour** — 3 entrées web ajoutées (§9, §10, §11) + récapitulatif enrichi
- [x] **6. Rapport livré** — ce fichier, commité avec le dernier commit de la session

## État final

- **Historique session 7** : `4255f42` (audit) → `8a0f6b7` (M1) → `3642862` (M2) → `88b2e37` (M3) → `5fe81cd` (M4) → `0e3d207` (M5) → `d2c8e75` (M6) → `5a10547` (M7) → `320c272` (M8) → `441f72b` (M9) — **tous poussés sur origin/main après chaque tâche** (règle user respectée, aucun force-push).
- **Web** : read-only, HEAD `98223df`, jamais modifié, jamais poussé.
- **Build** : `flutter analyze` 0 issue, `flutter test` tous verts.
