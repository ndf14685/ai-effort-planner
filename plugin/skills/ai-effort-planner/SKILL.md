---
name: ai-effort-planner
description: >
  Use after The Architect generates a blueprint. Estimates AI effort,
  presents timeline options, and sets up the daily autonomous executor.
  Trigger when user says "estimate effort", "plan the AI work",
  "set up daily runner", or "how long will this take with AI".
argument-hint: [blueprint-path]
allowed-tools: [Read, Write, Bash, Edit]
---

# ai-effort-planner

Estimate AI effort for a project and set up autonomous daily execution.
Follow these phases in order. Do not skip any phase.

---

## Phase 1: Locate and Read Blueprint

**Locate the blueprint:**
- If an argument was provided, read that file path directly.
- If no argument: run `ls output/*.md` and read the most recently modified file.
- If no file found: ask the user for the blueprint path and stop until they provide it.

**Extract from the blueprint:**
1. Count the numbered build steps in the **Build Order** section (look for "Paso N" or "Step N" or "**Step N:**" or "**Paso N:**").
2. Count the data rows (non-header) in the **Tech Stack** table.

**Calculate preliminary score:**

| Steps count | size_score |
|-------------|------------|
| Less than 8 | 1 |
| 8 to 18 | 3 |
| More than 18 | 5 |

| Stack rows | stack_score |
|------------|-------------|
| 1 or 2 | 1 |
| 3 to 5 | 3 |
| 6 or more | 5 |

preliminary_score = size_score + stack_score

**Announce to the user:**

```
Leí el blueprint **[project name]**. Tiene **[N] build steps** y **[M] tecnologías** en el stack.
Score preliminar: **[preliminary_score]/25** (tamaño: [size_score], stack: [stack_score]).
```

Then immediately ask Question 1 from Phase 2 (do not wait for the user to prompt you).

---

## Phase 2: Complete the Score (3 Questions — one at a time)

Ask these questions one at a time. Wait for the user's answer before asking the next.

**Question 1:** "¿El repo ya existe con código, o es proyecto nuevo?"
- "nuevo" / "no existe" → repo_score = 1
- "existe" + mentions small/chico → repo_score = 3
- "existe" + mentions large/grande/deuda → repo_score = 5
- If unclear: ask "¿Es chico (<5k líneas) o grande?"

**Question 2:** "¿Los requerimientos están 100% definidos o puede cambiar el scope?"
- "definidos" / "100%" / "claro" → clarity_score = 1
- "mayormente" / "mostly" / "casi" → clarity_score = 3
- "exploratorio" / "puede cambiar" / "no sé" → clarity_score = 5

**Question 3:** "¿El proyecto tiene módulos bien aislados, o hay muchas dependencias entre archivos?"
- "aislados" / "independientes" / "modular" → density_score = 1
- "moderado" / "algunas dependencias" → density_score = 3
- "acoplado" / "todo depende de todo" / "legacy" → density_score = 5

---

## Phase 3: Display Classification

After receiving all 3 answers, calculate:

```
total_score = size_score + stack_score + repo_score + clarity_score + density_score
```

Determine level and session estimate:

| Score range | Level | Session range | Formula |
|-------------|-------|---------------|---------|
| 5–9 | Bajo | 3–8 | 3 + ((score-5)/4 × 5) |
| 10–14 | Medio | 8–20 | 8 + ((score-10)/4 × 12) |
| 15–19 | Alto | 20–40 | 20 + ((score-15)/4 × 20) |
| 20–25 | Muy Alto | 40–60 | 40 + ((score-20)/5 × 20) |

Round sessions to nearest integer.

Display:

```
**Score: [total]/25 · Nivel: [level] · Sesiones estimadas: [sessions]**
```

Then immediately ask Question 1 from Phase 4.

---

## Phase 4: Execution Setup (3 Questions — one at a time)

**Question 1:** "¿Cuántos tokens/día tenés disponibles para este proyecto? (ej: 500k, 1M, 2M — no necesita ser exacto)"
- Store as daily_tokens (string, kept as a reference label only — not used for hard limits)

**Question 2:** "¿A qué hora querés que arranque el agente cada día? (ej: 04:00, 06:00, 22:00)"
- Store as daily_time (HH:MM format — validate format, ask again if invalid)

**Question 3:** "¿Tenés deadline o urgencia? Podés decirme (A) sin apuro — recomendame vos, o (B) lo quiero en N días — decime cuántos."
- (A) → present 3 options from Phase 5
- (B) → calculate custom timeline and skip to Phase 5 confirmation

---

## Phase 5: Timeline Options

Calculate the three options based on sessions count:

```
intensivo_days = ceil(sessions / 2)           — 2x steps per session
moderado_days  = sessions                      — 1x steps per session (recommended)
relajado_days  = ceil(sessions * 1.5)         — alternate days
```

