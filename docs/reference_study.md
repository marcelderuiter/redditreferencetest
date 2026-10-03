# Reference study

Notes taken from `reference/reference.png` (1080x810) before building anything.
Pixel coordinates are in that image; world coordinates are metres, X east,
Y up, Z south (towards the camera).

## Camera

- High three-quarter view straight down the grid (yaw 0): room edges run
  parallel to the image axes.
- Vertical edges (pillars, tower sides, the right wall of the cellar at
  x~1060) stay almost vertical across the frame, yet floor tiles at the top
  are ~0.7x the size of those at the bottom. A plain pitched camera can't do
  both, so the matched view is a shift-lens camera: the body pitches down only
  part of the way (keystone 0.45) and an off-centre frustum does the rest.
- The orrery's floor ellipse is 225x160 px. With a centre ray 44° below the
  horizon it unprojects to a circle (8.2 m x 8.1 m), and that fixes the pitch.
- Long lens: 16° vertical FOV, 110 m from the focus. That gives ~28 px/m at
  the centre, a floor flagstone of ~0.4 m (12 px), and a statue ~2 m tall.
- `scripts/viewmath.py` holds the same projection maths as `godot/scripts/rig.gd`
  and was used to unproject every room outline below.

## Big shapes (image region -> world rectangle, floor height)

| area | image px (x, y) | world X | world Z | floor |
|---|---|---|---|---|
| keep top: guard statue, two braziers | 85-230, 35-95 | -18.5..-13 | -19.5..-16 | 1.6 |
| keep stairs going south | 115-185, 95-165 | | | 1.6 -> 0 |
| rampart walk north of the forge | 85-330, 150-185 | -18.5..-9.5 | -13.5..-11 | 0 |
| gallery: arched windows | 230-330, 70-150 | -13..-8 | -19.5..-13.5 | 0 |
| study: desk, seated statue | 330-490, 90-205 | -8..-2 | -17..-10 | 0 |
| forge: fireplace, work tables | 50-210, 235-310 | -18.5..-12.5 | -11..-3.5 | 0 |
| long hall: red runner, knight | 335-470, 250-470 | -7.5..-2.5 | -10..3 | 0 |
| landing: knight on a round base | 300-470, 470-600 | -8..-2.5 | 3..8.5 | 0 |
| throne room: big statue, candles | 15-235, 425-560 | -18.5..-10.5 | 1..7 | 0 |
| store: barrels, statue | 595-720, 150-250 | 2..7 | -16.5..-8 | 0 |
| chapel: statue in an arch, altar, runner | 725-885, 110-280 | 7..13 | -13..-6.5 | 1.6 |
| treasury: gold heaps, chests, lit arches | 885-1060, 170-330 | 13..19.5 | -11..-3.5 | 1.6 |
| orrery: round dais, brass rings, column | 665-890, 285-445 | centre 8.6,-1.3 r 4 | | 0.8 |
| east wing | 950-1065, 360-480 | 14.5..18.5 | -3..2.5 | 0.8 |
| cellar: crates, barrels, candles | 700-1070, 480-690 | 5.5..17.5 | 4..12 | 0 |
| lift: hanging plate on chains | 500-595, 455-545 | -1.5..2 | 2.5..7 | 0 |
| low dock on wooden posts | 600-700, 590-650 | 0.5..3.5 | 8..10.5 | -1.2 |

The heights come from the visible stairs: about 8 steps at the keep, 4 from
the chapel down to the orrery, and 4 from the orrery down to the cellar. With
a 0.2 m rise per step and the hall level as 0, nothing else needs a step. The
one non-level link is the hall to orrery bridge: it rises 0.8 m over 7 m.

## Connections

- keep top -> rampart (stairs), rampart -> gallery (door), gallery -> study (door)
- study -> hall (arched door), study -> store (upper wooden bridge)
- forge -> hall (wooden bridge with brass fittings)
- hall -> landing (open arch), throne -> landing (stone walk with railing)
- hall -> orrery (long wooden bridge, posts underneath)
- chapel -> orrery (stairs), chapel -> treasury (door)
- orrery -> east wing (short bridge), orrery -> cellar (stairs), east wing -> cellar (stairs)
- landing -> lift -> cellar (iron girder walkway); cellar -> low dock (stairs)

## Supports

Every room stands on a massive stone pillar that runs down into the dark,
with stepped corbels under the floor slab. Wooden and iron posts and braces
hold up the long bridges, and the lift and the dock hang from chains or stand
on posts. Nothing in the image floats.

## Materials

- Stone: warm grey-brown (~sRGB 120,100,85 when lit), individual chipped
  blocks in running bond, irregular flagstone floors, crenellated parapets,
  rubble.
- Wood: dark brown planks with brass and bronze straps and rivets (bridges,
  scaffolding, tables, crates, barrels).
- Metal: polished brass and bronze (orrery rings, fittings, candle holders),
  dark steel statues on round bases.
- Cloth: red-brown runners with gold borders. Gold: coin heaps in the treasury.

## Light and colour

- The light comes from dozens of candles (yellow-orange flames, warm pools),
  the forge fire (strong orange), braziers on the keep and lit arched windows
  in the treasury. A soft warm light from above keeps floors readable even
  away from candles.
- The abyss is dark slate blue, with fog that thickens with depth and faint
  gothic towers and arches in the distance.
- Measured: OKLab L mean 0.30 (std 0.14), median 0.26, 95th percentile 0.59.
  Orange makes up 94% of the chroma-weighted hue mix, blue 3%. Detail energy
  0.087 means a lot of fine, high-frequency surface detail.
