# Phase 4+5 expected output

Given: sessions = 11, user answers: 1M tokens/day, 04:00, no urgency

Expected timeline options displayed:
```
─────────────────────────────────────────────────────────
  OPCIONES DE TIMELINE — cocina-media-center (Nivel Medio)
  Sesiones estimadas totales: 11
─────────────────────────────────────────────────────────
  🚀 INTENSIVO     6 días   2x steps/sesión   ~18% cuota/sesión  (1 cron, más steps por sesión)
  ✅ MODERADO     11 días   1x steps/sesión    ~9% cuota/sesión  ← recomendado
  😌 RELAJADO     17 días   0.5x steps/sesión  ~6% cuota/sesión  (días de pausa intercalados)
─────────────────────────────────────────────────────────
  Recomiendo MODERADO: una sesión por día es lo más predecible.
  El agente tiene contexto fresco cada vez y el commit-por-día
  hace fácil revisar el avance.
─────────────────────────────────────────────────────────
¿Cuál elegís? (o decime cuántos días y lo calculo)
```

Calculation derivation:
- intensivo_days = ceil(11/2) = 6
- moderado_days = 11
- relajado_days = ceil(11*1.5) = 17
- moderado_pct = round(100/11) = 9
- intensivo_pct = round(9*2) = 18
- relajado_pct = round(9*0.66) = 6
