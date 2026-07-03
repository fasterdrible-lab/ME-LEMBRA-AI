"""
app.py — Backend do comando de voz por IA do Me Lembra Aí.

Recebe a frase transcrita pelo app, verifica o login do usuário (ID token do
Firebase Auth) e chama a API da Groq para interpretar o comando, devolvendo
uma ação estruturada em JSON. O app usa isso quando a frase não bate em
nenhuma regra local rápida (ver `_processarComando` em elderly_screen.dart);
se este serviço estiver fora do ar, o app cai sozinho no roteador local.

O SOS nunca passa por aqui — continua 100% local no app, por segurança.

Pré-requisitos:
  python3 -m venv venv && venv/bin/pip install -r requirements.txt
    (Ubuntu 23.04+/Debian 12+ bloqueia "pip install" fora de venv — PEP 668)
  Arquivo serviceAccountKey.json na mesma pasta (baixar no Firebase
    Console → Configurações do projeto → Contas de serviço → Gerar nova
    chave privada)
  Arquivo .env na mesma pasta com: GROQ_API_KEY=sua_chave_aqui

Execução manual:
  python3 app.py

Execução como serviço systemd:
  Copiar melembra-ai-backend.service para /etc/systemd/system/ e rodar:
    systemctl enable melembra-ai-backend
    systemctl start melembra-ai-backend
"""

import json
import logging
import os
import sys
from dataclasses import dataclass, field
from typing import Any

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials
from flask import Flask, jsonify, request
from flask_limiter import Limiter
from groq import Groq

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("ai_command_server.log"),
    ],
)
log = logging.getLogger(__name__)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_ACCOUNT_PATH = os.path.join(SCRIPT_DIR, "serviceAccountKey.json")
GROQ_MODEL = os.environ.get("GROQ_MODEL", "llama-3.3-70b-versatile")

ACOES_VALIDAS = {
    "criar_lembrete",
    "ouvir_lembretes",
    "adicionar_item_lista",
    "consultar_alertas",
    "responder",
}

TIPOS_VALIDOS = {
    "Remedio", "Consulta", "Aniversario", "Mercado", "Reuniao", "Tomar", "Compras",
}

RECORRENCIAS_VALIDAS = {"unico", "diario", "semanal"}

SYSTEM_PROMPT = """Você interpreta comandos de voz em português de um app de \
lembretes para uma pessoa idosa. Responda SEMPRE em JSON puro (sem texto \
fora do JSON), seguindo exatamente este formato:

{
  "acao": "criar_lembrete" | "ouvir_lembretes" | "adicionar_item_lista" | "consultar_alertas" | "responder",
  "titulo": "string, só para criar_lembrete",
  "tipo": "Remedio" | "Consulta" | "Aniversario" | "Mercado" | "Reuniao" | "Tomar" | "Compras",
  "data_hora": "ISO 8601 completo, ex: 2026-07-03T08:00:00, só para criar_lembrete",
  "recorrencia": "unico" | "diario" | "semanal",
  "itens": ["string", "..."],
  "fala": "resposta curta e natural em português para falar de volta ao usuário"
}

Regras:
- "criar_lembrete": quando a pessoa pede para lembrar de algo em um horário/data. Use o "agora" fornecido no contexto para calcular data_hora relativa (ex: "amanhã", "daqui a uma hora").
- "ouvir_lembretes": quando pede para ouvir/saber os lembretes do dia.
- "adicionar_item_lista": quando pede para adicionar item(ns) na lista de compras/mercado. Preencha "itens".
- "consultar_alertas": quando pergunta sobre alertas de SOS enviados.
- "responder": para qualquer outra coisa (conversa, pergunta geral, algo que não é uma ação do app). Preencha "fala" com uma resposta curta, gentil e direta.
- Omita campos que não se aplicam à ação escolhida (não precisa incluir com valor vazio).
- Nunca invente que disparou um SOS ou uma ligação de emergência — isso não é controlado por você.
"""


@dataclass
class ComandoAction:
    acao: str
    titulo: str | None = None
    tipo: str | None = None
    data_hora: str | None = None
    recorrencia: str | None = None
    itens: list[str] = field(default_factory=list)
    fala: str = ""

    @staticmethod
    def from_raw(raw: dict[str, Any]) -> "ComandoAction":
        acao = raw.get("acao")
        if acao not in ACOES_VALIDAS:
            raise ValueError(f"acao inválida: {acao!r}")

        tipo = raw.get("tipo")
        if tipo is not None and tipo not in TIPOS_VALIDOS:
            tipo = None

        recorrencia = raw.get("recorrencia")
        if recorrencia not in RECORRENCIAS_VALIDAS:
            recorrencia = "unico"

        itens_raw = raw.get("itens") or []
        itens = [str(i).strip() for i in itens_raw if str(i).strip()] if isinstance(itens_raw, list) else []

        return ComandoAction(
            acao=acao,
            titulo=(str(raw["titulo"]).strip() if raw.get("titulo") else None),
            tipo=tipo,
            data_hora=(str(raw["data_hora"]) if raw.get("data_hora") else None),
            recorrencia=recorrencia,
            itens=itens,
            fala=str(raw.get("fala") or "").strip(),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "acao": self.acao,
            "titulo": self.titulo,
            "tipo": self.tipo,
            "data_hora": self.data_hora,
            "recorrencia": self.recorrencia,
            "itens": self.itens,
            "fala": self.fala,
        }


def init_firebase() -> None:
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        log.error(
            "serviceAccountKey.json não encontrado em %s. Copie o mesmo "
            "arquivo usado pelo sos_notifier.py.",
            SERVICE_ACCOUNT_PATH,
        )
        sys.exit(1)
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)
    log.info("Firebase Admin SDK inicializado.")


def verificar_token(auth_header: str | None) -> str | None:
    """Verifica o ID token do Firebase Auth. Retorna o UID ou None se inválido."""
    if not auth_header or not auth_header.startswith("Bearer "):
        return None
    token = auth_header[len("Bearer "):].strip()
    try:
        decoded = firebase_auth.verify_id_token(token)
        return decoded.get("uid")
    except Exception as exc:
        log.warning("Token inválido: %s", exc)
        return None


init_firebase()
groq_client = Groq(api_key=os.environ["GROQ_API_KEY"])

app = Flask(__name__)
limiter = Limiter(
    app=app,
    key_func=lambda: getattr(request, "uid_autenticado", None) or request.remote_addr,
    default_limits=["100 per day", "20 per hour"],
)


@app.route("/interpretar-comando", methods=["POST"])
def interpretar_comando():
    uid = verificar_token(request.headers.get("Authorization"))
    if not uid:
        return jsonify({"erro": "não autenticado"}), 401
    request.uid_autenticado = uid  # usado pelo rate limiter acima

    body = request.get_json(silent=True) or {}
    texto = str(body.get("texto") or "").strip()
    if not texto:
        return jsonify({"erro": "texto vazio"}), 400

    contexto = body.get("contexto") or {}
    agora = contexto.get("agora", "")

    try:
        completion = groq_client.chat.completions.create(
            model=GROQ_MODEL,
            response_format={"type": "json_object"},
            max_tokens=400,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"Agora é: {agora}\nComando: {texto}"},
            ],
        )
        raw = json.loads(completion.choices[0].message.content)
        acao = ComandoAction.from_raw(raw)
    except Exception as exc:
        log.error("Falha ao interpretar comando de %s: %s", uid, exc)
        return jsonify({"erro": "falha ao interpretar"}), 502

    return jsonify(acao.to_dict())


@app.route("/healthz", methods=["GET"])
def healthz():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8091)
