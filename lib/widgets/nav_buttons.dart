// lib/widgets/nav_buttons.dart
// Widget commun : hamburger (menu) + bouton retour, pour les 19 écrans.
//
// [FIX-NAV] — Chaque écran affiche désormais les DEUX boutons :
//   1. Le hamburger (gauche) ouvre le tiroir (drawer) s'il existe, sinon
//      il redirige vers /dashboard/commandes.
//   2. Le retour (immédiatement à droite) revient en arrière quand
//      l'écran est empilé ; sinon il redirige vers /dashboard/commandes.
//
// Utilisation dans un AppBar :
//   appBar: AppBar(
//     leadingWidth: 104,
//     leading: const NavButtons(),
//     ...
//   )
//
// Les écrans sans drawer (compte, change-password, forgot-password)
// bénéficient quand même du hamburger qui les ramène au tableau de bord.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

const String _kFallbackRoute = '/dashboard/commandes';

/// Ouvre le drawer quand l'écran en possède un ; sinon navigation fallback.
void _openMenuOrFallback(BuildContext context) {
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold != null && scaffold.hasDrawer) {
    scaffold.openDrawer();
    return;
  }
  // Les écrans sans drawer (ex: compte, change-password) :
  // aller au tableau de bord — la route s'occupe du confinement d'accès.
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(_kFallbackRoute);
  }
}

/// Revenir en arrière ; si l'écran est racine, aller au tableau de bord.
void _backOrFallback(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(_kFallbackRoute);
}

/// Les deux boutons de navigation (hamburger + retour).
class NavButtons extends StatelessWidget {
  const NavButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Hamburger — ouvre le menu (tiroir) ou fallback.
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => _openMenuOrFallback(context),
            tooltip: 'Menu',
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.gray700,
          ),
          // 2. Retour — pop ou fallback vers le tableau de bord.
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => _backOrFallback(context),
            tooltip: 'Retour',
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.gray700,
          ),
        ],
      ),
    );
  }
}
