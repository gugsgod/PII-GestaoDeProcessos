import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';
import 'pages/home_admin.dart';
import 'pages/login_page.dart';
import 'pages/materiais_admin_page.dart';
import 'pages/instrumentos_admin_page.dart';
import 'pages/historico_admin_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthStore()..init(), // carrega token uma vez
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    // Enquanto inicializa o store (evita tocar no app antes do tempo)
    if (!auth.initialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // 👇 Decida aqui qual tela é a "home" com base no auth
      home: auth.isAuthenticated ? const HomeAdminPage() : const LoginPage(),

      // Demais rotas nomeadas
      routes: {
        // '/': (context) => const LoginPage(),
        '/admin': (context) => const HomeAdminPage(),
        '/materiais': (context) => MateriaisAdminPage(),
        '/instrumentos': (context) => const InstrumentosAdminPage(),
        '/historico': (context) => const HistoricoAdminPage(),
      },
    );
  }
}
