function Compress-PDF {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [switch]$Remove,

        [Parameter(Mandatory=$false)]   
        [switch]$Touch,

        [Parameter(Mandatory=$false)]   
        [switch]$UpdateTimestamps,

        [Parameter(Mandatory=$false)]
        [string]$Version = '2.0',

        [Parameter(Mandatory=$false)]   
        [string]$Quality = 'ebook'
    )

    # Check if the file exists
    if (-Not (Test-Path $FilePath)) {
        Write-Error "File '$FilePath' does not exist."
        return
    }

    # Get the directory and filename details
    $directory = [System.IO.Path]::GetDirectoryName($FilePath)
    $filename = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $extension = [System.IO.Path]::GetExtension($FilePath)

    # Define the original and compressed file paths
    $originalFilePath = Join-Path $directory "$filename`_original$extension"
    $compressedFilePath = $FilePath

    # Step 1: Rename file.pdf to file_original.pdf
    if ($PSCmdlet.ShouldProcess($FilePath, "Compress using Ghostscript with -dCompatibilityLevel=$Version and -dPDFSETTINGS=/$Quality")) {
        try {
            $success = $true
            Rename-Item -Path $FilePath -NewName $originalFilePath
            Write-Verbose "Renamed '$FilePath' to '$originalFilePath'"

            # Step 2: Check for success of the renaming
            if (-Not (Test-Path $originalFilePath)) {
                Write-Error "Failed to rename '$FilePath' to '$originalFilePath'."
                return
            }

            $originalFileSize = (Get-Item $originalFilePath).Length

            # Step 3: Compress the PDF using Ghostscript
            $ghostscriptArgs = @(
                if ($PSBoundParameters.ContainsKey('Verbose')) { "" } else { "-q" } # Verbosity
                "'-sDEVICE=pdfwrite'",
                "'-dCompatibilityLevel=$Version'",
                "'-dPDFSETTINGS=/$Quality'",
                "-dNOPAUSE",
                "-dBATCH",
                "'-sOutputFile=$compressedFilePath'",
                "'$originalFilePath'"
            )

            $ghostscriptCommand = "gswin64c " + ($ghostscriptArgs -join ' ')
            Write-Verbose "Executing `"$ghostscriptCommand`""
            Invoke-Expression $ghostscriptCommand

            # Step 4: Check if Ghostscript was successful
            $success = $LASTEXITCODE -eq 0 -and (Test-Path $compressedFilePath)

            if ($success) {
                Write-Verbose "Compressed '$originalFilePath' to '$compressedFilePath'."

                # Step 4: Check the size difference
                $compressedFileSize = (Get-Item $compressedFilePath).Length

                $size_delta = $originalFileSize - $compressedFileSize

                # Step 5: If the compressed file is larger, replace it with the original
                if ($compressedFileSize -ge $originalFileSize) {
                    Remove-Item -Path $compressedFilePath
                    Rename-Item -Path $originalFilePath -NewName $compressedFilePath
                    Write-Verbose "Replaced compressed file with original due to larger size ($compressedFileSize vs $originalFileSize)"
                    $size_delta = 0
                } else {
                    if (-not $UpdateTimestamps -and -not $Touch) {
                        Set-FileDates $compressedFilePath $originalFilePath
                    }
                    # Step 6: Remove the original file if -Remove is specified
                    if ($Remove) {
                        Remove-ItemSafely -Path $originalFilePath
                        Write-Verbose "Moved original file '$originalFilePath' to recycle bin."
                    }
                }
            } else {
                Write-Error "Ghostscript failed to compress the PDF."
                Rename-Item -Path $originalFilePath -NewName $compressedFilePath
                Write-Verbose "Replaced compressed file with original due to failure to create compressed file."
                $size_delta = 0
            }
        } catch {
            Write-Error $_.Exception.Message
            $success = $false
            $size_delta = 0
        }

        # Step 7: Return the result
        return [PSCustomObject]@{
            GhostscriptSuccess = $success
            SizeDelta = $size_delta
            SizeDeltaMB = [Math]::Round($size_delta / 1MB, 2)
        }
    }   
}