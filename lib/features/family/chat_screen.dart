import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../models/family_member.dart';
import '../../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final FamilyMember member;
  const ChatScreen({super.key, required this.member});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isUploading = false;
  DateTime? _recordingStart;
  String? _playingId;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _hasText => _ctrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _durationTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text;
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    await ChatService.send(widget.member.uid, text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<bool> _startRecording() async {
    final has = await _recorder.hasPermission();
    if (!has) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de microfone negada.')),
        );
      }
      return false;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (mounted) {
      setState(() {
        _isRecording = true;
        _recordingStart = DateTime.now();
        _recordingDuration = Duration.zero;
      });
    }
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isRecording) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
      }
    });
    return true;
  }

  Future<void> _stopAndSend() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    final path = await _recorder.stop();
    final start = _recordingStart;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingStart = null;
        _recordingDuration = Duration.zero;
      });
    }
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    final duration = start == null
        ? 0
        : DateTime.now().difference(start).inMilliseconds;

    setState(() => _isUploading = true);
    try {
      await ChatService.sendAudio(widget.member.uid, file, durationMs: duration);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao enviar áudio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
      try { await file.delete(); } catch (_) {}
    }
  }

  Future<void> _togglePlay(ChatMessage m) async {
    if (m.audioUrl == null) return;
    if (_playingId == m.id) {
      await _player.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    await _player.stop();
    await _player.play(UrlSource(m.audioUrl!));
    if (mounted) setState(() => _playingId = m.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member.nome),
        backgroundColor: const Color(0xFF4A90D9),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.stream(widget.member.uid),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data!;
                if (msgs.isEmpty) {
                  return const Center(
                    child: Text('Sem mensagens ainda. Diga olá!'),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) => _bubble(msgs[i]),
                );
              },
            ),
          ),
          if (_isRecording)
            Container(
              color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Gravando ${_formatDuration(_recordingDuration)} — solte para enviar',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          if (_isUploading)
            const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      enabled: !_isRecording,
                      decoration: const InputDecoration(
                        hintText: 'Mensagem...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  // Um único botão: microfone (segurar para gravar) quando o
                  // campo está vazio, ou enviar quando há texto digitado —
                  // evita dois botões de ação ambíguos lado a lado.
                  _hasText
                      ? IconButton(
                          icon: const Icon(Icons.send, color: Color(0xFF4A90D9)),
                          onPressed: _send,
                        )
                      : GestureDetector(
                          onLongPressStart: (_) async {
                            if (!_isUploading && !_isRecording) {
                              await _startRecording();
                            }
                          },
                          onLongPressEnd: (_) async {
                            if (_isRecording) await _stopAndSend();
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? Colors.red.shade100
                                  : const Color(0xFFEDE7F6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isRecording ? Icons.stop_circle : Icons.mic,
                              color: _isRecording ? Colors.red : const Color(0xFF7B5EA7),
                              size: 26,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _bubble(ChatMessage m) {
    final mine = m.senderUid == _myUid;
    final bg = mine ? const Color(0xFF4A90D9) : Colors.grey.shade200;
    final fg = mine ? Colors.white : Colors.black87;

    Widget content;
    if (m.type == 'audio' && m.audioUrl != null) {
      final playing = _playingId == m.id;
      final secs = ((m.durationMs ?? 0) / 1000).round();
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              playing ? Icons.pause_circle : Icons.play_circle,
              color: fg,
              size: 32,
            ),
            onPressed: () => _togglePlay(m),
          ),
          const SizedBox(width: 6),
          Text('Áudio · ${secs}s', style: TextStyle(color: fg)),
        ],
      );
    } else {
      content = Text(m.text, style: TextStyle(color: fg));
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: content,
      ),
    );
  }
}
