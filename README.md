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