import 'package:flutter/material.dart';

class PaginaInicial extends StatelessWidget {

    @override
    Widget build(BuildContext context) {
        return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
                appBar: AppBar(
                    backgroundColor: Colors.white,
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset('assets/Sao_Paulo_Metro_Logo.svg'),
                    ),
                ),
            )
        );
    }
}

