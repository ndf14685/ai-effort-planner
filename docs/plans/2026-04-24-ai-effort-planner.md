# ai-effort-planner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `ai-effort-planner` Claude Code skill that reads a project blueprint, scores effort, presents timeline options, and generates four files that enable scheduled autonomous daily development.

**Architecture:** A single SKILL.md file guides Claude through a multi-phase conversation: auto-score from blueprint → 3 scoring questions → 3 execution questions → timeline options → risk scan → generate 4 artifacts (ai-plan.md, .ai-progress.json, .ai-handoff.md, ai-runner.sh) → show crontab instruction. The bash runner is a standalone script generated into the target project.

**Tech Stack:** SKILL.md (Claude instructions), Bash (ai-runner.sh), JSON (progress state)

---

## File Structure

| File | Responsibility |
|------|---------------|
| `~/.claude/plugins/ai-effort-planner/.claude-plugin/plugin.json` | Plugin metadata and registration |
| `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md` | The planner skill — all phases |
| `docs/superpowers/tests/fixtures/cocina-expected-plan.md` | Expected ai-plan.md for smoke test |
| `docs/superpowers/tests/test-runner.sh` | Tests ai-runner.sh timeout + log behavior |

**Generated artifacts (live in the target project, not here):**
- `<project>/ai-plan.md`
- `<project>/.ai-progress.json`
- `<project>/.ai-handoff.md`
- `<project>/ai-runner.sh`

---

## Task 1: Plugin scaffold

**Files:**
- Create: `~/.claude/plugins/ai-effort-planner/.claude-plugin/plugin.json`
- Create: `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/` (directory)

- [ ] **Step 1: Create plugin directory structure**

```bash
mkdir -p ~/.claude/plugins/ai-effort-planner/.claude-plugin
mkdir -p ~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner
```

Expected: no output, directories created.

- [ ] **Step 2: Write plugin.json**

Create `~/.claude/plugins/ai-effort-planner/.claude-plugin/plugin.json`:

```json
{
  "name": "ai-effort-planner",
  "version": "1.0.0",
  "description": "Estimates AI effort for development projects and sets up autonomous daily execution",
  "author": "ndf",
  "skills": [
    "skills/ai-effort-planner"
  ]
}
```

- [ ] **Step 3: Verify structure**

```bash
find ~/.claude/plugins/ai-effort-planner -type f -o -type d | sort
```

Expected output:
```
/home/ndf/.claude/plugins/ai-effort-planner
/home/ndf/.claude/plugins/ai-effort-planner/.claude-plugin
/home/ndf/.claude/plugins/ai-effort-planner/.claude-plugin/plugin.json
/home/ndf/.claude/plugins/ai-effort-planner/skills
/home/ndf/.claude/plugins/ai-effort-planner/skills/ai-effort-planner
```

- [ ] **Step 4: Commit**

```bash
cd ~/workspace/the-architect
git add -A
git commit -m "feat: add ai-effort-planner plugin scaffold"
```

---

## Task 2: SKILL.md — Frontmatter + Phase 1 (Blueprint Discovery)

**Files:**
- Create: `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md`

This task writes the opening of the skill: the frontmatter and the blueprint auto-detection + preliminary scoring logic.

- [ ] **Step 1: Write expected behavior for Phase 1 (defines the test)**

Create `docs/superpowers/tests/fixtures/phase1-expected.md`:

```markdown
# Phase 1 expected output — cocina-media-center-blueprint.md

Given: blueprint with 12 build steps, 10 tech stack rows

Expected Claude output:
---
Leí el blueprint **Cocina Media Center**. Tiene **12 build steps** y **10 tecnologías** en el stack.
Score preliminar: **8/25** (tamaño: 3, stack: 5).

3 preguntas para completar el score:

**1. ¿El repo ya existe con código, o es proyecto nuevo?**
---

Scoring derivation:
- size_score: 12 steps → 8-18 range → 3
- stack_score: 10 rows → 6+ range → 5
- preliminary: 8
```

