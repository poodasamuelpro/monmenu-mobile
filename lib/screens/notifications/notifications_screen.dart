// lib/screens/notifications/notifications_screen.dart
// Notifications in-app restaurant — liste paginée, marquer lue, marquer toutes lues
//
// LOGIQUE IDENTIQUE À L'APP WEB (api-dashboard.ts AJOUT v1.7.0) :
//   Table Supabase : notifications_restaurant
//   Colonnes      : id, tenant_id, type, titre, message, lue, lien, created_at
//
//   GET  /dashboard/notifications/liste?page=&limit=10&non_lues=
//        → { notifications[], page, limit, total, nb_non_lues, has_more }
//   PATCH /dashboard/notifications/:id     { lue: bool }
//   PATCH /dashboard/notifications/tout-lire → { success, nb_mises_a_jour }
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/nav_buttons.dart';

/// Modèle local pour une notification restaurant
class _NotifItem {
  final String id;
  final String type; // 'info' | 'warning' | 'error' | 'success' | 'commande'
  final String titre;
  final String message;
  final bool lue;
  final String? lien;
  final DateTime createdAt;

  const _NotifItem({
    required this.id,
    required this.type,
    required this.titre,
    required this.message,
    required this.lue,
    this.lien,
    required this.createdAt,
  });

