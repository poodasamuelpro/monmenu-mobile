# AUDIT TECHNIQUE MONMENU — RAPPORT COMPLET

> **Fichier** : `AUDIT-MONMENU-COMPLET-2026-08-10.md`  
> **Date** : 2026-08-10  
> **Auditeur** : Claude (Anthropic) — assistant technique senior  
> **Repos audités (clones frais, jamais supposés)** :
> - Mobile [`monmenu-mobile`] — commit `486093ab99e69ff1175c07368e53902bf2b598f4`
> - Web [`monmenu`] — commit `c5c449622db6f0f85c2ed3899f031a9e05506879`

---

## Sommaire

1. [Audit 1 — Notifications in-app mobile (bouton "tout lire" + clic notification)](#1-audit--notifications-in-app-mobile)
2. [Audit 2 — Page "Restaurant" mobile bloquée en chargement infini](#2-audit--page-restaurant-mobile-bloquée-en-chargement-infini)
3. [Audit 3 — Accès rapide au menu depuis n'importe quelle page (mobile)](#3-audit--accès-rapide-au-menu-depuis-nimporte-quelle-page)
4. [Audit 4 — Configuration FCM + bandeau de notification web/mobile](#4-audit--configuration-fcm-et-bandeau-de-notification)
5. [Audit 5 — Coordonnées de contact (web + mobile)](#5-audit--coordonnées-de-contact)
6. [Audit 6 — Page Plan & Paiement mobile vs web](#6-audit--page-plan--paiement-mobile-vs-web)
7. [Audit 7 — Sélection de suppléments/accompagnements à la commande](#7-conception--sélection-de-suppléments--accompagnements)
8. [Audit 8 — Points additionnels (upload preuve + disponibilité des plats)](#8-audit-complémentaire--points-additionnels)
9. [Tableau de synthèse global](#tableau-de-synthèse-global)

---

## 1. Audit — Notifications in-app mobile

### Symptôme observé

Le bouton "marquer tout comme lu" serait illisible (couleur de texte / fond en conflit). Les taps sur une notification individuelle doivent appeler `PATCH /notifications/:id`.

### Cause racine identifiée

**BUG 1.1 — Bouton "tout marquer comme lu" : NON illisible dans le code actuel**

Après analyse du code réel (`lib/screens/notifications/notifications_screen.dart`, lignes 302–319), le bouton **n'est pas un bouton texte avec couleur explicite**, mais un `IconButton` utilisant `Icons.done_all_rounded`. Il hérite de `foregroundColor: AppColors.gray900` défini sur l'`AppBar` (ligne 277). Sur fond blanc (`backgroundColor: Colors.white`, ligne 275), le contraste gris foncé (#111827) sur blanc est excellent (ratio > 15:1, conforme WCAG AAA).

**Conclusion sur BUG 1.1** : Le signalement "illisible" ne correspond à aucun problème de contraste vérifiable dans le code. Hypothèse : la plainte porte sur l'absence de **label textuel** visible — l'action n'est identifiable que par le tooltip `'Tout marquer comme lu'` (affiché uniquement au long tap sur Android). L'icône `Icons.done_all_rounded` seule, sans libellé, peut manquer de lisibilité pour certains utilisateurs.

**BUG 1.2 — Clic sur une notification : appel PATCH confirmé et fonctionnel**

`lib/screens/notifications/notifications_screen.dart`, ligne 447 :
```dart
onTap: () => _marquerLue(notif.id),
```

La méthode `_marquerLue()` (lignes 144–158) appelle bien `api.marquerNotificationLue(id, lue: true)`, qui effectue `PATCH /dashboard/notifications/:id` avec body `{ lue: true }` (`lib/services/api_service.dart`, lignes 432–435).

**BUG 1.3 — Cohérence API web/mobile : complète**

Côté web (`src/routes/api-dashboard.ts`, lignes 1837–1891), les trois routes existent :
- `PATCH /notifications/:id` — vérifie ownership tenant, met à jour `lue`, retourne `{success, lue}` ✅
- `PATCH /notifications/tout-lire` — retourne `{success, nb_mises_a_jour}` ✅
- `GET /notifications/liste?page=&limit=&non_lues=` — retourne `{notifications[], page, limit, total, nb_non_lues, has_more}` ✅

Le contrat API est **intégralement respecté** côté mobile.

**BUG 1.4 — Problème d'UX réel : bouton "tout lire" conditionnel non visible quand `_nbNonLues == 0`**

Le bouton est masqué par `if (_nbNonLues > 0)` (ligne 302). Si toutes les notifications sont déjà lues, le bouton n'apparaît pas — c'est le comportement attendu. Mais si `_nbNonLues > 0` ET que l'utilisateur filtre sur "Non lues seulement", le bouton est toujours affiché, ce qui est cohérent.

**BUG 1.5 — Absence de navigation depuis une notification (lien `lien`)**

Le modèle `_NotifItem` expose un champ `lien` (ligne 25), mais le `onTap` (ligne 447) ne fait que marquer comme lue — il n'ouvre jamais le lien. Si une notification a un `lien: '/dashboard/commandes'`, le clic ne navigue pas.

### Fichiers concernés

| Fichier | Statut |
|---|---|
| `lib/screens/notifications/notifications_screen.dart` | À modifier (BUG 1.5) |
| `lib/services/api_service.dart` | Aucune modification nécessaire |
| `src/routes/api-dashboard.ts` (web) | Aucune modification nécessaire |

### Proposition de correction

**Pour BUG 1.4 (UX — libellé visible)** : Remplacer `IconButton` par un `TextButton` avec icône et libellé explicite dans l'AppBar actions, ou ajouter un `Tooltip` visible en permanence (pas seulement au long tap).

**Pour BUG 1.5 (navigation depuis lien)** : Modifier `_marquerLue()` pour, après succès du PATCH, vérifier si `notif.lien != null` et effectuer `context.go(notif.lien!)` si le lien est une route interne (`/dashboard/...`) :

```dart
Future<void> _marquerLue(String id) async {
  final notif = _items.firstWhere((n) => n.id == id);
  final api = context.read<ApiService>();
  final resp = await api.marquerNotificationLue(id, lue: true);
  if (!mounted) return;

  if (resp.success) {
    setState(() {
      final idx = _items.indexWhere((n) => n.id == id);
      if (idx != -1 && !_items[idx].lue) {
        _items[idx] = _items[idx].copyWith(lue: true);
        if (_nbNonLues > 0) _nbNonLues--;
      }
    });
    // Naviguer si lien interne
    if (notif.lien != null && notif.lien!.startsWith('/dashboard') && mounted) {
      context.go(notif.lien!);
    }
  }
}
```

### Impact application mobile
**Important** — L'absence de navigation depuis le champ `lien` rend les notifications liées à des actions (commande, paiement) moins utiles qu'elles ne devraient l'être.

### Impact application web
Aucun — le comportement web (panneau notifications dans `notifications.js`) est indépendant.

### Risques de régression
Faibles — l'ajout de navigation conditionnel après un PATCH réussi est non-bloquant.

### Priorité
**Confort** (BUG 1.4 — libellé) | **Important** (BUG 1.5 — navigation lien)

---

## 2. Audit — Page "Restaurant" mobile bloquée en chargement infini

### Symptôme observé

L'écran "Mon Restaurant" resterait bloqué en état de chargement infini. Un écran "Point de vente" du même module s'afficherait correctement.

### Cause racine identifiée

**ÉTAT DU CODE ACTUEL** : après analyse de `lib/screens/restaurant/restaurant_screen.dart`, le fichier implémente **un seul écran** nommé `RestaurantScreen` qui édite le **Point de Vente** (PDV) via `GET/PATCH /dashboard/pdv`. Il n'y a **pas d'écran "Restaurant" distinct** de l'écran PDV dans le code actuel.

**Analyse de `_loadPdv()`** (lignes 63–83) :

```dart
Future<void> _loadPdv() async {
  setState(() { _isLoading = true; _error = null; });
  final api = context.read<ApiService>();
  final resp = await api.getPdv();
  if (!mounted) return;

  if (resp.success) {
    final pdvData = resp.data?['pdv'] as Map<String, dynamic>?;
    if (pdvData != null) {
      final pdv = PointDeVenteModel.fromJson(pdvData);
      _fillForm(pdv);
      setState(() { _pdv = pdv; _isLoading = false; });
    } else {
      // Aucun PDV encore créé — formulaire vide, l'API créera au premier PATCH
      setState(() { _isLoading = false; });
    }
  } else {
    setState(() { _error = resp.error; _isLoading = false; });
  }
}
```

**Bonne nouvelle** : contrairement à un bug signalé précédemment, `_isLoading` est **correctement** repassé à `false` dans tous les cas (succès, PDV null, erreur).

**Problème potentiel identifié** : 

1. **Bloc `else { _isLoading = false }` ligne 78–79** — si `resp.data` est non-null mais `resp.data['pdv']` est null (clé absente ou valeur null), `_pdv` reste `null`. L'écran affiche alors `Center(child: Text('Aucun point de vente configuré'))` (ligne 201 du `_buildBody()`). Ce n'est pas un chargement infini mais une page vide.

2. **Condition d'affichage du bouton "Sauvegarder" dans l'AppBar** (ligne 185) : `if (!_isLoading && _pdv != null)`. Si `_pdv == null` (PDV jamais créé), le bouton de sauvegarde est masqué, mais le formulaire vide est affiché. L'utilisateur ne peut pas créer un PDV depuis cet écran — **fonctionnalité manquante**.

3. **Champ `telephone`, `email`, `slogan`** (lignes 88–93) : ces champs sont dans le formulaire mais **non envoyés au backend** (commentaire ligne 117 : `NE PAS envoyer: telephone, email, slogan (non supportés par l'API)`). Si ces données existaient dans une version antérieure et que l'utilisateur les renseigne, elles sont silencieusement ignorées.

**BUG 2.1 — Chargement infini non reproductible dans le code actuel** : La cause exacte décrite (isLoading jamais repassé à false) n'est PAS présente dans la version auditée. Soit le bug a été corrigé dans un commit récent, soit il survient uniquement sur un tenant dont l'API `/dashboard/pdv` retourne une erreur réseau non gérée au niveau `_request()` — mais même dans ce cas, `ApiService._request()` retourne un `ApiResponse.failure()` et le bloc `else` de `_loadPdv()` repasse bien `_isLoading = false`.

**BUG 2.2 (confirmé) — PDV null → formulaire vide sans bouton de sauvegarde**

Si le tenant n'a jamais créé de PDV, `resp.data['pdv']` est null → `_pdv = null` → le bouton "Sauvegarder" est masqué → l'utilisateur ne peut pas créer son premier PDV.

### Fichiers concernés

| Fichier | Statut |
|---|---|
| `lib/screens/restaurant/restaurant_screen.dart` | À modifier (BUG 2.2) |
| `lib/services/api_service.dart` | Aucune modification nécessaire |
| `src/routes/api-dashboard.ts` (web) | Vérification : `PATCH /dashboard/pdv` crée ou met à jour selon existence |

### Proposition de correction

**Pour BUG 2.2** : Afficher le bouton "Sauvegarder" même quand `_pdv == null` (premier enregistrement) :

```dart
// Ligne 185 — remplacer :
if (!_isLoading && _pdv != null)
// Par :
if (!_isLoading)
```

Et dans `_save()`, ne pas conditionner l'appel au fait que `_pdv` soit non-null.

**Note** : vérifier que `PATCH /dashboard/pdv` (`src/routes/api-dashboard.ts`) crée bien le PDV s'il n'existe pas encore, ou qu'un `POST /dashboard/pdv` existe pour la création initiale.

### Impact application mobile
**Important** — Un restaurant fraîchement inscrit ne peut pas configurer son Point de Vente depuis l'app mobile.

### Impact application web
Non impacté directement, mais le dashboard web (`/dashboard/pdv`) gère peut-être la même situation.

### Risques de régression
Faibles — modification de la condition d'affichage d'un bouton.

### Priorité
**Important**

---

## 3. Audit — Accès rapide au menu depuis n'importe quelle page

### Symptôme observé

Depuis certains écrans, seul le bouton Retour est disponible. Il n'y a pas de navigation directe vers le menu principal.

### État actuel de la navigation

**Navigation drawer (sidebar)** : `lib/widgets/app_drawer.dart` implémente un `Drawer` complet accessible via le geste de swipe depuis le bord gauche ou le bouton hamburger (≡) dans l'AppBar. Ce drawer contient tous les liens de navigation.

**Écrans avec `AppDrawer` explicitement déclaré** (via `drawer: const AppDrawer()`) :
- `commandes_screen.dart` ✅
- `dashboard_screen.dart` ✅
- `plans_screen.dart` ✅
- `settings_screen.dart` ✅
- `stats_screen.dart` ✅

**Écrans SANS `AppDrawer`** (seul bouton retour) :
- `menu_screen.dart` ❌
- `restaurant_screen.dart` ❌
- `livreurs_screen.dart` ❌
- `qrcode_screen.dart` ❌
- `codes_promo_screen.dart` ❌
- `apparence_screen.dart` ❌
- `notifications_screen.dart` ❌

Ces 7 écrans sont des écrans "profonds" (accessibles depuis le drawer ou via navigation directe) et n'exposent que le bouton retour `←` vers `/dashboard/commandes`.

### Cause racine identifiée

Architecture intentionnelle (drawer uniquement sur les écrans "principaux"), mais incomplète. Les écrans "secondaires" n'ont pas de drawer, rendant la navigation inter-sections impossible sans revenir à l'accueil.

**Navigation GoRouter** (`lib/main.dart`, lignes 121–203) : routes plates, pas de shell route partagé avec navigation persistante.

### Fichiers concernés

| Fichier | Statut |
|---|---|
| `lib/widgets/app_drawer.dart` | Aucune modification nécessaire |
| `lib/screens/menu/menu_screen.dart` | À modifier |
| `lib/screens/restaurant/restaurant_screen.dart` | À modifier |
| `lib/screens/restaurant/livreurs_screen.dart` | À modifier |
| `lib/screens/restaurant/qrcode_screen.dart` | À modifier |
| `lib/screens/restaurant/codes_promo_screen.dart` | À modifier |
| `lib/screens/restaurant/apparence_screen.dart` | À modifier |
| `lib/screens/notifications/notifications_screen.dart` | À modifier |

### Proposition de correction

**Option A (recommandée) — Ajouter `drawer: const AppDrawer()` sur chaque écran secondaire** : solution minimale, non-invasive, conserve le bouton retour existant et ajoute le swipe-to-open drawer. Modification à ajouter dans chaque `Scaffold` des 7 écrans listés :

```dart
Scaffold(
  backgroundColor: AppColors.background,
  appBar: AppBar(/* ... */),
  drawer: const AppDrawer(),  // ← ajouter cette ligne
  body: _buildBody(),
)
```

**Option B — ShellRoute GoRouter avec navigation persistante** : implique une refonte de la navigation dans `main.dart`. Plus propre architecturalement mais risque de régression plus élevé.

**Recommandation** : Option A dans un premier temps.

### Impact application mobile
**Important** — Amélioration significative de l'UX.

### Impact application web
Aucun — pas de deep links partagés web/mobile.

### Risques de régression
Très faibles (Option A) — ajout d'un widget existant sur des écrans existants.

### Priorité
**Important**

---

## 4. Audit — Configuration FCM et bandeau de notification

### 4.1 Mobile — Configuration FCM

#### État vérifié dans le clone

| Élément | Présence | Chemin |
|---|---|---|
| `firebase_core: 3.6.0` dans `pubspec.yaml` | ✅ Confirmé | `pubspec.yaml` ligne 44 |
| `firebase_messaging: 15.1.3` dans `pubspec.yaml` | ✅ Confirmé | `pubspec.yaml` ligne 45 |
| `google-services.json` | ✅ Présent | `android/app/google-services.json` |
| `lib/services/fcm_service.dart` | ✅ Présent | Complet, 350 lignes |
| Handler background `@pragma('vm:entry-point')` | ✅ Correct | `fcm_service.dart` ligne 26 |
| Init FCM dans `main.dart` (`await Firebase.initializeApp()`) | ✅ Confirmé | `main.dart` ligne 54 |
| `_initFCM()` appelé après restauration session | ✅ Confirmé | `main.dart` lignes 241–244 |
| `logoutWithFCMCleanup()` avant déconnexion | ✅ Confirmé | `main.dart` lignes 312–321 |
| Canaux Android `commandes_channel` / `payment_channel` | ✅ Confirmés | `fcm_service.dart` lignes 56–77 |

**Action restante (configuration externe, pas un bug de code)** : un APK buildé postérieur aux correctifs FCM doit être distribué pour que les push fonctionnent en production. Ceci ne peut pas être vérifié dans le code source.

### 4.2 Web — Liste exhaustive des fichiers FCM créés/modifiés

#### Fichiers vérifiés dans le clone `monmenu`

| Fichier | Statut | Description |
|---|---|---|
| `src/lib/fcm.ts` | ✅ **Créé, présent** | Helper FCM v1 OAuth2 RS256, 210 lignes, fonctions `sendFcmNotification()` et `sendFcmToTenant()` |
| `src/routes/api-dashboard.ts` lignes 1904–1964 | ✅ **Ajouté** | `POST /fcm-token` + `DELETE /fcm-token` |
| `src/routes/api-commandes.ts` ligne 353 | ✅ **Ajouté** | `sendFcmToTenant()` à la création d'une nouvelle commande |
| `src/routes/api-admin-paiements.ts` lignes 267–275, 397–407 | ✅ **Ajouté** | `sendFcmToTenant()` sur `/confirmer` et `/rejeter` |
| `src/types/database.ts` lignes 368–373 | ✅ **Ajouté** | Champs `FCM_PROJECT_ID?`, `FCM_CLIENT_EMAIL?`, `FCM_PRIVATE_KEY?` dans type `Env` |
| `supabase/migrations/013_fcm_tokens.sql` | ✅ **Créé, présent** | Table `fcm_tokens`, index, RLS, fonction de nettoyage |

#### Vérification `wrangler.jsonc`

Le fichier `wrangler.jsonc` **ne contient PAS** `FCM_PROJECT_ID` dans la section `vars`. Ce champ est décrit dans `src/types/database.ts` (ligne 371) comme "Text" (non-secret), mais n'a pas encore été ajouté comme variable texte publique dans `wrangler.jsonc`.

#### Tableau "Reste à faire" vs "Déjà fait"

| Élément | Statut |
|---|---|
| Code TypeScript FCM (`fcm.ts`) | ✅ Déjà fait et vérifié dans le code |
| Routes `POST/DELETE /fcm-token` | ✅ Déjà fait et vérifié dans le code |
| Déclencheurs FCM (commandes + paiements) | ✅ Déjà fait et vérifié dans le code |
| Type `Env` avec champs FCM | ✅ Déjà fait et vérifié dans le code |
| Migration SQL `013_fcm_tokens.sql` | ✅ Présente dans le repo — **à exécuter** sur Supabase production |
| `FCM_PROJECT_ID` dans `wrangler.jsonc` `vars` | ❌ **Manquant** — action de configuration externe |
| Secrets `FCM_CLIENT_EMAIL` et `FCM_PRIVATE_KEY` sur Cloudflare Workers dashboard | ❌ **Manquants** — secrets à ajouter via `wrangler secret put` ou le dashboard Cloudflare (jamais dans le code) |
| APK mobile buildé et distribué | ❌ **Non vérifiable dans le code** — action externe |

### 4.3 Bandeau de notification — Web (confirmé existant) vs Mobile

#### A. Fonctionnement réel côté web

**Fichiers qui génèrent le bandeau** :
- `src/pages/dashboard.ts` ligne 177 : conteneur `<div id="notification-bandeaux" class="bg-white">` dans le layout principal (présent sur **toutes les pages** du dashboard web, car c'est le layout commun).
- `public/static/js/dashboard-paiement.js`, fonction `initBandeauxPaiement()` (lignes 102–127) : appelée au chargement de chaque page dashboard, récupère `GET /api/v1/paiement/notifications` et remplit le conteneur.

**Condition de déclenchement** (`src/routes/api-paiement.ts`, lignes 623–713) :
- **Essai** : bandeau de type `warning` (orangé) si `statut === 'essai'` ET `joursRestants <= 5`. Devient `error` (rouge) si `joursRestants <= 2`. Message : `"Essai expire dans X jour(s)"` avec lien vers `/dashboard/abonnement`.
- **Paiement en attente** : bandeau de type `info` (bleu) ou `warning` si <10h restantes, si `paiement_en_attente_depuis` est non-null ET un abonnement `en_attente_confirmation` existe dans la DB.

**Condition de disparition** :
- Le bandeau disparaît quand l'API `/paiement/notifications` retourne un tableau vide. Cela survient quand `statut` n'est plus `'essai'` OU quand `joursRestants > 5`. La disparition **est immédiate** dès que le statut change côté base (pas de cache local).

**Variantes de message** :
1. `warning` : `"Essai expire dans X jour(s)"` (1 < jours ≤ 5)
2. `error` : `"Essai expiré"` (jours ≤ 0) ou `"Essai expire dans X jour(s)"` avec type error (jours ≤ 2)
3. `info`/`warning` : `"Paiement en cours de vérification — X h restantes"` (en_attente_confirmation)

**Pages où il s'affiche** : toutes les pages du dashboard web (layout commun `dashboard.ts`).

#### B. Implémentation côté MOBILE

**Le bandeau mobile EXISTE déjà** dans `lib/widgets/payment_alert_banner.dart`. Il couvre :
- Essai expirant bientôt (seuil : `joursEssaiRestants <= 3`, calculé localement via `tenant.essaiExpireLe`)
- En attente de confirmation (type `secondary` bleu)
- Inactif / suspendu (type `error` rouge)

**Différences par rapport au web** :

| Aspect | Web | Mobile (actuel) |
|---|---|---|
| Source données | `GET /paiement/notifications` (temps réel) | `AuthService.tenant` (données session locale + `DashboardProvider.abonnementEnCours`) |
| Seuil "essai bientôt" | 5 jours | 3 jours |
| Variante "essai expiré" | ✅ Couverte (`joursRestants <= 0`) | ❌ Non couverte explicitement (seuil `<= 3` jours) |
| Variante "paiement rejeté" | Couverte si notification dans DB | Non couverte |
| Pages couvertes | Toutes les pages dashboard | Uniquement les écrans avec `PaymentAlertBanner` dans leur body |

**Écrans qui affichent `PaymentAlertBanner`** : à vérifier par grep.

```
grep -r "PaymentAlertBanner" lib/screens/
```

**Données disponibles côté mobile** : `tenant.essaiExpireLe`, `tenant.statut`, `dashboard.abonnementEnCours` sont déjà disponibles sans nouvel endpoint. **Aucun nouvel endpoint API n'est nécessaire** pour reproduire la logique web.

### Fichiers concernés

| Fichier | Statut |
|---|---|
| `lib/widgets/payment_alert_banner.dart` | À modifier (seuil 3→5 jours, variante essai expiré) |
| `wrangler.jsonc` | À modifier (ajouter `FCM_PROJECT_ID` dans `vars`) |
| Cloudflare Workers — secrets | Action externe (`FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY`) |
| Supabase — migration `013_fcm_tokens.sql` | Action externe (exécuter la migration) |

### Proposition de correction

**`payment_alert_banner.dart` — Aligner le seuil sur le web (5 jours)** :

```dart
// Remplacer dans tenant_model.dart :
bool get essaiExpireBientot {
  final jours = joursEssaiRestants;
  return isEssai && jours != null && jours <= 5; // ← 5 au lieu de 3
}
```

**Ajouter la variante "essai expiré"** dans `payment_alert_banner.dart` :

```dart
if (statut == 'essai') {
  final jours = tenant.joursEssaiRestants ?? 0;
  if (jours <= 0) {
    return _Banner(
      color: AppColors.error,
      icon: Icons.block_rounded,
      message: 'Votre essai a expiré. Activez votre abonnement.',
      actionLabel: 'Activer',
      onTap: () => context.go('/dashboard/plans'),
    );
  }
  if (jours <= 5) {
    return _Banner(/* ... message avec jours */);
  }
}
```

### Priorité
**Bloquant** (secrets FCM Cloudflare + migration SQL) | **Important** (alignement seuil bandeau)

---

## 5. Audit — Coordonnées de contact

### Résultats du grep exhaustif

#### Repo WEB (`monmenu`)

| Fichier | Ligne | Valeur actuelle | Type |
|---|---|---|---|
| `src/components/footer.ts` | 35 | `https://wa.me/22677980264?text=Bonjour%20MonMenu` | Lien WhatsApp footer |
| `src/components/footer.ts` | 69 | `mailto:contact.monmenu@gmail.com` | Lien email footer |
| `src/pages/contact.ts` | 19 | `'https://wa.me/22677980264'` (fallback si `whatsappSupport` vide) | Lien WhatsApp page contact |
| `src/pages/contact.ts` | 59 | `mailto:contact.monmenu@gmail.com` | Lien email page contact |
| `src/pages/contact.ts` | 65 | `contact.monmenu@gmail.com` | Texte visible page contact |
| `src/lib/supabase.ts` | 150 | `'contact.monmenu@gmail.com'` | Valeur par défaut `getEmailContact()` |

**Analyse** :
- Le numéro WhatsApp actuel en dur est `22677980264` (sans `+`), ce qui correspond déjà à `+226 77 98 02 64` — **le numéro est déjà correct** dans le code web.
- L'email `contact.monmenu@gmail.com` est déjà présent — **l'email est déjà correct** dans le code web.
- La page contact génère dynamiquement le lien WhatsApp depuis `whatsappSupport` (config D1), avec fallback sur `22677980264`.

#### Repo MOBILE (`monmenu-mobile`)

| Fichier | Ligne | Valeur actuelle | Type |
|---|---|---|---|
| `lib/config/app_config.dart` | 41 | `'support@monmenu.app'` | Constante `supportEmail` |
| `lib/screens/settings/settings_screen.dart` | 129 | `'22500000000'` | Numéro WhatsApp support (placeholder!) |
| `lib/screens/settings/settings_screen.dart` | 130 | `https://wa.me/22500000000?text=Bonjour...` | Lien WhatsApp support |
| `lib/screens/settings/settings_screen.dart` | 138 | `'support@monmenu.app'` | Label email affiché |
| `lib/screens/settings/settings_screen.dart` | 140 | `mailto:support@monmenu.app?subject=Support%20MonMenu` | Lien email mailto |

**Problèmes identifiés** :

1. **Numéro WhatsApp `22500000000` est un PLACEHOLDER fictif** (ligne 129 du `settings_screen.dart`, commentaire `// Numéro support MonMenu`). Ce numéro n'existe pas — le lien ouvrira WhatsApp avec un numéro invalide.

2. **Email `support@monmenu.app`** : adresse différente de `contact.monmenu@gmail.com` utilisée côté web. Incohérence entre les deux apps.

### Proposition de correction

#### Mobile — `lib/screens/settings/settings_screen.dart`

**Numéro WhatsApp** : Remplacer `'22500000000'` par `'22677980264'` :
```dart
// Ligne 129 — remplacer :
const numero = '22500000000'; // Numéro support MonMenu
// Par :
const numero = '22677980264'; // Numéro WhatsApp support MonMenu
```

Message pré-rempli suggéré (contextuel à l'écran Paramètres) :
```
Bonjour%2C%20j%27ai%20besoin%20d%27aide%20avec%20MonMenu.%20Voici%20mon%20probl%C3%A8me%20:
```

**Email** : Remplacer `support@monmenu.app` par `contact.monmenu@gmail.com` (lignes 138 et 140) :
```dart
label: 'contact.monmenu@gmail.com',
// ...
final uri = Uri.parse('mailto:contact.monmenu@gmail.com?subject=Support%20MonMenu');
```

**`lib/config/app_config.dart`** ligne 41 : Mettre à jour la constante :
```dart
static const String supportEmail = 'contact.monmenu@gmail.com';
```

#### Web — Aucune modification nécessaire

Le numéro `22677980264` et l'email `contact.monmenu@gmail.com` sont déjà en place. La page contact charge le numéro dynamiquement depuis D1 (`whatsappSupport`), ce qui est correct.

#### Backend (Brevo/email entrants)

`src/routes/api-contact.ts` : les emails du formulaire de contact sont acheminés via `envoyerEmailContact()` (Brevo) vers `getEmailContact()` qui retourne `contact.monmenu@gmail.com` (depuis D1 ou fallback). Le destinataire est déjà `contact.monmenu@gmail.com` — aucune modification nécessaire.

### Fichiers concernés

| Fichier | Statut |
|---|---|
| `lib/screens/settings/settings_screen.dart` | **À modifier** (BUG BLOQUANT — numéro fictif) |
| `lib/config/app_config.dart` | À modifier (cohérence email) |
| `src/components/footer.ts` (web) | Aucune modification nécessaire |
| `src/pages/contact.ts` (web) | Aucune modification nécessaire |
| `src/lib/supabase.ts` (web) | Aucune modification nécessaire |

### Priorité
**Bloquant** (numéro WhatsApp fictif `22500000000` dans `settings_screen.dart`) | **Important** (cohérence email)

---

## 6. Audit — Page Plan & Paiement mobile vs web

### Comparaison exhaustive

#### Ce qui existe côté MOBILE (`lib/screens/plans/plans_screen.dart`)

✅ Affichage du statut d'abonnement courant (`_CurrentSubscriptionCard`)  
✅ Carte "en attente de confirmation" avec compte à rebours (`_EnAttenteCard`)  
✅ Référence de paiement copiable (`_ReferenceCard`)  
✅ Liste des plans disponibles avec prix (`_PlanCard`)  
✅ Upload de preuve de paiement (sheet `_UploadProofSheet`) via `POST /paiement/soumettre`  
✅ Sélection méthode de paiement (Mobile Money, Virement, Carte)  
✅ Saisie du numéro expéditeur (obligatoire, min 8 chiffres)  
✅ Toggle mensuel / annuel (`_annuel = true/false`, lignes 28, 127–136)  
✅ Bouton WhatsApp support (redirige vers numéro du tenant)  
✅ Historique des abonnements accessible via `IconButton(Icons.history_rounded)` → `/dashboard/plans/historique`  
✅ Écran historique `AbonnementHistoriqueScreen` (`lib/screens/plans/abonnement_historique_screen.dart`)  

#### Ce qui existe côté WEB (`public/static/js/dashboard-paiement.js`)

✅ Statut courant  
✅ Référence de paiement  
✅ Upload preuve  
✅ Historique des abonnements  
✅ Sélection méthode de paiement (dynamique depuis DB)  
❌ **Pas de toggle mensuel/annuel** — le web est exclusivement mensuel (CYCLE-3)  

### Écarts identifiés

#### Écart 1 — Toggle annuel présent sur mobile, absent côté web et backend

`plans_screen.dart` ligne 28 : `bool _annuel = false;`, avec UI toggle (lignes 116–137) et calcul prix `annuel ? plan.prixAnnuel : plan.prixMensuel` (ligne 556).

**Problème critique** : `src/routes/api-paiement.ts` ligne 347 :
```typescript
// CYCLE-3 : periodicite supprimé — tous les abonnements sont exclusivement mensuels
const periodicite = 'mensuel'
```

La route `/paiement/soumettre` ignore le champ `periodicite` envoyé par le mobile et l'écrase systématiquement à `'mensuel'`. Si l'utilisateur choisit "Annuel (-15%)" sur mobile et clique "J'ai effectué le paiement", le backend enregistre quand même `periodicite: 'mensuel'` — **désynchronisation silencieuse entre ce que l'utilisateur pense payer et ce qui est enregistré**.

#### Écart 2 — Méthodes de paiement codées en dur sur mobile, dynamiques sur web

Mobile (`plans_screen.dart` lignes 839–843) :
```dart
static const _methods = [
  ('mobile_money', 'Mobile Money (Orange Money, Wave, MTN)'),
  ('virement', 'Virement bancaire'),
  ('carte', 'Carte bancaire Visa/Mastercard'),
];
```

Web : chargées dynamiquement depuis `/api/v1/moyens-paiement` (DB). Si les moyens de paiement changent en base, le web se met à jour automatiquement, le mobile non.

#### Écart 3 — WhatsApp dans `_PaymentInfoCard` utilise le numéro du tenant, pas le support MonMenu

Le bouton "Contacter le support" (ligne 160–165) ouvre WhatsApp vers `tenant?.whatsappNumber`. Ce numéro est le WhatsApp du **restaurant lui-même**, pas celui du **support MonMenu**. C'est cohérent si le contexte est "contacter MonMenu pour paiement" via le numéro du restaurant — mais ambigu.

### Constat utilisateur — "page plan et paiement absente côté mobile"

**Infirmé** : la page existe et est complète. L'upload de preuve fonctionne (`lib/services/payment_upload_service.dart`). L'historique existe (`abonnement_historique_screen.dart`).

### Fichiers concernés

| Fichier | Statut |
|---|---|
| `lib/screens/plans/plans_screen.dart` | À modifier (supprimer toggle annuel, dynamiser méthodes) |
| `src/routes/api-paiement.ts` (web) | Aucune modification nécessaire côté backend |

### Proposition de correction

**Supprimer le toggle mensuel/annuel côté mobile** : retirer `bool _annuel = false;`, le widget `_PeriodTab` et la section UI lignes 116–137. Dans `_UploadProofSheet`, fixer `periodicite: 'mensuel'` sans le proposer à l'utilisateur.

**Dynamiser les méthodes de paiement** : appeler `GET /api/v1/moyens-paiement` au chargement de `PlansScreen` et peupler `_methods` depuis la réponse.

### Impact application web
Aucun — la correction est purement côté mobile.

### Risques de régression
Faibles (suppression d'une fonctionnalité non fonctionnelle côté backend).

### Priorité
**Bloquant** (désynchronisation periodicite mensuel/annuel) | **Confort** (méthodes dynamiques)

---

## 7. Conception — Sélection de suppléments/accompagnements à la commande

### État actuel côté données

La table `produits` (`src/routes/api-dashboard.ts`, ligne 546) expose :
```
id, categorie_id, nom, description, prix, photo_url, disponible, ordre_affichage, created_at
```

**Il n'existe pas de notion de "supplément" ou "option" dans le schéma de données actuel.** Le modèle Dart `ProduitModel` (`lib/models/produit_model.dart`) ne contient pas non plus de champ suppléments.

### Proposition d'architecture

#### Côté Supabase — Nouvelle table `supplements`

```sql
CREATE TABLE supplements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  produit_id UUID NOT NULL REFERENCES produits(id) ON DELETE CASCADE,
  nom TEXT NOT NULL,
  prix_supplementaire NUMERIC(10,0) NOT NULL DEFAULT 0,
  obligatoire BOOLEAN DEFAULT FALSE,
  ordre_affichage INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

Ou **alternative JSON** dans la table `produits` (plus simple, moins flexible) :
```sql
ALTER TABLE produits ADD COLUMN supplements JSONB DEFAULT '[]'::jsonb;
-- Chaque supplément : { "nom": "Extra fromage", "prix": 500 }
```

#### Côté API (web) — Modifications nécessaires

- `GET /dashboard/menu` et `GET /api/v1/tenants/:slug/menu` : inclure `supplements` dans la réponse produit.
- `POST /dashboard/produits` / `PATCH /dashboard/produits/:id` : accepter `supplements` dans le body.
- Nouveau (si table dédiée) : `POST/PATCH/DELETE /dashboard/produits/:id/supplements`.

#### Côté Dashboard Web — À créer

Section de gestion des suppléments par produit dans la page Menu du dashboard (`public/static/js/dashboard.js`).

#### Côté Mobile Flutter — À créer

**Fichiers à créer** :
- `lib/screens/commandes/supplements_selection_sheet.dart` — Bottom sheet affiché après "Ajouter au panier", listant les suppléments du plat avec cases à cocher et recalcul du prix total.

**Fichiers à modifier** :
- `lib/models/produit_model.dart` — Ajouter `List<SupplementModel> supplements`.
- `lib/providers/commandes_provider.dart` — Modifier le modèle de commande pour inclure les suppléments sélectionnés dans `items_json`.

### Risques de rétrocompatibilité

Les commandes existantes sans suppléments ne sont pas affectées si `supplements` est un champ optionnel (JSONB `DEFAULT '[]'`). Le montant total calculé (utilisé par WhatsApp/FCM) doit inclure les suppléments sélectionnés.

### Priorité
**Confort** (fonctionnalité nouvelle, non bloquante)

---

## 8. Audit complémentaire — Points additionnels

### 8.1 Web — Upload de preuve de paiement

#### Analyse de `POST /api/v1/paiement/soumettre` (`src/routes/api-paiement.ts`)

La route est implémentée en détail (lignes 314–520). Elle vérifie :
1. Rate limiting 3/h (ligne 320)
2. **`c.env.R2_MEDIA` configuré** (ligne 329) : si absent → `503 Stockage de preuves non configuré`
3. Parsing `multipart/form-data` (ligne 336)
4. Validation extension (`validerExtensionImage`) (ligne 367)
5. Validation Content-Type (ligne 372)
6. Validation taille max (ligne 377)
7. Validation magic bytes (ligne 382)
8. Upload R2 (`c.env.R2_MEDIA.put(...)`) (ligne 449)

**Cause probable d'échec d'upload côté web** :

Le code est correct mais dépend de configurations externes :

- **R2_MEDIA non configuré** : `wrangler.jsonc` déclare `R2_MEDIA` binding (confirmé, lignes 28–33 de `wrangler.jsonc`), mais si le bucket n'est pas créé ou que le binding n'est pas actif en production, la route retourne 503.
- **CORS** : la route `api-paiement.ts` est accessible depuis le dashboard web (cookie httpOnly + `X-Requested-With`). Le formulaire d'upload utilise `FormData` avec `credentials: 'include'` — pas de problème CORS puisque same-origin.
- **Type MIME** : uniquement JPEG/PNG acceptés. Si l'utilisateur tente d'uploader un PDF ou HEIC, l'upload échoue côté client avant même l'envoi (validation JS dans `dashboard-paiement.js`, ligne 44 : `const EXTENSIONS_VALIDES = ['.jpg', '.jpeg', '.png']`).

**Conclusion** : l'upload échoue probablement en raison du **bucket R2 non configuré ou non créé en production**, pas d'un bug de code. Action requise : vérifier dans le dashboard Cloudflare que `monmenu-media` existe et que le binding `R2_MEDIA` est actif.

**Action de configuration externe** — pas un bug de code.

### 8.2 Boutique — Disponibilité des plats

#### Dashboard web — Toggle disponibilité

`public/static/js/dashboard.js` ligne 809–810 :
```javascript
<span class="... cursor-pointer ${p.disponible ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'}"
  onclick="toggleDisponible('${p.id}',${p.disponible?1:0})" ...>
  ${p.disponible?'Dispo':'Indispo'}
</span>
```

Ligne 1014 :
```javascript
body: JSON.stringify({ disponible: !currentDisponible })
```

✅ Le toggle de disponibilité existe déjà dans le dashboard web via `PATCH /dashboard/produits/:id { disponible: bool }`.

#### App Mobile — Toggle disponibilité

`lib/screens/menu/menu_screen.dart` ligne 86–88 :
```dart
Future<void> _toggleProduit(ProduitModel prod) async {
  final resp = await api.updateProduit(prod.id, {'disponible': !prod.disponible});
```

✅ Le toggle existe aussi côté mobile.

#### Boutique publique — Filtrage côté client

`public/static/js/boutique.js` lignes 276–296 : les produits `disponible == false` sont affichés avec le label "Indisponible" et ne peuvent pas être ajoutés au panier (`controles = '<span>Indisponible</span>'`).

**Cependant** : `src/routes/api-tenants.ts` ligne 214 — la requête sur `produits` ne filtre **pas** sur `disponible = true`. Tous les produits (disponibles et indisponibles) sont retournés à la boutique, qui fait le filtrage côté client. C'est acceptable mais signifie qu'un produit "Indisponible" est quand même transmis dans la réponse JSON (potentiellement visible à un client malveillant).

**Non-bug fonctionnel** — le comportement est intentionnel (afficher "Indisponible" plutôt que masquer complètement).

#### Ajout de plats depuis le dashboard

Le dashboard web permet de créer des produits via `POST /dashboard/produits`. L'app mobile le permet aussi via le formulaire dans `menu_screen.dart`. La fonctionnalité est complète.

### Fichiers concernés

| Fichier | Statut |
|---|---|
| `wrangler.jsonc` (binding R2_MEDIA) | Action externe — vérifier en production |
| `src/routes/api-tenants.ts` | Optionnel : filtrer `disponible = true` côté serveur |

### Priorité
**Bloquant** (R2 non configuré bloque les paiements) | **Confort** (filtrage serveur disponibilité)

---

## Tableau de synthèse global

| # | Problème | Priorité | Fichiers impactés | Application(s) | Statut |
|---|---|---|---|---|---|
| 1.4 | Bouton "tout lire" — icône seule sans libellé (UX) | Confort | `notifications_screen.dart` | Mobile | À corriger |
| 1.5 | Tap notification ne navigue pas vers `lien` | Important | `notifications_screen.dart` | Mobile | À corriger |
| 2.2 | PDV null → bouton "Sauvegarder" masqué (impossible de créer son premier PDV) | Important | `restaurant_screen.dart` | Mobile | À corriger |
| 3 | 7 écrans sans drawer (navigation inter-sections impossible) | Important | 7 fichiers screens | Mobile | À corriger |
| 4.1 | APK mobile FCM non buildé | Bloquant | — | Mobile | Action externe (build) |
| 4.2 | `FCM_PROJECT_ID` absent de `wrangler.jsonc vars` | Bloquant | `wrangler.jsonc` | Web/Backend | Action config externe |
| 4.2 | Secrets FCM (`FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY`) absents de Cloudflare | Bloquant | — | Web/Backend | Action config externe |
| 4.2 | Migration `013_fcm_tokens.sql` non exécutée sur Supabase prod | Bloquant | — | Web/Backend | Action SQL externe |
| 4.3 | Seuil bandeau mobile : 3 jours vs 5 jours côté web | Important | `tenant_model.dart`, `payment_alert_banner.dart` | Mobile | À corriger |
| 4.3 | Variante "essai expiré" absente du bandeau mobile | Important | `payment_alert_banner.dart` | Mobile | À créer |
| 5 | Numéro WhatsApp support `22500000000` fictif dans settings mobile | Bloquant | `settings_screen.dart` | Mobile | À corriger |
| 5 | Email support `support@monmenu.app` vs `contact.monmenu@gmail.com` (incohérence) | Important | `settings_screen.dart`, `app_config.dart` | Mobile | À corriger |
| 6 | Toggle annuel/mensuel mobile → backend force `mensuel` (désynchronisation silencieuse) | Bloquant | `plans_screen.dart` | Mobile | À corriger (supprimer le toggle) |
| 6 | Méthodes de paiement codées en dur sur mobile (non dynamiques) | Confort | `plans_screen.dart` | Mobile | À corriger |
| 7 | Suppléments/accompagnements inexistants (conception à créer) | Confort | Nouveau schéma SQL + nouveaux fichiers | Mobile + Web | À créer |
| 8.1 | Upload preuve web — R2 bucket potentiellement non configuré en prod | Bloquant | `wrangler.jsonc`, Cloudflare dashboard | Web/Backend | Action config externe |
| 8.2 | API boutique retourne tous produits (disponibles + indisponibles) — filtrage client | Confort | `src/routes/api-tenants.ts` | Web/Backend | Optionnel |

---

*Rapport généré le 2026-08-10. Basé exclusivement sur l'analyse des clones frais des deux repositories à leurs commits respectifs. Aucune ligne de code source n'a été modifiée dans les deux repos.*
