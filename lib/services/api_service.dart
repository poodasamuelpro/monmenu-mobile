// lib/services/api_service.dart
// Client HTTP avec Bearer token, auto-refresh 401, sécurité HTTPS only
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
    } on SocketException {
      return ApiResponse.failure(0, 'Pas de connexion internet.');
    } on HttpException {
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
  Future<ApiResponse> updateCommandeStatut(String id, String statut) async {
    return patch('/dashboard/commandes/$id/statut', {'statut': statut});
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

  /// PATCH /dashboard/pdv/:id
  Future<ApiResponse> updatePdv(String id, Map<String, dynamic> data) async =>
      patch('/dashboard/pdv/$id', data);

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
