set root [file normalize [file join [file dirname [info script]] ../..]]
source $root/build/deploy/paths.tcl
proc read_word {address} {
 return [expr {wide([lindex [mrd -value $address] 0])}]
}
if {[catch {
 set elf $artifact_dir/ditto_npu.elf
 source $root/build/deploy/evidence_addresses.tcl
 foreach path [list $elf $artifact_dir/ditto_npu.bit $artifact_dir/ditto_npu.xsa $root/build/deploy/ps7_init.tcl] {
  if {![file isfile $path]} {error "Missing artifact: $path"}
 }
 connect -url tcp:127.0.0.1:3121
 targets -set -nocase -filter {name =~ "APU*"}
 rst -system
 after 3000
 targets -set -nocase -filter {name =~ "xc7z020*"}
 fpga -file $artifact_dir/ditto_npu.bit
 targets -set -nocase -filter {name =~ "APU*"}
 loadhw -hw $artifact_dir/ditto_npu.xsa -mem-ranges [list {0x40000000 0xbfffffff}] -regs
 configparams force-mem-access 1
 source $root/build/deploy/ps7_init.tcl
 ps7_init
 ps7_post_config
 targets -set -nocase -filter {name =~ "*A9*#0"}
 dow $elf
 con
 set phase 0
 for {set poll 0} {$poll<20} {incr poll} {
  after 1000
  set phase [read_word $addr_npu_test_phase]
  if {$phase==3} {break}
 }
 set selftest [read_word $addr_npu_test_result]
 set camera [read_word $addr_npu_camera_result]
 puts "NPU_BOARD: PHASE=$phase SELFTEST=$selftest CAMERA=$camera"
 puts "NPU_BOARD: CAMERA_EVIDENCE=[mrd -value $addr_npu_camera_evidence 9]"
 foreach offset {0 4 8 12 20 24 28 32 36 40 44 48} {
  puts [format "NPU_BOARD: REG_%02x=%08x" $offset [read_word [expr {0x43c20000+$offset}]]]
 }
 set mm2s [read_word 0x43000004]; set s2mm [read_word 0x43000034]
 puts [format "NPU_BOARD: VDMA_MM2S=%08x VDMA_S2MM=%08x" $mm2s $s2mm]
 if {$phase!=3 || $selftest!=0 || $camera!=0} {error "ARM selftest/camera validation failed"}
 if {($mm2s & 0x4ff1)!=0 || ($s2mm & 0x4ff1)!=0} {error "VDMA halted or reports errors"}
 if {[read_word $addr_npu_camera_evidence]!=2 || [read_word [expr {$addr_npu_camera_evidence+8}]]!=3 || [read_word [expr {$addr_npu_camera_evidence+12}]]!=0} {error "Camera evidence incomplete"}
 set rate [mrd -value $addr_camera_rate_evidence 7]
 puts "NPU_RATE: EVIDENCE=$rate"
 if {[lindex $rate 0]!=2 || [lindex $rate 1]!=128 || [lindex $rate 5]!=0 || [lindex $rate 6]!=0} {error "Frame-rate measurement invalid"}
 puts [format "NPU_RATE: FPS=%.6f" [expr {128.0*1000000/[lindex $rate 2]}]]
 set digits [mrd -value $addr_digits_evidence 7]
 puts "NPU_DIGITS: EVIDENCE=$digits"
 if {[lindex $digits 0]!=2 || [lindex $digits 1]!=360 || [lindex $digits 3]!=0 || [lindex $digits 4]!=0 || [lindex $digits 2]<335} {error "Complete trained model hardware verification failed"}
 set live {}
 for {set poll 0} {$poll<90} {incr poll} {
  after 1000
  set live [mrd -value $addr_live_evidence 57]
  set state [lindex $live 0]
  if {$state==2 || $state==3} {break}
 }
 puts "NPU_LIVE: EVIDENCE=$live"
 if {[lindex $live 0]!=2 || [lindex $live 1]!=360 || [lindex $live 2]<335 || [lindex $live 5]<256} {error "Live state/dataset gate failed"}
 foreach field {3 4 6 7 8 9 18 19 20} {if {[lindex $live $field]!=0} {error "Live error counter $field is nonzero"}}
 if {[lindex $live 11]>34980 || [lindex $live 17]!=921600} {error "Full-frame deadline/size gate failed"}
 puts [format "NPU_LIVE: PASS frames=%d max_inference_us=%d max_end_to_end_us=%d predicted_digit=%d" [lindex $live 5] [lindex $live 10] [lindex $live 11] [lindex $live 13]]
 disconnect
 puts "NPU_BOARD: SELFTEST_AND_CAMERA_REFERENCE_PASS; HDMI_VISUAL_CONFIRMATION_STILL_REQUIRED"
} message]} {puts stderr "NPU_BOARD: FAILED: $message"; exit 1}
exit





