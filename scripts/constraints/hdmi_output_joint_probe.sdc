# UNSELECTED read-only joint diagnostic. These two proposals target different
# launch clocks; neither qualifies board timing or physical mode switching.
# If either source guard fails, abort the probe. Never accept partial reports.
source [file join [file dirname [info script]] hdmi_held_mode_candidate.sdc]
source [file join [file dirname [info script]] hdmi_inactive_data_candidate.sdc]
