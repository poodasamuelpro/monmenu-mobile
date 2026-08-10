// lib/services/fcm_service.dart
// Firebase Cloud Messaging — Push notifications app fermée / arrière-plan
//
// ARCHITECTURE DÉDOUBLONNAGE FOREGROUND :
//   - App OUVERTE   : Supabase Realtime déclenche la bannière in-app (NotificationService)
//                     FCM foreground reçu → ignoré silencieusement (pas de doublon)
//   - App ARRIÈRE-PLAN : FCM → notification système Android
//   - App FERMÉE    : FCM → notification système Android via background isolate
//   - OUVERTURE via notif : navigation vers la commande concernée
//
// SÉCURITÉ : le token FCM n'est jamais loggé en clair en production.
// PROJET FIREBASE : monmenumanager (project_id du google-services.json fourni par Samuel)
//
import 'dart:ui' show Color;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HANDLER BACKGROUND — OBLIGATOIREMENT TOP-LEVEL (hors de toute classe)
// Appelé par Firebase dans un isolate séparé quand l'app est en arrière-plan
// ou fermée. Firebase exige que cette fonction soit annotée @pragma('vm:entry-point')
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase doit être ré-initialisé dans l'isolate background
  await Firebase.initializeApp();

  if (kDebugMode) {
    debugPrint('[FCM Background] Message reçu: ${message.messageId}');
    debugPrint('[FCM Background] Titre: ${message.notification?.title}');
    debugPrint('[FCM Background] Type: ${message.data['type']}');
  }

  // Afficher une notification locale depuis le background isolate
  final localNotif = FlutterLocalNotificationsPlugin();
  await _initPluginForBackground(localNotif);
  await _showLocalNotificationFromFcm(localNotif, message);
}

/// Initialiser flutter_local_notifications dans le background isolate
Future<void> _initPluginForBackground(
    FlutterLocalNotificationsPlugin plugin) async {
  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: androidSettings);
  await plugin.initialize(settings);

  // Recréer les canaux dans l'isolate background
  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'commandes_channel',
      'Nouvelles commandes',
      description: 'Notifications pour les nouvelles commandes reçues',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    ),
  );

  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'payment_channel',
      'Paiement MonMenu',
      description: 'Notifications de statut de paiement',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ),
  );
}

/// Afficher une notification locale à partir d'un message FCM
Future<void> _showLocalNotificationFromFcm(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message,
) async {
  final notification = message.notification;

  // Si FCM envoie une notification display (titre/corps présents) →
  // Android l'affiche automatiquement en background. Ne pas doubler.
  // Si c'est un data-only message → on crée la notif locale nous-mêmes.
  if (notification == null) {
    // Message data-only : construire depuis message.data
    final type = message.data['type'] as String? ?? 'info';
    final title = message.data['titre'] as String? ?? _defaultTitle(type);
    final body = message.data['message'] as String? ?? '';
    final commandeId = message.data['commandeId'] as String?;
    final channelId = _channelForType(type);

    await plugin.show(
      message.hashCode % 9999,
      title,
      body,
      _buildNotificationDetails(channelId),
      payload: commandeId != null ? 'commande:$commandeId' : type,
    );
  }
  // Si notification non-null : Android gère l'affichage automatiquement.
}

String _defaultTitle(String type) {
  switch (type) {
    case 'commande':
      return '🛒 Nouvelle commande !';
    case 'paiement':
      return '💳 Notification paiement';
    default:
      return 'MonMenu';
  }
}

String _channelForType(String type) {
  switch (type) {
    case 'commande':
    case 'commande_acceptee':
    case 'commande_preparation':
    case 'commande_prete':
    case 'commande_livree':
    case 'commande_rappel':
      return 'commandes_channel';
    case 'paiement':
    case 'paiement_confirme':
    case 'paiement_rejete':
    case 'paiement_recu':
      return 'payment_channel';
    default:
      return 'payment_channel';
  }
}

NotificationDetails _buildNotificationDetails(String channelId) {
  final isCommande = channelId == 'commandes_channel';
  return NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      isCommande ? 'Nouvelles commandes' : 'Paiement MonMenu',
      channelDescription: isCommande
          ? 'Notifications pour les nouvelles commandes reçues'
          : 'Notifications de statut de paiement',
      importance: isCommande ? Importance.max : Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: isCommande,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFDC2626), // Rouge MonMenu
      category: isCommande
          ? AndroidNotificationCategory.message
          : AndroidNotificationCategory.status,
      fullScreenIntent: isCommande,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CLASSE FCMService
