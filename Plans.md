# Plan: Add CSV-based offline DNS fallback for testing & production

## TL;DR
SafeHold currently relies 100% on DNS for policy decisions. We'll add an explicit **`-UseOfflinePolicy`** parameter that loads policies from CSV files stored in `Program Files\SafeHold\policies\` (protected, non-user-modifiable). Tests can use this mode offline; production defaults to DNS but can opt-in if needed. CSV format: `extension,status,reason,alt,url`. Implementation spans Agent, Launcher, and test infrastructure.

---

## Steps

### Phase 1: Core Infrastructure (CSV parsing & storage)

1. **Create CSV policy file structure in repo** (for version control & bundling)
   - Store in `dns/policies/` (alongside current examples)
   - Create `dns/policies/extensions.csv` with headers: `extension,included`
   - Create `dns/policies/{ext}.csv` with headers: `status,reason,alt,url` for each extension
   - Example: `pdf.csv`, `zip.csv`, `7z.csv`
   - Populate with data matching current DNS examples

2. **Implement CSV parser in SafeHold-Common.ps1**
   - Add `Get-PolicyFromCsv` function that reads CSV and returns hashtable (same structure as DNS parser)
   - Handles missing files gracefully with logging
   - *depends on step 1*

3. **Update Agent to support -UseOfflinePolicy parameter**
   - Add parameter to SafeHoldAgent.ps1 function signature
   - Add conditional logic: if `-UseOfflinePolicy $true`, call `Get-PolicyFromCsv` instead of `Get-TxtRecord`
   - Update Agent logging to indicate "offline mode" when active
   - Default: DNS mode (no behavior change for existing users)
   - *depends on step 2*

4. **Update Launcher to support -UseOfflinePolicy parameter**
   - Add parameter to SafeHoldLauncher.ps1
   - Same conditional logic as Agent
   - *depends on step 2*

### Phase 2: Deployment & installer updates

5. **Copy CSV policies to installer output**
   - Update Install-SafeHold.ps1 to copy `dns/policies/*.csv` files to `C:\Program Files\SafeHold\policies\`
   - Verify permissions are read-only for non-admins
   - Update Uninstall-SafeHold.ps1 to clean up `policies\` folder
   - *depends on step 1 & 3*

6. **Update agent scheduled task to pass -UseOfflinePolicy parameter** (or leave default as DNS)
   - Decide: should production installs use offline mode by default or opt-in?
   - Current recommendation: Keep DNS as default; offline is testing-focused or emergency fallback
   - *depends on step 5*

### Phase 3: Test automation & simulator

7. **Populate test scenarios with offline mode**
   - Update `tests/scenarios/scenario-0{1-3}.txt` to reference CSV-based testing
   - Add scenario files for "Day 5: DNS down" using offline mode

8. **Build automated test runner** (PowerShell script)
   - Create `tests/run-all-tests.ps1` that:
     - Loops through each scenario
     - Calls Agent with `-UseOfflinePolicy $true`
     - Validates registry changes against expected state from testmatrix.md
     - Generates pass/fail report
   - *depends on step 7*

9. **Implement simulator** (run-simulator.ps1)
   - Orchestrate multi-day testing: call Agent once per day, inject offline policies
   - Update registry between days to simulate time passing
   - Validate state machine transitions match test matrix
   - Report Day 5 DNS failure behavior (should NO-OP)
   - *depends on step 7 & 8*

### Phase 4: Documentation & validation

10. **Document offline policy format**
    - Add to docs/README.md: CSV schema, file locations, parameter usage
    - Show example: how to run Agent with `-UseOfflinePolicy $true`
    - Explain use cases: testing, emergency manual override, CI/CD integration

11. **Validate the complete test matrix** (docs/testmatrix/testmatrix.md)
    - Day 1–4: Verify state transitions with CSV policies
    - Day 5: Verify NO-OP when using offline mode (DNS is assumed "working")
    - Day 6: Verify Day 2 behavior repeats

---

## Relevant files

### To Create
- `dns/policies/extensions.csv` — master list of extensions
- `dns/policies/pdf.csv` — PDF policies (status, reason, alt, url)
- `dns/policies/zip.csv` — ZIP policies
- `dns/policies/7z.csv` — 7z policies
- `tests/run-all-tests.ps1` — test runner orchestrator

### To Modify
- `src/utils/SafeHold-Common.ps1` — add `Get-PolicyFromCsv` function
- `src/agent/SafeHoldAgent.ps1` — add `-UseOfflinePolicy` parameter, conditional logic
- `src/launcher/SafeHoldLauncher.ps1` — add `-UseOfflinePolicy` parameter, conditional logic
- `src/installer/Install-SafeHold.ps1` — copy policies to Program Files
- `src/installer/Uninstall-SafeHold.ps1` — clean up policies folder
- `tests/simulator/run-simulator.ps1` — implement multi-day simulator
- `docs/README.md` — document offline mode

---

## Verification

1. **Manual test**: Run `SafeHoldAgent.ps1 -UseOfflinePolicy $true` with a test file type, validate registry is updated correctly
2. **Manual test**: Run `SafeHoldLauncher.ps1 -UseOfflinePolicy $true` on a test file, validate policy popup shows CSV-loaded policy
3. **Automated test**: Run `tests/run-all-tests.ps1`, confirm all scenarios pass (Days 1–6, including Day 5 NO-OP)
4. **Simulator**: Run `tests/simulator/run-simulator.ps1`, verify state machine transitions match test matrix
5. **Installer**: Run `Install-SafeHold.ps1`, verify `C:\Program Files\SafeHold\policies\` files exist and are read-only
6. **Uninstaller**: Run `Uninstall-SafeHold.ps1`, verify policies folder is cleaned up

---

## Decisions

- **Format**: CSV (option 2) — simple, human-readable, easy to parse with `Import-Csv`
- **Activation**: Explicit parameter `-UseOfflinePolicy` (option 2) — keeps DNS as default, testing opts-in
- **Storage**: `dns/policies/` in repo for version control; deployed to `C:\Program Files\SafeHold\policies\` (read-only)
- **Scope**: Testing + production fallback — if a user runs Agent with `-UseOfflinePolicy $true`, it uses CSV instead of DNS
- **Default behavior**: No change — Agent and Launcher still use DNS unless explicitly told otherwise
- **CSV location**: Duplicated (repo for testing, Program Files for deployed installs) — ensures tests are version-controlled and deployments are protected

---

## Further Considerations

1. **Should CSV policies be updated remotely like DNS?**
   - Recommendation: No — CSV is for testing & emergency manual override only. DNS is the authoritative source for production.
   - Alternative: Create a separate admin tool to update Program Files policies, but this requires more governance.

2. **What happens if Day 5 test runs with offline mode?**
   - Currently: No DNS needed, so Day 5 "DNS down" scenario won't test the actual fail-safe.
   - Recommendation: Keep DNS as default for production; add a separate "offline mode test" scenario that doesn't need to test DNS failure.

3. **CSV schema evolution**
   - If new policy fields are added in future, CSV format supports them naturally (new columns).
   - Both DNS parser and CSV parser should accept optional fields with defaults.
