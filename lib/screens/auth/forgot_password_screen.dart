// lib/screens/auth/forgot_password_screen.dart
// 3 étapes: 1) Saisir email → 2) OTP → 3) Nouveau mot de passe
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 1; // 1: email, 2: OTP, 3: new password
  final _emailCtrl = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _error;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  // ── Étape 1: envoyer OTP ──────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Entrez votre adresse email.');
      return;
    }
    setState(() { _isSubmitting = true; _error = null; });

    final auth = context.read<AuthService>();
    final result = await auth.sendPasswordResetOtp(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      setState(() => _step = 2);
      _showSnack('Code envoyé à ${_emailCtrl.text.trim()}', success: true);
    } else {
      setState(() => _error = result.message);
    }
  }

  // ── Étape 2: vérifier OTP (passer à l'étape 3) ───────────────────────────
  void _verifyOtp() {
    if (_otpValue.length < 6) {
      setState(() => _error = 'Entrez le code à 6 chiffres.');
      return;
    }
    setState(() { _step = 3; _error = null; });
  }

  // ── Étape 3: réinitialiser mot de passe ───────────────────────────────────
  Future<void> _resetPassword() async {
    final newPwd = _newPasswordCtrl.text;
    final confirmPwd = _confirmPasswordCtrl.text;

    if (newPwd.length < 8) {
      setState(() => _error = 'Mot de passe: 8 caractères minimum.');
      return;
    }
    if (newPwd != confirmPwd) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }

    setState(() { _isSubmitting = true; _error = null; });

    final auth = context.read<AuthService>();
    final result = await auth.resetPasswordWithOtp(
      email: _emailCtrl.text.trim(),
      otp: _otpValue,
      newPassword: newPwd,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      _showSnack('Mot de passe mis à jour !', success: true);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.go('/login');
    } else {
      setState(() => _error = result.message);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.gray700),
          onPressed: () {
            if (_step > 1) {
              setState(() { _step--; _error = null; });
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Progression ─────────────────────────────────────────
                  _StepIndicator(currentStep: _step),
                  const SizedBox(height: 32),

                  // ── Carte ──────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gray100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20, offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _step == 1
                          ? _buildStep1()
                          : _step == 2
                              ? _buildStep2()
                              : _buildStep3(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Étape 1: Email ────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset_rounded,
            color: AppColors.primary, size: 40),
        const SizedBox(height: 16),
        const Text('Mot de passe oublié ?', style: AppTextStyles.h2),
        const SizedBox(height: 6),
        const Text(
          'Entrez votre email pour recevoir un code de vérification.',
          style: TextStyle(color: AppColors.gray400, fontSize: 13),
        ),
        const SizedBox(height: 24),
        const Text('Email', style: AppTextStyles.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'contact@monrestaurant.com',
            prefixIcon: Icon(Icons.email_outlined,
                size: 18, color: AppColors.gray400),
          ),
        ),
        if (_error != null) _buildError(),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _sendOtp,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2,
                    ),
                  )
                : const Text('Envoyer le code'),
          ),
        ),
      ],
    );
  }

  // ── Étape 2: OTP ──────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined,
            color: AppColors.primary, size: 40),
        const SizedBox(height: 16),
        const Text('Vérification', style: AppTextStyles.h2),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: const TextStyle(color: AppColors.gray400, fontSize: 13),
            children: [
              const TextSpan(text: 'Code envoyé à '),
              TextSpan(
                text: _emailCtrl.text,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _OtpBox(
            controller: _otpControllers[i],
            focusNode: _otpFocusNodes[i],
            onChanged: (v) {
              if (v.isNotEmpty && i < 5) {
                _otpFocusNodes[i + 1].requestFocus();
              }
              if (v.isEmpty && i > 0) {
                _otpFocusNodes[i - 1].requestFocus();
              }
              setState(() {});
            },
          )),
        ),

        if (_error != null) _buildError(),
        const SizedBox(height: 20),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _otpValue.length == 6 ? _verifyOtp : null,
            child: const Text('Vérifier le code'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isSubmitting ? null : _sendOtp,
          child: const Text('Renvoyer le code'),
        ),
      ],
    );
  }

  // ── Étape 3: Nouveau mot de passe ─────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.key_rounded, color: AppColors.primary, size: 40),
        const SizedBox(height: 16),
        const Text('Nouveau mot de passe', style: AppTextStyles.h2),
        const SizedBox(height: 6),
        const Text(
          'Choisissez un mot de passe sécurisé (8 caractères minimum).',
          style: TextStyle(color: AppColors.gray400, fontSize: 13),
        ),
        const SizedBox(height: 24),

        const Text('Nouveau mot de passe', style: AppTextStyles.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: _newPasswordCtrl,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 18, color: AppColors.gray400),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
              icon: Icon(
                _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18, color: AppColors.gray400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        const Text('Confirmer le mot de passe', style: AppTextStyles.label),
        const SizedBox(height: 6),
        TextFormField(
          controller: _confirmPasswordCtrl,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                size: 18, color: AppColors.gray400),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(
                _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18, color: AppColors.gray400,
              ),
            ),
          ),
        ),

        if (_error != null) _buildError(),
        const SizedBox(height: 20),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _resetPassword,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2,
                    ),
                  )
                : const Text('Réinitialiser le mot de passe'),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(1, currentStep >= 1, 'Email'),
        _line(currentStep >= 2),
        _dot(2, currentStep >= 2, 'Code OTP'),
        _line(currentStep >= 3),
        _dot(3, currentStep >= 3, 'Nouveau MDP'),
      ],
    );
  }

  Widget _dot(int step, bool active, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.gray200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  color: active ? Colors.white : AppColors.gray400,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: active ? AppColors.primary : AppColors.gray400,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: active ? AppColors.primary : AppColors.gray200,
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44, height: 52,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: AppColors.gray900,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.gray200, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: true,
          fillColor: controller.text.isNotEmpty
              ? AppColors.primaryLight
              : AppColors.surface,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
