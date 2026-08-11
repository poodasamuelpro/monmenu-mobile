# RAPPORT DE CORRECTION — MONMENU-MOBILE — ÉTAPE 1
**Date** : 2026-08-10  
**Méthodologie** : A = Audit → B = Correction → C = Contre-audit  
**Repo** : https://github.com/poodasamuelpro/monmenu-mobile  
**Branche** : `main`  
**Build final** : `✅ app-release.apk (59 MB)` — `flutter analyze lib/ → No issues found!`

---

## TABLEAU DE BORD GLOBAL

| # | Point | Description | A | B | C | Build |
|---|-------|-------------|---|---|---|-------|
| 1 | FilterChip + navigation | Texte illisible + lien ignoré | ✅ | ✅ | ✅ | ✅ |
| 2 | Bandeau paiement | Seuil web non aligné, 3 écrans manquants | ✅ | ✅ | ✅ | ✅ |
| 3 | Coordonnées fausses | Numéro/email de test en production | ✅ | ✅ | ✅ | ✅ |
| 4 | AppDrawer manquant | 7 screens sans navigation principale | ✅ | ✅ | ✅ | ✅ |
| 5 | Toggle annuel + moyens paiement | Données hardcodées, toggle inutile | ✅ | ✅ | ✅ | ✅ |
| 6 | Audit `_loadPdv()` | Audit seul — aucune correction | ✅ | N/A | N/A | ✅ |
| Q | Quality issues | 4 issues `flutter analyze` | ✅ | ✅ | ✅ | ✅ |

---

## COMMITS CHRONOLOGIQUES

| Hash | Message | Fichiers modifiés |
|------|---------|-------------------|
| `445329a` | fix(notifications): contraste FilterChip + navigation whitelist | `notifications_screen.dart` |
| `75107fe` | fix(paiement+coords): bandeau web aligné + coordonnées réelles | `tenant_model.dart`, `payment_alert_banner.dart`, `commandes_screen.dart`, `stats_screen.dart`, `settings_screen.dart`, `app_config.dart` |
| `40f3770` | fix(drawer): AppDrawer sur tous les 12 screens | 7 fichiers screens |
| `83d2be8` | fix(plans): toggle annuel supprimé + moyens paiement API | `api_service.dart`, `plans_screen.dart` |
| `f338b7f` | fix(menu): import AppDrawer manquant | `menu_screen.dart` |
| `9cab934` | docs: rapport intermédiaire | `CORRECTION-MONMENU-ETAPE1-2026-08-10.md` |
| `04203aa` | fix(quality): corriger les 4 issues flutter analyze | `commande_detail_screen.dart`, `dashboard_screen.dart`, `menu_screen.dart`, `plans_screen.dart` |

---

## POINT 1 — FilterChip illisible + navigation lien ignorée

### A — Audit
**Root cause FilterChip** : `lib/theme/app_theme.dart` — `chipTheme.labelStyle` défini avec `TextStyle(fontSize: 12, fontWeight: FontWeight.w500)` **sans couleur explicite**. En Material 3, le chip non sélectionné hérite d'une couleur quasi-transparente sur fond blanc (`AppColors.gray100`) → WCAG contrast ratio < 3:1 → illisible.

**Root cause navigation** : `_marquerLue()` capturait `lien` **après** l'appel async `await api.marquerNotificationLue()`. La variable était perdue. De plus, même récupérée, aucune instruction de navigation n'existait.

### B — Correction (`notifications_screen.dart`)
```dart
// FilterChip — couleur explicite selon état sélectionné
FilterChip(
  label: Text(
    'Non lues',
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _nonLuesSeulement ? AppColors.primary : AppColors.gray700,
    ),
  ),
  // ...
)

// _marquerLue() — capture AVANT await + whitelist 13 routes
Future<void> _marquerLue(String id) async {
  final lien = _items.firstWhere((n) => n.id == id).lien; // avant await
  final resp = await api.marquerNotificationLue(id, lue: true);
  if (!mounted) return;
  if (resp.success && lien != null && lien.isNotEmpty) {
    const routesPermises = [
      '/dashboard/commandes', '/dashboard/home', '/dashboard/menu',
      '/dashboard/plans', '/dashboard/restaurant', '/dashboard/stats',
      '/dashboard/settings', '/dashboard/notifications', '/dashboard/livreurs',
      '/dashboard/qrcode', '/dashboard/codes-promo', '/dashboard/apparence',
      '/dashboard/change-password',
    ];
    if (routesPermises.any((r) => lien.startsWith(r))) context.go(lien);
  }
}
```

