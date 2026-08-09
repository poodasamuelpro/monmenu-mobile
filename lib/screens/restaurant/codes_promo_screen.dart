// lib/screens/restaurant/codes_promo_screen.dart
// Codes promotionnels — liste, création, toggle actif, suppression
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/livreur_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_widget.dart';

class CodesPromoScreen extends StatefulWidget {
  const CodesPromoScreen({super.key});

  @override
  State<CodesPromoScreen> createState() => _CodesPromoScreenState();
}

class _CodesPromoScreenState extends State<CodesPromoScreen> {
  List<CodePromoModel> _promos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPromos());
  }

  Future<void> _loadPromos() async {
    setState(() { _isLoading = true; _error = null; });
    final api = context.read<ApiService>();
    final resp = await api.getCodesPromo();
    if (!mounted) return;
    if (resp.success) {
      // Backend renvoie { codes: [...] } — clé confirmée dans api-dashboard.ts
      final list = (resp.data?['codes'] as List? ?? [])
          .map((j) => CodePromoModel.fromJson(j as Map<String, dynamic>))
          .toList();
      setState(() { _promos = list; _isLoading = false; });
    } else {
      setState(() { _error = resp.error; _isLoading = false; });
    }
  }

  // AUDIT-S5 FIX-A : PATCH /dashboard/codes-promo/:id n'existe PAS côté backend.
  // Le backend ne fournit que POST (créer) et DELETE (supprimer) pour les codes promo.
  // Le toggle actif/inactif n'est pas supporté par l'API actuelle.
  // UI : le Switch est désactivé et un message explicatif est affiché.
  void _toggleActif(CodePromoModel promo) {
    _showSnack(
      'Modification non disponible : le serveur ne supporte pas la mise à jour des codes promo. Supprimez et recréez le code si nécessaire.',
      isError: true,
    );
  }

  Future<void> _delete(CodePromoModel promo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le code promo'),
        content: Text('Supprimer le code « ${promo.code} » ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final api = context.read<ApiService>();
    final resp = await api.deleteCodePromo(promo.id);
    if (!mounted) return;
    if (resp.success) {
      _showSnack('Code supprimé');
      _loadPromos();
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

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (_) => _PromoDialog(onSaved: _loadPromos),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Codes Promo'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.gray900,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard/commandes'),
          tooltip: 'Retour',
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.gray200),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadPromos,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nouveau code', style: TextStyle(color: Colors.white)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingWidget(message: 'Chargement des codes promo…');
    if (_error != null) return AppErrorWidget(message: _error!, onRetry: _loadPromos);
    if (_promos.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      onRefresh: _loadPromos,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _promos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _PromoCard(
          promo: _promos[i],
          onToggle: () => _toggleActif(_promos[i]),
          onDelete: () => _delete(_promos[i]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.discount_outlined, size: 64, color: AppColors.gray300),
      const SizedBox(height: 16),
      const Text('Aucun code promo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray600)),
      const SizedBox(height: 8),
      const Text('Créez votre premier code de réduction', style: TextStyle(color: AppColors.gray400)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Créer un code'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ]));
  }
}

// ── Card code promo ────────────────────────────────────────────────────────────
class _PromoCard extends StatelessWidget {
  final CodePromoModel promo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _PromoCard({required this.promo, required this.onToggle, required this.onDelete});

  Color get _statusColor {
    if (promo.isExpire) return AppColors.gray400;
    if (promo.isEpuise) return AppColors.warning;
    if (!promo.actif) return AppColors.gray400;
    return AppColors.success;
  }

  String get _statusLabel {
    if (promo.isExpire) return 'Expiré';
    if (promo.isEpuise) return 'Épuisé';
    if (!promo.actif) return 'Inactif';
    return 'Actif';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ligne 1: code + status badge + switch
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gray900,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                promo.code,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1.5, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor)),
            ),
            const Spacer(),
            if (!promo.isExpire && !promo.isEpuise)
              Tooltip(
                message: 'Modification non disponible via l\'API actuelle',
                child: Switch(
                  value: promo.actif,
                  onChanged: null, // désactivé : PATCH /codes-promo/:id inexistant côté backend
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.success,
                ),
              ),
          ]),

          const SizedBox(height: 12),

          // Ligne 2: réduction + utilisations
          Row(children: [
            _InfoChip(
              icon: Icons.sell_rounded,
              label: promo.reductionFormatee,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            _InfoChip(
              icon: Icons.group_rounded,
              label: promo.maxUtilisations != null
                  ? '${promo.utilisationsActuelles}/${promo.maxUtilisations} utilisations'
                  : '${promo.utilisationsActuelles} utilisations',
              color: AppColors.gray500,
            ),
          ]),

          if (promo.minCommande != null) ...[
            const SizedBox(height: 6),
            _InfoChip(
              icon: Icons.shopping_cart_rounded,
              label: 'Min: ${promo.minCommande!.toStringAsFixed(0)} FCFA',
              color: AppColors.gray500,
            ),
          ],

          if (promo.dateExpiration != null) ...[
            const SizedBox(height: 6),
            _InfoChip(
              icon: Icons.schedule_rounded,
              label: 'Expire: ${_formatDate(promo.dateExpiration!)}',
              color: promo.isExpire ? AppColors.error : AppColors.gray500,
            ),
          ],

          const SizedBox(height: 12),

          // Bouton supprimer
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Supprimer'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color)),
    ]);
  }
}

