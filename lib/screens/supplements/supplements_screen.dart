// lib/screens/supplements/supplements_screen.dart
// Gestion des suppléments généraux — parité web /dashboard/supplements
// (3e entrée de la sidebar web, après Menu — src/pages/dashboard.ts l.40-64)
//
// SYNC API (src/routes/api-supplements.ts, Bearer exempté de CSRF) :
//   GET    /dashboard/supplements          → { supplements[] }
//   GET    /dashboard/supplements/limite   → { actif, limite, utilises }
//   POST   /dashboard/supplements          → { success, id } (201)
//   PATCH  /dashboard/supplements/:id      → { success }
//   DELETE /dashboard/supplements/:id      → { success } (soft-delete + purge R2)
//   POST   /dashboard/supplements/:id/image (multipart 'file', 5 Mo max)
//          → { success, url, key } — le serveur purge l'ancienne photo
//
// Règles web : nom 1-100 caractères, prix 0-999 999, jamais de prix
// recalculés côté client.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/supplement_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/nav_buttons.dart';

class SupplementsScreen extends StatefulWidget {
  const SupplementsScreen({super.key});

  @override
  State<SupplementsScreen> createState() => _SupplementsScreenState();
}

class _SupplementsScreenState extends State<SupplementsScreen> {
  List<SupplementModel> _supplements = [];
  SupplementLimiteModel? _limite;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    setState(() { _isLoading = true; _error = null; });
    final api = context.read<ApiService>();

    final resp = await api.getSupplements();
    if (!mounted) return;

    if (resp.success) {
      final list = (resp.data?['supplements'] as List? ?? [])
          .map((j) => SupplementModel.fromJson(j as Map<String, dynamic>))
          .toList();
      // Tri par ordre_affichage puis nom (parité affichage web)
      list.sort((a, b) {
        final cmp = a.ordreAffichage.compareTo(b.ordreAffichage);
        return cmp != 0 ? cmp : a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
      });
      setState(() { _supplements = list; _isLoading = false; });
    } else {
      setState(() { _error = resp.error; _isLoading = false; });
    }

