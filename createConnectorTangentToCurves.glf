####################################################################################
# Pointwise Glyph Script
# This script will create a database spline curve with
# two end points and two endpoint derivatives specified
# by the user from existing curves. The user may select
# existing connectors, database curves, or boundaries
# for curves 1 and 2; if selecting a connector, a separate
# script is called that converts the connector into a
# database curve before proceeding. The two points selected
# will be the two control points defining the spline, and
# the end derivatives of the selected curves will be taken
# at the selected points and used as start and end derivatives
# for the new database curve that will be created.
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

package require PWI_Glyph 3.18.3

set scriptMode "gui"

# Enters display mode in Pointwise and allows selection of a single entity
proc enterCurveSelectionMode {curveNumber} {

  global curve1Name curve2Name tl curve1 curve2
  global curve1Selected curve2Selected
  
  # Remove priority from menu window from top
  wm attributes $tl -topmost 0

  set selectionMask [pw::Display createSelectionMask -requireConnector {Dimensioned} -requireDatabase {Curves} -requireDatabaseBoundary {}]
 
  pw::Display selectEntities  -description "Select an entity you would like to use for tangency; you may select connectors, database curves or boundary curves" \
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
    set boundary [lindex $boundarySelected 0]
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
  if {$curveNumber==1} {
    set curve1Name $entityName
    set curve1 $curve
    set curve1Selected 1
  } elseif {$curveNumber==2} {
    set curve2Name $entityName
    set curve2 $curve
    set curve2Selected 1
  }

  # Bring menu window back to top
  wm attributes $tl -topmost 1

  # Check for selection state
  checkSelectionState  

  return
}

proc enterPointSelectionMode { db endPointNumber } {

  global tl endPoint1XYZ endPoint2XYZ
  global endPoint1Selected endPoint2Selected

  # Remove priority from menu window from top
  wm attributes $tl -topmost 0

  set dbList [list $db]
  set pointXYZ [pw::Display selectPoint  -description "Select one of the endpoints for your curve." \
                                         -database [list $dbList]] 
  
  if { $endPointNumber == 1 } {
    set endPoint1XYZ $pointXYZ
    set endPoint1Selected 1
  } elseif { $endPointNumber == 2 } {
    set endPoint2XYZ $pointXYZ
    set endPoint2Selected 1
  }

  # Bring menu window back to top
  wm attributes $tl -topmost 1

  # Check for selection state
  checkSelectionState  

  return
}

proc createTangent {} {
  
  global tl curve1 curve2 endPoint1XYZ endPoint2XYZ
  global dFactor1 dFactor2

  set seg1 [$curve1 getSegment 1]
  set seg2 [$curve2 getSegment 1]

  set nCPointSeg1 [$seg1 getPointCount]
  set nCPointSeg2 [$seg2 getPointCount]
  
  set iPoint1 [$seg1 getXYZ -control 1]
  set ePoint1 [$seg1 getXYZ -control $nCPointSeg1]
  set iPoint2 [$seg2 getXYZ -control 1]
  set ePoint2 [$seg2 getXYZ -control $nCPointSeg2]
  
  if { [lequal $iPoint1 $endPoint1XYZ] } {
    set iSlope [$seg1 getSlopeIn 2]
  } else {
    set iSlope [$seg1 getSlopeOut [expr $nCPointSeg1-1]]
  }

  if { [lequal $iPoint2 $endPoint2XYZ] } {
    set eSlope [$seg2 getSlopeIn 2]
  } else {
    set eSlope [$seg2 getSlopeOut [expr $nCPointSeg2-1]]
  }

  set tangentSeg [pw::SegmentSpline create]
  $tangentSeg addPoint $endPoint1XYZ
  $tangentSeg addPoint $endPoint2XYZ
  
  set x1 [lindex $endPoint1XYZ 0]
  set y1 [lindex $endPoint1XYZ 1]
  set z1 [lindex $endPoint1XYZ 2]

  set x2 [lindex $endPoint2XYZ 0]
  set y2 [lindex $endPoint2XYZ 1]
  set z2 [lindex $endPoint2XYZ 2]

  set ds [list [expr $x1-$x2] [expr $y1-$y2] [expr $z1-$z2]]

  set dist [pwu::Vector3 length $ds]

  $tangentSeg setSlopeOut 1 [pwu::Vector3 scale [pwu::Vector3 normalize $iSlope] [expr $dFactor1*$dist]]
  $tangentSeg setSlopeIn  2 [pwu::Vector3 scale [pwu::Vector3 normalize $eSlope] [expr $dFactor2*$dist]]

  set tangentCurve [pw::Curve create]
  $tangentCurve addSegment $tangentSeg

  exit
}

