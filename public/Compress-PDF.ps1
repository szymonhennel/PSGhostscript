function Compress-PDF {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [switch]$Remove
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
    if ($PSCmdlet.ShouldProcess($FilePath, "Compress using Ghostscript with -dPDFSETTINGS=/ebook")) {
        try {
            Rename-Item -Path $FilePath -NewName $originalFilePath
            Write-Verbose "Renamed '$FilePath' to '$originalFilePath'"

            # Step 2: Check for success of the renaming
            if (-Not (Test-Path $originalFilePath)) {
                Write-Error "Failed to rename '$FilePath' to '$originalFilePath'."
                return
            }

            $originalFileSize = (Get-Item $originalFilePath).Length

            # Step 3: Compress the PDF using Ghostscript
            $ghostscriptVerbosityOption = if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Verbose')) { "" } else { "-q" }
            
            $ghostscriptCommand = "gswin64c $ghostscriptVerbosityOption '-sDEVICE=pdfwrite' '-dCompatibilityLevel=2.0' '-dPDFSETTINGS=/ebook' -dNOPAUSE -dBATCH '-sOutputFile=$compressedFilePath' '$originalFilePath'"
            Write-Verbose "Executing `"$ghostscriptCommand`""
            
            Invoke-Expression $ghostscriptCommand
            Write-Verbose "Compressed '$originalFilePath' to '$compressedFilePath'"
            

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
                # Step 6: Remove the original file if -Remove is specified
                if ($Remove) {
                    Remove-ItemSafely -Path $originalFilePath
                    Write-Verbose "Moved original file '$originalFilePath' to recycle bin."
                }
            }
            $success = $true
        } catch {
            Write-Error $_.Exception.Message
            $success = $false
            $size_delta = 0
        }
        # Step 7: Return the result
        $success = $compressedFileSize -lt $originalFileSize -or $compressedFileSize -eq $originalFileSize
        return [PSCustomObject]@{
            GhostscriptSuccess = $success
            SizeDelta = $size_delta
            SizeDeltaMB = [Math]::Round($size_delta / 1MB, 2)
        }
    }   
}