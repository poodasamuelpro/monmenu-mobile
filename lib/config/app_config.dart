// lib/config/app_config.dart
// Configuration globale MonMenu — credentials Supabase + constantes API
class AppConfig {
  // ── Supabase ──────────────────────────────────────────────────────────────
  static const String supabaseUrl = 'https://vkgtcfwnrhnvhsooiovm.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrZ3RjZnducmhudmhzb29pb3ZtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNTcwNjMsImV4cCI6MjEwMDczMzA2M30'
      '.7TQ79mzG4NUO5Snk3ThfL5jt9Chul9pQrcF4nhlAJKA';

  // ── API Backend (Cloudflare Workers) ─────────────────────────────────────
  static const String apiBaseUrl = 'https://monmenu.poodasamuelpro.workers.dev';
  static const String apiVersion = '/api/v1';

  static String get apiUrl => '$apiBaseUrl$apiVersion';

  // ── Endpoints ─────────────────────────────────────────────────────────────
  static const String loginEndpoint = '/auth/login';
  static const String logoutEndpoint = '/auth/logout';
  static const String refreshEndpoint = '/auth/refresh';
  static const String forgotPasswordEndpoint = '/auth/forgot-password';
  static const String resetPasswordEndpoint = '/auth/reset-password';

  // ── Sécurité ──────────────────────────────────────────────────────────────
  static const int tokenMinLength = 20;
  static const int sessionTimeoutHours = 1;
  static const int refreshTokenDays = 30;

  // ── Plan essai ────────────────────────────────────────────────────────────
  static const int essaiDureeJours = 14;

  // ── Design System ─────────────────────────────────────────────────────────
  static const String primaryColorHex = '#DC2626';
  static const String secondaryColorHex = '#1D4ED8';
  static const String sidebarColorHex = '#111827';
  static const String backgroundColorHex = '#F9FAFB';

  // ── App info ──────────────────────────────────────────────────────────────
  static const String appName = 'MonMenu';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'contact.monmenu@gmail.com';

  // ── Stockage sécurisé — clés ──────────────────────────────────────────────
  static const String keyAccessToken = 'mm_access_token';
  static const String keyRefreshToken = 'mm_refresh_token';
  static const String keyTenantData = 'mm_tenant_data';
  static const String keyUserEmail = 'mm_user_email';

  // ── Hive boxes ────────────────────────────────────────────────────────────
  static const String hiveBoxCommandes = 'commandes_cache';
  static const String hiveBoxMenu = 'menu_cache';
  static const String hiveBoxStats = 'stats_cache';

  // ── FCM — Firebase Cloud Messaging ────────────────────────────────────────
  // Endpoint pour enregistrer/supprimer le token FCM du device
  static const String fcmTokenEndpoint = '/dashboard/fcm-token';

  // IDs des canaux Android (doivent correspondre aux canaux créés dans NotificationService)
  static const String fcmChannelCommandes = 'commandes_channel';
  static const String fcmChannelPaiement = 'payment_channel';

  // Firebase Project ID (source: google-services.json → project_info.project_id)
  // Utilisé dans les logs uniquement — les secrets FCM backend sont dans Cloudflare env vars
  static const String firebaseProjectId = 'monmenumanager';
}
