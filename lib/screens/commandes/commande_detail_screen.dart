// lib/screens/commandes/commande_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/commande_model.dart';
import '../../providers/commandes_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/statut_badge.dart';

class CommandeDetailScreen extends StatefulWidget {
  final String commandeId;
  const CommandeDetailScreen({super.key, required this.commandeId});

  @override
  State<CommandeDetailScreen> createState() => _CommandeDetailScreenState();
}

class _CommandeDetailScreenState extends State<CommandeDetailScreen> {
  CommandeModel? _commande;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCommande();
  }

  Future<void> _loadCommande() async {
    // Chercher d'abord en cache local
    final provider = context.read<CommandesProvider>();
    final cached = provider.getById(widget.commandeId);

    if (cached != null) {
      setState(() {
        _commande = cached;
        _isLoading = false;
      });
      return;
    }

    // Sinon charger depuis l'API
    final api = context.read<ApiService>();
    final resp = await api.get('/dashboard/commandes/${widget.commandeId}');

    if (!mounted) return;
    if (resp.success && resp.data != null) {
      setState(() {
        _commande = CommandeModel.fromJson(
            resp.data!['commande'] as Map<String, dynamic>? ?? resp.data!);
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = resp.error ?? 'Commande introuvable';
        _isLoading = false;
      });
    }
  }

  Future<void> _openWhatsApp(String telephone) async {
    // Nettoyer le numéro: garder uniquement chiffres et +
    final clean = telephone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final numero = clean.startsWith('+') ? clean.substring(1) : clean;
    final uri = Uri.parse('https://wa.me/$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible d\'ouvrir WhatsApp'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _updateStatut(String newStatut) async {
    if (_commande == null) return;
    setState(() => _isUpdating = true);

    final provider = context.read<CommandesProvider>();
    final success = await provider.updateStatut(_commande!.id, newStatut);

    if (!mounted) return;
    setState(() => _isUpdating = false);

    if (success) {
      // Recharger la commande mise à jour
      final updated = provider.getById(_commande!.id);
      if (updated != null) setState(() => _commande = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statut mis à jour : ${CommandeStatut.label(newStatut)}'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Erreur de mise à jour'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _annuler() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la commande'),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler cette commande ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirm == true) await _updateStatut('annulee');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Détail commande'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? Center(child: Text(_error!))
              : _commande == null
                  ? const Center(child: Text('Commande introuvable'))
                  : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final c = _commande!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gray100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#${c.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: AppColors.gray700,
                      ),
                    ),
                    StatutBadge(statut: c.statut),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${c.dateCommande} à ${c.heureCommande}',
                  style: const TextStyle(
                    fontSize: 12, color: AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Client ───────────────────────────────────────────────────────
          _Section(
            title: 'Client',
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Nom',
                  value: c.nomClient ?? 'Anonyme',
                ),
                if (c.telephoneClient != null) ...[
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Téléphone',
                    value: c.telephoneClient!,
                  ),
                  const SizedBox(height: 4),
                  // ── Bouton WhatsApp client ────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openWhatsApp(c.telephoneClient!),
                      icon: const Icon(Icons.chat_rounded, size: 16),
                      label: const Text('Contacter sur WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF25D366),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                if (c.adresseLivraison != null)
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Adresse',
                    value: c.adresseLivraison!,
                  ),
                if (c.notesClient != null && c.notesClient!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.notes_rounded,
                    label: 'Notes',
                    value: c.notesClient!,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Articles ─────────────────────────────────────────────────────
          if (c.items.isNotEmpty)
            _Section(
              title: 'Articles (${c.items.length})',
              child: Column(
                children: c.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.gray100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${item.quantite}x',
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: AppColors.gray600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.nomProduit ?? 'Produit',
                          style: const TextStyle(
                            fontSize: 13, color: AppColors.gray800,
                          ),
                        ),
                      ),
                      Text(
                        '${item.sousTotal.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.gray700,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),

          const SizedBox(height: 12),

          // ── Montant total ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gray100),
            ),
            child: Column(
              children: [
                if (c.fraisLivraison != null && c.fraisLivraison! > 0)
                  _TotalRow(
                    label: 'Frais de livraison',
                    value: '${c.fraisLivraison!.toStringAsFixed(0)} FCFA',
                  ),
                if (c.reductionAppliquee != null && c.reductionAppliquee! > 0)
                  _TotalRow(
                    label: 'Réduction',
                    value: '- ${c.reductionAppliquee!.toStringAsFixed(0)} FCFA',
                    isDiscount: true,
                  ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: AppColors.gray900,
                      ),
                    ),
                    Text(
                      c.montantFormate,
                      style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Actions ───────────────────────────────────────────────────────
          if (!_isUpdating) ...[
            if (c.nextStatut != null)
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatut(c.nextStatut!),
                  icon: Icon(CommandeStatut.icon(c.nextStatut!), size: 18),
                  label: Text(c.nextStatutLabel ?? ''),
                ),
              ),
            if (c.statut != 'livree' && c.statut != 'annulee') ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: _annuler,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Annuler la commande'),
                ),
              ),
            ],
          ] else
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.gray700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.gray400),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(
                  fontSize: 11, color: AppColors.gray400,
                )),
                Text(value, style: const TextStyle(
                  fontSize: 13, color: AppColors.gray700,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDiscount;
  const _TotalRow({required this.label, required this.value, this.isDiscount = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(
            fontSize: 13, color: AppColors.gray500,
          )),
          Text(value, style: TextStyle(
            fontSize: 13,
            color: isDiscount ? AppColors.success : AppColors.gray600,
            fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }
}
