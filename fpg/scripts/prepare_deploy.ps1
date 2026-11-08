param([string]$Artifacts='', [string]$VitisRoot='C:/Xilinx/Vitis/2020.2')
$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if(!$Artifacts){$Artifacts=Join-Path $repo 'fpg/artifacts'}
$Artifacts=(Resolve-Path -LiteralPath $Artifacts).Path
$state=Join-Path $repo 'build/deploy'
New-Item -ItemType Directory -Force $state | Out-Null
foreach($name in @('ditto_npu.bit','ditto_npu.xsa','ditto_npu.elf')) {if(!(Test-Path -LiteralPath (Join-Path $Artifacts $name))){throw "Missing artifact $name"}}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead((Join-Path $Artifacts 'ditto_npu.xsa'))
try {
 $entry=$archive.GetEntry('system.hwh')
 if($null -eq $entry){throw 'XSA missing system.hwh'}
 $reader=[IO.StreamReader]::new($entry.Open())
 try {$hardware=$reader.ReadToEnd()} finally {$reader.Dispose()}
 if(!$hardware.Contains('npu_video_ddr') -or !$hardware.Contains('npu_top100')){throw 'XSA does not match the optimized video/NPU hardware'}
 $init=$archive.GetEntry('ps7_init.tcl')
 if($null -eq $init){throw 'XSA missing PS init'}
 [IO.Compression.ZipFileExtensions]::ExtractToFile($init,(Join-Path $state 'ps7_init.tcl'),$true)
 $bits=@($archive.Entries | Where-Object {$_.FullName.EndsWith('.bit')})
 if($bits.Count -ne 1){throw 'XSA must contain exactly one bitstream'}
 [IO.Compression.ZipFileExtensions]::ExtractToFile($bits[0],(Join-Path $state 'included.bit'),$true)
} finally {$archive.Dispose()}
if((Get-FileHash (Join-Path $Artifacts 'ditto_npu.bit')).Hash -ne (Get-FileHash (Join-Path $state 'included.bit')).Hash){throw 'XSA bitstream mismatch'}
$symbols=& "$VitisRoot/gnu/aarch32/nt/gcc-arm-none-eabi/bin/arm-none-eabi-nm.exe" (Join-Path $Artifacts 'ditto_npu.elf')
if($LASTEXITCODE -ne 0){throw 'Cannot read ELF symbols'}
$lines=foreach($name in @('npu_test_phase','npu_test_result','npu_camera_result','npu_camera_evidence','camera_rate_evidence','digits_evidence','live_evidence')) {
 $matches=@($symbols | Select-String -Pattern "^([0-9a-fA-F]+) [BbDd] $name$")
 if($matches.Count -ne 1){throw "ELF symbol missing: $name"}
 'set addr_'+$name+' 0x'+$matches[0].Matches[0].Groups[1].Value
}
$lines | Set-Content (Join-Path $state 'evidence_addresses.tcl')
('set artifact_dir {'+$Artifacts.Replace('\','/')+'}') | Set-Content (Join-Path $state 'paths.tcl')
Write-Output 'DITTO: matching hardware and ELF symbols prepared for deployment'
