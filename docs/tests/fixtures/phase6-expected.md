# Phase 6 expected risks — cocina-media-center-blueprint.md

Expected risks detected (scan build order section):
- Paso 3: "Configurar audio Bluetooth" → signal: "Bluetooth" → risk: external hardware dependency
- Paso 4: "Instalar y configurar spotifyd" + mentions credentials → signal: Third-party API → risk: credentials required before session
- Paso 8 (or similar): Deploy/systemd → signal: Deploy → risk: requires system config

Expected output:
---
⚠️  RIESGOS DETECTADOS

⚠️  Paso 3 (audio Bluetooth) — dependencia de hardware externo, tener el parlante disponible antes
⚠️  Paso 4 (spotifyd) — requiere credenciales de Spotify antes de la sesión
⚠️  Paso 10 (deploy/systemd) — cambios a nivel sistema, revisar manualmente después
---
