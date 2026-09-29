// Trash Can Robot — every dimension lives here (mm).
// Tags: [MEASURED] = checked on the real part, [DEFAULT] = online spec or a
// guess. Remeasure the [DEFAULT]s, edit, run ./render.sh.

// ---------- Chassis: round cutting board ----------
board_d      = 357;   // [MEASURED]
board_t      = 7;     // [MEASURED] HDPE: too thin for wood screws, parts bolt through
// The board's handle hole (a slot with round ends), turned to the back.
handle_w     = 90;    // [DEFAULT] slot length, end to end
handle_h     = 25;    // [DEFAULT] slot width
handle_from_edge = 15; // [DEFAULT] board edge to the slot's outer side
handle_keepout = 8;   // nothing bolts to the board within this of the slot

// ---------- Trash can (sits on top) ----------
can_shape    = "rect"; // "rect" (square-ish) or "round"
can_w        = 240;   // [DEFAULT] rect: base width, left-right
can_dp       = 240;   // [DEFAULT] rect: base depth, front-back
can_corner_r = 25;    // [DEFAULT] rect: corner rounding (preview only)
can_base_d   = 280;   // [DEFAULT] round: base diameter
can_h        = 400;   // [DEFAULT] preview only
can_clear    = 1.5;   // gap between can and tab wall at mid-slide

// ---------- Can tabs: 2 per side, one slot each, M4 bolt + nut through the board ----------
// A single bolt lets a tab pivot; the wall pressed flat against the can is what
// stops it. If one still twists, add a toothed washer under it.
tab_slide    = 40;    // slot travel. Each tab adjusts +-tab_slide/2
tab_w        = 36;    // wall width, split in two around the bolt
tab_gap      = 12;    // gap in the middle of the wall: hex key and washer reach the bolt through it
tab_wall_h   = 40;    // wall height; taller = more tip resistance
tab_bolt_d   = 4.5;   // M4 clearance
strap_w      = 26;    // belt tunnel for a 25mm velcro strap around the can, 0 = none
// rect can: where each pair sits along its side (the rear pair is set by the handle)
side_tab_y   = [-15, -60]; // left/right pairs, behind the motor mounts (y 5-75)
front_tab_x  = 60;    // front pair, this far either side of center; carries the eyes

// ---------- Googly eyes, on stalks off the front tabs ----------
// Housing prints face-down in white, pupil + washer in black. The pupil's stem
// goes through the housing face and the washer presses on behind: M3x8 x2 per
// eye through the stalk into the housing rim.
eyes         = false;  // shelved 2026-09-28: sideways camera, face comes back later if at all
eye_d        = 45;
eye_pupil_d  = 25;    // covers the stem hole wherever the pupil sits
eye_travel   = 5;     // how far the pupil wobbles off center

// ---------- Drive motors: Greartisan 12V 100RPM (37mm gearbox) ----------
gearbox_d    = 37;    // [DEFAULT] spec
gearbox_l    = 24.5;  // [DEFAULT] spec
motor_d      = 36.2;  // [DEFAULT] spec
motor_l      = 33.3;  // [DEFAULT] spec
motor_tail_l = 6;     // [DEFAULT] brush cap / terminals behind the can
shaft_d      = 6;     // [DEFAULT] spec, D-shaft
shaft_flat   = 5.5;   // [DEFAULT] across the D flat
shaft_l      = 14;    // [DEFAULT] spec
shaft_offset = 0;     // [MEASURED] centric (photo)
// Gearbox face: 6x M3 threaded holes, 60 deg apart, one at 12 o'clock. Face is flush [MEASURED].
gb_holes_pcd = 28;    // [MEASURED ~28, tape] opposite hole to opposite hole; slots cover gb_pcd_range
gb_pcd_range = [27, 32];  // slotted so a 28 or a 31 PCD gearbox both fit
gb_thread    = 4;     // [LISTING] M3x6 with their ~2mm steel bracket = ~4mm into the gearbox; deeper can hit the gears
gb_boss_d    = 12;    // [PHOTO] raised ring around the shaft

// ---------- Wheels (printed by default) ----------
wheel_d      = 80;    // [DEFAULT]
wheel_w      = 20;
tire_groove  = 4;     // 2mm deep groove for an O-ring, rubber band or inner-tube strip; 0 = none
edge_margin  = 6;     // wheel outer face inset from the board edge

// ---------- Drive layout ----------
// One rear caster, so the drive axle sits ahead of the can's center: the can's
// weight then lands inside the wheel-wheel-caster triangle.
drive_y      = 40;    // drive axle, forward of board center

