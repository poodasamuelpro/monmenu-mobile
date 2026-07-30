// lib/screens/restaurant/apparence_screen.dart
// Apparence restaurant — couleur primaire, logo, bannière
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_widget.dart';

class ApparenceScreen extends StatefulWidget {
  const ApparenceScreen({super.key});

  @override
  State<ApparenceScreen> createState() => _ApparenceScreenState();
}

class _ApparenceScreenState extends State<ApparenceScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  Color _couleurPrimaire = AppColors.primary;
  String? _logoUrl;
  String? _banniereUrl;
  String? _nomRestaurant;

  // Palette de couleurs prédéfinies
  static const _palette = [
    Color(0xFFDC2626), // Rouge MonMenu
    Color(0xFF1D4ED8), // Bleu MonMenu
    Color(0xFF16A34A), // Vert
    Color(0xFFD97706), // Amber
    Color(0xFF7C3AED), // Violet
    Color(0xFFDB2777), // Rose
    Color(0xFF0891B2), // Cyan
    Color(0xFF374151), // Gris foncé
    Color(0xFFEA580C), // Orange
    Color(0xFF059669), // Émeraude
    Color(0xFF4F46E5), // Indigo
    Color(0xFFBE123C), // Rouge foncé
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadApparence());
  }

  Future<void> _loadApparence() async {
    setState(() { _isLoading = true; _error = null; });
    final api = context.read<ApiService>();

    // Charger les infos depuis /dashboard/pdv ou /dashboard/profil
    final resp = await api.getPdv();
    if (!mounted) return;

    if (resp.success) {
      final list = resp.data?['points_de_vente'] as List?;
      if (list != null && list.isNotEmpty) {
        final pdv = list.first as Map<String, dynamic>;
        final couleur = pdv['couleur_primaire'] as String?;
        if (couleur != null) {
          _couleurPrimaire = _hexToColor(couleur) ?? AppColors.primary;
        }
        _logoUrl = pdv['logo_url'] as String?;
        _banniereUrl = pdv['banniere_url'] as String?;
        _nomRestaurant = pdv['nom'] as String?;
      }
      setState(() => _isLoading = false);
    } else {
      // Fallback: charger depuis profil
      final profilResp = await api.getProfil();
      if (!mounted) return;
      if (profilResp.success) {
        final tenant = profilResp.data?['tenant'] as Map<String, dynamic>?;
        final couleur = tenant?['couleur_primaire'] as String?;
        if (couleur != null) {
          _couleurPrimaire = _hexToColor(couleur) ?? AppColors.primary;
        }
        _logoUrl = tenant?['logo_url'] as String?;
        _nomRestaurant = tenant?['nom'] as String?;
        setState(() => _isLoading = false);
      } else {
        setState(() { _error = resp.error; _isLoading = false; });
      }
    }
  }

  Color? _hexToColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return null;
    }
  }

  String _colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final api = context.read<ApiService>();

    final payload = {
      'couleur_primaire': _colorToHex(_couleurPrimaire),
    };

    final resp = await api.updateApparence(payload);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Apparence mise à jour'),
        backgroundColor: AppColors.success,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resp.error ?? 'Erreur de sauvegarde'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  void _showCustomColorPicker() {
    final hexCtrl = TextEditingController(text: _colorToHex(_couleurPrimaire).substring(1));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Couleur personnalisée'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Entrez un code hexadécimal (ex: DC2626)', style: TextStyle(fontSize: 13, color: AppColors.gray500)),
          const SizedBox(height: 12),
          Row(children: [
            const Text('#', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: hexCtrl,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final color = _hexToColor(hexCtrl.text.trim());
              if (color != null) {
                setState(() => _couleurPrimaire = color);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  void _showUploadInfo(String type) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Upload $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'L\'upload de $type est disponible depuis la version web de MonMenu.',
              style: const TextStyle(fontSize: 14, color: AppColors.gray600),
            ),
            const SizedBox(height: 12),
            const Text(
              'Accédez à :',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
            ),
            const SizedBox(height: 4),
            const SelectableText(
              'https://monmenu.app/dashboard/apparence',
              style: TextStyle(fontSize: 13, color: AppColors.primary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse('https://monmenu.app/dashboard/apparence');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Ouvrir le web'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Apparence'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.gray900,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: const Divider(height: 1, color: AppColors.gray200),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingWidget(message: 'Chargement de l\'apparence…');
    if (_error != null) return AppErrorWidget(message: _error!, onRetry: _loadApparence);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Aperçu
        _buildPreview(),
        const SizedBox(height: 16),

        // Couleur primaire
        _buildColorSection(),
        const SizedBox(height: 16),

        // Logo
        _buildMediaSection(
          title: 'Logo du restaurant',
          icon: Icons.image_rounded,
          imageUrl: _logoUrl,
          onUpload: () => _showUploadInfo('logo'),
          ratio: '1:1 — carré, PNG/JPG, max 2 Mo',
        ),
        const SizedBox(height: 16),

        // Bannière
        _buildMediaSection(
          title: 'Image de bannière',
          icon: Icons.panorama_rounded,
          imageUrl: _banniereUrl,
          onUpload: () => _showUploadInfo('bannière'),
          ratio: '16:9 — paysage, PNG/JPG, max 5 Mo',
          aspectRatio: 16 / 9,
        ),
        const SizedBox(height: 24),

        // Bouton sauvegarder
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_isSaving ? 'Sauvegarde…' : 'Sauvegarder l\'apparence'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _couleurPrimaire,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.visibility_rounded, size: 16, color: AppColors.gray500),
          const SizedBox(width: 8),
          const Text('Aperçu en temps réel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.gray600)),
        ]),
        const SizedBox(height: 16),

        // Mini preview boutique
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: _couleurPrimaire,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const SizedBox(width: 16),
            // Logo placeholder
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.restaurant_rounded, color: Colors.white.withValues(alpha: 0.8), size: 28),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(
                _nomRestaurant ?? 'Mon Restaurant',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Text(
                _colorToHex(_couleurPrimaire),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildColorSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.palette_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Couleur principale', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.gray900)),
        ]),
        const SizedBox(height: 4),
        const Text('Utilisée sur votre boutique en ligne', style: TextStyle(fontSize: 12, color: AppColors.gray400)),
        const SizedBox(height: 16),

        // Palette
        Wrap(spacing: 10, runSpacing: 10, children: [
          ..._palette.map((color) => _ColorSwatch(
            color: color,
            selected: _couleurPrimaire.toARGB32() == color.toARGB32(),
            onTap: () => setState(() => _couleurPrimaire = color),
          )),
          // Bouton custom
          InkWell(
            onTap: _showCustomColorPicker,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gray200, width: 2),
                gradient: const LinearGradient(
                  colors: [Colors.red, Colors.green, Colors.blue, Colors.yellow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(child: Icon(Icons.add_rounded, color: Colors.white, size: 16)),
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Couleur sélectionnée
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _couleurPrimaire,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _colorToHex(_couleurPrimaire),
            style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace', color: AppColors.gray700),
          ),
        ]),
      ]),
    );
  }

  Widget _buildMediaSection({
    required String title,
    required IconData icon,
    String? imageUrl,
    required VoidCallback onUpload,
    required String ratio,
    double aspectRatio = 1.0,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.gray900)),
        ]),
        const SizedBox(height: 4),
        Text(ratio, style: const TextStyle(fontSize: 12, color: AppColors.gray400)),
        const SizedBox(height: 12),

        // Image ou placeholder
        GestureDetector(
          onTap: onUpload,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gray200, style: BorderStyle.solid),
              ),
              child: imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _uploadPlaceholder(),
                      ),
                    )
                  : _uploadPlaceholder(),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _uploadPlaceholder() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.upload_rounded, size: 32, color: AppColors.gray300),
      const SizedBox(height: 8),
      const Text('Toucher pour changer', style: TextStyle(fontSize: 12, color: AppColors.gray400)),
      const SizedBox(height: 4),
      const Text('Via la version web', style: TextStyle(fontSize: 11, color: AppColors.gray300)),
    ]);
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: AppColors.gray900, width: 3) : null,
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)]
              : null,
        ),
        child: selected
            ? const Center(child: Icon(Icons.check_rounded, color: Colors.white, size: 18))
            : null,
      ),
    );
  }
}
