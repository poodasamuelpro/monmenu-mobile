// lib/screens/restaurant/restaurant_screen.dart
// Mon Restaurant — édition Point de Vente: nom, adresse, horaires, tarifs livraison
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/livreur_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/app_drawer.dart';

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  // M3 — avertissement non bloquant (401/accès restreint) : le formulaire
  // reste affiché, aucune cascade de déconnexion déclenchée par cet écran.
  String? _warning;

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
    setState(() { _isLoading = true; _error = null; _warning = null; });
    final api = context.read<ApiService>();
    final auth = context.read<AuthService>();
    final resp = await api.getPdv();
    if (!mounted) return;

    if (resp.success) {
      // API retourne: { pdv: {...} | null } — objet unique, PAS une liste
      final pdvData = resp.data?['pdv'] as Map<String, dynamic>?;
      if (pdvData != null) {
        final pdv = PointDeVenteModel.fromJson(pdvData);
        _fillForm(pdv);
        setState(() { _isLoading = false; });
      } else {
        // M3 — Aucun PDV encore créé : formulaire affiché quand même,
        // pré-rempli avec le nom du tenant. Le web INSÈRE le PDV au premier
        // PATCH /dashboard/pdv, donc _save fonctionne sans PDV existant.
        if (_nomCtrl.text.trim().isEmpty) {
          _nomCtrl.text = auth.tenant?.nom ?? '';
        }
        setState(() { _isLoading = false; });
      }
    } else if (resp.isUnauthorized) {
      // M3 — 401 : PAS de cascade (l'éventuel refresh/logout est géré
      // globalement par ApiService + redirect go_router). Ici on affiche le
      // formulaire pré-rempli avec un avertissement non bloquant au lieu de
      // figer l'écran sur une erreur.
      if (_nomCtrl.text.trim().isEmpty) {
        _nomCtrl.text = auth.tenant?.nom ?? '';
      }
      setState(() {
        _warning = 'Impossible de charger le point de vente (accès restreint). '
            'Vous pouvez renseigner le formulaire et réessayer.';
        _isLoading = false;
      });
    } else {
      setState(() { _error = resp.error; _isLoading = false; });
    }
  }

  void _fillForm(PointDeVenteModel pdv) {
    _nomCtrl.text = pdv.nom;
    _adresseCtrl.text = pdv.adresse;
    // telephone, email, slogan ne sont pas des champs API PDV
    _telephoneCtrl.text = '';
    _emailCtrl.text = '';
    _tarifBaseCtrl.text = pdv.tarifLivraisonBase?.toStringAsFixed(0) ?? '';
    _tarifKmCtrl.text = pdv.tarifParKm?.toStringAsFixed(0) ?? '';
    _sloganCtrl.text = '';

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

    setState(() => _isSaving = true);
    final api = context.read<ApiService>();

    // PATCH /dashboard/pdv — champs acceptés: nom, adresse, latitude, longitude,
    // tarif_livraison_base, tarif_par_km, horaires
    // NE PAS envoyer: telephone, email, slogan (non supportés par l'API)
    final payload = <String, dynamic>{
      'nom': _nomCtrl.text.trim(),
      'adresse': _adresseCtrl.text.trim(),
      if (_tarifBaseCtrl.text.trim().isNotEmpty)
        'tarif_livraison_base': double.tryParse(_tarifBaseCtrl.text.trim()),
      if (_tarifKmCtrl.text.trim().isNotEmpty)
        'tarif_par_km': double.tryParse(_tarifKmCtrl.text.trim()),
      'horaires': _horaires,
    };

    // updatePdv sans id — l'API identifie le PDV par le JWT tenant
    final resp = await api.updatePdv(payload);
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
          // M3 — Sauvegarder toujours disponible (le web INSÈRE si PDV absent)
          if (!_isLoading && _error == null)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Sauvegarder', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingWidget(message: 'Chargement du restaurant…');
    if (_error != null) return AppErrorWidget(message: _error!, onRetry: _loadPdv);
    // M3 — plus d'écran figé quand _pdv == null : le formulaire est affiché
    // (pré-rempli avec le nom du tenant) et PATCH /dashboard/pdv crée le PDV.

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // M3 — bandeau d'avertissement non bloquant (401 / accès restreint)
          if (_warning != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_warning!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.gray800)),
                ),
                TextButton(
                  onPressed: _loadPdv,
                  child: const Text('Réessayer'),
                ),
              ]),
            ),
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
