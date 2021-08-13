####################################################################################
# Pointwise Glyph Script
# This script can be run to export selected entities by their name set in the
# Pointwise file list, each as individual files. Desired entities must be
# pre-selected before running the script.
#
# Author: Luis Fernandes
# Date: 09-18-2020
#
# Change Log:
#   - Date: 
#     Author:
#     - 
#
####################################################################################

package require PWI_Glyph 4.18.4

set scriptMode "gui"

proc exportGridEntities {outputPath} {
  global doExportBlocks doExportDomains doExportConnectors selectedBlocks selectedDomains selectedConnectors nBlocksSelected nDomainsSelected nConnectorsSelected

  pw::Display getSelectedEntities selectedEntitiesArray

  set nEntitiesExported 0

  if {$doExportBlocks} {
    for {set i 0} {$i<$nBlocksSelected} {incr i 1} {
      set exportBlock [lindex $selectedBlocks $i]
      set blockName [$exportBlock getName]
      TextInsert "Exporting block $blockName to ${outputPath}/${blockName}.x"
      pw::Grid export -type PLOT3D -format Unformatted -precision Double $exportBlock ${outputPath}/${blockName}.x 
      incr nEntitiesExported 1
    }
  }

  if {$doExportDomains} {
    for {set i 0} {$i<$nDomainsSelected} {incr i 1} {
      set exportDomain [lindex $selectedDomains $i]
      set domainName [$exportDomain getName]
      TextInsert "Exporting domain $domainName to ${outputPath}/${domainName}.x"
      pw::Grid export -type PLOT3D -format Unformatted -precision Double $exportDomain ${outputPath}/${domainName}.x 
      incr nEntitiesExported 1
    }
  }

  if {$doExportConnectors} {
    for {set i 0} {$i<$nConnectorsSelected} {incr i 1} {
      set exportConnector [lindex $selectedConnectors $i]
      set connectorName [$exportConnector getName]
      TextInsert "Exporting connector $connectorName to ${outputPath}/${connectorName}.x"
      pw::Grid export -type PLOT3D -format Unformatted -precision Double $exportConnector ${outputPath}/${connectorName}.x 
      incr nEntitiesExported 1
    }
  }
  
  TextInsert "Exported a total of $nEntitiesExported entities."
  
}

proc checkBlocksSelected {} {
  global nBlocksSelected selectedBlocks

  pw::Display getSelectedEntities selectedEntitiesArray  
  set selectedBlocks $selectedEntitiesArray(Blocks)
  set nBlocksSelected [llength $selectedBlocks]
  if {$nBlocksSelected==0} {
    return "disabled"
  } else {
    return "normal"
  }
}

proc checkDomainsSelected {} {
  global nDomainsSelected selectedDomains

  pw::Display getSelectedEntities selectedEntitiesArray  
  set selectedDomains $selectedEntitiesArray(Domains)
  set nDomainsSelected [llength $selectedDomains]
  if {$nDomainsSelected==0} {
    return "disabled"
  } else {
    return "normal"
  }
}

proc checkConnectorsSelected {} {
  global nConnectorsSelected selectedConnectors

  pw::Display getSelectedEntities selectedEntitiesArray  
  set selectedConnectors $selectedEntitiesArray(Connectors)
  set nConnectorsSelected [llength $selectedConnectors]
  if {$nConnectorsSelected==0} {
    return "disabled"
  } else {
    return "normal"
  }
}

proc TextInsert {line} {
  global msgBox scriptMode
  if {$scriptMode == "gui" } {
    $msgBox configure -state normal
    $msgBox insert end "$line\n"
    $msgBox see end
    $msgBox configure -state disabled
  } else {
    puts $line
  }
  update
}

# Interfaces with Tk to open up a window to allow selection of an output directory
proc GetPath {} {
  global outputPath
 
  set dir [tk_chooseDirectory -initialdir ~ -title "Choose a directory"]

  if {$dir == ""} {
    #-- cancel
    TextInsert "No directory selected."
    return
  } else {
    TextInsert "Selected $dir"
    set outputPath $dir
  }

  return
}

proc setState {parent state} {

  catch {$parent configure -state $state}

  set wlist [winfo children $parent]
  foreach win $wlist {
    setState $win $state
  }
}

proc exportBlocksToggle {} {
  global doExportBlocks nBlocksSelected
  
  if {$doExportBlocks} {
    TextInsert "$nBlocksSelected blocks currently selected."
  }
}

proc exportDomainsToggle {} {
  global doExportDomains nDomainsSelected
  
  if {$doExportDomains} {
    TextInsert "$nDomainsSelected domains currently selected."
  }
}

proc exportConnectorsToggle {} {
  global doExportConnectors nConnectorsSelected
  
  if {$doExportConnectors} {
    TextInsert "$nConnectorsSelected connectors currently selected."
  }
}

