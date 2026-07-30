// lib/services/realtime_service.dart
// Supabase Realtime — abonnement aux nouvelles commandes + statut tenant
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/commande_model.dart';

class RealtimeService extends ChangeNotifier {
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;
  RealtimeChannel? _tenantChannel;
  String? _tenantId;
  bool _isConnected = false;

  final List<CommandeModel> _nouvellesCommandes = [];

  RealtimeService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  bool get isConnected => _isConnected;
  List<CommandeModel> get nouvellesCommandes => List.unmodifiable(_nouvellesCommandes);

  Function(CommandeModel)? onNouvelleCommande;
  Function(String commandeId, String newStatut)? onStatutChange;

  /// Callback déclenché quand le statut du tenant change (ex: actif après confirmation).
  Function(String newStatut, Map<String, dynamic> payload)? onTenantStatusChange;

  // ── Abonner aux commandes du tenant ────────────────────────────────────────
  void subscribe(String tenantId) {
    if (_tenantId == tenantId && _isConnected) return;
    _tenantId = tenantId;

    _channel?.unsubscribe();
    _channel = _supabase
        .channel('commandes_realtime_$tenantId')
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
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              final commande = CommandeModel.fromJson(newRecord);
              _nouvellesCommandes.insert(0, commande);
              onNouvelleCommande?.call(commande);
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'commandes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tenant_id',
            value: tenantId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final id = newRecord['id'] as String?;
            final statut = newRecord['statut'] as String?;
            if (id != null && statut != null) {
              onStatutChange?.call(id, statut);
              notifyListeners();
            }
          },
        )
        .subscribe((status, error) {
          _isConnected = status == RealtimeSubscribeStatus.subscribed;
          if (error != null) {
            if (kDebugMode) debugPrint('[Realtime] Error: $error');
          }
          notifyListeners();
        });
  }

  // ── Abonner aux changements de statut du tenant ────────────────────────────
  /// S'abonne aux mises à jour du tenant pour détecter un changement de statut
  /// d'abonnement (en_attente_confirmation → actif / rejete).
  void subscribeTenantStatus(String tenantId) {
    _tenantChannel?.unsubscribe();

    _tenantChannel = _supabase
        .channel('tenant_statut_$tenantId')
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
            if (newStatut != null) {
              if (kDebugMode) {
                debugPrint('[Realtime] Tenant statut changé: $newStatut');
              }
              onTenantStatusChange?.call(newStatut, newRecord);
              notifyListeners();
            }
          },
        )
        .subscribe((status, error) {
          if (error != null && kDebugMode) {
            debugPrint('[Realtime] Tenant channel error: $error');
          }
        });
  }

  /// Désabonne uniquement le canal tenant status.
  void unsubscribeTenantStatus() {
    _tenantChannel?.unsubscribe();
    _tenantChannel = null;
  }

  // ── Se désabonner ──────────────────────────────────────────────────────────
  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
    _tenantChannel?.unsubscribe();
    _tenantChannel = null;
    _isConnected = false;
    notifyListeners();
  }

  void clearNouvellesCommandes() {
    _nouvellesCommandes.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}

