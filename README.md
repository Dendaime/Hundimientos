# Hundimientos

Juego de **Batalla Naval** con multijugador local sin internet vía **Bluetooth Low Energy (BLE)**, compatible entre **Android e iOS/iPadOS**.

## Características
- **Host BLE (Peripheral)** y **Cliente BLE (Central)** usando un servicio GATT propio (`7a1b0001-4c2d-4e3f-9a5b-6c7d8e9f0001`).
- Protocolo compacto (≤ 20 bytes) compatible con el MTU estándar de BLE.
- Modo **vs Bot (Offline)** para probar en un solo dispositivo.
- Listo para compilar en **Codemagic** (`codemagic.yaml`) generando:
  - `Hundimientos-unsigned.ipa` para instalar en iPhone/iPad vía **Sideloadly** o **AltStore**.
  - `app-release.apk` para instalar directamente en Android.

## Cómo compilar en Codemagic
1. Conecta este repositorio (`Dendaime/Hundimientos`) en tu cuenta de [Codemagic](https://codemagic.io).
2. Selecciona el archivo `codemagic.yaml`.
3. Ejecuta el workflow **`iOS Unsigned IPA (Sideloadly / AltStore)`** para obtener el `.ipa` (o **`Android Release APK`** para Android).
4. Instala el `.ipa` en tu iPhone y iPad desde Windows con **Sideloadly** usando tu Apple ID.
