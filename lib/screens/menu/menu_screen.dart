// lib/screens/menu/menu_screen.dart
// Menu complet — CRUD catégories + produits, toggle disponibilité
// Image upload : POST /dashboard/upload-image (multipart/form-data, champ 'file')
// Produit API: photo_url (pas image_url)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../models/produit_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/loading_widget.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  List<CategorieModel> _categories = [];
  Map<String, List<ProduitModel>> _produitsByCategorie = {};
  bool _isLoading = true;
  String? _error;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMenu());
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    setState(() { _isLoading = true; _error = null; });
    final api = context.read<ApiService>();

    // Charger catégories + produits ensemble via /dashboard/menu
    final resp = await api.getMenu();
    if (!mounted) return;

    if (resp.success) {
      final data = resp.data ?? {};

      // API retourne: { categories: [{id, nom, ..., produits: [{...}]}] }
      // Les produits sont IMBRIQUÉS dans chaque catégorie (pas au niveau racine)
      final catList = <CategorieModel>[];
      final Map<String, List<ProduitModel>> byCateg = {};

      for (final catJson in (data['categories'] as List? ?? [])) {
        final catMap = catJson as Map<String, dynamic>;
        final cat = CategorieModel.fromJson(catMap);
        catList.add(cat);
        // Extraire les produits embarqués dans chaque catégorie
        final embeddedProduits = (catMap['produits'] as List? ?? [])
            .map((p) => ProduitModel.fromJson(p as Map<String, dynamic>))
            .toList();
        byCateg[cat.id] = embeddedProduits;
      }

      _tabController?.dispose();
      final newTabController = catList.isNotEmpty
          ? TabController(length: catList.length, vsync: this)
          : null;

      setState(() {
        _categories = catList;
        _produitsByCategorie = byCateg;
        _tabController = newTabController;
        _isLoading = false;
      });
    } else {
      setState(() { _error = resp.error; _isLoading = false; });
    }
  }

  Future<void> _toggleProduit(ProduitModel prod) async {
    final api = context.read<ApiService>();
    final resp = await api.updateProduit(prod.id, {'disponible': !prod.disponible});
    if (!mounted) return;
    if (resp.success) {
      _loadMenu();
    } else {
      _showSnack(resp.error ?? 'Erreur', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  void _showCategorieDialog({CategorieModel? categorie}) {
    showDialog(
      context: context,
      builder: (_) => _CategorieDialog(
        categorie: categorie,
        onSaved: _loadMenu,
      ),
    );
  }

  void _showProduitDialog({ProduitModel? produit, String? categorieId}) {
    final categId = categorieId ?? (produit?.categorieId) ??
        (_categories.isNotEmpty ? _categories[_tabController?.index ?? 0].id : null);
    showDialog(
      context: context,
      builder: (_) => _ProduitDialog(
        produit: produit,
        categorieId: categId,
        categories: _categories,
        onSaved: _loadMenu,
      ),
    );
  }

  void _confirmDeleteCategorie(CategorieModel cat) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la catégorie'),
        content: Text('Supprimer « ${cat.nom} » et tous ses produits ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final api = context.read<ApiService>();
              final resp = await api.deleteCategorie(cat.id);
              if (!mounted) return;
              if (resp.success) {
                _showSnack('Catégorie supprimée');
                _loadMenu();
              } else {
                _showSnack(resp.error ?? 'Erreur', isError: true);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduit(ProduitModel prod) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le produit'),
        content: Text('Supprimer « ${prod.nom} » ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final api = context.read<ApiService>();
              final resp = await api.deleteProduit(prod.id);
              if (!mounted) return;
              if (resp.success) {
                _showSnack('Produit supprimé');
                _loadMenu();
              } else {
                _showSnack(resp.error ?? 'Erreur', isError: true);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
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
        title: const Text('Menu'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.gray900,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard/commandes'),
          tooltip: 'Retour',
        ),
        bottom: _buildTabBar(),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded),
            onPressed: () => _showCategorieDialog(),
            tooltip: 'Nouvelle catégorie',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMenu,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: _categories.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showProduitDialog(),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Produit', style: TextStyle(color: Colors.white)),
            )
          : null,
      drawer: const AppDrawer(),
      body: _buildBody(),
    );
  }

  PreferredSize? _buildTabBar() {
    if (_isLoading || _error != null || _categories.isEmpty) return null;
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.gray500,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
        tabs: _categories.map((c) => Tab(text: c.nom)).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingWidget(message: 'Chargement du menu…');
    if (_error != null) return AppErrorWidget(message: _error!, onRetry: _loadMenu);

    if (_categories.isEmpty) {
      return _buildEmptyMenu();
    }

    return TabBarView(
      controller: _tabController,
      children: _categories.map((cat) => _buildCategoriePage(cat)).toList(),
    );
  }

  Widget _buildEmptyMenu() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.restaurant_menu_rounded, size: 64, color: AppColors.gray300),
      const SizedBox(height: 16),
      const Text('Menu vide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray600)),
      const SizedBox(height: 8),
      const Text('Commencez par créer une catégorie', style: TextStyle(color: AppColors.gray400)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => _showCategorieDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Créer une catégorie'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ]));
  }

  Widget _buildCategoriePage(CategorieModel cat) {
    final produits = _produitsByCategorie[cat.id] ?? [];

    return RefreshIndicator(
      onRefresh: _loadMenu,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // Header catégorie avec actions
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat.nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gray900)),
                if (cat.description != null)
                  Text(cat.description!, style: const TextStyle(fontSize: 12, color: AppColors.gray400)),
                Text('${produits.length} produit${produits.length != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.gray400)),
              ])),
              // Editer catégorie
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                onPressed: () => _showCategorieDialog(categorie: cat),
                tooltip: 'Modifier la catégorie',
              ),
              // Supprimer catégorie
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                onPressed: () => _confirmDeleteCategorie(cat),
                tooltip: 'Supprimer la catégorie',
              ),
            ]),
          )),

          // Liste produits
          if (produits.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.fastfood_rounded, size: 48, color: AppColors.gray300),
                const SizedBox(height: 12),
                const Text('Aucun produit dans cette catégorie', style: TextStyle(color: AppColors.gray400)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showProduitDialog(categorieId: cat.id),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Ajouter un produit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ])),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProduitCard(
                      produit: produits[i],
                      onEdit: () => _showProduitDialog(produit: produits[i]),
                      onDelete: () => _confirmDeleteProduit(produits[i]),
                      onToggle: () => _toggleProduit(produits[i]),
                    ),
                  ),
                  childCount: produits.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Card produit ──────────────────────────────────────────────────────────────
