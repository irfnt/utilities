# File: calc_harmful_skew.tcl
# Purpose: Comprehensive clock analysis with skew, latency, and physical metrics
# Assumes design is loaded, constraints applied, and CTS completed

proc calculate_harmful_skew {} {
    # Validate design setup
    if {[sizeof_collection [get_clocks *]] == 0} {
        puts "Error: No clocks defined. Check SDC file."
        return 1
    }

    # Open report file
    set report_file "harmful_skew_report.txt"
    set fh [open $report_file w]
    puts $fh "Clock Network Analysis Report - [clock format [clock seconds]]"
    puts $fh "--------------------------------------------------------------------------------------------"
    puts $fh [format "%-55s | %6s | %6s | %-6s | %6s | %6s | %6s | %6s | %6s" \
              "Path" "Skew" "Slack" "Type" "Harmful" "L.Lat" "C.Lat" "Trans" "Cap"]

    # Console header
    puts "Clock Network Analysis Report"
    puts "--------------------------------------------------------------------------------------------"
    puts [format "%-55s | %6s | %6s | %-6s | %6s | %6s | %6s | %6s | %6s" \
              "Path" "Skew" "Slack" "Type" "Harmful" "L.Lat" "C.Lat" "Trans" "Cap"]

    # Initialize metrics
    set setup_slacks [list]
    set hold_slacks [list]
    set harmful_skew_values [list]
    set launch_lats [list]
    set capture_lats [list]
    set total_harmful_skew 0.0
    set max_harmful_skew -inf
    set min_harmful_skew +inf
    set max_transition 0.0
    set min_transition inf
    set max_capacitance 0.0
    set harmful_skew_count 0
    set harmful_paths_details [list]

    # Get timing paths with violations
    set setup_paths [get_timing_paths -slack_lesser_than 0 -max_paths 1000 -delay_type max]
    set hold_paths [get_timing_paths -slack_lesser_than 0 -max_paths 1000 -delay_type min]

    # Process setup paths
    if {[sizeof_collection $setup_paths] > 0} {
        foreach_in_collection path $setup_paths {
            incr harmful_skew_count [process_path $path $fh "Setup" setup_slacks harmful_skew_values \
                                       total_harmful_skew max_harmful_skew min_harmful_skew \
                                       harmful_paths_details launch_lats capture_lats \
                                       max_transition min_transition max_capacitance]
        }
    }

    # Process hold paths
    if {[sizeof_collection $hold_paths] > 0} {
        foreach_in_collection path $hold_paths {
            incr harmful_skew_count [process_path $path $fh "Hold" hold_slacks harmful_skew_values \
                                       total_harmful_skew max_harmful_skew min_harmful_skew \
                                       harmful_paths_details launch_lats capture_lats \
                                       max_transition min_transition max_capacitance]
        }
    }

    # Calculate statistics
    set num_setup [llength $setup_slacks]
    set num_hold [llength $hold_slacks]
    set total_slacks [expr {$num_setup + $num_hold}]

    # Setup violations stats
    set setup_tns 0.0
    set setup_avg 0.0
    if {$num_setup > 0} {
        set setup_tns [expr [join $setup_slacks +]]
        set setup_avg [expr {$setup_tns / $num_setup}]
    }

    # Hold violations stats
    set hold_tns 0.0
    set hold_avg 0.0
    if {$num_hold > 0} {
        set hold_tns [expr [join $hold_slacks +]]
        set hold_avg [expr {$hold_tns / $num_hold}]
    }

    # Harmful skew stats
    set num_harmful [llength $harmful_skew_values]
    set avg_harmful 0.0
    set median_harmful 0.0
    if {$num_harmful > 0} {
        set avg_harmful [expr {$total_harmful_skew / $num_harmful}]
        set sorted_harmful [lsort -real $harmful_skew_values]
        set median_harmful [median $sorted_harmful]
        set max_harmful_skew [lindex $sorted_harmful end]
        set min_harmful_skew [lindex $sorted_harmful 0]
    }

    # Clock latency stats
    set avg_launch_lat [expr {[llength $launch_lats] ? [tcl::mathop::+ {*}$launch_lats]/[llength $launch_lats] : 0}]
    set avg_capture_lat [expr {[llength $capture_lats] ? [tcl::mathop::+ {*}$capture_lats]/[llength $capture_lats] : 0}]

    # Report sections
    puts "\n--------------------------------------------------------------------------------------------"
    puts $fh "\n--------------------------------------------------------------------------------------------"

    # Timing Violation Statistics
    puts "Timing Violation Statistics:"
    puts [format "%-25s %10s %10s %10s" "Metric" "Setup" "Hold" "Total"]
    puts [format "%-25s %10.3f %10.3f %10.3f" "TNS (ns):" $setup_tns $hold_tns [expr {$setup_tns + $hold_tns}]]
    puts [format "%-25s %10.3f %10.3f %10.3f" "Average Slack (ns):" $setup_avg $hold_avg \
          [expr {($setup_tns + $hold_tns)/$total_slacks}]]

    # Harmful Skew Statistics
    puts "\nHarmful Skew Statistics:"
    puts [format "%-25s %10.3f" "Total Harmful Skew (ns):" $total_harmful_skew]
    puts [format "%-25s %10.3f" "Maximum Harmful Skew:" $max_harmful_skew]
    puts [format "%-25s %10.3f" "Minimum Harmful Skew:" $min_harmful_skew]
    puts [format "%-25s %10.3f" "Average Harmful Skew:" $avg_harmful]
    puts [format "%-25s %10.3f" "Median Harmful Skew:" $median_harmful]
    puts [format "%-25s %10d" "Paths with Harmful Skew:" $harmful_skew_count]

    # Clock Network Statistics
    puts "\nClock Network Characteristics:"
    puts [format "%-25s %10.3f %10.3f" "Latency (ns) Avg:" $avg_launch_lat $avg_capture_lat]
    puts [format "%-25s %10.3f %10.3f" "Latency (ns) Max:" [tcl::mathfunc::max {*}$launch_lats] [tcl::mathfunc::max {*}$capture_lats]]
    puts [format "%-25s %10.3f %10.3f" "Latency (ns) Min:" [tcl::mathfunc::min {*}$launch_lats] [tcl::mathfunc::min {*}$capture_lats]]
    puts [format "%-25s %10.3f" "Max Transition (ns):" $max_transition]
    puts [format "%-25s %10.3f" "Min Transition (ns):" [expr {$min_transition == inf ? 0.0 : $min_transition}]]
    puts [format "%-25s %10.3f" "Max Capacitance (pF):" $max_capacitance]

    # Write statistics to file
    puts $fh "\nTiming Violation Statistics:"
    puts $fh [format "%-25s %10s %10s %10s" "Metric" "Setup" "Hold" "Total"]
    puts $fh [format "%-25s %10.3f %10.3f %10.3f" "TNS (ns):" $setup_tns $hold_tns [expr {$setup_tns + $hold_tns}]]
    puts $fh [format "%-25s %10.3f %10.3f %10.3f" "Average Slack (ns):" $setup_avg $hold_avg \
          [expr {($setup_tns + $hold_tns)/$total_slacks}]]

    puts $fh "\nHarmful Skew Statistics:"
    puts $fh [format "%-25s %10.3f" "Total Harmful Skew (ns):" $total_harmful_skew]
    puts $fh [format "%-25s %10.3f" "Maximum Harmful Skew:" $max_harmful_skew]
    puts $fh [format "%-25s %10.3f" "Minimum Harmful Skew:" $min_harmful_skew]
    puts $fh [format "%-25s %10.3f" "Average Harmful Skew:" $avg_harmful]
    puts $fh [format "%-25s %10.3f" "Median Harmful Skew:" $median_harmful]
    puts $fh [format "%-25s %10d" "Paths with Harmful Skew:" $harmful_skew_count]

    puts $fh "\nClock Network Characteristics:"
    puts $fh [format "%-25s %10.3f %10.3f" "Latency (ns) Avg:" $avg_launch_lat $avg_capture_lat]
    puts $fh [format "%-25s %10.3f %10.3f" "Latency (ns) Max:" [tcl::mathfunc::max {*}$launch_lats] [tcl::mathfunc::max {*}$capture_lats]]
    puts $fh [format "%-25s %10.3f %10.3f" "Latency (ns) Min:" [tcl::mathfunc::min {*}$launch_lats] [tcl::mathfunc::min {*}$capture_lats]]
    puts $fh [format "%-25s %10.3f" "Max Transition (ns):" $max_transition]
    puts $fh [format "%-25s %10.3f" "Min Transition (ns):" [expr {$min_transition == inf ? 0.0 : $min_transition}]]
    puts $fh [format "%-25s %10.3f" "Max Capacitance (pF):" $max_capacitance]

    # Detailed Harmful Paths
    if {[llength $harmful_paths_details] > 0} {
        puts "\n--------------------------------------------------------------------------------------------"
        puts "Detailed Paths with Harmful Skew:"
        puts "--------------------------------------------------------------------------------------------"
        puts [format "%-55s | %6s | %6s | %-6s | %6s | %6s | %6s | %6s | %6s" \
              "Path" "Skew" "Slack" "Type" "Harmful" "L.Lat" "C.Lat" "Trans" "Cap"]
        
        foreach path_entry $harmful_paths_details {
            puts $path_entry
            puts $fh $path_entry
        }
    } else {
        puts "\nNo paths with harmful skew found"
        puts $fh "No paths with harmful skew found"
    }

    close $fh
    puts "\nReport saved to $report_file"
    return 0
}

