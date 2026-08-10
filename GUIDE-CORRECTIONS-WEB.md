# GUIDE-CORRECTIONS-WEB.md
## MonMenu Manager — FCM Push Notifications
## Rédigé par l'agent Flutter/backend — Session du 2026-08-10
## Périmètre : dépôt mobile uniquement (monmenu-mobile)

---

## SECTION 1 — CE QUI A ÉTÉ IMPLÉMENTÉ CÔTÉ MOBILE

### Fichiers créés

#### `lib/services/fcm_service.dart` (nouveau)
- Fonction top-level `firebaseMessagingBackgroundHandler` (@pragma vm:entry-point)
  - Re-initialise Firebase dans l'isolate background
  - Crée les canaux Android dans l'isolate
  - Affiche une notification locale pour les messages data-only
- Fonctions utilitaires top-level :
  - `_initPluginForBackground()` — init flutter_local_notifications en background
  - `_showLocalNotificationFromFcm()` — affiche notif locale depuis message FCM
  - `_defaultTitle(type)` — titre par défaut selon type métier
  - `_channelForType(type)` — mappe type métier → canal Android
  - `_buildNotificationDetails(channelId)` — construit NotificationDetails
- Classe `FCMService` :
  - `init(onTokenReceived, onForegroundMessage, onAppOpenedFromNotif)` — init complète
  - `_fetchAndSendToken()` — récupère token FCM et appelle callback
  - `deleteToken()` — supprime token à la déconnexion
  - `subscribeToTopic(topic)` / `unsubscribeFromTopic(topic)` — topics FCM
  - Propriétés : `fcmToken`, `isActive`
- Dédoublonnage foreground : `setForegroundNotificationPresentationOptions(alert: false, sound: false)`

#### `android/app/src/main/res/values/colors.xml` (nouveau)
- `notification_color` = #DC2626 (rouge MonMenu, couleur d'accent FCM)

#### `android/app/google-services.json` (nouveau)
- Fichier fourni par Samuel
- `project_id` = monmenumanager
- `package_name` = com.monmenumanager.manage ✅ (correspond à applicationId)

---

### Fichiers modifiés

#### `pubspec.yaml`
- Ajout : `firebase_core: 3.6.0`
- Ajout : `firebase_messaging: 15.1.3`

#### `android/app/build.gradle.kts`
- Ajout plugin : `id("com.google.gms.google-services")`

#### `android/settings.gradle.kts`
- Ajout plugin : `id("com.google.gms.google-services") version "4.4.2" apply false`

#### `android/app/src/main/AndroidManifest.xml`
- Ajout service : `com.google.firebase.messaging.FirebaseMessagingService` avec intent MESSAGING_EVENT
- Ajout meta-data : icône FCM, couleur FCM, canal FCM par défaut (commandes_channel)

#### `lib/config/app_config.dart`
- Ajout : `fcmTokenEndpoint = '/dashboard/fcm-token'`
- Ajout : `fcmChannelCommandes = 'commandes_channel'`
- Ajout : `fcmChannelPaiement = 'payment_channel'`
- Ajout : `firebaseProjectId = 'monmenumanager'`

#### `lib/services/api_service.dart`
- Ajout méthode : `saveFcmToken(String token)` → POST /dashboard/fcm-token
- Ajout méthode : `deleteFcmToken(String token)` → DELETE /dashboard/fcm-token?token=xxx

#### `lib/main.dart`
- Ajout import : `firebase_core`, `fcm_service.dart`
- Ajout `Firebase.initializeApp()` AVANT `Supabase.initialize()` dans `main()`
- Ajout `FCMService _fcmService` dans `_MonMenuAppState`
- Ajout `Provider.value(value: _fcmService)` dans MultiProvider
- Ajout méthode `_initFCM()` avec 3 callbacks complets :
  - `onTokenReceived` → `_apiService.saveFcmToken()`
  - `onForegroundMessage` → dédoublonnage + rechargement commandes si type=commande
  - `onAppOpenedFromNotif` → navigation GoRouter vers commande ou plans selon type
