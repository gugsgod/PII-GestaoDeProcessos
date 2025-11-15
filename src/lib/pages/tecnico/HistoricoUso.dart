import 'dart:io';

import 'package:flutter/material.dart';
import 'package:src/pages/admin/animated_network_background.dart';
import 'package:src/widgets/tecnico/home_tecnico/tecnico_drawer.dart';

class HistoricoUso extends StatefulWidget {
  const HistoricoUso({Key? key}) : super(key: key);

  State<HistoricoUso> createState() => HistoricoUsoState();
}

class HistoricoUsoState extends State<HistoricoUso> {
  
  
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF080023);
    const Color secondaryColor = Color.fromARGB(255, 0, 14, 92);

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: secondaryColor,
        elevation: 0,
        flexibleSpace: const AnimatedNetworkBackground(numberOfParticles: 30, maxDistance: 50.0),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Image.asset('assets/images/logo_metroSP.png', height: 50,),
          ),
        ],
      ),
      drawer: const TecnicoDrawer(primaryColor: primaryColor, secondaryColor: secondaryColor),
      body: SingleChildScrollView(
        // controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Títulos
              const Text(
                'Histórico de Uso',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Histórico completo de retiradas e devoluções',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),

              // --- Barra de Pesquisa (IMPLEMENTADA) ---
              
            ],
          ),
        ),
      ),
    );
  }
}