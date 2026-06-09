#!/usr/bin/env bash
# Headless test harness for teams-launcher. No display or real Chromium needed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LAUNCHER="${REPO_ROOT}/bin/teams-launcher"
DESKTOP_TEMPLATE="${REPO_ROOT}/share/teams-launcher.desktop.in"
CI="${CI:-false}"

PASS=0
FAIL=0
FAILURES=()
FAKE_BIN_DIR=""
FAKE_CHROMIUM_ARGV_FILE=""

# ── Helpers ──────────────────────────────────────────────────────────────────
pass()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail()  { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); FAILURES+=("$1"); }
run_test() { echo ""; echo "── $1"; }

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if [[ "${haystack}" == *"${needle}"* ]]; then
    pass "${label}"
  else
    fail "${label} — expected '${needle}' in: ${haystack}"
  fi
}

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  if [[ "${haystack}" != *"${needle}"* ]]; then
    pass "${label}"
  else
    fail "${label} — did NOT expect '${needle}' in: ${haystack}"
  fi
}

assert_exit() {
  local label="$1" expected="$2" actual="$3"
  if [[ "${actual}" == "${expected}" ]]; then
    pass "${label} exits ${expected}"
  else
    fail "${label} — expected exit ${expected}, got ${actual}"
  fi
}

assert_dir_exists() {
  local label="$1" dir="$2"
  if [[ -d "${dir}" ]]; then
    pass "${label} dir exists"
  else
    fail "${label} — directory missing: ${dir}"
  fi
}

assert_dir_absent() {
  local label="$1" dir="$2"
  if [[ ! -d "${dir}" ]]; then
    pass "${label} dir absent"
  else
    fail "${label} — directory still exists: ${dir}"
  fi
}

count_profile_dirs() {
  find "${TMPFS_BASE}" -maxdepth 1 -name 'teams-launcher-*' -type d 2>/dev/null | wc -l | tr -d ' '
}

# ── Fake Chromium setup ───────────────────────────────────────────────────────
setup_fake_chromium() {
  FAKE_BIN_DIR="$(mktemp -d)"
  FAKE_CHROMIUM_ARGV_FILE="$(mktemp)"
  export FAKE_CHROMIUM_ARGV_FILE
  # FAKE_CHROMIUM_SLEEP env controls how long the stub runs (default: 5s).
  cat > "${FAKE_BIN_DIR}/chromium" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${FAKE_CHROMIUM_ARGV_FILE:?}"
sleep "${FAKE_CHROMIUM_SLEEP:-5}" &
SLEEP_PID=$!
trap 'kill "$SLEEP_PID" 2>/dev/null; exit 0' TERM INT
wait "$SLEEP_PID" || true
STUB
  chmod +x "${FAKE_BIN_DIR}/chromium"
  export PATH="${FAKE_BIN_DIR}:${PATH}"
}

teardown_fake_chromium() {
  if [[ -n "${FAKE_BIN_DIR}" && -d "${FAKE_BIN_DIR}" ]]; then
    rm -rf "${FAKE_BIN_DIR}"
  fi
  if [[ -n "${FAKE_CHROMIUM_ARGV_FILE}" && -f "${FAKE_CHROMIUM_ARGV_FILE}" ]]; then
    rm -f "${FAKE_CHROMIUM_ARGV_FILE}"
  fi
}

# ── Test 0: shellcheck ────────────────────────────────────────────────────────
run_test "0: shellcheck"
if command -v shellcheck &>/dev/null; then
  for sc_file in "${LAUNCHER}" "${REPO_ROOT}/install.sh" "${REPO_ROOT}/uninstall.sh" "${SCRIPT_DIR}/run.sh"; do
    sc_out="$(shellcheck "${sc_file}" 2>&1)" && sc_exit=0 || sc_exit=$?
    if [[ ${sc_exit} -eq 0 ]]; then
      pass "shellcheck $(basename "${sc_file}")"
    else
      fail "shellcheck $(basename "${sc_file}")"
      echo "${sc_out}"
    fi
  done
else
  if [[ "${CI}" == "true" ]]; then
    fail "shellcheck not installed (required in CI)"
  else
    echo "  SKIP: shellcheck not installed"
  fi
fi

# ── Test 0b: desktop-file-validate ───────────────────────────────────────────
run_test "0b: desktop-file-validate"
RENDERED_DESKTOP="$(mktemp /tmp/teams-launcher-test-XXXXXX.desktop)"
sed "s|@BINPATH@|/usr/local/bin/teams-launcher|g" "${DESKTOP_TEMPLATE}" > "${RENDERED_DESKTOP}"
if command -v desktop-file-validate &>/dev/null; then
  dfv_out="$(desktop-file-validate "${RENDERED_DESKTOP}" 2>&1)" && dfv_exit=0 || dfv_exit=$?
  if [[ ${dfv_exit} -eq 0 ]]; then
    pass "desktop-file-validate"
  else
    fail "desktop-file-validate: ${dfv_out}"
  fi
else
  if [[ "${CI}" == "true" ]]; then
    fail "desktop-file-validate not installed (required in CI)"
  else
    echo "  SKIP: desktop-file-validate not installed"
  fi
fi
rm -f "${RENDERED_DESKTOP}"

# Set up fake chromium stub for all functional tests.
setup_fake_chromium
trap teardown_fake_chromium EXIT

TMPFS_BASE="${XDG_RUNTIME_DIR:-/tmp}"

