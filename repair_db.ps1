$in='C:\Users\WALTON\Documents\hishab_pro_new\backup_inspect.db'
$out='C:\Users\WALTON\Documents\hishab_pro_new\backup_inspect_repaired.db'
[byte[]]$b = [System.IO.File]::ReadAllBytes($in)
$orig = $b[0]
$b[0] = 0x53
[System.IO.File]::WriteAllBytes($out,$b)
$head = -join ($b[0..15] | ForEach-Object { $_.ToString('X2') })
Write-Output "orig=0x$([Convert]::ToString($orig,16))"
Write-Output "hexhead=$head"
Write-Output "len=$($b.Length)"
Get-FileHash $out -Algorithm MD5 | Format-List