proc process_path {path fh violation_type slack_list_var harmful_skew_values_var \
                  total_harmful_skew_var max_harmful_var min_harmful_var \
                  harmful_paths_var launch_lats_var capture_lats_var \
                  max_trans_var min_trans_var max_cap_var} {
    upvar $slack_list_var slack_list
    upvar $harmful_skew_values_var harmful_skew_values
    upvar $total_harmful_skew_var total_harmful_skew
    upvar $max_harmful_var max_harmful
    upvar $min_harmful_var min_harmful
    upvar $harmful_paths_var harmful_paths
    upvar $launch_lats_var launch_lats
    upvar $capture_lats_var capture_lats
    upvar $max_trans_var max_trans
    upvar $min_trans_var min_trans
    upvar $max_cap_var max_cap

    # Initialize defaults
    set skew 0.0
    set harmful_skew 0.0
    set path_name "Unknown Path"
    set slack 0.0
    set path_trans 0.0
    set path_cap 0.0
    set launch_delay 0.0
    set capture_delay 0.0

    # Get basic path info
    set startpoint [get_attribute $path startpoint]
    set endpoint [get_attribute $path endpoint]
    
    # Get slack
    if {[catch {set slack [get_attribute $path slack]} || ![string is double $slack]} {
        puts $fh "Warning: Invalid slack for path"
        return 0
    }
    lappend slack_list $slack

    # Get clock info
    set launch_clock [get_attribute $path startpoint_clock]
    set capture_clock [get_attribute $path endpoint_clock]
    if {$launch_clock == "" || $capture_clock == ""} {
        puts $fh "Warning: Missing clock information"
        return 0
    }

    # Check clock domains
    set launch_clk_name [get_attribute $launch_clock name]
    set capture_clk_name [get_attribute $capture_clock name]
    if {$launch_clk_name ne $capture_clk_name} {
        set path_name "[get_attribute $startpoint full_name] -> [get_attribute $endpoint full_name]"
        puts $fh "Warning: Cross-clock path $launch_clk_name -> $capture_clk_name"
        return 0
    }

    # Get clock latencies
    if {[catch {
        set launch_delay [get_attribute $path startpoint_clock_latency]
        set capture_delay [get_attribute $path endpoint_clock_latency]
    }]} {
        puts $fh "Warning: Missing clock latencies"
        return 0
    }
    lappend launch_lats $launch_delay
    lappend capture_lats $capture_delay

    # Calculate skew
    set skew [expr {double($capture_delay) - double($launch_delay)}]
    
    # Determine harmful skew
    if {$violation_type == "Setup" && $skew < 0} {
        set harmful_skew [expr {abs($skew)}]
    } elseif {$violation_type == "Hold" && $skew > 0} {
        set harmful_skew $skew
    }

    # Get physical characteristics
    if {[catch {
        set startpoint_pin [get_pins -quiet [get_attribute $startpoint name]]
        set rise_trans [get_attribute $startpoint_pin actual_rise_transition_max]
        set fall_trans [get_attribute $startpoint_pin actual_fall_transition_max]
        set path_trans [expr {max($rise_trans, $fall_trans)}]
        set path_cap [get_attribute $startpoint_pin capacitance_max]
    }]} {
        set path_trans 0.0
        set path_cap 0.0
    }

    # Update max and min values
    if {$path_trans > $max_trans} {set max_trans $path_trans}
    if {$path_trans < $min_trans && $path_trans > 0.0} {set min_trans $path_trans}
    if {$path_cap > $max_cap} {set max_cap $path_cap}

    # Update metrics
    if {$harmful_skew > 0} {
        lappend harmful_skew_values $harmful_skew
        set total_harmful_skew [expr {$total_harmful_skew + $harmful_skew}]
        if {$harmful_skew > $max_harmful} {set max_harmful $harmful_skew}
        if {$harmful_skew < $min_harmful} {set min_harmful $harmful_skew}
        
        # Format path entry
        set path_name "[get_attribute $startpoint full_name] -> [get_attribute $endpoint full_name]"
        set formatted_line [format "%-55s | %6.3f | %6.3f | %-6s | %6.3f | %6.3f | %6.3f | %6.3f | %6.3f" \
                            $path_name $skew $slack $violation_type $harmful_skew \
                            $launch_delay $capture_delay $path_trans $path_cap]
        lappend harmful_paths $formatted_line
    }

    # Immediate output
    set console_line [format "%-55s | %6.3f | %6.3f | %-6s | %6.3f | %6.3f | %6.3f | %6.3f | %6.3f" \
                     $path_name $skew $slack $violation_type $harmful_skew \
                     $launch_delay $capture_delay $path_trans $path_cap]
    puts $console_line
    puts $fh $console_line

    return [expr {$harmful_skew > 0 ? 1 : 0}]
}

proc median {sorted_list} {
    set len [llength $sorted_list]
    if {$len == 0} {return 0.0}
    set mid [expr {$len / 2}]
    if {$len % 2 == 0} {
        return [expr {([lindex $sorted_list $mid-1] + [lindex $sorted_list $mid])/2.0}]
    } else {
        return [lindex $sorted_list $mid]
    }
}

# Execute the analysis
calculate_harmful_skew
