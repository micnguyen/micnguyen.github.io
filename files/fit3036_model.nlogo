;; This software is the original work of Michael Hieu Nguyen. ID: 22042962
;; This software is submitted in partial fulfillment of the 
;; requirements for the degree of Bachelor of Science, 
;; Monash University

globals ;; global variables
[
  hive-nutrition ;; amount of nutrition the hive currently has
  ticks-to-harvest ;; number of ticks it takes for a bee to stay on a flower to harvest nutrients
  hive-saturation ;; max saturation of nutrients for hive
]

turtles-own ;; variables for bees
[
  t1pref ;; preference for t1 plants (0 <= t1pref >= 100)
  t2pref ;; preference for t2 plants (0 <= t2pref >= 100)
  current-nutrition  ;; current amount of nutrition bee is holding
  harvesting? ;; boolean to state whether the bee is currently foraging
  start-harvest-time ;; variable to store time (tick) when they start foraging
  returning-hive? ;; if bee is returning home
  past-flowers ;; past flowers
  strategy ;; string for strategy
  total-collected ;; total nutrients bee has returned to hive
  past-flowers-success-type ;; list of past successful flower types
  past-flowers-failure-type ;; list of past failed flower types
]

patches-own ;; variables for plants
[
  hive? ;; Boolean to represent if patch is the hive (only true on px/ycor 0 0)
  plant? ;; Boolean to represent if the patch is a plant
  flower-type ;; Type of the plant and its flowers (T1/T2)
  number-of-flowers ;; Number of flowers on this plant
  full? ;; Max number of bees on this flower (might delete)
  reward-chance ;; Chance this plant and its flowers can reward bee
]

to setup ;; initial method run when 'setup model' button is clicked
  clear-all ;; Clear everything for a new start
  if debug-mode [ print "Starting new model..." ]
  set hive-saturation 30000
   
  set-default-shape turtles "butterfly" ;; make the bees use the "butterfly" graphic default in netlogo
  setup-bees ;; setup the bees
  setup-field ;; setup the area
  setup-plants ;; setup the patches
  reset-ticks ;; reset all ticks

  if debug-mode 
  [ 
    print "Setup complete." type "Final parameters: "
    type "Plant density: " print plant-density
    type "T1's initial rewarding chance: " print initial-t1-pref
    type "T2's initial rewarding chance: " print initial-t2-pref
    type "Time to switch rewards/strategy: " print switch-time
  ]
end

to setup-bees ;; setup all bees
  create-turtles number-of-bees ;; create number of bees based on parameter slider 
  [ 
    setxy 0 0 ;; make them all start in the centre (hive)
    set color yellow  ;; the bees are yellw
    set t1pref initial-t1-pref ;; set their flower preferences
    set t2pref initial-t2-pref
    set current-nutrition 0
    set ticks-to-harvest 5 ;; time in ticks it takes for bee to harvest nutrient from flower
    set harvesting? false ;; boolean to check if the bee is currently in the start of harvesting a flower
    set start-harvest-time 0 ;; time in ticks when the bee starts harvesting
    set returning-hive? false ;; boolean: if bee is in progress of returning to hive
    set past-flowers [] ;; list to keep track of all bees past flowers it's landed on
    set strategy "normal" ;; strategy bee starts off with
    set total-collected 0 ;; obviously starts off with 0 nutrients
    set past-flowers-success-type [] ;; separate list to keep track of its success flower types
    set past-flowers-failure-type [] ;; same but for failure
  ]
end

to setup-field ;; setup the world grid
  ask patches ;; ask all patches
  [
    set pcolor green ;; make them green (represent the grass - nonfactor in model)
    set plant? false ;; set it by default as not a flower
    setup-hive ;; setup the hive 
  ]
end

