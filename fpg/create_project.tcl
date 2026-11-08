set repo [file normalize [file join [file dirname [info script]] ..]]
set project_dir $repo/build/fpga
if {[file exists $project_dir/ditto_npu.xpr]} {error "Project exists: use build scripts or choose a fresh checkout"}
create_project ditto_npu $project_dir -part xc7z020clg400-2
set_property ip_repo_paths $repo/fpg/ip_repo [current_project]
update_ip_catalog
add_files [glob $repo/rtl/*.sv]
add_files [glob $repo/rtl/*.v]
add_files -fileset constrs_1 $repo/fpg/constraints/conqueror.xdc
source $repo/fpg/system_bd.tcl
if {![llength [get_bd_cells -quiet npu_0]] || ![llength [get_bd_cells -quiet video_tap]]} {error "Incomplete block design"}
set_property USER_LOCKED false [get_ips system_ov5640_capture_data_0_0]
validate_bd_design
save_bd_design
set_property synth_checkpoint_mode None [get_files system.bd]
generate_target all [get_files system.bd]
add_files [make_wrapper -files [get_files system.bd] -top]
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1
launch_runs synth_1 -scripts_only
puts "DITTO: PROJECT_READY"
close_project
exit
