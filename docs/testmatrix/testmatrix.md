# SafeHold – Testmatrise

Denne matrisen dekker hele livssyklusen fra installasjon til steady state.

## Dag 1 – Ingen policy

| DNS       | HKCU           | Backup       | Forventet |
|-----------|----------------|--------------|-----------|
| Ingen EXT | Ingen override | Ingen backup | NO-OP     |

## Dag 2 – ZIP settes i HOLD

| DNS      | HKCU           | Backup       | Forventet            |
|----------|----------------|--------------|----------------------|
| zip=hold | Ingen override | Ingen backup | SetRedirect + Backup |

## Dag 3 – ZIP endres til OK

| DNS    | HKCU     | Backup | Forventet |
|--------|----------|--------|-----------|
| zip=ok | Redirect | Backup | Restore   |

## Dag 4 – ZIP fjernes fra DNS

| DNS         | HKCU     | Backup       | Forventet      |
|-------------|----------|--------------|----------------|
| zip fjernet | Redirect | Backup       | Restore        |
| zip fjernet | Redirect | Ingen backup | Fjern override |

## Dag 5 – DNS nede

| DNS      | HKCU          | Backup        | Forventet |
|----------|---------------|---------------|-----------|
| DNS-feil | Hva som helst | Hva som helst | NO-OP     |

## Dag 6 – ZIP tilbake i HOLD

| DNS      | HKCU           | Backup       | Forventet            |
|----------|----------------|--------------|----------------------|
| zip=hold | Ingen override | Ingen backup | SetRedirect + Backup |
