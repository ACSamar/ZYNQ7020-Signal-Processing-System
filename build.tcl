set root [file normalize [file dirname [info script]]]
set project_file [file join $root ACM2108use.xpr]
set xsa_file [file join $root structure.xsa]

proc clean_build_outputs {root} {
    foreach name {.Xil ACM2108use.cache ACM2108use.gen ACM2108use.hw ACM2108use.ip_user_files ACM2108use.runs ACM2108use.sim} {
        set path [file join $root $name]
        if {[file exists $path]} {
            file delete -force $path
        }
    }
}

proc normalize_project_path {project_file} {
    set fp [open $project_file r]
    set data [read $fp]
    close $fp
    regsub {Path="[^"]*ACM2108use\.xpr"} $data {Path="ACM2108use.xpr"} data
    set fp [open $project_file w]
    puts -nonewline $fp $data
    close $fp
}

proc normalize_axi_clock {} {
    set fclk [get_bd_pins -quiet processing_system7_0/FCLK_CLK0]
    set board_clk [get_bd_pins -quiet acm2108_0/s_axi_aclk]
    if {[llength $fclk] == 0 || [llength $board_clk] == 0} {
        error "Required AXI clock pins are missing"
    }

    set hz [get_property CONFIG.FREQ_HZ $fclk]
    set_property CONFIG.FREQ_HZ $hz $board_clk
    foreach name {s_axi m_axis_adc s_axis_dac0 s_axis_dac1} {
        set pin [get_bd_intf_pins -quiet acm2108_0/$name]
        if {[llength $pin] != 0} {
            set_property CONFIG.FREQ_HZ $hz $pin
        }
    }

    set smc [get_bd_cells -quiet axi_ctrl_smc]
    if {[llength $smc] != 0} {
        set_property CONFIG.NUM_CLKS {1} $smc
    }
}

proc unlock_generated_ips {} {
    foreach ip [get_ips -quiet] {
        if {[string equal -nocase [get_property USER_LOCKED $ip] "true"]} {
            set_property USER_LOCKED false $ip
        }
    }
}

proc patch_run {run_dir run_base} {
    set file [file join $run_dir rundef.js]
    if {![file exists $file]} {
        return
    }

    set fp [open $file r]
    set data [read $fp]
    close $fp
    set bad "-log  -m64 -product Vivado -mode batch -messageDb vivado.pb -notrace -source "
    set good "-log ${run_base}.vds -m64 -product Vivado -mode batch -messageDb vivado.pb -notrace -source ${run_base}.tcl"
    if {[string first $bad $data] >= 0} {
        set fp [open $file w]
        puts -nonewline $fp [string map [list $bad $good] $data]
        close $fp
    }
}

proc patch_runs {runs_dir} {
    foreach dir [glob -nocomplain -types d -directory $runs_dir *_synth_1] {
        set name [file tail $dir]
        regsub {_synth_1$} $name {} base
        patch_run $dir $base
    }
}

proc fix_module_refs {file} {
    if {![file exists $file]} {
        return
    }

    set fp [open $file r]
    set data [read $fp]
    close $fp
    set refs [list \
        [list acm2108 acm2108_0 system_acm2108_0_0] \
        [list adc_dsp_axis adc_dsp system_adc_dsp_0] \
        [list contest_ctrl ctrl system_ctrl_0] \
        [list wave_axis dac0_wave system_dac0_wave_0] \
        [list wave_axis dac1_wave system_dac1_wave_0] \
        [list axis_mux2 dac0_mux system_dac0_mux_0] \
        [list axis_mux2 dac1_mux system_dac1_mux_0] \
        [list axis_mux2 dac0_src system_dac0_src_0] \
        [list shell shell system_shell_0] \
        [list slot slot system_slot_0] \
        [list axis_reg_slice axis_reg system_axis_reg_0] \
        [list axis_reg_slice cal_reg system_cal_reg_1] \
        [list dds_axis dds system_dds_0] \
        [list calibrate_axis cal system_cal_0]]

    set patched $data
    foreach ref $refs {
        lassign $ref raw inst wrapper
        set pattern [format {(^|[ \t\r\n])%s([ \t\r\n]+%s)} $raw $inst]
        regsub -all $pattern $patched [format {\1%s\2} $wrapper] patched
    }

    if {$patched ne $data} {
        set fp [open $file w]
        puts -nonewline $fp $patched
        close $fp
    }
}

clean_build_outputs $root
open_project $project_file
set_property source_mgmt_mode All [current_project]
set bd [get_files -quiet */system.bd]
open_bd_design $bd
unlock_generated_ips
normalize_axi_clock
validate_bd_design -force
save_bd_design
generate_target all $bd -force
make_wrapper -files $bd -top -import -force

set gen [file join $root ACM2108use.gen sources_1 bd system]
fix_module_refs [file join $gen synth system.v]
fix_module_refs [file join $gen sim system.v]
close_project

open_project $project_file
set_property source_mgmt_mode All [current_project]
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

reset_run synth_1
patch_runs [file join $root ACM2108use.runs]
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synth_1 did not complete"
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "impl_1 did not complete"
}

open_run impl_1
report_timing_summary -file [file join $root ACM2108use.runs impl_1 timing_summary.rpt]
write_hw_platform -fixed -include_bit -force $xsa_file
close_project
normalize_project_path $project_file
puts "BUILD_PASS: $xsa_file"
exit
