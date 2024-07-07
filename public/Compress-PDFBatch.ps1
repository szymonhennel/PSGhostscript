function Compress-PDFBatch {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$TargetFolder,

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
    $pdfFiles = Get-ChildItem -Path $TargetFolder -Filter *.pdf -File

    # Initialize counters
    $totalFiles = $pdfFiles.Count
    $successCount = 0
    $sizeReducedCount = 0
    $totalSizeDelta = 0

    foreach ($file in $pdfFiles) {
        if ($PSCmdlet.ShouldProcess($file.FullName, "Compressing PDF")) {
            # Assuming Compress-PDF returns an object with properties: GhostscriptSuccess, SizeDelta
            $result = Compress-PDF -FilePath $file.FullName -Remove -Version $Version -Quality $Quality

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