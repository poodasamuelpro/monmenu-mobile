// lib/widgets/in_app_notification_banner.dart
// Bannière de notification in-app qui s'affiche par-dessus tout le contenu
// Déclenché par NotificationService.onShowInAppBanner
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Overlay global : positionné en haut de l'écran, auto-dismiss après 4s
class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;
  const InAppNotificationOverlay({super.key, required this.child});

  @override
  State<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState
    extends State<InAppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnim;

  String? _title;
  String? _body;
  bool _isCommande = false;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Connecter le callback du service après le premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectService();
    });
  }

  void _connectService() {
    if (!mounted) return;
    final service = context.read<NotificationService>();
    service.onShowInAppBanner = (title, body, {isCommande = false}) {
      _show(title, body, isCommande: isCommande);
    };
  }

  void _show(String title, String body, {bool isCommande = false}) {
    if (!mounted) return;
    setState(() {
      _title = title;
      _body = body;
      _isCommande = isCommande;
    });
    _controller.forward(from: 0);
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) {
        setState(() {
          _title = null;
          _body = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_title != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnim,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(14),
                      color: _isCommande
                          ? const Color(0xFF111827)
                          : AppColors.surface,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isCommande
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : AppColors.gray200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _isCommande
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : AppColors.success.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isCommande
                                    ? Icons.receipt_long_rounded
                                    : Icons.notifications_rounded,
                                color: _isCommande
                                    ? AppColors.primary
                                    : AppColors.success,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _title!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _isCommande
                                          ? Colors.white
                                          : AppColors.gray900,
                                    ),
                                  ),
                                  if (_body != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _body!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _isCommande
                                            ? AppColors.gray400
                                            : AppColors.gray600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 16,
                                color: _isCommande
                                    ? AppColors.gray400
                                    : AppColors.gray500,
                              ),
                              onPressed: _dismiss,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