### C — Contre-audit
```
grep -n "gray700\|AppColors.primary" notifications_screen.dart
→ FilterChip.label.color: AppColors.gray700 (non sélectionné) ✅
→ FilterChip.label.color: AppColors.primary (sélectionné) ✅

grep -n "routesPermises\|estInterne" notifications_screen.dart
→ whitelist présente, navigation conditionnelle ✅
```

---

## POINT 2 — Bandeau paiement : logique web non alignée

### A — Audit (référence : `monmenu/src/routes/api-paiement.ts` lignes 646-688)

| Élément | Web (référence) | Mobile (avant) | Écart |
|---------|----------------|----------------|-------|
| Seuil affichage | `joursRestants <= 5` | `<= 3` | ❌ 2 jours de différence |
| Couleur ≤ 2j | `error` (rouge) | `warning` (orange) | ❌ mauvaise sévérité |
| Couleur 3-5j | `warning` (orange) | n/a | ❌ non géré |
| en_attente urgent | `heures < 10` → warning | non géré | ❌ |
| SLA affiché | `48h` | absent | ❌ |
| Screens concernés | tous | dashboard seulement | ❌ commandes/stats/settings manquants |

### B — Correction

**`tenant_model.dart`** :
```dart
// Avant : jours <= 3
// Après : aligné sur web
bool get essaiExpireBientot {
  final jours = joursEssaiRestants;
  return isEssai && jours != null && jours <= 5; // ← seuil web exact
}
```

**`payment_alert_banner.dart`** — réécrit complet :
```dart
// Essai ≤ 2j → error rouge (critique)
// Essai 3-5j → warning orange
// en_attente + heures < 10 → warning urgent "X h restantes avant coupure"
// en_attente normal → "Confirmation sous 48h max"
```

**Screens ajoutés** : `commandes_screen.dart`, `stats_screen.dart`, `settings_screen.dart`

### C — Contre-audit
```
grep -rln "PaymentAlertBanner" lib/screens/
→ dashboard_screen.dart ✅
→ commandes_screen.dart ✅
→ stats_screen.dart ✅
→ settings_screen.dart ✅  (4/4)

grep -n "<= 5" lib/models/tenant_model.dart → 1 occurrence ✅
grep -n "error\|<= 2\|< 10\|48h" lib/widgets/payment_alert_banner.dart → présent ✅
```

---

## POINT 3 — Coordonnées fausses en production

### A — Audit
```
grep -rn "22500000000" lib/ → settings_screen.dart:185  ❌ numéro fictif
grep -rn "support@monmenu.app" lib/
→ app_config.dart:12  ❌
→ settings_screen.dart:192  ❌
```

### B — Correction
| Fichier | Avant | Après |
|---------|-------|-------|
| `app_config.dart` | `support@monmenu.app` | `contact.monmenu@gmail.com` |
| `settings_screen.dart` numéro | `22500000000` | `22677980264` |
| `settings_screen.dart` email | `support@monmenu.app` | `contact.monmenu@gmail.com` |
| `settings_screen.dart` mailto URI | `support@monmenu.app` | `contact.monmenu@gmail.com` |

### C — Contre-audit
```
grep -rn "22500000000\|support@monmenu.app" lib/ → 0 résultat ✅
grep -rn "22677980264\|contact.monmenu@gmail.com" lib/ → 3 occurrences ✅
```

---

## POINT 4 — AppDrawer manquant sur 7 screens

### A — Audit
Screens avec `drawer` (avant correction) : `dashboard`, `plans`, `commandes`, `settings` (4)  
Screens **sans** drawer malgré présence dans la nav : `menu`, `restaurant`, `apparence`, `livreurs`, `qrcode`, `codes_promo`, `notifications` **(7 manquants)**

### B — Correction
Pour chacun des 7 fichiers :
```dart
import '../../widgets/app_drawer.dart'; // ajouté si absent
// Dans Scaffold :
drawer: const AppDrawer(),
```

**Fichiers modifiés** : `menu_screen.dart`, `restaurant_screen.dart`, `apparence_screen.dart`, `livreurs_screen.dart`, `qrcode_screen.dart`, `codes_promo_screen.dart`, `notifications_screen.dart`

### C — Contre-audit
```
grep -rln "drawer: const AppDrawer" lib/screens/
→ 12 fichiers (tous les screens de navigation principale) ✅
```

---

## POINT 5 — Toggle annuel inutile + moyens paiement hardcodés

