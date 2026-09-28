// Trash Can Robot — every dimension lives here (mm).
// Tags: [MEASURED] = checked on the real part, [DEFAULT] = online spec or a
// guess. Remeasure the [DEFAULT]s, edit, run ./render.sh.

// ---------- Chassis: round cutting board ----------
board_d      = 356;   // [DEFAULT] ~35.6cm per user, to confirm
board_t      = 12;    // [DEFAULT] cutting board thickness

// ---------- Trash can (sits on top) ----------
can_shape    = "rect"; // "rect" (square-ish) or "round"
can_w        = 240;   // [DEFAULT] rect: base width, left-right
can_dp       = 240;   // [DEFAULT] rect: base depth, front-back
can_corner_r = 25;    // [DEFAULT] rect: corner rounding (preview only)
can_base_d   = 280;   // [DEFAULT] round: base diameter
can_h        = 400;   // [DEFAULT] preview only
can_clear    = 1.5;   // gap between can and tab wall at mid-slide

// ---------- Can tabs: slotted, slide to fit, M4 bolt + nut through the board ----------
tab_slide    = 40;    // slot travel. Each tab adjusts +-tab_slide/2
tab_offset   = 60;    // rect: tabs sit this far off each side's center (pinwheel), clears motors/wheels
tab_w        = 24;    // wall width
tab_wall_h   = 40;    // wall height; taller = more tip resistance
tab_bolt_d   = 4.5;   // M4 clearance
tab_bolt_y   = 18;    // bolt slots sit this far either side of the wall
strap_w      = 26;    // belt tunnel for a 25mm velcro strap around the can, 0 = none

// ---------- Drive motors: Greartisan 12V 100RPM (37mm gearbox) ----------
gearbox_d    = 37;    // [DEFAULT] spec
gearbox_l    = 24.5;  // [DEFAULT] spec
motor_d      = 36.2;  // [DEFAULT] spec
motor_l      = 33.3;  // [DEFAULT] spec
motor_tail_l = 6;     // [DEFAULT] brush cap / terminals behind the can
shaft_d      = 6;     // [DEFAULT] spec, D-shaft
shaft_flat   = 5.5;   // [DEFAULT] across the D flat
shaft_l      = 14;    // [DEFAULT] spec
shaft_offset = 0;     // [DEFAULT] 0 = centric listing, ~7 if yours is eccentric

// ---------- Wheels (printed by default) ----------
wheel_d      = 80;    // [DEFAULT]
wheel_w      = 20;
tire_groove  = 3;     // groove for a rubber band / O-ring / TPU tire, 0 = none
edge_margin  = 6;     // wheel outer face inset from the board edge

// ---------- Casters ----------
caster_h        = 25; // [DEFAULT] 1" ball caster, floor to mounting face
caster_hole_sp  = 38; // [DEFAULT] mounting hole spacing
caster_hole_d   = 3.4;
caster_plate    = [48, 30]; // [DEFAULT] mounting plate footprint
caster_lift     = 1;  // casters sit this much high so drive wheels keep traction
front_caster_y  = 110;
rear_caster_y   = -135;

// ---------- Electronics ----------
l298n        = [43, 43]; // [DEFAULT]
l298n_holes  = [37, 37]; // [DEFAULT] M3, center to center
l298n_h      = 27;       // [DEFAULT] incl. heatsink
lm2596       = [43, 21]; // [DEFAULT]
lm2596_holes = [30, 16]; // [DEFAULT] two holes, diagonal corners
lm2596_h     = 14;
esp32        = [63.5, 28.5, 1.6]; // [DEFAULT] FORIOT ESP32-S3-CAM PCB (L, W, T)
esp32_pin_clear = 16;    // header pins + dupont housings behind the PCB
cam_tilt     = 25;       // degrees upward. Baked into training data — don't change after collecting demos
cam_from_edge = 5;       // how far the lens sits behind the board edge (the board blocks the view if too far)

// ---------- Power bank ----------
bank         = [134, 71, 25]; // [DEFAULT] INIU 20000mAh (B5 size) — L, W, H
bank_y       = 45;

// ---------- Board positions (underside, board center = origin, +y = front) ----------
l298n_pos    = [0, -45];
lm2596_pos   = [0, -95];

// ---------- Fasteners / print ----------
wood_screw_d = 3.8;   // clearance for #6 / 3.5mm screws into the board
m3_tap_d     = 2.8;   // M3 self-tapping into plastic
m3_clear_d   = 3.4;
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
gearbox_face_x = wheel_cx - wheel_w / 2 - 1.5;  // inner end of the gearbox
motor_total_l  = gearbox_l + motor_l + motor_tail_l;
riser_h      = ride_h - caster_h - caster_lift;
