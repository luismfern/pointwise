####################################################################################
# Pointwise Glyph Script
# This script will take a connector and apply a growth distribution, allowing the
# user to specify a number of layers on either side that should follow a given
# stretching ratio (constant), as well as the stretching ratio to apply in the 
# middle section on both sides
#
# Author: Luis Fernandes
# Date: 09-18-2020
#
# Change Log:
#   - Date: 04-29-2021
#     Author: Luis Fernandes
#
#   - Date:
#     Author: 
#
####################################################################################

package require PWI_Glyph 3.18.3

set scriptMode "gui"

proc checkPreSelection {} {

  global conSelected
  global preSelectedEntities
  global boxText
  global connectorList
 
  set entitiesSelected [pw::Display getSelectedEntities -selectionmask [pw::Display createSelectionMask \
                                                        -requireConnector {Dimensioned}] \
                                                        preSelection]

  if { $entitiesSelected == 0 } { 
    set preSelectedEntities 0
    puts "No acceptable pre-selected entity detected."
    return
  }

  set connectorList $preSelection(Connectors)
  set ncons [llength $connectorList]
  set conSelected 1

  if { $ncons == 1 } {
    set connector [lindex $connectorList 0]
    set boxText [$connector getName]
    puts "Connector selected."
  } else {
    set boxText "Several connectors selected"
    puts "More than 1 entity was pre-selected; applying script to all connectors"
  }

  pw::Display setSelectedEntities $connectorList

  checkSelectionState
  return
}

# Enters display mode in Pointwise and allows selection of a single entity
proc enterConnectorSelectionMode {} {

  global tl
  global boxText
  global connectorList
  global conSelected
  
  # Remove priority from menu window from top
  wm attributes $tl -topmost 0

  set selectionMask [pw::Display createSelectionMask -requireConnector {Dimensioned}]
 
  pw::Display selectEntities  -description "Select a dimensioned connector" \
                              -selectionmask $selectionMask \
                              selectedEntity

  
  set connectorList $selectedEntity(Connectors)
  set ncons [llength $connectorList]
  
  if { $ncons == 1 } {
    set conSelected 1
    set connector [lindex $connectorList 0]
    set boxText [$connector getName]
    puts "Connector selected."
  } elseif { $ncons > 1 } {
    set conSelected 1
    set boxText "Several connectors selected"
    puts "More than 1 entity was pre-selected; applying script to all connectors"
  }
 
  # Bring menu window back to top
  wm attributes $tl -topmost 1

  # Check for selection state
  checkSelectionState  

  pw::Display setSelectedEntities $connectorList

  return
}

proc updateDistribution {} {
  
  global tl
  global endSide
  global startLayers
  global startSideStretchingRatio
  global startSideMidStretchingRatio
  global endLayers
  global endSideStretchingRatio
  global endSideMidStretchingRatio
  global connectorList
  

  foreach conn $connectorList {

    set dist [pw::DistributionGrowth create]

    # If stretching ratios on either side are set to zero, assume user wants a tanh distribution in middle section
    if { $startSideMidStretchingRatio == 0.0 || $endSideMidStretchingRatio == 0.0 } { 
      $dist setMiddleMode SwitchToTanh
      $dist setMiddleSpacing 0.0
    }

    $dist setBeginMode LayersAndRate
    $dist setBeginLayers [expr $startLayers-1]
    set beginRateList [list ]
    for {set i 1} {$i<$startLayers} {incr i 1} {
      lappend beginRateList 1.0
    }
    $dist setBeginRateProfile $beginRateList

    if { $endSide == 1 } {
      $dist setEndMode LayersAndRate
      $dist setEndLayers [expr $endLayers-1]
      set endRateList [list ]
      for {set i 1} {$i<$endLayers} {incr i 1} {
        lappend endRateList 1.0
      }
      $dist setEndRateProfile $endRateList
    }

    $conn replaceDistribution 1 $dist

  }

  pw::Display update
  
}

proc checkSelectionState {} {
  
  global applyBtn
  global selectionState
  global conSelected
  
  if { $conSelected == 1 } {
    set selectionState normal
    setState $applyBtn $selectionState
  }
}

proc updateEndState {} {
  
  global endLayerBtn endBeginSRBtn endMidSRBtn
  global endSide
  
  if { $endSide == 1 } {
    set selectionState "normal"
    setState $endLayerBtn   $selectionState
    setState $endBeginSRBtn $selectionState
#    setState $endMidSRBtn   $selectionState
    setState $endMidSRBtn   "disabled"
  } else {
    set selectionState "disabled"
    setState $endLayerBtn   $selectionState
    setState $endBeginSRBtn $selectionState
    setState $endMidSRBtn   $selectionState
  }
}

