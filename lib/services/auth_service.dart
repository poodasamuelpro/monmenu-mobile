// lib/services/auth_service.dart
// Auth via Supabase direct + stockage sécurisé flutter_secure_storage
// Bearer Token pour toutes les requêtes API
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/tenant_model.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage;
  final SupabaseClient _supabase;

  String? _accessToken;
  String? _refreshToken;
  TenantModel? _tenant;
  bool _isLoading = false;
  String? _error;

  AuthService({
    FlutterSecureStorage? secureStorage,
    SupabaseClient? supabaseClient,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        ),
        _supabase = supabaseClient ?? Supabase.instance.client;

  // ── Getters ────────────────────────────────────────────────────────────────
  String? get accessToken => _accessToken;
  TenantModel? get tenant => _tenant;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _accessToken != null && _tenant != null;

  // ── Init: charger session depuis le stockage sécurisé ─────────────────────
  Future<bool> tryRestoreSession() async {
    try {
      _setLoading(true);
      final token = await _secureStorage.read(key: AppConfig.keyAccessToken);
      final refreshToken = await _secureStorage.read(key: AppConfig.keyRefreshToken);
      final tenantJson = await _secureStorage.read(key: AppConfig.keyTenantData);

      if (token == null || token.length < AppConfig.tokenMinLength) {
        return false;
      }

      // Restaurer session Supabase
      if (refreshToken != null) {
        try {
          final resp = await _supabase.auth.setSession(token);
          if (resp.session == null && refreshToken.isNotEmpty) {
            final refreshed = await _supabase.auth.refreshSession();
            if (refreshed.session != null) {
              _accessToken = refreshed.session!.accessToken;
              _refreshToken = refreshed.session!.refreshToken;
              await _saveTokens(_accessToken!, _refreshToken!);
            } else {
              return false;
            }
          } else if (resp.session != null) {
            _accessToken = resp.session!.accessToken;
            _refreshToken = resp.session!.refreshToken;
          }
        } catch (_) {
          return false;
        }
      } else {
        _accessToken = token;
      }

      if (tenantJson != null) {
        _tenant = TenantModel.fromJsonString(tenantJson);
      }

      notifyListeners();
      return isAuthenticated;
    } catch (e) {
      debugPrint('[AuthService] tryRestoreSession error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<AuthResult> login(String email, String password) async {
    _setLoading(true);
    _error = null;

    try {
      // Connexion directe via Supabase Auth
      final resp = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (resp.session == null || resp.user == null) {
        return AuthResult.failure('Identifiants incorrects.');
      }

      _accessToken = resp.session!.accessToken;
      _refreshToken = resp.session!.refreshToken;

      // Récupérer les infos du tenant
      final tenantResult = await _fetchTenantForUser(resp.user!.id);
      if (!tenantResult.success) {
        await _supabase.auth.signOut();
        return AuthResult.failure(tenantResult.message ?? 'Aucun restaurant associé.');
      }

      await _saveTokens(_accessToken!, _refreshToken!);
      await _saveTenant(_tenant!);

      notifyListeners();
      return AuthResult.success();
    } on AuthException catch (e) {
      final msg = _mapAuthError(e.message);
      _error = msg;
      return AuthResult.failure(msg);
    } catch (e) {
      const msg = 'Erreur de connexion. Vérifiez votre connexion internet.';
      _error = msg;
      return AuthResult.failure(msg);
    } finally {
      _setLoading(false);
    }
  }

  // ── Fetch tenant pour l'utilisateur connecté ──────────────────────────────
  Future<AuthResult> _fetchTenantForUser(String userId) async {
    try {
      final data = await _supabase
          .from('utilisateurs_tenant')
          .select('tenant_id, tenants!inner(id, nom, slug, statut, plan_id, couleur_primaire, couleur_secondaire, logo_url, whatsapp_number, domaine_perso, essai_expire_le, metadata)')
          .eq('auth_user_id', userId)
          .isFilter('tenants.deleted_at', null)
          .neq('tenants.statut', 'suspendu')
          .limit(1)
          .single();

      final tenantMap = data['tenants'] as Map<String, dynamic>?;
      if (tenantMap == null) {
        return AuthResult.failure('Aucun restaurant associé à ce compte.');
      }

      final statut = tenantMap['statut'] as String? ?? 'essai';
      if (statut == 'suspendu') {
        return AuthResult.failure('Votre compte est suspendu. Contactez le support.');
      }

      _tenant = TenantModel.fromJson(tenantMap);
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('Impossible de charger les informations du restaurant.');
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _supabase.auth.signOut();
    } catch (_) {}

    await _clearStorage();
    _accessToken = null;
    _refreshToken = null;
    _tenant = null;
    notifyListeners();
    _setLoading(false);
  }

  // ── Mot de passe oublié — Étape 1 : envoyer OTP email ─────────────────────
  Future<AuthResult> sendPasswordResetOtp(String email) async {
    _setLoading(true);
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: null, // Mobile: OTP uniquement, pas de lien
      );
      return AuthResult.success(message: 'Code envoyé à $email');
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (_) {
      return AuthResult.failure('Erreur lors de l\'envoi du code. Réessayez.');
    } finally {
      _setLoading(false);
    }
  }

  // ── Reset password avec token OTP ─────────────────────────────────────────
  Future<AuthResult> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      if (newPassword.length < 8) {
        return AuthResult.failure('Le mot de passe doit contenir au moins 8 caractères.');
      }

      // Vérifier OTP et créer session
      final resp = await _supabase.auth.verifyOTP(
        email: email.trim(),
        token: otp.trim(),
        type: OtpType.recovery,
      );

      if (resp.session == null) {
        return AuthResult.failure('Code invalide ou expiré.');
      }

      // Mettre à jour le mot de passe
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));

      return AuthResult.success(message: 'Mot de passe mis à jour avec succès.');
    } on AuthException catch (e) {
      if (e.message.contains('otp')) {
        return AuthResult.failure('Code OTP invalide ou expiré.');
      }
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('Erreur lors de la réinitialisation.');
    } finally {
      _setLoading(false);
    }
  }

  // ── Changer mot de passe (utilisateur connecté) ───────────────────────────
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      if (newPassword.length < 8) {
        return AuthResult.failure('Nouveau mot de passe: 8 caractères minimum.');
      }

      final email = _supabase.auth.currentUser?.email;
      if (email == null) return AuthResult.failure('Session expirée. Reconnectez-vous.');

      // Vérifier mot de passe actuel
      final verify = await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      if (verify.session == null) {
        return AuthResult.failure('Mot de passe actuel incorrect.');
      }

      // Mettre à jour
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      return AuthResult.success(message: 'Mot de passe modifié avec succès.');
    } on AuthException catch (e) {
      return AuthResult.failure(_mapAuthError(e.message));
    } catch (_) {
      return AuthResult.failure('Erreur lors du changement de mot de passe.');
    } finally {
      _setLoading(false);
    }
  }

  // ── Refresh token ──────────────────────────────────────────────────────────
  Future<bool> refreshToken() async {
    try {
      final resp = await _supabase.auth.refreshSession();
      if (resp.session != null) {
        _accessToken = resp.session!.accessToken;
        _refreshToken = resp.session!.refreshToken;
        await _saveTokens(_accessToken!, _refreshToken!);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Storage helpers ────────────────────────────────────────────────────────
  Future<void> _saveTokens(String access, String refresh) async {
    await _secureStorage.write(key: AppConfig.keyAccessToken, value: access);
    await _secureStorage.write(key: AppConfig.keyRefreshToken, value: refresh);
  }

  Future<void> _saveTenant(TenantModel t) async {
    await _secureStorage.write(
      key: AppConfig.keyTenantData,
      value: t.toJsonString(),
    );
  }

  Future<void> _clearStorage() async {
    await _secureStorage.delete(key: AppConfig.keyAccessToken);
    await _secureStorage.delete(key: AppConfig.keyRefreshToken);
    await _secureStorage.delete(key: AppConfig.keyTenantData);
    await _secureStorage.delete(key: AppConfig.keyUserEmail);
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  // ── Mapping erreurs Supabase → messages FR ────────────────────────────────
  String _mapAuthError(String msg) {
    if (msg.contains('Invalid login credentials') || msg.contains('invalid_credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Email non confirmé. Vérifiez votre boîte mail.';
    }
    if (msg.contains('Too many requests') || msg.contains('rate limit')) {
      return 'Trop de tentatives. Attendez quelques minutes.';
    }
    if (msg.contains('User already registered')) {
      return 'Cet email est déjà utilisé.';
    }
    if (msg.contains('Password should be')) {
      return 'Mot de passe trop court (8 caractères minimum).';
    }
    if (msg.contains('Token has expired') || msg.contains('expired')) {
      return 'Session expirée. Reconnectez-vous.';
    }
    return msg;
  }

  void updateTenant(TenantModel updated) {
    _tenant = updated;
    _saveTenant(updated);
    notifyListeners();
  }
}

// Résultat d'une opération d'auth
class AuthResult {
  final bool success;
  final String? message;

  const AuthResult._({required this.success, this.message});

  factory AuthResult.success({String? message}) =>
      AuthResult._(success: true, message: message);

  factory AuthResult.failure(String message) =>
      AuthResult._(success: false, message: message);
}
