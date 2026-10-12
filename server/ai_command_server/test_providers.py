"""
Testes de providers.py (TAREFA 32) — rodam sem rede, sem Groq e sem
Firebase:  python -m unittest test_providers  (dentro desta pasta).
"""

import json
import unittest

import httpx

import providers


class Falso(providers.AiProvider):
    def __init__(self, nome, resposta=None, erro=None):
        self.nome = nome
        self.resposta = resposta
        self.erro = erro
        self.chamadas = 0

    def send_message(self, mensagens):
        self.chamadas += 1
        if self.erro:
            raise self.erro
        return self.resposta


MSGS = [{"role": "user", "content": "oi"}]


class InterpretarTest(unittest.TestCase):
    def test_primeiro_responde_e_os_outros_nem_sao_chamados(self):
        a, b = Falso("a", {"acao": "responder"}), Falso("b", {"acao": "x"})
        raw, quem = providers.interpretar([a, b], MSGS)
        self.assertEqual(raw, {"acao": "responder"})
        self.assertIs(quem, a)
        self.assertEqual(b.chamadas, 0)

    def test_falha_passa_para_o_proximo(self):
        a = Falso("groq", erro=RuntimeError("429"))
        b = Falso("deepseek", {"acao": "responder"})
        raw, quem = providers.interpretar([a, b], MSGS)
        self.assertIs(quem, b)

    def test_resposta_fora_do_contrato_tambem_passa_para_o_proximo(self):
        def validar(raw):
            if raw.get("acao") != "responder":
                raise ValueError("ação inválida")
            return raw

        a, b = Falso("a", {"acao": "inventada"}), Falso("b", {"acao": "responder"})
        _, quem = providers.interpretar([a, b], MSGS, validar=validar)
        self.assertIs(quem, b)

    def test_todos_falham_devolve_none(self):
        self.assertIsNone(providers.interpretar([Falso("a", erro=ValueError())], MSGS))

    def test_orcamento_esgotado_nao_comeca_outra_tentativa(self):
        tempos = iter([0.0, 0.0, 5.0])  # início, antes de a, antes de b
        a = Falso("a", erro=RuntimeError("lento"))
        b = Falso("b", {"acao": "responder"})
        resultado = providers.interpretar([a, b], MSGS, orcamento_segundos=4.0, relogio=lambda: next(tempos))
        self.assertIsNone(resultado)
        self.assertEqual(b.chamadas, 0)


class AmbienteTest(unittest.TestCase):
    def test_sem_deepseek_key_so_groq(self):
        lista = providers.provedores_do_ambiente(
            {"GROQ_API_KEY": "g", "GROQ_MODEL": "m1", "GROQ_MODELOS_RESERVA": "m2, m1 ,m3"}
        )
        self.assertEqual([p.nome for p in lista], ["groq:m1", "groq:m2", "groq:m3"])

    def test_deepseek_entra_por_ultimo(self):
        lista = providers.provedores_do_ambiente(
            {"GROQ_API_KEY": "g", "GROQ_MODEL": "m1", "GROQ_MODELOS_RESERVA": "", "DEEPSEEK_API_KEY": "d"}
        )
        self.assertEqual([p.nome for p in lista], ["groq:m1", "deepseek:deepseek-chat"])

    def test_so_deepseek(self):
        lista = providers.provedores_do_ambiente({"DEEPSEEK_API_KEY": "d", "DEEPSEEK_MODEL": "outro"})
        self.assertEqual([p.nome for p in lista], ["deepseek:outro"])

    def test_nenhuma_chave_falha_ao_subir(self):
        with self.assertRaises(RuntimeError):
            providers.provedores_do_ambiente({})


class DeepSeekTest(unittest.TestCase):
    def _provedor(self, handler):
        return providers.DeepSeekProvider("chave-teste", transport=httpx.MockTransport(handler))

    def test_monta_a_requisicao_e_le_o_json(self):
        recebido = {}

        def handler(req):
            recebido["url"] = str(req.url)
            recebido["auth"] = req.headers["Authorization"]
            recebido["corpo"] = json.loads(req.content)
            return httpx.Response(
                200, json={"choices": [{"message": {"content": '{"acao": "responder", "fala": "Oi!"}'}}]}
            )

        raw = self._provedor(handler).send_message(MSGS)
        self.assertEqual(raw, {"acao": "responder", "fala": "Oi!"})
        self.assertEqual(recebido["url"], "https://api.deepseek.com/chat/completions")
        self.assertEqual(recebido["auth"], "Bearer chave-teste")
        self.assertEqual(recebido["corpo"]["model"], "deepseek-chat")
        self.assertEqual(recebido["corpo"]["response_format"], {"type": "json_object"})
        self.assertEqual(recebido["corpo"]["messages"], MSGS)

    def test_erro_http_lanca(self):
        p = self._provedor(lambda req: httpx.Response(402, json={"error": "saldo insuficiente"}))
        with self.assertRaises(httpx.HTTPStatusError):
            p.send_message(MSGS)

    def test_conteudo_vazio_lanca(self):
        p = self._provedor(lambda req: httpx.Response(200, json={"choices": [{"message": {"content": ""}}]}))
        with self.assertRaises(ValueError):
            p.send_message(MSGS)


if __name__ == "__main__":
    unittest.main()
