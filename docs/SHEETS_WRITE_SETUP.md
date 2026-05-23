# Friday — Sheets-write auth setup (spike)

Friday's daily sweep, backfill, and review all need to write rows back to your Google Sheet. The native Google Drive connector that Cowork ships with can read Sheets but **not** write cells. The workaround is to shell out to the [Google Workspace CLI (`gws`)](https://github.com/googleworkspace/cli) from inside Cowork's local Linux VM.

This doc walks you through setting up the two auth paths so you can run the `friday-sheets-test` skill and find out which one works for your Cowork install.

## Path 1 — OAuth (try this first)

Simplest setup. Risk: Cowork's VM may not share your host OS keyring, in which case the cached credentials aren't visible to the plugin's scripts.

1. Open a terminal on your machine.
2. Install the CLI:

   ```bash
   npm install -g @googleworkspace/cli
   # or: brew install googleworkspace-cli
   ```

3. Run the interactive OAuth flow:

   ```bash
   gws auth setup
   ```

   This opens your browser, you sign in to your Google account, you grant Sheets read+write scope. The CLI stores the token in your OS keyring.

4. Verify it works from your terminal:

   ```bash
   gws sheets +append \
     --spreadsheet <YOUR_SHEET_ID> \
     --range "Activity Log!A:A" \
     --values "test-from-terminal"
   ```

   Open your Sheet, confirm the row appeared. If yes, OAuth is working on your host.

   Whether it works **inside Cowork's VM** is what the `friday-sheets-test` skill verifies next.

## Path 2 — Service account

More setup but more robust across ephemeral sessions. Recommended for production.

### One-time GCP setup

1. Go to [console.cloud.google.com](https://console.cloud.google.com).
2. Create a new project (or reuse an existing one). Name it whatever you like — `friday-personal` is fine.
3. Enable the **Google Sheets API** for the project: APIs & Services → Library → search "Sheets API" → Enable.
4. Create a service account: APIs & Services → Credentials → Create Credentials → Service Account.
   - Name: `friday-bot` (or similar)
   - Skip the optional grant-access steps.
5. Open the new service account → Keys tab → Add Key → Create new key → JSON. The JSON file downloads.
6. Note the service account's **email address** (it looks like `friday-bot@your-project.iam.gserviceaccount.com`).

### Share your Friday Sheet with the service account

1. Open your Friday CRM Sheet in your browser.
2. Click **Share** (top right).
3. Paste the service account's email address.
4. Set permission to **Editor**.
5. Send.

The service account can now read/write your Sheet.

### Get the JSON key into Cowork's VM

This is the part that depends on how your Cowork install exposes its VM filesystem. Two options to try:

**Option A — drop the JSON into your Cowork Working folder.** Cowork has a "Working folder" panel (visible in the Customize sidebar). Files placed there should be readable by skill scripts.

1. Move the downloaded JSON file into your Cowork Working folder.
2. Rename it to `friday-sa.json` for clarity.

**Option B — paste the JSON contents and have Claude save it.** If the Working folder isn't directly accessible, open the JSON file in a text editor, copy its entire contents, then in a Cowork chat paste:

> "Save the following JSON to ~/friday-sa.json: { ...the whole JSON... }"

Claude will write the file in the VM session. **Caveat:** this file probably doesn't persist across Cowork sessions, so you may need to re-paste it for each session. If that turns out to be true, we'll need to find a more durable location during the spike.

## Running the spike

Once at least one of the two paths is set up:

1. In a Cowork chat, say:

   > test Friday sheets write access for sheet `<YOUR_SHEET_ID>`

   (Or just "test Friday sheets" if Claude remembers your Sheet ID from a previous setup.)

2. Claude invokes `friday-sheets-test`, which runs the `test_sheets_write.sh` script.

3. You'll get a report like:

   ```
   ============ TEST REPORT ============
     gws install: SUCCESS via npm
     OAuth path: FAILED (exit 1) — first lines: Error: no credentials...
     Service account path: SUCCESS — appended 'friday-spike-SA-2026-05-23T19:42:00Z' to 'Activity Log'
   =====================================
   ```

4. Open your Sheet's Activity Log tab and look for the `friday-spike-*` rows in column A.

5. Delete the diagnostic rows after verifying.

## What we'll do based on the result

| Result | Next step |
|---|---|
| **OAuth ✓ Service account ✓** | Pick service account for the production rewrite — more durable across fresh sessions. |
| **OAuth ✗ Service account ✓** | Service account is the only viable path. Proceed with the rewrite. |
| **OAuth ✓ Service account ✗** | Service account setup likely has a Sheet-share or file-path issue. Diagnose, then probably end up using OAuth despite the session-durability question. |
| **OAuth ✗ Service account ✗** | Send `/tmp/friday_oauth_test.log` and `/tmp/friday_sa_test.log` contents. We'll either fix the auth or fall back to the markdown-summary mode (Option A from the earlier triage). |

## Cleanup

If you abandon this spike or move to Option A (markdown-summary):

- Revoke the OAuth token (Google account settings → Security → Third-party apps).
- Delete the GCP project and service account.
- Un-share the Sheet with the service account email.
- Delete `~/friday-sa.json` from the VM (and your host machine).
