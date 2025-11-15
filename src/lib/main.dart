import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';
import 'package:src/pages/tecnico/HistoricoUso.dart';
import 'pages/admin/home_admin.dart';
import 'pages/admin/login_page.dart';
import 'pages/admin/materiais_admin_page.dart';
import 'pages/admin/instrumentos_admin_page.dart';
import 'pages/admin/historico_admin_page.dart';
import 'pages/admin/movimentacoes.dart';
import 'pages/admin/pessoas_page.dart';
import 'pages/tecnico/HomeTecnico.dart';
import 'pages/tecnico/Catalogo.dart';
import 'pages/tecnico/Calibracao.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
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


    if (!auth.initialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,


      home: auth.isAuthenticated ? auth.isAdmin ? const HomeAdminPage() : const HomeTecnico() : const LoginPage(),

      // Demais rotas nomeadas
      routes: {
        // '/': (context) => const LoginPage(),
        '/admin': (context) => const HomeAdminPage(),
        '/materiais': (context) => MateriaisAdminPage(),
        '/instrumentos': (context) => const InstrumentosAdminPage(),
        '/historico': (context) => const HistoricoAdminPage(),
        '/movimentacoes': (context) => const MovimentacoesRecentesPage(),
        '/pessoas': (context) => const PessoasPage(),
        '/tecnico': (context) => const HomeTecnico(),
        '/catalogo': (context) => const Catalogo(),
        '/historico-uso': (context) => const HistoricoUso(),
        '/calibracao': (context) => const Calibracao(),
      },
    );
  }
}