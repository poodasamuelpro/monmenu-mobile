// lib/screens/menu/menu_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/produit_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/loading_widget.dart' as lw;

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<CategorieModel> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    final resp = await context.read<ApiService>().getMenu();
    if (!mounted) return;
    if (resp.success) {
      final list = resp.data?['categories'] as List? ?? [];
      setState(() {
        _categories = list
            .map((e) => CategorieModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() { _error = resp.error; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categories.isEmpty ? 1 : _categories.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Menu'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _showAddCategorieDialog(),
              tooltip: 'Ajouter une catégorie',
            ),
          ],
          bottom: _categories.isEmpty
              ? null
              : TabBar(
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.gray400,
                  indicatorColor: AppColors.primary,
                  tabs: _categories.map((c) => Tab(text: c.nom)).toList(),
                ),
        ),
        drawer: const AppDrawer(),
        body: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: lw.ShimmerList(count: 5),
              )
            : _error != null
                ? lw.ErrorWidget(message: _error!, onRetry: _load)
                : _categories.isEmpty
                    ? _EmptyMenu(onAdd: _showAddCategorieDialog)
                    : TabBarView(
                        children: _categories.map((cat) => _CategorieTab(
                          categorie: cat,
                          onRefresh: _load,
                        )).toList(),
                      ),
        floatingActionButton: _categories.isNotEmpty
            ? FloatingActionButton(
                onPressed: () => _showAddProduitDialog(),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add_rounded, color: Colors.white),
              )
            : null,
      ),
    );
  }

  void _showAddCategorieDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nom de la catégorie'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await context.read<ApiService>().createCategorie({
                'nom': ctrl.text.trim(),
              });
              _load();
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _showAddProduitDialog() {
    // Navigation vers formulaire produit
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité disponible prochainement')),
    );
  }
}

class _CategorieTab extends StatelessWidget {
  final CategorieModel categorie;
  final VoidCallback onRefresh;

  const _CategorieTab({required this.categorie, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final produits = categorie.produits;
    if (produits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_menu_rounded,
                size: 48, color: AppColors.gray200),
            const SizedBox(height: 12),
            const Text('Aucun produit dans cette catégorie',
                style: TextStyle(color: AppColors.gray400, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Ajouter un produit'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: produits.length,
      itemBuilder: (ctx, i) => _ProduitTile(produit: produits[i]),
    );
  }
}

class _ProduitTile extends StatelessWidget {
  final ProduitModel produit;
  const _ProduitTile({required this.produit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: produit.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      produit.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.fastfood_rounded,
                        color: AppColors.gray300, size: 24,
                      ),
                    ),
                  )
                : const Icon(Icons.fastfood_rounded,
                    color: AppColors.gray300, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produit.nom,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.gray800,
                  ),
                ),
                if (produit.description != null)
                  Text(
                    produit.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12, color: AppColors.gray400,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  produit.prixFormate,
                  style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Disponible toggle
          Switch(
            value: produit.disponible,
            onChanged: (_) {},
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryLight,
          ),
        ],
      ),
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyMenu({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded,
              size: 64, color: AppColors.gray200),
          const SizedBox(height: 16),
          const Text(
            'Votre menu est vide',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: AppColors.gray600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Commencez par créer des catégories\npuis ajoutez vos produits',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.gray400),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Créer une catégorie'),
          ),
        ],
      ),
    );
  }
}
