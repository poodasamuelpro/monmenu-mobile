# CHANGELOG — Module Paiement MonMenu Mobile

## [1.0.0] — 2025-07-17

### Module Paiement — PUSH 3 (commit 935bde6)

#### Modèles

**`lib/models/tenant_model.dart`** — Réécriture complète
- Ajout classe `PaiementEnAttenteModel` avec champs :
  - `statut` (always `'en_attente_confirmation'`)
  - `soumisLe` (DateTime)
  - `delaiConfirmationExpireLe` (DateTime?)
  - `heuresRestantes` (int?)
  - `message38h` (String?)
  - `abonnementId` (String?)
  - Getters : `heuresRestantesCalculees`, `estExpire`
- `TenantModel` : ajout `referencePaiement` (String?)
- `TenantModel` : ajout `paiementEnAttente` (PaiementEnAttenteModel?)
- `canAccess` : inclut désormais `'en_attente_confirmation'` (SEC-04)
- Getter `isEnAttenteConfirmation`
- Getter `essaiExpireBientot` (essai + joursEssaiRestants ≤ 3)

**`lib/models/plan_model.dart`** — Enrichissement `AbonnementModel`
- 11 nouveaux champs : `montantPaye`, `devise`, `methodePaiement`, `preuveUrl`, `referencePaiement`, `confirmeParNom`, `confirmeLe`, `soumisLe`, `rejeteLe`, `motifRejet`, `delaiConfirmationExpireLe`, `heuresRestantesConfirmation`
- Nouveaux getters : `isEnAttente`, `isRejete`, `heuresAvantExpirationAdmin`, `statutLibelle`
- `fromJson` gère les alias : `date_debut`/`debut_le`, `date_fin`/`fin_le`, `plan`/`plans`

#### Services

**`lib/services/api_service.dart`** — 5 méthodes paiement ajoutées
- `import 'dart:async'` pour `TimeoutException`
- `getAbonnementActif()` → `GET /paiement/statut`
- `getReferencePaiement()` → `GET /paiement/reference`
- `soumettrePreuvePaiement({filePath, planId, methodePaiement, periodicite})` → multipart upload, SEC-02
- `getHistoriqueAbonnements({page, limit})` → `GET /paiement/historique`
- `getPaiementNotifications()` → `GET /paiement/notifications`

**`lib/services/payment_upload_service.dart`** — Créé
- Classes valeur : `ImagePickResult`, `UploadResult`, `PendingUpload`
- `pickAndCompressImage({source})` : galerie ou camera, compress 80% max 800×600
- `uploadPreuve({filePath, planId, methodePaiement, periodicite})` : MIME validation, <5MB check
- `retryPendingUploadIfNeeded()` : re-vérifie statut serveur (SEC-07), retry si toujours pending
- `purgeLocalProofs()` : nettoyage fichiers locaux
- `hasPendingUpload()` : vérifie si un upload est en attente
- Stockage : `path_provider` répertoire privé application (SEC-10)

**`lib/services/notification_service.dart`** — Créé
- Supabase Realtime sur table `tenants` (filtre par `id`)
- `subscribeTenantStatus(tenantId)` : écoute les changements de statut
- `_sendLocalNotification(statut)` : notifications locales pour `actif`, `rejete`, `en_attente_confirmation`
- `onTenantStatusChange` : callback pour propager vers UI
- Architecture FCM-ready (documentée, non implémentée)

**`lib/services/realtime_service.dart`** — Extension
- Ajout `_tenantChannel` (RealtimeChannel Supabase)
- `subscribeTenantStatus(tenantId)` : canal dédié tenant
- `onTenantStatusChange` callback
- `unsubscribeTenantStatus()` : fermeture propre
- `unsubscribe()` mis à jour pour inclure le canal tenant

#### Providers

**`lib/providers/dashboard_provider.dart`** — Réécriture
- Enum `UploadStatut { idle, loading, success, error }`
- `loadAbonnement()` → appelle `getAbonnementActif()`
- `loadReferencePaiement()` → appelle `getReferencePaiement()`
- `setUploadLoading()`, `setUploadSuccess(Map)`, `setUploadError(String)`, `resetUpload()`
- Getters : `hasAbonnementEnAttente`, `statutTenant`, `abonnementEnCours`, `joursEssaiRestants`
- `uploadStatut`, `uploadError`, `uploadData` exposés

#### UI — Screens

**`lib/screens/plans/plans_screen.dart`** — Réécriture complète
- Import `api_service.dart`
- `_uploadService` initialisé via `context.read<ApiService>()`
- `_countdownTimer` : `Timer.periodic(Duration(minutes: 1), ...)` avec dispose
- `initState` : charge `loadPlans`, `loadProfil`, `loadAbonnement`, `loadReferencePaiement`
- Bouton "Historique" dans AppBar → `/dashboard/plans/historique`
- Widgets nouveaux :
  - `_CurrentSubscriptionCard` : plan actuel + dates
  - `_EnAttenteCard` : état en attente + countdown 38h
  - `_ReferenceCard` : référence copiable
  - `_PaymentInfoCard` : modes paiement + contact
  - `_UploadProofSheet` : StatefulWidget avec RadioListTile méthodes, ImagePicker, `_submitProof()`