# Interfaces with Tk to control window options
proc CenterWindow {w {parent ""} {xoff "0"} {yoff "0"}} {
  global tcl_platform

  if [winfo exists $parent] {
    set rootx [winfo rootx $parent]
    set rooty [winfo rooty $parent]
    set pwidth [winfo width $parent]
    set pheight [winfo height $parent]
  } else {
    set parent "."
    set rootx 0
    set rooty 0
    set pwidth [winfo screenwidth $parent]
    set pheight [winfo screenheight $parent]

    set winInfo [list $pwidth $pheight 0 0 0]
    set pwidth [lindex $winInfo 0]
    set pheight [lindex $winInfo 1]
  }

  set screenwidth [winfo screenwidth .]
  set screenheight [winfo screenheight .]

  set winInfo [list $screenwidth $screenheight 0 0 0]
  set screenwidth [lindex $winInfo 0]
  set screenheight [lindex $winInfo 1]
  set l_off [lindex $winInfo 2]
  set t_off [lindex $winInfo 3]

  update idletasks
  set wwidth [winfo reqwidth $w]
  set wheight [winfo reqheight $w]
  set x0 [expr $rootx+($pwidth-$wwidth)/2+$xoff]
  set y0 [expr $rooty+($pheight-$wheight)/2+$yoff]

  set border 4
  set maxW [expr $x0 + $wwidth + 2*$border]
  if { $maxW > $screenwidth} {
    set x0 [expr $screenwidth-$wwidth - 2*$border]
  } elseif { $x0 < 0 } {
    set x0 0
  }

  set border 4
  set maxH [expr $y0 + $wheight + 2*$border]
  if { $maxH > $screenheight} {
    set y0 [expr $screenheight-$wheight - 2*$border]
  } elseif { $y0 < 0 } {
    set y0 0
  }

  #-- allow for windows taskbar
  if { $tcl_platform(platform) == "windows" } {
    set x0 [expr $x0+$l_off]
    set y0 [expr $y0+$t_off]
  }

  wm geometry $w "+$x0+$y0"

  if {0} {
   foreach var {rootx rooty pwidth pheight wwidth wheight x0 y0} {
    set val [set $var]
    puts "$var: $val"
   }
  }
}

proc export {outDir} {
  global msgBox scriptMode title tl
  global closeBtn exportBtn

  if {$scriptMode == "gui"} {
    #-- Disable text box
    $msgBox configure -state normal
    $msgBox configure -state disabled
    $closeBtn configure -text "Cancel"
    $exportBtn configure -state disabled
  }

  if {$outDir!=""} {
    exportGridEntities $outDir
  } else {
    TextInsert "No directory selected."
  }

  if {$scriptMode == "gui"} {
    #-- Re-enable text box
    $msgBox configure -state normal
    $closeBtn configure -text "Close"
    $exportBtn configure -state normal
  }
}

if {$scriptMode == "gui" } {
  #################################################################
  ##  GUI MODE
  #################################################################

  pw::Script loadTk

  set tl .
  wm withdraw $tl

  set tf [frame $tl.title]
  pack $tf -side top -fill x -expand 0 -padx 2 -pady 2

  label $tf.l -text "Output Directory" -anchor c -font {Arial 12 bold}
  pack $tf.l -side top
  set title $tf.l

  set tf [frame $tl.top]
  pack $tf -side top -fill x -expand 0 -padx 2 -pady 2

  set bf [frame $tl.bot]
  pack $bf -side bottom -fill both -expand 1 -padx 2 -pady 2

  set f [frame $tf.1]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "Directory Path:"
  pack $f.file -side left

  entry $f.e -textvariable outputPath -width 20
  pack $f.e -side left -fill x -expand 1

  frame $f.spc -width 3
  pack $f.spc -side left

  button $f.browse -text "Browse" -command GetPath -width 6
  pack $f.browse -side left

  set f [frame $tf.2]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set splitFrame $f
  
  set exportBlocksState [checkBlocksSelected]
  set exportDomainsState [checkDomainsSelected]
  set exportConnectorsState [checkConnectorsSelected]

  checkbutton $f.expBlocks -text "Export Blocks" \
      -variable doExportBlocks -command exportBlocksToggle \
      -state $exportBlocksState
  pack $f.expBlocks -side left

  checkbutton $f.expDomains -text "Export Domains" \
      -variable doExportDomains -command exportDomainsToggle \
      -state $exportDomainsState
  pack $f.expDomains -side left

  checkbutton $f.expConnectors -text "Export Curves" \
      -variable doExportConnectors -command exportConnectorsToggle \
      -state $exportConnectorsState
  pack $f.expConnectors -side left

  set f [frame $tf.3 -bd 2 -relief groove]
  pack $f -side top -fill x -expand 0 -padx 0 -pady 4

  button $f.export -text "Export grid entities" \
     -command {export $outputPath} -width 12
  pack $f.export -side left -padx 2 -pady 2

  button $f.cancel -text "Close" \
     -command {exit} -width 12
  pack $f.cancel -side right -padx 2 -pady 2

  set exportBtn $f.export
  set closeBtn $f.cancel

  set f $bf

  set sbar [scrollbar $f.sbar -command "$f.t yview"]
  pack $sbar -side right -fill y -expand 0

  set msgBox [text $f.t -width 65 -height 20 \
     -font {courier 10} -yscrollcommand "$sbar set" -state disabled]
  set t $f.t
  pack $msgBox -side left -fill both -expand 1

  #-- set some bindings so we can select text with the mouse
  bind $msgBox <KeyPress> {
    $msgBox configure -state disabled
  }
  bind $msgBox <ButtonPress-1> {
    $msgBox configure -state normal
  }
  bind $msgBox <ButtonRelease-1> {
    $msgBox configure -state disabled
  }

  TextInsert "This script will export structured blocks, domains"
  TextInsert "or curves that you have selected into a user-specified"
  TextInsert "directory. Each entity is saved separately into its own"
  TextInsert "PLOT3D grid file, with the name specified in Pointwise."

  CenterWindow $tl
  wm deiconify $tl
}