```bash
cd ~/workspace/the-architect
git add docs/superpowers/tests/fixtures/phase1-expected.md
git commit -m "test: add Phase 1 expected output fixture"
```

- [ ] **Step 2: Write SKILL.md frontmatter + Phase 1**

Create `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md` with this exact content:

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add ~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md
cd ~/workspace/the-architect
git add -A
git commit -m "feat: add SKILL.md Phase 1 — blueprint discovery and auto-scoring"
```

---

## Task 3: SKILL.md — Phase 2 (Scoring questions) + Phase 3 (Classification)

**Files:**
- Modify: `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md`

- [ ] **Step 1: Write expected behavior for Phase 2+3 (defines the test)**

Create `docs/superpowers/tests/fixtures/phase2-expected.md`:

```markdown
# Phase 2+3 expected output — cocina, new project, 100% defined, isolated modules

Given: preliminary_score = 8
Answers: new project (1), 100% defined (1), isolated modules (1)

total_score = 8 + 1 + 1 + 1 = 11
Level: Medio (10-14)
Sessions: midpoint calculation → position = (11-10)/(14-10) = 0.25 → 8 + (0.25 × 12) = 11 sessions

Expected classification display:
---
**Score: 11/25 · Nivel: Medio · Sesiones estimadas: 11**
---
```

```bash
cd ~/workspace/the-architect
git add docs/superpowers/tests/fixtures/phase2-expected.md
git commit -m "test: add Phase 2+3 expected output fixture"
```

- [ ] **Step 2: Append Phase 2 and Phase 3 to SKILL.md**

Append to `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md`:

```markdown

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
```

- [ ] **Step 3: Commit**

```bash
cd ~/workspace/the-architect
git add -A
git commit -m "feat: add SKILL.md Phase 2+3 — scoring questions and classification"
```

---

## Task 4: SKILL.md — Phase 4 (Execution questions) + Phase 5 (Timeline options)

**Files:**
- Modify: `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md`

- [ ] **Step 1: Write expected behavior for Phase 4+5 (defines the test)**

Create `docs/superpowers/tests/fixtures/phase4-expected.md`:

```markdown
# Phase 4+5 expected output

Given: sessions = 11, user answers: 1M tokens/day, 04:00, no urgency

Expected timeline options displayed:
---
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
---

INTENSIVO = ceil(sessions/2) days, 2x normal steps per session
MODERADO = sessions days, 1 step-group per session
RELAJADO = ceil(sessions × 1.5) days, skip days (agent runs every other day)
```

```bash
cd ~/workspace/the-architect
git add docs/superpowers/tests/fixtures/phase4-expected.md
git commit -m "test: add Phase 4+5 expected output fixture"
```

- [ ] **Step 2: Append Phase 4 and Phase 5 to SKILL.md**

Append to `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md`:

```markdown

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
```

- [ ] **Step 3: Commit**

```bash
cd ~/workspace/the-architect
git add -A
git commit -m "feat: add SKILL.md Phase 4+5 — execution questions and timeline options"
```

---

## Task 5: SKILL.md — Phase 6 (Risk Detection)

**Files:**
- Modify: `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md`

- [ ] **Step 1: Write expected risk output for cocina blueprint (defines the test)**

Create `docs/superpowers/tests/fixtures/phase6-expected.md`:

```markdown
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
```

```bash
cd ~/workspace/the-architect
git add docs/superpowers/tests/fixtures/phase6-expected.md
git commit -m "test: add Phase 6 expected risk output fixture"
```

- [ ] **Step 2: Append Phase 6 to SKILL.md**

Append to `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md`:

```markdown

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
```

- [ ] **Step 3: Commit**

```bash
cd ~/workspace/the-architect
git add -A
git commit -m "feat: add SKILL.md Phase 6 — risk detection"
```

---

## Task 6: SKILL.md — Phase 7 (Artifact Generation)

**Files:**
- Modify: `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md`

This is the most critical phase — it generates the 4 files in the project directory.

- [ ] **Step 1: Define expected ai-plan.md for cocina (defines the test)**

Create `docs/superpowers/tests/fixtures/cocina-expected-plan.md`:

```markdown
# AI Execution Plan — cocina-media-center
Score: 11/25 · Nivel: Medio · Sesiones: 11 · Timeline: 11 días
Inicio: 2026-04-25 · Hora diaria: 04:00

