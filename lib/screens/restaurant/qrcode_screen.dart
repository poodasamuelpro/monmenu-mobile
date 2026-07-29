// lib/screens/restaurant/qrcode_screen.dart
// QR Code restaurant — affichage, partage, instructions client
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_widget.dart';

class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  String? _qrData;
  String? _boutiqueUrl;
  String? _nomRestaurant;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQrCode());
  }

  Future<void> _loadQrCode() async {
    setState(() { _isLoading = true; _error = null; });
    final api = context.read<ApiService>();

    // Récupérer les infos QR via /dashboard/qrcode
    final resp = await api.getQrCode();
    if (!mounted) return;

    if (resp.success) {
      final data = resp.data ?? {};
      setState(() {
        _qrData = data['qr_url'] as String? ??
            data['boutique_url'] as String? ??
            data['url'] as String?;
        _boutiqueUrl = data['boutique_url'] as String? ?? _qrData;
        _nomRestaurant = data['nom'] as String? ?? 'Mon Restaurant';
        _isLoading = false;
      });
    } else {
      // Fallback: construire l'URL depuis le PDV
      final pdvResp = await api.getPdv();
      if (!mounted) return;
      if (pdvResp.success) {
        final pdvList = pdvResp.data?['points_de_vente'] as List?;
        final pdv = pdvList?.isNotEmpty == true
            ? pdvList!.first as Map<String, dynamic>
            : <String, dynamic>{};
        final slug = pdv['slug'] as String? ?? '';
        setState(() {
          _boutiqueUrl = slug.isNotEmpty
              ? 'https://monmenu.app/boutique/$slug'
              : null;
          _qrData = _boutiqueUrl;
          _nomRestaurant = pdv['nom'] as String? ?? 'Mon Restaurant';
          _isLoading = false;
          if (_qrData == null) _error = resp.error ?? 'QR Code indisponible';
        });
      } else {
        setState(() { _error = resp.error; _isLoading = false; });
      }
    }
  }

  Future<void> _copyUrl() async {
    if (_boutiqueUrl == null) return;
    await Clipboard.setData(ClipboardData(text: _boutiqueUrl!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Lien copié dans le presse-papier'),
      backgroundColor: AppColors.success,
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _shareUrl() async {
    if (_boutiqueUrl == null) return;
    // Utiliser Clipboard comme fallback (share_plus non ajouté pour éviter complexité)
    await Clipboard.setData(ClipboardData(text: _boutiqueUrl!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Lien copié — partagez-le à vos clients'),
      backgroundColor: AppColors.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('QR Code'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.gray900,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: const Divider(height: 1, color: AppColors.gray200),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadQrCode,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingWidget(message: 'Génération du QR Code…');
    if (_error != null) return AppErrorWidget(message: _error!, onRetry: _loadQrCode);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // Titre
        const SizedBox(height: 8),
        Text(
          _nomRestaurant ?? 'Mon Restaurant',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.gray900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'Partagez ce QR Code avec vos clients',
          style: TextStyle(fontSize: 14, color: AppColors.gray500),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 32),

        // QR Code card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gray200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: [
            // QR code avec logo centré
            Stack(alignment: Alignment.center, children: [
              QrImageView(
                data: _qrData ?? 'https://monmenu.app',
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.gray900,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.gray900,
                ),
              ),
              // Logo MonMenu au centre
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 28),
              ),
            ]),

            const SizedBox(height: 16),

            // URL boutique
            if (_boutiqueUrl != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: Row(children: [
                  const Icon(Icons.link_rounded, size: 16, color: AppColors.gray400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _boutiqueUrl!,
                      style: const TextStyle(fontSize: 12, color: AppColors.gray600),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: _copyUrl,
                    child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                  ),
                ]),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 24),

        // Boutons d'action
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _copyUrl,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copier le lien'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _shareUrl,
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Partager'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 32),

        // Instructions
        _buildInstructions(),
      ]),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Comment utiliser ce QR Code', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13)),
        ]),
        const SizedBox(height: 12),
        _instructionStep('1', 'Imprimez ce QR Code et affichez-le sur vos tables'),
        _instructionStep('2', 'Vos clients le scannent avec leur téléphone'),
        _instructionStep('3', 'Ils accèdent directement à votre menu en ligne'),
        _instructionStep('4', 'Les commandes arrivent en temps réel dans votre tableau de bord'),
      ]),
    );
  }

  Widget _instructionStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Center(child: Text(num, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.gray600))),
      ]),
    );
  }
}