- Ajout méthode `logoutWithFCMCleanup()` — supprime token avant déconnexion
- Appel `_initFCM()` après restauration de session

---

### Fichiers non modifiés (non-régression confirmée)

| Fichier | Raison | État |
|---------|--------|------|
| `lib/services/notification_service.dart` | Fonctionnel, dédoublonnage géré via FCMService | ✅ Intact |
| `lib/services/realtime_service.dart` | Fonctionnel, aucun conflit FCM | ✅ Intact |
| `lib/widgets/in_app_notification_banner.dart` | Fonctionnel, connecté à NotificationService | ✅ Intact |
| `lib/screens/notifications/notifications_screen.dart` | Fonctionnel, liste Supabase | ✅ Intact |
| `lib/services/auth_service.dart` | Non modifié — logout via `logoutWithFCMCleanup()` dans main | ✅ Intact |

---

## SECTION 2 — CE QUI DOIT ÊTRE FAIT CÔTÉ WEB/BACKEND

### ⚠️ IMPORTANT : Ces éléments ne peuvent PAS être implémentés côté mobile

---

### 2.1 — Table Supabase `fcm_tokens` (OBLIGATOIRE)

**Pourquoi pas côté mobile :** La table Supabase est une infrastructure backend. Le mobile ne peut pas créer de tables SQL.

**Où le faire :** Supabase Dashboard → SQL Editor → Nouvelle requête

**SQL à exécuter :**
```sql
-- Table pour stocker les tokens FCM des devices des restaurateurs
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id   UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  token       TEXT NOT NULL UNIQUE,
  platform    TEXT NOT NULL DEFAULT 'android' CHECK (platform IN ('android', 'ios', 'web')),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour requêtes par tenant (performances)
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_tenant_id ON public.fcm_tokens(tenant_id);

-- RLS — seul le service role (backend) peut lire/écrire
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_all" ON public.fcm_tokens
  FOR ALL USING (auth.role() = 'service_role');

-- Nettoyage automatique des tokens inactifs > 60 jours
CREATE OR REPLACE FUNCTION public.cleanup_old_fcm_tokens()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM public.fcm_tokens
  WHERE updated_at < NOW() - INTERVAL '60 days';
END;
$$;
```

---

### 2.2 — Variables d'environnement Cloudflare Workers (OBLIGATOIRE)

**Pourquoi pas côté mobile :** Les secrets Firebase Admin ne peuvent pas être dans le code mobile (risque de fuite APK).

**Où le faire :** Cloudflare Dashboard → Workers → monmenu → Settings → Variables

**Variables à ajouter (type Secret) :**

| Nom variable | Source dans le JSON | Description |
|-------------|---------------------|-------------|
| `FCM_PROJECT_ID` | `project_info.project_id` du `google-services.json` | = `monmenumanager` |
| `FCM_CLIENT_EMAIL` | `client_email` du **JSON compte de service Firebase Admin** | Ex: `firebase-adminsdk-xxx@monmenumanager.iam.gserviceaccount.com` |
| `FCM_PRIVATE_KEY` | `private_key` du **JSON compte de service Firebase Admin** | Clé RSA complète avec `\n` |

> **⚠️ IMPORTANT** : `FCM_CLIENT_EMAIL` et `FCM_PRIVATE_KEY` proviennent du JSON du **compte de service Firebase Admin** (pas du google-services.json). Samuel doit le télécharger dans Firebase Console → Project Settings → Service accounts → Generate new private key.

---

### 2.3 — Routes backend Cloudflare Workers (OBLIGATOIRE)

**Fichier concerné :** `monmenu-web/src/routes/api-dashboard.ts`

**Pourquoi pas côté mobile :** Ce sont des routes HTTP côté serveur.

#### Route 1 : POST /api/v1/dashboard/fcm-token
À ajouter dans `api-dashboard.ts` après les routes notifications existantes :

