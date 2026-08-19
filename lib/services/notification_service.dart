// lib/services/notification_service.dart
// Notifications in-app + locales avec son pour commandes et paiements
// FIX: initialisé au démarrage dans main.dart, canal commandes + canal paiement
//
// M7 — NOTE ARCHITECTURE : ce service écoute les mêmes tables (commandes,
// tenants) que realtime_service.dart mais via des channels distincts
// (`notif_tenant_$id`, `notif_commandes_$id`) et pour un usage disjoint :
// notifications locales uniquement, jamais de mutation des providers.
// Voir le commentaire détaillé en tête de realtime_service.dart —
// redondance assumée, ne pas fusionner sans revoir les cycles de vie.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef TenantStatusCallback = void Function(
    String newStatut, Map<String, dynamic> payload);
typedef NouvelleCommandeCallback = void Function(
    String commandeId, String nomClient, double montant);

class NotificationService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final FlutterLocalNotificationsPlugin _localNotifications;

  RealtimeChannel? _tenantChannel;
  RealtimeChannel? _commandesChannel;
  String? _currentTenantId;
  bool _isSubscribed = false;

  TenantStatusCallback? onTenantStatusChange;
  NouvelleCommandeCallback? onNouvelleCommande;

  String? _lastStatut;

  // In-app notification overlay callback
  Function(String title, String body, {bool isCommande})? onShowInAppBanner;

  NotificationService({
    SupabaseClient? supabase,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  bool get isSubscribed => _isSubscribed;
  String? get lastStatut => _lastStatut;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    await _initLocalNotifications();
  }

  Future<void> _initLocalNotifications() async {
    // Canal commandes — haute priorité + son
    const androidCommandes = AndroidNotificationChannel(
      'commandes_channel',
      'Nouvelles commandes',
      description: 'Notifications pour les nouvelles commandes reçues',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    // Canal paiement — haute priorité + son
    const androidPaiement = AndroidNotificationChannel(
      'payment_channel',
      'Paiement MonMenu',
      description: 'Notifications de statut de paiement',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(androidCommandes);
    await androidPlugin?.createNotificationChannel(androidPaiement);

    // Demander permission Android 13+
    await androidPlugin?.requestNotificationsPermission();

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

    if (kDebugMode) debugPrint('[NotificationService] Initialisé');
  }

  void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint(
          '[NotificationService] Notification tappée: ${response.payload}');
    }
  }

  // ── Abonnement Realtime ───────────────────────────────────────────────────

  void subscribe(String tenantId) {
    if (_currentTenantId == tenantId && _isSubscribed) return;
    _currentTenantId = tenantId;

    _unsubscribeAll();
    _subscribeTenantStatus(tenantId);
    _subscribeCommandes(tenantId);

    if (kDebugMode) debugPrint('[NotificationService] Abonné pour $tenantId');
  }

  void _subscribeTenantStatus(String tenantId) {
    _tenantChannel?.unsubscribe();

    _tenantChannel = _supabase
        .channel('notif_tenant_$tenantId')
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
                    '[NotificationService] Statut: $_lastStatut → $newStatut');
              }
              _lastStatut = newStatut;
              onTenantStatusChange?.call(newStatut, newRecord);
              _sendPaiementNotification(newStatut);
              notifyListeners();
            }
          },
        )
        .subscribe((status, error) {
          _isSubscribed = status == RealtimeSubscribeStatus.subscribed;
          if (error != null && kDebugMode) {
            debugPrint('[NotificationService] Tenant error: $error');
          }
        });
  }

  void _subscribeCommandes(String tenantId) {
    _commandesChannel?.unsubscribe();

    _commandesChannel = _supabase
        .channel('notif_commandes_$tenantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'commandes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tenant_id',
            value: tenantId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final commandeId = record['id'] as String? ?? '';
            // FIX Phase-E: La colonne Supabase s'appelle 'client_nom' (pas 'nom_client')
            // Les payloads Realtime reflètent le vrai nom de colonne DB, pas les alias API
            final nomClient =
                record['client_nom'] as String? ?? 'Client inconnu';
            final montant =
                (record['montant_total'] as num?)?.toDouble() ?? 0.0;
            final numero = record['numero_commande'] as String?;

            onNouvelleCommande?.call(commandeId, nomClient, montant);

            // Notification locale avec son
            _sendCommandeNotification(
              commandeId: commandeId,
              nomClient: nomClient,
              montant: montant,
              numero: numero,
            );

            // In-app banner
            onShowInAppBanner?.call(
              '🛒 Nouvelle commande !',
              '$nomClient — ${_formatMontant(montant)}',
              isCommande: true,
            );

            notifyListeners();
          },
        )
        .subscribe((status, error) {
          if (error != null && kDebugMode) {
            debugPrint('[NotificationService] Commandes error: $error');
          }
        });
  }

  // ── Envoi notifications locales ───────────────────────────────────────────

  Future<void> _sendCommandeNotification({
    required String commandeId,
    required String nomClient,
    required double montant,
    String? numero,
  }) async {
    final titre = numero != null
        ? '🛒 Commande #$numero'
        : '🛒 Nouvelle commande !';
    final corps = '$nomClient — ${_formatMontant(montant)}';

    const androidDetails = AndroidNotificationDetails(
      'commandes_channel',
      'Nouvelles commandes',
      channelDescription: 'Notifications pour les nouvelles commandes reçues',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      icon: '@mipmap/ic_launcher',
      // Son par défaut du système (le plus fort)
      sound: RawResourceAndroidNotificationSound('notification'),
      category: AndroidNotificationCategory.message,
      fullScreenIntent: true,
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
      commandeId.hashCode % 9999,
      titre,
      corps,
      details,
      payload: 'commande:$commandeId',
    );
  }

  Future<void> _sendPaiementNotification(String statut) async {
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
            'Votre preuve de paiement a été rejetée. Veuillez en soumettre une nouvelle.';
        break;
      case 'en_attente_confirmation':
        title = '⏳ Preuve reçue';
        body = 'Votre preuve de paiement a été reçue. Confirmation sous 48h.';
        break;
      default:
        return;
    }

    // In-app banner
    onShowInAppBanner?.call(title, body);

    const androidDetails = AndroidNotificationDetails(
      'payment_channel',
      'Paiement MonMenu',
      channelDescription: 'Notifications de statut de paiement',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
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
      case 'actif':
        return 1001;
      case 'rejete':
        return 1002;
      case 'en_attente_confirmation':
        return 1003;
      default:
        return 1000;
    }
  }

  String _formatMontant(double montant) {
    return '${montant.toStringAsFixed(0)} FCFA';
  }

  // ── Désabonnement ─────────────────────────────────────────────────────────

  void _unsubscribeAll() {
    _tenantChannel?.unsubscribe();
    _commandesChannel?.unsubscribe();
    _tenantChannel = null;
    _commandesChannel = null;
    _isSubscribed = false;
  }

  void unsubscribe() {
    _unsubscribeAll();
    _currentTenantId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}
