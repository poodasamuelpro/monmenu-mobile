// lib/screens/restaurant/apparence_screen.dart
// Apparence restaurant — couleur primaire, logo, bannière
//
// P4 — UPLOAD RÉEL (parité web api-dashboard.ts) :
//   POST  /dashboard/upload-image  : multipart 'file' + 'ancienne_cle'
//         (purge R2 de l'ancien fichier côté serveur — l.1940-2060)
//   PATCH /dashboard/apparence     : { couleur_primaire?, logo_url?, banniere_url? }
//         (couleurs #RRGGBB — l.1374-1415)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/app_drawer.dart';

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

  // Uploads en cours (désactive le bouton correspondant)
  bool _isUploadingLogo = false;
  bool _isUploadingBanniere = false;

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
    final auth = context.read<AuthService>();
    final tenant = auth.tenant;

    // Fallback immédiat depuis le cache tenant
    if (tenant != null) {
      if (tenant.couleurPrimaire != null) {
        final c = _hexToColor(tenant.couleurPrimaire!);
        if (c != null) _couleurPrimaire = c;
      }
      _logoUrl = tenant.logoUrl;
      _nomRestaurant = tenant.nom;
    }

    // Charger les infos depuis /dashboard/profil (JSON plat — source de vérité)
    // /profil contient: couleur_primaire, logo_url, banniere_url, nom directement
    final profilResp = await api.getProfil();
    if (!mounted) return;

    if (profilResp.success) {
      final data = profilResp.data ?? {};
      // JSON plat — lire les champs directement (pas d'objet 'tenant' imbriqué)
      final couleur = data['couleur_primaire'] as String?;
      if (couleur != null) {
        _couleurPrimaire = _hexToColor(couleur) ?? AppColors.primary;
      }
      _logoUrl = data['logo_url'] as String?;
      _banniereUrl = data['banniere_url'] as String?;
      _nomRestaurant = data['nom'] as String?;
      setState(() => _isLoading = false);
    } else {
      setState(() { _error = profilResp.error; _isLoading = false; });
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

  // ── P4 : extraire la clé R2 depuis l'URL publique /dashboard/media/:key ───
  // Le contrat web exige que 'ancienne_cle' commence par `${tenant_id}/`.
  // Les URLs renvoyées par le backend sont de la forme .../dashboard/media/<cle>
  // (cle encodée URL). Si le format ne correspond pas, on n'envoie rien :
  // le serveur validera de toute façon la clé (sécurité côté backend).
  String? _extraireCleR2(String? url) {
    if (url == null || url.isEmpty) return null;
    const marqueur = '/dashboard/media/';
    final idx = url.indexOf(marqueur);
    if (idx == -1) return null;
    final cle = Uri.decodeComponent(url.substring(idx + marqueur.length));
    if (cle.isEmpty || cle.contains('..')) return null;
    return cle;
  }

  // ── P4 : upload réel logo / bannière ──────────────────────────────────
  // 1. Sélection galerie (ImagePicker, compression intégrée)
  // 2. POST /dashboard/upload-image avec ancienne_cle (purge R2 côté serveur)
  // 3. PATCH /dashboard/apparence { logo_url | banniere_url } immédiat
  Future<void> _uploadMedia({required bool estLogo}) async {
    if (estLogo ? _isUploadingLogo : _isUploadingBanniere) return;

    final api = context.read<ApiService>();

    XFile? picked;
    try {
      final picker = ImagePicker();
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: estLogo ? 800 : 1600,
        maxHeight: estLogo ? 800 : 1600,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible de sélectionner une image'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }
    if (picked == null || !mounted) return;

    setState(() {
      if (estLogo) {
        _isUploadingLogo = true;
      } else {
        _isUploadingBanniere = true;
      }
    });

    // Ancienne clé R2 à purger (extraite de l'URL actuelle)
    final ancienneCle = _extraireCleR2(estLogo ? _logoUrl : _banniereUrl);

    final resp = await api.uploadImage(picked.path, ancienneCle: ancienneCle);

    if (!mounted) return;

    if (!resp.success || resp.data?['url'] == null) {
      setState(() {
        _isUploadingLogo = false;
        _isUploadingBanniere = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resp.error ?? 'Erreur lors de l\'upload'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final nouvelleUrl = resp.data!['url'] as String;

    // Persister immédiatement dans l'apparence (PATCH partiel — contrat web)
    final patchResp = await api.updateApparence(
      estLogo ? {'logo_url': nouvelleUrl} : {'banniere_url': nouvelleUrl},
    );

    if (!mounted) return;
    setState(() {
      _isUploadingLogo = false;
      _isUploadingBanniere = false;
      if (patchResp.success) {
        if (estLogo) {
          _logoUrl = nouvelleUrl;
        } else {
          _banniereUrl = nouvelleUrl;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        patchResp.success
            ? (estLogo ? 'Logo mis à jour' : 'Bannière mise à jour')
            : (patchResp.error ?? 'Image envoyée mais non enregistrée'),
      ),
      backgroundColor:
          patchResp.success ? AppColors.success : AppColors.error,
    ));
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
        leadingWidth: 104,

        leading: const NavButtons(),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.gray200),
        ),
      ),
      drawer: const AppDrawer(),
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

        // Logo — upload réel (P4)
        _buildMediaSection(
          title: 'Logo du restaurant',
          icon: Icons.image_rounded,
          imageUrl: _logoUrl,
          onUpload: () => _uploadMedia(estLogo: true),
          isUploading: _isUploadingLogo,
          ratio: '1:1 — carré, PNG/JPG, max 5 Mo',
        ),
        const SizedBox(height: 16),

        // Bannière — upload réel (P4)
        _buildMediaSection(
          title: 'Image de bannière',
          icon: Icons.panorama_rounded,
          imageUrl: _banniereUrl,
          onUpload: () => _uploadMedia(estLogo: false),
          isUploading: _isUploadingBanniere,
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
    bool isUploading = false,
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

        // Image ou placeholder — toucher pour uploader (P4)
        GestureDetector(
          onTap: isUploading ? null : onUpload,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gray200, style: BorderStyle.solid),
              ),
              child: isUploading
                  ? const Center(
                      child: SizedBox(
                        width: 26, height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.primary,
                        ),
                      ),
                    )
                  : imageUrl != null
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
    return const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.upload_rounded, size: 32, color: AppColors.gray300),
      SizedBox(height: 8),
      Text('Toucher pour ajouter une image',
          style: TextStyle(fontSize: 12, color: AppColors.gray400)),
      SizedBox(height: 4),
      Text('Depuis votre galerie',
          style: TextStyle(fontSize: 11, color: AppColors.gray300)),
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
