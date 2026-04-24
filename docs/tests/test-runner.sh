#!/bin/bash
# Tests ai-runner.sh behavior without running claude CLI

PASS=0
FAIL=0

pass() { echo "✅ $1"; PASS=$((PASS+1)); }
fail() { echo "❌ $1"; FAIL=$((FAIL+1)); }

# Setup
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

mkdir -p "$TMPDIR/.git"
cat > "$TMPDIR/.ai-handoff.md" << 'EOF'
# Test handoff
Do nothing.
EOF

# Create fake git
cat > "$TMPDIR/fake-git" << 'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$TMPDIR/fake-git"

# Build the runner inline (mirrors the ai-runner.sh the skill generates)
build_runner() {
  local FAKE_CLAUDE="$1"
  local TIMEOUT_VAL="${2:-14400}"
  cat > "$TMPDIR/ai-runner.sh" << RUNNER
#!/bin/bash
PROJECT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
LOG="\$PROJECT_DIR/ai-runner.log"
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] ====== Starting daily session ======" >> "\$LOG"
cd "\$PROJECT_DIR"
$TMPDIR/fake-git pull origin main >> "\$LOG" 2>&1
timeout $TIMEOUT_VAL $FAKE_CLAUDE --dangerously-skip-permissions -p "\$(cat .ai-handoff.md)" >> "\$LOG" 2>&1
EXIT_CODE=\$?
if [ \$EXIT_CODE -eq 124 ]; then
  echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Session ended by timeout (4h limit reached)" >> "\$LOG"
elif [ \$EXIT_CODE -eq 0 ]; then
  echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Session completed normally" >> "\$LOG"
else
  echo "[\$(date '+%Y-%m-%d %H:%M:%S')] Session ended with exit code \$EXIT_CODE" >> "\$LOG"
fi
echo "[\$(date '+%Y-%m-%d %H:%M:%S')] ====== Session done ======" >> "\$LOG"
RUNNER
  chmod +x "$TMPDIR/ai-runner.sh"
}

# ---- Test 1: normal completion ----
cat > "$TMPDIR/fake-claude" << 'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$TMPDIR/fake-claude"

build_runner "$TMPDIR/fake-claude"
rm -f "$TMPDIR/ai-runner.log"
cd "$TMPDIR" && bash ai-runner.sh

grep -q "Session completed normally" "$TMPDIR/ai-runner.log" && pass "Normal completion logged" || fail "Normal completion not logged"
grep -q "Starting daily session" "$TMPDIR/ai-runner.log" && pass "Session start logged" || fail "Session start not logged"
grep -q "Session done" "$TMPDIR/ai-runner.log" && pass "Session end logged" || fail "Session end not logged"

# ---- Test 2: timeout handling ----
cat > "$TMPDIR/fake-claude" << 'EOF'
#!/bin/bash
sleep 9999
EOF
chmod +x "$TMPDIR/fake-claude"

build_runner "$TMPDIR/fake-claude" 1
rm -f "$TMPDIR/ai-runner.log"
cd "$TMPDIR" && bash ai-runner.sh || true

grep -q "timeout" "$TMPDIR/ai-runner.log" && pass "Timeout exit correctly logged" || fail "Timeout not detected in log"

# ---- Test 3: non-zero exit (non-timeout) ----
cat > "$TMPDIR/fake-claude" << 'EOF'
#!/bin/bash
exit 2
EOF
chmod +x "$TMPDIR/fake-claude"

build_runner "$TMPDIR/fake-claude"
rm -f "$TMPDIR/ai-runner.log"
cd "$TMPDIR" && bash ai-runner.sh || true

grep -q "exit code 2" "$TMPDIR/ai-runner.log" && pass "Non-zero exit code logged" || fail "Non-zero exit code not logged"

# ---- Summary ----
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ $FAIL -eq 0 ] && exit 0 || exit 1