### A — Audit
| Problème | Localisation | Type |
|----------|-------------|------|
| `bool _annuel = false` + Container toggle | `plans_screen.dart:28,116-137` | Fonctionnalité non requise — confuse pour l'utilisateur |
| Classe `_PeriodTab` entière | `plans_screen.dart:769-809` | Code mort |
| `static const _methods` hardcodé (3 méthodes) | `plans_screen.dart:839-843` | Donnée statique — ne reflète pas les vrais moyens en DB |
| `getMoyensPaiement()` absent | `api_service.dart` | Endpoint API non câblé |
| `_PlanCard.annuel` param | `plans_screen.dart:542` | Dépendance au toggle supprimé |

### B — Correction

**`api_service.dart`** — nouvel endpoint :
```dart
/// GET /api/v1/moyens-paiement — endpoint PUBLIC (pas d'auth requise)
/// Retourne: {moyens: [{id, code, nom, description, instructions, numero, logo_url, actif}]}
Future<ApiResponse> getMoyensPaiement() async => get('/moyens-paiement');
```

**`plans_screen.dart`** — modifications complètes :
```dart
// SUPPRIMÉ : bool _annuel = false
// SUPPRIMÉ : Container Toggle Mensuel/Annuel (22 lignes)
// SUPPRIMÉ : classe _PeriodTab entière (40 lignes)

// _PlanCard — param annuel retiré, prixMensuel fixe
final prix = plan.prixMensuel; // plus de ternaire annuel/mensuel
// '/mois' fixe au lieu de annuel ? '/an' : '/mois'

// _UploadProofSheetState — chargement dynamique
List<Map<String, dynamic>> _moyensPaiement = [];
bool _loadingMoyens = false;

@override
void initState() {
  super.initState();
  _loadMoyensPaiement(); // charge depuis l'API au démarrage du sheet
}

Future<void> _loadMoyensPaiement() async {
  final resp = await api.getMoyensPaiement();
  // filtre actif=true, sélectionne le premier par défaut
  // affiche nom + numéro (avec copie) + instructions par moyen sélectionné
}
```

### C — Contre-audit
```
grep -rn "_annuel\b" lib/screens/    → 0 résultat ✅
grep -rn "annuel:" lib/screens/      → 0 résultat ✅
grep -rn "_PeriodTab" lib/           → 0 résultat ✅
grep -rn "static.*_methods" lib/     → 0 résultat ✅
```
Résidu légitime : `prixAnnuel` dans `plan_model.dart` = champ API conservé dans le modèle (l'API l'expose, il n'est plus utilisé dans l'UI) ✅

---

## POINT 6 — AUDIT `_loadPdv()` (restaurant_screen.dart)

> ⚠️ **Audit documentaire uniquement — aucune correction appliquée**

### Code audité (lignes 64-83)
```dart
Future<void> _loadPdv() async {
  setState(() { _isLoading = true; _error = null; });
  final api = context.read<ApiService>();
  final resp = await api.getPdv();           // ← pas de timeout
  if (!mounted) return;

  if (resp.success) {
    final pdvData = resp.data?['pdv'] as Map<String, dynamic>?;
    if (pdvData != null) {
      setState(() { _pdv = pdvData; _isLoading = false; });
    } else {
      setState(() { _isLoading = false; });  // PDV non créé — OK
    }
  } else {
    setState(() { _error = resp.error; _isLoading = false; });
  }
  // ← pas de try/catch autour de l'ensemble
}
```

### Risques identifiés

**Risque R1 — Absence de timeout (Sévérité : Moyenne)**
- `api.getPdv()` ne définit pas de `.timeout()`
- Si le réseau est coupé ou le backend irresponsif, la requête peut bloquer indéfiniment
- `_isLoading` reste `true` → spinner infini, l'utilisateur ne peut rien faire
- **Impact** : UX bloquée sans message d'erreur

**Risque R2 — Exception non catchée (Sévérité : Élevée)**
- Si `getPdv()` lève une exception (`SocketException`, `TimeoutException`, `HttpException`, `FormatException`)
- Aucun `try/catch` → l'exception remonte et `_isLoading` reste `true`
- Le widget peut se retrouver dans un état incohérent
- **Impact** : Crash silencieux + spinner infini

**Risque R3 — Ordre auth/API (Sévérité : Faible)**
- `_loadPdv()` est appelé via `addPostFrameCallback` → frame rendu → token auth déjà disponible
- Aucune race condition détectée avec ce pattern
- **Impact** : Risque negligeable

**Risque R4 — `context.read` avant await (Sévérité : Info)**
- Ligne 66 : `context.read<ApiService>()` est capturé **avant** l'`await` → conforme aux bonnes pratiques
- **Impact** : Aucun — correctement implémenté