For percentage display (informational only, not a hard limit):
```
moderado_pct   = round(100 / sessions)
intensivo_pct  = round(moderado_pct * 2)
relajado_pct   = round(moderado_pct * 0.66)
```

Display:

```
─────────────────────────────────────────────────────────
  OPCIONES DE TIMELINE — [project name] ([level])
  Sesiones estimadas totales: [sessions]
─────────────────────────────────────────────────────────
  🚀 INTENSIVO   [intensivo_days] días   2x steps/sesión   ~[intensivo_pct]% cuota/sesión  (1 cron, más steps por sesión)
  ✅ MODERADO    [moderado_days] días    1x steps/sesión   ~[moderado_pct]% cuota/sesión  ← recomendado
  😌 RELAJADO    [relajado_days] días   0.5x steps/sesión  ~[relajado_pct]% cuota/sesión  (días de pausa intercalados)
─────────────────────────────────────────────────────────
  Recomiendo MODERADO: una sesión por día es lo más predecible.
  El agente tiene contexto fresco cada vez y el commit-por-día
  hace fácil revisar el avance.
─────────────────────────────────────────────────────────
¿Cuál elegís? (o decime cuántos días y lo calculo)
```

Wait for the user's choice. Store as chosen_option (intensivo/moderado/relajado/custom) and chosen_days.

Confirm: "Perfecto — **[chosen_days] días**, arrancando el **[tomorrow's date]** a las **[daily_time]**. Ahora analizo los riesgos y genero los archivos."

Then proceed immediately to Phase 6.

---

## Phase 6: Risk Detection

Scan every build step in the blueprint's Build Order section. For each step, check for these signals:

| Signal (case-insensitive) | Risk label |
|--------------------------|------------|
| auth, oauth, sso, login, jwt, session | Alto contexto — puede necesitar 2 sesiones |
| deploy, ci/cd, dns, nginx, systemd, pm2, docker | Requiere config de sistema — revisar manualmente |
| migration, existing data, alter table, backup | Cambios destructivos — revisar antes de ejecutar |
| api key, secret, credentials, token, webhook, third-party, spotify, stripe, clerk, google | Credenciales externas — tener listas antes de la sesión |
| bluetooth, hardware, raspberry, gpio, sensor, device | Dependencia de hardware — tener el dispositivo disponible |
| step description longer than 250 words | Tarea muy grande — considerar dividirla antes de empezar |

Collect all flagged steps. If none found, skip the risk section silently.

Format the risk output as:
```
⚠️  RIESGOS DETECTADOS

⚠️  [Step name] ([brief description]) — [risk label]
⚠️  [Step name] ([brief description]) — [risk label]
```

Store risks as risks_list for inclusion in the final output box.

Then proceed immediately to Phase 7.

---

## Phase 7: Generate Artifacts

Generate all 4 files. All paths are relative to the project root (the directory containing the blueprint).

### 7a. Generate ai-plan.md

Distribute the blueprint's build steps across sessions:
- Total steps = N (from blueprint)
- Total sessions = sessions (from Phase 3)
- Base steps per session = floor(N / sessions)
- Extra steps = N mod sessions (distribute 1 extra to the first `extra` sessions)
- If steps > sessions: first `(steps mod sessions)` sessions get one extra step each
- If steps < sessions: last `(sessions - steps)` sessions are marked as "rest day" with no tasks
- Start date = tomorrow's date (today + 1 day)
- Each session date = start_date + (session_index - 1) days

For INTENSIVO: base_steps_per_session × 2 per session, sessions = intensivo_days
For RELAJADO: every other calendar day has a session — odd session_index days work, even days rest.
  Session 1 → start_date, Session 2 → start_date + 2, Session 3 → start_date + 4, etc.

Write to `ai-plan.md`:

```markdown
# AI Execution Plan — [project name]
Score: [score]/25 · Nivel: [level] · Sesiones: [sessions] · Timeline: [chosen_days] días
Inicio: [start_date] · Hora diaria: [daily_time]

## Sesión 1 — [date]
- [ ] [Step name from blueprint]
- [ ] [Step name from blueprint]  (if this session has 2 steps)

## Sesión 2 — [date]
- [ ] [Step name from blueprint]

[... one section per session, all steps assigned]
```

### 7b. Generate .ai-progress.json

Write to `.ai-progress.json`:

```json
{
  "project": "[project name from blueprint title]",
  "blueprint": "[relative path to blueprint file]",
  "score": [score],
  "level": "[level]",
  "total_sessions": [sessions],
  "total_days": [chosen_days],
  "daily_time": "[daily_time]",
  "timeout_hours": 4,
  "start_date": "[start_date]",
  "current_session": 1,
  "completed_steps": [],
  "pending_steps": [array of step numbers 1..N],
  "last_run": null,
  "status": "ready",
  "blockers": []
}
```

### 7c. Generate .ai-handoff.md

Write to `.ai-handoff.md`:

```markdown
# AI Daily Handoff — Sesión 1 / [sessions]
Fecha: [start_date] · Proyecto: [project name]

## Tu misión de hoy
Completar los siguientes steps del blueprint:
[list today's steps from ai-plan.md Session 1]

Lee el blueprint completo en: [blueprint path]
Lee el estado actual en: .ai-progress.json

## Contexto de sesión anterior
[Primera sesión — sin historial previo]

## Reglas de ejecución
1. Trabajá en orden. No avances al siguiente step sin terminar el actual.
2. Cuando completes un step, marcalo en .ai-progress.json (mueve el número de pending_steps a completed_steps).
3. Si algo está bloqueado, documentalo en .ai-progress.json bajo "blockers" y seguí con el próximo step disponible.
4. Al terminar tus steps asignados (o si llegás al timeout de 4 horas):
   a. git add -A
   b. git commit -m "ai: session [N] — [step names] complete"
   c. git push origin main
   d. Actualizar .ai-progress.json: incrementar current_session, actualizar last_run con fecha actual
   e. Escribir el nuevo .ai-handoff.md para la próxima sesión (siguiente sesión de ai-plan.md)
   f. Hacer un último git add + commit + push con los archivos de estado
   g. Parar.

## No hagas
- No toques steps que no son de hoy
- No refactorices código que no es parte de tu step
- No pidas confirmación — tomá decisiones y avanzá
- No instales dependencias globales sin verificar si ya están instaladas

## ÚLTIMA SESIÓN (solo si current_session === total_sessions)
Esta es la sesión final del plan. Al terminar:
1. Completar todos los steps pendientes que queden
2. git add -A && git commit -m "ai: final session — project complete"
3. git push origin main
4. Actualizar .ai-progress.json: status → "completed", last_run → fecha actual
5. Escribir en .ai-handoff.md: "# Proyecto completado\nTodas las sesiones ejecutadas. No hay trabajo pendiente."
6. git add -A && git commit -m "ai: mark project as completed" && git push
7. Parar — no generar nueva sesión.
```

### 7d. Generate ai-runner.sh

Write to `ai-runner.sh` and make it executable with `chmod +x ai-runner.sh`:

```bash
#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$PROJECT_DIR/ai-runner.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ====== Starting daily session ======" >> "$LOG"

cd "$PROJECT_DIR"

# Pull latest before starting
git pull origin main >> "$LOG" 2>&1

# Run the agent with 4-hour timeout
timeout 14400 claude --dangerously-skip-permissions \
  -p "$(cat .ai-handoff.md)" >> "$LOG" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Session ended by timeout (4h limit reached)" >> "$LOG"
elif [ $EXIT_CODE -eq 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Session completed normally" >> "$LOG"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Session ended with exit code $EXIT_CODE" >> "$LOG"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ====== Session done ======" >> "$LOG"
```

Then proceed immediately to Phase 8.

---

## Phase 8: Final Output

Display this summary box:

```
╔══════════════════════════════════════════════════════════╗
║         AI EFFORT PLAN — [PROJECT NAME]                  ║
╠══════════════════════════════════════════════════════════╣
║  Score:      [score]/25                                  ║
║  Nivel:      [level]                                     ║
║  Sesiones:   [sessions]                                  ║
║  Timeline:   [chosen_days] días ([chosen_option])        ║
║  Inicio:     [start_date] a las [daily_time]             ║
╠══════════════════════════════════════════════════════════╣
║  RIESGOS DETECTADOS                                      ║
[For each risk: ║  ⚠️  [step] — [risk label]                              ║]
[If no risks:   ║  ✅ Sin riesgos detectados                              ║]
╠══════════════════════════════════════════════════════════╣
║  ARCHIVOS GENERADOS                                      ║
║  ✅ ai-plan.md                                           ║
║  ✅ .ai-progress.json                                    ║
║  ✅ .ai-handoff.md                                       ║
║  ✅ ai-runner.sh                                         ║
╠══════════════════════════════════════════════════════════╣
║  PRÓXIMO PASO — activar el runner diario:                ║
║                                                          ║
║  crontab -e                                              ║
║                                                          ║
║  Agregar esta línea:                                     ║
║  [cron_minute] [cron_hour] * * * [full_path]/ai-runner.sh║
║                                                          ║
║  Verificar: crontab -l                                   ║
║  Monitorear: tail -f [full_path]/ai-runner.log           ║
╚══════════════════════════════════════════════════════════╝
```

Where:
- cron_hour = first part of daily_time (e.g., "04" from "04:00")
- cron_minute = second part (e.g., "00" from "04:00")
- full_path = absolute path to the project directory (run `pwd` to get it if not known)

After displaying the box, add this note:

```
El agente arranca el [start_date] a las [daily_time].
Podés ver el progreso en cualquier momento con: tail -f ai-runner.log
Para pausar: crontab -e y comentar la línea con #.
Para retomar: descomentar la línea.
```