```typescript
// POST /api/v1/dashboard/fcm-token — Enregistrer token FCM du device
dashboardRouter.post('/fcm-token', authenticateJWT, async (c) => {
  const { token, platform } = await c.req.json();
  
  if (!token || typeof token !== 'string' || token.length < 100) {
    return c.json({ error: 'Token FCM invalide' }, 422);
  }

  const supabase = createSupabaseServiceClient(c); // service role pour bypasser RLS
  const tenantId = c.get('tenantId');

  const { error } = await supabase
    .from('fcm_tokens')
    .upsert({
      tenant_id: tenantId,
      token: token,
      platform: platform ?? 'android',
      updated_at: new Date().toISOString(),
    }, { onConflict: 'token' });

  if (error) {
    console.error('[FCM] Erreur upsert token:', error.message);
    return c.json({ error: 'Erreur sauvegarde token' }, 500);
  }

  return c.json({ success: true });
});

// DELETE /api/v1/dashboard/fcm-token?token=xxx — Supprimer à la déconnexion
dashboardRouter.delete('/fcm-token', authenticateJWT, async (c) => {
  const token = c.req.query('token');
  if (!token) return c.json({ error: 'Token requis' }, 422);

  const supabase = createSupabaseServiceClient(c);

  await supabase
    .from('fcm_tokens')
    .delete()
    .eq('token', decodeURIComponent(token));

  return c.json({ success: true });
});
```

---

### 2.4 — Helper FCM : sendFcmNotification (OBLIGATOIRE)

**Fichier à créer :** `monmenu-web/src/lib/fcm.ts` (nouveau fichier)

**Pourquoi pas côté mobile :** C'est un appel serveur→FCM avec clé privée.

```typescript
// monmenu-web/src/lib/fcm.ts
// Helper Firebase Cloud Messaging v1 — Envoi de push via OAuth2 RS256

export interface FcmPayload {
  token: string;        // Token FCM du device destinataire
  title: string;        // Titre de la notification
  body: string;         // Corps de la notification
  data?: Record<string, string>; // Données métier (type, commandeId, etc.)
  channelId?: string;   // Canal Android ('commandes_channel' | 'payment_channel')
}

// Obtenir un access_token OAuth2 pour FCM v1
// Utilise JWT signé RS256 avec les credentials du compte de service Firebase Admin
async function getFcmAccessToken(env: {
  FCM_CLIENT_EMAIL: string;
  FCM_PRIVATE_KEY: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');

  const payload = btoa(JSON.stringify({
    iss: env.FCM_CLIENT_EMAIL,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');

  const privateKeyPem = env.FCM_PRIVATE_KEY.replace(/\\n/g, '\n');
  const keyContent = privateKeyPem
    .replace('-----BEGIN RSA PRIVATE KEY-----', '')
    .replace('-----END RSA PRIVATE KEY-----', '')
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');

  const binaryKey = Uint8Array.from(atob(keyContent), c => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8', binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['sign']
  );

  const signingInput = `${header}.${payload}`;
  const signatureBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');

  const jwt = `${signingInput}.${signature}`;

  const tokenResp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResp.json() as { access_token: string };
  return tokenData.access_token;
}

// Envoyer une notification FCM à un device
export async function sendFcmNotification(
  env: { FCM_PROJECT_ID: string; FCM_CLIENT_EMAIL: string; FCM_PRIVATE_KEY: string },
  payload: FcmPayload
): Promise<boolean> {
  try {
    const accessToken = await getFcmAccessToken(env);
    const channelId = payload.channelId ?? 'commandes_channel';

    const fcmMessage = {
      message: {
        token: payload.token,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data ?? {},
        android: {
          priority: 'high',
          notification: {
            channel_id: channelId,
            sound: 'default',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            icon: 'ic_launcher',
            color: '#DC2626',
          },
        },
      },
    };

    const resp = await fetch(
      `https://fcm.googleapis.com/v1/projects/${env.FCM_PROJECT_ID}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(fcmMessage),
      }
    );

    if (!resp.ok) {
      const err = await resp.text();
      console.error(`[FCM] Erreur envoi (${resp.status}):`, err);
      return false;
    }

    return true;
  } catch (e) {
    console.error('[FCM] Exception sendFcmNotification:', e);
    return false;
  }
}

