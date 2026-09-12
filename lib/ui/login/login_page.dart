import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/config/tenant_config.dart';
import '../../state/auth_controller.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _tenantController = TextEditingController(
    text: TenantConfig.savedTenant ?? '',
  );
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _tenantController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    await context.read<AuthController>().login(
      _emailController.text.trim(),
      _passwordController.text,
      _tenantController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const BrandHeader(subtitle: 'POS Terminal Login'),
                        const SizedBox(height: 22),

                        if (auth.error != null) ...[
                          ErrorBanner(message: auth.error!),
                          const SizedBox(height: 16),
                        ],

                        const _FieldLabel('Restaurant code'),
                        TextFormField(
                          controller: _tenantController,
                          autocorrect: false,
                          enableSuggestions: false,
                          enabled: !auth.busy,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.none,
                          onChanged: (_) => auth.clearError(),
                          decoration: const InputDecoration(
                            hintText: 'your-restaurant',
                            prefixIcon: Icon(Icons.storefront_outlined, size: 18),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Restaurant code is required'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        const _FieldLabel('Email address'),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enabled: !auth.busy,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => auth.clearError(),
                          decoration: const InputDecoration(
                            hintText: 'manager@example.com',
                            prefixIcon: Icon(Icons.mail_outline, size: 18),
                          ),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Email is required';
                            if (!value.contains('@') ||
                                !value.contains('.')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        const _FieldLabel('Password'),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscure,
                          enabled: !auth.busy,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => auth.clearError(),
                          onFieldSubmitted: (_) => auth.busy ? null : _submit(),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              tooltip: _obscure
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Password is required'
                              : null,
                        ),
                        const SizedBox(height: 20),

                        FilledButton(
                          onPressed: auth.busy ? null : _submit,
                          child: auth.busy
                              ? const ButtonSpinner(label: 'Signing in…')
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, size: 17),
                                    SizedBox(width: 8),
                                    Text('Log in'),
                                  ],
                                ),
                        ),

                        const SizedBox(height: 18),
                        const _BuildBadge(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The square logo already carries the RESTAURA ERP wordmark, so no
        // separate title is drawn here.
        Image.asset(
          'assets/brand/logo-square.png',
          width: 132,
          height: 132,
          fit: BoxFit.contain,
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        border: Border.all(color: AppColors.dangerBorder),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 17, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.danger,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.primaryContent),
          ),
        ),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

/// Shows which environment this build points at, so a staging terminal is never
/// mistaken for a live one. Nothing is shown on a production build.
class _BuildBadge extends StatelessWidget {
  const _BuildBadge();

  @override
  Widget build(BuildContext context) {
    if (AppConfig.isProduction) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.warningBg,
            border: Border.all(color: AppColors.warningBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${AppConfig.environment.toUpperCase()} BUILD',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.warningText,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
