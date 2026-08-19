# RAPPORT FINAL — Mise en conformité monmenu-mobile vs monmenu (web)

- **Web (source de vérité, read-only)** : `poodasamuelpro/monmenu` HEAD `98223df` — jamais modifié.
- **Mobile (travail)** : `poodasamuelpro/monmenu-mobile`, branche `main`, baseline `1b79ac4`.
- **Gate d'entrée** : lecture intégrale AUDIT E1 + E2 ✅ ; double audit consigné dans `audit-avant.md` ✅.

---

## 1. Baseline avant / après

| Métrique | Avant (1b79ac4) | Après |
|----------|-----------------|-------|
| `flutter analyze` | 0 issues (baseline_analyze.txt) | **0 issues** |
| `flutter test` | passait | **All tests passed** |
| Écarts critiques ouverts (E1/E2) | 15 écarts E1–E15 | 0 côté mobile (2 dépendances backend documentées) |

## 2. Statut des corrections P0–P11

| # | Intitulé | Commit | Statut |
|---|----------|--------|--------|
| P0 | Reset MDP : OTP 8 chiffres, type `recovery`, message web exact | `9027342` | ✅ |
| P1 | 6 modes d'accès (parité acces-tenant.ts) + confinement tenant bloqué | `8dbaabb` | ✅ |
| P2 | Module Suppléments complet (model, 6 méthodes API, écran, drawer, route) | `5aecf4e` | ✅ |
| P3 | Suppression de compte (demander/annuler, 429/422, écran dédié) | `721ae44` | ✅ |
| P4 | Upload réel apparence + `ancienne_cle` + PATCH partiel | `47aa5d2` | ✅ |
| P5 | Stats : « En cours » = total serveur − livree − annulee | `83d1981` | ✅ |
| P6 | Notifications : alias web→mobile + section Paiement (GET /paiement/notifications) | `d6804c7` | ✅ |
| P7 | Change-password → déconnexion propre + /login | `33135fb` | ✅ |
| P8 | Header `X-Tenant-Slug` (JSON + multipart) | `b76d83e` | ✅ |
| P9 | Drawer universel : Historique paiements + drawer sur 2 écrans | `8c32ad7` | ✅ |
| P10 | Retrait code mort Hive (décision argumentée) | `208f559` | ✅ |
| P11 | Purge photos produits orphelines | — | ⚠️ Côté WEB uniquement (voir §5) |

Chaque commit est atomique, conventionnel (`fix:`/`feat:`/`refactor:`), avec `flutter analyze = 0` vérifié après chacun.

## 3. Statut des écarts E1–E15 (audit E1)

| Écart | Description | Résolution |
|-------|-------------|-----------|
| E1 | OTP reset MDP 6 vs 8 chiffres | ✅ P0 |
| E2 | Message reset non conforme | ✅ P0 (message web exact) |
| E3 | canAccess 3 modes vs 6 modes web | ✅ P1 |
| E4 | Tenant bloqué non confiné | ✅ P1 (routes permises : plans/settings/change-password/notifications) |
| E5 | Module Suppléments absent | ✅ P2 |
| E6 | Suppression de compte absente | ✅ P3 |
| E7 | Upload apparence factice (url_launcher) | ✅ P4 (upload réel + purge ancienne clé) |
| E8 | commandesPendantes toujours 0 | ✅ P5 |
| E9 | Total commandes = somme statuts partielle | ✅ P5 (total serveur exact) |
| E10 | Liens notifications web non navigables | ✅ P6 (alias + fallback) |
| E11 | Alertes paiement non affichées | ✅ P6 (section Paiement) |
| E12 | Change-password : 401 surprise post-révocation | ✅ P7 |
| E13 | X-Tenant-Slug absent | ✅ P8 |
| E14 | Drawer incomplet / écrans sans menu | ✅ P9 |
| E15 | Persistance Hive annoncée, jamais implémentée | ✅ P10 (retrait code mort) |

## 4. Commits de la session (base `1b79ac4`)

```
9027342 fix(auth): reset MDP aligné web — OTP 8 chiffres, type recovery (P0)
8dbaabb feat(acces): parité 6 modes acces-tenant.ts + confinement tenant bloqué (P1)
5aecf4e feat(supplements): module suppléments complet (P2)
721ae44 feat(compte): suppression de compte (P3)
47aa5d2 feat(apparence): upload réel logo/bannière avec ancienne_cle + PATCH apparence (P4)
83d1981 fix(stats): commandes en cours = total − livree − annulee (contrat statuts web) (P5)
d6804c7 feat(notifications): alias liens web→mobile + section alertes Paiement (P6)
33135fb fix(auth): change-password → déconnexion propre + retour login (P7)
b76d83e feat(api): header X-Tenant-Slug sur tous les appels authentifiés (P8)
8c32ad7 feat(nav): drawer universel — Historique paiements + drawer sur 2 écrans (P9)
208f559 refactor(cache): retrait du code mort Hive (persistance jamais implémentée) (P10)
+ commit docs : audits et rapports (audit-avant.md, PRE-REQUIS-BACKEND.md,
  RAPPORT-AUDIT-POST-CORRECTION.md, RAPPORT-FINAL-CORRECTION-MOBILE.md)
```

## 5. Dépendances backend (AUCUNE modification web effectuée — hors périmètre)

1. **Template email Supabase (P0)** : le mail de récupération doit envoyer le code
   `{{ .Token }}` (OTP 8 chiffres) — cf. `PRE-REQUIS-BACKEND.md`.
2. **Migrations 015→024 appliquées en production** (routes suppléments, suppression
   compte, apparence) — sinon les écrans P2–P4 parleront à des routes mortes.
3. **P11 — Purge photos produits** : à corriger CÔTÉ WEB : dans
   `PATCH /dashboard/produits/:id` (api-dashboard.ts l.804–840), lire `photo_r2_key`
   avant UPDATE et purger l'objet R2 si remplacé (copier le pattern
   `PATCH /dashboard/supplements/:id` l.1042). Le mobile est déjà passif — rien à changer.
4. **BUG-001 web (login inactif silencieux)** : si le web ajoute `compte_inactif` +
   `redirect_to` à la réponse login, le mobile devra consommer ces champs (surveiller).
5. **Notes de conception communes** : `paiement_initial` fusionné sous `bloque`
   côté mobile (mêmes droits, documenté dans tenant_model.dart) ; `periodicite`
   ignorée par le backend (dette commune web+mobile, hors périmètre).

## 6. Sécurité (préservée de bout en bout)

- Token / OTP : jamais loggés, jamais persistés (mémoire seule pour le flux recovery).
- HTTPS only : aucun `http://` dans lib/.
- `X-Tenant-Slug` jamais envoyé vide ; `ancienne_cle` validée (rejet `..`).
- Navigation notifications : whitelist stricte + fallback `/dashboard`.

## 7. Verdict final

**Mission accomplie côté mobile : 11/11 corrections livrées**, 0 issue d'analyse,
tests passés, aucune régression sur les points conformes A1–A9, sécurité intacte.
Reste 2 actions backend (template email OTP, purge R2 produits) documentées ci-dessus.
