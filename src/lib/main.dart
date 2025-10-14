import 'package:flutter/material.dart';
import 'src/pages/home_admin.dart'; 
import 'src/pages/login_page.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/admin': (context) => const HomeAdminPage(),
      },
    );
  }
}