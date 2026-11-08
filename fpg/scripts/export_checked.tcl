file mkdir $ditto_repo/build/artifacts
file mkdir $ditto_repo/build/evidence
if {[llength [get_clocks]]<7} {error "Missing integrated clocks"}
set timing [report_timing_summary -report_unconstrained -return_string -file $ditto_repo/build/evidence/timing.rpt]
if {![regexp {checking no_clock \(([0-9]+)\)} $timing matched count] || $count!=0} {error "Unclocked registers or missing clock coverage report"}
set skew [report_bus_skew -return_string -file $ditto_repo/build/evidence/bus_skew.rpt]
if {[string match {*VIOLATED*} $skew]} {error "Bus skew failed"}
report_utilization -file $ditto_repo/build/evidence/utilization.rpt
report_drc -file $ditto_repo/build/evidence/drc.rpt
foreach delay {max min} {
 set paths [get_timing_paths -delay_type $delay -max_paths 1]
 if {![llength $paths] || [get_property SLACK $paths]<0} {error "Timing failed: $delay"}
}
write_bitstream -force $ditto_repo/build/artifacts/ditto_npu.bit
write_hw_platform -fixed -include_bit -force -file $ditto_repo/build/artifacts/ditto_npu.xsa
puts "DITTO: CHECKED_EXPORT_PASS"
exit