class _ProduitCard extends StatelessWidget {
  final ProduitModel produit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _ProduitCard({
    required this.produit,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: produit.disponible ? AppColors.gray200 : AppColors.gray200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Opacity(
        opacity: produit.disponible ? 1.0 : 0.6,
        child: Row(children: [
          // Image produit
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(11),
              bottomLeft: Radius.circular(11),
            ),
            child: SizedBox(
              width: 80, height: 80,
              child: produit.imageUrl != null
                  ? Image.network(produit.imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder())
                  : _imagePlaceholder(),
            ),
          ),

          // Infos
          Expanded(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(
                  produit.nom,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.gray900),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: produit.disponible
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.gray100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    produit.disponible ? 'Disponible' : 'Indisponible',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: produit.disponible ? AppColors.success : AppColors.gray400,
                    ),
                  ),
                ),
              ]),
              if (produit.description != null) ...[
                const SizedBox(height: 2),
                Text(produit.description!, style: const TextStyle(fontSize: 12, color: AppColors.gray400), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 6),
              Row(children: [
                Text(
                  '${produit.prix.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary),
                ),
                if (produit.variantes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('+ ${produit.variantes.length} variante${produit.variantes.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.gray400)),
                ],
              ]),
            ]),
          )),

          // Actions
          Column(mainAxisSize: MainAxisSize.min, children: [
            Switch(
              value: produit.disponible,
              onChanged: (_) => onToggle(),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.success,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 16),
                onPressed: onEdit,
                color: AppColors.primary,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                onPressed: onDelete,
                color: AppColors.error,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ]),
            const SizedBox(height: 4),
          ]),
        ]),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.gray100,
      child: const Center(child: Icon(Icons.fastfood_rounded, color: AppColors.gray300, size: 32)),
    );
  }
}

