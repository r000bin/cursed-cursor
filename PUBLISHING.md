# Publishing to the PowerShell Gallery

`CursedCursor.ps1` carries a `PSScriptInfo` metadata block at the top, so it can
be published as a Gallery *script* (installed by users with `Install-Script`).

## One-time setup

1. **Create a Gallery account** at <https://www.powershellgallery.com> (sign in
   with a Microsoft/GitHub account).
2. **Get your API key:** profile → *API Keys* → create one scoped to *Push new
   packages and package versions*. Treat it like a password — don't commit it.
3. **Update the publishing tooling** (the built-in PowerShellGet 1.0.0.1 is old):

   ```powershell
   Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
   Install-Module -Name PowerShellGet -Force -AllowClobber -Scope CurrentUser
   # restart PowerShell so the new module loads
   ```

## Publish a release

From the repo root:

```powershell
# 1. Sanity-check the metadata parses
Test-ScriptFileInfo -Path .\CursedCursor.ps1

# 2. Push it (use your real key; or set $env:PSGALLERY_KEY first)
Publish-Script -Path .\CursedCursor.ps1 -NuGetApiKey $env:PSGALLERY_KEY
```

It appears at <https://www.powershellgallery.com/packages/CursedCursor> within a
few minutes. Users then install with:

```powershell
Install-Script -Name CursedCursor -Scope CurrentUser
```

## Shipping an update

1. Bump `.VERSION` in the `<#PSScriptInfo #>` block at the top of
   `CursedCursor.ps1` (semantic versioning, e.g. `1.0.0` -> `1.1.0`).
2. Note what changed under `.RELEASENOTES`.
3. Commit, tag (`git tag v1.1.0 && git push --tags`), then run `Publish-Script`
   again. Gallery versions are immutable — you can't overwrite a published
   version, only publish a higher one.