  factory _NotifItem.fromJson(Map<String, dynamic> j) => _NotifItem(
        id: j['id'] as String? ?? '',
        type: j['type'] as String? ?? 'info',
        titre: j['titre'] as String? ?? '',
        message: j['message'] as String? ?? '',
        lue: j['lue'] as bool? ?? false,
        lien: j['lien'] as String?,
        createdAt: j['created_at'] != null
            ? DateTime.tryParse(j['created_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  _NotifItem copyWith({bool? lue}) => _NotifItem(
        id: id,
        type: type,
        titre: titre,
        message: message,
        lue: lue ?? this.lue,
        lien: lien,
        createdAt: createdAt,
      );
}

/// [P6] Notification paiement synthétique — contrat web GET /paiement/notifications :
/// { notifications[{id,type,titre,message,action?{label,href},created_at}], count, non_lues }
class _PaiementNotifItem {
  final String id;
  final String type; // 'info' | 'warning' | 'error'
  final String titre;
  final String message;
  final String? actionLabel;
  final String? actionHref;
  final DateTime createdAt;

  const _PaiementNotifItem({
    required this.id,
    required this.type,
    required this.titre,
    required this.message,
    this.actionLabel,
    this.actionHref,
    required this.createdAt,
  });

  factory _PaiementNotifItem.fromJson(Map<String, dynamic> j) {
    final action = j['action'] is Map ? Map<String, dynamic>.from(j['action'] as Map) : null;
    return _PaiementNotifItem(
      id: j['id'] as String? ?? '',
      type: j['type'] as String? ?? 'info',
      titre: j['titre'] as String? ?? '',
      message: j['message'] as String? ?? '',
      actionLabel: action?['label'] as String?,
      actionHref: action?['href'] as String?,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// [P6] Alias des routes web → routes mobiles équivalentes.
/// Le web écrit des liens de notifications avec SES chemins de pages ;
/// on les traduit avant le passage par la whitelist mobile.
String mapLienWebVersMobile(String lien) {
  const aliases = <String, String>{
    '/dashboard/parametres': '/dashboard/settings',
    '/dashboard/abonnement': '/dashboard/plans',
    '/dashboard/home': '/dashboard',
  };
  for (final entry in aliases.entries) {
    if (lien == entry.key || lien.startsWith('${entry.key}/')) {
      return entry.value + lien.substring(entry.key.length);
    }
  }
  return lien;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<_NotifItem> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isToutLireLoading = false;
  String? _error;

  int _page = 1;
  static const int _limit = 10;
  bool _hasMore = false;
  int _nbNonLues = 0;

  // Filtre : uniquement non lues ou toutes
  bool _nonLuesSeulement = false;

  // [P6] Alertes paiement synthétiques (GET /paiement/notifications)
  List<_PaiementNotifItem> _paiementItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPage(reset: true);
      _loadPaiementNotifications();
    });
  }

  // ── [P6] Charger les alertes paiement (essai qui expire, paiement en attente) ─
  Future<void> _loadPaiementNotifications() async {
    final api = context.read<ApiService>();
    final resp = await api.getPaiementNotifications();
    if (!mounted) return;
    if (resp.success && resp.data != null) {
      final rawList = resp.data!['notifications'] as List? ?? [];
      setState(() {
        _paiementItems = rawList
            .map((j) => _PaiementNotifItem.fromJson(j as Map<String, dynamic>))
            .toList();
      });
    }
    // Échec silencieux : la liste principale reste utilisable sans les alertes.
  }

  // ── Charger une page de notifications ──────────────────────────────────────
  Future<void> _loadPage({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _items.clear();
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    final api = context.read<ApiService>();
    final resp = await api.getNotificationsListe(
      page: _page,
      limit: _limit,
      nonLuesSeulement: _nonLuesSeulement,
    );

    if (!mounted) return;

    if (resp.success && resp.data != null) {
      final rawList = resp.data!['notifications'] as List? ?? [];
      final newItems =
          rawList.map((j) => _NotifItem.fromJson(j as Map<String, dynamic>)).toList();

      setState(() {
        if (reset) {
          _items.clear();
        }
        _items.addAll(newItems);
        _hasMore = resp.data!['has_more'] as bool? ?? false;
        _nbNonLues = (resp.data!['nb_non_lues'] as num?)?.toInt() ?? 0;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _error = resp.error ?? 'Erreur chargement notifications';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  // ── Charger la page suivante (pagination) ──────────────────────────────────
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _page++;
    await _loadPage(reset: false);
  }

  // ── Marquer une notification comme lue ────────────────────────────────────
  Future<void> _marquerLue(String id) async {
    // Capturer le lien AVANT l'appel async (sécurité de synchronisation d'état)
    final idx0 = _items.indexWhere((n) => n.id == id);
    final lien = idx0 != -1 ? _items[idx0].lien : null;

    final api = context.read<ApiService>();
    final resp = await api.marquerNotificationLue(id, lue: true);
    if (!mounted) return;

    if (resp.success) {
      setState(() {
        final idx = _items.indexWhere((n) => n.id == id);
        if (idx != -1 && !_items[idx].lue) {
          _items[idx] = _items[idx].copyWith(lue: true);
          if (_nbNonLues > 0) _nbNonLues--;
        }
      });

      // [P6] Navigation : alias web→mobile PUIS whitelist ; fallback dashboard
      if (lien != null && lien.isNotEmpty && mounted) {
        _naviguerVersLien(lien);
      }
    }
  }

  // ── [P6] Traduction alias web→mobile + whitelist + fallback dashboard ──────
  void _naviguerVersLien(String lien) {
    // Liens ancre internes web ('#paiements', '#suppressions') : sans
    // équivalent mobile → fallback dashboard.
    final mappe = lien.startsWith('#') ? '/dashboard' : mapLienWebVersMobile(lien);
    const routesPermises = [
      '/dashboard/commandes',
      '/dashboard/home',
      '/dashboard/menu',
      '/dashboard/supplements',
      '/dashboard/plans',
      '/dashboard/restaurant',
      '/dashboard/stats',
      '/dashboard/settings',
      '/dashboard/notifications',
      '/dashboard/livreurs',
      '/dashboard/qrcode',
      '/dashboard/codes-promo',
      '/dashboard/apparence',
      '/dashboard/change-password',
    ];
    final estInterne = mappe == '/dashboard' ||
        routesPermises.any((r) => mappe == r || mappe.startsWith('$r/'));
    // Lien inconnu : fallback visible vers le dashboard (au lieu d'ignorer).
    context.go(estInterne ? mappe : '/dashboard');
  }

  // ── Marquer toutes les notifications comme lues ────────────────────────────
  Future<void> _marquerToutesLues() async {
    if (_nbNonLues == 0) return;

    setState(() => _isToutLireLoading = true);
    final api = context.read<ApiService>();
    final resp = await api.marquerToutesLues();
    if (!mounted) return;

    setState(() => _isToutLireLoading = false);

    if (resp.success) {
      setState(() {
        for (int i = 0; i < _items.length; i++) {
          if (!_items[i].lue) {
            _items[i] = _items[i].copyWith(lue: true);
          }
        }
        _nbNonLues = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Toutes les notifications ont été marquées comme lues'),
          backgroundColor: AppColors.success,
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(resp.error ?? 'Erreur'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ── Icône selon le type de notification ───────────────────────────────────
  IconData _iconForType(String type) {
    switch (type) {
      case 'commande':
        return Icons.receipt_long_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'error':
        return Icons.error_outline_rounded;
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'paiement':
        return Icons.payment_rounded;
      case 'info':
      default:
        return Icons.info_outline_rounded;
    }
  }

  // ── Couleur selon le type ─────────────────────────────────────────────────
  Color _colorForType(String type) {
    switch (type) {
      case 'commande':
        return AppColors.primary;
      case 'warning':
        return AppColors.warning;
      case 'error':
        return AppColors.error;
      case 'success':
        return AppColors.success;
      case 'paiement':
        return const Color(0xFF7C3AED); // violet
      case 'info':
      default:
        return AppColors.secondary;
    }
  }

  // ── Formater la date ──────────────────────────────────────────────────────
  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (_nbNonLues > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_nbNonLues',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.gray900,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 104,

        leading: const NavButtons(),
        actions: [
          // Filtre non lues seulement
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilterChip(
              label: Text(
                'Non lues',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  // Couleur explicite pour garantir le contraste WCAG
                  // Sélectionné : rouge primary sur fond primaryLight (red-100)
                  // Non sélectionné : gray700 (#374151) sur fond gray100 (#F3F4F6)
                  color: _nonLuesSeulement
                      ? AppColors.primary
                      : AppColors.gray700,
                ),
              ),
              selected: _nonLuesSeulement,
              onSelected: (v) {
                setState(() => _nonLuesSeulement = v);
                _loadPage(reset: true);
              },
              selectedColor: AppColors.primaryLight,
              backgroundColor: AppColors.gray100,
              checkmarkColor: AppColors.primary,
              showCheckmark: false,
              side: BorderSide(
                color: _nonLuesSeulement
                    ? AppColors.primaryBorder
                    : AppColors.gray300,
                width: 1,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            ),
          ),
          // Tout marquer comme lus
          if (_nbNonLues > 0)
            _isToutLireLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.done_all_rounded),
                    tooltip: 'Tout marquer comme lu',
                    onPressed: _marquerToutesLues,
                  ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: const AppDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Chargement des notifications…',
              style: TextStyle(color: AppColors.gray400, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.gray600, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _loadPage(reset: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      // [P6] Même vide, afficher les alertes paiement si présentes
      if (_paiementItems.isNotEmpty) {
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await _loadPage(reset: true);
            await _loadPaiementNotifications();
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildPaiementSection(),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  _nonLuesSeulement
                      ? 'Aucune notification non lue'
                      : 'Aucune autre notification',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.gray400,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: AppColors.gray300,
            ),
            const SizedBox(height: 16),
            Text(
              _nonLuesSeulement
                  ? 'Aucune notification non lue'
                  : 'Aucune notification',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.gray600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _nonLuesSeulement
                  ? 'Toutes vos notifications ont été lues'
                  : 'Vos notifications apparaîtront ici',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.gray400,
              ),
            ),
            if (_nonLuesSeulement) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() => _nonLuesSeulement = false);
                  _loadPage(reset: true);
                },
                child: const Text('Voir toutes les notifications'),
              ),
            ],
          ],
        ),
      );
    }

    // [P6] Bloc paiement en tête de liste (index 0 si présent)
    final hasPaiement = _paiementItems.isNotEmpty;
    final headerCount = hasPaiement ? 1 : 0;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await _loadPage(reset: true);
        await _loadPaiementNotifications();
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: headerCount + _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          if (hasPaiement && index == 0) {
            return _buildPaiementSection();
          }
          final itemIndex = index - headerCount;
          // Bouton "Charger plus" en fin de liste
          if (itemIndex == _items.length) {
            return _buildLoadMoreButton();
          }
          return _buildNotifTile(_items[itemIndex]);
        },
      ),
    );
  }

