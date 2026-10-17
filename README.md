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

O endereço padrão da API é `http://10.0.2.2:3333/api`, adequado ao emulador Android com a API local na porta 3333. Para outros ambientes, passe a URL base incluindo `/api`:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3333/api
```

No simulador iOS, `localhost` aponta para a máquina de desenvolvimento. Em um aparelho físico, use o IP local do computador, por exemplo `http://192.168.1.20:3333/api`, e permita conexões pela rede local. Para produção, configure uma URL HTTPS.

## Verificar

```bash
flutter analyze
flutter test
```

As telas de estações, detalhes e relatos consomem os endpoints públicos da API. Login, cadastro e envio de relatos usam autenticação Bearer; o token é guardado no armazenamento seguro nativo do dispositivo.