# DOCUMENTACAO ME LEMBRA AI - Flutter

## SERVIDOR VPS
- Provedor: Hetzner
- IP: 204.168.180.25
- OS: Ubuntu 4GB RAM - Helsinki (hel1)
- Usuario: root

## PROJETO
- Caminho: /root/ME-LEMBRA-AI/me_lembra_ai
- Tecnologia: Flutter
- APK gerado: build/app/outputs/flutter-apk/app-release.apk (60.2MB)

## FIREBASE
- Projeto: ME LEMBRA AI
- ID: me-lembra-ai-bf0f0
- Plano: Spark gratuito
- ATENCAO: google-services.json NAO esta no GitHub - baixar em:
  https://console.firebase.google.com/project/me-lembra-ai-bf0f0/settings/general/android

## CORRECOES APLICADAS

### activeThumbColor invalido
sed -i 's/activeThumbColor:/activeColor:/g' lib/config_screen.dart

### withValues invalido
sed -i 's/\.withValues(alpha: \([0-9.]*\))/.withOpacity(\1)/g' lib/config_screen.dart
sed -i 's/\.withValues(alpha: \([0-9.]*\))/.withOpacity(\1)/g' lib/profile_selection_screen.dart

### minSdkVersion
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 23/' android/app/build.gradle.kts

### gradle.properties
org.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=512m
android.useAndroidX=true
android.enableJetifier=true

## GERAR APK
cd ~/ME-LEMBRA-AI/me_lembra_ai
swapon /swapfile
flutter build apk --release

## BAIXAR APK
cd /root/ME-LEMBRA-AI/me_lembra_ai/build/app/outputs/flutter-apk/
python3 -m http.server 8080
Acessar: http://204.168.180.25:8080/app-release.apk

## ATENCAO PROXIMA VEZ
1. Recolocar google-services.json manualmente
2. Rodar: swapon /swapfile (SWAP some apos reiniciar)
3. Rodar: flutter doctor
