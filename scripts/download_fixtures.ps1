$ids = @(1342,11,84,1661,98,1952,2701,1400,74,76,25344,345,2600,1080,205,46,1260,768,158,5200,3207,2591,1497,2814,4300,219,174,996,30254,1232)
$outDir = "C:\SOURCE\Mia-Legilo\test\fixtures\epub"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
foreach ($id in $ids) {
  $dest = Join-Path $outDir "$id.epub"
  if (Test-Path $dest) { Write-Host "skip $id"; continue }
  $url = "https://www.gutenberg.org/ebooks/$id.epub.images"
  try {
    Invoke-WebRequest -Uri $url -OutFile $dest -TimeoutSec 60 -UseBasicParsing
    Write-Host "downloaded $id"
  } catch {
    Write-Host "failed $id : $($_.Exception.Message)"
    # try noimages
    try {
      Invoke-WebRequest -Uri "https://www.gutenberg.org/ebooks/$id.epub.noimages" -OutFile $dest -TimeoutSec 60 -UseBasicParsing
      Write-Host "downloaded $id (noimages)"
    } catch {
      Write-Host "failed $id noimages"
    }
  }
}
Write-Host "done"