// ─────────────────────────────────────────────────────────────────────────────

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _fcmToken;

  /// Token FCM du device courant. Null si non initialisé ou permission refusée.
  String? get fcmToken => _fcmToken;

  /// Indicateur : FCM est-il actif (permission accordée et token obtenu) ?
  bool get isActive => _fcmToken != null;

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Initialiser FCM.
  ///
  /// [onTokenReceived]      — appelé quand un token FCM est obtenu ou rafraîchi.
  ///                          Responsabilité : l'envoyer au backend via ApiService.saveFcmToken().
  /// [onForegroundMessage]  — appelé quand un message FCM arrive app OUVERTE.
  ///                          DÉDOUBLONNAGE : en foreground, Realtime Supabase gère déjà
  ///                          la bannière in-app. Ce callback n'affiche PAS de notification locale.
  /// [onAppOpenedFromNotif] — appelé quand l'app est ouverte depuis une notification.
  ///                          Responsabilité : naviguer vers la bonne page.
  Future<void> init({
    required Future<void> Function(String token) onTokenReceived,
    required void Function(RemoteMessage message) onForegroundMessage,
    required void Function(RemoteMessage? message) onAppOpenedFromNotif,
  }) async {
    // 1. Enregistrer le handler background EN PREMIER (exigence Firebase)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Demander permission (iOS obligatoire, Android 13+ recommandé)
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      debugPrint(
          '[FCM] Statut permission: ${settings.authorizationStatus.name}');
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      if (kDebugMode) {
        debugPrint(
            '[FCM] ⚠️ Permission refusée — notifications push désactivées');
      }
      return;
    }

    // 3. Configurer présentation foreground (iOS : afficher même app ouverte)
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: false, // DÉDOUBLONNAGE : Realtime gère le foreground
      badge: true,
      sound: false, // DÉDOUBLONNAGE : pas de son FCM si app ouverte
    );

    // 4. Récupérer le token et l'envoyer au backend
    await _fetchAndSendToken(onTokenReceived);

    // 5. Écouter les rafraîchissements de token (rotation FCM)
    _messaging.onTokenRefresh.listen((newToken) async {
      _fcmToken = newToken;
      if (kDebugMode) {
        debugPrint('[FCM] Token rafraîchi (${newToken.length} chars)');
      }
      await onTokenReceived(newToken);
    });

    // 6. Messages FOREGROUND (app ouverte)
    // DÉDOUBLONNAGE : Supabase Realtime déclenche déjà la bannière in-app.
    // On appelle le callback mais on N'affiche PAS de notification locale supplémentaire.
    FirebaseMessaging.onMessage.listen((message) {
      if (kDebugMode) {
        debugPrint(
            '[FCM Foreground] Reçu (dédoublonnage Realtime actif): ${message.notification?.title}');
      }
      // Déléguer au main.dart qui décide si afficher ou non selon état Realtime
      onForegroundMessage(message);
    });

    // 7. App ouverte depuis notification (était en ARRIÈRE-PLAN)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (kDebugMode) {
        debugPrint(
            '[FCM] App ouverte depuis notification (arrière-plan): ${message.data}');
      }
      onAppOpenedFromNotif(message);
    });

    // 8. App lancée depuis notification (était FERMÉE)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        debugPrint(
            '[FCM] App lancée depuis notification (fermée): ${initialMessage.data}');
      }
      // Délai pour laisser le router s'initialiser avant de naviguer
      await Future<void>.delayed(const Duration(milliseconds: 500));
      onAppOpenedFromNotif(initialMessage);
    }

    if (kDebugMode) {
      debugPrint('[FCM] Initialisé avec succès');
    }
  }

  // ── Token ──────────────────────────────────────────────────────────────────

  Future<void> _fetchAndSendToken(
      Future<void> Function(String token) onTokenReceived) async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        if (kDebugMode) {
          // Ne jamais logger le token complet en production
          debugPrint('[FCM] Token obtenu (${_fcmToken!.length} chars) ✅');
        }
        await onTokenReceived(_fcmToken!);
      } else {
        if (kDebugMode) {
          debugPrint('[FCM] ⚠️ Token null — device non enregistré');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Erreur récupération token: $e');
      }
    }
  }

  // ── Déconnexion ────────────────────────────────────────────────────────────

  /// Supprimer le token FCM lors de la déconnexion.
  /// À appeler AVANT auth_service.logout() pour garantir l'envoi.
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      if (kDebugMode) {
        debugPrint('[FCM] Token supprimé (déconnexion)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Erreur suppression token: $e');
      }
    } finally {
      _fcmToken = null;
    }
  }

  // ── Abonnement topics (optionnel, pour diffusions globales) ───────────────

  /// S'abonner à un topic FCM (ex: 'alertes_globales')
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) debugPrint('[FCM] Abonné au topic: $topic');
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Erreur abonnement topic $topic: $e');
    }
  }

  /// Se désabonner d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) debugPrint('[FCM] Désabonné du topic: $topic');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Erreur désabonnement topic $topic: $e');
      }
    }
  }
}
