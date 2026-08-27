/// Quem falou uma mensagem numa conversa com a MOLLY.
enum MollyAutor { usuario, assistente }

/// Uma mensagem de uma conversa com a MOLLY (texto ou transcrição de voz).
///
/// Usada como memória de curto prazo por [MollyAgentService] — uma lista
/// dessas é convertida em pares (usuário, assistente) antes de ser mandada
/// ao backend de IA. O armazenamento de longo prazo (Firestore) é
/// responsabilidade de uma camada futura (ver TAREFA 7/8 do prompt mestre
/// da MOLLY e `docs/MOLLY_ARCHITECTURE_ANALYSIS.md`), não deste modelo.
class MollyMessage {
  final MollyAutor autor;
  final String texto;
  final DateTime quando;

  MollyMessage({
    required this.autor,
    required this.texto,
    DateTime? quando,
  }) : quando = quando ?? DateTime.now();

  MollyMessage.usuario(String texto) : this(autor: MollyAutor.usuario, texto: texto);

  MollyMessage.assistente(String texto) : this(autor: MollyAutor.assistente, texto: texto);
}
