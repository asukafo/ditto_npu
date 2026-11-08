set repo [file normalize [file join [file dirname [info script]] ../..]]
open_project $repo/build/fpga/ditto_npu.xpr
launch_runs impl_1 -to_step write_bitstream -scripts_only
close_project
exit
