#
# Copyright 2020 (c) Pointwise, Inc.
# All rights reserved.
# 
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.  
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#

package require PWI_Glyph

# User defined parameters
set ratio   1.25;  # Desired length ratio between grid points
set tol     0.05; # Max deviation from ratio allowed
set zero    1e-5; # Define zero for equally spaced cons 
set maxIter 500;  # Max iterations for while loop

# Create selection mask for dimensioned connectors
set mask [pw::Display createSelectionMask -requireConnector {Dimensioned}]
pw::Display getSelectedEntities -selectionmask $mask resultVar
set cons $resultVar(Connectors)

# Procedure for returning the max length ratio for a connector
proc ExamineLengthRatio {con} {

    set examine [pw::Examine create ConnectorLengthRatioI]
        $examine addEntity $con
        $examine examine
        set maxLengthRatio [$examine getMaximum]

    return $maxLengthRatio

}

# Loop through each connector
foreach con $cons {

    set iter 0
    set maxRatio [ExamineLengthRatio $con]

    # If the ratio is unity, abort as this con likely has no spacing constraints
    if {[expr {abs($maxRatio-1.0)}] < $zero} {
        puts "Length ratio for [$con getName] is unity. Moving to next connector."
        continue
    }

    # While the difference between the length ratio and desired ratio is greater
    # than the tolerance, keep going. Abort once max iterations is achieved.
    while {[expr {abs($maxRatio-$ratio)}] > $tol} {

        set dim [$con getDimension]

        # Routine for adding/removing points to connectors
        if {$maxRatio < $ratio} {
            $con setDimension [expr {$dim-1}]
        } else {
            $con setDimension [expr {$dim+1}]
        }

        set maxRatio [ExamineLengthRatio $con]
        incr iter

        # Break out of loop if exeeded max iterations
        if {$iter == $maxIter} {break}

    }
    
    puts "Final length ratio for [$con getName]: [ExamineLengthRatio $con] in $iter iterations."

}

#
# DISCLAIMER:
# TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, POINTWISE DISCLAIMS
# ALL WARRANTIES, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED
# TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE, WITH REGARD TO THIS SCRIPT.  TO THE MAXIMUM EXTENT PERMITTED 
# BY APPLICABLE LAW, IN NO EVENT SHALL POINTWISE BE LIABLE TO ANY PARTY 
# FOR ANY SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES 
# WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF 
# BUSINESS INFORMATION, OR ANY OTHER PECUNIARY LOSS) ARISING OUT OF THE 
# USE OF OR INABILITY TO USE THIS SCRIPT EVEN IF POINTWISE HAS BEEN 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGES AND REGARDLESS OF THE 
# FAULT OR NEGLIGENCE OF POINTWISE.
#
