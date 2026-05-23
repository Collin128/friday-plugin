---
name: friday-sheets-test
description: |
  Use when the user says "test Friday sheets write access", "test the
  gws auth spike", or wants to verify whether Friday can write to their
  Google Sheet from Cowork's local VM. Tests both OAuth and service-
  account auth paths via the Google Workspace CLI (gws).
---

# friday-sheets-test

Diagnostic skill. Runs the `test_sheets_write.sh` script in Cowork's local Linux VM. Tries both auth paths (OAuth-cached and service-account-via-JSON) and reports which work. This is the spike before committing the rest of the plugin to a specific auth pattern.

## When to invoke

The user says any of:

- "test Friday sheets write access"
- "run the gws auth spike"
- "see if Friday can write to my Sheet"
- "test if writes work"

## Prerequisites — at least one of these must be set up

The script tests both, so the user doesn't have to set up both at once. Each path tests independently; the script reports which paths were attempted and which succeeded.

### Path 1 — OAuth (cached credentials)

Before running this skill, the user opens a terminal on their machine and runs:

```bash
npm install -g @googleworkspace/cli
gws auth setup
```

This does a one-time interactive OAuth flow and caches credentials in the OS keyring.

**Important caveat:** Cowork's local Linux VM may not share the user's host OS keyring. If OAuth credentials don't survive into the VM session, this path will fail in the test. That's a meaningful negative result — it tells us OAuth isn't viable for ephemeral scheduled-task sessions.

### Path 2 — Service account

Before running this skill:

1. The user creates a Google Cloud project (or reuses one) and enables the Google Sheets API.
2. Creates a service account in that project. Downloads its JSON key.
3. Opens their Friday CRM Sheet → Share → invites the service account's email address (looks like `friday-bot@my-project.iam.gserviceaccount.com`) with **Editor** access.
4. Places the JSON key somewhere the Cowork VM can read:
   - Option A: at `~/friday-sa.json` in the VM's home directory
   - Option B: at the path pointed to by `$GOOGLE_APPLICATION_CREDENTIALS` env var
   - Option C: at the path pointed to by `$FRIDAY_SA_JSON` env var

The script checks all three locations in order.

If the JSON is in the user's host filesystem but not the VM's, the user may need to upload it through Cowork's file mechanism (the "Working folder" UI) or paste its contents and ask Claude to save them to `~/friday-sa.json` in the VM.

## Steps

1. **Ask the user for the Sheet ID** if not already known. The Sheet ID is the long path segment after `/d/` in the Sheet URL — for the SHARED CRM template it would be `1DE0fGKgzP-zd4Z4kyPOsHHQPvd9q5HDlQIWoQF48a3I` (but the user wants to test their OWN copy, not the template).

2. **Run the script** from the VM:

   ```bash
   bash {{ plugin_dir }}/scripts/test_sheets_write.sh <SHEET_ID>
   ```

   If `{{ plugin_dir }}` isn't resolved by Cowork, the absolute path inside the plugin cache is typically `~/.claude/plugins/cache/collin128-friday/<sha>/plugins/friday/scripts/test_sheets_write.sh`. Use whichever form Cowork's bash environment resolves.

3. **Read the script's output** — it prints a `TEST REPORT` block at the end summarizing what worked.

4. **Tell the user** in plain prose what happened. Three possible shapes:
   - **Both paths succeeded:** "Both OAuth and service account paths wrote successfully. Service account is recommended for production because OAuth tokens may not survive scheduled-task session boundaries."
   - **Only one path succeeded:** "Service account worked; OAuth failed (likely because Cowork's VM doesn't share your host OS keyring). Service account is the path forward."
   - **Both failed:** "Both paths failed. Logs at /tmp/friday_oauth_test.log and /tmp/friday_sa_test.log — paste them here and we'll debug."

5. **Tell the user to clean up** the diagnostic rows. The script appends rows labeled `friday-spike-OAUTH-<timestamp>` and `friday-spike-SA-<timestamp>` to column A of the target tab. They should be deleted after verifying.

## Output

The plain-text TEST REPORT block from the script + a one-paragraph interpretation from Claude.

## What "success" means here

Success isn't just "the script returned exit 0." It means the diagnostic row actually appears in the Sheet's target tab. Have the user open the Sheet and confirm. If the script reports success but no row appears, that's a different bug (probably row went to a different tab or the gws helper interprets `--range` differently than we expect).

## See also

- [`docs/SHEETS_WRITE_SETUP.md`](../../../docs/SHEETS_WRITE_SETUP.md) — the user-facing setup walkthrough for both auth paths
- [Google Workspace CLI](https://github.com/googleworkspace/cli) — upstream documentation for gws
- [[friday-sheet]] — once an auth path is confirmed working, friday-sheet's write discipline section gets a sub-section about the gws invocation pattern
