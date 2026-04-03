import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'services/profile_service.dart';

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({super.key});

  void _entrar(BuildContext context, String perfil) async {
    await ProfileService.saveProfile(perfil);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(), // ✅ SEM CONST
      ),
    );
  }

  Widget _card(
      BuildContext context, String titulo, String imagem) {
    return GestureDetector(
      onTap: () => _entrar(context, titulo),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Image.asset(imagem),
            ),
            const SizedBox(height: 10),
            Text(
              titulo,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text("Quem vai usar?",
                  style:
                      TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Escolha o perfil"),

              const SizedBox(height: 30),

              Expanded(
                child: ListView(
                  children: [
                    _card(context, "Vovô / Vovó",
                        "assets/images/avos.png"),
                    _card(context, "Adulto",
                        "assets/images/adultos.png"),
                    _card(context, "Criança",
                        "assets/images/crianca.png"),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}