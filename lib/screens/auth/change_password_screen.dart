// lib/screens/auth/change_password_screen.dart
// Changement de mot de passe pour un utilisateur connecté.
// Appelle POST /api/v1/dashboard/profil/change-password via ApiService (Bearer token).
// Body : { current_password, new_password }
// Réponse : { success, message } | { error } (401 = mdp actuel incorrect)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isSubmitting = true; _error = null; });

    // Récupérer les services AVANT les gaps async (lint use_build_context_synchronously)
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();

    // Étape 1 : validation côté client via AuthService
    final validationResult = await auth.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );

    if (!validationResult.success) {
      if (!mounted) return;
      setState(() { _isSubmitting = false; _error = validationResult.message; });
      return;
    }

    // Étape 2 : appel API POST /dashboard/profil/change-password via ApiService
    // (Bearer token inclus automatiquement par ApiService._headers)
    final resp = await api.post(
      '/dashboard/profil/change-password',
      {
        'current_password': _currentCtrl.text,
        'new_password': _newCtrl.text,
      },
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resp.data?['message'] as String? ?? 'Mot de passe modifié avec succès.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } else {
      // 401 = mot de passe actuel incorrect
      // 422 = règle de format non respectée
      setState(() => _error = resp.error ?? 'Erreur lors du changement de mot de passe.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Changer le mot de passe'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icône
                Center(
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: AppColors.primary, size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Mot de passe actuel
                const Text('Mot de passe actuel', style: AppTextStyles.label),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _currentCtrl,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        size: 18, color: AppColors.gray400),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscureCurrent = !_obscureCurrent,
                      ),
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18, color: AppColors.gray400,
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Mot de passe actuel requis'
                      : null,
                ),
                const SizedBox(height: 16),

                // Nouveau mot de passe
                const Text('Nouveau mot de passe', style: AppTextStyles.label),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _newCtrl,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        size: 18, color: AppColors.gray400),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscureNew = !_obscureNew,
                      ),
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18, color: AppColors.gray400,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Nouveau mot de passe requis';
                    if (v.length < 8) return '8 caractères minimum';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirmer
                const Text('Confirmer le nouveau mot de passe',
                    style: AppTextStyles.label),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        size: 18, color: AppColors.gray400),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm,
                      ),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18, color: AppColors.gray400,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirmation requise';
                    if (v != _newCtrl.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.primary, fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2,
                            ),
                          )
                        : const Text('Enregistrer le nouveau mot de passe'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
