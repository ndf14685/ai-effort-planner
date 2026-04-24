#!/bin/bash
# Tests ai-runner.sh behavior without running claude CLI

PASS=0
FAIL=0

pass() { echo "✅ $1"; PASS=$((PASS+1)); }
fail() { echo "❌ $1"; FAIL=$((FAIL+1)); }

# Setup — use TEST_DIR, not TMPDIR (TMPDIR is a POSIX-reserved env var)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/.git"
cat > "$TEST_DIR/.ai-handoff.md" << 'EOF'
# Test handoff
Do nothing.
EOF

# Fake git that succeeds by default
cat > "$TEST_DIR/fake-git" << 'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$TEST_DIR/fake-git"

# Fake git that fails (simulates network/auth error)
cat > "$TEST_DIR/fake-git-fail" << 'EOF'
#!/bin/bash
echo "fatal: unable to access remote" >&2
exit 1
EOF
chmod +x "$TEST_DIR/fake-git-fail"

# Build the runner inline — mirrors the ai-runner.sh template in SKILL.md Phase 7d
build_runner() {
  local FAKE_CLAUDE="$1"
  local TIMEOUT_VAL="${2:-14400}"
  local FAKE_GIT="${3:-$TEST_DIR/fake-git}"
  cat > "$TEST_DIR/ai-runner.sh" << RUNNER
#!/bin/bash

PROJECT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
LOG="\$PROJECT_DIR/ai-runner.log"

install -m 600 /dev/null "\$LOG" 2>/dev/null || true

ts() { date '+%Y-%m-%d %H:%M:%S'; }

echo "[\$(ts)] ====== Starting daily session ======" >> "\$LOG"

cd "\$PROJECT_DIR"

if ! $FAKE_GIT pull origin main >> "\$LOG" 2>&1; then
  echo "[\$(ts)] ERROR: git pull failed — skipping session. Fix the issue and re-run manually." >> "\$LOG"
  echo "[\$(ts)] ====== Session aborted ======" >> "\$LOG"
  exit 0
fi

if [ -f ".ai-handoff.next.md" ]; then
  echo "[\$(ts)] Promoting .ai-handoff.next.md → .ai-handoff.md" >> "\$LOG"
  mv ".ai-handoff.next.md" ".ai-handoff.md"
fi

if [ ! -f ".ai-handoff.md" ]; then
  echo "[\$(ts)] ERROR: .ai-handoff.md not found — nothing to execute." >> "\$LOG"
  exit 0
fi

if grep -q "Proyecto completado" ".ai-handoff.md" 2>/dev/null; then
  echo "[\$(ts)] Project marked as completed — no work to do." >> "\$LOG"
  exit 0
fi

timeout $TIMEOUT_VAL $FAKE_CLAUDE --dangerously-skip-permissions -p "\$(cat .ai-handoff.md)" >> "\$LOG" 2>&1

EXIT_CODE=\$?

if [ \$EXIT_CODE -eq 124 ]; then
  echo "[\$(ts)] Session ended by timeout (4h limit reached)" >> "\$LOG"
elif [ \$EXIT_CODE -eq 0 ]; then
  echo "[\$(ts)] Session completed normally" >> "\$LOG"
else
  echo "[\$(ts)] Session ended with exit code \$EXIT_CODE" >> "\$LOG"
fi

echo "[\$(ts)] ====== Session done ======" >> "\$LOG"
RUNNER
  chmod +x "$TEST_DIR/ai-runner.sh"
}

# ──────────────────────────────────────────────────
# Test 1: Normal completion
# ──────────────────────────────────────────────────
cat > "$TEST_DIR/fake-claude" << 'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$TEST_DIR/fake-claude"

build_runner "$TEST_DIR/fake-claude"
rm -f "$TEST_DIR/ai-runner.log"
cd "$TEST_DIR" && bash ai-runner.sh

grep -q "Session completed normally" "$TEST_DIR/ai-runner.log" \
  && pass "Normal completion logged" || fail "Normal completion not logged"
grep -q "Starting daily session" "$TEST_DIR/ai-runner.log" \
  && pass "Session start logged" || fail "Session start not logged"
grep -q "Session done" "$TEST_DIR/ai-runner.log" \
  && pass "Session end logged" || fail "Session end not logged"

# ──────────────────────────────────────────────────
# Test 2: Timeout handling
# ──────────────────────────────────────────────────
cat > "$TEST_DIR/fake-claude" << 'EOF'
#!/bin/bash
sleep 9999
EOF
chmod +x "$TEST_DIR/fake-claude"

build_runner "$TEST_DIR/fake-claude" 1
rm -f "$TEST_DIR/ai-runner.log"
cd "$TEST_DIR" && bash ai-runner.sh || true

grep -q "timeout" "$TEST_DIR/ai-runner.log" \
  && pass "Timeout exit correctly logged" || fail "Timeout not detected in log"

# ──────────────────────────────────────────────────
# Test 3: Non-zero exit code (non-timeout)
# ──────────────────────────────────────────────────
cat > "$TEST_DIR/fake-claude" << 'EOF'
#!/bin/bash
exit 2
EOF
chmod +x "$TEST_DIR/fake-claude"

build_runner "$TEST_DIR/fake-claude"
rm -f "$TEST_DIR/ai-runner.log"
cd "$TEST_DIR" && bash ai-runner.sh || true

grep -q "exit code 2" "$TEST_DIR/ai-runner.log" \
  && pass "Non-zero exit code logged" || fail "Non-zero exit code not logged"

