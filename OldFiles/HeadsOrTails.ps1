#[string]$name = Read-Host "Please enter your name"; [int]$countFlip = Read-Host "How many times would you like to flip the coin?"; $countHeads = $countTails = $countToFlip = 0; do { $countToFlip++; $headsOrTails = $(Get-Random) % 2; if ($headsOrTails -eq 0) { $countHeads++ } else { $countTails++ } } until ($countToFlip -eq $countFlip); Write-Output "$name flipped the coin $countFlip times`r`nHeads: $countHeads`tTails: $countTails"


Get-Content C:\path\machinelist.txt | ForEach-Object -parallel  { Invoke-Command -Scriptblock {C:\path\onboardingARC.ps1 -ComputerName $_} -Credential $cred }