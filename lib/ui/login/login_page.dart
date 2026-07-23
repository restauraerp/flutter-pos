import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/config/server_config.dart';
import '../../state/auth_controller.dart';
import '../theme.dart';
import 'server_setup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
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
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                              ? 'Email is required'
                              : null,
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
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 12),
                        const _ServerRow(),
                        const BuildBadge(),
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

/// Shows the server this terminal talks to, with a way to change it — the
/// post-logout server management entry point.
class _ServerRow extends StatelessWidget {
  const _ServerRow();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();

    return Row(
      children: [
        const Icon(Icons.dns_outlined, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            ServerConfig.baseUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textMuted,
            ),
          ),
        ),
        if (!AppConfig.lockServerUrl)
          TextButton(
            onPressed: auth.busy ? null : auth.requestServerChange,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Change', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
