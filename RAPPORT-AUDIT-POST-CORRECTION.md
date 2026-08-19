# Rapport d'audit post-correction — monmenu-mobile

Référence web HEAD `98223df` (read-only). Baseline mobile : `1b79ac4`.
Méthode : triple audit — A fonctionnel, B régression, C sécurité + contrats.

---

## Passe A — Audit fonctionnel (P0 → P11)

| # | Correction | Vérification | Statut |
|---|-----------|--------------|--------|
| P0 | Reset MDP OTP **8 chiffres**, type `recovery` | `_otpLength = 8` (6 usages), `validateOtpCode` regex `^\d{8}$`, message web exact, token en mémoire seule | ✅ Conforme |
| P1 | 6 modes d'accès + confinement tenant bloqué | `tenant_model.dart` : `modeAcces` (actif → essai → suspendu → grace_confirmation → bloque), `accesComplet`/`accesAbonnementSeul` ; redirect go_router : bloqué confiné à plans/settings/change-password/notifications | ✅ Conforme |
| P2 | Module Suppléments | `supplement_model.dart` + 6 méthodes API (GET/POST/PATCH/DELETE + limite + image multipart `file`) + `supplements_screen.dart` + drawer 3e position + route | ✅ Conforme |
| P3 | Suppression de compte | `compte_screen.dart` (double confirmation, 429 rate-limit, 422 annulation), 2 méthodes API, entrée Settings, route `/dashboard/settings/compte` | ✅ Conforme |
| P4 | Upload réel apparence | `uploadImage(filePath, ancienneCle:)` → champ `ancienne_cle` ; `_extraireCleR2` (rejet `..`) ; PATCH `/dashboard/apparence` partiel immédiat | ✅ Conforme |
| P5 | Stats exactes | `commandesEnCours(totalServeur) = total − livree − annulee` borné ≥ 0 ; `totalServeur` = champ `total` exact de GET /commandes ; UI dashboard (« En cours ») + stats câblées | ✅ Conforme |
| P6 | Notifications navigables | `mapLienWebVersMobile` (parametres→settings, abonnement→plans, home→dashboard, ancres `#`→dashboard) ; whitelist enrichie (+supplements) ; fallback visible `/dashboard` ; section « Paiement » branchée sur GET /paiement/notifications (seuils serveur) | ✅ Conforme |
| P7 | Change-password session propre | Succès → « Mot de passe modifié. Veuillez vous reconnecter. » + `logout()` + `go('/login')` (cohérent avec la révocation globale web) | ✅ Conforme |
| P8 | Contrat slug | `X-Tenant-Slug` dans `_headers` + les 3 MultipartRequest ; omis si tenant absent, jamais vide | ✅ Conforme |
| P9 | Drawer universel | Entrée « Historique paiements » (`/dashboard/plans/historique`, exact-match anti double surlignage) ; drawer + bouton menu sur `commande_detail_screen` et `abonnement_historique_screen` ; PDV hors périmètre (écran inexistant, à valider client) | ✅ Conforme |
| P10 | Code mort Hive | Constantes `hiveBox*` retirées, `Hive.initFlutter()` + import retirés ; deps pubspec conservées ; décision argumentée (audit-avant.md B.14) | ✅ Conforme |
| P11 | Purge photos produits orphelines | **Hors périmètre mobile** : correction requise côté WEB (PATCH /dashboard/produits/:id doit purger `photo_r2_key` comme PATCH supplements/:id l.1042). Le mobile n'a rien à changer | ⚠️ Dépendance backend |

## Passe B — Audit de régression

- `flutter analyze` : **0 issues** après **chacun** des commits P0→P10 et à l'état final.
- `flutter test` : **All tests passed**.
- Points conformes A1–A9 pré-existants : non touchés — vérifié :
  - 22 GoRoute intactes (2 ajouts uniquement : supplements, settings/compte) ;
  - pattern logout inchangé (settings_screen l.208) et réutilisé à l'identique en P7 ;
  - aucun appel `Hive.` ne subsistait dans lib/ avant le retrait P10 (zéro perte fonctionnelle) ;
  - `pendingCount` (badge commandes en attente, realtime) inchangé — P5 n'a modifié que les getters stats ;
  - flux paiement (soumettrePreuve), commandes, menu, livreurs, QR, codes promo : fichiers non modifiés.

## Passe C — Audit sécurité + contrats

| Contrôle | Résultat |
|----------|----------|
| Token/OTP jamais loggé | ✅ Aucun `print/debugPrint` de token, OTP ou password (seuls status codes et messages génériques) |
| OTP jamais persisté | ✅ Aucune écriture storage/prefs dans le flux recovery — token OTP en mémoire seule |
| HTTPS only | ✅ Aucun `http://` dans lib/ |
| `X-Tenant-Slug` | ✅ Jamais envoyé vide ; omis tant que le tenant n'est pas chargé (login/reset) |
| `ancienne_cle` | ✅ Clé extraite après `/dashboard/media/`, rejet `..`, omise si format inattendu (validation serveur en dernier recours) |
| Whitelist navigation notifications | ✅ Alias appliqués AVANT la whitelist ; lien inconnu → fallback `/dashboard` (jamais de navigation arbitraire) |
| Contrats API respectés | ✅ OTP `/^\d{8}$/` ; statuts stats `{livree, annulee}` ; GET /paiement/notifications `{notifications[], count, non_lues}` avec `action{label,href}` ; suppléments multipart champ `file` ; suppression compte 429/422 ; PATCH apparence partiel |

## Verdict

**11/11 corrections livrées côté mobile** (P11 = dépendance web documentée).
`flutter analyze` final : 0 issues. Tests passés. Aucune régression. Sécurité préservée.
