"""
sos_notifier.py — Serviço VPS: envia FCM push para cuidadores ao disparar SOS.

Pré-requisitos:
  pip install firebase-admin
  Arquivo serviceAccountKey.json na mesma pasta (baixar no Firebase Console)

Execução manual:
  python3 sos_notifier.py

Execução como serviço systemd:
  Copiar sos-notifier.service para /etc/systemd/system/ e rodar:
    systemctl enable sos-notifier
    systemctl start sos-notifier
"""

import logging
import os
import sys
import time
from datetime import datetime, timezone, timedelta

import firebase_admin
from firebase_admin import credentials, firestore, messaging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("sos_notifier.log"),
    ],
)
log = logging.getLogger(__name__)

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVICE_ACCOUNT_PATH = os.path.join(SCRIPT_DIR, "serviceAccountKey.json")
FCM_CHANNEL_ID = "sos_alert"


def init_firebase():
    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)
    log.info("Firebase Admin SDK inicializado.")


def get_cuidador_tokens(db, user_id: str) -> list[str]:
    """Retorna FCM tokens de todos os cuidadores vinculados a user_id."""
    tokens = []
    try:
        family_docs = (
            db.collection("users")
            .document(user_id)
            .collection("family")
            .where(filter=firestore.FieldFilter("papel", "==", "cuidador"))
            .stream()
        )
        for doc in family_docs:
            cuidador_uid = doc.id
            user_snap = db.collection("users").document(cuidador_uid).get()
            data = user_snap.to_dict()
            if data:
                token = data.get("fcmToken")
                if token:
                    tokens.append(token)
    except Exception as exc:
        log.error("Erro ao buscar tokens dos cuidadores de %s: %s", user_id, exc)
    return tokens


def send_sos_notification(token: str, nome: str, motivo: str, lat, lng):
    loc = (
        f"{float(lat):.4f}, {float(lng):.4f}"
        if lat is not None and lng is not None
        else "sem localização"
    )
    body = f"{motivo or 'manual'} · {loc}"

    message = messaging.Message(
        notification=messaging.Notification(
            title=f"SOS de {nome or 'Familiar'}",
            body=body,
        ),
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                channel_id=FCM_CHANNEL_ID,
                sound="default",
                icon="@mipmap/ic_launcher",
                notification_priority=messaging.AndroidNotificationPriority.MAX_PRIORITY,
                visibility=messaging.AndroidNotificationVisibility.PUBLIC,
            ),
        ),
        apns=messaging.APNSConfig(
            headers={"apns-priority": "10"},
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    sound=messaging.CriticalSound(name="default", critical=True, volume=1.0),
                    badge=1,
                ),
            ),
        ),
        data={"type": "sos", "nome": nome or "Familiar", "motivo": motivo or "manual"},
        token=token,
    )

    try:
        response = messaging.send(message)
        log.info("FCM enviado (token ...%s): %s", token[-6:], response)
    except messaging.UnregisteredError:
        log.warning("Token inválido/expirado: ...%s", token[-6:])
    except Exception as exc:
        log.error("Erro ao enviar FCM para ...%s: %s", token[-6:], exc)


def on_sos_snapshot(col_snapshot, changes, read_time):
    db = firestore.client()
    for change in changes:
        if change.type.name != "ADDED":
            continue

        data = change.document.to_dict() or {}
        user_id = data.get("userId")
        if not user_id:
            continue

        nome = data.get("nome", "Familiar")
        motivo = data.get("motivo", "manual")
        lat = data.get("latitude")
        lng = data.get("longitude")

        log.info("Novo SOS de %s (uid: %s, motivo: %s)", nome, user_id, motivo)

        tokens = get_cuidador_tokens(db, user_id)
        if not tokens:
            log.info("Nenhum cuidador com token FCM para uid %s.", user_id)
            continue

        for token in tokens:
            send_sos_notification(token, nome, motivo, lat, lng)


def main():
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        log.error(
            "serviceAccountKey.json não encontrado em %s. "
            "Baixe em: Firebase Console → Configurações → Contas de serviço.",
            SERVICE_ACCOUNT_PATH,
        )
        sys.exit(1)

    init_firebase()
    db = firestore.client()

    # Ignorar alertas anteriores ao início do serviço
    start_dt = datetime.now(timezone.utc) - timedelta(seconds=10)
    log.info("Ouvindo sos_alerts criados após %s...", start_dt.isoformat())

    query = db.collection("sos_alerts").where(
        filter=firestore.FieldFilter("createdAt", ">=", start_dt)
    )
    watch = query.on_snapshot(on_sos_snapshot)

    log.info("SOS Notifier em execução. Pressione Ctrl+C para parar.")
    try:
        while True:
            time.sleep(30)
    except KeyboardInterrupt:
        log.info("Parando serviço...")
    finally:
        watch.unsubscribe()
        log.info("Listener cancelado.")


if __name__ == "__main__":
    main()
