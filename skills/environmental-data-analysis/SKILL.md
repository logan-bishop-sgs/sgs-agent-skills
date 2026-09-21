---
name: environmental-data-analysis
description: >-
  Maps Agilent MSD ChemStation Environmental Data Analysis (EnviroQuant /
  OFFLINE Data Analysis, msda.exe) on this PC: what it is, launch args,
  macros, DDE/command-processor surfaces, local help, and PowerShell
  start commands. Use when the user says environmental data analysis,
  EnviroQuant, ChemStation, msda, envforms, instrument results, or
  automate lab data analysis.
---

# Environmental Data Analysis (ChemStation)

**Talk to the user** with `.cursor/library-notes/voice.md`. This skill
is a **map**, not a runner. Do not invent a CLI. Do not launch `msda.exe`
unless they asked you to open it. Do not pass `/?` or `-h` — that just
starts the GUI.

When they only want orientation: say what the app is, that we start it
from PowerShell the same way the Start Menu does, and that real
automation is **macros** (and old DDE), not a PowerShell module.

## What it is

Labs use this to **quantify GC/MS runs** after the instrument writes a
data file. Official product: **Agilent MSD ChemStation**
**E.02.02.1431** (G1701, 1989–2011). The environmental package is
**EnviroQuant** / Environmental Data Analysis.

On this PC the Start Menu names are:

| Shortcut | What it actually starts |
|---|---|
| **OFFLINE Data Analysis** | `msda.exe` + env startup macros |
| **Environmental Forms** | Access 97 + `envforms.mdb` (CLP-style forms) |
| OFFLINE | `mstop.exe` (top launcher; this box sets `NOTOP=1`) |
| Batch Summary Report | `batsum.exe` |
| Report Manager | `request.exe` |

This install is **offline analysis only** (`INSTNAME=OFFLINE`,
`Offline=1`). It is not driving a live GC/MS from this desktop.
Instrument #1 is typed as a **5975** MSD (tune files under
`C:\msdchem\1\5975\`). Config still has lab LAN IPs
(`10.1.1.101` / `10.1.1.102`) from the original lab image.

Install root: **`C:\msdchem`**. Paths and file types:
[reference.md](reference.md).

## There is no standalone CLI

`msda.exe` has **no** documented `/help` switch. The only supported
"command line" is the Start Menu pattern:

```text
msda.exe <instrument>, <startup-macro>, <macro-file>
```

This PC's Data Analysis shortcut:

```powershell
Start-Process -FilePath 'C:\msdchem\MSexe\msda.exe' `
  -ArgumentList '1, envorphinit, envinit.mac' `
  -WorkingDirectory 'C:\msdchem\MSexe\'
```

- `1` = instrument number (`C:\msdchem\1\`)
- `envorphinit` = startup macro inside `envinit.mac` (orphan / extra DA
  session; writes `daorphstart1.log`)
- `envinit.mac` = environmental DA init (loads EnviroQuant, default
  method `C:\msdchem\1\methods\default.m`)

Environmental Forms (Access 97 runtime — already on this PC):

```powershell
Start-Process -FilePath 'C:\msdchem\envforms\envforms.bat' `
  -ArgumentList 'C:\msdchem' `
  -WorkingDirectory 'C:\msdchem\envforms'
```

The bat copies `envforms.bup` → `envforms.mdb` then
`start msaccess ... /runtime`.

That is the PowerShell control we have today: **start the same EXEs
the Start Menu starts**. There is no `Get-ChemStation` module.

## How automation actually works

When we get a real job, use these in this order:

1. **Macros (`.mac`)** — the real API. ChemStation command processor
   runs them. Startup file, method `deuser.mac` / `cqual.mac`, or
   prerun / custom DA / postrun on the method. Vendor guide:
   https://www.agilent.com/cs/library/usermanuals/Public/MACROS.PDF
2. **Launch + startup macro** — pass a *our* `.mac` as the third
   argument the same way `envinit.mac` is passed. Do not pixel-click
   the GUI first.
3. **Files on disk** — a run is a folder `*.D` with `data.ms`. A
   method is a folder `*.M`. A sequence is `*.S`. Demo data:
   `C:\msdchem\1\data\evaldemo.d`. We can read/copy those without
   opening the GUI.
4. **DDE / command DLLs** — `AgtDDE.dll`, `MsdChemCmd.dll`,
   `CommandProcessorEx.dll`, `HiaCpCom.dll`. Old ChemStation
   interop. Do not prototype this until we have a concrete task.
5. **UI click scripts** — last resort (same class of pain as AniTa).

Do **not** kill existing `msda.exe` / Access sessions. One extra
`/?` launch already opened a second DA window on this box.

## Docs and dev tools (local)

Read these on disk before searching the web:

| File | Use |
|---|---|
| `C:\msdchem\MSexe\EnviroQntDa.chm` | Environmental DA help |
| `C:\msdchem\MSexe\enviroqnt.chm` | EnviroQuant |
| `C:\msdchem\MSexe\EnhancedDA.chm` / `EnhancedDA-en.chm` | Enhanced Data Analysis |
| `C:\msdchem\MSexe\creports.chm` | Custom reports |
| `C:\msdchem\Supplemental\Advanced_Macro_Examples.chm` | Macro examples |
| `C:\msdchem\MSexe\Software Status Bulletin.pdf` | Version notes |
| `C:\msdchem\envforms\envforms.hlp` | Environmental Forms (old WinHelp) |
| `C:\msdchem\MSexe\envinit.mac` | How DA actually boots |
| `C:\msdchem\Supplemental\Developer Information\` | Sample macros (`protect`, 6890 IQ) |
| `C:\msdchem\Supplemental\Utility Programs\` | `copydata.mac`, `expdata.mac`, `idmerge`, CreateMS |

Also: **169** files in `C:\msdchem\msmacros`, **141** in
`C:\msdchem\gcmacros`. Custom reports: `C:\msdchem\custrpt\`.
Spectral library on this image: `C:\DATABASE\demo.l` only.

## What we have not done

No extract script. No SharePoint drop. No LIMS hook. No proven DDE
round-trip. Stop at this map until Logan names a job (export a
quant report, batch a folder of `.D` files, feed Accutest, etc.).