# ── Test 1: ephemeral --dry-run ───────────────────────────────────────────────
run_test "1: ephemeral --dry-run"
t1_exit=0
t1_out="$(TEAMS_MODE=ephemeral "${LAUNCHER}" --dry-run 2>&1)" || t1_exit=$?
assert_exit       "1 exit code" "0" "${t1_exit}"
assert_contains   "1 PROFILE under tmpfs dir"    "${t1_out}" "${TMPFS_BASE}"
assert_contains   "1 --app flag present"         "${t1_out}" "--app="
assert_contains   "1 --class=TeamsLauncher"      "${t1_out}" "--class=TeamsLauncher"
assert_contains   "1 --password-store=basic"     "${t1_out}" "--password-store=basic"

# Profile dir must be cleaned up by EXIT trap after dry-run exits.
t1_profile="$(printf '%s\n' "${t1_out}" | grep '^PROFILE=' | cut -d= -f2- || true)"
if [[ -n "${t1_profile}" ]]; then
  assert_dir_absent "1 ephemeral profile cleaned after dry-run" "${t1_profile}"
else
  fail "1 PROFILE= line missing from dry-run output"
fi

# ── Test 2a: ephemeral real run — profile created then deleted on natural exit ─
run_test "2a: ephemeral real run — natural exit"
before_count="$(count_profile_dirs)"

FAKE_CHROMIUM_SLEEP=1 "${LAUNCHER}" --mode=ephemeral &
t2a_pid=$!
sleep 0.5

mid_count="$(count_profile_dirs)"
if [[ "${mid_count}" -gt "${before_count}" ]]; then
  pass "2a profile dir exists during run"
else
  fail "2a profile dir not found during run (before=${before_count} mid=${mid_count})"
fi

wait "${t2a_pid}" 2>/dev/null || true
sleep 0.5

after_count="$(count_profile_dirs)"
if [[ "${after_count}" -le "${before_count}" ]]; then
  pass "2a profile dir cleaned up after natural exit"
else
  fail "2a profile dir NOT cleaned up after natural exit (before=${before_count} after=${after_count})"
fi

# ── Test 2b: ephemeral real run — SIGTERM triggers cleanup ────────────────────
run_test "2b: ephemeral real run — SIGTERM cleanup"
before2_count="$(count_profile_dirs)"

"${LAUNCHER}" --mode=ephemeral &
t2b_pid=$!
sleep 1

mid2_count="$(count_profile_dirs)"
if [[ "${mid2_count}" -gt "${before2_count}" ]]; then
  pass "2b profile dir exists before SIGTERM"
else
  fail "2b profile dir not found before SIGTERM (before=${before2_count} mid=${mid2_count})"
fi

kill -TERM "${t2b_pid}" 2>/dev/null || true
wait "${t2b_pid}" 2>/dev/null || true
sleep 0.5

after2_count="$(count_profile_dirs)"
if [[ "${after2_count}" -le "${before2_count}" ]]; then
  pass "2b profile dir cleaned up after SIGTERM"
else
  fail "2b profile dir NOT cleaned up after SIGTERM (before=${before2_count} after=${after2_count})"
fi

# ── Test 3: persistent --dry-run ──────────────────────────────────────────────
run_test "3: persistent --dry-run"
t3_data_home="$(mktemp -d)"
t3_exit=0
t3_out="$(XDG_DATA_HOME="${t3_data_home}" "${LAUNCHER}" --mode=persistent --dry-run 2>&1)" || t3_exit=$?
assert_exit       "3 exit code" "0" "${t3_exit}"
assert_contains   "3 profile under XDG_DATA_HOME" "${t3_out}" "${t3_data_home}"
# Persistent profile must NOT look like a tmpfs ephemeral path (teams-launcher-XXXX).
assert_not_contains "3 no ephemeral path pattern" "${t3_out}" "/teams-launcher-"

t3_profile="$(printf '%s\n' "${t3_out}" | grep '^PROFILE=' | cut -d= -f2- || true)"
if [[ -n "${t3_profile}" ]]; then
  assert_dir_exists "3 persistent profile created"         "${t3_profile}"
  assert_dir_exists "3 persistent profile not deleted"     "${t3_profile}"
else
  fail "3 PROFILE= line missing from dry-run output"
fi

rm -rf "${t3_data_home}"

# ── Test 4: missing chromium ──────────────────────────────────────────────────
run_test "4: missing chromium"
# Invoke via explicit 'bash' to bypass the #!/usr/bin/env bash shebang, which
# itself searches PATH. The launcher detects chromium first (before mktemp), so
# an empty PATH causes find_chromium to fail before any disk operations.
empty_dir="$(mktemp -d)"
t4_exit=0
t4_out="$(PATH="${empty_dir}" CHROMIUM="" /bin/bash "${LAUNCHER}" --dry-run 2>&1)" || t4_exit=$?
rm -rf "${empty_dir}"

if [[ "${t4_exit}" -ne 0 ]]; then
  pass "4 non-zero exit when chromium missing"
else
  fail "4 expected non-zero exit, got 0"
fi
assert_contains "4 apt install hint in error" "${t4_out}" "apt"

# ── Test 5: unknown flag ──────────────────────────────────────────────────────
run_test "5: unknown flag exits 2"
t5_exit=0
"${LAUNCHER}" --totally-unknown-flag 2>/dev/null || t5_exit=$?
assert_exit "5 unknown flag" "2" "${t5_exit}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
printf ' Results: %d passed, %d failed\n' "${PASS}" "${FAIL}"
echo "══════════════════════════════════════════"

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo ""
  echo "Failed tests:"
  for f_name in "${FAILURES[@]}"; do
    echo "  - ${f_name}"
  done
fi

[[ ${FAIL} -eq 0 ]]