// ---------- Swivel caster (printed, rear) ----------
// M8 pivot bolt through a 608 skate bearing, or the printed caster_bushing
// (same size) until you have one. Wheel spins on an M4 bolt.
caster_y       = -108; // pivot position; clear of the handle so fingers fit
caster_wheel_d = 50;
caster_wheel_w = 16;
caster_trail   = 22;   // axle trails the pivot, so the wheel self-aligns
caster_axle_d  = 4.4;  // M4 clearance, wheel spins on the bolt
pivot_bolt_d   = 8.4;  // M8 clearance = 608 bore
brg_od         = 22;   // 608 bearing / bushing
brg_t          = 7;
caster_lift    = 1;    // caster sits this much high so the drive wheels keep traction

// ---------- Front skids: stop the can tipping forward on hard braking ----------
skid_gap     = 8;     // floor clearance; 0 = no skids
skid_pos     = [[110, 118], [-110, 118]];

// ---------- Electronics ----------
l298n        = [43, 43]; // [DEFAULT]
l298n_holes  = [37, 37]; // [DEFAULT] M3, center to center
l298n_h      = 27;       // [DEFAULT] incl. heatsink
lm2596       = [43, 21]; // [DEFAULT]
lm2596_holes = [30, 16]; // [DEFAULT] two holes, diagonal corners
lm2596_h     = 14;
esp32        = [66, 28.1, 1.6]; // [LISTING 28.1; tape said 27, too tight] FORIOT ESP32-S3-CAM PCB (L incl. antenna, W, T); T is nominal
esp32_lens   = 17;              // [MEASURED] lens center from the antenna-end edge, centered across the width
esp32_lens_proud = 8;           // [PHOTO] lens front, in front of the PCB face
esp32_tab    = [5.5, 19.3, 2.6]; // [PHOTO] antenna tab past the header shoulders: length, width (19.3 scaled off the fit photo; 18 bound), thickness incl. module
esp32_usb_clear = 10;           // [MEASURED] header-free strip on the back at the USB end
esp32_corner = 4;               // [MEASURED] bare corners beside the USB ports, where the mounting holes are
esp32_hole   = [2.5, 2.5, 3];   // [PHOTO] mounting hole center from the USB edge, from the long edge; dia [MEASURED ~3]
// Mounted sideways, USB end to the right, so both USB-C ports plug in from the side.
cam_tilt     = 25;       // degrees upward. Baked into training data — don't change after collecting demos
cam_vfov     = 55;       // [GUESS] vertical field of view, portrait (sensor long axis vertical)
cam_drop     = 10;       // PCB top edge below the board underside
cam_from_edge = 9;       // lens tip behind the board edge: the board must stay out of the view, the cradle inside the rim

// ---------- Power bank ----------
bank         = [134, 71, 25]; // [DEFAULT] INIU 20000mAh (B5 size) — L, W, H
bank_y       = 45;

// ---------- Board positions (underside, board center = origin, +y = front) ----------
l298n_pos    = [0, -35];
lm2596_pos   = [-75, -70];

// ---------- Fasteners / print ----------
wood_screw_d = 3.8;   // clearance for #6 / 3.5mm screws into the board
m3_tap_d     = 2.8;   // M3 self-tapping into plastic
m3_clear_d   = 3.4;
m3_nut_af    = 5.5;   // M3 nut across flats
m25_tap_d    = 2.2;   // M2.5 self-tapping into plastic
m3_nut_t     = 2.4;
standoff_h   = 5;
wall         = 3;
fit          = 0.3;   // clearance added to press/slide fits
$fn          = 64;

// ---------- Derived (don't edit) ----------
board_r      = board_d / 2;
wheel_r      = wheel_d / 2;
// Axle sits far enough below the board that the wheel clears it: no slots to cut.
axle_below   = wheel_r + 4;
ride_h       = wheel_r + axle_below;            // floor to board underside
wheel_cx     = board_r - edge_margin - wheel_w / 2;
mbr_t        = 4;                                // motor bracket face plate, between gearbox and wheel
wheel_gap    = 1;                                // plate to wheel hub
gearbox_face_x = wheel_cx - wheel_w / 2 - wheel_gap - mbr_t;  // gearbox face (shaft end)
shaft_in_wheel = shaft_l - mbr_t - wheel_gap;   // how much shaft the wheel hub gets
motor_total_l  = gearbox_l + motor_l + motor_tail_l;
handle_cy    = -(board_r - handle_from_edge - handle_h / 2);
caster_wr    = caster_wheel_d / 2;
caster_plate_t   = brg_t + 1.5;                                  // fork top plate, bearing pocket + lip
caster_plate_bot = caster_wheel_d + caster_lift + 3;              // 3mm over the wheel
caster_mount_h   = ride_h - caster_plate_bot - caster_plate_t - 1; // 1mm collar gap
rear_tab_x   = handle_w / 2 + handle_keepout + tab_w / 2;   // rear pair flanks the handle hole
