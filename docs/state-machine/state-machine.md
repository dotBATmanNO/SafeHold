# SafeHoldAgent – State Machine

Denne state-maskinen beskriver hvordan SafeHoldAgent håndterer hver filtype basert på DNS-policy og eksisterende registry-tilstand.

## Tilstander

### NotHandled
- Ingen backup
- Ingen redirect
- HKCU har ingen SafeHold-override

### Redirected
- HKCU\.ext = SafeHold.Redirect
- Backup finnes

### Restored
- HKCU\.ext = original ProgID
- Backup slettet

## Beslutningspunkter

1. **DNS fungerer?**
   - Nei → NO-OP
   - Ja → fortsett

2. **EXT i extensions.safehold.internal.domain?**
   - Nei → cleanup (restore)
   - Ja → slå opp EXT-policy

3. **status=hold?**
   - Ja → SetRedirect
   - Nei → Restore

4. **Cleanup**
   - Hvis backup finnes → restore original
   - Hvis redirect uten backup → slett override
   - Hvis ingen av delene → ingen endring

## Diagram

Se `docs/diagrams/safehold-agent.drawio` for komplett grafisk diagram.