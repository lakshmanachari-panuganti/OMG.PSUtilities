function Get-PSUBatchDirectoryObjects {
    <#
    .SYNOPSIS
      Batch-get directory objects from Microsoft Graph using /$batch to reduce per-object calls.
    .PARAMETER Ids
      Array of directory object ids to retrieve.
    .OUTPUTS
      Array of parsed Directory objects (has id, displayName, mail, userPrincipalName, @odata.type)
    #>
    param([string[]] $Ids)

    if (-not $Ids -or $Ids.Count -eq 0) { return @() }

    # Graph batch supports up to 20 requests per batch
    $chunkSize = 20
    $out = @()

    foreach ($chunk in ($Ids | ForEach-Object -Begin { $i=0 } -Process { [PSCustomObject]@{Index = [int]($i++); Id = $_ } } | Group-Object { [int]($_.Index / $chunkSize) } | ForEach-Object { $_.Group | Select-Object -ExpandProperty Id })) {
        # Build requests for this chunk
        $requests = @()
        $reqId = 1
        foreach ($id in $chunk) {
            $requests += @{
                id = "$reqId"
                method = "GET"
                url = "/directoryObjects/$id"
            }
            $reqId++
        }
        $body = @{ requests = $requests }

        try {
            $resp = Invoke-MgGraphRequest -Method POST -Uri '/$batch' -Body ($body | ConvertTo-Json -Depth 5) -ContentType 'application/json'
        } catch {
            Write-Verbose "Graph batch request failed: $_"
            # fall back: try per-id
            foreach ($id in $chunk) {
                try {
                    $obj = Get-MgDirectoryObject -DirectoryObjectId $id -ErrorAction Stop
                    if ($obj) { $out += $obj }
                } catch { Write-Verbose "Get-MgDirectoryObject failed for $id`: $_" }
            }
            continue
        }

        # resp has 'responses' array
        if ($resp -and $resp.responses) {
            foreach ($r in $resp.responses) {
                if ($r.status -ge 200 -and $r.status -lt 300) {
                    # content is a JSON object - parse
                    $contentJson = $r.body | ConvertTo-Json -Compress
                    # The SDK returns objects already - but to be safe, rehydrate minimal properties
                    $obj = $r.body
                    $out += $obj
                } else {
                    Write-Verbose "Batch sub-request failed (id $($r.id)) status $($r.status)"
                }
            }
        }
    }

    return $out
}
