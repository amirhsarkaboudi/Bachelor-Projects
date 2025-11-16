extensions [nw]

turtles-own [
  infected?
  immune?
]

globals [
  avg-degree
]

to setup
  clear-all
  setup-turtles
  setup-network
  setup-infected
  calculate-network-stats
  recolor
  reset-ticks
end

to setup-turtles
  create-turtles num-turtles [
    set shape "circle"
    set color white
    set infected? false
    set immune? false
    setxy random-xcor random-ycor
  ]
end

to setup-network
  if network-type = "random" [ make-random-network ]
  if network-type = "small-world" [ make-small-world-network ]
  if network-type = "scale-free" [ make-scale-free-network ]
  if network-type = "lattice" [ make-lattice-network ]
  if network-type = "clustered" [ make-clustered-network ]

  repeat 50 [ layout-spring turtles links 0.2 5 1 ]
end

to make-random-network
  ask turtles [
    let num-links round (avg-connections / 2)
    create-links-with n-of num-links other turtles [
      set color gray
      set thickness 0.05
    ]
  ]
end

to make-small-world-network
  let n count turtles
  ask turtles [
    let k avg-connections
    let half-k floor (k / 2)
    let neighbor-list []
    let i 1
    while [i <= half-k] [
      set neighbor-list lput ((who + i) mod n) neighbor-list
      set neighbor-list lput ((who - i + n) mod n) neighbor-list
      set i i + 1
    ]
    foreach neighbor-list [
      neighbor-id ->
      create-link-with turtle neighbor-id [
        set color gray
        set thickness 0.05
      ]
    ]
  ]

  ask links [
    if random-float 1 < rewiring-prob [
      let node1 end1
      let node2 end2
      ask node1 [
        let possible-partners other turtles with [not link-neighbor? myself and self != node2]
        if any? possible-partners [
          ask myself [ die ]
          create-link-with one-of possible-partners [
            set color gray
            set thickness 0.05
          ]
        ]
      ]
    ]
  ]
end

to make-scale-free-network
  let initial-nodes min (list 5 num-turtles)
  ask n-of initial-nodes turtles [
    create-links-with other turtles with [who < initial-nodes] [
      set color gray
      set thickness 0.05
    ]
  ]

  let nodes-to-add turtles with [who >= initial-nodes]
  ask nodes-to-add [
    let m min (list avg-connections count turtles with [who < [who] of myself])

    let potential-partners turtles with [who < [who] of myself]
    let m-count 0
    while [m-count < m and any? potential-partners with [not link-neighbor? myself]] [
      let total-degree sum [count link-neighbors] of potential-partners
      if total-degree > 0 [
        let chosen-partner nobody
        let rand-val random-float total-degree
        let cumulative 0
        ask potential-partners [
          if chosen-partner = nobody [
            set cumulative cumulative + count link-neighbors
            if rand-val < cumulative [
              set chosen-partner self
            ]
          ]
        ]
        if chosen-partner != nobody and not link-neighbor? chosen-partner [
          create-link-with chosen-partner [
            set color gray
            set thickness 0.05
          ]
          set m-count m-count + 1
        ]
      ]
    ]
  ]
end

to make-lattice-network
  let grid-size ceiling sqrt num-turtles
  let i 0
  ask turtles [
    let row floor (i / grid-size)
    let col i mod grid-size
    setxy (col - grid-size / 2) (row - grid-size / 2)
    set i i + 1
  ]

  ask turtles [
    let my-x xcor
    let my-y ycor
    let nearby-turtles turtles with [
      (abs (xcor - my-x) <= 1) and
      (abs (ycor - my-y) <= 1) and
      self != myself
    ]
    let num-to-connect min (list avg-connections count nearby-turtles)
    create-links-with n-of num-to-connect nearby-turtles [
      set color gray
      set thickness 0.05
    ]
  ]
end

to make-clustered-network
  let num-communities 5
  let community-size floor (num-turtles / num-communities)

  let comm-id 0
  ask turtles [
    set comm-id floor (who / community-size)
  ]

  let i 0
  while [i < num-communities] [
    let community-members turtles with [floor (who / community-size) = i]
    ask community-members [
      let num-internal-links floor (avg-connections * 0.8)
      let potential-partners other community-members
      if count potential-partners >= num-internal-links [
        create-links-with n-of num-internal-links potential-partners [
          set color gray
          set thickness 0.05
        ]
      ]
    ]
    set i i + 1
  ]

  ask turtles [
    let my-community floor (who / community-size)
    let num-external-links floor (avg-connections * 0.2)
    let other-communities turtles with [floor (who / community-size) != my-community]
    if any? other-communities [
      let num-to-add min (list num-external-links count other-communities)
      create-links-with n-of num-to-add other-communities [
        set color orange
        set thickness 0.1
      ]
    ]
  ]
end

to calculate-network-stats
  if any? turtles [
    set avg-degree mean [count link-neighbors] of turtles
  ]
