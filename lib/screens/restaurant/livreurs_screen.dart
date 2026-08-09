// lib/screens/restaurant/livreurs_screen.dart
// Gestion complète des livreurs — liste, ajout, édition, toggle actif
// SYNC API : POST/PATCH /dashboard/livreurs → champs: nom, whatsapp_number, actif
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/livreur_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_widget.dart';

class LivreursScreen extends StatefulWidget {
  const LivreursScreen({super.key});

  @override
  State<LivreursScreen> createState() => _LivreursScreenState();
}

class _LivreursScreenState extends State<LivreursScreen> {
  List<LivreurModel> _livreurs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLivreurs());
  }

  Future<void> _loadLivreurs() async {
    setState(() { _isLoading = true; _error = null; });
    final api = context.read<ApiService>();
    final resp = await api.getLivreurs();
    if (!mounted) return;
    if (resp.success) {
      final list = (resp.data?['livreurs'] as List? ?? [])
          .map((j) => LivreurModel.fromJson(j as Map<String, dynamic>))
          .toList();
      setState(() { _livreurs = list; _isLoading = false; });
    } else {
      setState(() { _error = resp.error; _isLoading = false; });
    }
  }

  Future<void> _toggleActif(LivreurModel l) async {
    final api = context.read<ApiService>();
    // API attend: actif (bool ou 0/1)
    final resp = await api.updateLivreur(l.id, {'actif': !l.actif});
    if (!mounted) return;
    if (resp.success) {
      _loadLivreurs();
    } else {
      _showSnack(resp.error ?? 'Erreur', isError: true);
    }
  }

  Future<void> _openWhatsApp(String whatsapp) async {
    final clean = whatsapp.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final numero = clean.startsWith('+') ? clean.substring(1) : clean;
    final uri = Uri.parse('https://wa.me/$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  void _showLivreurDialog({LivreurModel? livreur}) {
    showDialog(
      context: context,
      builder: (_) => _LivreurDialog(
        livreur: livreur,
        onSaved: _loadLivreurs,
      ),
    );
  }

  void _confirmDelete(LivreurModel l) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le livreur'),
        content: Text('Supprimer « ${l.nom} » ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final api = context.read<ApiService>();
              final resp = await api.deleteLivreur(l.id);
              if (!mounted) return;
              if (resp.success) {
                _showSnack('Livreur supprimé');
                _loadLivreurs();
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
        title: const Text('Livreurs'),
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
            onPressed: _loadLivreurs,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLivreurDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingWidget(message: 'Chargement des livreurs…');
    if (_error != null) return AppErrorWidget(message: _error!, onRetry: _loadLivreurs);
    if (_livreurs.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      onRefresh: _loadLivreurs,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _livreurs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _LivreurCard(
          livreur: _livreurs[i],
          onEdit: () => _showLivreurDialog(livreur: _livreurs[i]),
          onToggle: () => _toggleActif(_livreurs[i]),
          onDelete: () => _confirmDelete(_livreurs[i]),
          onWhatsApp: _livreurs[i].whatsappNumber != null
              ? () => _openWhatsApp(_livreurs[i].whatsappNumber!)
              : null,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.delivery_dining_rounded, size: 64, color: AppColors.gray300),
        const SizedBox(height: 16),
        const Text('Aucun livreur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray600)),
        const SizedBox(height: 8),
        const Text('Ajoutez votre premier livreur', style: TextStyle(color: AppColors.gray400)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _showLivreurDialog(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter un livreur'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }
}

// ── Card livreur ─────────────────────────────────────────────────────────────
class _LivreurCard extends StatelessWidget {
  final LivreurModel livreur;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onWhatsApp;

  const _LivreurCard({
    required this.livreur,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            // Avatar
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: livreur.actif ? AppColors.primary.withValues(alpha: 0.1) : AppColors.gray100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delivery_dining_rounded,
                color: livreur.actif ? AppColors.primary : AppColors.gray400,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      livreur.nom,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.gray900),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusBadge(actif: livreur.actif),
                ]),
                if (livreur.whatsappNumber != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.phone_rounded, size: 13, color: AppColors.gray400),
                    const SizedBox(width: 4),
                    Text(livreur.whatsappNumber!, style: const TextStyle(fontSize: 13, color: AppColors.gray500)),
                  ]),
                ],
              ],
            )),

            // Actions
            Column(children: [
              Switch(
                value: livreur.actif,
                onChanged: (_) => onToggle(),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.success,
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  onPressed: onEdit,
                  color: AppColors.primary,
                  tooltip: 'Modifier',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: onDelete,
                  color: AppColors.error,
                  tooltip: 'Supprimer',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ]),
            ]),
          ]),

          // Bouton WhatsApp livreur
          if (onWhatsApp != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onWhatsApp,
                icon: const Icon(Icons.chat_rounded, size: 14),
                label: const Text('Contacter sur WhatsApp', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(color: Color(0xFF25D366)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool actif;
  const _StatusBadge({required this.actif});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: actif ? AppColors.success.withValues(alpha: 0.1) : AppColors.gray100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        actif ? 'Actif' : 'Inactif',
        style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: actif ? AppColors.success : AppColors.gray500,
        ),
      ),
    );
  }
}