// Envoyer une notification à TOUS les devices d'un tenant
export async function sendFcmToTenant(
  env: { FCM_PROJECT_ID: string; FCM_CLIENT_EMAIL: string; FCM_PRIVATE_KEY: string },
  supabase: any,
  tenantId: string,
  payload: Omit<FcmPayload, 'token'>
): Promise<{ sent: number; failed: number }> {
  const { data: tokens } = await supabase
    .from('fcm_tokens')
    .select('token')
    .eq('tenant_id', tenantId);

  if (!tokens || tokens.length === 0) {
    return { sent: 0, failed: 0 };
  }

  let sent = 0;
  let failed = 0;

  await Promise.all(
    tokens.map(async (t: { token: string }) => {
      const ok = await sendFcmNotification(env, { ...payload, token: t.token });
      if (ok) sent++; else failed++;
    })
  );

  console.log(`[FCM] Tenant ${tenantId}: ${sent} envoyés, ${failed} échecs`);
  return { sent, failed };
}
```

---

### 2.5 — Déclenchement FCM à la création de commande (OBLIGATOIRE)

**Fichier concerné :** `monmenu-web/src/routes/api-dashboard.ts` ou le webhook Supabase qui traite les commandes

**Pourquoi pas côté mobile :** Le déclenchement vient du serveur (commande créée par le client web/app client).

**À ajouter** dans la fonction/route qui traite la création de commande (ou dans le webhook Supabase) :

```typescript
import { sendFcmToTenant } from '../lib/fcm';

// Après création de la commande en base :
async function notifyNouvelleCommande(env: Env, supabase: any, commande: any) {
  const numero = commande.numero_commande ?? '';
  const client = commande.client_nom ?? 'Client';
  const montant = Math.round(commande.montant_total ?? 0);

  await sendFcmToTenant(env, supabase, commande.tenant_id, {
    title: numero ? `🛒 Commande #${numero}` : '🛒 Nouvelle commande !',
    body: `${client} — ${montant} FCFA`,
    data: {
      type: 'commande',
      commandeId: commande.id ?? '',
      numero: numero,
      client: client,
      montant: String(montant),
    },
    channelId: 'commandes_channel',
  });
}
```

---

### 2.6 — Déclenchement FCM pour les changements de statut paiement (OBLIGATOIRE)

**Fichier concerné :** Route ou webhook qui met à jour le statut tenant (actif/rejete/en_attente_confirmation)

**À ajouter** après la mise à jour du statut :

```typescript
// Map statut → payload FCM
const STATUT_FCM_MAP: Record<string, { title: string; body: string }> = {
  actif: {
    title: '✅ Paiement confirmé !',
    body: 'Votre abonnement MonMenu est maintenant actif.',
  },
  rejete: {
    title: '❌ Preuve de paiement rejetée',
    body: 'Votre preuve de paiement a été rejetée. Veuillez soumettre une nouvelle preuve.',
  },
  en_attente_confirmation: {
    title: '⏳ Preuve reçue',
    body: 'Votre preuve de paiement a été reçue. Confirmation sous 48h.',
  },
};

async function notifyStatutPaiement(env: Env, supabase: any, tenantId: string, statut: string) {
  const notifPayload = STATUT_FCM_MAP[statut];
  if (!notifPayload) return;

  await sendFcmToTenant(env, supabase, tenantId, {
    ...notifPayload,
    data: {
      type: 'paiement',
      statut: statut,
    },
    channelId: 'payment_channel',
  });
}
```

---

### 2.7 — Déclenchement FCM pour changements de statut commande (OPTIONNEL)

**Fichier concerné :** Route `PATCH /dashboard/commandes/:id/statut` dans `api-dashboard.ts`

**À ajouter** après la mise à jour du statut de commande :

```typescript
const COMMANDE_STATUT_FCM: Record<string, { title: string; body: (num?: string) => string }> = {
  acceptee: {
    title: '✅ Commande acceptée',
    body: (num) => `La commande${num ? ` #${num}` : ''} a été acceptée.`,
  },
  en_preparation: {
    title: '👨‍🍳 En préparation',
    body: (num) => `La commande${num ? ` #${num}` : ''} est en cours de préparation.`,
  },
  prete: {
    title: '✅ Commande prête',
    body: (num) => `La commande${num ? ` #${num}` : ''} est prête.`,
  },
  livree: {
    title: '🚚 Commande livrée',
    body: (num) => `La commande${num ? ` #${num}` : ''} a été livrée.`,
  },
};

