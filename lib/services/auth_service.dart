// lib/services/auth_service.dart
// Auth via Supabase direct + stockage sécurisé flutter_secure_storage
// FIX Phase-E: tryRestoreSession() — setSession(refreshToken) correct (supabase_flutter ^2.x)
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
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                  accessibility: KeychainAccessibility.first_unlock),
            ),
        _supabase = supabaseClient ?? Supabase.instance.client;

  // ── Getters ────────────────────────────────────────────────────────────────
  String? get accessToken => _accessToken;
  TenantModel? get tenant => _tenant;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _accessToken != null && _tenant != null;

  // ── Init: restaurer session depuis secure storage ──────────────────────────
  // FIX Phase-E: setSession() dans supabase_flutter ^2.x prend UN seul arg = refreshToken
  // Le refreshToken est chargé depuis le secure storage puis passé à setSession()
  Future<bool> tryRestoreSession() async {
    try {
      _setLoading(true);

      // 1. Vérifier d'abord la session Supabase active (en mémoire)
      final currentSession = _supabase.auth.currentSession;
      if (currentSession != null && !currentSession.isExpired) {
        _accessToken = currentSession.accessToken;
        _refreshToken = currentSession.refreshToken;
        final tenantJson =
            await _secureStorage.read(key: AppConfig.keyTenantData);
        if (tenantJson != null) {
          _tenant = TenantModel.fromJsonString(tenantJson);
        } else {
          final userId = _supabase.auth.currentUser?.id;
          if (userId != null) {
            await _fetchTenantForUser(userId);
          }
        }
        if (isAuthenticated) {
          notifyListeners();
          return true;
        }
      }

      // 2. Charger tokens depuis secure storage
      final accessToken =
          await _secureStorage.read(key: AppConfig.keyAccessToken);
      final refreshToken =
          await _secureStorage.read(key: AppConfig.keyRefreshToken);
      final tenantJson =
          await _secureStorage.read(key: AppConfig.keyTenantData);

      if (accessToken == null ||
          accessToken.length < AppConfig.tokenMinLength) {
        return false;
      }

      // 3. Restaurer session Supabase avec BOTH tokens
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          // FIX RÉEL: setSession() prend UN seul arg = le refreshToken (supabase_flutter ^2.x)
          // L'accessToken n'est PAS le bon arg ici — c'est le refreshToken qui restaure la session
          final resp =
              await _supabase.auth.setSession(refreshToken);
          if (resp.session != null && !resp.session!.isExpired) {
            _accessToken = resp.session!.accessToken;
            _refreshToken = resp.session!.refreshToken;
            await _saveTokens(_accessToken!, _refreshToken!);
          } else {
            // Session expirée → refresh
            try {
              final refreshed = await _supabase.auth.refreshSession();
              if (refreshed.session != null) {
                _accessToken = refreshed.session!.accessToken;
                _refreshToken = refreshed.session!.refreshToken;
                await _saveTokens(_accessToken!, _refreshToken!);
              } else {
                await _clearStorage();
                return false;
              }
            } catch (_) {
              await _clearStorage();
              return false;
            }
          }
        } catch (e) {
          // Token invalide — essayer refresh direct
          try {
            final refreshed = await _supabase.auth.refreshSession();
            if (refreshed.session != null) {
              _accessToken = refreshed.session!.accessToken;
              _refreshToken = refreshed.session!.refreshToken;
              await _saveTokens(_accessToken!, _refreshToken!);
            } else {
              await _clearStorage();
              return false;
            }
          } catch (_) {
            await _clearStorage();
            return false;
          }
        }
      } else {
        _accessToken = accessToken;
      }

      // 4. Charger tenant
      if (tenantJson != null) {
        _tenant = TenantModel.fromJsonString(tenantJson);
      } else {
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          await _fetchTenantForUser(userId);
        }
      }

      notifyListeners();
      return isAuthenticated;
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] tryRestoreSession error: $e');
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
      final resp = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (resp.session == null || resp.user == null) {
        return AuthResult.failure('Identifiants incorrects.');
      }

      _accessToken = resp.session!.accessToken;
      _refreshToken = resp.session!.refreshToken;

      final tenantResult = await _fetchTenantForUser(resp.user!.id);
      if (!tenantResult.success) {
        await _supabase.auth.signOut();
        return AuthResult.failure(
            tenantResult.message ?? 'Aucun restaurant associé.');
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

  // ── Fetch tenant ──────────────────────────────────────────────────────────
  Future<AuthResult> _fetchTenantForUser(String userId) async {
    try {
      // Essai 1: via table de jointure utilisateurs_tenant
      try {
        final data = await _supabase
            .from('utilisateurs_tenant')
            .select(
                'tenant_id, tenants!inner(id, nom, slug, statut, plan_id, couleur_primaire, couleur_secondaire, logo_url, whatsapp_number, domaine_perso, essai_expire_le, metadata)')
            .eq('auth_user_id', userId)
            .isFilter('tenants.deleted_at', null)
            .limit(1)
            .single();

        final tenantMap = data['tenants'] as Map<String, dynamic>?;
        if (tenantMap == null) {
          return AuthResult.failure(
              'Aucun restaurant associé à ce compte.');
        }

        final statut = tenantMap['statut'] as String? ?? 'essai';
        if (statut == 'suspendu') {
          return AuthResult.failure(
              'Votre compte est suspendu. Contactez le support.');
        }

        _tenant = TenantModel.fromJson(tenantMap);
        return AuthResult.success();
      } catch (_) {
        // Essai 2: via table tenants directement (owner_id)
        final data = await _supabase
            .from('tenants')
            .select(
                'id, nom, slug, statut, plan_id, couleur_primaire, couleur_secondaire, logo_url, whatsapp_number, domaine_perso, essai_expire_le, metadata')
            .eq('owner_id', userId)
            .isFilter('deleted_at', null)
            .limit(1)
            .single();

        final statut = data['statut'] as String? ?? 'essai';
        if (statut == 'suspendu') {
          return AuthResult.failure(
              'Votre compte est suspendu. Contactez le support.');
        }

        _tenant = TenantModel.fromJson(data);
        return AuthResult.success();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] _fetchTenantForUser error: $e');
      return AuthResult.failure(
          'Impossible de charger les informations du restaurant.');
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

  // ── Mot de passe oublié — FLUX OTP À 6 CHIFFRES ──────────────────────────
  // ⚠️ REMPLACEMENT COMPLET : l'ancienne implémentation utilisait le Supabase SDK
  // directement (resetPasswordForEmail → envoie un LIEN) et verifyOTP avec
  // OtpType.recovery (type non conforme au backend qui utilise type:'email').
  //
  // NOUVEAU FLUX (confirmé en lisant api-auth.ts) :
  //   Étape 1 — POST /api/v1/auth/forgot-password → Supabase signInWithOtp()
  //             → code à 6 chiffres envoyé par email, JAMAIS un lien
  //   Étape 2 — POST /api/v1/auth/verify-otp { email, token }
  //             → { access_token, refresh_token } renvoyés par le backend
  //   Étape 3 — POST /api/v1/auth/reset-password { password }
  //             → Bearer = access_token obtenu à l'étape 2 (pas le token de session)
  //
  // NOTE : les appels réseau se font dans forgot_password_screen.dart via ApiService
  // (même raison que changePassword : éviter la dépendance circulaire).
  // Ces méthodes restent ici pour valider les données côté client uniquement.

  /// Validation email pour étape 1 (format basique)
  String? validateEmailForOtp(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return 'Entrez votre adresse email.';
    if (!trimmed.contains('@') || !trimmed.contains('.')) {
      return 'Format d\'email invalide.';
    }
    return null; // OK
  }

  /// Validation OTP pour étape 2 (exactement 6 chiffres)
  String? validateOtpCode(String otp) {
    final trimmed = otp.trim();
    if (trimmed.length != 6) return 'Le code doit contenir exactement 6 chiffres.';
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return 'Le code doit être numérique (6 chiffres).';
    }
    return null; // OK
  }

  /// Validation du nouveau mot de passe (étape 3)
  String? validateNewPassword(String password) {
    if (password.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères.';
    }
    return null; // OK
  }

  // Méthodes conservées pour compatibilité — délèguent la validation uniquement
  Future<AuthResult> sendPasswordResetOtp(String email) async {
    final err = validateEmailForOtp(email);
    if (err != null) return AuthResult.failure(err);
    return AuthResult.success(message: 'validation_ok');
  }

  Future<AuthResult> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    // Cette méthode n'est plus utilisée directement — voir forgot_password_screen.dart
    final otpErr = validateOtpCode(otp);
    if (otpErr != null) return AuthResult.failure(otpErr);
    final pwdErr = validateNewPassword(newPassword);
    if (pwdErr != null) return AuthResult.failure(pwdErr);
    return AuthResult.success(message: 'validation_ok');
  }

  // ── Changement de mot de passe (utilisateur connecté) ──────────────────────
  // NOTE: la logique d'appel API est désormais dans ChangePasswordScreen directement
  // (via ApiService.post '/dashboard/profil/change-password') pour éviter la dépendance
  // circulaire AuthService ↔ ApiService. Cette méthode est conservée pour rétrocompabilité
  // mais délègue la validation côté client uniquement.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Validation côté client uniquement — l'appel réseau se fait dans l'écran
    if (newPassword.length < 8) {
      return AuthResult.failure(
          'Nouveau mot de passe: 8 caractères minimum.');
    }
    if (newPassword == currentPassword) {
      return AuthResult.failure(
          'Le nouveau mot de passe doit être différent de l\'ancien.');
    }
    // Signal que la validation côté client est OK — l'écran appelle ensuite l'API
    return AuthResult.success(message: 'validation_ok');
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
    await _secureStorage.write(
        key: AppConfig.keyRefreshToken, value: refresh);
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

  String _mapAuthError(String msg) {
    if (msg.contains('Invalid login credentials') ||
        msg.contains('invalid_credentials')) {
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

class AuthResult {
  final bool success;
  final String? message;

  const AuthResult._({required this.success, this.message});

  factory AuthResult.success({String? message}) =>
      AuthResult._(success: true, message: message);

  factory AuthResult.failure(String message) =>
      AuthResult._(success: false, message: message);
}