  // ── [P6] Section « Paiement » : alertes de GET /paiement/notifications ────
  Widget _buildPaiementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text(
            'Paiement',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.gray600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ..._paiementItems.map(_buildPaiementTile),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            'Autres notifications',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.gray600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  // ── [P6] Tuile d'une alerte paiement (avec action → alias + whitelist) ────
  Widget _buildPaiementTile(_PaiementNotifItem notif) {
    final color = _colorForType(notif.type);
    final icon = _iconForType(notif.type);

    return Material(
      color: color.withValues(alpha: 0.06),
      child: InkWell(
        onTap: notif.actionHref != null
            ? () => _naviguerVersLien(notif.actionHref!)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.titre,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.gray600,
                        height: 1.35,
                      ),
                    ),
                    if (notif.actionLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${notif.actionLabel} →',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tuile d'une notification ──────────────────────────────────────────────
  Widget _buildNotifTile(_NotifItem notif) {
    final color = _colorForType(notif.type);
    final icon = _iconForType(notif.type);

    return Material(
      color: notif.lue ? Colors.white : AppColors.primaryLight.withValues(alpha: 0.4),
      child: InkWell(
        onTap: () => _marquerLue(notif.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icône type
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),

              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.titre,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notif.lue
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: AppColors.gray900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Point non lue
                        if (!notif.lue)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: notif.lue ? AppColors.gray500 : AppColors.gray700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatDate(notif.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.gray400,
                          ),
                        ),
                        if (!notif.lue) ...[
                          const Spacer(),
                          Text(
                            'Appuyer pour marquer lue',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bouton "Charger plus" (pagination) ────────────────────────────────────
  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      child: _isLoadingMore
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            )
          : OutlinedButton.icon(
              onPressed: _loadMore,
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              label: const Text('Charger plus de notifications'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primaryBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
    );
  }
}
