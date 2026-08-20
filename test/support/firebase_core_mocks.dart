import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake do host API (Pigeon) do `firebase_core` para permitir que
/// `Firebase.initializeApp()` funcione em testes de widget, sem precisar
/// de um app Firebase real nem de plugins nativos.
///
/// Usado por testes que exercitam telas cujo caminho de codigo toca em
/// `FirebaseAuth.instance` / `Firebase.app()` (ex.: ProfileSelectionScreen),
/// para evitar o erro `[core/no-app] No Firebase App '[DEFAULT]' has been
/// created`.
class _FakeFirebaseCoreHostApi implements TestFirebaseCoreHostApi {
  static final _fakeOptions = CoreFirebaseOptions(
    apiKey: 'fake-api-key',
    appId: 'fake-app-id',
    messagingSenderId: 'fake-sender-id',
    projectId: 'fake-project-id',
  );

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async {
    return CoreInitializeResponse(
      name: appName,
      options: initializeAppRequest,
      pluginConstants: const {},
    );
  }

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    return [
      CoreInitializeResponse(
        name: '[DEFAULT]',
        options: _fakeOptions,
        pluginConstants: const {},
      ),
    ];
  }

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async => _fakeOptions;
}

/// Instala o mock do `firebase_core` e garante o binding de testes
/// inicializado. Deve ser chamado no `setUp`/inicio do teste, antes de
/// `Firebase.initializeApp()`.
void setupFirebaseCoreMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(_FakeFirebaseCoreHostApi());
}
