set repo [file normalize [file join [file dirname [info script]] ..]]
set tests {compute dma v2 preprocess preprocess_hd feature_writer video_ddr}
if {[llength $argv]} {set tests $argv}
foreach name $tests {
 if {$name ni {compute dma v2 preprocess preprocess_hd feature_writer video_ddr}} {error "Unknown test: $name"}
 create_project -force test_$name $repo/build/test_$name -part xc7z020clg400-2
 add_files [glob $repo/rtl/*.sv]
 add_files [glob $repo/rtl/*.v]
 add_files -fileset sim_1 $repo/tb/tb_$name.sv
 set_property top tb_$name [get_filesets sim_1]
 set_property xsim.simulate.runtime all [get_filesets sim_1]
 launch_simulation
 close_sim
 set fd [open $repo/build/test_$name/test_$name.sim/sim_1/behav/xsim/simulate.log r]
 set result [read $fd]; close $fd
 if {![regexp {PASS} $result] || [regexp {Fatal:|Error:} $result]} {error "Regression failed: $name"}
 puts "DITTO_TEST: PASS $name"
 close_project
}
exit
