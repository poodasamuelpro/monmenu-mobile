// lib/services/notification_service.dart
// Option B (Supabase Realtime) — détection de changement de statut tenant
// Architecture prête pour FCM (hors périmètre immédiat)
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Callback déclenché quand le statut du tenant change.
typedef TenantStatusCallback = void Function(
    String newStatut, Map<String, dynamic> payload);

/// Service de notification basé sur Supabase Realtime.
///
/// Écoute les changements sur la table `tenants` pour l'ID du tenant courant.
/// Déclenche une notification locale et notifie les listeners à chaque
/// changement de statut (typiquement : en_attente_confirmation → actif/rejete).
///
/// Architecture FCM-ready : les méthodes `initFcm()` / `_handleFcmMessage()`
/// sont documentées mais non implémentées (hors périmètre v2).
class NotificationService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final FlutterLocalNotificationsPlugin _localNotifications;

  RealtimeChannel? _tenantChannel;
  String? _currentTenantId;
  bool _isSubscribed = false;

  TenantStatusCallback? onTenantStatusChange;

  String? _lastStatut;

  NotificationService({
    SupabaseClient? supabase,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  bool get isSubscribed => _isSubscribed;
  String? get lastStatut => _lastStatut;

  // ── Initialisation notifications locales ──────────────────────────────────

  /// Initialise le plugin de notifications locales.
  Future<void> initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('[NotificationService] Notification tapped: ${response.payload}');
    }
  }

  // ── Supabase Realtime — abonnement statut tenant ──────────────────────────

  /// S'abonne aux changements de la table `tenants` pour [tenantId].
  /// Déclenche [onTenantStatusChange] et une notification locale à chaque
  /// changement de champ `statut`.
  void subscribeTenantStatus(String tenantId) {
    if (_currentTenantId == tenantId && _isSubscribed) return;
    _currentTenantId = tenantId;

    // Désabonner l'ancien canal
    _tenantChannel?.unsubscribe();

    _tenantChannel = _supabase
        .channel('tenant_status_$tenantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'tenants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: tenantId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final newStatut = newRecord['statut'] as String?;

            if (newStatut != null && newStatut != _lastStatut) {
              if (kDebugMode) {
                debugPrint(
                    '[NotificationService] Statut tenant: $_lastStatut → $newStatut');
              }
              _lastStatut = newStatut;
              onTenantStatusChange?.call(newStatut, newRecord);
              _sendLocalNotification(newStatut);
              notifyListeners();
            }
          },
        )
        .subscribe((status, error) {
          _isSubscribed = status == RealtimeSubscribeStatus.subscribed;
          if (error != null && kDebugMode) {
            debugPrint('[NotificationService] Realtime error: $error');
          }
          notifyListeners();
        });
  }

  /// Envoie une notification locale selon le nouveau statut.
  Future<void> _sendLocalNotification(String statut) async {
    String title;
    String body;

    switch (statut) {
      case 'actif':
        title = '✅ Paiement confirmé !';
        body = 'Votre abonnement MonMenu est maintenant actif. Bonne gestion !';
        break;
      case 'rejete':
        title = '❌ Preuve de paiement rejetée';
        body =
            'Votre preuve de paiement a été rejetée. Veuillez soumettre une nouvelle preuve.';
        break;
      case 'en_attente_confirmation':
        title = '⏳ Preuve reçue';
        body =
            'Votre preuve de paiement a été reçue. Confirmation sous 38h.';
        break;
      default:
        return; // Pas de notification pour les autres statuts
    }

    const androidDetails = AndroidNotificationDetails(
      'payment_channel',
      'Paiement MonMenu',
      channelDescription: 'Notifications de statut de paiement',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      _notificationIdForStatut(statut),
      title,
      body,
      details,
      payload: statut,
    );
  }

  int _notificationIdForStatut(String statut) {
    switch (statut) {
      case 'actif': return 1001;
      case 'rejete': return 1002;
      case 'en_attente_confirmation': return 1003;
      default: return 1000;
    }
  }

  // ── Désabonnement ─────────────────────────────────────────────────────────

  void unsubscribe() {
    _tenantChannel?.unsubscribe();
    _tenantChannel = null;
    _isSubscribed = false;
    _currentTenantId = null;
    notifyListeners();
  }

  // ── Architecture FCM-ready (non implémenté dans v2) ───────────────────────
  //
  // Pour implémenter FCM :
  // 1. Ajouter firebase_messaging: ^15.x.x dans pubspec.yaml
  // 2. Configurer google-services.json (Android) et GoogleService-Info.plist (iOS)
  // 3. Implémenter initFcm() :
  //    - FirebaseMessaging.instance.requestPermission()
  //    - FirebaseMessaging.instance.getToken() → envoyer au backend
  //    - FirebaseMessaging.onMessage.listen(_handleFcmMessage)
  //    - FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmMessage)
  // 4. Backend : appel à FCM Admin SDK lors du changement de statut tenant
  //    (déclenché dans le webhook Supabase ou la fonction Cloudflare)
  // IMPORTANT : ne jamais committer les clés FCM en clair dans le code

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}
