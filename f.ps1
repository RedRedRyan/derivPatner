Get-ChildItem -Path .\src -Recurse -Include *.ts,*.tsx,*.js,*.jsx |
  Select-String -Pattern 'from [''"]@/([^''"]+)[''"]' -AllMatches |
  ForEach-Object {
    foreach ($m in $_.Matches) {
      $importPath = $m.Groups[1].Value
      $base = Join-Path .\src $importPath
      $exists = @(
        "$base.ts", "$base.tsx", "$base.js", "$base.jsx",
        (Join-Path $base "index.ts"), (Join-Path $base "index.tsx")
      ) | Where-Object { Test-Path $_ }
      if (-not $exists) {
        [PSCustomObject]@{ File = $_.Path; Import = $importPath }
      }
    }
  } | Sort-Object Import -Unique | Format-Table -AutoSize