// ── Dialog catégorie ───────────────────────────────────────────────────────────
class _CategorieDialog extends StatefulWidget {
  final CategorieModel? categorie;
  final VoidCallback onSaved;
  const _CategorieDialog({this.categorie, required this.onSaved});

  @override
  State<_CategorieDialog> createState() => _CategorieDialogState();
}

class _CategorieDialogState extends State<_CategorieDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _descCtrl;
  bool _isLoading = false;

  bool get _isEdit => widget.categorie != null;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.categorie?.nom ?? '');
    _descCtrl = TextEditingController(text: widget.categorie?.description ?? '');
  }

  @override
  void dispose() { _nomCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    final payload = {
      'nom': _nomCtrl.text.trim(),
      if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
    };
    final resp = _isEdit
        ? await api.updateCategorie(widget.categorie!.id, payload)
        : await api.createCategorie(payload);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (resp.success) {
      Navigator.pop(context);
      widget.onSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp.error ?? 'Erreur'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Modifier la catégorie' : 'Nouvelle catégorie'),
      content: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _nomCtrl,
            decoration: InputDecoration(
              labelText: 'Nom de la catégorie *',
              prefixIcon: const Icon(Icons.category_rounded, size: 18, color: AppColors.gray400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Description (optionnel)',
              prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 24), child: Icon(Icons.notes_rounded, size: 18, color: AppColors.gray400)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Modifier' : 'Créer'),
        ),
      ],
    );
  }
}

// ── Dialog produit ─────────────────────────────────────────────────────────────
// Upload image via POST /dashboard/upload-image (multipart, champ 'file')
// API produit: photo_url (champ correct côté Supabase/API)
class _ProduitDialog extends StatefulWidget {
  final ProduitModel? produit;
  final String? categorieId;
  final List<CategorieModel> categories;
  final VoidCallback onSaved;
  const _ProduitDialog({this.produit, this.categorieId, required this.categories, required this.onSaved});

  @override
  State<_ProduitDialog> createState() => _ProduitDialogState();
}

