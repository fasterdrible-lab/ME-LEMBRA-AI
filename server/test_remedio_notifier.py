"""
Testes das regras de remedio_notifier.py (TAREFA 21) — sem Firebase, sem
rede:  python -m unittest test_remedio_notifier  (dentro de server/).
"""

import unittest
from datetime import date, datetime, timedelta

import remedio_notifier as rn

TZ = rn.TZ
# Segunda, 12/10/2026, 10h em São Paulo.
AGORA = datetime(2026, 10, 12, 10, 0, tzinfo=TZ)


def lembrete(hora=8, minuto=0, dia=date(2026, 10, 12), repeat="unico", tipo="Remedio", **extra):
    r = {
        "id": "r1",
        "title": "Losartana",
        "type": tipo,
        "repeat": repeat,
        "dateTime": datetime(dia.year, dia.month, dia.day, hora, minuto, tzinfo=TZ),
        "confirmed": False,
        "confirmedDates": [],
    }
    r.update(extra)
    return r


class RegrasTest(unittest.TestCase):
    def test_atrasado_mais_de_1_hora_avisa(self):
        saida = rn.remedios_para_avisar([lembrete(8)], AGORA)
        self.assertEqual(len(saida), 1)
        self.assertEqual(saida[0][1], datetime(2026, 10, 12, 8, 0, tzinfo=TZ))

    def test_menos_de_1_hora_ainda_nao(self):
        self.assertEqual(rn.remedios_para_avisar([lembrete(9, 30)], AGORA), [])

    def test_muito_tarde_nao_avisa_mais(self):
        # 8h + 1h + 3h de janela = 12h: às 13h não avisa (serviço parado, etc.)
        self.assertEqual(rn.remedios_para_avisar([lembrete(8)], AGORA.replace(hour=13)), [])

    def test_confirmado_hoje_nao_avisa(self):
        r = lembrete(8, repeat="diario", dia=date(2026, 10, 1), confirmedDates=["2026-10-12"])
        self.assertEqual(rn.remedios_para_avisar([r], AGORA), [])

    def test_diario_confirmado_ontem_avisa_hoje(self):
        # O `confirmed` antigo é um só pra sempre — num diário não vale.
        r = lembrete(8, repeat="diario", dia=date(2026, 10, 1), confirmed=True, confirmedDates=["2026-10-11"])
        self.assertEqual(len(rn.remedios_para_avisar([r], AGORA)), 1)

    def test_unico_com_confirmed_antigo_nao_avisa(self):
        self.assertEqual(rn.remedios_para_avisar([lembrete(8, confirmed=True)], AGORA), [])

    def test_semanal_so_no_mesmo_dia_da_semana(self):
        segunda = lembrete(8, repeat="semanal", dia=date(2026, 10, 5))  # segunda passada
        terca = lembrete(8, repeat="semanal", dia=date(2026, 10, 6))
        self.assertEqual(len(rn.remedios_para_avisar([segunda], AGORA)), 1)
        self.assertEqual(rn.remedios_para_avisar([terca], AGORA), [])

    def test_unico_de_outro_dia_nao_avisa(self):
        self.assertEqual(rn.remedios_para_avisar([lembrete(8, dia=date(2026, 10, 11))], AGORA), [])

    def test_agua_e_outros_tipos_ficam_de_fora(self):
        self.assertEqual(rn.remedios_para_avisar([lembrete(8, tipo="Tomar"), lembrete(8, tipo="Consulta")], AGORA), [])

    def test_criado_depois_do_horario_nao_e_atraso(self):
        r = lembrete(8, createdAt=datetime(2026, 10, 12, 9, 30, tzinfo=TZ))
        self.assertEqual(rn.remedios_para_avisar([r], AGORA), [])

    def test_horario_gravado_em_utc_vira_hora_de_sao_paulo(self):
        # 11h UTC = 8h em São Paulo (UTC-3).
        from datetime import timezone

        r = lembrete(8)
        r["dateTime"] = datetime(2026, 10, 12, 11, 0, tzinfo=timezone.utc)
        self.assertEqual(rn.remedios_para_avisar([r], AGORA)[0][1].hour, 8)


class TextoEEstadoTest(unittest.TestCase):
    def test_texto_do_aviso(self):
        texto = rn.texto_aviso("Maria", "Losartana", datetime(2026, 10, 12, 8, 0, tzinfo=TZ))
        self.assertIn('Maria ainda não confirmou o remédio "Losartana" das 08:00', texto)

    def test_texto_sem_nome_nem_titulo(self):
        texto = rn.texto_aviso("", "", datetime(2026, 10, 12, 8, 0, tzinfo=TZ))
        self.assertIn("Seu familiar ainda não confirmou o remédio das 08:00", texto)

    def test_podar_avisados_guarda_so_os_ultimos_dias(self):
        avisados = {
            rn.chave_aviso("u", "r", date(2026, 10, 12)): "x",
            rn.chave_aviso("u", "r", date(2026, 10, 9)): "x",
            rn.chave_aviso("u", "r", date(2026, 10, 1)): "x",
        }
        podado = rn.podar_avisados(avisados, date(2026, 10, 12))
        self.assertEqual(sorted(podado), ["u|r|2026-10-09", "u|r|2026-10-12"])

    def test_chave_dia_igual_ao_app(self):
        self.assertEqual(rn.chave_dia(date(2026, 1, 5)), "2026-01-05")


if __name__ == "__main__":
    unittest.main()