proc lequal {l1 l2} {
  set nl1 [llength $l1]
  set nl2 [llength $l2]
  if { $nl1 != $nl2 } {
    return false
  }
  for {set i 0} {$i<$nl1} {incr i 1} {
    if {[lindex $l1 $i] != [lindex $l2 $i]} {
      return false
    } else {
      continue
    }
  }
  return true
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

proc setState {parent state} {

  catch {$parent configure -state $state}

  set wlist [winfo children $parent]
  foreach win $wlist {
    setState $win $state
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

if {$scriptMode == "gui" } {
  #################################################################
  ##  GUI MODE
  #################################################################

  pw::Script loadTk
  
  set conSelected 0

  set extendStartState "normal"
  set extendEndState "normal"
  
  set selectionState "disabled"
  set doubleSidedState "normal"

  set endSide 0
  set endSideState "disabled"

  set startLayers 5
  set startSideStretchingRatio 1.0
  set startSideMidStretchingRatio 0.0

  set endLayers 5
  set endSideStretchingRatio 1.0
  set endSideMidStretchingRatio 0.0
  
  set boxText "Name of curve to be extended"
 
  set tl .
  wm withdraw $tl

  set tf [frame $tl.title]
  pack $tf -side top -fill x -expand 0 -padx 2 -pady 2

  label $tf.l -text "Curve Selection" -anchor c -font {Arial 12 bold}
  pack $tf.l -side top
  set title $tf.l

  set tf [frame $tl.top]
  pack $tf -side top -fill x -expand 0 -padx 2 -pady 2

  set bf [frame $tl.bot]
  pack $bf -side bottom -fill both -expand 1 -padx 2 -pady 2

  # Create box for Text
  set f [frame $tf.1]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "Curve:"
  pack $f.file -side left

  entry $f.e -textvariable boxText -width 10
  pack $f.e -side left -fill x -expand 1

  frame $f.spc -width 3
  pack $f.spc -side left

  button $f.browse -text "Select" -command enterConnectorSelectionMode -width 6
  pack $f.browse -side left

  # Create box for text
  set f [frame $tf.2]
  pack $f -side top -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  checkbutton $f.expBlocks -text "Double-sided distribution" \
      -variable endSide \
      -state $doubleSidedState \
      -command updateEndState
  pack $f.expBlocks -side left

  set f [frame $tf.3]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "Start number of layers:"
  pack $f.file -side left

  entry $f.e -textvariable startLayers -width 10
  pack $f.e -side left -fill x -expand 1

  set f [frame $tf.4]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "Start side begin stretching ratio:"
  pack $f.file -side left

  entry $f.e -textvariable startSideStretchingRatio -width 10
  pack $f.e -side left -fill x -expand 1

  set f [frame $tf.5]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "Start side middle stretching ratio:"
  pack $f.file -side left

  entry $f.e -textvariable startSideMidStretchingRatio -width 10 -state "disabled"
  pack $f.e -side left -fill x -expand 1

  set f [frame $tf.6]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 5
  set fileFrame $f

  label $f.file -text "End number of layers:"
  pack $f.file -side left

  entry $f.e -textvariable endLayers -width 10 -state $endSideState
  set endLayerBtn $f.e
  pack $f.e -side left -fill x -expand 1

  set f [frame $tf.7]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "End side begin stretching ratio:"
  pack $f.file -side left

  entry $f.e -textvariable endSideStretchingRatio -width 10 -state $endSideState
  set endBeginSRBtn $f.e
  pack $f.e -side left -fill x -expand 1

  set f [frame $tf.8]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "End side middle stretching ratio:"
  pack $f.file -side left

#  entry $f.e -textvariable endSideMidStretchingRatio -width 10 -state $endSideState
  entry $f.e -textvariable endSideMidStretchingRatio -width 10 -state "disabled"
  set endMidSRBtn $f.e
  pack $f.e -side left -fill x -expand 1

  # Create box for button
  set f [frame $tf.9 -bd 2 -relief groove]
  pack $f -side top -fill x -expand 0 -padx 0 -pady 4

  button $f.apply -text "Apply" \
      -command {updateDistribution} -width 15 \
      -state $selectionState
 
  pack $f.apply -side left -padx 2 -pady 2

  button $f.cancel -text "Close" \
     -command {exit} -width 12
  pack $f.cancel -side right -padx 2 -pady 2

  set applyBtn $f.apply
  set closeBtn $f.cancel

  set f $bf

  set sbar [scrollbar $f.sbar -command "$f.t yview"]
  pack $sbar -side right -fill y -expand 0

  set msgBox [text $f.t -width 65 -height 14 \
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
  
  TextInsert "Description:"
  TextInsert "This script will create a growth distribution with a specified"
  TextInsert "number of layers at either end with a constant stretching ratio"

  CenterWindow $tl {} -950 -200
  wm deiconify $tl
  wm title $tl "Script to create a connector distribution with number of initial constant stretching ratio layers"

  checkPreSelection
}