proc checkSelectionState {} {
  
  global createBtn
  global selectionState
  global curve1Selected curve2Selected
  global endPoint1Selected endPoint2Selected
  
  if { $curve1Selected == 1 && $curve2Selected == 1 && $endPoint1Selected == 1 && $endPoint2Selected == 1 } {
    set selectionState normal
    setState $createBtn $selectionState
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
  
  set curve1Selected 0
  set endPoint1Selected 0
  set curve2Selected 0
  set endPoint2Selected 0
  set selectionState "disabled"
  
  set dFactor1 0.25
  set dFactor2 0.25

  set tl .
  wm withdraw $tl

  set tf [frame $tl.title]
  pack $tf -side top -fill x -expand 0 -padx 2 -pady 2

  label $tf.l -text "Curve 1 Selection" -anchor c -font {Arial 12 bold}
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

  label $f.file -text "Curve 1:"
  pack $f.file -side left

  set curve1Name "Name of first curve"

  entry $f.e -textvariable curve1Name -width 10
  pack $f.e -side left -fill x -expand 1

  frame $f.spc -width 3
  pack $f.spc -side left

  button $f.browse -text "Select" -command {enterCurveSelectionMode 1} -width 6
  pack $f.browse -side left

  # Create box for text
  set f [frame $tf.2]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "Endpoint 1:"
  pack $f.file -side left

  set endPoint1XYZ [list 0.0 0.0 0.0]

  entry $f.e -textvariable endPoint1XYZ -width 10
  pack $f.e -side left -fill x -expand 1

  frame $f.spc -width 3
  pack $f.spc -side left

  button $f.browse -text "Select" -command {enterPointSelectionMode $curve1 1} -width 6
  pack $f.browse -side left

  # Create box for text
  set f [frame $tf.3]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "Derivative strength factor for endpoint 1"
  pack $f.file -side left

  entry $f.e -textvariable dFactor1 -width 10
  pack $f.e -side left -fill x -expand 1

  label $tf.l -text "Curve 2 Selection" -anchor c -font {Arial 12 bold}
  pack $tf.l -side top -pady [list 10 0]
  set title $tf.l

  # Create box for text
  set f [frame $tf.4]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "Curve 2:"
  pack $f.file -side left

  set curve2Name "Name of second curve"

  entry $f.e -textvariable curve2Name -width 10
  pack $f.e -side left -fill x -expand 1

  frame $f.spc -width 3
  pack $f.spc -side left

  button $f.browse -text "Select" -command {enterCurveSelectionMode 2} -width 6
  pack $f.browse -side left

  # Create box for text
  set f [frame $tf.5]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 0
  set fileFrame $f

  label $f.file -text "Endpoint 2:"
  pack $f.file -side left

  set endPoint2XYZ [list 0.0 0.0 0.0]

  entry $f.e -textvariable endPoint2XYZ -width 10
  pack $f.e -side left -fill x -expand 1

  frame $f.spc -width 3
  pack $f.spc -side left

  button $f.browse -text "Select" -command {enterPointSelectionMode $curve2 2} -width 6
  pack $f.browse -side left

  # Create box for text
  set f [frame $tf.6]
  pack $f -side top  -fill x -expand 0 -padx 0 -pady 2
  set fileFrame $f

  label $f.file -text "Derivative strength factor for endpoint 2"
  pack $f.file -side left

  entry $f.e -textvariable dFactor2 -width 10
  pack $f.e -side left -fill x -expand 1

  # Create box for button
  set f [frame $tf.7 -bd 2 -relief groove]
  pack $f -side top -fill x -expand 0 -padx 0 -pady 4

  button $f.createTangent -text "Create tangent curve" \
      -command {createTangent} -width 15 \
      -state $selectionState
 
  pack $f.createTangent -side left -padx 2 -pady 2

  button $f.cancel -text "Close" \
     -command {exit} -width 12
  pack $f.cancel -side right -padx 2 -pady 2

  set createBtn $f.createTangent
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
  TextInsert "This script will create a database spline curve with"
  TextInsert "two end points and two endpoint derivatives specified"
  TextInsert "by the user from existing curves. The user may select"
  TextInsert "existing connectors, database curves, or boundaries"
  TextInsert "for curves 1 and 2; if selecting a connector, a separate"
  TextInsert "script is called that converts the connector into a"
  TextInsert "database curve before proceeding. The two points selected"
  TextInsert "will be the two control points defining the spline, and"
  TextInsert "the end derivatives of the selected curves will be taken"
  TextInsert "at the selected points and used as start and end derivatives"
  TextInsert "for the new database curve that will be created."

  CenterWindow $tl {} -950 -200
  wm deiconify $tl
  wm title $tl "Script to create curve tangent to two other curves"
}
