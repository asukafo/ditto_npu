set repo [file normalize [file join [file dirname [info script]] ..]]
set xsa $repo/build/artifacts/ditto_npu.xsa
if {![file exists $xsa]} {set xsa $repo/fpg/artifacts/ditto_npu.xsa}
if {[catch {
 hsi::open_hw_design $xsa
 hsi::create_sw_design ditto_bsp -proc ps7_cortexa9_0 -os standalone
 hsi::generate_bsp -dir $repo/build/bsp
} message]} {puts stderr $message; exit 1}
puts "DITTO: BSP_GENERATED"
exit 0
