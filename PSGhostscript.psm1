# Import all public functions
. "$PSScriptRoot\public\Compress-PDF.ps1"
. "$PSScriptRoot\public\Compress-PDFBatch.ps1"

Export-ModuleMember -Function Compress-PDF
Export-ModuleMember -Function Compress-PDFBatch