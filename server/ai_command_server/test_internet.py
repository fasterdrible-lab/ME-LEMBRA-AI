"""
Testes da escolha de manchetes (sessão 26) — sem rede:
  python -m unittest test_internet  (dentro desta pasta).
"""

import unittest

import internet


class EscolherManchetesTest(unittest.TestCase):
    # As 6 manchetes reais de 13/10/2026 que a IA leu em lista.
    FEED = [
        "Mercado eleva previsão da inflação para 5,22% em 2026",
        "Nunes Marques suspende novos posts e seguidores no Exército do Lula",
        "Polícia de SP prende três suspeitos de explorar bets",
        'Redução de desastres: especialistas defendem "cultura da prevenção"',
        "Nunes Marques convoca campanhas de Lula e Flávio para reunião no TSE",
        "Governo cria programa nacional para bloquear celulares em presídios",
    ]

    def test_no_maximo_tres_e_leves_primeiro(self):
        escolhidas = internet.escolher_manchetes(self.FEED)
        self.assertEqual(len(escolhidas), 3)
        self.assertEqual(escolhidas[0], self.FEED[0])
        self.assertEqual(escolhidas[1], self.FEED[3])
        self.assertNotIn(self.FEED[1], escolhidas)  # política
        self.assertNotIn(self.FEED[2], escolhidas)  # polícia/crime
        self.assertNotIn(self.FEED[4], escolhidas)  # campanha/TSE

    def test_sem_leves_suficientes_completa_com_as_outras(self):
        pesadas = [self.FEED[1], self.FEED[2]]
        self.assertEqual(internet.escolher_manchetes(pesadas), pesadas)

    def test_lista_vazia(self):
        self.assertEqual(internet.escolher_manchetes([]), [])


if __name__ == "__main__":
    unittest.main()
