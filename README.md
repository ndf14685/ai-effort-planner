# ai-effort-planner

Plugin de Claude Code que convierte un blueprint de proyecto en un plan de ejecución autónoma con agente diario.

---

## Qué hace

Dado un blueprint generado por **The Architect** (u otro generador de blueprints), el skill:

1. Lee el blueprint y calcula automáticamente un score de esfuerzo (5–25 puntos) en 5 dimensiones
2. Te hace 3 preguntas para completar el score
3. Presenta opciones de timeline (Intensivo / Moderado / Relajado)
4. Detecta riesgos en los build steps (auth, deploy, credenciales externas, migraciones, etc.)
5. Genera 4 archivos que permiten al agente ejecutarse solo cada día via cron

### Flujo completo

```
The Architect → blueprint.md → /ai-effort-planner → artefactos + instrucción de cron
                                                              ↓
                                         ai-runner.sh dispara diariamente a la hora configurada
                                         claude -p lee .ai-handoff.md
                                         el agente escribe código, hace commit y push
                                         el agente escribe el .ai-handoff.md del día siguiente
                                         duerme hasta mañana
```

### Archivos generados

| Archivo | Descripción |
|---------|-------------|
| `ai-plan.md` | Steps del blueprint distribuidos por sesión y fecha |
| `.ai-progress.json` | Estado de ejecución — qué completó, en qué sesión está |
| `.ai-handoff.md` | Prompt diario del agente: misión de hoy + reglas de ejecución |
| `ai-runner.sh` | Script bash invocado por cron — hace pull, llama a claude, loguea |

---

## Instalación

```bash
/plugin install ai-effort-planner@claude-plugins-official
```

O desde el menú: `/plugin` → Discover → buscar `ai-effort-planner`.

---

## Cómo ejecutarlo

### Opción 1 — Slash command (con argumento)

```
/ai-effort-planner output/mi-proyecto-blueprint.md
```

### Opción 2 — Sin argumento (detecta el blueprint más reciente en `output/`)

```
/ai-effort-planner
```

### Opción 3 — Por frase natural (el skill se activa automáticamente)

Decirle a Claude cualquiera de estas frases:

- `"estimate effort"`
- `"plan the AI work"`
- `"set up daily runner"`
- `"how long will this take with AI"`

---

## Sesión interactiva

El skill te guía en 8 fases. Aproximadamente así:

```
Leí el blueprint "mi-proyecto". Tiene 14 build steps y 4 tecnologías.
Score preliminar: 8/25 (tamaño: 3, stack: 3).

¿El repo ya existe con código, o es proyecto nuevo?
```

Respondés 3 preguntas de scoring + 3 de configuración (tokens/día, hora de arranque, urgencia), elegís el timeline y el skill genera todo.

---

## Score de esfuerzo

5 dimensiones, cada una de 1 a 5 puntos (total 5–25):

| Dimensión | 1 — Bajo | 3 — Medio | 5 — Alto |
|-----------|----------|-----------|----------|
| Tamaño | <8 steps | 8–18 steps | >18 steps |
| Stack | 1–2 tecnologías | 3–5 | 6+ / microservicios |
| Estado del repo | proyecto nuevo | repo chico | repo grande con deuda |
| Claridad de reqs | 100% definidos | mayormente claros | exploratorio |
| Densidad de contexto | módulos aislados | dependencias moderadas | muy acoplado |

| Score | Nivel | Sesiones estimadas |
|-------|-------|--------------------|
| 5–9 | Bajo | 3–8 |
| 10–14 | Medio | 8–20 |
| 15–19 | Alto | 20–40 |
| 20–25 | Muy Alto | 40–60 |

---

## Activar el runner diario

Al final de la sesión el skill muestra el comando exacto. En general:

```bash
crontab -e
# Agregar:
0 4 * * * /ruta/al/proyecto/ai-runner.sh

# Verificar:
crontab -l

# Monitorear:
tail -f /ruta/al/proyecto/ai-runner.log
```

Para pausar: comentar la línea en `crontab -e` con `#`.
Para retomar: descomentar.

---

## Tests

```bash
bash docs/tests/test-runner.sh
```

Cubre 8 casos: completion normal, timeout, error de git pull, handoff faltante, proyecto completado, permisos del log, y promoción de `.ai-handoff.next.md`.