    // Limite plan (non bloquant pour l'affichage de la liste)
    final limiteResp = await api.getSupplementLimite();
    if (!mounted) return;
    if (limiteResp.success && limiteResp.data != null) {
      setState(() =>
          _limite = SupplementLimiteModel.fromJson(limiteResp.data!));
    }
  }

  Future<void> _toggleActif(SupplementModel s) async {
    final api = context.read<ApiService>();
    final resp = await api.updateSupplement(s.id, {'actif': !s.actif});
    if (!mounted) return;
    if (resp.success) {
      _loadAll();
    } else {
      _showSnack(resp.error ?? 'Erreur', isError: true);
    }
  }

  void _confirmDelete(SupplementModel s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le supplément'),
        content: Text('Supprimer « ${s.nom} » ?\nSa photo sera également supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final api = context.read<ApiService>();
              final resp = await api.deleteSupplement(s.id);
              if (!mounted) return;
              if (resp.success) {
                _showSnack('Supplément supprimé');
                _loadAll();
              } else {
                _showSnack(resp.error ?? 'Erreur suppression', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  void _showSupplementSheet({SupplementModel? supplement}) {
    // Création bloquée si la limite du plan est atteinte (parité web)
    if (supplement == null && (_limite?.limiteAtteinte ?? false)) {
      _showSnack(
        'Limite de suppléments atteinte (${_limite!.utilises}/${_limite!.limite}). '
        'Passez à un plan supérieur.',
        isError: true,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplementSheet(
        supplement: supplement,
        onSaved: _loadAll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Suppléments'),
        leadingWidth: 104,

        leading: const NavButtons(),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupplementSheet(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
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
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.gray600)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadAll,
      child: _supplements.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.add_circle_outline_rounded,
            size: 64, color: AppColors.gray300),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Aucun supplément',
            style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600,
              color: AppColors.gray600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Les suppléments (fromage, sauce, boisson…) sont proposés '
              'à vos clients lors de la commande.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.gray400),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        if (_limite != null && _limite!.limite > 0) _buildLimiteBanner(),
        ..._supplements.map(_buildTile),
      ],
    );
  }

  Widget _buildLimiteBanner() {
    final l = _limite!;
    final atteinte = l.limiteAtteinte;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: atteinte ? AppColors.primaryLight : AppColors.gray100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: atteinte ? AppColors.primaryBorder : AppColors.gray200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            atteinte ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: 18,
            color: atteinte ? AppColors.primary : AppColors.gray500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              atteinte
                  ? 'Limite atteinte : ${l.utilises}/${l.limite} suppléments. '
                    'Passez à un plan supérieur pour en ajouter.'
                  : '${l.utilises}/${l.limite} suppléments utilisés sur votre plan.',
              style: TextStyle(
                fontSize: 12,
                color: atteinte ? AppColors.primary : AppColors.gray600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(SupplementModel s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showSupplementSheet(supplement: s),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: s.photoUrl != null && s.photoUrl!.isNotEmpty
                    ? Image.network(
                        s.photoUrl!,
                        width: 52, height: 52, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _photoPlaceholder(),
                      )
                    : _photoPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.nom,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: s.actif ? AppColors.gray900 : AppColors.gray400,
                        decoration:
                            s.actif ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${s.prix.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              // Toggle actif
              Switch(
                value: s.actif,
                onChanged: (_) => _toggleActif(s),
                activeThumbColor: AppColors.primary,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppColors.gray400),
                onPressed: () => _confirmDelete(s),
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 52, height: 52,
      color: AppColors.gray100,
      child: const Icon(Icons.fastfood_rounded,
          size: 22, color: AppColors.gray300),
    );
  }
}

// ── Bottom sheet création / édition ──────────────────────────────────────────
class _SupplementSheet extends StatefulWidget {
  final SupplementModel? supplement;
  final VoidCallback onSaved;

  const _SupplementSheet({this.supplement, required this.onSaved});

  @override
  State<_SupplementSheet> createState() => _SupplementSheetState();
}

class _SupplementSheetState extends State<_SupplementSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _prixCtrl;
  late bool _actif;
  XFile? _pickedImage;
  bool _isSubmitting = false;

  bool get _isEdit => widget.supplement != null;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.supplement?.nom ?? '');
    _prixCtrl = TextEditingController(
      text: widget.supplement != null
          ? widget.supplement!.prix.toStringAsFixed(0)
          : '',
    );
    _actif = widget.supplement?.actif ?? true;
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() => _pickedImage = picked);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible de sélectionner une image'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final api = context.read<ApiService>();
    final nom = _nomCtrl.text.trim();
    final prix = double.tryParse(_prixCtrl.text.trim()) ?? 0;

    String? supplementId = widget.supplement?.id;
    ApiResponse resp;

    if (_isEdit) {
      resp = await api.updateSupplement(supplementId!, {
        'nom': nom,
        'prix': prix,
        'actif': _actif,
      });
    } else {
      resp = await api.createSupplement({
        'nom': nom,
        'prix': prix,
        'actif': _actif,
        'ordre': 0,
      });
      supplementId = resp.data?['id'] as String?;
    }

    if (!mounted) return;

    if (!resp.success) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resp.error ?? 'Erreur enregistrement'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    // Upload photo si sélectionnée (le serveur purge l'ancienne automatiquement)
    if (_pickedImage != null && supplementId != null) {
      final imgResp =
          await api.uploadSupplementImage(supplementId, _pickedImage!.path);
      if (!mounted) return;
      if (!imgResp.success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Supplément enregistré mais photo non envoyée : '
            '${imgResp.error ?? 'erreur upload'}',
          ),
          backgroundColor: AppColors.warning,
        ));
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEdit ? 'Modifier le supplément' : 'Nouveau supplément',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 20),

            // Photo
            Center(
              child: GestureDetector(
                onTap: _isSubmitting ? null : _pickImage,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildPreview(),
                    ),
                    Positioned(
                      right: 4, bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Nom (1-100 caractères — règle web)
            const Text('Nom', style: AppTextStyles.label),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nomCtrl,
              maxLength: 100,
              decoration: const InputDecoration(
                hintText: 'Ex : Fromage supplémentaire',
                counterText: '',
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Nom requis';
                if (t.length > 100) return '100 caractères maximum';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Prix (0 à 999 999 — règle web)
            const Text('Prix (FCFA)', style: AppTextStyles.label),
            const SizedBox(height: 6),
            TextFormField(
              controller: _prixCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: 'Ex : 500'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Prix requis';
                final p = double.tryParse(t);
                if (p == null || p < 0) return 'Prix invalide';
                if (p > 999999) return 'Prix maximum : 999 999';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Actif
            SwitchListTile(
              value: _actif,
              onChanged: (v) => setState(() => _actif = v),
              title: const Text('Disponible',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _save,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2,
                        ),
                      )
                    : Text(_isEdit ? 'Enregistrer' : 'Créer le supplément'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final existingUrl = widget.supplement?.photoUrl;
    if (_pickedImage == null && (existingUrl == null || existingUrl.isEmpty)) {
      return Container(
        width: 90, height: 90,
        color: AppColors.gray100,
        child: const Icon(Icons.add_photo_alternate_rounded,
            size: 30, color: AppColors.gray300),
      );
    }
    if (_pickedImage == null) {
      return Image.network(
        existingUrl!,
        width: 90, height: 90, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 90, height: 90,
          color: AppColors.gray100,
          child: const Icon(Icons.broken_image_rounded,
              size: 26, color: AppColors.gray300),
        ),
      );
    }
    // Image locale sélectionnée
    return SizedBox(
      width: 90, height: 90,
      child: FutureBuilder(
        future: _pickedImage!.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              color: AppColors.gray100,
              child: const Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        },
      ),
    );
  }
}