// ── Dialog création code promo ─────────────────────────────────────────────────
class _PromoDialog extends StatefulWidget {
  final VoidCallback onSaved;
  const _PromoDialog({required this.onSaved});

  @override
  State<_PromoDialog> createState() => _PromoDialogState();
}

class _PromoDialogState extends State<_PromoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _valeurCtrl = TextEditingController();
  final _maxUtilCtrl = TextEditingController();
  String _typeReduction = 'pourcentage';
  DateTime? _dateExpiration;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose(); _valeurCtrl.dispose();
    _maxUtilCtrl.dispose();
    super.dispose();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = DateTime.now().millisecondsSinceEpoch;
    final code = List.generate(8, (i) => chars[(rand >> i) % chars.length]).join();
    _codeCtrl.text = code;
    return code;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _dateExpiration = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final api = context.read<ApiService>();
    // Noms de champs conformes à l'API backend (api-dashboard.ts) :
    //   'type'       au lieu de 'type_reduction'
    //   'usage_max'  au lieu de 'max_utilisations'
    //   'date_fin'   au lieu de 'date_expiration'
    // 'min_commande' n'est pas supporté côté backend — retiré de la requête
    final payload = {
      'code': _codeCtrl.text.trim().toUpperCase(),
      'type': _typeReduction,
      'valeur': double.tryParse(_valeurCtrl.text) ?? 0,
      if (_maxUtilCtrl.text.trim().isNotEmpty)
        'usage_max': int.tryParse(_maxUtilCtrl.text),
      if (_dateExpiration != null) 'date_fin': _dateExpiration!.toIso8601String(),
    };

    final resp = await api.createCodePromo(payload);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (resp.success) {
      Navigator.pop(context);
      widget.onSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resp.error ?? 'Erreur création'),
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
            // Titre
            Row(children: [
              const Icon(Icons.discount_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Nouveau code promo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero),
            ]),
            const SizedBox(height: 20),

            // Code
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Code promo *',
                    prefixIcon: const Icon(Icons.label_rounded, size: 18, color: AppColors.gray400),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Code requis' : null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _generateCode()),
                icon: const Icon(Icons.casino_rounded, color: AppColors.primary),
                tooltip: 'Générer un code',
              ),
            ]),

            const SizedBox(height: 12),

            // Type réduction
            const Text('Type de réduction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.gray700)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _TypeChip(
                label: '% Pourcentage',
                selected: _typeReduction == 'pourcentage',
                onTap: () => setState(() => _typeReduction = 'pourcentage'),
              )),
              const SizedBox(width: 8),
              Expanded(child: _TypeChip(
                label: 'Montant fixe',
                selected: _typeReduction == 'montant_fixe',
                onTap: () => setState(() => _typeReduction = 'montant_fixe'),
              )),
            ]),

            const SizedBox(height: 12),

            // Valeur
            TextFormField(
              controller: _valeurCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _typeReduction == 'pourcentage' ? 'Valeur (%) *' : 'Montant (FCFA) *',
                prefixIcon: Icon(
                  _typeReduction == 'pourcentage' ? Icons.percent_rounded : Icons.attach_money_rounded,
                  size: 18, color: AppColors.gray400,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Valeur requise';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Valeur invalide';
                if (_typeReduction == 'pourcentage' && n > 100) return 'Max 100%';
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Note : montant min. commande non supporté par le serveur
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, size: 14, color: AppColors.gray500),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Le montant minimum de commande n\'est pas encore disponible. Fonctionnalité à venir.',
                  style: TextStyle(fontSize: 11, color: AppColors.gray500),
                )),
              ]),
            ),

            const SizedBox(height: 12),

            // Max utilisations
            TextFormField(
              controller: _maxUtilCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nombre max d\'utilisations',
                prefixIcon: const Icon(Icons.group_rounded, size: 18, color: AppColors.gray400),
                hintText: 'Illimité si vide',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),

            const SizedBox(height: 12),

            // Date expiration
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.gray300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.gray400),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    _dateExpiration != null
                        ? 'Expire le ${_dateExpiration!.day}/${_dateExpiration!.month}/${_dateExpiration!.year}'
                        : 'Date d\'expiration (optionnel)',
                    style: TextStyle(
                      color: _dateExpiration != null ? AppColors.gray900 : AppColors.gray400,
                      fontSize: 14,
                    ),
                  )),
                  if (_dateExpiration != null)
                    GestureDetector(
                      onTap: () => setState(() => _dateExpiration = null),
                      child: const Icon(Icons.clear_rounded, size: 16, color: AppColors.gray400),
                    ),
                ]),
              ),
            ),

            const SizedBox(height: 24),

            // Boutons
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text('Annuler'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Créer'),
              )),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.primary : AppColors.gray200),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : AppColors.gray600),
        ),
      ),
    );
  }
}
