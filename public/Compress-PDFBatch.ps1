function Compress-PDFBatch {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$TargetFolder,

        [Parameter(Mandatory=$false)]
        [switch]$Recurse,

        [Parameter(Mandatory=$false)]   
        [switch]$Touch,

        [Parameter(Mandatory=$false)]   
        [switch]$UpdateTimestamps,

        [Parameter(Mandatory=$false)]
        [string]$Version = '2.0',

        [Parameter(Mandatory=$false)]
        [string]$Quality = 'ebook'
    )

    # Ensure the target folder exists
    if (-Not (Test-Path $TargetFolder)) {
        Write-Error "Target folder '$TargetFolder' does not exist."
        return
    }

    # Get all PDF files in the target folder
    $pdfFiles = Get-ChildItem -Path $TargetFolder -Filter *.pdf -File -Recurse:$Recurse

    # Initialize counters
    $totalFiles = $pdfFiles.Count
    $successCount = 0
    $sizeReducedCount = 0
    $totalSizeDelta = 0

    foreach ($file in $pdfFiles) {
        if ($PSCmdlet.ShouldProcess($file.FullName, "Compress using Ghostscript with -dCompatibilityLevel=$Version and -dPDFSETTINGS=/$Quality")) {
            # Assuming Compress-PDF returns an object with properties: GhostscriptSuccess, SizeDelta
            Write-Host "Processing file $($pdfFiles.IndexOf($file) + 1) out of $totalFiles`: $($file.FullName)"
            $result = Compress-PDF -FilePath $file.FullName -Remove -Touch:($Touch -or $UpdateTimestamps) -Version $Version -Quality $Quality -Verbose:$PSBoundParameters.ContainsKey('Verbose')

            if ($result.GhostscriptSuccess) {
                $successCount++
                if ($result.SizeDelta -gt 0) {
                    $sizeReducedCount++
                    $totalSizeDelta += $result.SizeDelta
                }
            }
            Write-Verbose "Processed: $($file.Name)"
        }
    }

    if ($PSCmdlet.ShouldProcess($TargetFolder, "Report the outcome of all PDF files contained in folder $(if($Recurse) { 'recursively' } else { '(non-recursively)' })")) {
        $totalSizeDeltaMB = [Math]::Round($totalSizeDelta / 1MB, 2)

        # Generate and print the report
        $resultObject = [PSCustomObject]@{
            "Files processed" = $totalFiles
            "Successful" = $successCount
            "Reduced size" = $sizeReducedCount
            "Size delta (MB)" = $totalSizeDeltaMB
        }
        
        # Print the object as a table
        $resultObject | Format-Table -AutoSize
    }
}