// lib/widgets/commande_card.dart
import 'package:flutter/material.dart';
import '../models/commande_model.dart';
import '../theme/app_theme.dart';
import 'statut_badge.dart';

class CommandeCard extends StatelessWidget {
  final CommandeModel commande;
  final VoidCallback? onTap;
  final VoidCallback? onNextStatut;

  const CommandeCard({
    super.key,
    required this.commande,
    this.onTap,
    this.onNextStatut,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: numéro + statut + heure ────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${commande.id.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gray600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatutBadge(statut: commande.statut, small: true),
                      ],
                    ),
                  ),
                  Text(
                    commande.heureCommande,
                    style: const TextStyle(
                      fontSize: 12, color: AppColors.gray400,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Client info ────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: AppColors.gray400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      commande.nomClient ?? 'Client anonyme',
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.gray800,
                      ),
                    ),
                  ),
                ],
              ),

              if (commande.telephoneClient != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 14, color: AppColors.gray400),
                    const SizedBox(width: 6),
                    Text(
                      commande.telephoneClient!,
                      style: const TextStyle(
                        fontSize: 12, color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ],

              if (commande.items.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${commande.items.length} article${commande.items.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12, color: AppColors.gray500,
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // ── Footer: montant + action ───────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    commande.montantFormate,
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: AppColors.gray900,
                    ),
                  ),
                  if (commande.nextStatut != null && onNextStatut != null)
                    GestureDetector(
                      onTap: onNextStatut,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_forward_rounded,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              commande.nextStatutLabel ?? '',
                              style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
