/// Nível de risco de uma ferramenta da MOLLY (TAREFA 4 do prompt mestre).
///
/// Esta enum carrega só o METADADO de cada ferramenta em
/// `MollyToolRegistry`. A política de quando exigir confirmação por causa
/// do risco — LOW executa direto, MEDIUM confirma quando há ambiguidade,
/// CRITICAL sempre confirma (exceto um gatilho explícito de emergência já
/// autorizado, como "SOCORRO") — é decidida por quem despacha a
/// ferramenta (`molly_controller.dart`, ainda não construído), não aqui.
enum MollyRiskLevel { low, medium, critical }