// À appeler si des notifications aux clients sont souhaitées (usage interne).
// Note : ces notifications iraient au RESTAURATEUR dans l'app mobile.
// Si les notifications doivent aller au CLIENT (application cliente), 
// cela nécessite un système FCM distinct pour l'app cliente.
```

---

## SECTION 3 — VARIABLES D'ENVIRONNEMENT CLOUDFLARE À CONFIGURER

**URL Cloudflare Dashboard :** https://dash.cloudflare.com → Workers → monmenu → Settings → Variables & Secrets

| Variable | Type | Valeur source |
|----------|------|---------------|
| `FCM_PROJECT_ID` | Text | `monmenumanager` (google-services.json → project_id) |
| `FCM_CLIENT_EMAIL` | **Secret** | JSON compte de service Firebase → `client_email` |
| `FCM_PRIVATE_KEY` | **Secret** | JSON compte de service Firebase → `private_key` (avec `\n`) |

**Où obtenir le JSON du compte de service Firebase :**
1. Firebase Console → ⚙️ → Project settings → Service accounts
2. Sélectionner "Python" (ou n'importe quel SDK)
3. "Generate new private key" → télécharger le JSON
4. Copier `client_email` et `private_key` dans Cloudflare

---

## SECTION 4 — MIGRATION SQL SUPABASE FCMTOKENS

**À exécuter dans :** Supabase Dashboard → https://app.supabase.com → projet monmenumanager → SQL Editor

Voir le SQL complet dans la **Section 2.1** ci-dessus.

**Vérification après exécution :**
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name = 'fcm_tokens';
-- Doit retourner : fcm_tokens
```

---

## SECTION 5 — RAPPORT DE VÉRIFICATION — TRIPLE PASSE

### Fichier 1 : `android/app/google-services.json`
- **Passe 1 (cohérence)** ✅ — `package_name` = `com.monmenumanager.manage` = `applicationId` dans build.gradle.kts
- **Passe 2 (complétude)** ✅ — Placé exactement à `android/app/google-services.json`
- **Passe 3 (non-régression)** ✅ — Fichier nouveau, aucun impact sur l'existant

### Fichier 2 : `pubspec.yaml`
- **Passe 1 (cohérence)** ✅ — Versions lockées compatibles Flutter 3.35.4 (firebase_core 3.6.0, firebase_messaging 15.1.3)
- **Passe 2 (complétude)** ✅ — flutter pub get réussi, 7 nouvelles dépendances résolues
- **Passe 3 (non-régression)** ✅ — Toutes dépendances existantes conservées

### Fichier 3 : `android/app/build.gradle.kts`
- **Passe 1 (cohérence)** ✅ — Plugin `com.google.gms.google-services` ajouté en 4ème position dans le bloc plugins
- **Passe 2 (complétude)** ✅ — Plugin déclaré, version gérée dans settings.gradle.kts
- **Passe 3 (non-régression)** ✅ — Plugins existants (com.android.application, kotlin-android, flutter-gradle-plugin) inchangés

### Fichier 4 : `android/settings.gradle.kts`
- **Passe 1 (cohérence)** ✅ — Syntaxe Kotlin DSL, `apply false` conforme (plugin déclaré au niveau projet, appliqué au module)
- **Passe 2 (complétude)** ✅ — Version 4.4.2 spécifiée, conforme au guide
- **Passe 3 (non-régression)** ✅ — 3 plugins existants inchangés, repository google() déjà présent dans pluginManagement

### Fichier 5 : `android/app/src/main/AndroidManifest.xml`
- **Passe 1 (cohérence)** ✅ — Service FCM ajouté après les receivers flutter_local_notifications existants
- **Passe 2 (complétude)** ✅ — Service FirebaseMessagingService, 3 meta-data (icon, color, channel_id)
- **Passe 3 (non-régression)** ✅ — Permissions existantes inchangées, receivers flutter_local_notifications inchangés

