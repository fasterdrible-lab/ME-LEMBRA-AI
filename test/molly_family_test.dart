import 'package:flutter_test/flutter_test.dart';
import 'package:me_lembra_ai/features/molly/services/molly_family_intent.dart';
import 'package:me_lembra_ai/features/molly/services/offline_intent_service.dart';
import 'package:me_lembra_ai/features/molly/tools/family_tool.dart';
import 'package:me_lembra_ai/models/family_member.dart';

/// TAREFA 20 do prompt mestre (integração com família). 100% puro Dart.
void main() {
  const ana = FamilyMember(uid: '1', nome: 'Ana Paula', perfil: 'Família', papel: 'cuidador');
  const pedro = FamilyMember(uid: '2', nome: 'Pedro', perfil: 'Família', papel: 'cuidador');
  const lia = FamilyMember(uid: '3', nome: 'Lia', perfil: 'Filhos', papel: 'monitorado');

  group('MollyFamilyIntent.classificar — frases literais da TAREFA 20', () {
    test('"avisa a Ana que estou bem"', () {
      final c = MollyFamilyIntent.classificar('Molly, avisa a Ana que estou bem.')!;
      expect(c.tipo, MollyFamilyIntentTipo.avisar);
      expect(c.destino, 'Ana');
      expect(c.mensagem, 'Estou bem.');
    });

    test('"manda mensagem para meu filho" (sem conteudo)', () {
      final c = MollyFamilyIntent.classificar('Molly, manda mensagem para meu filho.')!;
      expect(c.tipo, MollyFamilyIntentTipo.mensagem);
      expect(c.destino, 'meu filho');
      expect(c.mensagem, isNull);
    });

    test('"quem esta acompanhando meus lembretes?"', () {
      expect(
        MollyFamilyIntent.classificar('Molly, quem está acompanhando meus lembretes?')!.tipo,
        MollyFamilyIntentTipo.quemAcompanha,
      );
    });
  });

  group('MollyFamilyIntent.classificar — variacoes', () {
    test('mensagem com conteudo na mesma frase', () {
      final c = MollyFamilyIntent.classificar('manda uma mensagem pro Pedro dizendo que cheguei bem')!;
      expect(c.tipo, MollyFamilyIntentTipo.mensagem);
      expect(c.destino, 'Pedro');
      expect(c.mensagem, 'Cheguei bem.');
    });

    test('"fala pra minha filha que..." e "quem cuida de mim"', () {
      final c = MollyFamilyIntent.classificar('fala pra minha filha que já almocei')!;
      expect(c.destino, 'minha filha');
      expect(c.mensagem, 'Já almocei.');
      expect(MollyFamilyIntent.classificar('quem cuida de mim')!.tipo, MollyFamilyIntentTipo.quemAcompanha);
      expect(MollyFamilyIntent.classificar('quem é minha família')!.tipo, MollyFamilyIntentTipo.listarFamilia);
    });

    test('nao confunde com outras intencoes', () {
      const frases = [
        'me lembra de avisar a Ana amanhã às 8',
        'avisa a Ana às 5 que eu chego tarde',
        'fala o que eu tenho hoje',
        'me avisa quando for a hora do remédio',
        'quem vê a novela comigo',
        'Me lembra do remédio às oito.',
        'liga para minha filha',
      ];
      for (final f in frases) {
        expect(MollyFamilyIntent.classificar(f), isNull, reason: f);
      }
    });
  });

  group('OfflineIntentService — prioridade', () {
    test('"quem acompanha meus lembretes" e familia, nao "ouvir meus lembretes"', () {
      expect(
        OfflineIntentService.classificar('quem está acompanhando meus lembretes'),
        OfflineIntent.familia,
      );
      expect(OfflineIntentService.classificar('quais são meus lembretes de hoje'), OfflineIntent.meusLembretes);
    });

    test('emergencia e SOCORRO continuam na frente da mensagem', () {
      expect(
        OfflineIntentService.classificar('avisa minha filha que estou passando mal'),
        OfflineIntent.possivelEmergencia,
      );
      expect(OfflineIntentService.classificar('avisa a Ana que socorro'), OfflineIntent.socorro);
      expect(OfflineIntentService.classificar('liga para minha filha'), OfflineIntent.ligarPara);
    });
  });

  group('FamilyTool.resolverFamiliar', () {
    test('nome parcial e nome exato', () {
      expect(FamilyTool.resolverFamiliar([ana, pedro], 'Ana').membro, ana);
      expect(FamilyTool.resolverFamiliar([ana, pedro], 'a Ana').membro, ana);
      expect(FamilyTool.resolverFamiliar([ana, pedro], 'pedro').membro, pedro);
    });

    test('"minha filha" com um familiar so: usa ele', () {
      expect(FamilyTool.resolverFamiliar([ana], 'minha filha').membro, ana);
    });

    test('"minha filha" com varios: pede o nome, sem adivinhar', () {
      final r = FamilyTool.resolverFamiliar([ana, pedro], 'minha filha');
      expect(r.membro, isNull);
      expect(r.falaProblema, contains('mais de um familiar'));
      expect(r.falaProblema, contains('Ana Paula e Pedro'));
    });

    test('"minha filha Ana" usa o nome', () {
      expect(FamilyTool.resolverFamiliar([ana, pedro], 'minha filha Ana').membro, ana);
    });

    test('nao achado lista quem existe; nenhum vinculado avisa', () {
      expect(
        FamilyTool.resolverFamiliar([ana, pedro], 'Carlos').falaProblema,
        'Não encontrei um familiar chamado Carlos. Seus familiares são: Ana Paula e Pedro.',
      );
      expect(FamilyTool.resolverFamiliar(const [], 'Ana').falaProblema, contains('nenhum familiar vinculado'));
    });
  });

  group('FamilyTool.falaQuemAcompanha', () {
    test('so cuidadores contam', () {
      expect(FamilyTool.falaQuemAcompanha([ana, lia]), 'Ana Paula acompanha seus lembretes.');
      expect(FamilyTool.falaQuemAcompanha([ana, pedro, lia]), 'Ana Paula e Pedro acompanham seus lembretes.');
    });

    test('ninguem acompanhando explica como vincular', () {
      expect(FamilyTool.falaQuemAcompanha([lia]), contains('código de convite'));
    });
  });

  test('formatarMensagem', () {
    expect(MollyFamilyIntent.formatarMensagem('estou bem'), 'Estou bem.');
    expect(MollyFamilyIntent.formatarMensagem('vem jantar hoje?'), 'Vem jantar hoje?');
  });
}