end

to setup-infected
  if init-infected > num-turtles
  [set init-infected 1]
  ask n-of init-infected turtles [
    set infected? true
  ]
end

to recolor
  ask turtles [
    ifelse infected?
    [set color red]
    [ifelse immune?
      [set color gray]
      [set color white]
    ]
  ]
end

to go
  if (count turtles with [infected?]) = 0 [ stop ]

  infect-via-network
  recover-infecteds
  recolor
  tick
end

to infect-via-network
  ask turtles with [infected?] [
    ask link-neighbors with [not infected? and not immune?] [
      if random-float 1 < transmissibility [
        set infected? true
      ]
    ]
  ]

  ask turtles with [not infected? and not immune?] [
    if random-float 1 < spontaneous-infect [
      set infected? true
    ]
  ]
end

to recover-infecteds
  ask turtles with [infected? and color = red] [
    if random-float 1 < recovery-rate [
      set infected? false
      if remove-recovered? [
        set immune? true
      ]
    ]
  ]
end

to-report prop-infected
  report (count turtles with [infected?]) / num-turtles
end

to-report prop-immune
  report (count turtles with [immune?]) / num-turtles
end

to-report prop-susceptible
  report (count turtles with [not infected? and not immune?]) / num-turtles
end

to-report clustering-coefficient
  let total-clustering 0
  let num-measured 0
  ask turtles [
    let my-neighbors link-neighbors
    let k count my-neighbors
    if k > 1 [
      let possible-links (k * (k - 1)) / 2
      let actual-links count links with [
        member? end1 my-neighbors and member? end2 my-neighbors
      ]
      set total-clustering total-clustering + (actual-links / possible-links)
      set num-measured num-measured + 1
    ]
  ]
  ifelse num-measured > 0
  [ report total-clustering / num-measured ]
  [ report 0 ]
end

to-report average-path-length
  let sample-size min (list 100 count turtles)
  let total-distance 0
  let num-pairs 0

  repeat sample-size [
    ask one-of turtles [
      let source self
      ask one-of other turtles [
        let target self
        let dist nw:distance-to source
        if dist != false [
          set total-distance total-distance + dist
          set num-pairs num-pairs + 1
        ]
      ]
    ]
  ]

  ifelse num-pairs > 0
  [ report total-distance / num-pairs ]
  [ report 0 ]
end
@#$#@#$#@
GRAPHICS-WINDOW
235
18
562
346
-1
-1
10.3
1
10
1
1
1
0
1
1
1
-15
15
-15
15
0
0
1
ticks
30.0

BUTTON
0
10
89
43
NIL
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
159
17
233
50
NIL
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
568
19
883
346
Frequency of Cooperation
Time
proportion
0.0
100.0
0.0
1.0
true
false
"" ""
PENS
"Infected" 1.0 0 -2674135 true "" "plot prop-infected"
"Immune" 1.0 0 -14070903 true "" "plot prop-immune"
"Susceptible" 1.0 0 -955883 true "" "plot prop-susceptible"

BUTTON
154
52
235
85
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
0
88
172
121
num-turtles
num-turtles
0
100
50.0
1
1
NIL
HORIZONTAL

CHOOSER
0
43
138
88
network-type
network-type
"random" "small-world" "scale-free" "lattice" "clustered"
4

SLIDER
0
152
172
185
avg-connections
avg-connections
0
49
6.0
20
1
NIL
HORIZONTAL

SLIDER
0
120
172
153
rewiring-prob
rewiring-prob
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
0
248
172
281
init-infected
init-infected
0
50
3.0
1
1
NIL
HORIZONTAL

SLIDER
0
313
172
346
transmissibility
transmissibility
0
1
0.15
0.01
1
NIL
HORIZONTAL

SLIDER
0
281
172
314
spontaneous-infect
spontaneous-infect
0
0.1
0.001
0.001
1
NIL
HORIZONTAL

SLIDER
0
345
172
378
recovery-rate
recovery-rate
0
1
0.05
0.01
1
NIL
HORIZONTAL

SWITCH
0
214
156
247
remove-recovered?
remove-recovered?
0
1
-1000

@#$#@#$#@
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
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Network Type Comparison" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <exitCondition>ticks &gt; 500</exitCondition>
    <metric>count turtles with [infected?]</metric>
    <metric>count turtles with [immune?]</metric>
    <metric>prop-infected</metric>
    <metric>prop-immune</metric>
    <metric>avg-degree</metric>
    <enumeratedValueSet variable="network-type">
      <value value="&quot;random&quot;"/>
      <value value="&quot;small-world&quot;"/>
      <value value="&quot;lattice&quot;"/>
      <value value="&quot;clustered&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-turtles">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="init-infected">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg-connections">
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="transmissibility">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-rate">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="spontaneous-infect">
      <value value="0.001"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewiring-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="remove-recovered?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