- `_openWhatsApp()` : `canLaunchUrl` + `launchUrl(url, mode: LaunchMode.externalApplication)`

**`lib/screens/plans/abonnement_historique_screen.dart`** — Créé
- Liste paginée avec `ScrollController` lazy-load
- `_AbonnementCard` : référence, montant, méthode, dates début/fin, motif rejet
- États : chargement initial, erreur, liste vide, données, chargement page suivante

#### UI — Widgets

**`lib/widgets/payment_alert_banner.dart`** — Créé
- État 1 — Essai bientôt expiré (orange) : `essaiExpireBientot == true`
- État 2 — En attente confirmation (bleu) : `isEnAttenteConfirmation == true`
- État 3 — Inactif/suspendu (rouge) : `statut == 'inactif' || statut == 'suspendu'`
- Tap → navigation vers `/dashboard/plans`

**`lib/screens/dashboard/dashboard_screen.dart`** — Modifications
- Import `payment_alert_banner.dart`
- `const PaymentAlertBanner()` ajouté en tête du body column
- `_EssaiBanner` conditionnel : `!tenant.essaiExpireBientot` (évite double affichage)
- `dashboard.loadAbonnement()` ajouté dans `initState` et `onRefresh`

**`lib/widgets/app_drawer.dart`** — Modifications
- Suppression import `DashboardProvider` (inutilisé)
- `showPaymentBadge` : `tenant.statut == 'en_attente_confirmation' || tenant.statut == 'inactif' || tenant.essaiExpireBientot`
- Paramètre `badge` ajouté à `_NavItem`
- Point orange (8×8, `AppColors.warning`) sur item "Plans & Paiement" si `badge && !isActive`

#### Config

**`lib/main.dart`** — Modifications
- Import `abonnement_historique_screen.dart`
- Route imbriquée sous `/dashboard/plans` :
  ```dart
  GoRoute(path: 'historique', builder: (_, __) => const AbonnementHistoriqueScreen())
  ```

**`android/app/build.gradle.kts`** — Réécriture
- `isCoreLibraryDesugaringEnabled = true` (requis par flutter_local_notifications ≥17)
- `minSdk = 21`, `multiDexEnabled = true`
- `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`
- Configuration signing release depuis `key.properties`

**`ios/Runner/Info.plist`** — Modifications
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`

**`pubspec.yaml`** — Modifications
- Suppression doublon `image_picker`
- Section "Paiement" ajoutée :
  - `flutter_image_compress: ^2.3.0`
  - `path_provider: ^2.1.5`
  - `mime: ^1.0.6`

---

## [0.9.0] — Précédent — PUSH 2 (commit 758ecdc)

### Fonctionnalités restaurant complètes

- `livreurs_screen.dart` : CRUD livreurs complet
- `qrcode_screen.dart` : Génération QR + copie + partage
- `codes_promo_screen.dart` : CRUD codes promo
- `restaurant_screen.dart` : Édition PDV + horaires + tarifs livraison
- `apparence_screen.dart` : Color picker + aperçu temps réel
- `menu_screen.dart` : CRUD menu complet avec tabs catégories
- `api_service.dart` : createLivreur, updateLivreur, deleteLivreur, updateCodePromo, deleteCodePromo, getQrCode
- `main.dart` : Remplacement 5 PlaceholderScreen

---

## [0.8.0] — PUSH 1 initial

- Architecture de base Flutter
- Authentification Supabase
- Tableau de bord avec stats
- Liste commandes avec Realtime
- Design system MonMenu (#DC2626, #1D4ED8, #111827)

---

## Corrections — PUSH 4 (Audit RAPPORT-AUDIT-02)

### fix(commande_detail): WhatsApp client
- Ajout `import 'package:url_launcher/url_launcher.dart'`
- Méthode `_openWhatsApp(telephone)` avec nettoyage numéro
- Bouton vert `#25D366` "Contacter sur WhatsApp" dans section Client

### fix(settings): Support fonctionnel
- Support WhatsApp → `https://wa.me/22500000000?text=...`
- Email support → `mailto:support@monmenu.app`
- `canLaunchUrl` + `launchUrl` pour les deux

### fix(qrcode): Partage WhatsApp réel
- `_shareUrl()` → `https://wa.me/?text={url encodée}`
- Fallback Clipboard si WhatsApp indisponible

### fix(apparence): Dialog upload informatif
- Remplace SnackBar par `AlertDialog` avec URL sélectionnable
- Bouton "Ouvrir le web" avec `url_launcher`

### fix(commandes_provider): Préservation champs modèle
- `_onStatutChange()` préserve : `livreurId`, `codePromoId`, `reductionAppliquee`, `numeroCommande`, `pointDeVenteId`, `modesPaiementId`

### fix(theme): TenantStatut en_attente_confirmation
- `TenantStatut.color('en_attente_confirmation')` → `AppColors.info` (bleu)
- `TenantStatut.label('en_attente_confirmation')` → `'En attente'`