to setup-plants ;; method to setup all plants on field
  ask patches ;; ask every patch (1600 of them)
  [
    if random 100 < plant-density ;; generate a number between 0 and 100 and see if it's under density value %, ie: higher plant density = more plants
    [
      let random-x random-pxcor ;; select a random patch to become a plant
      let random-y random-pycor ;; select a random patch to become a plant 
      
      while [random-x = 0] [ set random-x random-pxcor ] ;; remomve centre patch if it is chosen as a flower (reserved for hive)
      while [random-y = 0] [ set random-y random-pycor ]
      
      ask patch random-x random-y ;; ask a random patch to become a plant, that patch could be set a flower twice, overriding itself
      [
        set plant? true ;; set boolean as being flower
        set full? false ;; plant is not full of bees
        set number-of-flowers random 3 + 3 ;; random number of flowers between 3 - 5
        
        ifelse random 100 < T1-vs-T2-distribution  ;; set flower type based on parameter
        [
          set flower-type "T1"
          set pcolor orange + 1
          set reward-chance t1-reward-chance ;; set T1's reward chance based on parameter
        ]
        [
          set flower-type "T2"
          set pcolor violet + 1
          set reward-chance t2-reward-chance 
        ]
        
        if debug-mode
        [
          type "Plant (pxcor, pycor): " 
          type "( " type pxcor type ", " type pycor type " )"
          type " is type: " type flower-type 
          type " and has: " type number-of-flowers type " flowers"
          type " with reward chance of: " type reward-chance print "%."          
        ]
        
        set plabel number-of-flowers ;; label for number of flowers on each plant
      ]
    ]
  ]
end

to setup-hive ;; setup hive in centre
  set hive? (distancexy 0 0) < 1 ;; set the middle patch to be the hive
  set hive-nutrition 0 ;; set starting nutrition value collected of hive to be 0
  if hive?
  [ set pcolor yellow]
end

to half-day-strategy ;; method that is called from a turtle context in go method. used for changing all bee strategies at half day.
  while [current-nutrition > 0 ] ;; while loop to teleport bees back to hive 
  ;; so they return all their nutrients. was too complicated making them 'fly' to hive. to make distinction between strategy nutrients from earlier phase.
  [
    return-hive
    return-nutrients-hive
  ]
  
  set total-collected 0 ;; reset this (total-collected not reset in return-hive) so that the plotting information is accurate for each strategy, remembering all previous total-collected was done under "normal"
  set returning-hive? false
  
  ;; assign strategies based off what the selected scenario is
  if after-half-day-scenario = "All Learn"
  [
    set strategy "learn" 
    if debug-mode [ type "**** Bee: " type who type " has now adopted strategy: " print strategy ] 
  ]
  if after-half-day-scenario = "All Switch"
  [
    set strategy "switch"
    if debug-mode [ type "**** Bee: " type who type " has now adopted strategy: " print strategy ]
  ]
  if after-half-day-scenario = "All Stay"
  [
    set strategy "stay"
    if debug-mode [ type "**** Bee: " type who type " has now adopted strategy: " print strategy ]
  ]
  
  if after-half-day-scenario = "Even split bet hedging"
  [
    if debug-mode [ type "**** Even split bet hedging chosen. Now evenly assigning different strategies to all bees **** " ]
    
    let bee-id-split (who mod 3) ;; since increment of bees is in 3, can do an even split of strategy 
    if bee-id-split = 0
    [
      set strategy "stay"
      if debug-mode [ type "**** Bee: " type who type " has now adopted strategy: " print strategy ]
    ]
    if bee-id-split = 1
    [
      set strategy "switch"
      if debug-mode [ type "**** Bee: " type who type " has now adopted strategy: " print strategy ]
    ]
    if bee-id-split = 2
    [
      set strategy "learn" 
      if debug-mode [ type "**** Bee: " type who type " has now adopted strategy: " print strategy ] 
    ]
  ]  
end



