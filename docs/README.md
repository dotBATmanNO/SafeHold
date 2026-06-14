# SafeHold

SafeHold er et DNS-styrt sikkerhetssystem som midlertidig kan blokkere eller omdirigere åpning av filtyper som anses sårbare. Systemet består av to hovedkomponenter:

- **SafeHoldLauncher** – reagerer når brukeren åpner en fil  
- **SafeHoldAgent** – setter og rydder opp i filassosiasjoner basert på DNS-policy  

SafeHold er designet for å være:

- reversibelt  
- robust  
- idempotent  
- enkelt å distribuere (GPO, Intune, manuell installasjon)

---

## Arkitekturdiagram

Dette diagrammet viser hele SafeHold-flyten fra DNS-policy → agent → registry → launcher → bruker.

```
                         ┌──────────────────────────────┐
                         │  DNS (policy)                │
                         │                              │
                         │  extensions.safehold.test    │
                         │      → "pdf;zip;7z"          │
                         │                              │
                         │  pdf.safehold.test           │
                         │      → "status=hold;..."     │
                         └───────────────┬──────────────┘
                                         │
                                         │ leses av
                                         ▼
                         ┌──────────────────────────────┐
                         │  SafeHoldAgent               │
                         │                              │
                         │  • sjekker DNS fungerer      │
                         │  • leser liste over EXT      │
                         │  • setter redirect           │
                         │  • tar backup                │
                         │  • restore ved endret policy │
                         │  • restore ved slettet EXT   │
                         │  • NO\-OP ved DNS-feil       │
                         └───────────────┬──────────────┘
                                         │
                                         │ skriver til
                                         ▼
                         ┌───────────────────────────────┐
                         │  Windows Registry (HKCU)      │
                         │                               │
                         │  .pdf → SafeHold.Redirect     │
                         │  Backup\pdf → Original ProgID │
                         └───────────────┬───────────────┘
                                         │
                                         │ trigges når bruker
                                         │ åpner fil
                                         ▼
                         ┌───────────────────────────────┐
                         │  SafeHoldLauncher             │
                         │                               │
                         │  • mottar filsti              │
                         │  • slår opp EXT               │
                         │  • leser DNS-policy           │
                         │  • viser blokkering/alternativ│
                         │  • ingen registry-endringer   │
                         └───────────────┬───────────────┘
                                         │
                                         │ viser popup
                                         ▼
                         ┌──────────────────────────────┐
                         │  Brukeropplevelse            │
                         │                              │
                         │  "Denne filtypen er i HOLD"  │
                         │  "Alternativ: Åpne i Edge"   │
                         └──────────────────────────────┘
```

---

## Komponenter

### SafeHoldAgent

Agenten kjører regelmessig og:

1. Leser `extensions.safehold.internal.test`  
2. Stopper umiddelbart hvis DNS ikke svarer (fail-safe)  
3. For hver EXT i listen:  
   - Leser `ext.safehold.internal.test`  
   - Hvis `status=hold` → redirect + backup  
   - Hvis ikke hold → restore  
4. Rydder opp:  
   - EXT som tidligere var i hold, men nå er fjernet fra DNS  
   - Stray redirects uten backup  
5. Logger til `C:\ProgramData\SafeHold\agent.log`

### SafeHoldLauncher

Launcheren erstatter standardprogrammet for en filtype når den er i HOLD.

- Tar imot `-File`  
- Leser EXT  
- Leser DNS-policy  
- Viser popup med årsak, alternativ og URL  
- Endrer aldri registry  

---

## DNS-policy

SafeHold styres 100 % via DNS TXT-records.

### Liste over filtyper

```
extensions.safehold.internal.test → "pdf;zip;7z"
```

### Policy for en filtype

```
zip.safehold.internal.test → "status=hold;reason=ZIP blokkert;alt=7-Zip;url=https://..."
```

---

## State-machine

Se `docs/state-machine/state-machine.md` for full state-maskin og beslutningslogikk.

---

## Testmatrise

Se `docs/testmatrix/testmatrix.md` for full livssyklus fra:

- Dag 1: ingen policy  
- Dag 2: EXT i hold  
- Dag 3: EXT i ok  
- Dag 4: EXT fjernet  
- Dag 5: DNS nede  
- Dag 6: EXT tilbake i hold  

---

## Mappestruktur

```
SafeHold/
├── src/
│   ├── launcher/
│   ├── agent/
│   ├── installer/
│   └── utils/
├── docs/
│   ├── diagrams/
│   ├── state-machine/
│   └── testmatrix/
├── dns/
│   └── examples/
├── tests/
│   ├── scenarios/
│   └── simulator/
└── .github/
    └── workflows/
```

---

## Lisens

Dette prosjektet kan lisensieres etter behov (MIT anbefales for enkelhet).