# RAPPORT DE VÉRIFICATION EXTERNE — monmenu-mobile

**Date** : 2026-08-19/20
**Auditeur** : vérificateur externe indépendant (clones frais)
**Dépôt audité** : `poodasamuelpro/monmenu-mobile`, branche `main`, HEAD au début de l'audit : `ea70b96`
**Source de vérité (READ-ONLY)** : web `monmenu`, HEAD `98223df` — jamais modifié
**HEAD après audit** : `a193a34` (commit correctif de l'auditeur, voir §Verdict global)

---

## Résumé exécutif

| Périmètre | Verdict |
|---|---|
| **A — Uploads multipart (contentType)** | ✅ CONFORME (A1-A5) / ⚠️ A6 écart mineur documenté / ❌→✅ A7 corrigé par l'auditeur |
| **B — Écran Restaurant (_parseHoraires, try/catch)** | ✅ CONFORME (B1-B6) |
| **C — 6 commits (NavButtons, écrans, QR, jours essai)** | ✅ Conforme sur le FOND / ❌ ÉCART MAJEUR : le code ne compilait pas (37 issues) — **corrigé et poussé** |
| **D — Preuve de paiement (contentType)** | ✅ CONFORME |
| **Build debug** | ✅ SUCCESS (après correction, voir §7) |

**Écart majeur découvert** : le HEAD `ea70b96` **ne compilait pas** (`flutter analyze` : 37 issues dont ~30 erreurs bloquantes), introduites par les commits `bd54582`, `ee282e2` et `03aacb0`. Toutes les corrections — strictement limitées aux périmètres 2/3/4 — ont été appliquées, validées (`flutter analyze` : 0 issue) et poussées dans le commit **`a193a34`**.

---

## §1 Préliminaires

| Attendu | Constaté | Verdict |
|---|---|---|
| Clone frais mobile, HEAD ≥ ea70b96 | `/home/user/audit/mobile`, HEAD `ea70b96` | ✅ |
| Clone frais web, HEAD 98223df, read-only | `/home/user/audit/web`, HEAD `98223df`, jamais modifié | ✅ |
| pubspec lu | sdk `>=3.0.0 <4.0.0`, http 1.5.0, flutter_image_compress ^2.3.0, path_provider ^2.1.5 | ✅ |
| Routes web localisées | `src/routes/api-dashboard.ts`, `api-paiement.ts`, `api-supplements.ts`, `src/lib/validation.ts`, `src/lib/paiement.ts` | ✅ |

Chaîne des 6 commits confirmée : `ea70b96 ← ee282e2 ← 6e3ace9 ← 2d89dc9 ← bd54582 ← 03aacb0 ← b2c2c8a`.

---

## §2 Vérification A — Uploads multipart

| # | Attendu | Constaté | Preuve | Verdict |
|---|---|---|---|---|
| A1 | Import http_parser | `import 'package:http_parser/http_parser.dart';` | `api_service.dart` l.7 | ✅ |
| A2 | Helper MediaType par extension | `MediaType _imageContentType(String ext)` : png→image/png, webp→image/webp, gif→image/gif, défaut image/jpeg | `api_service.dart` l.15-26 | ✅ |
| A3 | 3/3 `MultipartFile.fromBytes` avec contentType, 0 manquant | preuve l.376-381 (`MediaType('image','jpeg')`), uploadImage l.444-449 (`_imageContentType(ext)`), uploadSupplementImage l.527-532 (idem). `grep fromBytes` → 3 occurrences, toutes avec contentType | `api_service.dart` | ✅ |
| A4 | Le web rejette octet-stream (justification du fix) | Validation 3 couches : extension, `file.type` déclaré → 415, magic bytes `validerMimeImageUnifie` → 415 | web `api-dashboard.ts` l.1948-1963 | ✅ |
| A5 | Compression avant upload Apparence | `FlutterImageCompress.compressAndGetFile` via `getTemporaryDirectory()`, quality 80 (logo) / 75 (bannière) | `apparence_screen.dart` l.238-248 | ✅ |
| A6 | Suppression du fichier compressé temporaire | **Aucun `File.delete()`** du fichier compressé. Écart mineur : le fichier est écrit dans le répertoire temporaire (`getTemporaryDirectory()`), purgé par l'OS — pas de fuite durable, mais nettoyage explicite absent | `apparence_screen.dart` | ⚠️ ÉCART MINEUR (documenté, non bloquant) |
| A7 | `flutter analyze` vert | **AVANT : 37 issues (≈30 erreurs)**. APRÈS correction `a193a34` : **No issues found** | sortie analyze | ❌→✅ CORRIGÉ |

---

## §3 Vérification B — Écran Restaurant

| # | Attendu | Constaté | Preuve | Verdict |
|---|---|---|---|---|
| B1 | `import 'dart:convert';` | présent | `livreur_model.dart` l.4 | ✅ |
| B2 | `_parseHoraires(dynamic)` robuste | branches : null→null ; `Map<String,dynamic>`→inchangé ; `Map`→`MapEntry(k.toString(), v)` ; `String`→`jsonDecode` sous try/catch ; autre→null | `livreur_model.dart` l.233-248 | ✅ |
| B3 | Appel dans fromJson | `horaires: _parseHoraires(json['horaires'])` | `livreur_model.dart` l.206 | ✅ |
| B4 | try/catch englobant `_loadPdv` | catch → `setState` `_error` + `_isLoading=false`, protégé par `mounted` | `restaurant_screen.dart` | ✅ |
| B5 | Branches 401 / erreur | warning 401 distinct + message d'erreur générique | `restaurant_screen.dart` | ✅ |
| B6 | Équilibre des accolades | comptage `{` = `}` (0/0 de delta) | vérifié par script | ✅ |

---

## §4 Vérification C — Audit des 6 commits

### Tableau des commits

| Commit | Message | Fond | Compilation |
|---|---|---|---|
| `03aacb0` | hamburger visible partout + téléchargement QR fichier + jours d'essai affichés | ✅ | ❌ `auth` indéfini dans `_downloadQrFile` (qrcode_screen l.147) |
| `bd54582` | hamburger + retour sur tous les écrans (widget NavButtons) | ✅ | ❌ import `nav_buttons.dart` manquant dans 11/17 écrans ; import `app_theme.dart` supprimé de compte_screen → `AppColors` indéfini ×15 |
| `2d89dc9` | retirer le menu des écrans login et mot de passe oublié | ✅ | ✅ |
| `6e3ace9` | déclarer le Content-Type réel des uploads multipart (415) | ✅ | ✅ |
| `ee282e2` | compresser logo/bannière avant upload Apparence | ✅ | ❌ `CompressFormat.jpg` (l'enum s'appelle `jpeg`) |
| `ea70b96` | Restaurant ne tourne plus en rond (parsing horaires + try/catch) | ✅ | ✅ |

### Points de contrôle C

| Attendu | Constaté | Verdict |
|---|---|---|
| Widget NavButtons : hamburger + retour avec fallbacks | `nav_buttons.dart` : `_openMenuOrFallback` (Scaffold.maybeOf→openDrawer, sinon pop/go `/dashboard/commandes`) + `_backOrFallback` (canPop→pop sinon fallback) | ✅ |
| 17+ écrans avec NavButtons | **17 écrans** utilisent `NavButtons(` (liste vérifiée par grep) ; après correction, 17/17 ont l'import | ✅ (après `a193a34`) |
| login / forgot_password SANS menu | `grep NavButtons` → 0 occurrence dans les deux ; forgot : bouton retour seul (l.241-250) | ✅ |
| QR téléchargeable en vrai fichier | `_downloadQrFile` : GET url, `getApplicationDocumentsDirectory()` + `writeAsBytes`, gestion url null sans plantage, snackbar chemin. Web : `qr_download_png/svg` 1000×1000 (api-dashboard l.2110-2111) | ✅ (après fix `auth`) |
| Jours d'essai JAMAIS hardcodés | priorité `dashboard.joursEssaiRestants ?? tenant.joursEssaiRestants ?? _joursEssaiFallback(tenant)` ; tenant calcule depuis `essai_expire_le` (tenant_model l.221-225) ; serveur `jours_essai_restants` (api-paiement l.166-167) ; fallback `createdAt + 14` aligné sur `ESSAI_DUREE_JOURS=14` (web constants.ts l.90) | ✅ |
| Non-régression | analyze 0 issue, aucun autre fichier touché hors périmètre | ✅ |

---

## §5 Vérification D — Preuve de paiement

| Attendu | Constaté | Preuve | Verdict |
|---|---|---|---|
| Preuve envoyée avec contentType image | `fromBytes('preuve', ..., contentType: MediaType('image','jpeg'))` | `api_service.dart` l.376-381 | ✅ |
| Cohérence avec le format réel du fichier | `payment_upload_service.dart` compresse **toujours** en `.jpg` (l.140-146, CompressFormat par défaut = jpeg) → le MediaType jpeg déclaré est exact | `payment_upload_service.dart` | ✅ |
| Handler web accepte | `validerExtensionImage` (jpg/jpeg/png) + `validerContentTypeImage` + magic bytes `validerMimeImageUnifie` | web `api-paiement.ts` l.283-297 | ✅ |

---

## §6 Audit exhaustif complémentaire (documentation seule — AUCUNE modification)

- **Accès abonnement** : `accesAbonnementSeul => modeAcces=='bloque'` (tenant_model l.215) — parité avec la logique web.
- **Email éditable** : `_editEmail` présent dans settings (compte_screen l.217) — conforme au web.
- **Contrat API pdv** : le mobile lit `data.pdv` comme objet unique — cohérent avec la réponse du web.
- **Résidu qualité (hors périmètre, non corrigé)** : `http_parser` était en dépendance transitive alors qu'importé directement → régularisé dans `a193a34` (dépendance directe `^4.0.2`, résolue 4.1.2) car il faisait partie du lint du périmètre A.
- **Recommandation (non appliquée, hors périmètre)** : ajouter un `finally { compressed.delete() }` dans apparence_screen pour nettoyer le fichier temporaire (cf. A6).

---

## §7 Correctif de l'auditeur + Build

### Commit correctif poussé : `a193a34`

`fix(build): réparation compilation cassée par bd54582/ee282e2/03aacb0`
- +11 imports `widgets/nav_buttons.dart` (NavButtons utilisé sans import)
- compte_screen : réintroduction `theme/app_theme.dart` (AppColors indéfini ×15)
- apparence_screen : `CompressFormat.jpg` → `CompressFormat.jpeg`
- qrcode_screen : `final auth = context.read<AuthService>();` en tête de `_downloadQrFile`
- nettoyage imports inutilisés (go_router ×11, app_drawer ×1)
- pubspec : `http_parser: ^4.0.2` en dépendance directe

**`flutter analyze` : No issues found** (était 37). Push confirmé : `ea70b96..a193a34 main -> main`.

### Build

- Commande : `flutter build apk --debug` (jamais release, conformément au prompt)
- Résultat : ✅ SUCCESS — `app-debug.apk`, **149 MB** (155 990 481 octets), SHA-256 `9c4201f705c77f0cd052982b95cb2bb79d824e198f9267f9432c4b74bb51aae4` (Gradle assembleDebug 200s)

---

## Résidus / points ouverts

1. **A6** : pas de suppression explicite du fichier compressé temporaire (mineur, temp dir OS).
2. Les logs `kDebugMode` ont été **ignorés** conformément au prompt.
3. Le web n'a **jamais** été modifié (`git status` clone web : propre).