to go ;; Method that runs constantly
  refresh-flowers
  ask turtles
  [   
    
    move-bees ;; call move turtles command constantly
    
    ;; condition: if the bees are currently holding as much as they can hold (or more due to some bug/skipping, return to hive
    if (current-nutrition >= max-nutrition-for-bees) 
    [
      return-hive
      return-nutrients-hive
    ]
    
    ;; condition: once the half day has elapsed, change all bees to their respective strategies. "normal" strategy is their starting off one.
    if ((ticks > switch-time) and (strategy = "normal"))
    [
      
      if debug-mode
      [
      ]
      half-day-strategy 
    ]
    
    ;; condition: if a bee has strategy "switch" and it has at least 4 successes and 4 failures, see what the history is and maybe learn off that
    if ((strategy = "switch") and (length past-flowers-success-type >= 4) and (length past-flowers-failure-type >= 4))
    [
      switch-pref-strategy
    ]
  ] 
  
  if ticks = switch-time ;; switch the reward chance of the flowers when half the day elapses
  [
    
    if debug-mode
    [
      print "" type "**** HALF DAY HAS PASSED. TICKS: " type switch-time print " IS UP. **** " 
    ]
    
    switch-flower-reward-chance
    
    if debug-mode
    [
      type "**** SELECTED HALF DAY SCENARIO FOR BEES: " type after-half-day-scenario print ". **** "
      print "**** RETURNING ALL BEES TO HIVE AND SWITCHING STRATEGY FOR ALL BEES NOW **** "
    ]
  ]  
  
  if (hive-nutrition >= hive-saturation)
  [
    stop
  ]
  tick
end

to switch-pref-strategy ;; method for bees under "switch" strategy to switch flower if they find 4 success and 4 failures  
  let num-success-t1 length filter [? = "T1"] past-flowers-success-type
  let num-success-t2 length filter [? = "T2"] past-flowers-success-type
  let num-failure-t1 length filter [? = "T1"] past-flowers-failure-type
  let num-failure-t2 length filter [? = "T2"] past-flowers-failure-type
  
  if num-success-t1 > 3 and num-failure-t2 > 3
  [
    if t1pref < t2pref
    [
      let temp t1pref
      set t1pref t2pref
      set t2pref temp
      if debug-mode
      [
        type "^ Bee: " type who print " learnt 4 successful T1s, 4 failed T2: Switching preference now..."
        type "^ New t1pref: " type t1pref type " New t2pref: " print t2pref
      ]
    ]
  ]
  
  if num-success-t2 > 3 and num-failure-t1 > 3
  [
    if t2pref < t1pref
    [
      let temp t1pref
      set t1pref t2pref
      set t2pref temp
      if debug-mode
      [
        type "^ Bee: " type who print " learnt 4 successful T2s, 4 failed T1: Switching preference now..."
        type "^ New t1pref: " type t1pref type " New t2pref: " print t2pref
      ]
    ]
  ]
  
  set past-flowers-success-type []
  set past-flowers-failure-type []
end

to switch-flower-reward-chance ;; method to switch the reward chance of t1 and t2 flowers
  let temp t1-reward-chance ;; temp variable to store, refers to global variables
  set t1-reward-chance t2-reward-chance
  set t2-reward-chance temp
  
  if debug-mode
  [
    print ""
    print "**** Switching flower reward chance ****" 
    type "**** T1 reward-chance was: " type temp type "% T2 reward-chance was: " type t1-reward-chance print "% ****" ;; Those variables are intentional
    type "**** T1 reward-chance now: " type t1-reward-chance type "% T2 reward-chance now: " type t2-reward-chance print "% ****"
  ]
  
  ask patches
  [
    ifelse flower-type = "T1"
    [
      set reward-chance t1-reward-chance
    ]
    [
      set reward-chance t2-reward-chance
    ]
  ]
end

to refresh-flowers ;; method to update whether a flower is full so not allow any other bees to harvest from it
  ask patches
  [
    ifelse count turtles-here <= number-of-flowers
    [
      set full? false
    ]
    [
      set full? true
    ]
  ]
end

to return-nutrients-hive ;; method for transferring bee nutrient to hive
  if hive? ;; add the bee's current nutrition to the hive and reset it
  [
    set hive-nutrition hive-nutrition + current-nutrition
    set total-collected total-collected + current-nutrition
    
    if debug-mode
      [ 
        print "" type "++ Bee: " type who type " transferred " type current-nutrition type " nutrients to hive. Current hive total now: "
        print hive-nutrition
        type "-- Clearing Bee: " type who print " past flowers. Setting off to new bout..."
      ]
    
    set harvesting? false
    set start-harvest-time 0
    set returning-hive? false
    set current-nutrition 0
    set past-flowers []
  ]
end

to return-hive ;; method for bees to return back to hive, should be continually run from go
  if not returning-hive? ;; only prints once
    [
      if debug-mode
      [
        print ""
        type "+ Bee: " type who type " returning to hive with " type current-nutrition print " nutrients."
      ]
    ]
  
  set returning-hive? true ;; set boolean so this method only prints once
  right random 360 ;; random degree from 0 to 360
  forward 1 ;; head 1 unit in that direction, to simulate a more 'real' path and not straight to hive
  facexy 0 0 ;; face the hive and go
  forward 2 ;; 2 Movement speed is the extra speed they get when returning with full nutrition
  
end

to move-bees ;; Method for bees to fly 
  let already-been? false ;; already-been is temp variable to determine if bee has already visited this flower before
  
  set label-color red ;; label for their nutrition 
  set label current-nutrition ;; red label next to them to show current nutrition
  
  let flower-xy (list pxcor pycor) ;; make temporary value of the flower bee is on to check if it's already been
  
  foreach past-flowers
  [
    if flower-xy = ?
      [
        set already-been? true
      ]    
  ]
  
  if (plant? and not full? and not already-been?) ;; if you're on a flower and it's not completely full and you haven't alreayd been here
  [ 
    let chance random 100 ;; generate a temp number between 0 and 100 to see if you can land on the flower
    
    ifelse flower-type = "T1"
    [
      ifelse chance < t1pref ;; if the number generated falls within the bees preference, harvest it
        [
          harvest-flower
        ]
        [ ;; otherwise fly past it
          if debug-mode
          [
            print "" type "Bee: " type who type " flew over but decided not to land on plant ( " type pxcor type ", " type pycor type " ) of type: " print flower-type
            fd 1
          ]
        ]
    ]
    [
      ifelse chance < t2pref
        [
          ;;type "Bee " type who type " decided to land on plant ( " type pxcor type ", " type pycor type " ) of type: " print flower-type
          harvest-flower
        ]
        [
          if debug-mode
          [
            print "" type "Bee: " type who type " flew over but decided not to land on plant ( " type pxcor type ", " type pycor type " ) of type: " print flower-type
            fd 1
          ]
          
        ]
    ]
  ]
  
  if(plant? and (start-harvest-time + ticks-to-harvest) < ticks and harvesting?) ;; time for the plant to stay on the plant for a certain number of ticks before moving off
  [
    set harvesting? false ;; finished harvesting and can move off
    set start-harvest-time 0 ;; reset the time in which he started harvesting
    if debug-mode
    [
      print "" type "+ Bee: " type who type " finished harvesting plant ( " type pxcor type ", " type pycor print " ). Moving off plant."
    ]
    fd 1
  ]
  
  if(not harvesting?) ;; otherwise, if the bee has finished harvesting (or hasn't harvested) keep flying around
  [
    right random 360 ;; randomly rotate between 0deg and 360deg
    forward 1 ;; move forward 1 unit in that direction, simulates a more realistic movement
    ;; *** CONSIDER ADDING VISION?
  ]
end

to harvest-flower ;; method called in the context of turtles, from move-bees, for harvesting flower
  ifelse count turtles-here > number-of-flowers ;; if the number of bees on that plant is more than the number of flowers it has, do not harvest
  [
    set full? true
  ]
  [
    harvesting-process;; otherwise, there is a free flower so run the procedure to harvest flowers
  ]
end

to harvesting-process ;; **** CONSIDER RENAMING **** Method for bee to attempt and extract the nutrient from the flower for all strategies
  set full? false
  if not harvesting?
  [
    set start-harvest-time ticks ;; set the time when the bee starts to harvest in order to make him stay there for some time
    
    if debug-mode 
    [ 
      print ""
      type "Bee: " type who type " strategy: " type strategy type " landed on plant ( " type pxcor type ", " type pycor 
      type " ) of type: " type flower-type type " with reward chance of: " type reward-chance 
      type "% at tick time: " type start-harvest-time print "."
      type "-- Starting attempt of harvest.."
    ]
    
    set past-flowers fput (list pxcor pycor) past-flowers ;; add the current flower position it is harvesting onto its list of previous flowers (append to start)
    
    if flower-type = "T1" ;; if the plant the bee landed on is of type T1
    [
      let chance random-float 100 ;; generate a number to see if it can harvest it or not
      
      ifelse chance < (reward-chance) ;; create reward chance based off plant's reward %
      [
        set current-nutrition current-nutrition + 1 ;; succeeess condition for t1. 
        set past-flowers-success-type fput (flower-type) past-flowers-success-type ;; save the type of flower onto its past success types (mainly for switch strategy)
        
        if t1pref < 100 and t2pref > 0 ;; condition to prevent >100% preference for t1 plant
        [
          ifelse strategy = "stay" and t2pref = 70 ;; preventing change if bee is on stay strategy and hit the threshold
          [
            if debug-mode 
              [ 
                print "" 
                type "-- Bee: " type who type " failed! No change in current nutrition, still: " print current-nutrition
                type "-- T1 preference: " type t1pref type "% T2 preference: " type t2pref print "%."
                type "~~ Bee: " type who print " is on strategy: Stay. Hard wired not to drop below 70%. Not changing preference..."
              ]
          ]
          [
            ;; otherwise, if its on a different strategy or not met the stay threshold continue
            set t1pref t1pref + 1 ;; increase T1 plant preference
            set t2pref t2pref - 1 ;; decrease T2 plant preference
            
            if debug-mode
            [ 
              print ""
              type "-- Bee: " type who type " strategy: " type strategy type " succeeded! Increase nutrition by 1, current nutrition: " type current-nutrition print "." 
              type "-- Increase preference for T1 by 1%, now t1pref: " type (t1pref) 
              type "%, decrease preference for T2 by 1%, now t2pref: " type (t2pref) print "%."
              type "-- Adding to bee's past flowers: ( " type pxcor type ", " type pycor print " )."
              type "-- Bee " type who type " past flowers: " print past-flowers 
              type "-- Last 4 success types: " 
              
              ;; print out the past 4 success types with appropriate length checking if there is less than 4
              ifelse length past-flowers-success-type < 4
              [
                type past-flowers-success-type
              ]
              [
                type sublist past-flowers-success-type 0 4
              ]
              type " Last 4 failure types: "
              
              ifelse length past-flowers-failure-type < 4
              [
                print past-flowers-failure-type
              ]
              [
                print sublist past-flowers-failure-type 0 4
              ]
            ]
          ]
        ]
      ]
      [
        ;; failure condition for t1
        set past-flowers-failure-type fput (flower-type) past-flowers-failure-type ;; append the failed flower type to the list of failures
        
        if t1pref > 0 and t2pref < 100 ;; condition to prevent negative preference
        [
          ifelse strategy = "stay" and t1pref = 70 ;; threshold measure for bees on strategy stay
          [
            if debug-mode 
              [ 
                print "" 
                type "-- Bee: " type who type " failed! No change in current nutrition, still: " print current-nutrition
                type "-- T1 preference: " type t1pref type "% T2 preference: " type t2pref print "%."
                type "~~ Bee: " type who print " is on strategy: Stay. Hard wired not to drop below 70%. Not changing preference..."
              ]
          ]
          [
            set t1pref t1pref - 1 ;; decrease preference for t1               
            set t2pref t2pref + 1 ;; increase preference for t2
            
            if debug-mode
            [ 
              print ""
              type "-- Bee: " type who type " failed! No change in current nutrition, still: " print current-nutrition
              type "-- Increase preference for T2 by 1%, now t2pref: " type (t2pref) 
              type "%, decrease preference for T1 by 1%, now t1pref: " type (t1pref) print "%."
              type "-- Adding to bee's past flowers: ( " type pxcor type ", " type pycor print " )."
              type "-- Bee " type who type " past flowers: " print past-flowers 
              type "-- Last 4 success types: " 
              ifelse length past-flowers-success-type < 4
              [
                type past-flowers-success-type
              ]
              [
                type sublist past-flowers-success-type 0 4
              ]
              type " Last 4 failure types: " 
              ifelse length past-flowers-failure-type < 4
              [
                print past-flowers-failure-type
              ]
              [
                print sublist past-flowers-failure-type 0 4
              ]
            ]
          ]
        ] 
      ]
    ]
    
    
    if flower-type = "T2" ;; if the bee lands on flower type t2, for further comments on bits of this code, look at the comments above for t1, same applies
    [
      let chance random-float 100
      
      ifelse chance < (reward-chance) ;; create reward chance based off plant's reward chance %
      [
        set current-nutrition current-nutrition + 1 ;; success condition for t2
        set past-flowers-success-type fput (flower-type) past-flowers-success-type
        
        if t2pref < 100 and t1pref > 0 ;; condition to prevent > 100% preference
        [
          ifelse strategy = "stay" and t1pref = 70
          [
            if debug-mode 
            [ 
              print "" 
              type "-- Bee: " type who type " failed! No change in current nutrition, still: " print current-nutrition
              type "-- T1 preference: " type t1pref type "% T2 preference: " type t2pref print "%."
              type "~~ Bee: " type who print " is on strategy: Stay. Hard wired not to drop below 70%. Not changing preference..."
            ]
          ]
          [
            set t2pref t2pref + 1
            set t1pref t1pref - 1
            
            if debug-mode
            [ 
              print "" 
              type "-- Bee: " type who type " succeeded! Increase nutrition by 1, current nutrition: " type current-nutrition print "."
              type "-- Increase preference for T2 by 1%, now t2pref: " type (t2pref) 
              type "%, decrease preference for T1 by 1%, now t1pref: " type (t1pref) print "%."
              type "-- Adding to bee's past flowers: ( " type pxcor type ", " type pycor print " )."
              type "-- Bee " type who type " past flowers: " print past-flowers 
              type "-- Last 4 success types: " 
              ifelse length past-flowers-success-type < 4
              [
                type past-flowers-success-type
              ]
              [
                type sublist past-flowers-success-type 0 4 
              ]
              type " Last 4 failure types: " 
              ifelse length past-flowers-failure-type < 4
              [
                print past-flowers-failure-type
              ]
              [
                print sublist past-flowers-failure-type 0 4
              ]
            ]
          ]
        ]
      ]
      [
        ;; failure condition for t2
        set past-flowers-failure-type fput (flower-type) past-flowers-failure-type
        
        if t2pref > 0 and t1pref < 100
        [
          ifelse strategy = "stay" and t2pref = 70
          [
            if debug-mode 
              [ 
                print "" 
                type "-- Bee: " type who type " failed! No change in current nutrition, still: " print current-nutrition
                type "-- T1 preference: " type t1pref type "% T2 preference: " type t2pref print "%."
                type "~~ Bee: " type who print " is on strategy: Stay. Hard wired not to drop below 70%. Not changing preference..."
              ]
          ]
          [
            set t2pref t2pref - 1
            set t1pref t1pref + 1
            
            if debug-mode
            [ 
              print ""
              type "-- Bee: " type who type " failed! No change in current nutrition, still: " print current-nutrition
              type "-- Increase preference for T1 by 1%, now t1pref: " type (t1pref) 
              type "%, decrease preference for T2 by 1%, now t2pref: " type (t2pref) print "%."
              type "-- Adding to bee's past flowers: ( " type pxcor type ", " type pycor print " )."
              type "-- Bee " type who type " past flowers: " print past-flowers 
              type "-- Last 4 success types: " 
              ifelse length past-flowers-success-type < 4
              [
                type past-flowers-success-type
              ]
              [
                type sublist past-flowers-success-type 0 4
              ]
              type " Last 4 failure types: " 
              ifelse length past-flowers-failure-type < 4
              [
                print past-flowers-failure-type
              ]
              [
                print sublist past-flowers-failure-type 0 4
              ]
            ]
          ]
        ] 
      ]
    ]
    set harvesting? true
  ]   
end
@#$#@#$#@
GRAPHICS-WINDOW
483
15
1108
661
20
20
15.0
1
10
1
1
1
0
0
0
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
177
325
282
358
Setup Model
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
314
326
424
359
Start Model
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
17
538
224
682
Nutrition Returned
ticks
nutrients
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Learn" 1.0 0 -13345367 true "" "plot (sum [total-collected] of (turtles with [strategy = \"learn\"]))"
"Stay" 1.0 0 -2674135 true "" "plot (sum [total-collected] of (turtles with [strategy = \"stay\"]))"
"Switch" 1.0 0 -13840069 true "" "plot (sum [total-collected] of (turtles with [strategy = \"switch\"]))"

SLIDER
26
36
219
69
number-of-bees
number-of-bees
3
99
60
3
1
NIL
HORIZONTAL

SLIDER
235
36
431
69
plant-density
plant-density
20
40
30
1
1
% of grid
HORIZONTAL

MONITOR
176
222
303
267
T1 Flowers (Orange)
sum [number-of-flowers] of patches with [pcolor = orange + 1 ]
17
1
11

SWITCH
29
325
147
358
debug-mode
debug-mode
1
1
-1000

SLIDER
235
80
431
113
T1-vs-T2-distribution
T1-vs-T2-distribution
0
100
50
1
1
% are T1
HORIZONTAL

MONITOR
26
222
155
267
Number of Plants
count patches with [plant? = true ]
17
1
11

MONITOR
314
223
430
268
T2 Flowers (Violet)
sum [number-of-flowers] of patches with [pcolor = violet + 1 ]
17
1
11

SLIDER
26
81
220
114
max-nutrition-for-bees
max-nutrition-for-bees
1
100
50
1
1
units
HORIZONTAL

CHOOSER
27
272
229
317
after-half-day-scenario
after-half-day-scenario
"All Stay" "All Switch" "All Learn" "Even split bet hedging"
3

SLIDER
239
278
428
311
switch-time
switch-time
100
50000
4000
100
1
ticks
HORIZONTAL

PLOT
17
371
223
521
Average Preference
Ticks
%
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"T1" 1.0 0 -817084 true "" "plot (sum [t1pref] of turtles / count turtles)"
"T2" 1.0 0 -6917194 true "" "plot (sum [t2pref] of turtles / count turtles)"

PLOT
241
369
443
519
Total Hive Nutrition
ticks
nutrients
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot (hive-nutrition)"

SLIDER
26
128
219
161
initial-t1-pref
initial-t1-pref
0
100
50
1
1
%
HORIZONTAL

SLIDER
26
175
218
208
initial-t2-pref
initial-t2-pref
0
100
50
1
1
%
HORIZONTAL

SLIDER
236
129
429
162
t1-reward-chance
t1-reward-chance
51
100
90
1
1
%
HORIZONTAL

SLIDER
237
175
430
208
t2-reward-chance
t2-reward-chance
0
49
10
1
1
%
HORIZONTAL

TEXTBOX
27
10
101
28
Bee settings:
11
0.0
1

TEXTBOX
238
10
388
28
Plant settings:
11
0.0
1

PLOT
240
535
442
682
Current Nutrition Held
ticks
nutrients
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -13840069 true "" "plot (sum [current-nutrition] of (turtles with [strategy = \"switch\"]))"
"Stay" 1.0 0 -2674135 true "" "plot (sum [current-nutrition] of (turtles with [strategy = \"stay\"]))"
"pen-2" 1.0 0 -13345367 true "" "plot (sum [current-nutrition] of (turtles with [strategy = \"learn\"]))"

@#$#@#$#@
## WHAT IS IT?

This model examines the effectivness of different bee foraging techniques and whether given certain conditions and a change in situation, which strategies can prove to be more effective.

NB: The use of 'plant' and 'flower' are used interchangably throughout this document and mean the same thing.

## HOW IT WORKS

This model has 2 main phases:

In the first phase, all the bees are under the "normal" strategy where they fly around randomly looking for flowers. Each plant on the field contains 3-5 flowers and each plant contains flowers of type T1 or T2 denoted by their different colours. Each flower has a percentage to reward a bee a nutrient based on the parameters you set. Each bee has a preference to a flower plant type based on the parameters you set. Bees can fly over a flower and based on their preference for that flower type can decide to land on it or not. Bees that do decide to land on a flower attempt harvesting its nutrients and if successful gain a +1% to that flower preference while a -1% for the other flower type and vice versa if they fail. Bees that decide to land on flowers remember what flowers they have visited and will not visit them again on the same bout until they return back to the hive.

The second phase takes place when the selected switch-time in ticks has elapsed. In the second phase, all bees drop the "normal" strategy and adopt the chosen after-half-day-strategy; "All Switch", "All Learn", "All Stay" and "Even Split Bet Hedging". The outine of strategies are below: 

- Switch: Bees that encounter 4 rewarding flowers and 4 non-rewarding flowers then switch to the rewarding flower type.
- Learn: Bees learn like they have been on the "normal" strategy with +1%/-1% for a rewarding/non-rewarding flower.
- Stay: Bees that reach above 70% for a particular flower type cannot drop below that even if it becomes non-rewarding. Note that their flower preference stays from the first phase.
- Even split: There is an even distribution of the above strategies to bees.

Though the model can be stopped any time, once the hive reaches 200,000 units of nutrients the model will stop.

## HOW TO USE IT

1. Adjust the slider parameters (see below), or use the default settings.
2. Choose the desired half day scenario and click Setup model.
3. Press Go.

Parameters:

- NUMBER-OF-BEES: The number of bees that are in the model.
- MAX-NUTRITION-FOR-BEES: Max nutrition for bees before returning back to hive
- PLANT-DENSITY: The occurence of plants in the model. 
- T1-VS-T2-DISTRIBUTION: The percentage of T1 plants.
- AFTER-HALF-DAY-SCENARIO: Model scenario that takes place after SWITCH-TIME
- SWITCH-TIME: The number of ticks until the AFTER-HALF-DAY-SCENARIO takes place.
- HIVE-SATURATION: Maximum number of nutrients hive can contain.
- INITIAL-T1-PREF: The starting preference percentage for T1 flowers for the bees.
- INITIAL-T2-PREF: The starting preference percentage for T2 flowers for the bees.
- DEBUG-MODE: Toggles command center print statements on or off. 

Notes: 
- It is a good idea to keep initial-t1-pref and initial-t2-pref in balance (summing to 100%) although not doing so would not have adverse effects.
- It is a good idea to keep t1-reward-chance and t2-reward-chance in balance (summing to 100%) although not doing so would not have adverse effects.
- DEBUG-MODE is -EXTREMELY- processor dependent as it will print thousands of console statements. Only have it on for debugging purposes as it will slow down the model considerably.

## THINGS TO NOTICE

- Bees take some take attempting to harvest a flower for nutrients and this is reflected in the model. Under the normal update speed or slower, it is possible to see bees that land on a flower and attempt to harvest it stay there for a bit before flying off and continuing their bout.

## THINGS TO TRY

- The "stay" strategy only affects bees who have developed a 70% preference to a flower type. Try adjusting the switch-time slider to a low value (100-1000) and choose the even-split scenario, preventing bees to develop a >70% for a flower type before the switch in flower preference occurs. 

## EXTENDING THE MODEL

Simulation design (2012) suggests multiple cues can be used by the bees to assist their flower detection such as vision and olfactiom, of which neither are part of this model, rather than just random flying. These would make the model more closely resemble a real world scenario.

## RELATED MODELS

See the "Ants" and "Termites" models in the NetLogo models library for similar behavioural models.

## NETLOGO FEATURES

The model imports and uses the 'bitmap' library to display the hive in the center. As a result however, scaling the model bigger or smaller will place the hive graphic in the wrong position but still keeping the actual hive position in the center.

## SEE

The included test report analyses this model's accuracy to the description.
The included report analyses the findings presented by this model.

## CREDITS AND REFERENCES

Model concept: Simulation design by A.G. Dyer, A. Dorin and K.B. Korb (2012)
Authored by: Michael Hieu Nguyen (2012) mhngu10@student.monash.edu 22042962
For the purposes of FIT3036 Computer Science Project in completion of the Bachelor of Science, Monash University Australia.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
