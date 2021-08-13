####################################################################################
# Pointwise Glyph Script
# This script will take a curve entity (connector, database curve or boundary curve)
# and extend either one or both of its endpoints by linear extrapolation. The
# resulting curve is a database curve.
#
# Author: Luis Fernandes
# Date: 09-18-2020
#
# Change Log:
#   - Date: 09-21-2020
#     Author: Luis Fernandes
#     - Added ability to pre-select an entity (connector, database curve or boundary curve)
#
#   - Date:
#     Author: 
#
####################################################################################

package require PWI_Glyph 3.18.3

set scriptMode "gui"

proc checkPreSelection {} {

  global curveSelected
  global preSelectedEntities
  global curveName curve
 
  set entitiesSelected [pw::Display getSelectedEntities -selectionmask [pw::Display createSelectionMask \
                                                        -requireConnector {Dimensioned} \
                                                        -requireDatabase {Curves} \
                                                        -requireDatabaseBoundary {}] \
                                                        preSelection]

  if { $entitiesSelected == 0 } { 
    set preSelectedEntities 0
    puts "No acceptable pre-selected entity detected."
    return
  }

  set connectorPreSelection $preSelection(Connectors)
  set databasePreSelection $preSelection(Databases)
  set boundaryPreSelection $preSelection(Boundaries)
  
  if { ([llength $connectorPreSelection] == 1 && [llength $databasePreSelection] == 0 && [llength $boundaryPreSelection] == 0) || \
       ([llength $connectorPreSelection] == 0 && [llength $databasePreSelection] == 1 && [llength $boundaryPreSelection] == 0) || \
       ([llength $connectorPreSelection] == 0 && [llength $databasePreSelection] == 0 && [llength $boundaryPreSelection] == 1) } {
    set preSelectedEntities 1
    set curveSelected 1
    if { [llength $connectorPreSelection] == 1 } {
      puts "Connector selected."
      puts "Converting connector to database spline"
      if {[info exists ::env(PW_SRC)]} {
        pw::Display setSelectedEntities [lindex $connectorPreSelection 0]
        pw::Script source $::env(PW_SRC)/connectorToSegmentSpline.glf
        pw::Display setSelectedEntities [list ]
      } else {
        puts "Must define location of pointwise scripts through environment variable PW_SRC for access to connectorToSegmentSpline.glf"
        exit
      }
      set curve [pw::Entity getByName $newCurveName]
      set curveName $newCurveName
      checkSelectionState
      return
    }
    if { [llength $databasePreSelection] == 1 } {
      puts "Database curve selected."
      set curve [lindex $databasePreSelection 0]
      set curveName [$curve getName]
      checkSelectionState
      return
    }
    if { [llength $boundaryPreSelection] == 1 } {
      puts "Boundary curve selected."
      set boundary [lindex $boundaryPreSelection 0]
      set quilt [lindex $boundary 0]
      set bCurveList [$quilt getBoundaryCurve [lindex $boundary 1]]

      set bCurve [lindex $bCurveList 0]
      set nCPoints [$bCurve getControlPointCount]
      set segCurve [pw::SegmentSpline create]
      for {set i 1} {$i<=$nCPoints} {incr i 1} {
        set point [$bCurve getXYZ -control $i]
        $segCurve addPoint $point
      }   
      set curve [pw::Curve create]
      $curve addSegment $segCurve
      set curveName [$curve getName]

      checkSelectionState
      return
    }
  } else {
    puts "More than 1 entity was pre-selected; de-selecting."
    set preSelectedEntities 0
    return
  }
}

# Enters display mode in Pointwise and allows selection of a single entity
proc enterCurveSelectionMode {} {

  global tl
  global curveName curve
  global curveSelected
  
  # Remove priority from menu window from top
  wm attributes $tl -topmost 0

  set selectionMask [pw::Display createSelectionMask -requireConnector {Dimensioned} -requireDatabase {Curves} -requireDatabaseBoundary {}]
 
  pw::Display selectEntities  -description "Select an entity you would like to extend; you may select connectors, database curves or boundary curves" \
                              -single \
                              -selectionmask $selectionMask \
                              selectedEntity

  set connectorSelected $selectedEntity(Connectors)
  set databaseCurveSelected $selectedEntity(Databases)
  set boundarySelected $selectedEntity(Boundaries)
  
  if { [llength $connectorSelected] != 0 } {
    puts "Connector selected."
    puts "Converting connector to database spline"
    if {[info exists ::env(PW_SRC)]} {
      pw::Display setSelectedEntities [lindex $connectorSelected 0]
      pw::Script source $::env(PW_SRC)/connectorToSegmentSpline.glf
      pw::Display setSelectedEntities [list ]
    } else {
      puts "Must define location of pointwise scripts through environment variable PW_SRC for access to connectorToSegmentSpline.glf"
      exit
    }
    set curve [pw::Entity getByName $newCurveName]
    set entityName $newCurveName
  } 
 
 if { [llength $databaseCurveSelected] != 0 } {
    puts "Database curve selected."
    set curve [lindex $databaseCurveSelected 0]
    set entityName [$curve getName]
  }

 if { [llength $boundarySelected] != 0 } {
    puts "Boundary curve selected."
    set boundary [lindex $boundaryPreSelection 0]
    set quilt [lindex $boundary 0]
    set bCurveList [$quilt getBoundaryCurve [lindex $boundary 1]]

    set bCurve [lindex $bCurveList 0]
    set nCPoints [$bCurve getControlPointCount]
    set segCurve [pw::SegmentSpline create]
    for {set i 1} {$i<=$nCPoints} {incr i 1} {
      set point [$bCurve getXYZ -control $i]
      $segCurve addPoint $point
    }   
    set curve [pw::Curve create]
    $curve addSegment $segCurve
    set entityName [$curve getName]
  } 

  set curveName $entityName
  set curveSelected 1

  # Bring menu window back to top
  wm attributes $tl -topmost 1

  # Check for selection state
  checkSelectionState  

  return
}