## Sesión 1 — 2026-04-25
- [ ] Paso 1: Preparar la Raspberry Pi
- [ ] Paso 2: Instalar display mínimo (X11 + Openbox)

## Sesión 2 — 2026-04-26
- [ ] Paso 3: Configurar audio Bluetooth

## Sesión 3 — 2026-04-27
- [ ] Paso 4: Instalar y configurar spotifyd

## Sesión 4 — 2026-04-28
- [ ] Paso 5: [next step]

[... continues for all 12 steps, distributing 1 step per session except session 1 which gets 2 to account for 12 steps / 11 sessions]
```

```bash
cd ~/workspace/the-architect
git add docs/superpowers/tests/fixtures/cocina-expected-plan.md
git commit -m "test: add expected ai-plan.md fixture for cocina blueprint"
```

- [ ] **Step 2: Append Phase 7 to SKILL.md**

Append to `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md`:

```markdown

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
```

### 7d. Generate ai-runner.sh

Write to `ai-runner.sh` and make it executable:

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

After writing the file, run: `chmod +x ai-runner.sh`

### 7e. Final session — completion condition

The handoff template in 7c includes these rules for when current_session === total_sessions:

```markdown
## ÚLTIMA SESIÓN
Esta es la sesión final del plan. Al terminar:
1. Completar todos los steps pendientes que queden (aunque sean más de los asignados)
2. git add -A && git commit -m "ai: final session — project complete"
3. git push origin main
4. Actualizar .ai-progress.json: status → "completed", last_run → fecha actual
5. Escribir en .ai-handoff.md: "# Proyecto completado\nTodas las sesiones ejecutadas. No hay trabajo pendiente."
6. git add -A && git commit -m "ai: mark project as completed" && git push
7. Parar — no generar nueva sesión.
```

This prevents the runner from doing work when the project is already done (the next cron invocation will read the handoff, see "Proyecto completado", and exit without doing anything meaningful).

Then proceed to Phase 8.
```

- [ ] **Step 3: Commit**

```bash
cd ~/workspace/the-architect
git add -A
git commit -m "feat: add SKILL.md Phase 7 — artifact generation (all 4 files)"
```

---

## Task 7: SKILL.md — Phase 8 (Final Output)

**Files:**
- Modify: `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md`

- [ ] **Step 1: Append Phase 8 to SKILL.md**

Append to `~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md`:

```markdown

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
```

- [ ] **Step 2: Commit**

```bash
cd ~/workspace/the-architect
git add -A
git commit -m "feat: add SKILL.md Phase 8 — final output and crontab instructions"
```

---

## Task 8: Test ai-runner.sh behavior

**Files:**
- Create: `docs/superpowers/tests/test-runner.sh`

Test that `ai-runner.sh` logs correctly and handles the timeout exit code.

- [ ] **Step 1: Write the test script**

Create `docs/superpowers/tests/test-runner.sh`:

