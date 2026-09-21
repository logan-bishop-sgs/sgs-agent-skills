# ChemStation EDA — this PC

> Last verified: 2026-09-18

Facts from `C:\msdchem` and `C:\msdchem.ini` (also appears as
`C:\Windows\msdchem.ini` content under `[PCS]` / `[PCS,1]`).

## Version

| | |
|---|---|
| Product | MSD ChemStation Data Analysis (`msda.exe`) |
| File / product version | E.02.02 |
| Startup log banner | `MSD ChemStation E.02.02.1431` (© 1989–2011 Agilent) |
| `envinit.mac` header | G1701DA D.02.00 (macros older than the EXE) |
| Publisher | Agilent Technologies, Inc. |

## Layout

```
C:\msdchem\
  1\                 instrument 1 (offline)
    5975\            tunes (atune.u, bfb.u, dftpp.u, …)
    data\            *.D run folders (evaldemo.d)
    methods\         checkout, default, default.m
    sequence\        default.s
  MSexe\             EXEs, CHM help, envinit.mac, envtop.mac
  envforms\          Access 97 Environmental Forms
  msmacros\          169 system/user macros
  gcmacros\          141 GC macros
  custrpt\           custom report engine + MDBs
  Supplemental\      Developer Information + Utility Programs
C:\DATABASE\         demo.l only on this image
```

Configured DA paths (`[PCS,1]`):

| Variable | Value |
|---|---|
| `_INSTPATH$` | `C:\msdchem\1\` |
| `_DATAPATH$` / `_DATAFILE$` | `C:\msdchem\1\DATA\` / `EVALDEMO.D` |
| `_METHPATH$` / `_METHFILE$` | `C:\msdchem\1\METHODS\` / `DEFAULT.M` |
| `_SEQPATH$` / `_SEQFILE$` | `C:\msdchem\1\SEQUENCE\` / `DEFAULT.S` |
| `_LIBPATH$` | `C:\DATABASE\` |
| `_TUNEPATH$` | `C:\msdchem\1\5975\` |
| `_AUTOPATH$` / `_EXEPATH$` | `C:\msdchem\MSEXE\` |
| `INSTNAME` | `OFFLINE` |
| `Offline` | `1` |
| `NOTOP` | `1` |

A **data file** is a directory `name.D` containing at least `data.ms`.
A **method** is a directory `name.M` (this image's `default.m` includes
`acq.ms`, `deuser.mac`, `cqual.mac`, `envdaver.mac`, EPA/BFB/DFTPP
val files). A **sequence** is `name.S`.

## Start Menu → EXE

| Shortcut | Target | Arguments | Work dir |
|---|---|---|---|
| OFFLINE Data Analysis | `C:\msdchem\MSexe\msda.exe` | `1, envorphinit, envinit.mac` | `C:\msdchem\MSexe\` |
| OFFLINE | `C:\msdchem\MSexe\mstop.exe` | `1 ,envtop, envtop.mac` | `C:\msdchem\MSexe\` |
| Environmental Forms | `C:\msdchem\envforms\envforms.bat` | `C:\msdchem` | `C:\msdchem\envforms` |
| Agilent MSD Configuration | `msconfig.net.exe` | | `C:\msdchem\Msexe` |
| Batch Summary Report | `batsum.exe` | | |
| Report Manager | `request.exe` | | |
| Tune Report | `tuneplot.exe` | | |

Other EXEs in `MSexe` (not started unless needed):
`FileConverterUtility.exe` (post-unicode → pre-unicode signal),
`DataFileViewer.exe`, `Emethodlauncher.exe`, `MethInfo.exe`,
`custrpt.exe` (under `custrpt\`).

Startup log for orphan DA: `C:\msdchem\MSexe\daorphstart1.log`.

## Interop DLLs (do not poke until we have a job)

`MsdChemCmd.dll`, `CommandProcessorEx.dll`, `AgtDDE.dll`,
`HiaCpCom.dll`, `RCNetCOMInterop.dll`, `rtecmds.dll`,
`topcommands.dll`, `mstopcmd.dll`. Sample-prep stack:
`Agilent.Automation.SamplePrep.*.dll`.

## Vendor docs (web)

- Macro Programming Guide (G2070-90107):
  https://www.agilent.com/cs/library/usermanuals/Public/MACROS.PDF
- Successor platform in the field is often **MassHunter**; this box
  is classic ChemStation E.02.02, not MassHunter.
