# Releasing a new version

The GitHub installer (`install.ps1`) pins a release **tag** and verifies the
downloaded `CursedCursor.ps1` against a published **SHA256 checksum**, so cutting
a release is a few coordinated steps. Say you're going from `1.0.0` -> `1.1.0`:

1. **Edit the tool** and bump `.VERSION` (note changes under `.RELEASENOTES`) in
   the `<#PSScriptInfo #>` block at the top of `CursedCursor.ps1`. Commit and
   push to `main`.

2. **Regenerate the checksum** from the file *as raw GitHub serves it* (LF line
   endings — do NOT hash your local CRLF working copy, or the installer and CI
   will reject it):

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

That's it — `irm .../install.ps1 | iex` now installs `v1.1.0` with a verified
checksum. CI re-checks the checksum on every push, so an inconsistent pair fails
the build.

> Optional: turn the tag into a formal GitHub Release (web UI or
> `gh release create v1.1.0`) for release notes and download stats.
