import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/config/server_config.dart';
import '../../state/auth_controller.dart';
import '../theme.dart';

/// First-run screen: point this terminal at a RestoraERP server.
///
/// Also reachable from the login screen so the URL can be changed after logout.
class ServerSetupPage extends StatefulWidget {
  const ServerSetupPage({super.key});

  @override
  State<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends State<ServerSetupPage> {
  late final TextEditingController _controller = TextEditingController(
    text: ServerConfig.savedUrl ?? AppConfig.defaultBaseUrl,
  );

  bool _testing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _testing = true;
      _error = null;
    });

    final input = _controller.text;
    final problem = await ApiClient.probe(input);
    if (!mounted) return;

    if (problem != null) {
      setState(() {
        _testing = false;
        _error = problem;
      });
      return;
    }

    await context.read<AuthController>().saveServer(input);
  }

  @override
  Widget build(BuildContext context) {
    final canCancel = ServerConfig.isConfigured;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _BrandHeader(
                        subtitle: 'Terminal Setup',
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Server address',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _controller,
                        autocorrect: false,
                        enabled: !_testing && !AppConfig.lockServerUrl,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _testing ? null : _save(),
                        decoration: const InputDecoration(
                          hintText: 'https://your-restaurant.com',
                          prefixIcon: Icon(Icons.dns_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the host only — /api/v1 is added automatically. '
                        'On the Android emulator use 10.0.2.2 to reach a server '
                        'running on your computer.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _ErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _testing ? null : _save,
                        child: _testing
                            ? const _ButtonSpinner(label: 'Testing connection…')
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.link, size: 17),
                                  SizedBox(width: 8),
                                  Text('Connect'),
                                ],
                              ),
                      ),
                      if (canCancel) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _testing
                              ? null
                              : () => context
                                    .read<AuthController>()
                                    .cancelServerChange(),
                          child: const Text('Cancel'),
                        ),
                      ],
                      const SizedBox(height: 4),
                      const _BuildBadge(),
                    ],
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.subtitle});

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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

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
          const Icon(
            Icons.error_outline,
            size: 17,
            color: AppColors.danger,
          ),
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

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({required this.label});

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
/// mistaken for a live one.
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

/// Reused by the login page.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) => _BrandHeader(subtitle: subtitle);
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => _ErrorBanner(message: message);
}

class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => _ButtonSpinner(label: label);
}

class BuildBadge extends StatelessWidget {
  const BuildBadge({super.key});

  @override
  Widget build(BuildContext context) => const _BuildBadge();
}