```bash
#!/bin/bash
# Tests ai-runner.sh behavior without running claude CLI
set -e

PASS=0
FAIL=0

pass() { echo "✅ $1"; PASS=$((PASS+1)); }
fail() { echo "❌ $1"; FAIL=$((FAIL+1)); }

# Setup temp project directory
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Create minimal project structure
mkdir -p "$TMPDIR/.git"
cat > "$TMPDIR/.ai-handoff.md" << 'EOF'
# Test handoff
Do nothing.
EOF

# Create fake git that does nothing
cat > "$TMPDIR/fake-git" << 'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$TMPDIR/fake-git"

# ---- Test 1: normal completion ----
# Create fake claude that exits 0
cat > "$TMPDIR/fake-claude" << 'EOF'
#!/bin/bash
echo "Claude executed with: $@"
exit 0
EOF
chmod +x "$TMPDIR/fake-claude"

# Copy runner and replace `claude` with fake-claude, `git` with fake-git
sed "s|claude --dangerously|$TMPDIR/fake-claude --|g; s|git pull|$TMPDIR/fake-git pull|g" \
  ~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/../../../ai-runner-template.sh \
  > "$TMPDIR/ai-runner.sh" 2>/dev/null || \
sed "s|claude --dangerously|$TMPDIR/fake-claude --|g; s|git pull|$TMPDIR/fake-git pull|g" \
  "$(find ~/.claude/plugins/ai-effort-planner -name 'ai-runner.sh' 2>/dev/null | head -1)" \
  > "$TMPDIR/ai-runner.sh" 2>/dev/null || true

# If the runner template doesn't exist yet, create a minimal one for testing
if [ ! -s "$TMPDIR/ai-runner.sh" ]; then
cat > "$TMPDIR/ai-runner.sh" << 'RUNNER'
#!/bin/bash
set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$PROJECT_DIR/ai-runner.log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ====== Starting daily session ======" >> "$LOG"
cd "$PROJECT_DIR"
FAKE_GIT pull origin main >> "$LOG" 2>&1
timeout 14400 FAKE_CLAUDE --dangerously-skip-permissions -p "$(cat .ai-handoff.md)" >> "$LOG" 2>&1
EXIT_CODE=$?
if [ $EXIT_CODE -eq 124 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Session ended by timeout (4h limit reached)" >> "$LOG"
elif [ $EXIT_CODE -eq 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Session completed normally" >> "$LOG"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Session ended with exit code $EXIT_CODE" >> "$LOG"
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ====== Session done ======" >> "$LOG"
RUNNER
  sed -i "s|FAKE_GIT|$TMPDIR/fake-git|g; s|FAKE_CLAUDE|$TMPDIR/fake-claude|g" "$TMPDIR/ai-runner.sh"
fi
chmod +x "$TMPDIR/ai-runner.sh"

cd "$TMPDIR" && bash ai-runner.sh

grep -q "Session completed normally" "$TMPDIR/ai-runner.log" && pass "Normal completion logged" || fail "Normal completion not logged"
grep -q "Starting daily session" "$TMPDIR/ai-runner.log" && pass "Session start logged" || fail "Session start not logged"
grep -q "Session done" "$TMPDIR/ai-runner.log" && pass "Session end logged" || fail "Session end not logged"

# ---- Test 2: timeout handling ----
rm -f "$TMPDIR/ai-runner.log"

# Create fake claude that sleeps forever (will be killed by timeout)
cat > "$TMPDIR/fake-claude" << 'EOF'
#!/bin/bash
sleep 9999
EOF
chmod +x "$TMPDIR/fake-claude"

# Patch runner with 1-second timeout for testing
sed "s|timeout 14400|timeout 1|g" "$TMPDIR/ai-runner.sh" > "$TMPDIR/ai-runner-timeout-test.sh"
chmod +x "$TMPDIR/ai-runner-timeout-test.sh"

cd "$TMPDIR" && bash ai-runner-timeout-test.sh || true

grep -q "timeout" "$TMPDIR/ai-runner.log" && pass "Timeout exit correctly logged" || fail "Timeout not detected in log"

# ---- Summary ----
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
```

- [ ] **Step 2: Make test executable and run it**

```bash
chmod +x docs/superpowers/tests/test-runner.sh
bash docs/superpowers/tests/test-runner.sh
```