class _ProduitDialogState extends State<_ProduitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _prixCtrl;
  late String? _selectedCategorieId;
  bool _disponible = true;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  // Image — URL actuelle (existante ou uploadée)
  String? _photoUrl;
  // Image locale sélectionnée (à uploader)
  XFile? _selectedImage;

  bool get _isEdit => widget.produit != null;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.produit?.nom ?? '');
    _descCtrl = TextEditingController(text: widget.produit?.description ?? '');
    _prixCtrl = TextEditingController(text: widget.produit?.prix.toStringAsFixed(0) ?? '');
    _selectedCategorieId = widget.produit?.categorieId ?? widget.categorieId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);
    _disponible = widget.produit?.disponible ?? true;
    _photoUrl = widget.produit?.imageUrl;
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  // ── Sélectionner une image depuis la galerie ──────────────────────────────
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
      setState(() => _selectedImage = picked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible de sélectionner une image'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ── Comprimer et uploader l'image ─────────────────────────────────────────
  // Route : POST /api/v1/dashboard/upload-image
  // Champ multipart : 'file'
  // Réponse : { success, url, key }
  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      setState(() => _isUploadingImage = true);

      // Capturer le provider avant tout await (évite use_build_context_synchronously)
      final api = context.read<ApiService>();

      // Dossier temp
      final tempDir = await getTemporaryDirectory();
      final compressedPath = '${tempDir.path}/produit_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Compression : max 800KB, qualité 80
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        compressedPath,
        quality: 80,
        minWidth: 400,
        minHeight: 400,
        format: CompressFormat.jpeg,
      );

      final filePath = result?.path ?? imageFile.path;

      // Upload via API
      final resp = await api.uploadImage(filePath);

      if (!mounted) return null;
      setState(() => _isUploadingImage = false);

      if (resp.success && resp.data?['url'] != null) {
        return resp.data!['url'] as String;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(resp.error ?? 'Erreur upload image'),
            backgroundColor: AppColors.error,
          ));
        }
        return null;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de l\'upload de l\'image'),
          backgroundColor: AppColors.error,
        ));
      }
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final api = context.read<ApiService>();

    // Upload image si une nouvelle a été sélectionnée
    String? finalPhotoUrl = _photoUrl;
    if (_selectedImage != null) {
      final uploaded = await _uploadImage(_selectedImage!);
      if (!mounted) return;
      if (uploaded != null) {
        finalPhotoUrl = uploaded;
      } else {
        // L'upload a échoué — on continue sans image ou avec l'ancienne
      }
    }

    final payload = <String, dynamic>{
      'nom': _nomCtrl.text.trim(),
      if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
      'prix': double.tryParse(_prixCtrl.text) ?? 0,
      if (_selectedCategorieId != null) 'categorie_id': _selectedCategorieId,
      'photo_url': finalPhotoUrl, // Champ correct API
      'disponible': _disponible,
    };

    final resp = _isEdit
        ? await api.updateProduit(widget.produit!.id, payload)
        : await api.createProduit(payload);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (resp.success) {
      Navigator.pop(context);
      widget.onSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resp.error ?? 'Erreur'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.fastfood_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _isEdit ? 'Modifier le produit' : 'Nouveau produit',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              )),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero),
            ]),
            const SizedBox(height: 20),

            // ── Sélecteur d'image ─────────────────────────────────────────
            const Text('Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.gray700)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isLoading || _isUploadingImage ? null : _pickImage,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.gray200,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _isUploadingImage
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
                            ),
                          )
                        : _photoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.network(
                                  _photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _imagePlaceholderContent(),
                                ),
                              )
                            : _imagePlaceholderContent(),
              ),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton.icon(
                onPressed: _isLoading ? null : _pickImage,
                icon: const Icon(Icons.photo_library_rounded, size: 14),
                label: const Text('Choisir une image', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: EdgeInsets.zero),
              ),
              if (_selectedImage != null || _photoUrl != null)
                TextButton.icon(
                  onPressed: () => setState(() { _selectedImage = null; _photoUrl = null; }),
                  icon: const Icon(Icons.delete_rounded, size: 14),
                  label: const Text('Supprimer', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error, padding: EdgeInsets.zero),
                ),
            ]),
            const SizedBox(height: 12),

            // ── Catégorie ─────────────────────────────────────────────────
            if (widget.categories.isNotEmpty) ...[
              const Text('Catégorie', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.gray700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategorieId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nom))).toList(),
                onChanged: (v) => setState(() => _selectedCategorieId = v),
                validator: (v) => v == null ? 'Catégorie requise' : null,
              ),
              const SizedBox(height: 12),
            ],

            // ── Nom ───────────────────────────────────────────────────────
            TextFormField(
              controller: _nomCtrl,
              decoration: InputDecoration(
                labelText: 'Nom du produit *',
                prefixIcon: const Icon(Icons.label_rounded, size: 18, color: AppColors.gray400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 12),

            // ── Description ───────────────────────────────────────────────
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Icon(Icons.notes_rounded, size: 18, color: AppColors.gray400),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // ── Prix ──────────────────────────────────────────────────────
            TextFormField(
              controller: _prixCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Prix (FCFA) *',
                prefixIcon: const Icon(Icons.attach_money_rounded, size: 18, color: AppColors.gray400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Prix requis';
                if (double.tryParse(v) == null) return 'Prix invalide';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // ── Disponible ────────────────────────────────────────────────
            SwitchListTile(
              title: const Text('Disponible à la vente', style: TextStyle(fontSize: 14)),
              value: _disponible,
              onChanged: (v) => setState(() => _disponible = v),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.success,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 20),

            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text('Annuler'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: (_isLoading || _isUploadingImage) ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: (_isLoading || _isUploadingImage)
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEdit ? 'Modifier' : 'Créer'),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _imagePlaceholderContent() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.add_photo_alternate_rounded, size: 36, color: AppColors.gray300),
      const SizedBox(height: 6),
      const Text('Appuyer pour ajouter une image', style: TextStyle(fontSize: 12, color: AppColors.gray400)),
    ]);
  }
}