// ── Dialog ajout / édition ────────────────────────────────────────────────────
// API POST /dashboard/livreurs : { nom, whatsapp_number }
// API PATCH /dashboard/livreurs/:id : { nom?, whatsapp_number?, actif? }
class _LivreurDialog extends StatefulWidget {
  final LivreurModel? livreur;
  final VoidCallback onSaved;

  const _LivreurDialog({this.livreur, required this.onSaved});

  @override
  State<_LivreurDialog> createState() => _LivreurDialogState();
}

class _LivreurDialogState extends State<_LivreurDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _whatsappCtrl;
  bool _actif = true;
  bool _isLoading = false;

  bool get _isEdit => widget.livreur != null;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.livreur?.nom ?? '');
    _whatsappCtrl = TextEditingController(text: widget.livreur?.whatsappNumber ?? '');
    _actif = widget.livreur?.actif ?? true;
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final api = context.read<ApiService>();

    ApiResponse resp;
    if (_isEdit) {
      // En mode édition : le backend PATCH /livreurs/:id ne lit QUE 'actif'.
      // Envoyer seulement ce champ pour éviter toute confusion.
      resp = await api.updateLivreur(widget.livreur!.id, {'actif': _actif});
    } else {
      // Création : nom + whatsapp_number requis
      final payload = <String, dynamic>{
        'nom': _nomCtrl.text.trim(),
        'whatsapp_number': _whatsappCtrl.text.trim(),
      };
      resp = await api.createLivreur(payload);
    }

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
    return AlertDialog(
      title: Text(_isEdit ? 'Modifier le livreur' : 'Nouveau livreur'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!_isEdit) ...[
              // ── Création : champs nom + WhatsApp requis ────────────────
              TextFormField(
                controller: _nomCtrl,
                decoration: InputDecoration(
                  labelText: 'Nom complet *',
                  prefixIcon: const Icon(Icons.person_rounded, size: 18, color: AppColors.gray400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Nom requis (2 caractères min)' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _whatsappCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro WhatsApp *',
                  hintText: '+22612345678',
                  prefixIcon: const Icon(Icons.chat_rounded, size: 18, color: AppColors.gray400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Numéro WhatsApp requis';
                  final clean = v.replaceAll(RegExp(r'[\s\-]'), '');
                  if (clean.length < 8) return 'Numéro invalide (min 8 chiffres)';
                  return null;
                },
              ),
            ] else ...[
              // ── Édition : seul le statut actif/inactif est modifiable ──
              // Le backend PATCH /livreurs/:id ne lit que le champ 'actif'.
              // Les champs nom et whatsapp_number sont ignorés silencieusement.
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: AppColors.gray500),
                    SizedBox(width: 6),
                    Expanded(child: Text(
                      'Seul le statut actif/inactif peut être modifié.\nPour changer le nom ou le numéro, supprimez et recréez le livreur.',
                      style: TextStyle(fontSize: 11, color: AppColors.gray500),
                    )),
                  ]),
                  const SizedBox(height: 8),
                  Text('Nom : ${widget.livreur!.nom}',
                      style: const TextStyle(fontSize: 13, color: AppColors.gray700, fontWeight: FontWeight.w500)),
                  if (widget.livreur!.whatsappNumber != null) ...[
                    const SizedBox(height: 2),
                    Text('WhatsApp : ${widget.livreur!.whatsappNumber}',
                        style: const TextStyle(fontSize: 13, color: AppColors.gray700)),
                  ],
                ]),
              ),
              SwitchListTile(
                title: const Text('Actif', style: TextStyle(fontSize: 14)),
                value: _actif,
                onChanged: (v) => setState(() => _actif = v),
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.success,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Enregistrer' : 'Ajouter'),
        ),
      ],
    );
  }
}
