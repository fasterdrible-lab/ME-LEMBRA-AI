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
import time
from dataclasses import dataclass, field
from typing import Any

import firebase_admin
from dotenv import load_dotenv
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials
from flask import Flask, jsonify, request
from flask_limiter import Limiter
from groq import Groq

import internet  # tempo e notícias, só quando a frase pede

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

# TAREFAs 31/32: modelos reserva, tentados em ordem quando o anterior falha
# (429 limite/min, 404 modelo saiu do catálogo, JSON inválido...). Na Groq o
# limite de 8.000 tokens/min é POR MODELO — cada reserva soma capacidade.
GROQ_MODELOS = [GROQ_MODEL] + [
    m.strip()
    for m in os.environ.get("GROQ_MODELOS_RESERVA", "openai/gpt-oss-120b,qwen/qwen3.8-27b").split(",")
    if m.strip() and m.strip() != GROQ_MODEL
]
ORCAMENTO_SEGUNDOS = 4.0  # depois disso não começa outra tentativa (app desiste em 8 s)


def _max_tokens(modelo: str) -> int:
    """gpt-oss: 1024 (o raciocínio conta). qwen3 na Groq tem limite de 1.000
    tokens de SAÍDA por minuto — pedir 1024 dá 429 sempre; sem raciocínio,
    400 sobra pra uma resposta curta."""
    return 400 if "qwen" in modelo else 1024


def _parametros_de_raciocinio(modelo: str) -> dict:
    """Raciocínio mínimo: gpt-oss aceita "low"; qwen3 aceita "none"."""
    if "gpt-oss" in modelo:
        return {"reasoning_effort": "low"}
    if "qwen3" in modelo:
        return {"reasoning_effort": "none"}
    return {}

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

