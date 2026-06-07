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

The GitHub installer pins a release **tag** and verifies a **SHA256 checksum**,
so a release is a few coordinated steps. Say you're going from `1.0.0` -> `1.1.0`:

1. **Edit the tool** and bump `.VERSION` to `1.1.0` (and `.RELEASENOTES`) in the
   `<#PSScriptInfo #>` block of `CursedCursor.ps1`. Commit and push to `main`.

2. **Regenerate the checksum** from the file *as raw GitHub serves it* (LF line
   endings — do NOT hash your local CRLF working copy):

   ```powershell
   $tmp = New-TemporaryFile
   irm 'https://raw.githubusercontent.com/r000bin/cursed-cursor/main/CursedCursor.ps1' -OutFile $tmp
   $h = (Get-FileHash $tmp -Algorithm SHA256).Hash
   "$h  CursedCursor.ps1" | Set-Content .\CursedCursor.ps1.sha256
   Remove-Item $tmp
   ```

3. **Bump the installer's default** `$Ref` to `'v1.1.0'` in `install.ps1`.

4. **Commit, then tag and push** so the tag holds the matching script +
   checksum + installer:

   ```powershell
   git add -A; git commit -m "Release v1.1.0"
   git tag v1.1.0; git push; git push --tags
   ```

5. **Publish to the Gallery** (immutable versions — you can only go up):

   ```powershell
   Publish-Script -Path .\CursedCursor.ps1 -NuGetApiKey $env:PSGALLERY_KEY
   ```

> Optional: turn the tag into a formal GitHub Release (web UI or
> `gh release create v1.1.0`) for release notes and download stats.
