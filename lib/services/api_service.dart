// lib/services/api_service.dart
// Client HTTP avec Bearer token, auto-refresh 401, sécurité HTTPS only
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/auth_service.dart';

class ApiService {
  final AuthService _authService;
  final http.Client _client;

  ApiService(this._authService, {http.Client? client})
      : _client = client ?? http.Client();

  // ── Headers communs avec Bearer token ─────────────────────────────────────
  Map<String, String> get _headers {
    final token = _authService.accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.length >= AppConfig.tokenMinLength)
        'Authorization': 'Bearer $token',
    };
  }

  // ── GET ────────────────────────────────────────────────────────────────────
  Future<ApiResponse> get(String endpoint) async {
    return _request(() => _client.get(
      _buildUri(endpoint),
      headers: _headers,
    ));
  }

  // ── POST ───────────────────────────────────────────────────────────────────
  Future<ApiResponse> post(String endpoint, Map<String, dynamic> body) async {
    return _request(() => _client.post(
      _buildUri(endpoint),
      headers: _headers,
      body: jsonEncode(body),
    ));
  }

  // ── PATCH ──────────────────────────────────────────────────────────────────
  Future<ApiResponse> patch(String endpoint, Map<String, dynamic> body) async {
    return _request(() => _client.patch(
      _buildUri(endpoint),
      headers: _headers,
      body: jsonEncode(body),
    ));
  }

  // ── DELETE ─────────────────────────────────────────────────────────────────
  Future<ApiResponse> delete(String endpoint) async {
    return _request(() => _client.delete(
      _buildUri(endpoint),
      headers: _headers,
    ));
  }

  // ── Core request avec retry 401 ────────────────────────────────────────────
  Future<ApiResponse> _request(
    Future<http.Response> Function() fn, {
    bool retry = true,
  }) async {
    try {
      final resp = await fn().timeout(const Duration(seconds: 30));

      if (resp.statusCode == 401 && retry) {
        // Tenter refresh token
        final refreshed = await _authService.refreshToken();
        if (refreshed) {
          return _request(fn, retry: false);
        }
        // Session expirée — déconnexion
        await _authService.logout();
        return ApiResponse.failure(401, 'Session expirée. Reconnectez-vous.');
      }

      return _parseResponse(resp);
    } on SocketException catch (e) {
      debugPrint('[ApiService] SocketException (connexion refusée ou DNS résolu): $e');
      return ApiResponse.failure(0, 'Pas de connexion internet.');
    } on http.ClientException catch (e) {
      // Captures les erreurs réseau HTTP (connexion refusée, timeout réseau, etc.)
      debugPrint('[ApiService] ClientException (réseau): $e');
      return ApiResponse.failure(0, 'Erreur réseau : impossible de joindre le serveur.');
    } on HttpException catch (e) {
      debugPrint('[ApiService] HttpException: $e');
      return ApiResponse.failure(0, 'Erreur réseau.');
    } catch (e) {
      debugPrint('[ApiService] Error: $e');
      return ApiResponse.failure(0, 'Erreur inattendue.');
    }
  }

  ApiResponse _parseResponse(http.Response resp) {
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return ApiResponse.success(resp.statusCode, body);
      }
      final msg = body['error'] as String? ??
          body['message'] as String? ??
          'Erreur ${resp.statusCode}';
      return ApiResponse.failure(resp.statusCode, msg);
    } catch (_) {
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return ApiResponse.success(resp.statusCode, {});
      }
      return ApiResponse.failure(resp.statusCode, 'Erreur ${resp.statusCode}');
    }
  }

  Uri _buildUri(String endpoint) {
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('${AppConfig.apiUrl}$path');
  }

  // ── Dashboard endpoints ────────────────────────────────────────────────────

  /// GET /dashboard/commandes
  Future<ApiResponse> getCommandes({String? statut, int page = 1}) async {
    String ep = '/dashboard/commandes?page=$page&limit=50';
    if (statut != null) ep += '&statut=$statut';
    return get(ep);
  }

  /// PATCH /dashboard/commandes/:id/statut
  /// [livreurId] — si fourni ET statut == 'en_preparation', déclenche la notif WhatsApp livreur
  /// Retourne lien_whatsapp_livreur dans resp.data si livreur notifié
  Future<ApiResponse> updateCommandeStatut(
    String id,
    String statut, {
    String? livreurId,
    String? note,
  }) async {
    final body = <String, dynamic>{'statut': statut};
    if (livreurId != null && livreurId.isNotEmpty) body['livreur_id'] = livreurId;
    if (note != null && note.isNotEmpty) body['note'] = note;
    return patch('/dashboard/commandes/$id/statut', body);
  }

  /// GET /dashboard/stats
  Future<ApiResponse> getStats() async => get('/dashboard/stats');

  /// GET /dashboard/stats-journalieres
  Future<ApiResponse> getStatsJournalieres({int jours = 30}) async =>
      get('/dashboard/stats-journalieres?jours=$jours');

  /// GET /dashboard/menu
  Future<ApiResponse> getMenu() async => get('/dashboard/menu');

  /// GET /dashboard/categories
  Future<ApiResponse> getCategories() async => get('/dashboard/categories');

  /// POST /dashboard/categories
  Future<ApiResponse> createCategorie(Map<String, dynamic> data) async =>
      post('/dashboard/categories', data);

  /// PATCH /dashboard/categories/:id
  Future<ApiResponse> updateCategorie(String id, Map<String, dynamic> data) async =>
      patch('/dashboard/categories/$id', data);

  /// DELETE /dashboard/categories/:id
  Future<ApiResponse> deleteCategorie(String id) async =>
      delete('/dashboard/categories/$id');

  /// POST /dashboard/produits
  Future<ApiResponse> createProduit(Map<String, dynamic> data) async =>
      post('/dashboard/produits', data);

  /// PATCH /dashboard/produits/:id
  Future<ApiResponse> updateProduit(String id, Map<String, dynamic> data) async =>
      patch('/dashboard/produits/$id', data);

  /// DELETE /dashboard/produits/:id
  Future<ApiResponse> deleteProduit(String id) async =>
      delete('/dashboard/produits/$id');

  /// GET /dashboard/livreurs
  Future<ApiResponse> getLivreurs() async => get('/dashboard/livreurs');

  /// GET /dashboard/pdv
  Future<ApiResponse> getPdv() async => get('/dashboard/pdv');

  /// PATCH /dashboard/pdv  (pas de :id — l'API identifie le PDV par le tenant JWT)
  Future<ApiResponse> updatePdv(Map<String, dynamic> data) async =>
      patch('/dashboard/pdv', data);

  /// GET /dashboard/profil
  Future<ApiResponse> getProfil() async => get('/dashboard/profil');

  /// PATCH /dashboard/parametres
  Future<ApiResponse> updateParametres(Map<String, dynamic> data) async =>
      patch('/dashboard/parametres', data);

  /// PATCH /dashboard/apparence
  Future<ApiResponse> updateApparence(Map<String, dynamic> data) async =>
      patch('/dashboard/apparence', data);

  /// GET /dashboard/codes-promo
  Future<ApiResponse> getCodesPromo() async => get('/dashboard/codes-promo');

  /// POST /dashboard/codes-promo
  Future<ApiResponse> createCodePromo(Map<String, dynamic> data) async =>
      post('/dashboard/codes-promo', data);

  /// PATCH /dashboard/codes-promo/:id
  Future<ApiResponse> updateCodePromo(String id, Map<String, dynamic> data) async =>
      patch('/dashboard/codes-promo/$id', data);

  /// DELETE /dashboard/codes-promo/:id
  Future<ApiResponse> deleteCodePromo(String id) async =>
      delete('/dashboard/codes-promo/$id');

  /// POST /dashboard/livreurs
  Future<ApiResponse> createLivreur(Map<String, dynamic> data) async =>
      post('/dashboard/livreurs', data);

  /// PATCH /dashboard/livreurs/:id
  Future<ApiResponse> updateLivreur(String id, Map<String, dynamic> data) async =>
      patch('/dashboard/livreurs/$id', data);

  /// DELETE /dashboard/livreurs/:id
  Future<ApiResponse> deleteLivreur(String id) async =>
      delete('/dashboard/livreurs/$id');

  /// GET /dashboard/qrcode
  Future<ApiResponse> getQrCode() async => get('/dashboard/qrcode');

  /// GET /plans
  Future<ApiResponse> getPlans() async => get('/plans');

  // ── Paiement endpoints ─────────────────────────────────────────────────────

  /// GET /paiement/statut
  /// Retourne : {statut_tenant, abonnement{id, statut, reference_paiement,
  /// soumis_le, delai_confirmation_expire_le, heures_restantes_confirmation,
  /// message_confirmation}, essai_expire_le, jours_essai_restants, reference_active}
  Future<ApiResponse> getAbonnementActif() async =>
      get('/paiement/statut');

  /// GET /paiement/reference
  /// Retourne : {reference, instructions[]}
  Future<ApiResponse> getReferencePaiement() async =>
      get('/paiement/reference');

  /// POST /paiement/soumettre — multipart/form-data
  /// Champs: preuve (File), plan_id, methode_paiement, periodicite, numero_expediteur
  /// Retourne : {success, abonnement_id, reference, delai_confirmation,
  ///             heures_delai: 72, message, plan{nom, montant, devise}}
  ///
  /// SEC-02 : Le token n'est jamais loggé.
  /// SEC-07 : Idempotence — vérifier statut avant renvoi.
  Future<ApiResponse> soumettrePreuvePaiement({
    required String filePath,
    required String planId,
    required String methodePaiement,
    required String periodicite,
    required String numeroExpediteur,
  }) async {
    try {
      final token = _authService.accessToken;
      if (token == null || token.length < AppConfig.tokenMinLength) {
        return ApiResponse.failure(401, 'Token manquant. Reconnectez-vous.');
      }

      final uri = _buildUri('/paiement/soumettre');
      final request = http.MultipartRequest('POST', uri);

      // SEC-02 : Authorization header, jamais loggé
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Champs texte
      request.fields['plan_id'] = planId;
      request.fields['methode_paiement'] = methodePaiement;
      request.fields['periodicite'] = periodicite;
      // Numéro utilisé pour le paiement — obligatoire côté backend (min 8 chiffres)
      request.fields['numero_expediteur'] = numeroExpediteur;

      // Fichier preuve
      final file = File(filePath);
      if (!file.existsSync()) {
        return ApiResponse.failure(0, 'Fichier preuve introuvable.');
      }
      final fileBytes = await file.readAsBytes();
      final fileName = file.path.split('/').last;
      final multipartFile = http.MultipartFile.fromBytes(
        'preuve',
        fileBytes,
        filename: fileName,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send()
          .timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      // SEC-02 : pas de log du token ni du contenu de la réponse en production
      if (kDebugMode) {
        debugPrint('[ApiService] soumettrePreuve status=${response.statusCode}');
      }

      return _parseResponse(response);
    } on SocketException catch (e) {
      debugPrint('[ApiService] soumettrePreuve SocketException: $e');
      return ApiResponse.failure(0, 'Pas de connexion internet.');
    } on TimeoutException {
      return ApiResponse.failure(0, 'Délai d\'upload dépassé. Réessayez.');
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] soumettrePreuve error: $e');
      return ApiResponse.failure(0, 'Erreur lors de l\'upload.');
    }
  }

  // ── Upload image ───────────────────────────────────────────────────────────

  /// POST /dashboard/upload-image — Upload vers R2 (multipart/form-data)
  /// Champ: file (File image — jpeg/png/webp/gif, max 5MB)
  /// Retourne: { success, url, key } — url = URL publique via /dashboard/media/:key
  /// SEC-02: token jamais loggé
  Future<ApiResponse> uploadImage(String filePath) async {
    try {
      final token = _authService.accessToken;
      if (token == null || token.length < AppConfig.tokenMinLength) {
        return ApiResponse.failure(401, 'Token manquant. Reconnectez-vous.');
      }

      final uri = _buildUri('/dashboard/upload-image');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      final file = File(filePath);
      if (!file.existsSync()) {
        return ApiResponse.failure(0, 'Fichier image introuvable.');
      }

      final ext = filePath.split('.').last.toLowerCase();

      final fileBytes = await file.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: 'image.$ext',
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send()
          .timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        debugPrint('[ApiService] uploadImage status=${response.statusCode}');
      }

      return _parseResponse(response);
    } on SocketException {
      return ApiResponse.failure(0, 'Pas de connexion internet.');
    } on TimeoutException {
      return ApiResponse.failure(0, 'Délai d\'upload dépassé. Réessayez.');
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiService] uploadImage error: $e');
      return ApiResponse.failure(0, 'Erreur lors de l\'upload image.');
    }
  }

  // ── Notifications restaurant ───────────────────────────────────────────────

  /// GET /dashboard/notifications/liste?page=&limit=&non_lues=
  /// Retourne: { notifications[], page, limit, total, nb_non_lues, has_more }
  /// Table Supabase: notifications_restaurant (id, tenant_id, type, titre, message, lue, lien, created_at)
  Future<ApiResponse> getNotificationsListe({
    int page = 1,
    int limit = 10,
    bool nonLuesSeulement = false,
  }) async {
    String ep = '/dashboard/notifications/liste?page=$page&limit=$limit';
    if (nonLuesSeulement) ep += '&non_lues=true';
    return get(ep);
  }

  /// PATCH /dashboard/notifications/:id — Marquer comme lue/non lue
  /// Body: { lue: bool }
  Future<ApiResponse> marquerNotificationLue(String id, {bool lue = true}) async {
    return patch('/dashboard/notifications/$id', {'lue': lue});
  }

  /// PATCH /dashboard/notifications/tout-lire — Marquer toutes comme lues
  Future<ApiResponse> marquerToutesLues() async {
    return patch('/dashboard/notifications/tout-lire', {});
  }

  /// GET /paiement/historique?page=&limit=
  /// Retourne : {abonnements[], total, page, limit, total_pages}
  Future<ApiResponse> getHistoriqueAbonnements({
    int page = 1,
    int limit = 10,
  }) async =>
      get('/paiement/historique?page=$page&limit=$limit');

  /// GET /paiement/notifications
  /// Retourne : {notifications[], count, non_lues}
  Future<ApiResponse> getPaiementNotifications() async =>
      get('/paiement/notifications');
}

class ApiResponse {
  final bool success;
  final int statusCode;
  final Map<String, dynamic>? data;
  final String? error;

  const ApiResponse._({
    required this.success,
    required this.statusCode,
    this.data,
    this.error,
  });

  factory ApiResponse.success(int code, Map<String, dynamic> data) =>
      ApiResponse._(success: true, statusCode: code, data: data);

  factory ApiResponse.failure(int code, String error) =>
      ApiResponse._(success: false, statusCode: code, error: error);

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isRateLimited => statusCode == 429;
}
