import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'create_reminder_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  List<String> lembretes = [];

  @override
  void initState() {
    super.initState();
    _carregarLembretes();
  }

  Future<void> _carregarLembretes() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList('lembretes') ?? [];
    setState(() {
      lembretes = lista;
    });
  }

  Future<void> _salvarLembretes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('lembretes', lembretes);
  }

  void _irCriar() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateReminderScreen(),
      ),
    );

    if (resultado != null && resultado is String) {
      setState(() {
        lembretes.add(resultado);
      });
      _salvarLembretes();
    }
  }

  void _remover(int index) {
    setState(() {
      lembretes.removeAt(index);
    });
    _salvarLembretes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C63FF),
        onPressed: _irCriar,
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [
          // HEADER BONITO
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFFA855F7)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bom dia 👋',
                    style: TextStyle(color: Colors.white70)),
                SizedBox(height: 6),
                Text(
                  'ME LEMBRA AÍ',
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // LISTA
          Expanded(
            child: lembretes.isEmpty
                ? const Center(
                    child: Text('Nenhum lembrete ainda 🚀'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: lembretes.length,
                    itemBuilder: (context, index) {
                      final item = lembretes[index];

                      return Dismissible(
                        key: Key(item + index.toString()),
                        onDismissed: (_) => _remover(index),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(Icons.delete,
                              color: Colors.white),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 10,
                                color: Colors.black.withOpacity(0.06),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0EEFF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.notifications,
                                    color: Color(0xFF6C63FF)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}