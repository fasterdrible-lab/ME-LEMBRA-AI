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
GROQ_MODEL = os.environ.get("GROQ_MODEL", "openai/gpt-oss-20b")

ACOES_VALIDAS = {
    "criar_lembrete",
    "ouvir_lembretes",
    "adicionar_item_lista",
    "consultar_alertas",
    "perguntar",
    "responder",
}

TIPOS_VALIDOS = {
    "Remedio", "Consulta", "Aniversario", "Mercado", "Reuniao", "Tomar", "Compras",
}

RECORRENCIAS_VALIDAS = {"unico", "diario", "semanal"}

MAX_HISTORICO_TROCAS = 3

SYSTEM_PROMPT = """Você é a MOLLY: interpreta comandos de voz em português \
de um app de lembretes para uma pessoa idosa, dentro de uma conversa que \
pode ter várias falas seguidas (não é só uma pergunta e resposta isolada).

Personalidade (aplica-se a todo texto que você escrever em "fala"):
- Paciente, educada, gentil, objetiva e acolhedora.
- Frases curtas (1 a 3), nunca parágrafos.
- Linguagem do dia a dia — nunca termos técnicos (sistema, erro, serviço,
  processando, sincronizando, exceção).
- Nunca infantilize o usuário: mesmo respeito e naturalidade de uma
  conversa entre adultos, não como se fosse uma criança.
- Diga o que precisa de forma direta; se fizer sentido, ofereça o próximo
  passo (ex.: "Quer tentar de novo?").
- Nunca leia uma lista item por item numa "fala" só — resuma. Bom: "Você
  tem dois compromissos hoje. Um às dez da manhã e outro às três da
  tarde." Ruim: uma frase separada para cada compromisso. Com muitos
  itens, diga a quantidade e cite só o mais próximo/relevante.

Responda SEMPRE em JSON puro (sem texto fora do JSON), seguindo exatamente este formato:

{
  "acao": "criar_lembrete" | "ouvir_lembretes" | "adicionar_item_lista" | "consultar_alertas" | "perguntar" | "responder",
  "titulo": "string, só para criar_lembrete",
  "tipo": "Remedio" | "Consulta" | "Aniversario" | "Mercado" | "Reuniao" | "Tomar" | "Compras",
  "data_hora": "ISO 8601 completo, ex: 2026-07-03T08:00:00, só para criar_lembrete",
  "recorrencia": "unico" | "diario" | "semanal",
  "itens": ["string", "..."],
  "fala": "resposta curta e natural em português para falar de volta ao usuário",
  "memoria": {"tipo": "string curta, ex: nome_preferido, horario_rotina, preferencia", "valor": "string", "confianca": 0.0 a 1.0}
}

Regras:
- "criar_lembrete": quando a pessoa pede para lembrar de algo em um horário/data JÁ CLARO na frase (ou dedutível do "agora" fornecido, ex.: "amanhã", "daqui a uma hora"). Se faltar informação essencial (por exemplo, não disse quando), NÃO invente um horário — use "perguntar" em vez disso. A mesma intenção pode vir de frases bem diferentes — todas as variações abaixo significam exatamente a mesma coisa: "Me lembra do remédio às oito.", "Coloca um lembrete para oito horas.", "Às oito eu preciso tomar meu remédio.", "Não deixa eu esquecer o remédio às oito."
- "ouvir_lembretes": quando pede para ouvir/saber os lembretes do dia.
- "adicionar_item_lista": quando pede para adicionar item(ns) na lista de compras/mercado. Preencha "itens".
- "consultar_alertas": quando pergunta sobre alertas de SOS enviados.
- "perguntar": quando o pedido está ambíguo ou incompleto para ser executado com segurança (ex.: pediu para criar um lembrete mas não disse a hora, ou não ficou claro qual item da lista). Preencha "fala" com UMA pergunta curta e específica para esclarecer — nunca confirme uma ação nem invente o dado que falta.
- "responder": para conversa livre, pergunta geral sobre os lembretes/dados fornecidos no contexto, ou qualquer coisa que não é uma ação do app. Preencha "fala" com uma resposta curta, gentil e direta, baseada SOMENTE no que está no contexto — nunca invente lembretes, horários, alertas ou dados que não foram te passados. Isso inclui conversa de "Modo Companhia": se o usuário disser que quer conversar, que está sozinho, pedir uma história curta ou algo bom pra ouvir, responda com calor humano (uma história curta e leve é permitida) — mas você não é terapeuta nem médica, nunca diga que resolveu a tristeza ou solidão do usuário; se ele parecer triste ou em sofrimento, sugira gentilmente falar com um familiar ou buscar ajuda de verdade. Se o usuário disser que quer falar com um familiar (ex.: "quero falar com minha filha"), nunca diga que vai ligar, mandar mensagem ou avisar alguém — isso não é uma ação que você executa; só converse e, se fizer sentido, sugira que o próprio usuário entre em contato.
- Você recebe em "Lembretes cadastrados" a lista real dos lembretes do usuário (título, tipo, data/hora). Use SOMENTE essa lista para responder perguntas sobre lembretes existentes (ex.: "o que eu tenho hoje?", "eu já tenho consulta marcada?"). Se a lista não trouxer o que foi perguntado, diga que não encontrou — não invente um item "para ser útil".
- Você pode receber um histórico das últimas trocas da conversa. Use-o para entender continuidade, mas aplique as mesmas regras acima a cada novo comando — não repita uma ação já executada em um turno anterior.
- Omita campos que não se aplicam à ação escolhida (não precisa incluir com valor vazio).
- Nunca invente que disparou um SOS ou uma ligação de emergência — isso não é controlado por você.
- Nunca invente lembretes, alertas, itens de lista ou qualquer outro dado que não esteja explicitamente no contexto fornecido ou na frase do usuário. Na dúvida, pergunte ou diga que não sabe — não adivinhe.
- "memoria" (campo OPCIONAL, independente de "acao" — pode vir junto de qualquer ação): inclua SOMENTE quando o usuário compartilhar uma preferência pessoal durável, não algo pontual/de uma vez só. Bons exemplos: "pode me chamar de Seu Antônio" (nome_preferido), "eu sempre almoço ao meio-dia" (horario_rotina), "eu prefiro tomar remédio de manhã" (preferencia). NÃO inclua "memoria" para: comandos de ação (criar lembrete, ouvir lembretes, etc.), perguntas, comentários pontuais de um momento só, ou qualquer coisa da qual você não tenha certeza — nesse caso, omita o campo inteiro. Você nunca decide sozinha se isso é salvo: é só uma sugestão, o app sempre pergunta ao usuário antes de guardar qualquer coisa.
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
    # Proposta opcional de memória de longo prazo (sessão 24) — sempre os
    # três campos juntos, ou nenhum. Nunca gravado aqui: só passa adiante
    # pro app decidir se pergunta ao usuário (ver MollyAgentService.processar
    # no cliente, que ainda confere o interruptor geral antes de perguntar).
    memoria: dict[str, Any] | None = None

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

        fala = str(raw.get("fala") or "").strip()
        if not fala and acao in ("responder", "perguntar"):
            fala = "Pode repetir, por favor?"

        memoria_raw = raw.get("memoria")
        memoria = None
        if isinstance(memoria_raw, dict):
            m_tipo = str(memoria_raw.get("tipo") or "").strip()
            m_valor = str(memoria_raw.get("valor") or "").strip()
            if m_tipo and m_valor:
                try:
                    m_confianca = float(memoria_raw.get("confianca", 0.7))
                except (TypeError, ValueError):
                    m_confianca = 0.7
                memoria = {
                    "tipo": m_tipo,
                    "valor": m_valor,
                    "confianca": max(0.0, min(1.0, m_confianca)),
                }

        return ComandoAction(
            acao=acao,
            titulo=(str(raw["titulo"]).strip() if raw.get("titulo") else None),
            tipo=tipo,
            data_hora=(str(raw["data_hora"]) if raw.get("data_hora") else None),
            recorrencia=recorrencia,
            itens=itens,
            fala=fala,
            memoria=memoria,
        )

    def to_dict(self) -> dict[str, Any]:
        d: dict[str, Any] = {
            "acao": self.acao,
            "titulo": self.titulo,
            "tipo": self.tipo,
            "data_hora": self.data_hora,
            "recorrencia": self.recorrencia,
            "itens": self.itens,
            "fala": self.fala,
        }
        if self.memoria is not None:
            d["memoria"] = self.memoria
        return d


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
    # 60/hora (antes 20/hora): uma conversa multi-turno gera várias
    # requisições em vez de uma só por comando.
    default_limits=["100 per day", "60 per hour"],
)


def _formatar_lembretes(lembretes: list[Any]) -> str:
    if not lembretes:
        return "Nenhum lembrete cadastrado."
    linhas = []
    for item in lembretes[:20]:
        if not isinstance(item, dict):
            continue
        titulo = str(item.get("titulo") or "").strip()
        tipo = str(item.get("tipo") or "").strip()
        data_hora = str(item.get("data_hora") or "").strip()
        if not titulo:
            continue
        linha = f"- {titulo} ({tipo}) em {data_hora}"
        itens_raw = item.get("itens")
        if isinstance(itens_raw, list) and itens_raw:
            itens = ", ".join(str(i).strip() for i in itens_raw if str(i).strip())
            if itens:
                linha += f" — itens: {itens}"
        linhas.append(linha)
    return "\n".join(linhas) if linhas else "Nenhum lembrete cadastrado."


def _montar_mensagens(
    agora: str, lembretes: list[Any], historico: list[Any], texto: str
) -> list[dict]:
    mensagens = [{"role": "system", "content": SYSTEM_PROMPT}]
    trocas = historico[-MAX_HISTORICO_TROCAS:] if isinstance(historico, list) else []
    for troca in trocas:
        if not isinstance(troca, dict):
            continue
        usuario = str(troca.get("usuario") or "").strip()
        assistente = str(troca.get("assistente") or "").strip()
        if usuario:
            mensagens.append({"role": "user", "content": usuario})
        if assistente:
            mensagens.append({"role": "assistant", "content": assistente})
    contexto_texto = (
        f"Agora é: {agora}\n"
        f"Lembretes cadastrados:\n{_formatar_lembretes(lembretes)}\n"
        f"Comando: {texto}"
    )
    mensagens.append({"role": "user", "content": contexto_texto})
    return mensagens


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
    lembretes = contexto.get("lembretes") or []
    historico = body.get("historico") or []

    try:
        completion = groq_client.chat.completions.create(
            model=GROQ_MODEL,
            response_format={"type": "json_object"},
            max_tokens=400,
            temperature=0.2,
            messages=_montar_mensagens(agora, lembretes, historico, texto),
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
