$bookmarks = Get-Content .\favorites_8_6_21.html

switch -regex ($bookmarks.GetEnumerator()) {
    '^\s{0,40}\<DT\>\<A\sHREF\=\"(?<url>\S*)\"\sADD_DATE\=\"\d+\"\sICON\=\"\S*\"\>(?<title>.*)\<\/A\>$' {Write-Host "Match with icon: $($Matches.url)"}
    '^\s{0,40}\<DT\>\<A\sHREF\=\"(?<url>\S*)\"\sADD_DATE\=\"\d+\">(?<title>.*)\<\/A\>$' {Write-Host "Match without icon: $($Matches.url)"}
}

# All set