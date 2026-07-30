# MonMenu Mobile — Application Flutter

Application mobile de gestion de restaurant pour les restaurateurs MonMenu. Interface complète pour gérer commandes, menu, statistiques, livreurs et abonnements.

## Stack Technique

| Technologie | Version | Usage |
|-------------|---------|-------|
| Flutter | 3.35.4 | Framework UI |
| Dart | 3.9.2 | Langage |
| Supabase | Auth + Realtime | Auth JWT + WebSocket temps réel |
| API MonMenu | `https://monmenu.app/api/v1` | Backend Cloudflare Workers + Hono.js |
| go_router | ^14.4.1 | Navigation déclarative |
| provider | 6.1.5+1 | State management |
| fl_chart | ^0.69.0 | Graphiques statistiques |
| flutter_secure_storage | — | Stockage token Android Keystore |
| flutter_image_compress | ^2.3.0 | Compression preuves paiement |
| flutter_local_notifications | ^17.2.3 | Notifications locales statut |
| hive + hive_flutter | 2.2.3 / 1.1.0 | Cache local |
| url_launcher | ^6.3.1 | WhatsApp deeplinks |
| qr_flutter | — | Affichage QR Code |

## Fonctionnalités

### Tableau de bord
- KPIs en temps réel (commandes, CA, en attente)
- Graphique 30 jours (fl_chart)
- Bandeau alertes paiement intelligent (essai expirante, en attente confirmation, bloqué)
- Indicateur connexion Realtime Supabase

### Commandes
- Liste avec filtres par statut (toutes / en_attente / confirmée / en_préparation / en_livraison / livrée / annulée)
- Compteur commandes en attente en temps réel
- Progression statut (bouton "Confirmer" / "En préparation" / etc.)
- Détail commande : articles, montants, frais livraison, réductions
- **Bouton WhatsApp** pour contacter directement le client depuis le détail
- Annulation avec confirmation

### Menu
- CRUD catégories (créer, modifier, supprimer)
- CRUD produits (nom, description, prix, image URL, disponibilité)
- Toggle disponibilité temps réel
- Navigation par onglets catégories
- Variantes produits affichées

### Statistiques
- 4 KPI cards (total commandes, CA, commandes aujourd'hui, CA aujourd'hui)
- LineChart commandes 30j
- LineChart CA 30j
- Tableau détail 14 derniers jours

### Restaurant
- Édition Point de Vente (nom, adresse, téléphone, email, slogan)
- Horaires d'ouverture par jour (toggle + time picker)
- Tarifs livraison (base + par km)
- **Apparence** : palette couleurs + custom hex + aperçu temps réel + lien vers upload web
- **QR Code** : affichage avec logo centré, copie URL, **partage WhatsApp**

### Livreurs
- CRUD livreurs (nom, téléphone, email, actif/inactif)
- Toggle statut actif
- Compteurs commandes en cours et total

### Codes Promo
- Création avec : code, type (pourcentage/montant fixe), valeur, min commande, max utilisations, date expiration
- Générateur de code aléatoire
- Toggle actif
- Affichage statut (actif/inactif/expiré/épuisé)

### Plans & Paiement (Module complet)
- Affichage plan actuel + statut tenant
- **Référence de paiement** copiable
- **Upload preuve de paiement** : galerie ou camera, compression 80% max 800×600, validation <5MB, multipart upload
- Informations de paiement (méthodes acceptées, WhatsApp support)
- **État en_attente_confirmation** : badge + countdown 38h
- **Historique abonnements** paginé avec lazy-scroll
- **Retry upload** avec vérification serveur (SEC-07)
- Stockage local preuve en attente (path_provider, SEC-10)
- Notifications locales : confirmation paiement, rejet, activation

### Paramètres
- Profil restaurant avec badge statut
- Liens de navigation rapide
- **Support WhatsApp** fonctionnel + **email support** cliquable
- Déconnexion avec confirmation

### Auth
- Login email/password
- Validation formulaire
- Lien mot de passe oublié
- Token JWT stocké via flutter_secure_storage (Android Keystore)

## Architecture