# TAREFA 31 (custos): versão enxuta — 2.260 → ~1.200 tokens por chamada,
# mesmas regras. A chave Groq tem 8.000 tokens/min POR MODELO somando todos
# os usuários; cada token aqui pesa em toda pergunta. Textos exatos que o
# código procura: "De qual cidade você quer saber a previsão do tempo?"
# (_molly_perguntou_cidade) e "Segundo a Agência Brasil,".
SYSTEM_PROMPT = """Você é a MOLLY, assistente de voz de um app de lembretes para uma pessoa idosa. Interpreta cada fala (pode haver histórico da conversa) e responde em JSON.

Jeito de falar ("fala"): paciente, gentil, acolhedora, respeitosa (nunca infantilize); 1 a 3 frases curtas; linguagem do dia a dia, sem termos técnicos. Nunca leia lista item por item: diga a quantidade e cite o mais próximo (ex.: "Você tem dois compromissos hoje. Um às dez e outro às três.").

SEGURANÇA (acima de tudo): nunca diagnostique, nunca indique/mude remédio ou dose, nunca substitua o médico nem diga que não precisa de um, nunca diga que a pessoa está segura, que "não é grave" ou que uma emergência foi resolvida. Sobre remédio, só lembrar horário e falar dos lembretes. Pergunta de saúde: "responder" orientando falar com médico, farmacêutico ou família. Sinal de emergência (passando mal, dor forte, queda, falta de ar, remédio a mais): oriente dizer "socorro" (aciona o SOS do app) ou ligar 192.

JSON ("acao" e "fala" sempre; omita os outros campos que não se aplicam):
{"acao": "criar_lembrete"|"ouvir_lembretes"|"adicionar_item_lista"|"consultar_alertas"|"perguntar"|"responder", "titulo": "só criar_lembrete", "tipo": "Remedio"|"Consulta"|"Aniversario"|"Mercado"|"Reuniao"|"Tomar"|"Compras", "data_hora": "ISO 8601, ex. 2026-07-03T08:00:00", "recorrencia": "unico"|"diario"|"semanal", "itens": ["..."], "fala": "texto curto para falar", "memoria": {"tipo": "nome_preferido|horario_rotina|preferencia", "valor": "...", "confianca": 0.0-1.0}}

Ações:
- criar_lembrete: pedido de lembrar algo com dia/hora claros ou dedutíveis do "Agora" ("amanhã", "daqui a uma hora"). São a mesma intenção: "Me lembra do remédio às oito.", "Coloca um lembrete para oito horas.", "Às oito eu preciso tomar meu remédio.", "Não deixa eu esquecer o remédio às oito." Sem hora/dia: "perguntar" — nunca invente.
- ouvir_lembretes: quer ouvir os lembretes do dia. adicionar_item_lista: itens na lista de compras (preencha "itens"). consultar_alertas: pergunta sobre alertas de SOS.
- perguntar: SÓ para completar um lembrete ambíguo/incompleto; "fala" = uma pergunta curta.
- responder: todo o resto. Dados do usuário (lembretes, alertas, familiares): só do contexto; se não estiver lá, diga que não encontrou. Conhecimento geral e curiosidades: pode responder com o que sabe, em 1 a 3 frases; sem certeza, diga que não tem certeza. Fatos do momento (tempo, notícias, jogos, preços): só do bloco "Informações da internet"; sem ele, diga que não conseguiu ver agora.

Regras:
- Você só executa as ações acima. Nunca diga que excluiu, apagou, ligou, mandou mensagem, avisou alguém, cancelou ou acionou o SOS. Pedido de excluir lembretes: por segurança é na tela Meus Lembretes. "Ligar para qualquer pessoa": pergunte para quem. "Quero falar com minha filha": converse e sugira que a pessoa entre em contato.
- Modo Companhia (no contexto): se estiver "desligado" e pedirem história ou conversa longa, NÃO conte a história — responda numa frase só, com gentileza, que para contar histórias é preciso ligar o Modo Companhia nas Configurações da Molly. Se estiver "ligado": conversa calorosa, história curta e leve permitida. Nos dois: você não é terapeuta; se a pessoa parecer triste ou sozinha, sugira com carinho falar com um familiar.
- Tempo: com a previsão, 1 ou 2 frases sobre o que foi perguntado (chuva → guarda-chuva se a chance for alta). Sem previsão nem cidade: "responder" com "De qual cidade você quer saber a previsão do tempo?".
- Notícias: comece com "Segundo a Agência Brasil," e conte 2 ou 3 manchetes, calmas e neutras, uma frase cada; prefira leves (esporte, cultura, serviço, ciência); evite crimes, tragédias e disputa política quando houver outras; sem opinião.
- Histórico: use para continuidade, sem repetir ação já feita.
- memoria (opcional, junto de "responder" ou outra ação): só quando a pessoa conta uma preferência durável (como gosta de ser chamada, horário fixo de uma rotina). Nunca para comandos, perguntas ou algo pontual; na dúvida, omita. É só sugestão: o app pergunta antes de guardar.
- Nunca chame a pessoa por um nome que ela não disse nesta conversa.
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
        # Sem "acao" mas com uma fala (visto com "pode me chamar de...": o
        # modelo mandou só fala+memoria) — é conversa, não um comando.
        if acao is None and str(raw.get("fala") or "").strip():
            acao = "responder"
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
# Sem novas tentativas automáticas: num limite por minuto (429) a Groq pede
# 13-22 s de espera, mas o app desiste em 8 s. Em vez de esperar, passa
# pro modelo reserva (GROQ_MODELOS). 3 s por tentativa: normal é < 1 s.
groq_client = Groq(api_key=os.environ["GROQ_API_KEY"], max_retries=0, timeout=3.0)

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
    agora: str,
    lembretes: list[Any],
    historico: list[Any],
    texto: str,
    modo_companhia: bool = True,
    info_internet: str | None = None,
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
        f"Modo Companhia: {'ligado' if modo_companhia else 'desligado'}\n"
        + (f"Informações da internet (consultadas agora):\n{info_internet}\n" if info_internet else "")
        + f"Comando: {texto}"
    )
    mensagens.append({"role": "user", "content": contexto_texto})
    return mensagens


def _consultar_internet(texto: str, localizacao: Any, historico: Any = None) -> str | None:
    partes = []
    # Resposta curta a "De qual cidade você quer saber a previsão do
    # tempo?" (ex.: só "Campinas"): a frase em si não fala de tempo, mas a
    # última fala da Molly sim — trata como pedido de previsão dessa cidade.
    if not internet.precisa_tempo(texto) and _molly_perguntou_cidade(historico):
        texto = f"previsão do tempo em {texto.strip().rstrip('.!?')}"
    if internet.precisa_tempo(texto):
        lat = lon = None
        if isinstance(localizacao, dict):
            try:
                lat, lon = float(localizacao["lat"]), float(localizacao["lon"])
            except (KeyError, TypeError, ValueError):
                lat = lon = None
        partes.append(
            internet.buscar_tempo(texto, lat, lon)
            or "Previsão do tempo: não foi possível consultar agora (sem localização ou serviço fora do ar)."
        )
    if internet.precisa_noticias(texto):
        partes.append(internet.buscar_noticias() or "Notícias: não foi possível consultar agora.")
    return "\n".join(partes) if partes else None


def _molly_perguntou_cidade(historico: Any) -> bool:
    if not isinstance(historico, list) or not historico:
        return False
    ultima = historico[-1]
    if not isinstance(ultima, dict):
        return False
    fala = str(ultima.get("assistente") or "").lower()
    return "qual cidade" in fala and "tempo" in fala


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
    # Apps anteriores à tela de Configurações da Molly não mandam o campo —
    # mantém o comportamento de antes (companhia permitida) pra eles.
    modo_companhia = contexto.get("modo_companhia")
    modo_companhia = True if modo_companhia is None else bool(modo_companhia)

    # Tempo/notícias: só consulta a internet quando a frase pede (economiza
    # tempo e o limite de tokens/min). Localização vem do app só nesses
    # casos, arredondada (~1 km); cidade dita na frase tem prioridade.
    info_internet = _consultar_internet(texto, contexto.get("localizacao"), historico)

    mensagens = _montar_mensagens(agora, lembretes, historico, texto, modo_companhia, info_internet)
    inicio = time.monotonic()
    for modelo in GROQ_MODELOS:
        # O app desiste em 8 s: sem tempo pra outra tentativa, para aqui.
        if time.monotonic() - inicio > ORCAMENTO_SEGUNDOS:
            break
        try:
            completion = groq_client.chat.completions.create(
                model=modelo,
                response_format={"type": "json_object"},
                # Modelos com raciocínio contam esses tokens no max_tokens:
                # com 400 e muitos lembretes, o limite estourava antes do
                # JSON (400 json_validate_failed, resposta vazia — sessão
                # 25). 1024 + raciocínio mínimo resolve.
                max_tokens=_max_tokens(modelo),
                temperature=0.2,
                messages=mensagens,
                extra_body=_parametros_de_raciocinio(modelo),
            )
            raw = json.loads(completion.choices[0].message.content)
            acao = ComandoAction.from_raw(raw)
            if modelo != GROQ_MODELOS[0]:
                log.warning("Comando de %s respondido pelo modelo reserva %s", uid, modelo)
            return jsonify(acao.to_dict())
        except Exception as exc:  # noqa: BLE001 — 429, 404, json inválido...: tenta o próximo
            log.error("Falha ao interpretar comando de %s com %s: %s", uid, modelo, exc)

    return jsonify({"erro": "falha ao interpretar"}), 502


@app.route("/healthz", methods=["GET"])
def healthz():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8091)
