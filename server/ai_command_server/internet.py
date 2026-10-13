"""Informações da internet para a MOLLY: previsão do tempo e notícias.

Só é consultado quando a frase do usuário pede (palavras-chave abaixo) —
nunca em toda chamada, pra não gastar tempo nem o limite de tokens/min
da Groq. Tudo com timeout curto (o app desiste da chamada inteira em 6 s)
e cache em memória; qualquer falha devolve None e a MOLLY diz que não
conseguiu ver agora, em vez de inventar.

Fontes (gratuitas, sem cadastro):
- Tempo: Open-Meteo (https://open-meteo.com) — previsão + geocoding.
- Notícias: Agência Brasil (EBC), feed RSS público de últimas notícias.
"""

from __future__ import annotations

import logging
import re
import time
import unicodedata
import xml.etree.ElementTree as ET

import httpx

log = logging.getLogger(__name__)

TIMEOUT = httpx.Timeout(2.5)
CACHE_TEMPO_S = 10 * 60
CACHE_NOTICIAS_S = 15 * 60
FEED_NOTICIAS = "https://agenciabrasil.ebc.com.br/rss/ultimasnoticias/feed.xml"

_cache: dict[str, tuple[float, object]] = {}


def _sem_acento(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFD", s.lower()) if unicodedata.category(c) != "Mn")


# ---------------------------------------------------------------- detecção

_RE_TEMPO = re.compile(
    r"\b(previsao|vai chover|chover|chuva|chovendo|temperatura|calor|frio|graus|"
    r"como (esta|ta|vai estar|fica) o tempo|o tempo (hoje|amanha|la fora|agora)|tempo (hoje|amanha)|"
    r"clima|guarda.?chuva|sol hoje|esquentar|esfriar)\b"
)
_RE_NOTICIAS = re.compile(r"\b(noticia|noticias|manchete|manchetes|jornal|aconteceu (hoje|no brasil|no mundo)|novidades do dia)\b")


def precisa_tempo(texto: str) -> bool:
    return bool(_RE_TEMPO.search(_sem_acento(texto)))


def precisa_noticias(texto: str) -> bool:
    return bool(_RE_NOTICIAS.search(_sem_acento(texto)))


# ---------------------------------------------------------------- tempo

_WMO = {
    0: "céu limpo", 1: "quase sem nuvens", 2: "parcialmente nublado", 3: "nublado",
    45: "neblina", 48: "neblina", 51: "garoa fraca", 53: "garoa", 55: "garoa forte",
    56: "garoa gelada", 57: "garoa gelada", 61: "chuva fraca", 63: "chuva", 65: "chuva forte",
    66: "chuva gelada", 67: "chuva gelada", 71: "neve fraca", 73: "neve", 75: "neve forte",
    77: "neve", 80: "pancadas de chuva fracas", 81: "pancadas de chuva", 82: "pancadas de chuva fortes",
    85: "neve", 86: "neve", 95: "trovoadas", 96: "trovoadas com granizo", 99: "trovoadas com granizo",
}

_RE_PREPOSICAO = re.compile(r"\b(?:em|no|na|de|do|da|pra|para)\s+", re.IGNORECASE)
_NAO_E_CIDADE = {"tempo", "chuva", "frio", "calor", "sol", "hoje", "casa", "rua", "manha", "tarde",
                 "noite", "previsao", "temperatura", "clima", "fim", "semana", "dia"}


def _cidade_na_frase(texto: str) -> str | None:
    """'vai chover em Campinas amanhã?' -> 'Campinas'.

    Tira palavras de tempo/data e testa, da esquerda pra direita, o que vem
    depois de cada 'em/no/na/de/do...' até o fim da frase, pulando trechos
    que começam com palavra que não é cidade ('do tempo em Campinas' →
    pula 'tempo em Campinas', fica 'Campinas'). Da esquerda primeiro pra
    manter 'Rio de Janeiro' inteiro."""
    t = re.sub(r"[?!.,]", " ", texto).strip()
    t = re.sub(r"\b(hoje|amanh[ãa]|agora|depois|essa semana|esta semana|de manh[ãa]|[àa] tarde|[àa] noite)\b", " ", t, flags=re.I)
    t = re.sub(r"\s+", " ", t).strip()
    for m in _RE_PREPOSICAO.finditer(t):
        candidato = t[m.end():].strip()
        if len(candidato) < 3 or len(candidato.split()) > 4:
            continue
        if _sem_acento(candidato.split()[0]) in _NAO_E_CIDADE:
            continue
        return candidato
    return None


def _get_json(url: str, params: dict) -> dict | None:
    try:
        r = httpx.get(url, params=params, timeout=TIMEOUT)
        r.raise_for_status()
        return r.json()
    except Exception as exc:  # noqa: BLE001 — qualquer falha vira "não consegui ver"
        log.warning("internet: falha em %s: %s", url, exc)
        return None


def _geocodificar(cidade: str) -> tuple[float, float, str] | None:
    chave = f"geo:{_sem_acento(cidade)}"
    if chave in _cache:
        return _cache[chave][1]  # type: ignore[return-value]
    dados = _get_json(
        "https://geocoding-api.open-meteo.com/v1/search",
        {"name": cidade, "count": 1, "language": "pt", "country_code": "BR"},
    )
    res = (dados or {}).get("results") or []
    if not res:
        return None
    r0 = res[0]
    valor = (float(r0["latitude"]), float(r0["longitude"]), str(r0.get("name") or cidade))
    _cache[chave] = (time.time(), valor)
    return valor


def buscar_tempo(texto: str, latitude: float | None, longitude: float | None) -> str | None:
    """Resumo em texto da previsão (agora, hoje, amanhã), ou None.
    Cidade dita na frase tem prioridade sobre a localização do aparelho."""
    nome_local = "na sua região"
    cidade = _cidade_na_frase(texto)
    if cidade:
        geo = _geocodificar(cidade)
        if geo:
            latitude, longitude, nome = geo
            nome_local = f"em {nome}"
    if latitude is None or longitude is None:
        return None

    lat, lon = round(float(latitude), 2), round(float(longitude), 2)
    chave = f"tempo:{lat},{lon}"
    agora = time.time()
    if chave in _cache and agora - _cache[chave][0] < CACHE_TEMPO_S:
        dados = _cache[chave][1]
    else:
        dados = _get_json(
            "https://api.open-meteo.com/v1/forecast",
            {
                "latitude": lat,
                "longitude": lon,
                "current": "temperature_2m,weather_code",
                "daily": "temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code",
                "timezone": "America/Sao_Paulo",
                "forecast_days": 2,
            },
        )
        if dados:
            _cache[chave] = (agora, dados)
    if not dados:
        return None

    try:
        cur = dados["current"]
        d = dados["daily"]
        linhas = [
            f"Previsão do tempo {nome_local} (Open-Meteo):",
            f"- Agora: {round(cur['temperature_2m'])} graus, {_WMO.get(cur['weather_code'], 'tempo variável')}.",
        ]
        for i, dia in enumerate(["Hoje", "Amanhã"][: len(d["time"])]):
            linhas.append(
                f"- {dia}: mínima {round(d['temperature_2m_min'][i])}, máxima {round(d['temperature_2m_max'][i])} graus, "
                f"{_WMO.get(d['weather_code'][i], 'tempo variável')}, "
                f"chance de chuva {d['precipitation_probability_max'][i] or 0}%."
            )
        return "\n".join(linhas)
    except (KeyError, IndexError, TypeError) as exc:
        log.warning("internet: resposta inesperada do Open-Meteo: %s", exc)
        return None


# ---------------------------------------------------------------- notícias


# Sessão 26: o modelo ignorava "2 ou 3 manchetes, evite crimes e política"
# e lia 6 em lista (mais de meio minuto falado). A escolha agora é feita
# aqui: no máximo 3, deixando por último o que for crime/tragédia/disputa
# política — só entra se não houver manchetes leves suficientes.
_RE_NOTICIA_PESADA = re.compile(
    r"\b(pres[oa]s?|prende|prendem|pris[aã]o|pol[ií]cia|crime|assassin\w*|homic[ií]dio|morte|morre\w*|mort[oa]s?|"
    r"tiroteio|trag[eé]dia|acidente|golpe|fraude|investiga\w*|lula|bolsonaro|stf|tse|stj|campanha|elei[cç]\w*|"
    r"candidat\w*|partido|deputad\w*|senador\w*|ministr\w*|congresso|c[aâ]mara|pf|ministério público)\b",
    re.IGNORECASE,
)


def escolher_manchetes(titulos: list[str], quantidade: int = 3) -> list[str]:
    """Até [quantidade] manchetes, leves primeiro, mantendo a ordem do feed."""
    leves = [t for t in titulos if not _RE_NOTICIA_PESADA.search(t)]
    pesadas = [t for t in titulos if _RE_NOTICIA_PESADA.search(t)]
    return (leves + pesadas)[:quantidade]


def buscar_noticias(maximo: int = 15) -> str | None:
    """Até 3 manchetes da Agência Brasil (só os títulos), leves primeiro, ou None."""
    agora = time.time()
    if "noticias" in _cache and agora - _cache["noticias"][0] < CACHE_NOTICIAS_S:
        return _cache["noticias"][1]  # type: ignore[return-value]
    try:
        r = httpx.get(FEED_NOTICIAS, timeout=TIMEOUT, follow_redirects=True, headers={"User-Agent": "MeLembraAi/1.0"})
        r.raise_for_status()
        raiz = ET.fromstring(r.content)
        titulos = [
            (item.findtext("title") or "").strip()
            for item in raiz.iter("item")
        ]
        titulos = escolher_manchetes([t for t in titulos if t][:maximo])
    except Exception as exc:  # noqa: BLE001
        log.warning("internet: falha ao ler notícias: %s", exc)
        return None
    if not titulos:
        return None
    texto = "Últimas manchetes (Agência Brasil):\n" + "\n".join(f"- {t}" for t in titulos)
    _cache["noticias"] = (agora, texto)
    return texto
