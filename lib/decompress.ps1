function requires_7zip($manifest, $architecture) {
    foreach($dlurl in @(url $manifest $architecture)) {
        if(file_requires_7zip $dlurl) { return $true }
    }
}

function requires_lessmsi ($manifest, $architecture) {
    $useLessMsi = get_config MSIEXTRACT_USE_LESSMSI
    if (!$useLessMsi) { return $false }

    $(url $manifest $architecture | Where-Object {
        $_ -match '\.(msi)$'
    } | Measure-Object | Select-Object -exp count) -gt 0
}

function file_requires_7zip($fname) {
    $fname -match '\.((gz)|(tar)|(tgz)|(lzma)|(bz)|(bz2)|(7z)|(rar)|(iso)|(xz)|(lzh))$'
}

function extract_7zip($path, $to, $recurse) {
    $7zip = "& '$(7zip_path)' x '$path' -o'$to' -y -bso1 -bsp1 -bse1"
    $fname = fname $path
    $log = ''
    Invoke-Expression $7zip | ForEach-Object {
        $log += "    $_`n"
        if([String]::IsNullOrWhiteSpace($_)) {
            # skip blank lines
            return
        }
        if($_.StartsWith('Everything is Ok')) {
            Write-Host "`rExtracting " -NoNewline
            Write-Host $fname  -f Cyan -NoNewline
            Write-Host " ... " -NoNewline
            Write-Host "done." -f Green
        } elseif($_ -match '\s+(?<percent>[\d]{1,3}%)\s+\d\s+') {
            Write-Host "`rExtracting " -NoNewline
            Write-Host $fname  -f Cyan -NoNewline
            Write-Host " ... " -NoNewline
            Write-Host $matches['percent'] -f Cyan -NoNewline
        }
    }
    if($lastexitcode -ne 0) {
        Write-Host "`n***"
        debug $log $true
        Write-Host '***'
        debug $7zip $true
        Write-Host '***'
        error "Extraction failed! (Error $lastexitcode)"
        abort $(new_issue_msg $app $bucket "extraction with 7zip failed")
    }

    # check for tar
    $tar = (split-path $path -leaf) -replace '\.[^\.]*$', ''
    if($tar -match '\.tar$') {
        if(test-path "$to\$tar") { extract_7zip "$to\$tar" $to $true }
    }

    if($recurse) { Remove-Item $path } # clean up intermediate files
}
