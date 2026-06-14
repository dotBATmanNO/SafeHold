# SafeHold
<!-- Badges -->
[![CI Status](https://github.com/dotbatmanno/SafeHold/actions/workflows/ci.yml/badge.svg)](https://github.com/dotbatmanno/SafeHold/actions/workflows/ci.yml)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green)

SafeHold er et DNS-styrt sikkerhetssystem som midlertidig kan blokkere eller omdirigere åpning av filtyper som anses sårbare. Systemet består av to hovedkomponenter:

- **SafeHoldLauncher** – reagerer når brukeren åpner en fil  
- **SafeHoldAgent** – setter og rydder opp i filassosiasjoner basert på DNS-policy  

SafeHold er designet for å være:
- reversibelt  
- robust  
- idempotent  
- enkelt å distribuere (GPO, Intune, manuell installasjon)

---

## Dokumentasjon

All dokumentasjon ligger i `docs/`:

- `docs/README.md` – hoveddokumentasjon  
- `docs/state-machine/state-machine.md` – full state-machine  
- `docs/testmatrix/testmatrix.md` – testmatrise  
- `docs/diagrams/safehold-agent.drawio` – arkitekturdiagram  

---

## Kode

Kildekode ligger i `src/`:

- `src/launcher/` – SafeHoldLauncher  
- `src/agent/` – SafeHoldAgent  
- `src/installer/` – installasjons- og avinstallasjonsskript  
- `src/utils/` – fellesfunksjoner  

---

## DNS-policy

SafeHold styres 100% via DNS TXT-records.

Eksempel:

```
extensions.safehold.internal.test → "pdf;zip;7z"
zip.safehold.internal.test → "status=hold;reason=ZIP blokkert;alt=7-Zip"
```

Eksempler ligger i `dns/examples/`.

---

## Tester

Testoppsett ligger i `tests/`:

- `tests/scenarios/` – manuelle scenarier  
- `tests/simulator/` – simulator for mock-DNS  

---

## CI/CD

GitHub Actions workflow ligger i:

`.github/workflows/ci.yml`

Workflowen kjører:

- PSScriptAnalyzer  
- Linting av PowerShell-kode  
- Strukturkontroll  

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