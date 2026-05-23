#!/usr/bin/env bash
#
# test_sheets_write.sh — verify gws can write to a Google Sheet from
# Cowork's local Linux VM. Tests two auth paths and reports which work.
#
# Usage: test_sheets_write.sh <SHEET_ID> [<TAB_NAME>]
#   SHEET_ID  — the Google Sheet ID (the long path segment after /d/)
#   TAB_NAME  — optional, defaults to "Activity Log"
#
# Auth paths tested:
#   1. OAuth — uses whatever credentials gws has cached (from `gws auth setup`)
#   2. Service account — uses GOOGLE_APPLICATION_CREDENTIALS or ~/friday-sa.json
#
# Both paths append ONE diagnostic row to the target tab. The row is
# clearly labeled so you can identify and delete it after.

set -u  # but not -e — we want to test all paths even if one fails

SHEET_ID="${1:-}"
TAB_NAME="${2:-Activity Log}"

if [ -z "$SHEET_ID" ]; then
  echo "ERROR: Sheet ID is required." >&2
  echo "Usage: $0 <SHEET_ID> [<TAB_NAME>]" >&2
  exit 1
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REPORT_LINES=()
add_report() { REPORT_LINES+=("$1"); }

echo "============================================================"
echo "Friday Sheets-write auth spike"
echo "  Sheet ID:  $SHEET_ID"
echo "  Tab:       $TAB_NAME"
echo "  Timestamp: $TIMESTAMP"
echo "============================================================"
echo

# ---------- 0. Ensure gws is installed ----------
echo "[0/3] Checking for gws..."
if ! command -v gws >/dev/null 2>&1; then
  echo "  gws not found. Installing via npm..."
  if command -v npm >/dev/null 2>&1; then
    npm install -g @googleworkspace/cli >/tmp/gws_install.log 2>&1
    if command -v gws >/dev/null 2>&1; then
      add_report "gws install: SUCCESS via npm"
    else
      add_report "gws install: FAILED — npm install ran but gws not on PATH (see /tmp/gws_install.log)"
      printf '%s\n' "${REPORT_LINES[@]}"
      exit 2
    fi
  else
    add_report "gws install: FAILED — npm not available; try installing manually with brew or cargo"
    printf '%s\n' "${REPORT_LINES[@]}"
    exit 2
  fi
else
  add_report "gws install: already present ($(gws --version 2>/dev/null | head -1))"
fi
echo

# ---------- 1. Test OAuth path ----------
echo "[1/3] Testing OAuth path (cached credentials from \`gws auth setup\`)..."
OAUTH_VALUE="friday-spike-OAUTH-${TIMESTAMP}"
OAUTH_LOG=/tmp/friday_oauth_test.log

# We use the `+append` helper. If gws's flag syntax differs slightly,
# the error message will tell us.
gws sheets +append \
  --spreadsheet "$SHEET_ID" \
  --range "${TAB_NAME}!A:A" \
  --values "$OAUTH_VALUE" \
  >"$OAUTH_LOG" 2>&1
OAUTH_RC=$?

if [ $OAUTH_RC -eq 0 ]; then
  add_report "OAuth path: SUCCESS — appended '$OAUTH_VALUE' to '$TAB_NAME'"
else
  HEAD=$(head -3 "$OAUTH_LOG" 2>/dev/null | tr '\n' ' ' | cut -c1-200)
  add_report "OAuth path: FAILED (exit $OAUTH_RC) — first lines: $HEAD ... (full log: $OAUTH_LOG)"
fi
echo

# ---------- 2. Test service account path ----------
echo "[2/3] Testing service account path..."
SA_PATH="${GOOGLE_APPLICATION_CREDENTIALS:-${FRIDAY_SA_JSON:-$HOME/friday-sa.json}}"

if [ ! -f "$SA_PATH" ]; then
  add_report "Service account path: NOT TESTED — no JSON found at \$GOOGLE_APPLICATION_CREDENTIALS, \$FRIDAY_SA_JSON, or ~/friday-sa.json"
else
  SA_VALUE="friday-spike-SA-${TIMESTAMP}"
  SA_LOG=/tmp/friday_sa_test.log

  GOOGLE_APPLICATION_CREDENTIALS="$SA_PATH" gws sheets +append \
    --spreadsheet "$SHEET_ID" \
    --range "${TAB_NAME}!A:A" \
    --values "$SA_VALUE" \
    >"$SA_LOG" 2>&1
  SA_RC=$?

  if [ $SA_RC -eq 0 ]; then
    add_report "Service account path: SUCCESS — appended '$SA_VALUE' to '$TAB_NAME' using $SA_PATH"
  else
    HEAD=$(head -3 "$SA_LOG" 2>/dev/null | tr '\n' ' ' | cut -c1-200)
    add_report "Service account path: FAILED (exit $SA_RC) — first lines: $HEAD ... (full log: $SA_LOG)"
  fi
fi
echo

# ---------- 3. Report ----------
echo "[3/3] Final report"
echo "============================================================"
for line in "${REPORT_LINES[@]}"; do
  echo "  $line"
done
echo "============================================================"
echo
echo "Next steps:"
echo "  - If a path succeeded, look in your Sheet's '$TAB_NAME' tab"
echo "    column A for the diagnostic row(s). Delete after verifying."
echo "  - If both paths failed, send the report and the contents of"
echo "    /tmp/friday_oauth_test.log and /tmp/friday_sa_test.log."
