####################################################################################
# Pointwise Glyph Script
# This script takes a connector with a single sub-connector or a database boundary
# curve and transforms it to a database curve (spline) using its underlying control
# points
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

set selectionMode 0

pw::Display getSelectedEntities -selectionmask [pw::Display createSelectionMask \
                                -requireConnector {Dimensioned}] \
                                preSelection

if { [llength $preSelection(Connectors)] == 0 } {
  puts "No acceptable connector were pre-selected."
  set selectionMode 1
}

if { [llength $preSelection(Connectors)] > 1 } {
  puts "More than 1 connector was pre-selected; de-selecting."
  set selectionMode 1
}

if { [llength $preSelection(Connectors)] == 1 } {
  puts "One acceptable connector was pre-selected. Creating database curve from selected entity."
  set selectionMode 0
}

if { $selectionMode == 1 } {
  puts "Entering selection mode."
  
  pw::Display selectEntities  -description "Select connector to create database curve from. Must be dimensioned." \
                              -single \
                              -selectionmask [pw::Display createSelectionMask \
                              -requireConnector {Dimensioned}] \
                              selectedEntityArray
  
  set connectorList $selectedEntityArray(Connectors)

  if { [llength $connectorList] != 0 } {
    set nSubCons [$connectorList getSubConnectorCount]
    set connector [lindex $connectorList 0]
    if {$nSubCons > 1} {
      puts "WARNING: More than one sub-connector detedcted. Removing breakpoints."
      $connector removeAllBreakPoints
    }
  puts "Connector selected."
  set connectorSelected 1
  }
  
  puts "Selection successful."


} else {
  set connector [lindex $preSelection(Connectors) 0]
}

set nPoints [$connector getDimension]
  
puts "Selected connector has $nPoints nodes."

set segCurve [pw::SegmentSpline create]

for {set i 1} {$i<=$nPoints} {incr i 1} {
  set point [$connector getXYZ -grid $i]
  $segCurve addPoint $point
}

puts "Creating database curve from control points."

set dbCurve [pw::Curve create]
$dbCurve addSegment $segCurve
set newCurveName [$dbCurve getName]

puts "Successfully created database curve $newCurveName."
