import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Mensagem de chat entre dois familiares (texto ou áudio).
class ChatMessage {
  final String id;
  final String senderUid;
  final String text;
  final String type; // 'text' | 'audio'
  final String? audioUrl;
  final int? durationMs;
  final DateTime? sentAt;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    this.type = 'text',
    this.audioUrl,
    this.durationMs,
    this.sentAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? const {};
    final ts = data['sentAt'];
    DateTime? when;
    if (ts is Timestamp) when = ts.toDate();
    return ChatMessage(
      id: d.id,
      senderUid: (data['senderUid'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'text',
      audioUrl: data['audioUrl'] as String?,
      durationMs: (data['durationMs'] as num?)?.toInt(),
      sentAt: when,
    );
  }
}

/// Chat 1-a-1 entre familiares. Usa um id determinístico (uids ordenados).
class ChatService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static String pairId(String a, String b) {
    final list = [a, b]..sort();
    return '${list[0]}_${list[1]}';
  }

  static CollectionReference<Map<String, dynamic>> _messages(String otherUid) {
    final me = FirebaseAuth.instance.currentUser!.uid;
    return _db
        .collection('chats')
        .doc(pairId(me, otherUid))
        .collection('messages');
  }

  static Stream<List<ChatMessage>> stream(String otherUid) {
    return _messages(otherUid)
        .orderBy('sentAt', descending: false)
        .limit(200)
        .snapshots()
        .map((qs) => qs.docs.map(ChatMessage.fromDoc).toList());
  }

  static Future<void> send(String otherUid, String text) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final clean = text.trim();
    if (clean.isEmpty) return;
    await _messages(otherUid).add({
      'senderUid': me.uid,
      'text': clean,
      'type': 'text',
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  /// Faz upload do arquivo de áudio para o Firebase Storage e cria a mensagem.
  static Future<void> sendAudio(
    String otherUid,
    File file, {
    int? durationMs,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final pid = pairId(me.uid, otherUid);
    final filename = '${DateTime.now().millisecondsSinceEpoch}.m4a';
    final ref = _storage.ref('chats/$pid/$filename');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    await _messages(otherUid).add({
      'senderUid': me.uid,
      'text': '',
      'type': 'audio',
      'audioUrl': url,
      'durationMs': durationMs ?? 0,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }
}
