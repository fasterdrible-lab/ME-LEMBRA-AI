/// Membro da família vinculado ao usuário atual.
class FamilyMember {
  final String uid;
  final String nome;
  final String perfil;
  final String papel; // 'cuidador' | 'monitorado'
  final DateTime? vinculadoEm;

  const FamilyMember({
    required this.uid,
    required this.nome,
    required this.perfil,
    required this.papel,
    this.vinculadoEm,
  });

  factory FamilyMember.fromMap(String uid, Map<String, dynamic> data) {
    final ts = data['vinculadoEm'];
    DateTime? when;
    if (ts is DateTime) {
      when = ts;
    } else if (ts != null) {
      try {
        when = (ts as dynamic).toDate() as DateTime;
      } catch (_) {}
    }
    return FamilyMember(
      uid: uid,
      nome: (data['nome'] as String?) ?? 'Sem nome',
      perfil: (data['perfil'] as String?) ?? '',
      papel: (data['papel'] as String?) ?? 'cuidador',
      vinculadoEm: when,
    );
  }

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'perfil': perfil,
        'papel': papel,
        'vinculadoEm': vinculadoEm,
      };
}
