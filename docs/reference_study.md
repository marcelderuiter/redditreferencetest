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

Image regions were unprojected with `scripts/viewmath.py` at the floor height
each room needed. A second pass re-measured anchors (statue bases, wall feet)
and moved the north-west cluster and the treasury about 1.5 m south. The
table shows the final values, as in `godot/scripts/plan.gd`.

| area | image px (x, y) | world X | world Z | floor |
|---|---|---|---|---|
| keep top: guard statue, braziers on two towers | 85-230, 35-100 | -18.5..-13 | -17.5..-14.5 | 1.6 |
| keep stairs going south (8 steps) | 115-185, 95-165 | | -14.5..-12 | 1.6 -> 0 |
| rampart walk north of the forge | 85-215, 150-185 | -18.5..-13 | -12..-9.5 | 0 |
| gallery: arched windows | 230-330, 60-150 | -13..-8 | -18..-12 | 0 |
| study: desk, seated statue | 330-490, 90-205 | -8..-2 | -17..-10 | 0 |
| forge: fireplace, work tables | 50-210, 170-310 | -18.5..-13 | -9.5..-3.5 | 0 |
| long hall: runner, knight | 335-470, 250-470 | -7.5..-2.5 | -10..3 | 0 |
| landing: knight (the player) | 300-470, 470-600 | -8..-2.5 | 3..8.5 | 0 |
| throne room: big statue, candles | 15-235, 425-560 | -18.5..-10.5 | 1..7 | 0 |
| store: barrels, statue | 595-720, 150-250 | 2..6.5 | -16.5..-7.5 | 0 |
| chapel: statue in an alcove, altar, runner | 725-885, 60-280 | 6.5..12 | -13..-6.5 | 1.6 |
| treasury: gold, chests, lit arches | 885-1060, 100-300 | 12..19.5 | -10.5..-4.6 | 1.6 |
| orrery: round dais, brass rings, column | 665-890, 285-445 | centre 9.25,-1.3 r 4 | | 0.8 |
| east wing | 950-1065, 345-480 | 15..18.5 | -2.6..2.5 | 0.8 |
| cellar: crates, barrels, candles | 700-1070, 480-690 | 5.5..17.5 | 4..12 | 0 |
| lift: hanging plate | 500-595, 455-545 | -1.5..2 | 3.5..7.5 | 0 |
| low dock on timber posts | 600-700, 590-650 | 0.5..3.5 | 8..10.5 | -1.2 |

The heights come from the visible stairs: about 8 steps at the keep, 4 from
the chapel down to the orrery, and 4 from the orrery down to the cellar. With
a 0.2 m rise per step and the hall level as 0, nothing else needs a step. The
one non-level link is the hall to orrery bridge: it rises 0.8 m over 7 m.

## Shafts

At thumbnail size the reference is a pale lattice of walkways around about a
dozen black holes, so the plan keeps these open (image px at floor level):

- upper left, 218-335 x 153-294: between the forge/rampart (east edge X -13)
  and the hall, south of the gallery; the forge -> hall bridge crosses it
- left, 215-305 x 332-470: the same shaft south of that bridge, down to the
  throne -> landing walk
- top centre, 480-600 x 150-340: under the study -> store bridge and the
  hall -> store girder
- store -> orrery, 616-709 x 238-324: south of the store
- treasury, 926-1035 x 273-349: under the treasury's south balustrade, a
  2 m gap before the east wing
- centre, 462-762 x 362-547: under the long hall -> orrery bridge, around the
  lift
- right, 849-956 x 395-504: under the orrery's south-east rim, between it, the
  east wing and the cellar

## Connections

- keep top -> rampart (stairs), rampart -> forge (door), gallery -> study (door)
- study -> hall (arched door), study -> store (upper wooden bridge)
- hall -> store (iron girder with timber framing, 215-250 px)
- forge -> hall (wooden bridge with brass fittings)
- hall -> landing (open arch), throne -> landing (stone walk with railing)
- hall -> orrery (long wooden bridge, posts underneath)
- chapel -> orrery (stairs), chapel -> treasury (door)
- orrery -> east wing (short bridge), orrery -> cellar (stairs), east wing -> cellar (stairs)
- landing -> lift -> cellar (iron girder walkway); cellar -> low dock (stairs)
- the door between study and hall, and the walls between other touching
  rooms, are single shared walls (see `Layout._share_walls`)

## Supports

Every room stands on a few slender stone piers that run down into the dark,
with stepped corbels under the floor slab: piers at the corners and every
5 m or so along a front, with heavy beams, knee braces and ties in the open
bays between them. Rooms whose south edge overhangs a shaft (gallery, store,
treasury) rest there on brass-banded timber posts, so the shaft below stays
open; the round dais sits on a slim drum and four posts. Wooden and iron
posts and braces hold up the long bridges, and the lift and the dock hang
from chains or stand on posts. Nothing in the image floats.

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