proc extendCurve {} {
  
  global tl
  global extendEnd extendStart
  global startExtensionFactor
  global endExtensionFactor
  global curve

  set segment [$curve getSegment 1]
  set s [$curve getTotalLength]

  if { $extendStart == 1 } {
    set startSlope [pwu::Vector3 scale [$segment getSlopeOut 1] -1.0]
    set startPoint [$segment getPoint 1]
    set newPoint [pwu::Vector3 add $startPoint [pwu::Vector3 scale [pwu::Vector3 normalize $startSlope] [expr $s*$startExtensionFactor]]]
    set newSegment [pw::SegmentSpline create]
    $newSegment addPoint $newPoint
    $newSegment addPoint $startPoint
    $curve insertSegment 1 $newSegment 
  }

  if { $extendEnd == 1 } {
    set nPoints [$segment getPointCount]
    set endSlope [pwu::Vector3 scale [$segment getSlopeIn $nPoints] -1.0]
    set endPoint [$segment getPoint $nPoints]
    set newPoint [pwu::Vector3 add $endPoint [pwu::Vector3 scale [pwu::Vector3 normalize $endSlope] [expr $s*$endExtensionFactor]]]
    set newSegment [pw::SegmentSpline create]
    $newSegment addPoint $endPoint
    $newSegment addPoint $newPoint
    $curve addSegment $newSegment
 }
  
  exit
}

proc checkSelectionState {} {
  
  global extendBtn
  global selectionState
  global curveSelected
  
  if { $curveSelected == 1 } {
    set selectionState normal
    setState $extendBtn $selectionState
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
  
  set curveSelected 0

  set extendStartState "normal"
  set extendEndState "normal"
  
  set selectionState "disabled"

  set startExtensionFactor 0.1
  set endExtensionFactor 0.1
  
  set curveName "Name of curve to be extended"
 
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

  entry $f.e -textvariable curveName -width 10
  pack $f.e -side left -fill x -expand 1

  frame $f.spc -width 3
  pack $f.spc -side left

  button $f.browse -text "Select" -command enterCurveSelectionMode -width 6
  pack $f.browse -side left

  # Create box for text
  set f [frame $tf.2]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "Start extension factor:"
  pack $f.file -side left

  entry $f.e -textvariable startExtensionFactor -width 10
  pack $f.e -side left -fill x -expand 1

  # Create box for text
  set f [frame $tf.3]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "End extension factor:"
  pack $f.file -side left

  entry $f.e -textvariable endExtensionFactor -width 10
  pack $f.e -side left -fill x -expand 1

  set f [frame $tf.4]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  checkbutton $f.expBlocks -text "Extend start of curve" \
      -variable extendStart \
      -state $extendStartState
  pack $f.expBlocks -side left

  set f [frame $tf.5]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  checkbutton $f.expBlocks -text "Extend end of curve" \
      -variable extendEnd \
      -state $extendEndState
  pack $f.expBlocks -side left

  # Create box for button
  set f [frame $tf.6 -bd 2 -relief groove]
  pack $f -side top -fill x -expand 0 -padx 0 -pady 4

  button $f.extendCurve -text "Extend curve" \
      -command {extendCurve} -width 15 \
      -state $selectionState
 
  pack $f.extendCurve -side left -padx 2 -pady 2

  button $f.cancel -text "Close" \
     -command {exit} -width 12
  pack $f.cancel -side right -padx 2 -pady 2

  set extendBtn $f.extendCurve
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
  TextInsert "This script will extend an existing connector, database curve"
  TextInsert "or boundary curve by a certain percentage using linear"
  TextInsert "extrapolation at either one or both ends of the curve. When"
  TextInsert "a connector is selected, it is first converted to a spline"
  TextInsert "spline database curve that fits its nodes; so make sure it"
  TextInsert "is sufficiently resolved near the endpoints for proper"
  TextInsert "extrapolation; a similar procedure is applied to a boundary,"
  TextInsert "with an initial conversion to a connector."

  CenterWindow $tl {} -950 -200
  wm deiconify $tl
  wm title $tl "Script to linearly extend a curve/connector"

  checkPreSelection
}
