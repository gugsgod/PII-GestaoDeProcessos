import 'package:flutter/material.dart';

// import das paginas pra rodar:
import 'src/pages/login_page.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      
      home: LoginPage(), 
    );
  }
}