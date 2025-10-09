import 'package:flutter/material.dart';

class Cadastro extends StatelessWidget {

    @override 
    Widget build(BuildContext context) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            // backgroundColor: Colors.blue,
            // appBar: AppBar(
            //   title: Text('Cadastro'),
            // ),
            body: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/fundo_login.png'),
                  fit: BoxFit.cover,
                )
              ),
            ),
          ),
          
        );
    }
}
