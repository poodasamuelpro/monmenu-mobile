// lib/theme/app_theme.dart
// MonMenu Design System — reproduit exactement le design web
// Couleurs: red #DC2626, blue #1D4ED8, sidebar #111827, bg #F9FAFB
import 'package:flutter/material.dart';

class AppColors {
  // Primaires
  static const Color primary = Color(0xFFDC2626);       // red-600
  static const Color primaryDark = Color(0xFFB91C1C);   // red-700
  static const Color primaryLight = Color(0xFFFEE2E2);  // red-100
  static const Color primaryBorder = Color(0xFFFECACA); // red-200

  // Secondaires
  static const Color secondary = Color(0xFF1D4ED8);      // blue-700
  static const Color secondaryLight = Color(0xFFEFF6FF); // blue-50

  // Sidebar (identique au web: bg-gray-900)
  static const Color sidebar = Color(0xFF111827);        // gray-900
  static const Color sidebarHover = Color(0xFF1F2937);   // gray-800
  static const Color sidebarBorder = Color(0xFF374151);  // gray-700
  static const Color sidebarText = Color(0xFFD1D5DB);    // gray-300
  static const Color sidebarActive = Color(0xFFF9FAFB);  // gray-50

  // Fond (bg-gray-50)
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);

  // Gris
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray900 = Color(0xFF111827);

  // Statuts commandes
  static const Color statusEnAttente = Color(0xFFF59E0B);     // amber-500
  static const Color statusConfirmee = Color(0xFF3B82F6);      // blue-500
  static const Color statusEnPreparation = Color(0xFF8B5CF6);  // violet-500
  static const Color statusEnLivraison = Color(0xFFEC4899);    // pink-500
  static const Color statusLivree = Color(0xFF10B981);         // emerald-500
  static const Color statusAnnulee = Color(0xFF6B7280);        // gray-500

  // Succès / Erreur / Warning
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Fond des statuts
  static const Color statusEnAttenteBg = Color(0xFFFEF3C7);
  static const Color statusConfirmeeBg = Color(0xFFEFF6FF);
  static const Color statusLivreeBg = Color(0xFFD1FAE5);
  static const Color statusAnnuleeBg = Color(0xFFF3F4F6);
}

class AppTextStyles {
  static const String fontFamily = 'Inter';

  static const TextStyle h1 = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w700,
    color: AppColors.gray900, height: 1.2,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w700,
    color: AppColors.gray900, height: 1.3,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w700,
    color: AppColors.gray900,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400,
    color: AppColors.gray700,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.gray700,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.gray500,
  );
  static const TextStyle label = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.gray700,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400,
    color: AppColors.gray400,
  );
  static const TextStyle button = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w700,
    color: Colors.white, letterSpacing: 0.1,
  );
  static const TextStyle buttonOutlined = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
  static const TextStyle price = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w700,
    color: AppColors.gray900,
  );
  static const TextStyle priceLarge = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w800,
    color: AppColors.gray900,
  );
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: AppTextStyles.fontFamily,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.gray900,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.gray200,
      titleTextStyle: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w700,
        color: AppColors.gray900,
      ),
      iconTheme: IconThemeData(color: AppColors.gray700),
    ),

    // ElevatedButton — bouton rouge principal (identique web)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: AppTextStyles.button,
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return AppColors.primaryDark;
          if (states.contains(WidgetState.disabled)) return AppColors.gray300;
          return AppColors.primary;
        }),
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primaryBorder, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: AppTextStyles.buttonOutlined,
      ),
    ),

    // TextButton
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),

    // InputDecoration (identique web: border-gray-200 rounded-xl focus:ring-red)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray200, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gray200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.gray500, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.gray400, fontSize: 14),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
    ),

    // Card
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.gray100, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.gray100, thickness: 1, space: 1,
    ),

    // BottomNavigationBar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.gray400,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.gray100,
      selectedColor: AppColors.primaryLight,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentTextStyle: const TextStyle(fontSize: 14, color: Colors.white),
    ),
  );
}

// ── Helper extensions ─────────────────────────────────────────────────────────
extension ColorHex on Color {
  static Color fromHex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

// Statut commande → couleur + libellé
class CommandeStatut {
  static Color background(String statut) {
    switch (statut) {
      case 'en_attente': return AppColors.statusEnAttenteBg;
      case 'confirmee': return AppColors.statusConfirmeeBg;
      case 'en_preparation': return const Color(0xFFF5F3FF);
      case 'en_livraison': return const Color(0xFFFDF2F8);
      case 'livree': return AppColors.statusLivreeBg;
      case 'annulee': return AppColors.statusAnnuleeBg;
      default: return AppColors.gray100;
    }
  }

  static Color foreground(String statut) {
    switch (statut) {
      case 'en_attente': return AppColors.statusEnAttente;
      case 'confirmee': return AppColors.statusConfirmee;
      case 'en_preparation': return AppColors.statusEnPreparation;
      case 'en_livraison': return AppColors.statusEnLivraison;
      case 'livree': return AppColors.statusLivree;
      case 'annulee': return AppColors.statusAnnulee;
      default: return AppColors.gray500;
    }
  }

  static String label(String statut) {
    switch (statut) {
      case 'en_attente': return 'En attente';
      case 'confirmee': return 'Confirmée';
      case 'en_preparation': return 'En préparation';
      case 'en_livraison': return 'En livraison';
      case 'livree': return 'Livrée';
      case 'annulee': return 'Annulée';
      default: return statut;
    }
  }

  static IconData icon(String statut) {
    switch (statut) {
      case 'en_attente': return Icons.access_time_rounded;
      case 'confirmee': return Icons.check_circle_outline_rounded;
      case 'en_preparation': return Icons.restaurant_rounded;
      case 'en_livraison': return Icons.delivery_dining_rounded;
      case 'livree': return Icons.check_circle_rounded;
      case 'annulee': return Icons.cancel_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  static List<String> get all => [
    'en_attente', 'confirmee', 'en_preparation',
    'en_livraison', 'livree', 'annulee',
  ];

  static List<String> get actives => [
    'en_attente', 'confirmee', 'en_preparation', 'en_livraison',
  ];
}

// Statut tenant
class TenantStatut {
  static Color color(String statut) {
    switch (statut) {
      case 'actif': return AppColors.success;
      case 'essai': return AppColors.warning;
      case 'inactif': return AppColors.gray500;
      case 'suspendu': return AppColors.error;
      case 'en_attente_confirmation': return AppColors.info;
      default: return AppColors.gray500;
    }
  }

  static String label(String statut) {
    switch (statut) {
      case 'actif': return 'Actif';
      case 'essai': return 'Essai';
      case 'inactif': return 'Inactif';
      case 'suspendu': return 'Suspendu';
      case 'en_attente_confirmation': return 'En attente';
      default: return statut;
    }
  }
}
