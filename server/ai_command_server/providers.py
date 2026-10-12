"""
providers.py — provedores de IA da Molly (TAREFA 32 do prompt mestre).

O app nunca fala com um provedor direto: chama esta VPS, que tenta os
provedores em ordem até um responder. As chaves ficam só aqui (no .env da
VPS), nunca no APK — por isso a abstração mora no backend e trocar ou
acrescentar um provedor não exige APK novo.

Ordem: modelos da Groq (grátis, mas com limite de tokens/min POR MODELO)
e, só se TODOS falharem, o DeepSeek (pago, barato) — se DEEPSEEK_API_KEY
estiver no .env. Sem a chave, o DeepSeek simplesmente não entra na lista.

Do `AiProvider` sugerido no prompt mestre fica só `send_message`:
- `executeTool`: ferramentas rodam NO APP (MollyRiskPolicy decide se
  confirma), nunca aqui — o backend só devolve a ação em JSON.
- `streamResponse`: o app hoje recebe a resposta inteira; streaming só faz
  sentido com voz em tempo real (TAREFA 33).
"""

from __future__ import annotations

import json
import logging
import os
import time
from abc import ABC, abstractmethod
from typing import Any

import httpx

log = logging.getLogger(__name__)


class AiProvider(ABC):
    """Um modelo de um provedor. `send_message` devolve o JSON da resposta
    já decodificado, ou lança exceção (o chamador passa para o próximo)."""

    nome: str

    @abstractmethod
    def send_message(self, mensagens: list[dict]) -> dict[str, Any]: ...


def _decodificar(conteudo: str | None, nome: str) -> dict[str, Any]:
    if not conteudo or not conteudo.strip():
        raise ValueError(f"{nome}: resposta vazia")
    raw = json.loads(conteudo)
    if not isinstance(raw, dict):
        raise ValueError(f"{nome}: JSON não é objeto")
    return raw


class GroqProvider(AiProvider):
    _cliente = None  # um só cliente para todos os modelos

    def __init__(self, modelo: str, api_key: str):
        self.modelo = modelo
        self.nome = f"groq:{modelo}"
        self._api_key = api_key

    def _client(self):
        if GroqProvider._cliente is None:
            from groq import Groq  # só na VPS; testes locais não precisam

            # Sem novas tentativas: num 429 a Groq pede 13-22 s de espera e o
            # app desiste em 8 s — melhor passar pro próximo provedor.
            GroqProvider._cliente = Groq(api_key=self._api_key, max_retries=0, timeout=3.0)
        return GroqProvider._cliente

    def _max_tokens(self) -> int:
        """gpt-oss: 1024 (o raciocínio conta). qwen3 na Groq tem limite de
        1.000 tokens de SAÍDA por minuto — pedir 1024 dá 429 sempre."""
        return 400 if "qwen" in self.modelo else 1024

    def _raciocinio(self) -> dict:
        """Raciocínio mínimo: gpt-oss aceita "low"; qwen3 aceita "none"."""
        if "gpt-oss" in self.modelo:
            return {"reasoning_effort": "low"}
        if "qwen3" in self.modelo:
            return {"reasoning_effort": "none"}
        return {}

    def send_message(self, mensagens: list[dict]) -> dict[str, Any]:
        completion = self._client().chat.completions.create(
            model=self.modelo,
            response_format={"type": "json_object"},
            max_tokens=self._max_tokens(),
            temperature=0.2,
            messages=mensagens,
            extra_body=self._raciocinio(),
        )
        return _decodificar(completion.choices[0].message.content, self.nome)


class DeepSeekProvider(AiProvider):
    """API compatível com a da OpenAI (`/chat/completions`). Modo JSON exige a
    palavra "JSON" no prompt — o SYSTEM_PROMPT já tem."""

    def __init__(
        self,
        api_key: str,
        modelo: str = "deepseek-chat",
        base_url: str = "https://api.deepseek.com",
        timeout: float = 3.5,
        transport: httpx.BaseTransport | None = None,  # testes
    ):
        self.modelo = modelo
        self.nome = f"deepseek:{modelo}"
        self._http = httpx.Client(
            base_url=base_url,
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=timeout,
            transport=transport,
        )

    def send_message(self, mensagens: list[dict]) -> dict[str, Any]:
        resp = self._http.post(
            "/chat/completions",
            json={
                "model": self.modelo,
                "messages": mensagens,
                "response_format": {"type": "json_object"},
                "max_tokens": 400,  # sem raciocínio: só a resposta curta
                "temperature": 0.2,
            },
        )
        resp.raise_for_status()
        return _decodificar(resp.json()["choices"][0]["message"]["content"], self.nome)


def provedores_do_ambiente(env: dict[str, str] | None = None) -> list[AiProvider]:
    """Lista na ordem de tentativa, a partir do .env:
    GROQ_API_KEY + GROQ_MODEL + GROQ_MODELOS_RESERVA, depois (opcional)
    DEEPSEEK_API_KEY + DEEPSEEK_MODEL + DEEPSEEK_BASE_URL."""
    env = os.environ if env is None else env
    lista: list[AiProvider] = []

    groq_key = env.get("GROQ_API_KEY", "").strip()
    if groq_key:
        principal = env.get("GROQ_MODEL", "openai/gpt-oss-20b")
        reservas = env.get("GROQ_MODELOS_RESERVA", "openai/gpt-oss-120b,qwen/qwen3.8-27b")
        modelos = [principal] + [m.strip() for m in reservas.split(",") if m.strip() and m.strip() != principal]
        lista += [GroqProvider(m, groq_key) for m in modelos]

    deepseek_key = env.get("DEEPSEEK_API_KEY", "").strip()
    if deepseek_key:
        lista.append(
            DeepSeekProvider(
                deepseek_key,
                modelo=env.get("DEEPSEEK_MODEL", "deepseek-chat"),
                base_url=env.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com"),
            )
        )

    if not lista:
        raise RuntimeError("Nenhum provedor de IA configurado (GROQ_API_KEY e/ou DEEPSEEK_API_KEY no .env)")
    return lista


def interpretar(
    provedores: list[AiProvider],
    mensagens: list[dict],
    validar=lambda raw: raw,
    orcamento_segundos: float = 4.0,
    relogio=time.monotonic,
):
    """Tenta cada provedor em ordem; devolve (validar(json), provedor que
    respondeu) ou None se todos falharem. [validar] roda dentro da
    tentativa: resposta fora do contrato também passa para o próximo.
    Depois de [orcamento_segundos] não começa outra tentativa (o app
    desiste em 8 s)."""
    inicio = relogio()
    for provedor in provedores:
        if relogio() - inicio > orcamento_segundos:
            log.error("Orçamento de tempo esgotado antes de %s", provedor.nome)
            break
        try:
            return validar(provedor.send_message(mensagens)), provedor
        except Exception as exc:  # noqa: BLE001 — 429, 404, JSON inválido, rede...
            log.error("Falha com %s: %s", provedor.nome, exc)
    return None