```
lib/
├── config/
│   └── app_config.dart          # URLs Supabase + API
├── models/
│   ├── tenant_model.dart        # TenantModel + PaiementEnAttenteModel
│   ├── plan_model.dart          # AbonnementModel enrichi
│   ├── commande_model.dart      # CommandeModel + CommandeItemModel
│   ├── livreur_model.dart       # LivreurModel, CodePromoModel, PointDeVenteModel
│   └── produit_model.dart       # ProduitModel, CategorieModel, VarianteModel
├── services/
│   ├── api_service.dart         # HTTP client + méthodes paiement
│   ├── auth_service.dart        # Auth Supabase + tenant
│   ├── realtime_service.dart    # Supabase Realtime (commandes + tenant)
│   ├── payment_upload_service.dart  # Upload preuve paiement
│   └── notification_service.dart   # Notifications locales
├── providers/
│   ├── dashboard_provider.dart  # Stats + abonnement state
│   └── commandes_provider.dart  # Liste + filtres + realtime
├── screens/
│   ├── auth/                    # login, forgot_password
│   ├── dashboard/               # dashboard_screen
│   ├── commandes/               # commandes_screen, commande_detail_screen
│   ├── menu/                    # menu_screen
│   ├── stats/                   # stats_screen
│   ├── settings/                # settings_screen
│   ├── plans/                   # plans_screen, abonnement_historique_screen
│   └── restaurant/              # restaurant, apparence, livreurs, qrcode, codes_promo
├── widgets/
│   ├── app_drawer.dart          # Sidebar avec badge paiement
│   ├── commande_card.dart       # Card commande
│   ├── statut_badge.dart        # Badges statuts commande + tenant
│   ├── loading_widget.dart      # Loading, Error, Shimmer
│   └── payment_alert_banner.dart # Bannière alerte paiement
├── theme/
│   └── app_theme.dart           # Design system MonMenu (rouge #DC2626, bleu #1D4ED8)
└── main.dart                    # Routes go_router + MultiProvider
```

## Design System

| Variable | Valeur | Usage |
|----------|--------|-------|
| `AppColors.primary` | `#DC2626` | Rouge principal (boutons, accents) |
| `AppColors.secondary` | `#1D4ED8` | Bleu secondaire |
| `AppColors.sidebar` | `#111827` | Fond drawer |
| `AppColors.background` | `#F9FAFB` | Fond app |
| `AppColors.success` | `#10B981` | Succès / livrée |
| `AppColors.warning` | `#F59E0B` | En attente / essai |
| `AppColors.error` | `#EF4444` | Erreur / annulée |
| `AppColors.info` | `#3B82F6` | En attente confirmation |

## Flux Paiement

```
Restaurant                    API MonMenu                   Admin
    │                              │                            │
    ├─ GET /paiement/reference ───>│                            │
    │<── référence unique ─────────┤                            │
    │                              │                            │
    ├─ Paiement externe ───────────────────────────────────────>│
    │                              │                            │
    ├─ POST /paiement/preuve ─────>│                            │
    │  (multipart: photo, planId)  │                            │
    │<── {statut: en_attente} ─────┤                            │
    │                              │                            │
    │    [Timer 38h commence]      │── Notification admin ─────>│
    │                              │                            │
    │<── Realtime WebSocket ───────┤<── Confirme/Rejette ───────│
    │    {statut: actif|rejete}    │                            │
    │                              │                            │
    ├─ Notification locale ────────┤                            │
```

## Sécurité

- **SEC-02** : Token JWT jamais loggué (api_service.dart, payment_upload_service.dart)
- **SEC-04** : `en_attente_confirmation` donne accès pendant 72h (FENETRE_TOLERANCE)
- **SEC-07** : Retry upload re-vérifie le statut serveur avant envoi
- **SEC-10** : Preuves stockées dans répertoire privé app (path_provider)

## Build

### Web (preview)
```bash
flutter pub get
flutter build web --release
python3 -m http.server 5060 --directory build/web
```

### APK Release
```bash
# Prérequis: android/key.properties + release-key.jks
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk (~57 MB)
```

### Dépendances Android
```kotlin
// android/app/build.gradle.kts
compileOptions { isCoreLibraryDesugaringEnabled = true }
defaultConfig { minSdk = 21; multiDexEnabled = true }
dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }
```

## Permissions Android

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

## Variables d'environnement

Configurées dans `lib/config/app_config.dart` :
```dart
static const supabaseUrl = 'https://vkgtcfwnrhnvhsooiovm.supabase.co';
static const apiBaseUrl = 'https://monmenu.app/api/v1';
```

## Qualité

- `flutter analyze` : ✅ 0 erreurs, 0 warnings, 5 infos non-bloquants
- Build APK release : ✅ 57 MB
- Build web : ✅ SUCCESS

---

*MonMenu Mobile v1.0.0 — Flutter 3.35.4 / Dart 3.9.2*
