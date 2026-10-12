"""
remedio_notifier.py — Serviço VPS: avisa a família quando um remédio passa
1 hora sem ser confirmado (TAREFA 21 do prompt mestre — "avisar familiar
autorizado").

Separado do sos_notifier.py de propósito: um erro aqui nunca pode derrubar
o aviso de SOS. Roda na mesma pasta (/root/sos_notifier) só para usar o
mesmo venv e o mesmo serviceAccountKey.json.

Como funciona, a cada VERIFICAR_A_CADA:
  1. Usuários com `avisarFamiliaRemedio: true` (o próprio idoso liga em
     Configurações da Molly — padrão desligado).
  2. Lembretes tipo Remedio de hoje (diário/semanal contam) que passaram de
     ATRASO_PARA_AVISAR sem confirmação de HOJE (`confirmedDates`, gravado
     pelo app em ReminderService.confirm).
  3. Para cada cuidador vinculado: mensagem no chat familiar + notificação
     (FCM). Cada remédio avisa no máximo uma vez por dia (avisados.json).

"Tomar" (água) fica de fora — mesma decisão do acompanhamento de remédio
no app (TAREFA 23). Horários em America/Sao_Paulo.

Execução manual:
  venv/bin/python3 remedio_notifier.py
Serviço:
  cp remedio-notifier.service /etc/systemd/system/
  systemctl daemon-reload && systemctl enable --now remedio-notifier
Testes (sem Firebase, sem rede):
  python3 -m unittest test_remedio_notifier
"""

import json
import logging
import os
import sys
import time
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

TZ = ZoneInfo("America/Sao_Paulo")
VERIFICAR_A_CADA = 300  # segundos
ATRASO_PARA_AVISAR = timedelta(hours=1)
# Passou disso sem avisar (serviço parado, por exemplo): não avisa mais —
# um aviso das 8h chegando às 15h só assusta.
JANELA_PARA_AVISAR = timedelta(hours=3)
TIPOS_REMEDIO = ("Remedio", "Remédio")
FCM_CHANNEL_ID = "me_lembra_ai_channel"  # canal comum de lembretes no app

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_ACCOUNT_PATH = os.path.join(SCRIPT_DIR, "serviceAccountKey.json")
AVISADOS_PATH = os.path.join(SCRIPT_DIR, "avisados.json")

log = logging.getLogger("remedio_notifier")


# ── Regras (puras, testáveis) ────────────────────────────────────────────


def chave_dia(d: date) -> str:
    """Mesmo formato de Reminder.chaveDia no app: "2026-10-12"."""
    return d.strftime("%Y-%m-%d")


def ocorre_em(inicio: datetime, repeat: str, dia: date) -> bool:
    """Mesma regra de Reminder.ocorreEm no app ([inicio] já em TZ)."""
    d0 = inicio.date()
    if repeat == "diario":
        return d0 <= dia
    if repeat == "semanal":
        return d0 <= dia and inicio.weekday() == dia.weekday()
    return d0 == dia


def confirmado_em(lembrete: dict, dia: date) -> bool:
    """Mesma regra de Reminder.confirmadoEm: lembrete único também aceita o
    `confirmed` antigo; repetido, só a confirmação daquele dia."""
    if chave_dia(dia) in (lembrete.get("confirmedDates") or []):
        return True
    return lembrete.get("repeat") not in ("diario", "semanal") and bool(lembrete.get("confirmed"))


def remedios_para_avisar(lembretes: list[dict], agora: datetime) -> list[tuple[dict, datetime]]:
    """(lembrete, horário de hoje) dos remédios a avisar agora. [agora] em TZ;
    cada lembrete tem `dateTime` (datetime com fuso)."""
    hoje = agora.date()
    saida = []
    for r in lembretes:
        if r.get("type") not in TIPOS_REMEDIO or not isinstance(r.get("dateTime"), datetime):
            continue
        inicio = r["dateTime"].astimezone(TZ)
        if not ocorre_em(inicio, r.get("repeat") or "unico", hoje):
            continue
        if confirmado_em(r, hoje):
            continue
        horario = datetime.combine(hoje, inicio.timetz().replace(tzinfo=None), tzinfo=TZ)
        # Criado depois do horário (ex.: às 15h, um remédio "das 8h"): não
        # houve chance de confirmar — não é atraso.
        criado = r.get("createdAt")
        if isinstance(criado, datetime) and criado > horario:
            continue
        atraso = agora - horario
        if ATRASO_PARA_AVISAR <= atraso < ATRASO_PARA_AVISAR + JANELA_PARA_AVISAR:
            saida.append((r, horario))
    return saida


def texto_aviso(nome: str, titulo: str, horario: datetime) -> str:
    remedio = f'o remédio "{titulo.strip()}"' if titulo and titulo.strip() else "o remédio"
    return (
        f"Aviso automático do Me Lembra Aí: {nome or 'Seu familiar'} ainda não confirmou "
        f"{remedio} das {horario.strftime('%H:%M')}. Que tal ligar para saber se está tudo bem?"
    )


def chave_aviso(uid: str, rid: str, dia: date) -> str:
    return f"{uid}|{rid}|{chave_dia(dia)}"


