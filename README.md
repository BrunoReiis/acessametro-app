# AcessaMetrô App

Aplicativo Flutter para consultar estações e relatos de acessibilidade, criar uma conta e enviar ocorrências pela API AcessaMetrô.

## Requisitos

- Flutter 3.41 ou superior
- Android SDK para compilar e executar no Android
- Xcode em macOS para compilar e executar no iOS
- API AcessaMetrô em execução ou publicada

## Executar

Na raiz do aplicativo:

```bash
flutter pub get
flutter run
```

O app usa por padrão a API publicada em `https://acessametro-api.vercel.app/api`. Para desenvolver com a API local, passe a URL base incluindo `/api`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3333/api
```

`10.0.2.2` aponta para a máquina host no emulador Android. No simulador iOS, use `http://localhost:3333/api`. Em um aparelho físico, use o IP local do computador, por exemplo `http://192.168.1.20:3333/api`, e permita conexões pela rede local.

## Verificar

```bash
flutter analyze
flutter test
```

As telas de estações, detalhes e relatos consomem os endpoints públicos da API. Login, cadastro e envio de relatos usam autenticação Bearer; o token é guardado no armazenamento seguro nativo do dispositivo.

O app usa Firebase Cloud Messaging (FCM) para avisar sobre novos relatos ativos
de elevador, escada rolante ou acessibilidade em estações favoritas. Push exige
uma conta autenticada, permissão de notificações e configuração do Firebase no
app e na API. Configure as opções públicas do app no build:

```powershell
flutter run `
  --dart-define=FIREBASE_PROJECT_ID=seu-projeto `
  --dart-define=FIREBASE_API_KEY=sua-api-key `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=seu-sender-id `
  --dart-define=FIREBASE_ANDROID_APP_ID=seu-app-id-android `
  --dart-define=FIREBASE_IOS_APP_ID=seu-app-id-ios `
  --dart-define=FIREBASE_IOS_BUNDLE_ID=com.acessametro.acessametroApp
```

Obtenha os valores em Firebase Console > Configurações do projeto > Seus apps.
Cadastre Android `com.acessametro.acessametro_app` e iOS
`com.acessametro.acessametroApp`. No iOS, configure uma chave APNs em Cloud
Messaging. As chaves de configuração do app não são credenciais administrativas;
**nunca** coloque a chave privada da conta de serviço Firebase no app.
Favoritos feitos sem login permanecem locais e passam a receber push após entrar
na conta. Para testar push, use um dispositivo real ou emulador com Google Play
Services; o envio de push não é simulado pelos testes Flutter.

## Planejamento de rotas

O app consulta a API AcessaMetrô, que encaminha as coordenadas selecionadas ao
Transitous para obter itinerários e trechos de transporte. A disponibilidade
depende dos feeds e da cobertura do Transitous. Os dados das rotas são
atribuídos a [Transitous e suas fontes](https://transitous.org/sources/), e o
mapa usa [OpenStreetMap](https://www.openstreetmap.org/copyright).

O Transitous permite o uso da API somente em projetos não comerciais com
código-fonte publicado sob uma licença de código aberto. Consulte a
[política da API](https://transitous.org/api/) antes de publicar ou implantar
o app.