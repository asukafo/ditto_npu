param([string]$VitisRoot='C:/Xilinx/Vitis/2020.2')
$ErrorActionPreference='Continue'
$repo=Split-Path $PSScriptRoot -Parent
$bsp=Join-Path $repo 'build/bsp/ps7_cortexa9_0'
$out=Join-Path $repo 'build/artifacts'
New-Item -ItemType Directory -Force $out | Out-Null
$env:PATH="$VitisRoot/gnu/aarch32/nt/gcc-arm-none-eabi/bin;$VitisRoot/gnuwin/bin;"+$env:PATH
$env:RDI_PLATFORM='win64'
& "$VitisRoot/bin/xsct.bat" (Join-Path $PSScriptRoot 'generate_bsp.tcl')
if($LASTEXITCODE -ne 0){throw 'BSP generation failed'}
& "$VitisRoot/gnuwin/bin/make.exe" -C (Join-Path $repo 'build/bsp')
if($LASTEXITCODE -ne 0){throw 'BSP build failed'}
Copy-Item "$VitisRoot/data/embeddedsw/ThirdParty/sw_services/libmetal_v2_1/src/libmetal/test/system/generic/zynq7/Xilinx.spec" (Join-Path $out 'Xilinx.spec') -Force
$gcc="$VitisRoot/gnu/aarch32/nt/gcc-arm-none-eabi/bin/arm-none-eabi-gcc.exe"
$objects=@()
foreach($source in Get-ChildItem $PSScriptRoot -Recurse -Filter '*.c') {
 $relative=$source.FullName.Substring($PSScriptRoot.Length+1)
 $object=Join-Path $out (($relative -replace '[/\\]','_')+'.o')
 & $gcc -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -O2 -g -Wall -Wextra "-I$PSScriptRoot" "-I$PSScriptRoot/app" "-I$repo/sw_train" "-I$bsp/include" -c $source.FullName -o $object
 if($LASTEXITCODE -ne 0){throw "Compile failed: $relative"}
 $objects+=$object
}
$elf=Join-Path $out 'ditto_npu.elf'
& $gcc -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard '-Wl,-build-id=none' "-specs=$out/Xilinx.spec" "-Wl,-T,$PSScriptRoot/app/lscript.ld" "-Wl,-Map,$out/ditto_npu.map" "-L$bsp/lib" -o $elf @objects '-Wl,--start-group,-lxil,-lgcc,-lc,--end-group'
if($LASTEXITCODE -ne 0){throw 'ELF link failed'}
Write-Output "DITTO: SOFTWARE_BUILD_PASS $elf"
