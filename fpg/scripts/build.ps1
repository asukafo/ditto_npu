param([string]$Vivado='C:/Xilinx/Vivado/2020.2/bin/vivado.bat')
$ErrorActionPreference='Stop'
$repo=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$project=Join-Path $repo 'build/fpga/ditto_npu.xpr'
if(!(Test-Path -LiteralPath $project)) {
 & $Vivado -mode batch -notrace -source (Join-Path $repo 'fpg/create_project.tcl')
 if($LASTEXITCODE -ne 0){throw 'Project creation failed'}
}
$runs=Join-Path $repo 'build/fpga/ditto_npu.runs'
Push-Location (Join-Path $runs 'synth_1')
try {& $Vivado -mode batch -notrace -source system_wrapper.tcl -log synthesis.log; if($LASTEXITCODE -ne 0){throw 'Synthesis failed'}} finally {Pop-Location}
& $Vivado -mode batch -notrace -source (Join-Path $PSScriptRoot 'prepare_impl.tcl')
if($LASTEXITCODE -ne 0){throw 'Implementation preparation failed'}
$runDir=Join-Path $runs 'impl_1'
$generated=[IO.File]::ReadAllText((Join-Path $runDir 'system_wrapper.tcl'))
$boundary=$generated.IndexOf('OPTRACE "write_bitstream setup" START')
if($boundary -lt 0){throw 'Unexpected Vivado implementation script'}
$guard=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'export_checked.tcl'))
$checked=Join-Path $runDir 'implementation_checked.tcl'
# Root comes from this script, never from the original developer workspace.
$prefix='set ditto_repo {'+$repo.Replace('\','/')+"}`n"
[IO.File]::WriteAllText($checked,$prefix+$generated.Substring(0,$boundary)+$guard)
Push-Location $runDir
try {& $Vivado -mode batch -notrace -source $checked -log implementation.log; if($LASTEXITCODE -ne 0){throw 'Implementation/timing failed'}} finally {Pop-Location}