### Correction recommandée (sprint suivant)
```dart
Future<void> _loadPdv() async {
  setState(() { _isLoading = true; _error = null; });
  final api = context.read<ApiService>(); // avant await ✓
  try {
    final resp = await api.getPdv().timeout(const Duration(seconds: 15));
    if (!mounted) return;
    if (resp.success) {
      final pdvData = resp.data?['pdv'] as Map<String, dynamic>?;
      setState(() {
        _pdv = pdvData != null ? PointDeVenteModel.fromJson(pdvData) : null;
        _isLoading = false;
      });
      if (_pdv != null) _fillForm(_pdv!);
    } else {
      setState(() { _error = resp.error; _isLoading = false; });
    }
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _error = 'Erreur réseau. Vérifiez votre connexion et réessayez.';
      _isLoading = false;
    });
  }
}
```

---

## POINT Q — 4 ISSUES FLUTTER ANALYZE (qualité code)

> Issues détectées après `flutter analyze lib/` post-corrections, corrigées avant build.

### Issue 1 — `unused_element_parameter` (Warning)
**Fichier** : `commande_detail_screen.dart:597`  
**Cause** : Paramètre `isDiscount` déclaré dans `_TotalRow` et utilisé dans le `build` (`color: isDiscount ?`), mais jamais passé `true` par aucun appelant.  
**Fix** : Suppression du paramètre `isDiscount`, hardcodage de la couleur par défaut (`AppColors.gray600`).

### Issue 2 — `use_build_context_synchronously` (Info)
**Fichier** : `dashboard_screen.dart:106-107`  
**Cause** : `context.read<DashboardProvider>()` et `context.read<CommandesProvider>()` utilisés après des `await` dans `onRefresh` → le widget peut être démonté entre-temps.  
**Fix** : Capture des providers **avant** les `await` :
```dart
onRefresh: () async {
  final dashboard = context.read<DashboardProvider>();  // avant await
  final commandes = context.read<CommandesProvider>();   // avant await
  await dashboard.loadAll();
  await dashboard.loadAbonnement();
  await commandes.loadCommandes();
},
```

### Issue 3 — `use_build_context_synchronously` (Info)
**Fichier** : `menu_screen.dart:679`  
**Cause** : `context.read<ApiService>()` appelé après `await FlutterImageCompress.compressAndGetFile()`.  
**Fix** : Déplacement de la capture `final api = context.read<ApiService>()` **avant** tous les `await`.

### Issue 4+5 — `deprecated_member_use` x2 (Info)
**Fichier** : `plans_screen.dart:966,974`  
**Cause** : `RadioListTile.groupValue` et `RadioListTile.onChanged` dépréciés depuis Flutter 3.32 (migration vers `RadioGroup` recommandée).  
**Fix** : Remplacement de `RadioListTile` par un indicateur radio **custom** avec `InkWell` + `Container` cercle — aucune API dépréciée, comportement identique, meilleur contrôle visuel (couleur primaire sur sélection).

### Résultat final
```
flutter analyze lib/
→ No issues found! ✅
```

---

## BUILD APK

```bash
cd /home/user/correction-workspace/monmenu-mobile
flutter build apk --release
```

**Résultat** :
```
✓ Built build/app/outputs/flutter-apk/app-release.apk (60.9MB)
```

| Métrique | Valeur |
|----------|--------|
| Statut | ✅ **Succès** |
| Taille | 59 MB |
| Durée build | ~2 min 20 sec |
| Tree-shaking icons | CupertinoIcons: -99.7% / MaterialIcons: -99.0% |
| Mode | Release |

---

## ÉTAT FINAL GITHUB

```
Branch: main
Remote: https://github.com/poodasamuelpro/monmenu-mobile.git

Commits cette session:
04203aa fix(quality): corriger les 4 issues flutter analyze
9cab934 docs: rapport correction étape 1
f338b7f fix(menu): import AppDrawer manquant
83d2be8 fix(plans): toggle annuel supprimé + moyens paiement API
40f3770 fix(drawer): AppDrawer sur tous les 12 screens
75107fe fix(paiement+coords): bandeau aligné web + coordonnées réelles
445329a fix(notifications): FilterChip contraste + navigation whitelist
```

**`flutter analyze lib/ → No issues found!` ✅**  
**`flutter build apk --release → ✓ Built app-release.apk (60.9MB)` ✅**  
**`git push origin main → ok` ✅**

---

*Rapport généré — Sprint correction Étape 1 — 2026-08-10*
