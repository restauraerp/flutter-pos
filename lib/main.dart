import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/pos_repository.dart';
import 'state/auth_controller.dart';
import 'state/pos_controller.dart';
import 'ui/login/login_page.dart';
import 'ui/login/server_setup_page.dart';
import 'ui/pos/pos_page.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PosApp());
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();

    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider(
          create: (_) => AuthController(AuthRepository(apiClient))..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (_) => PosController(PosRepository(apiClient)),
        ),
      ],
      child: MaterialApp(
        title: 'RestoraERP POS',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _AppRoot(),
      ),
    );
  }
}

/// Routes on auth state: set up the server, then log in, then sell.
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthController, AuthStatus>((c) => c.status);

    final child = switch (status) {
      AuthStatus.checking => const _SplashScreen(),
      AuthStatus.needsServer => const ServerSetupPage(),
      AuthStatus.loggedOut => const LoginPage(),
      AuthStatus.authenticated => const PosPage(),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(key: ValueKey(status), child: child),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage('assets/brand/logo-square.png'),
              width: 150,
              height: 150,
            ),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