def podar_avisados(avisados: dict, hoje: date, dias: int = 3) -> dict:
    """Guarda só os últimos [dias] dias — o arquivo não cresce para sempre."""
    limite = chave_dia(hoje - timedelta(days=dias))
    return {k: v for k, v in avisados.items() if k.rsplit("|", 1)[-1] >= limite}


# ── Estado em disco ──────────────────────────────────────────────────────


def carregar_avisados() -> dict:
    try:
        with open(AVISADOS_PATH, encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def salvar_avisados(avisados: dict) -> None:
    tmp = AVISADOS_PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(avisados, f)
    os.replace(tmp, AVISADOS_PATH)


# ── Firebase (só na VPS) ─────────────────────────────────────────────────


def _cuidadores(db, firestore, uid: str) -> list[str]:
    docs = (
        db.collection("users").document(uid).collection("family")
        .where(filter=firestore.FieldFilter("papel", "==", "cuidador"))
        .stream()
    )
    return [d.id for d in docs]


def _avisar_cuidador(db, firestore, messaging, uid: str, cuidador_uid: str, texto: str) -> None:
    # Chat familiar: mesmo formato de ChatService.send no app.
    par = "_".join(sorted([uid, cuidador_uid]))
    db.collection("chats").document(par).collection("messages").add({
        "senderUid": uid,
        "text": texto,
        "type": "text",
        "sentAt": firestore.SERVER_TIMESTAMP,
    })
    token = (db.collection("users").document(cuidador_uid).get().to_dict() or {}).get("fcmToken")
    if not token:
        log.info("Cuidador %s sem token FCM — só a mensagem no chat.", cuidador_uid)
        return
    try:
        messaging.send(messaging.Message(
            notification=messaging.Notification(title="Remédio não confirmado", body=texto),
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(channel_id=FCM_CHANNEL_ID, icon="@mipmap/ic_launcher"),
            ),
            data={"type": "remedio_nao_confirmado", "uid": uid},
            token=token,
        ))
    except messaging.UnregisteredError:
        log.warning("Token inválido/expirado do cuidador %s", cuidador_uid)
    except Exception as exc:  # noqa: BLE001 — o chat já foi; a notificação é extra
        log.error("Erro ao enviar FCM ao cuidador %s: %s", cuidador_uid, exc)


def verificar(db, firestore, messaging, avisados: dict, agora: datetime) -> int:
    """Uma rodada. Devolve quantos avisos saíram."""
    enviados = 0
    usuarios = db.collection("users").where(
        filter=firestore.FieldFilter("avisarFamiliaRemedio", "==", True)
    ).stream()
    for u in usuarios:
        uid = u.id
        try:
            lembretes = []
            for doc in (
                db.collection("users").document(uid).collection("reminders")
                .where(filter=firestore.FieldFilter("type", "in", list(TIPOS_REMEDIO)))
                .stream()
            ):
                lembretes.append({**(doc.to_dict() or {}), "id": doc.id})
            pendentes = [
                (r, h) for r, h in remedios_para_avisar(lembretes, agora)
                if chave_aviso(uid, r["id"], agora.date()) not in avisados
            ]
            if not pendentes:
                continue
            cuidadores = _cuidadores(db, firestore, uid)
            nome = (u.to_dict() or {}).get("nome") or "Seu familiar"
            for r, horario in pendentes:
                # Marca antes de enviar: na dúvida, um aviso a menos é melhor
                # que o mesmo aviso repetido a cada 5 minutos.
                avisados[chave_aviso(uid, r["id"], agora.date())] = agora.isoformat()
                if not cuidadores:
                    log.info("Remédio atrasado de %s, mas sem cuidador vinculado.", uid)
                    continue
                texto = texto_aviso(nome, r.get("title") or "", horario)
                for c in cuidadores:
                    _avisar_cuidador(db, firestore, messaging, uid, c, texto)
                    enviados += 1
                log.info("Aviso de remédio de %s (%s, %s) para %d cuidador(es).",
                         uid, r["id"], horario.strftime("%H:%M"), len(cuidadores))
        except Exception as exc:  # noqa: BLE001 — um usuário com problema não para os outros
            log.error("Erro ao verificar remédios de %s: %s", uid, exc)
    return enviados


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[logging.StreamHandler(sys.stdout), logging.FileHandler(os.path.join(SCRIPT_DIR, "remedio_notifier.log"))],
    )
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        log.error("serviceAccountKey.json não encontrado em %s.", SERVICE_ACCOUNT_PATH)
        sys.exit(1)

    import firebase_admin
    from firebase_admin import credentials, firestore, messaging

    firebase_admin.initialize_app(credentials.Certificate(SERVICE_ACCOUNT_PATH))
    db = firestore.client()
    log.info("Aviso de remédio em execução (a cada %ss, atraso %s).", VERIFICAR_A_CADA, ATRASO_PARA_AVISAR)

    while True:
        agora = datetime.now(timezone.utc).astimezone(TZ)
        avisados = podar_avisados(carregar_avisados(), agora.date())
        try:
            n = verificar(db, firestore, messaging, avisados, agora)
            if n:
                log.info("%d aviso(s) enviados nesta rodada.", n)
        except Exception as exc:  # noqa: BLE001 — Firestore fora do ar: tenta na próxima
            log.error("Falha na rodada: %s", exc)
        salvar_avisados(avisados)
        time.sleep(VERIFICAR_A_CADA)


if __name__ == "__main__":
    main()
