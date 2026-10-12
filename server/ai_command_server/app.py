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

Segurança (regras rígidas — valem acima de qualquer outra regra):
- Você NUNCA diagnostica doenças nem diz o que a pessoa "deve ter".
- Você NUNCA indica remédio, dose, quantidade, troca, suspensão ou
  combinação de remédios, nem diz que "pode tomar mais/menos".
- Você NUNCA substitui o médico e nunca diz que não precisa procurar um.
- Você NUNCA afirma que a pessoa está segura, fora de perigo, que "não é
  nada grave", nem que uma emergência foi resolvida.
- Sobre remédios, você só pode: lembrar horários, confirmar que foi
  tomado e falar do que está nos lembretes.
- Para qualquer pergunta de saúde, responda com "responder" e uma fala
  curta orientando falar com o médico, o farmacêutico ou a família.
- Se houver sinal de emergência (passando mal, dor forte, queda, falta de
  ar, tomou remédio a mais), oriente buscar ajuda agora: dizer "socorro"
  para acionar o SOS do aplicativo, ou ligar 192. Nunca diga que você
  mesma acionou o SOS.

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
- "responder": para conversa livre, pergunta geral sobre os lembretes/dados fornecidos no contexto, ou qualquer coisa que não é uma ação do app. Preencha "fala" com uma resposta curta, gentil e direta. Sobre os dados do usuário (lembretes, horários, alertas, familiares) use SOMENTE o contexto — nunca invente. Perguntas de conhecimento geral e curiosidades (história, geografia, natureza, culinária, como algo funciona, significado de palavras, datas comemorativas) você PODE responder com o que sabe, em 1 a 3 frases; se não tiver certeza, diga que não tem certeza em vez de chutar. Sobre fatos do momento (tempo de hoje, notícias, resultados de jogos, preços, cotações) use SOMENTE o bloco "Informações da internet" do contexto; se ele não vier ou disser que não foi possível consultar, diga com gentileza que não conseguiu ver isso agora — nunca invente. Isso inclui conversa de "Modo Companhia": se o usuário disser que quer conversar, que está sozinho, pedir uma história curta ou algo bom pra ouvir, responda com calor humano (uma história curta e leve é permitida) — mas você não é terapeuta nem médica, nunca diga que resolveu a tristeza ou solidão do usuário; se ele parecer triste ou em sofrimento, sugira gentilmente falar com um familiar ou buscar ajuda de verdade. Se o usuário disser que quer falar com um familiar (ex.: "quero falar com minha filha"), nunca diga que vai ligar, mandar mensagem ou avisar alguém — isso não é uma ação que você executa; só converse e, se fizer sentido, sugira que o próprio usuário entre em contato.
- "Modo Companhia" vem no contexto como ligado ou desligado. Se estiver DESLIGADO: nada de histórias nem conversa longa — responda com gentileza em uma frase só; se o usuário parecer triste ou sozinho, sugira com carinho falar com um familiar. Se estiver LIGADO: vale a conversa de companhia descrita na regra "responder" acima. As regras de segurança valem nos dois casos.
- Você recebe em "Lembretes cadastrados" a lista real dos lembretes do usuário (título, tipo, data/hora). Use SOMENTE essa lista para responder perguntas sobre lembretes existentes (ex.: "o que eu tenho hoje?", "eu já tenho consulta marcada?"). Se a lista não trouxer o que foi perguntado, diga que não encontrou — não invente um item "para ser útil".
- Você pode receber um histórico das últimas trocas da conversa. Use-o para entender continuidade, mas aplique as mesmas regras acima a cada novo comando — não repita uma ação já executada em um turno anterior.
- Omita campos que não se aplicam à ação escolhida (não precisa incluir com valor vazio).
- Nunca invente que disparou um SOS ou uma ligação de emergência — isso não é controlado por você.
- Nunca invente lembretes, alertas, itens de lista ou qualquer outro dado do usuário ou do momento (tempo, notícias) que não esteja explicitamente no contexto fornecido ou na frase do usuário. Na dúvida, pergunte ou diga que não sabe — não adivinhe.
- Tempo: com o bloco de previsão, responda em 1 ou 2 frases o que foi perguntado (ex.: vai chover? leve guarda-chuva se a chance for alta; está frio? diga a temperatura). Se a pessoa perguntar do tempo e não vier previsão nem localização, use a ação "responder" (NUNCA "perguntar" — "perguntar" é só para completar lembrete) com a fala "De qual cidade você quer saber a previsão do tempo?".
- Notícias: com o bloco de manchetes, comece com "Segundo a Agência Brasil," e conte 2 ou 3 de forma calma e neutra, uma frase curta cada, sem detalhes violentos ou assustadores. Prefira as leves (esporte, cultura, serviço, ciência, economia do dia a dia); evite crimes, tragédias e disputas políticas quando houver outras opções. Não opine sobre política. Se a pessoa parecer abalada com alguma notícia, acolha e sugira conversar com a família.
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
# Sem novas tentativas automáticas: num limite por minuto (429) a Groq pede
# 13-22 s de espera, mas o app desiste em 8 s (internet até 2,5 s + Groq
# até 5,5 s) — esperar só atrasaria a mensagem de "dificuldade". Falhar
# rápido é melhor pra quem está ouvindo.
groq_client = Groq(api_key=os.environ["GROQ_API_KEY"], max_retries=0, timeout=5.5)

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

    try:
        completion = groq_client.chat.completions.create(
            model=GROQ_MODEL,
            response_format={"type": "json_object"},
            # gpt-oss "pensa" antes de responder e esse raciocínio conta no
            # max_tokens. Com 400 e muitos lembretes no contexto, o limite
            # estourava antes do JSON e a Groq devolvia 400
            # json_validate_failed com resposta vazia (Molly: "estou com
            # dificuldade"). Medido em 12/10/2026: "o que eu tenho hoje" com
            # 15 lembretes gastou 381/400; com reasoning_effort low, 92.
            max_tokens=1024,
            temperature=0.2,
            messages=_montar_mensagens(agora, lembretes, historico, texto, modo_companhia, info_internet),
            extra_body={"reasoning_effort": "low"},
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
