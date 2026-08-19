// lib/screens/commandes/commande_detail_screen.dart
// Détail commande + validation + WhatsApp client + WhatsApp livreur conditionnel
//
// LOGIQUE IDENTIQUE À L'APP WEB (api-dashboard.ts) :
//   - updateStatut PATCH /dashboard/commandes/:id/statut
//   - Si statut == 'en_preparation' && livreur_id fourni → API génère lien_whatsapp_livreur
//   - Le lien livreur est retourné dans la réponse JSON → app ouvre WhatsApp directement
//   - Notification CLIENT via wa.me/ avec message pré-rempli au changement de statut
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/commande_model.dart';
import '../../models/livreur_model.dart';
import '../../providers/commandes_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/statut_badge.dart';
import '../../widgets/nav_buttons.dart';

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

  // Livreurs disponibles (chargés pour sélection lors de en_preparation)
  List<LivreurModel> _livreurs = [];
  bool _livreursCharged = false;

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

  // ── Charger les livreurs disponibles ─────────────────────────────────────
  Future<void> _chargerLivreurs() async {
    if (_livreursCharged) return;
    try {
      final api = context.read<ApiService>();
      final resp = await api.getLivreurs();
      if (!mounted) return;
      if (resp.success) {
        final list = (resp.data?['livreurs'] as List? ?? [])
            .map((j) => LivreurModel.fromJson(j as Map<String, dynamic>))
            .where((l) => l.actif)
            .toList();
        setState(() {
          _livreurs = list;
          _livreursCharged = true;
        });
      }
    } catch (_) {
      // non-bloquant
    }
  }

  // ── WhatsApp vers CLIENT ─────────────────────────────────────────────────
  // Message pré-rempli selon le statut de la commande
  Future<void> _notifierClientWhatsApp(String telephone, String statut) async {
    final c = _commande!;
    final id = c.id.substring(0, 8).toUpperCase();

    String message;
    switch (statut) {
      case 'confirmee':
        message = '✅ Bonjour ${c.nomClient ?? ''} ! Votre commande #$id a été confirmée. '
            'Nous préparons votre commande dans les plus brefs délais.';
        break;
      case 'en_preparation':
        message = '👨‍🍳 Bonjour ${c.nomClient ?? ''} ! Votre commande #$id est en cours de préparation.';
        break;
      case 'en_livraison':
        message = '🛵 Bonjour ${c.nomClient ?? ''} ! Votre commande #$id est en cours de livraison. '
            'Notre livreur sera bientôt chez vous !';
        break;
      case 'livree':
        message = '🎉 Bonjour ${c.nomClient ?? ''} ! Votre commande #$id a été livrée. '
            'Merci pour votre confiance. Bonne dégustation !';
        break;
      case 'annulee':
        message = '❌ Bonjour ${c.nomClient ?? ''} ! Votre commande #$id a été annulée. '
            'Nous nous excusons pour la gêne occasionnée.';
        break;
      default:
        message = 'Votre commande #$id : mise à jour du statut.';
    }

    await _openWhatsApp(telephone, message);
  }

  // ── Ouvrir WhatsApp avec un message ─────────────────────────────────────
  Future<void> _openWhatsApp(String telephone, [String? message]) async {
    final clean = telephone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final numero = clean.startsWith('+') ? clean.substring(1) : clean;
    final encoded = message != null ? Uri.encodeComponent(message) : '';
    final uri = message != null
        ? Uri.parse('https://wa.me/$numero?text=$encoded')
        : Uri.parse('https://wa.me/$numero');

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

  // ── Mise à jour statut ──────────────────────────────────────────────────
  // Si statut == 'en_preparation', demande le livreur → API génère lien WA livreur
  Future<void> _updateStatut(String newStatut) async {
    if (_commande == null) return;

    String? livreurIdChoisi;

    // Si on passe en "en_preparation" et qu'il y a des livreurs → sélection
    if (newStatut == 'en_preparation') {
      await _chargerLivreurs();
      if (!mounted) return;

      if (_livreurs.isNotEmpty) {
        livreurIdChoisi = await _showLivreurPicker();
        if (!mounted) return;
        // Si l'utilisateur a annulé sans choisir de livreur, on continue sans
      }
    }

    setState(() => _isUpdating = true);

    final provider = context.read<CommandesProvider>();
    final result = await provider.updateStatut(
      _commande!.id,
      newStatut,
      livreurId: livreurIdChoisi,
    );

    if (!mounted) return;
    setState(() => _isUpdating = false);

    if (result.success) {
      // Recharger la commande mise à jour
      final updated = provider.getById(_commande!.id);
      if (updated != null) setState(() => _commande = updated);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statut mis à jour : ${CommandeStatut.label(newStatut)}'),
          backgroundColor: AppColors.success,
        ),
      );

      // ── Notifier CLIENT via WhatsApp ──────────────────────────────────
      final tel = _commande?.telephoneClient;
      if (tel != null && tel.isNotEmpty) {
        _notifierClientWhatsApp(tel, newStatut);
      }

      // ── Ouvrir WhatsApp LIVREUR si lien retourné ───────────────────────
      // Ce lien est généré par l'API uniquement si livreur_id + statut == en_preparation
      if (result.lienWhatsappLivreur != null) {
        final lien = result.lienWhatsappLivreur!;
        if (mounted) {
          // Montrer confirmation avant d'ouvrir
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ouverture WhatsApp livreur…'),
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'Ouvrir',
                onPressed: () async {
                  final uri = Uri.parse(lien);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          );
          // Ouvrir automatiquement après 1 seconde
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            final uri = Uri.parse(lien);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        }
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Erreur de mise à jour'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Dialog sélection livreur ────────────────────────────────────────────
  Future<String?> _showLivreurPicker() async {
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assigner un livreur'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sélectionnez un livreur pour cette commande.\n'
                'Il recevra une notification WhatsApp automatiquement.',
                style: TextStyle(fontSize: 13, color: AppColors.gray500),
              ),
              const SizedBox(height: 12),
              ..._livreurs.map((l) => ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delivery_dining_rounded, color: AppColors.primary, size: 18),
                ),
                title: Text(l.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: l.whatsappNumber != null
                    ? Text(l.whatsappNumber!, style: const TextStyle(fontSize: 12))
                    : null,
                onTap: () => Navigator.pop(ctx, l.id),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Sans livreur'),
          ),
        ],
      ),
    );
  }

  Future<void> _annuler() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la commande'),
        content: const Text('Êtes-vous sûr de vouloir annuler cette commande ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
        leadingWidth: 104,
        leading: const NavButtons(),
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
          _Card(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${c.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 16,
                      fontWeight: FontWeight.w700, color: AppColors.gray700,
                    ),
                  ),
                  StatutBadge(statut: c.statut),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${c.dateCommande} à ${c.heureCommande}',
                style: const TextStyle(fontSize: 12, color: AppColors.gray400),
              ),
            ],
          )),

          const SizedBox(height: 12),

          // ── Client ───────────────────────────────────────────────────────
          _Section(
            title: 'Client',
            child: Column(
              children: [
                _InfoRow(icon: Icons.person_outline_rounded, label: 'Nom', value: c.nomClient ?? 'Anonyme'),
                if (c.telephoneClient != null) ...[
                  _InfoRow(icon: Icons.phone_outlined, label: 'Téléphone', value: c.telephoneClient!),
                  const SizedBox(height: 8),
                  // Bouton WhatsApp client (sans message prérempli — simple contact)
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
                if (c.adresseLivraison != null)
                  _InfoRow(icon: Icons.location_on_outlined, label: 'Adresse', value: c.adresseLivraison!),
                if (c.notesClient != null && c.notesClient!.isNotEmpty)
                  _InfoRow(icon: Icons.notes_rounded, label: 'Notes', value: c.notesClient!),
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
                        child: Center(child: Text(
                          '${item.quantite}x',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gray600),
                        )),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        item.nomProduit ?? 'Produit',
                        style: const TextStyle(fontSize: 13, color: AppColors.gray800),
                      )),
                      Text(
                        '${item.sousTotal.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),

          const SizedBox(height: 12),

          // ── Montant total ─────────────────────────────────────────────────
          _Card(child: Column(
            children: [
              if (c.fraisLivraison != null && c.fraisLivraison! > 0)
                _TotalRow(label: 'Frais de livraison', value: '${c.fraisLivraison!.toStringAsFixed(0)} FCFA'),
              // reductionAppliquee supprimé du modèle (non retourné par l'API)
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.gray900)),
                  Text(c.montantFormate, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
            ],
          )),

          const SizedBox(height: 24),

          // ── Actions ───────────────────────────────────────────────────────
          if (!_isUpdating) ...[
            // Bouton statut suivant
            if (c.nextStatut != null) ...[
              // Si on passe en en_preparation, montrer un texte explicatif livreur
              if (c.nextStatut == 'en_preparation' && _livreurs.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(child: Text(
                      'Vous pourrez assigner un livreur lors de cette étape',
                      style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                    )),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatut(c.nextStatut!),
                  icon: Icon(CommandeStatut.icon(c.nextStatut!), size: 18),
                  label: Text(c.nextStatutLabel ?? ''),
                ),
              ),
            ],

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
            const Center(child: Column(
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 8),
                Text('Mise à jour…', style: TextStyle(color: AppColors.gray400, fontSize: 12)),
              ],
            )),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Widgets helper ────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray100),
      ),
      child: child,
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
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gray700)),
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
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.gray400)),
              Text(value, style: const TextStyle(fontSize: 13, color: AppColors.gray700)),
            ],
          )),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  const _TotalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.gray500)),
          Text(value, style: const TextStyle(
            fontSize: 13,
            color: AppColors.gray600,
            fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }
}