# ──────────────────────────────────────────────────
# Test 4 (security): git pull failure → session skipped, claude NOT called
# ──────────────────────────────────────────────────
CLAUDE_INVOKED=0
cat > "$TEST_DIR/fake-claude-sentinel" << 'EOF'
#!/bin/bash
touch "$TEST_DIR/claude_was_called"
exit 0
EOF
chmod +x "$TEST_DIR/fake-claude-sentinel"

build_runner "$TEST_DIR/fake-claude-sentinel" 14400 "$TEST_DIR/fake-git-fail"
rm -f "$TEST_DIR/ai-runner.log" "$TEST_DIR/claude_was_called"
cd "$TEST_DIR" && bash ai-runner.sh

grep -q "git pull failed" "$TEST_DIR/ai-runner.log" \
  && pass "git pull failure logged" || fail "git pull failure not logged"
grep -q "Session aborted" "$TEST_DIR/ai-runner.log" \
  && pass "Session aborted on git pull failure" || fail "Session not aborted on git pull failure"
[ ! -f "$TEST_DIR/claude_was_called" ] \
  && pass "Claude NOT invoked when git pull fails" || fail "Claude was invoked despite git pull failure"

# ──────────────────────────────────────────────────
# Test 5 (security): .ai-handoff.next.md → .ai-handoff.md promotion
# ──────────────────────────────────────────────────
rm -f "$TEST_DIR/.ai-handoff.md"
cat > "$TEST_DIR/.ai-handoff.next.md" << 'EOF'
# Next session handoff
Do next session work.
EOF

cat > "$TEST_DIR/fake-claude" << 'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$TEST_DIR/fake-claude"

build_runner "$TEST_DIR/fake-claude"
rm -f "$TEST_DIR/ai-runner.log"
cd "$TEST_DIR" && bash ai-runner.sh

grep -q "Promoting .ai-handoff.next.md" "$TEST_DIR/ai-runner.log" \
  && pass ".ai-handoff.next.md promoted to .ai-handoff.md" || fail ".ai-handoff.next.md not promoted"
[ -f "$TEST_DIR/.ai-handoff.md" ] \
  && pass ".ai-handoff.md exists after promotion" || fail ".ai-handoff.md missing after promotion"
[ ! -f "$TEST_DIR/.ai-handoff.next.md" ] \
  && pass ".ai-handoff.next.md removed after promotion" || fail ".ai-handoff.next.md still exists after promotion"

# Restore for subsequent tests
cat > "$TEST_DIR/.ai-handoff.md" << 'EOF'
# Test handoff
Do nothing.
EOF

# ──────────────────────────────────────────────────
# Test 6 (security): "Proyecto completado" → skip execution
# ──────────────────────────────────────────────────
cat > "$TEST_DIR/.ai-handoff.md" << 'EOF'
# Proyecto completado — sin trabajo pendiente
EOF

CLAUDE_INVOKED=0
cat > "$TEST_DIR/fake-claude-sentinel2" << EOF
#!/bin/bash
touch "$TEST_DIR/claude_was_called_completed"
exit 0
EOF
chmod +x "$TEST_DIR/fake-claude-sentinel2"

build_runner "$TEST_DIR/fake-claude-sentinel2"
rm -f "$TEST_DIR/ai-runner.log" "$TEST_DIR/claude_was_called_completed"
cd "$TEST_DIR" && bash ai-runner.sh

grep -q "marked as completed" "$TEST_DIR/ai-runner.log" \
  && pass "Completed project detected and skipped" || fail "Completed project not detected"
[ ! -f "$TEST_DIR/claude_was_called_completed" ] \
  && pass "Claude NOT invoked on completed project" || fail "Claude invoked on completed project"

# Restore for subsequent tests
cat > "$TEST_DIR/.ai-handoff.md" << 'EOF'
# Test handoff
Do nothing.
EOF

# ──────────────────────────────────────────────────
# Test 7 (security): missing handoff → abort, no claude invocation
# ──────────────────────────────────────────────────
rm -f "$TEST_DIR/.ai-handoff.md"

cat > "$TEST_DIR/fake-claude-sentinel3" << EOF
#!/bin/bash
touch "$TEST_DIR/claude_was_called_missing"
exit 0
EOF
chmod +x "$TEST_DIR/fake-claude-sentinel3"

build_runner "$TEST_DIR/fake-claude-sentinel3"
rm -f "$TEST_DIR/ai-runner.log" "$TEST_DIR/claude_was_called_missing"
cd "$TEST_DIR" && bash ai-runner.sh

grep -q ".ai-handoff.md not found" "$TEST_DIR/ai-runner.log" \
  && pass "Missing handoff detected and aborted" || fail "Missing handoff not detected"
[ ! -f "$TEST_DIR/claude_was_called_missing" ] \
  && pass "Claude NOT invoked when handoff missing" || fail "Claude invoked despite missing handoff"

# Restore
cat > "$TEST_DIR/.ai-handoff.md" << 'EOF'
# Test handoff
Do nothing.
EOF

# ──────────────────────────────────────────────────
# Test 8 (security): log file permissions are 600
# ──────────────────────────────────────────────────
cat > "$TEST_DIR/fake-claude" << 'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$TEST_DIR/fake-claude"

build_runner "$TEST_DIR/fake-claude"
rm -f "$TEST_DIR/ai-runner.log"
cd "$TEST_DIR" && bash ai-runner.sh

if [ -f "$TEST_DIR/ai-runner.log" ]; then
  LOG_PERMS=$(stat -c "%a" "$TEST_DIR/ai-runner.log" 2>/dev/null || stat -f "%OLp" "$TEST_DIR/ai-runner.log" 2>/dev/null)
  [ "$LOG_PERMS" = "600" ] \
    && pass "Log file has restricted permissions (600)" \
    || fail "Log file permissions are $LOG_PERMS, expected 600"
else
  fail "Log file not created"
fi

# ──────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
