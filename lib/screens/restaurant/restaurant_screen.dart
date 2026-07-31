// lib/screens/restaurant/restaurant_screen.dart
// Mon Restaurant — édition Point de Vente: nom, adresse, horaires, tarifs livraison
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/livreur_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_widget.dart';

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  PointDeVenteModel? _pdv;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _adresseCtrl;
  late final TextEditingController _telephoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _tarifBaseCtrl;
  late final TextEditingController _tarifKmCtrl;
  late final TextEditingController _sloganCtrl;

  // Horaires: map jour -> {ouvert: bool, ouverture: String, fermeture: String}
  final Map<String, Map<String, dynamic>> _horaires = {};
  static const _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  static const _joursKeys = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController();
    _adresseCtrl = TextEditingController();
    _telephoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _tarifBaseCtrl = TextEditingController();
    _tarifKmCtrl = TextEditingController();
    _sloganCtrl = TextEditingController();
    // Initialiser horaires par défaut
    for (final key in _joursKeys) {
      _horaires[key] = {'ouvert': true, 'ouverture': '08:00', 'fermeture': '22:00'};
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPdv());
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _adresseCtrl.dispose(); _telephoneCtrl.dispose();
    _emailCtrl.dispose(); _tarifBaseCtrl.dispose(); _tarifKmCtrl.dispose();
    _sloganCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPdv() async {
    setState(() { _isLoading = true; _error = null; });
    final api = context.read<ApiService>();
    final resp = await api.getPdv();
    if (!mounted) return;

    if (resp.success) {
      final list = resp.data?['points_de_vente'] as List?;
      if (list != null && list.isNotEmpty) {
        final pdv = PointDeVenteModel.fromJson(list.first as Map<String, dynamic>);
        _fillForm(pdv);
        setState(() { _pdv = pdv; _isLoading = false; });
      } else {
        setState(() { _isLoading = false; });
      }
    } else {
      setState(() { _error = resp.error; _isLoading = false; });
    }
  }

  void _fillForm(PointDeVenteModel pdv) {
    _nomCtrl.text = pdv.nom;
    _adresseCtrl.text = pdv.adresse;
    _telephoneCtrl.text = pdv.telephone ?? '';
    _emailCtrl.text = pdv.email ?? '';
    _tarifBaseCtrl.text = pdv.tarifLivraisonBase?.toStringAsFixed(0) ?? '';
    _tarifKmCtrl.text = pdv.tarifParKm?.toStringAsFixed(0) ?? '';
    _sloganCtrl.text = pdv.slogan ?? '';

    if (pdv.horaires != null) {
      for (final key in _joursKeys) {
        if (pdv.horaires!.containsKey(key)) {
          final h = pdv.horaires![key] as Map<String, dynamic>?;
          if (h != null) {
            _horaires[key] = {
              'ouvert': h['ouvert'] as bool? ?? true,
              'ouverture': h['ouverture'] as String? ?? '08:00',
              'fermeture': h['fermeture'] as String? ?? '22:00',
            };
          }
        }
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pdv == null) return;

    setState(() => _isSaving = true);
    final api = context.read<ApiService>();

    final payload = {
      'nom': _nomCtrl.text.trim(),
      'adresse': _adresseCtrl.text.trim(),
      if (_telephoneCtrl.text.trim().isNotEmpty) 'telephone': _telephoneCtrl.text.trim(),
      if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
      if (_tarifBaseCtrl.text.trim().isNotEmpty) 'tarif_livraison_base': double.tryParse(_tarifBaseCtrl.text),
      if (_tarifKmCtrl.text.trim().isNotEmpty) 'tarif_par_km': double.tryParse(_tarifKmCtrl.text),
      if (_sloganCtrl.text.trim().isNotEmpty) 'slogan': _sloganCtrl.text.trim(),
      'horaires': _horaires,
    };

    final resp = await api.updatePdv(_pdv!.id, payload);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Restaurant mis à jour avec succès'),
        backgroundColor: AppColors.success,
      ));
      _loadPdv();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resp.error ?? 'Erreur de sauvegarde'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _pickTime(String jour, String type) async {
    final current = _horaires[jour]?[type] as String? ?? '08:00';
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        _horaires[jour]![type] =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon Restaurant'),
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
          if (!_isLoading && _pdv != null)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Sauvegarder', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingWidget(message: 'Chargement du restaurant…');
    if (_error != null) return AppErrorWidget(message: _error!, onRetry: _loadPdv);
    if (_pdv == null) return const Center(child: Text('Aucun point de vente configuré'));

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _buildSection('Informations générales', Icons.storefront_rounded, [
            _field(_nomCtrl, 'Nom du restaurant *', Icons.storefront_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 12),
            _field(_sloganCtrl, 'Slogan / description courte', Icons.format_quote_rounded),
            const SizedBox(height: 12),
            _field(_adresseCtrl, 'Adresse *', Icons.location_on_rounded,
              maxLines: 2,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Adresse requise' : null,
            ),
          ]),

          const SizedBox(height: 16),

          _buildSection('Contact', Icons.contact_phone_rounded, [
            _field(_telephoneCtrl, 'Téléphone', Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _field(_emailCtrl, 'Email', Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
          ]),

          const SizedBox(height: 16),

          _buildSection('Tarifs de livraison', Icons.delivery_dining_rounded, [
            Row(children: [
              Expanded(child: _field(_tarifBaseCtrl, 'Tarif de base (FCFA)', Icons.attach_money_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              )),
              const SizedBox(width: 12),
              Expanded(child: _field(_tarifKmCtrl, 'Tarif / km (FCFA)', Icons.straighten_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              )),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Tarif total = tarif de base + (distance km × tarif/km)',
              style: TextStyle(fontSize: 12, color: AppColors.gray400),
            ),
          ]),

          const SizedBox(height: 16),

          _buildSection('Horaires d\'ouverture', Icons.schedule_rounded, [
            ..._joursKeys.asMap().entries.map((entry) {
              final i = entry.key;
              final key = entry.value;
              final label = _jours[i];
              final horaire = _horaires[key]!;
              final ouvert = horaire['ouvert'] as bool;
              return _HoraireRow(
                jour: label,
                ouvert: ouvert,
                ouverture: horaire['ouverture'] as String,
                fermeture: horaire['fermeture'] as String,
                onToggle: (v) => setState(() => _horaires[key]!['ouvert'] = v),
                onPickOuverture: () => _pickTime(key, 'ouverture'),
                onPickFermeture: () => _pickTime(key, 'fermeture'),
              );
            }),
          ]),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isSaving ? 'Sauvegarde…' : 'Sauvegarder les modifications'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.gray900)),
        ]),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.gray400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

// ── Ligne horaire ──────────────────────────────────────────────────────────────
class _HoraireRow extends StatelessWidget {
  final String jour;
  final bool ouvert;
  final String ouverture;
  final String fermeture;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickOuverture;
  final VoidCallback onPickFermeture;

  const _HoraireRow({
    required this.jour,
    required this.ouvert,
    required this.ouverture,
    required this.fermeture,
    required this.onToggle,
    required this.onPickOuverture,
    required this.onPickFermeture,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 75,
          child: Text(jour, style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: ouvert ? AppColors.gray800 : AppColors.gray400,
          )),
        ),
        Switch(
          value: ouvert,
          onChanged: onToggle,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.success,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        if (ouvert) ...[
          const SizedBox(width: 8),
          _TimeButton(time: ouverture, onTap: onPickOuverture),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('–', style: TextStyle(color: AppColors.gray400)),
          ),
          _TimeButton(time: fermeture, onTap: onPickFermeture),
        ] else ...[
          const SizedBox(width: 8),
          const Text('Fermé', style: TextStyle(fontSize: 12, color: AppColors.gray400)),
        ],
      ]),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String time;
  final VoidCallback onTap;

  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Text(time, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.gray800)),
      ),
    );
  }
}