Expected output:
```
✅ Normal completion logged
✅ Session start logged
✅ Session end logged
✅ Timeout exit correctly logged

Results: 4 passed, 0 failed
```

- [ ] **Step 3: Commit**

```bash
cd ~/workspace/the-architect
git add docs/superpowers/tests/test-runner.sh
git commit -m "test: add ai-runner.sh behavior tests (normal completion + timeout)"
```

---

## Task 9: Smoke test with real blueprint

**Files:**
- Read: `output/cocina-media-center-blueprint.md`
- Verify skill invocation produces correct output

- [ ] **Step 1: Verify SKILL.md is complete**

```bash
wc -l ~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md
```

Expected: at least 200 lines. If significantly less, a phase is missing — re-read the plan.

- [ ] **Step 2: Verify all 8 phases are present**

```bash
grep -c "^## Phase" ~/.claude/plugins/ai-effort-planner/skills/ai-effort-planner/SKILL.md
```

Expected: `8`

- [ ] **Step 3: Invoke the skill manually in Claude Code**

In a Claude Code session in the `cocina-media-center` project directory (or any directory containing the blueprint), run:

```
/ai-effort-planner output/cocina-media-center-blueprint.md
```

Verify Phase 1 output matches `docs/superpowers/tests/fixtures/phase1-expected.md`:
- Project name: "Cocina Media Center" (or similar)
- Build steps: 12
- Tech stack rows: 10
- Preliminary score: 8/25
- First question asked immediately after

- [ ] **Step 4: Walk through the full conversation**

Answer the scoring questions:
1. "nuevo" → repo_score = 1
2. "100% definidos" → clarity_score = 1
3. "aislados" → density_score = 1

Verify total score = 11, Nivel = Medio, sessions ≈ 11.

Answer execution questions:
1. "1M"
2. "04:00"
3. "A" (sin apuro)

Verify timeline options appear with correct day counts.

Choose "MODERADO". Verify:
- `ai-plan.md` created with correct structure
- `.ai-progress.json` created with correct fields
- `.ai-handoff.md` created with today's steps
- `ai-runner.sh` created and executable (`ls -la ai-runner.sh`)
- Risk warnings mention Paso 3 (Bluetooth) and Paso 4 (spotifyd credentials)

- [ ] **Step 5: Commit smoke test results**

```bash
cd ~/workspace/the-architect
git add -A
git commit -m "test: smoke test verified against cocina blueprint — all phases pass"
```

---

## Task 10: Register skill in The Architect's skills registry

**Files:**
- Modify: `knowledge/skills-registry.md`

- [ ] **Step 1: Add ai-effort-planner to the registry**

In `knowledge/skills-registry.md`, add a new row to the "Skills The Architect Uses During Design" table:

```markdown
| `/ai-effort-planner` | Phase 4 (Generate) | Estimate AI effort and set up daily autonomous executor after blueprint is complete |
```

And add to the "Skills for Blueprint Recommendations" table:

```markdown
| `/ai-effort-planner` | Build Order | After blueprint is generated | Estimates AI effort and schedules autonomous daily execution |
```

- [ ] **Step 2: Commit**

```bash
cd ~/workspace/the-architect
git add knowledge/skills-registry.md
git commit -m "docs: register ai-effort-planner in skills registry"
```

---

## Self-Review Checklist

Before calling this plan complete, verify:

- [ ] Every task has complete file paths (no "the file above" references)
- [ ] Every code step shows the actual code, not "implement X"
- [ ] The SKILL.md content is complete across all 8 phases with no gaps
- [ ] The ai-runner.sh in Task 6 matches the one tested in Task 8 (same structure)
- [ ] Phase 7 step distribution formula handles the case where steps > sessions (extra steps go to session 1) and steps < sessions (some sessions are empty → mark as rest days)
- [ ] Phase 5 RELAJADO timeline correctly skips days (cron runs daily, but ai-plan.md marks some days as rest and the handoff says "no work today, next session tomorrow")
