import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/create_reminder_screen.dart';

void main() {
  Widget buildSubject() => const MaterialApp(home: CreateReminderScreen());

  group('CreateReminderScreen — estrutura', () {
    testWidgets('exibe campos de titulo e descricao', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('exibe labels de secao', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Tipo'), findsOneWidget);
      expect(find.text('Titulo'), findsOneWidget);
      expect(find.text('Descricao (opcional)'), findsOneWidget);
      expect(find.text('Data e Hora'), findsOneWidget);
    });

    testWidgets('exibe chips de tipo de lembrete', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Remedio'), findsAtLeastNWidgets(1));
      expect(find.text('Consulta'), findsAtLeastNWidgets(1));
      expect(find.text('Aniversario'), findsAtLeastNWidgets(1));
      expect(find.text('Mercado'), findsAtLeastNWidgets(1));
      expect(find.text('Reuniao'), findsAtLeastNWidgets(1));
      expect(find.text('Tomar'), findsAtLeastNWidgets(1));
    });

    testWidgets('exibe chips de repeticao', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Repetição'), findsOneWidget);
      expect(find.text('Único'), findsOneWidget);
      expect(find.text('Diário'), findsOneWidget);
      expect(find.text('Semanal'), findsOneWidget);
    });

    testWidgets('exibe botao salvar', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('SALVAR LEMBRETE'), findsOneWidget);
    });
  });

  group('CreateReminderScreen — interacao', () {
    testWidgets('titulo vazio nao navega', (tester) async {
      await tester.pumpWidget(buildSubject());
      final salvar = find.text('SALVAR LEMBRETE');
      await tester.ensureVisible(salvar);
      await tester.tap(salvar);
      await tester.pump();
      // Sem titulo, _salvar() retorna sem navegar — tela continua visivel
      expect(find.byType(CreateReminderScreen), findsOneWidget);
    });

    testWidgets('campo titulo aceita entrada de texto', (tester) async {
      await tester.pumpWidget(buildSubject());
      final campos = find.byType(TextField);
      await tester.enterText(campos.first, 'Losartana 50mg');
      expect(find.text('Losartana 50mg'), findsOneWidget);
    });

    testWidgets('selecionando chip Consulta muda tipo', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Consulta').first);
      await tester.pump();
      // Chip Consulta ainda visivel apos selecao
      expect(find.text('Consulta'), findsAtLeastNWidgets(1));
    });

    testWidgets('selecionando chip Diario muda repeticao', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Diário'));
      await tester.pump();
      expect(find.text('Diário'), findsOneWidget);
    });
  });
}