### Fichier 6 : `android/app/src/main/res/values/colors.xml`
- **Passe 1 (cohérence)** ✅ — Format XML Android standard, couleur #DC2626 = AppConfig.primaryColorHex
- **Passe 2 (complétude)** ✅ — `notification_color` référencé par `@color/notification_color` dans AndroidManifest
- **Passe 3 (non-régression)** ✅ — Fichier nouveau, n'écrase pas styles.xml existant

### Fichier 7 : `lib/config/app_config.dart`
- **Passe 1 (cohérence)** ✅ — Constantes ajoutées dans la section existante, conventions camelCase respectées
- **Passe 2 (complétude)** ✅ — `fcmTokenEndpoint`, `fcmChannelCommandes`, `fcmChannelPaiement`, `firebaseProjectId`
- **Passe 3 (non-régression)** ✅ — 49 lignes existantes inchangées

### Fichier 8 : `lib/services/fcm_service.dart`
- **Passe 1 (cohérence)** ✅ — Conventions nommage identiques aux autres services (camelCase, [FCM] préfixe logs)
- **Passe 2 (complétude)** ✅ — Handler background top-level, classe FCMService complète, 3 callbacks, dédoublonnage
- **Passe 3 (non-régression)** ✅ — Nouveau fichier, dart analyze : 0 issue

### Fichier 9 : `lib/services/api_service.dart`
- **Passe 1 (cohérence)** ✅ — Méthodes ajoutées dans la section existante "Notifications restaurant", style doc identique
- **Passe 2 (complétude)** ✅ — `saveFcmToken()` POST + `deleteFcmToken()` DELETE
- **Passe 3 (non-régression)** ✅ — 456 lignes existantes inchangées, dart analyze : 0 issue

### Fichier 10 : `lib/main.dart`
- **Passe 1 (cohérence)** ✅ — Firebase.initializeApp() avant Supabase.initialize(), FCMService dans MultiProvider
- **Passe 2 (complétude)** ✅ — `_initFCM()` avec 3 callbacks, `logoutWithFCMCleanup()`, navigation GoRouter par type
- **Passe 3 (non-régression)** ✅ — 270 lignes existantes reproduites exactement + ajouts uniquement, dart analyze : 0 issue

---

## SECTION 6 — SCÉNARIOS DE COMPORTEMENT APRÈS INTÉGRATION

| Scénario | Mécanisme | Résultat attendu |
|----------|-----------|-----------------|
| App **ouverte** | Supabase Realtime → NotificationService → InAppBanner | Bannière animée en haut de l'écran |
| App **ouverte** + FCM reçu | FCM foreground ignoré (`alert:false`) | **Pas de doublon** — seule la bannière Realtime s'affiche |
| App **arrière-plan** | FCM → Android système | Notification dans le tiroir Android |
| App **fermée** | FCM → background isolate → notification locale | Notification dans le tiroir Android |
| Tap sur notification | `onAppOpenedFromNotif` → GoRouter.push | Navigation vers commande ou plans |
| **Déconnexion** | `logoutWithFCMCleanup()` → DELETE /fcm-token → deleteToken() | Token supprimé, pas de push orphelin |
| Token rafraîchi | `onTokenRefresh` → `saveFcmToken()` | Backend mis à jour automatiquement |

---

## SECTION 7 — BUILD ET PUSH

- **flutter analyze** : 4 issues préexistantes uniquement (0 nouveau)
- **flutter build apk --release** : ✅ SUCCÈS — 61.1 MB
- **Signé avec** : `android/release-key.jks`, alias `monmenu`, RSA 2048
- **Package** : `com.monmenumanager.manage`
- **Commits** : 2 commits atomiques (voir git log)
- **Push** : `origin/main` — `https://github.com/poodasamuelpro/monmenu-mobile`

---

*Document généré par l'agent Flutter/backend — 2026-08-10*
*Périmètre strict : dépôt mobile monmenu-mobile uniquement*
