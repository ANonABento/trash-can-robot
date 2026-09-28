// Trash Can Robot — parametric chassis parts.
// All dimensions come from params.scad. Pick what to render with -D 'part="..."':
//   assembly (default), saddle, motor_cradle, wheel, caster_mount, caster_fork,
//   caster_wheel, caster_bushing, skid, l298n_mount, lm2596_mount, cam_cradle, cam_fit_test,
//   bank_strap, can_tab, eye_tab, eye, eye_pupil, drill_template (2D, export SVG)
// Printable parts are modelled in print orientation. The assembly places them.
//
// Layout: the cutting board is the chassis. The can sits on top; motors,
// electronics, battery and camera hang underneath. Origin = board center on the
// floor, +y = front, +x = right.

include <params.scad>

part = "assembly";
show_can = true;   // preview only

// ---------------------------------------------------------------- helpers

// Place a part whose local z=0 face bolts to the board underside, hanging down.
module hang(x = 0, y = 0, rz = 0)
    translate([x, y, ride_h]) mirror([0, 0, 1]) rotate([0, 0, rz]) children();

module screw_hole(h = 50) cylinder(d = wood_screw_d, h = h, center = true);

// M3 through the board: countersunk head flush on the board top, nut trapped in
// a hex pocket in the part's far face (z = t), so it all tightens from above.
module board_bolt(t) {
    cylinder(d = m3_clear_d, h = 50, center = true);
    translate([0, 0, t - m3_nut_t - 0.4]) cylinder(d = (m3_nut_af + fit) / cos(30), h = 10, $fn = 6);
}
// shortest stock M3 length that passes the nut
function m3_len(t) = let (need = board_t + t) [for (l = [8, 10, 12, 16, 20, 25, 30]) if (l >= need) l][0];

// Rectangular flange plate with a wood-screw hole at each listed [x, y].
module flange(size, holes, t = 4) {
    difference() {
        translate([-size[0] / 2, -size[1] / 2, 0]) cube([size[0], size[1], t]);
        for (p = holes) translate([p[0], p[1], 0]) screw_hole();
    }
}

// ---------------------------------------------------------------- motor mounts

sw = 20;                                  // saddle width along the motor axis
ring_r = gearbox_d / 2 + 4;
motor_zc = axle_below - shaft_offset;     // gearbox/can axis, below the board

// Pinch-clamp ring around the gearbox.
module saddle() {
    difference() {
        union() {
            hull() {
                translate([-sw / 2, -ring_r, 0]) cube([sw, 2 * ring_r, 1]);
                translate([0, 0, motor_zc]) rotate([0, 90, 0]) cylinder(r = ring_r, h = sw, center = true);
            }
            flange([sw, 2 * ring_r + 24], [], 5);
            translate([-sw / 2, -7, motor_zc + ring_r - 3]) cube([sw, 14, 10]);   // pinch boss
        }
        translate([0, 0, motor_zc]) rotate([0, 90, 0]) cylinder(d = gearbox_d + fit, h = sw + 2, center = true);
        translate([-sw / 2 - 1, -0.75, motor_zc]) cube([sw + 2, 1.5, ring_r + 20]);  // clamp slit
        translate([0, 0, motor_zc + ring_r + 2]) rotate([90, 0, 0]) cylinder(d = m3_clear_d, h = 40, center = true);
        for (s = [-1, 1]) translate([0, s * (ring_r + 6), 0]) screw_hole();
    }
}

// Zip-tie cradle under the motor can, so the motor isn't cantilevered off the gearbox.
module motor_cradle() {
    cw = 12;
    cr = motor_d / 2 + fit;
    difference() {
        union() {
            translate([-cw / 2, -(cr + 4), 0]) cube([cw, 2 * (cr + 4), motor_zc]);
            flange([cw, 2 * (cr + 4) + 24], [], 5);
        }
        translate([0, 0, motor_zc]) rotate([0, 90, 0]) cylinder(r = cr, h = cw + 2, center = true);
        // tie channel just above the can
        translate([-2, -50, motor_zc - cr - 5]) cube([4, 100, 2.5]);
        for (s = [-1, 1]) translate([0, s * (cr + 10), 0]) screw_hole();
    }
}

// ---------------------------------------------------------------- wheel

module d_bore(h) {
    intersection() {
        cylinder(d = shaft_d + fit, h = h);
        translate([-shaft_d, -shaft_d, 0]) cube([2 * shaft_d, shaft_d + shaft_flat - shaft_d / 2 + fit / 2, h]);
    }
}

module wheel() {
    hub_r = 9;
    web_t = 4;
    set_z = min(shaft_l, wheel_w) / 2;
    difference() {
        union() {
            difference() {
                cylinder(r = wheel_r, h = wheel_w);
                translate([0, 0, -1]) cylinder(r = wheel_r - 5, h = wheel_w + 2);
            }
            cylinder(r = hub_r, h = wheel_w);
            translate([0, 0, wheel_w - web_t]) difference() {
                cylinder(r = wheel_r - 2, h = web_t);
                for (a = [30:60:359]) rotate([0, 0, a])
                    translate([(hub_r + wheel_r - 5) / 2, 0, -1]) cylinder(r = (wheel_r - 5 - hub_r) / 2 - 4, h = web_t + 2);
            }
        }
        translate([0, 0, -1]) d_bore(min(shaft_l, wheel_w) + 1);
        // set screw onto the D flat, with a driver access hole through the rim
        translate([0, 0, set_z]) rotate([-90, 0, 0]) cylinder(d = m3_tap_d, h = wheel_r + 1);
        translate([0, hub_r + 1, set_z]) rotate([-90, 0, 0]) cylinder(d = 6, h = wheel_r);
        if (tire_groove > 0)
            translate([0, 0, 2]) difference() {
                cylinder(r = wheel_r + 1, h = wheel_w - 4);
                translate([0, 0, -1]) cylinder(r = wheel_r - tire_groove / 2, h = wheel_w);
            }
    }
}

// ---------------------------------------------------------------- casters

// Swivel caster, three printed parts plus bolts:
//   caster_mount  screws to the board; M8 bolt head trapped in its top face
//   caster_fork   holds the 608 (or caster_bushing) in a pocket, swivels on the bolt
//   caster_wheel  spins on an M4 bolt through the fork legs
// Stack on the M8, top down: head (in the mount), mount, collar, bearing inner
// race, washer, nyloc. The collar and washer only touch the inner race, so the
// fork turns freely; snug the nyloc, don't crank it.
caster_leg_t = 5;
caster_gap   = 1;                                     // wheel to leg, each side
caster_fw    = caster_wheel_w + 2 * (caster_gap + caster_leg_t);
collar_d     = 11.5;                                  // under a 608 inner race (12mm OD)
lip_hole_d   = 17;                                    // washer reaches the inner race; outer race sits on the lip
m8_head_af   = 13;

module caster_mount() {
    fl = [64, 30];
    difference() {
        union() {
            flange(fl, [], 5);
            cylinder(d = brg_od + 12, h = caster_mount_h);
            translate([0, 0, caster_mount_h]) cylinder(d = collar_d, h = 1);
        }
        cylinder(d = pivot_bolt_d, h = 3 * caster_mount_h, center = true);
        translate([0, 0, -1]) cylinder(d = m8_head_af / cos(30) + fit, h = 6.5, $fn = 6);  // head trap, board side
        for (s = [-1, 1]) translate([s * (fl[0] / 2 - 6), 0, 0]) screw_hole();
    }
}

// Fork frame: pivot on the z axis, z=0 = plate top, wheel axle at y=-trail below.
caster_axle_zl = caster_wr + caster_lift - (caster_plate_bot + caster_plate_t);

module caster_fork() {
    bw = 20;   // leg width along y
    difference() {
        union() {
            hull() {
                translate([0, 0, -caster_plate_t]) cylinder(d = brg_od + 8, h = caster_plate_t);
                translate([-caster_fw / 2, -caster_trail - bw / 2, -caster_plate_t]) cube([caster_fw, bw, caster_plate_t]);
            }
            for (sx = [-1, 1]) mirror([sx < 0 ? 1 : 0, 0, 0])
                hull() {
                    translate([caster_fw / 2 - caster_leg_t, -caster_trail - bw / 2, -caster_plate_t]) cube([caster_leg_t, bw, 1]);
                    translate([caster_fw / 2 - caster_leg_t, -caster_trail, caster_axle_zl]) rotate([0, 90, 0]) cylinder(d = bw * 0.7, h = caster_leg_t);
                }
        }
        translate([0, 0, -brg_t]) cylinder(d = brg_od + fit / 2, h = brg_t + 1);   // bearing pocket, opens toward the mount
        cylinder(d = lip_hole_d, h = 50, center = true);
        translate([0, -caster_trail, caster_axle_zl]) rotate([0, 90, 0]) cylinder(d = caster_axle_d, h = 60, center = true);
    }
}

module caster_wheel() {
    hub_boss = caster_gap - 0.3;   // spacers on the hub so the wheel can't rub the legs
    translate([0, 0, hub_boss]) difference() {
        union() {
            cylinder(r = caster_wr, h = caster_wheel_w);
            for (z = [-hub_boss, caster_wheel_w]) translate([0, 0, z]) cylinder(d = 10, h = hub_boss);
        }
        cylinder(d = caster_axle_d + fit, h = 3 * caster_wheel_w, center = true);
        for (a = [0:60:359]) rotate([0, 0, a]) translate([caster_wr * 0.55, 0, -1]) cylinder(d = caster_wr * 0.45, h = caster_wheel_w + 2);
        if (tire_groove > 0)
            translate([0, 0, 2]) difference() {
                cylinder(r = caster_wr + 1, h = caster_wheel_w - 4);
                translate([0, 0, -1]) cylinder(r = caster_wr - tire_groove / 2, h = caster_wheel_w);
            }
    }
}

// PLA stand-in for the 608: same outside size, so the fork doesn't change when
// you swap. Grease it; the fork turns on its outside.
module caster_bushing() {
    difference() {
        cylinder(d = brg_od, h = brg_t);
        translate([0, 0, -1]) cylinder(d = pivot_bolt_d + fit, h = brg_t + 2);
    }
}

// Domed post that sits skid_gap off the floor: harmless in normal driving,
// catches the board if a hard stop rocks the can forward.
module skid() {
    h = ride_h - skid_gap;
    difference() {
        union() {
            flange([40, 16], [], 5);
            cylinder(d = 14, h = h - 7);
            translate([0, 0, h - 7]) sphere(d = 14);
        }
        for (s = [-1, 1]) translate([s * 14, 0, 0]) screw_hole();
    }
}

// ---------------------------------------------------------------- electronics

// Plate with M3 standoffs for a PCB, screwed to the board through its end tabs.
module pcb_mount(size, holes) {
    pw = size[0] + 20;
    ph = size[1] + 6;
    difference() {
        union() {
            translate([-pw / 2, -ph / 2, 0]) cube([pw, ph, 3]);
            for (p = holes) translate([p[0], p[1], 0]) cylinder(d = 6.5, h = 3 + standoff_h);
        }
        for (p = holes) translate([p[0], p[1], 0]) cylinder(d = m3_tap_d, h = 50, center = true);
        for (s = [-1, 1]) translate([s * (pw / 2 - 4.5), 0, 0]) screw_hole();
        // wiring window under the board
        translate([-size[0] / 2 + 8, -size[1] / 2 + 5, -1]) cube([size[0] - 16, size[1] - 10, 5]);
    }
}

l298n_hole_list = [for (x = [-1, 1], y = [-1, 1]) [x * l298n_holes[0] / 2, y * l298n_holes[1] / 2]];
lm2596_hole_list = [[-lm2596_holes[0] / 2, -lm2596_holes[1] / 2], [lm2596_holes[0] / 2, lm2596_holes[1] / 2]];

module l298n_mount()  pcb_mount(l298n, l298n_hole_list);
module lm2596_mount() pcb_mount(lm2596, lm2596_hole_list);

// Sideways cradle for the ESP32-S3-CAM (the camera is on the PCB, so this is also
// the camera bracket). Headers cover both long edges front and back, so only the
// short ends are held: the antenna tab (ant_*) slides into a pocket, then the USB end
// swings back and two snap hooks click over its bare front corners. The back stays
// open for the dupont wires, the right end for the USB plugs.
// Built in a PCB frame: x along the PCB (lens at 0, USB end +x), y out of the
// camera face (PCB back at 0), z down the PCB width (top edge at 0).
cam_L   = esp32[0];
cam_W   = esp32[1];
cam_T   = esp32[2];
cam_xa  = -esp32_lens;          // antenna tab tip
cam_xu  = cam_L - esp32_lens;   // USB edge
ant_l   = esp32_tab[0];
ant_w   = esp32_tab[1];
ant_t   = esp32_tab[2];
ant_z0  = cam_W / 2 - ant_w / 2;
ant_z1  = cam_W / 2 + ant_w / 2;
cam_bk  = 10;     // solid depth behind the PCB; this face prints on the bed
cam_end = 2.4;    // antenna-end wall
lip_t   = 1.2;
lip_over = 1.5;   // how far the pocket lip reaches over the tab tip
hook_w  = 1.2;    // snap arm thickness; flexes along x
hook_ov = 0.8;    // how far a hook bites over the PCB front
hook_ramp = 1.6;
ledge   = 2;
gap     = 0.8;    // printable gap that keeps the snap arms free
usb_x0  = cam_xu - esp32_usb_clear + 1;   // 1mm clear of the last header
usb_relief = 2.5; // the USB shells' legs poke through the back between the corners

// frame -> hang coordinates, and the placement that does it
function cam_to_hang(p) = [p[0], p[1] * cos(cam_tilt) + p[2] * sin(cam_tilt),
                           cam_drop - p[1] * sin(cam_tilt) + p[2] * cos(cam_tilt)];
module cam_place() translate([0, 0, cam_drop]) rotate([-cam_tilt, 0, 0]) children();
module cam_unplace() rotate([cam_tilt, 0, 0]) translate([0, 0, -cam_drop]) children();

module cam_cradle_frame(beam_top = -4) {
    x0 = cam_xa - fit - cam_end;
    zb = cam_W + fit + ledge;
    // beam over the top edge; the PCB's top edge stops against it
    translate([x0, -cam_bk, beam_top]) cube([cam_xu - gap - x0, cam_bk + cam_T, -fit - beam_top]);
    // antenna end: wall, blocks either side of the tab, back pad under it, lip over its tip
    translate([x0, -cam_bk, beam_top]) cube([cam_end, cam_bk + ant_t + fit + lip_t, zb - beam_top]);
    translate([cam_xa - fit, -cam_bk, -fit]) cube([ant_l, cam_bk + ant_t + fit + lip_t, ant_z0]);
    translate([cam_xa - fit, -cam_bk, ant_z1 + fit]) cube([ant_l, cam_bk + ant_t + fit + lip_t, zb - ant_z1 - fit]);
    translate([cam_xa - fit, -cam_bk, 0]) cube([ant_l, cam_bk, cam_W]);
    translate([cam_xa - fit, ant_t + fit, 0]) cube([lip_over + fit, lip_t, cam_W]);
    // USB end: block behind the header-free strip, pads on the bare corners, ledge under the bottom edge
    translate([usb_x0, -cam_bk, beam_top]) cube([cam_xu - gap - usb_x0, cam_bk - usb_relief, zb - beam_top]);
    for (z = [0, cam_W - esp32_corner]) translate([usb_x0, -usb_relief, z]) cube([cam_xu - gap - usb_x0, usb_relief, esp32_corner]);
    translate([usb_x0, -cam_bk, cam_W + fit]) cube([cam_xu - gap - usb_x0, cam_bk + cam_T, ledge]);
    // snap hooks: arms rooted at the back, ramps over the front corners
    for (z = [0, cam_W - esp32_corner]) translate([0, 0, z]) {
        translate([usb_x0, -cam_bk, 0]) cube([cam_xu + fit + hook_w - usb_x0, 1.5, esp32_corner]);
        linear_extrude(esp32_corner) polygon([
            [cam_xu + fit, -cam_bk], [cam_xu + fit + hook_w, -cam_bk],
            [cam_xu + fit + hook_w, cam_T + fit + hook_ramp], [cam_xu + fit, cam_T + fit + hook_ramp],
            [cam_xu - hook_ov, cam_T + fit + 0.3], [cam_xu - hook_ov, cam_T + fit], [cam_xu + fit, cam_T + fit]]);
    }
}

cam_flange_t = 6;
cam_fl_back  = cam_to_hang([0, -cam_bk, -(cam_drop + cam_bk * sin(cam_tilt)) / cos(cam_tilt)])[1];
cam_fl_front = cam_to_hang([0, cam_T, -(cam_drop - cam_T * sin(cam_tilt)) / cos(cam_tilt)])[1] + 3;
cam_fl_x     = [cam_xa - fit - cam_end - 11, cam_xu + fit + hook_w + 10];
cam_fl_bolts = [for (x = [cam_fl_x[0] + 5.5, cam_fl_x[1] - 5.5]) [x, (cam_fl_back + cam_fl_front) / 2 + 1.5]];

// The whole cradle, in the PCB frame: frame, beam run up to a flange on the board.
module cam_cradle_body() intersection() {
    union() {
        cam_cradle_frame(-60);
        cam_unplace() difference() {
            translate([cam_fl_x[0], cam_fl_back - 5, 0]) cube([cam_fl_x[1] - cam_fl_x[0], cam_fl_front - cam_fl_back + 5, cam_flange_t]);
            for (b = cam_fl_bolts) translate([b[0], b[1], 0]) board_bolt(cam_flange_t);
        }
    }
    translate([-200, -cam_bk, -200]) cube(400);   // flat back
    cam_unplace() translate([-200, -200, 0]) cube(400);   // nothing above the board underside
}
module cam_cradle() cam_place() cam_cradle_body();
echo(str("cam_cradle: 2x M3x", m3_len(cam_flange_t), " countersunk + nut"));

// Just the frame: both end clamps, the ledge and the top beam, to check the fit
// before printing the flange. Prints on its back like the full cradle.
module cam_fit_test() cam_cradle_frame();

// ---------------------------------------------------------------- battery, can

module bank_strap() {
    sl = 15;
    bw = bank[1] + 2 * fit;
    bh = bank[2] + fit;
    difference() {
        rotate([90, 0, 90]) linear_extrude(sl, center = true) {
            for (s = [-1, 1]) mirror([s < 0 ? 1 : 0, 0]) {
                translate([bw / 2, 0]) square([wall, bh + wall]);
                translate([bw / 2, 0]) square([wall + 14, 4]);
            }
            translate([-bw / 2 - wall, bh]) square([bw + 2 * wall, wall]);
        }
        for (s = [-1, 1]) translate([0, s * (bw / 2 + wall + 8), 0]) screw_hole();
    }
}

// Slotted tab: wall faces the can at local x=0, +x points away from it. One
// slot on the centerline runs under a gap in the wall, so the bolt sits close
// to the can (the tabs stay on the board) and a hex key reaches it from above.
// Loosen, slide against the can, tighten.
tab_t      = 5;                                  // base plate
slot_x0    = 3;
slot_len   = tab_slide + tab_bolt_d;
tab_len    = slot_x0 + slot_len + 5;
tab_bolt_x = slot_x0 + tab_bolt_d / 2 + tab_slide / 2;  // bolt, tab at mid-slide
tab_wall_t = strap_w > 0 ? 13 : 6;
pillar_w   = (tab_w - tab_gap) / 2;
pillar_mid = tab_gap / 2 + pillar_w / 2;

// Googly eye: a housing with a stem hole in its face, and a pupil whose stem
// goes through it and gets a washer pressed on behind. Housing frame: z=0 is the
// face (print it face-down), the open back screws to the stalk.
eye_r        = eye_d / 2;
eye_stem_r   = 2.5;
eye_hole_r   = eye_stem_r + eye_travel;
eye_washer_r = eye_hole_r + 2;
eye_cav_r    = eye_washer_r + eye_travel + 0.5;
eye_face_t   = 2;
eye_washer_t = 2.5;
eye_depth    = eye_face_t + 0.3 + eye_washer_t + 1.2;
eye_stem_l   = eye_face_t + 0.6 + eye_washer_t;      // 0.6 end play keeps it loose
eye_rim_mid  = (eye_cav_r + eye_r) / 2;
eye_screw_dz = 6;                                    // screws at +-this on the stalk
eye_screw_dy = sqrt(eye_rim_mid ^ 2 - eye_screw_dz ^ 2);
// Stalk: a plate on the wall pillar nearer the robot's centerline, set forward
// of the wall so a flaring can doesn't touch it. The eye hangs off its inner edge.
stalk_x0  = 3;
stalk_t   = 4;
eye_cy    = pillar_mid + eye_screw_dy;
eye_z     = tab_wall_h + eye_r + 3;
stalk_top = eye_z + eye_screw_dz + 6;

module eye() {
    difference() {
        cylinder(r = eye_r, h = eye_depth);
        translate([0, 0, eye_face_t]) cylinder(r = eye_cav_r, h = eye_depth);
        translate([0, 0, -1]) cylinder(r = eye_hole_r, h = eye_face_t + 2);
        // pilots for the stalk screws; four, so either eye fits either stalk
        for (x = [-1, 1], y = [-1, 1]) translate([x * eye_screw_dz, y * eye_screw_dy, 1.5])
            cylinder(d = m3_tap_d, h = eye_depth);
    }
}

// Pupil (disc down) and its washer, side by side. Print black. Press the washer
// flush onto the stem end from behind the housing; a drop of CA if it's loose.
module eye_pupil() {
    cylinder(d = eye_pupil_d, h = 2);
    cylinder(r = eye_stem_r, h = 2 + eye_stem_l);
    translate([eye_pupil_d / 2 + eye_washer_r + 4, 0, 0]) difference() {
        cylinder(r = eye_washer_r, h = eye_washer_t);
        translate([0, 0, -1]) cylinder(r = eye_stem_r - 0.1, h = eye_washer_t + 2);
    }
}

// eye: 0 = none, +1/-1 = eye stalk on the +y/-y pillar
module can_tab(eye = 0) {
    difference() {
        union() {
            linear_extrude(tab_t) hull() {
                translate([0, -tab_w / 2]) square([1, tab_w]);
                for (s = [-1, 1]) translate([tab_len - 8, s * (tab_w / 2 - 8)]) circle(r = 8);
            }
            for (s = [-1, 1]) mirror([0, s < 0 ? 1 : 0, 0]) {
                translate([0, tab_gap / 2, 0]) cube([tab_wall_t, pillar_w, tab_wall_h]);
                // gusset on the outer edge, clear of the washer
                translate([0, tab_w / 2, 0]) rotate([90, 0, 0]) linear_extrude(4)
                    polygon([[tab_wall_t, 0], [tab_len - 10, 0], [tab_len - 10, tab_t], [tab_wall_t, tab_wall_h * 0.8]]);
            }
            if (eye != 0) mirror([0, eye < 0 ? 1 : 0, 0])
                translate([stalk_x0, tab_gap / 2, tab_wall_h - 1]) cube([stalk_t, pillar_w, stalk_top - tab_wall_h + 1]);
        }
        hull() for (x = [slot_x0 + tab_bolt_d / 2, slot_x0 + slot_len - tab_bolt_d / 2])
            translate([x, 0, -1]) cylinder(d = tab_bolt_d, h = tab_t + 2);
        if (strap_w > 0)   // tunnel along y, behind the can-facing skin
            translate([5, -tab_w, (tab_wall_h - strap_w) / 2 + 4]) cube([3.5, 2 * tab_w, strap_w]);
        if (eye != 0) mirror([0, eye < 0 ? 1 : 0, 0])
            for (z = [-1, 1]) translate([0, pillar_mid, eye_z + z * eye_screw_dz]) rotate([0, 90, 0])
                cylinder(d = m3_clear_d, h = 30);
    }
}

// Eye, pupil and washer where they sit on a tab (same frame), pupil sagged down.
module tab_eye(eye) {
    mirror([0, eye < 0 ? 1 : 0, 0]) translate([stalk_x0 + stalk_t + eye_depth, eye_cy, eye_z]) rotate([0, -90, 0]) {
        color("white") eye();
        color("black") translate([-eye_travel, 0, -2.3]) {
            cylinder(d = eye_pupil_d, h = 2);
            cylinder(r = eye_stem_r, h = 2 + eye_stem_l);
            translate([0, 0, 2 + eye_face_t + 0.6]) cylinder(r = eye_washer_r, h = eye_washer_t);
        }
    }
}

// [x, y, angle, eye] for each tab on the board top; angle points away from the can.
// Eyes lean toward the centerline: the front-right tab's local +y is world -x.
tab_list = can_shape == "round"
    ? [for (a = [45:90:315]) let (r = can_base_d / 2 + can_clear)
        [r * cos(a), r * sin(a), a, !eyes ? 0 : a == 45 ? 1 : a == 135 ? -1 : 0]]
    : let (x = can_w / 2 + can_clear, y = can_dp / 2 + can_clear)
      concat(
        [for (ty = side_tab_y, s = [-1, 1]) [s * x, ty, s > 0 ? 0 : 180, 0]],
        [for (s = [-1, 1]) [s * front_tab_x, y, 90, eyes ? s : 0]],
        [for (s = [-1, 1]) [s * rear_tab_x, -y, 270, 0]]);

function rot2(v, a) = [v[0] * cos(a) - v[1] * sin(a), v[0] * sin(a) + v[1] * cos(a)];
// bolt positions with the tab slid to x_along its slot (mid-slide by default)
function tab_bolts_at(xa = tab_bolt_x) = [for (t = tab_list) [t[0], t[1]] + rot2([xa, 0], t[2])];
tab_bolts = tab_bolts_at();

max_bolt_r = max([for (b = tab_bolts) norm(b)]);
echo(str("can tabs: ", len(tab_list), " tabs / M4 bolts, fit ", can_shape == "round"
    ? str("diameter ", can_base_d - tab_slide, "-", can_base_d + tab_slide)
    : str(can_w - tab_slide, "-", can_w + tab_slide, " x ", can_dp - tab_slide, "-", can_dp + tab_slide),
    " mm; outermost bolt ", round(max_bolt_r), " of ", board_r, " mm radius"));
if (max_bolt_r > board_r - 10) echo("WARNING: can tab bolts too close to the board edge — move the tabs toward center");

eye_gap = 2 * (front_tab_x - eye_cy - eye_r);
if (eyes) echo(str("eyes: ", eye_d, " mm, ", round(eye_z + board_t), " mm up; pupil wobbles ", eye_travel,
    " mm", can_shape == "rect" ? str("; ", round(eye_gap), " mm between them") : ""));
if (eyes && can_shape == "rect" && eye_gap < 2) echo("WARNING: the eyes overlap — raise front_tab_x");
if (eye_pupil_d / 2 < eye_hole_r + eye_travel) echo("WARNING: pupil too small, the stem hole shows — raise eye_pupil_d");
if (eye_r - eye_cav_r < 5) echo("WARNING: eye rim too thin for the M3s — raise eye_d or lower eye_travel");

// Swivel caster: the fork must clear the pivot nut, and stay on the board as it swings.
caster_swing_r = norm([caster_trail + caster_wr, caster_fw / 2]);
nut_clear = (caster_plate_bot - 12) - (caster_wr + caster_lift + sqrt(max(0, caster_wr ^ 2 - caster_trail ^ 2)));
echo(str("caster: mount ", caster_mount_h, " mm tall, swings to ", round(norm([0, caster_y]) + caster_swing_r),
    " of ", board_r, " mm radius; M8 nut clears the wheel by ", round(nut_clear), " mm"));
if (nut_clear < 2) echo("WARNING: caster wheel hits the pivot nut — raise caster_trail");
if (caster_mount_h < 8) echo("WARNING: caster too tall for ride height — shrink caster_wheel_d");

// Handle hole: distance from a point to the slot's edge (negative = inside it).
handle_half = handle_w / 2 - handle_h / 2;   // round-end centers at +-this
function handle_dist(p) = norm([max(abs(p[0]) - handle_half, 0), p[1] - handle_cy]) - handle_h / 2;
slide_ends = [slot_x0 + tab_bolt_d / 2, slot_x0 + slot_len - tab_bolt_d / 2];
handle_hits = concat(
    [for (xa = slide_ends, b = tab_bolts_at(xa)) if (handle_dist(b) < 4.5 + 1) "a can tab bolt"],
    [for (c = [[-32, caster_y - 17], [32, caster_y - 17], [0, caster_y - 17]])
        if (handle_dist(c) < handle_keepout) "the caster mount"]);
handle_near_y = handle_cy + handle_h / 2;   // slot edge nearest the board center
can_dp_max = 2 * (-handle_near_y - can_clear);
echo(str("handle: ", handle_w, "x", handle_h, " mm slot at the back; can depth up to ", floor(can_dp_max),
    " mm before the can covers it; ", round(caster_mount_h + board_t), " mm finger room above the caster"));
if (len(handle_hits) > 0) echo(str("WARNING: handle hole hits ", handle_hits));
if (can_shape == "rect" && can_dp > can_dp_max) echo("WARNING: a can this deep covers the handle hole");

// ---------------------------------------------------------------- stand-ins for bought parts

module ghost_motor() {   // shaft points +x, axis on x
    color("silver") rotate([0, -90, 0]) {
        translate([0, 0, 0]) cylinder(d = gearbox_d, h = gearbox_l);
        translate([0, 0, gearbox_l]) cylinder(d = motor_d, h = motor_l + motor_tail_l);
    }
    color("dimgray") translate([0, shaft_offset, 0]) rotate([0, 90, 0]) cylinder(d = shaft_d, h = shaft_l);
}

module ghost_pcb(size, h, c) {
    color(c) translate([-size[0] / 2, -size[1] / 2, 3 + standoff_h]) cube([size[0], size[1], 1.6]);
    color("black", 0.6) translate([-size[0] / 4, -size[1] / 4, 4.6 + standoff_h]) cube([size[0] / 2, size[1] / 2, h - 1.6]);
}

module ghost_bearing() {   // 608, same frame as the bushing
    color("silver") difference() {
        cylinder(d = brg_od, h = brg_t);
        translate([0, 0, -1]) cylinder(d = 8, h = brg_t + 2);
    }
}

// ---------------------------------------------------------------- assembly

saddle_x = gearbox_face_x - gearbox_l / 2;
cradle_x = gearbox_face_x - gearbox_l - motor_l / 2;
cam_lens = cam_to_hang([0, cam_T + esp32_lens_proud, cam_W / 2]);   // lens tip, cradle-relative
cam_y    = board_r - cam_from_edge - cam_lens[1];

cam_view = atan((cam_lens[2]) / cam_from_edge);
if (cam_view < cam_tilt + cam_vfov / 2)
    echo(str("WARNING: the board edge is in the camera view (edge at ", round(cam_view), " deg up, view reaches ",
             cam_tilt + cam_vfov / 2, ") — raise cam_drop or lower cam_from_edge"));
for (p = [[cam_xu + fit + hook_w, cam_T + fit + hook_ramp, cam_W], [cam_xu - gap, cam_T, cam_W + fit + ledge],
          [cam_xa - fit - cam_end, ant_t + fit + lip_t, cam_W + fit + ledge]])
    let (h = cam_to_hang(p)) if (norm([h[0], cam_y + h[1]]) > board_r)
        echo(str("WARNING: the camera cradle pokes past the board rim at x=", p[0], " — raise cam_from_edge"));
echo(str("camera: lens ", round(cam_lens[2]), " mm under the board, ", cam_from_edge, " mm behind the edge"));

module under_parts() {
    for (s = [-1, 1]) mirror([s < 0 ? 1 : 0, 0, 0]) {
        hang(saddle_x, drive_y) saddle();
        hang(cradle_x, drive_y) motor_cradle();
    }
    hang(0, caster_y) caster_mount();
    if (skid_gap > 0) for (p = skid_pos) hang(p[0], p[1]) skid();
    hang(l298n_pos[0], l298n_pos[1]) l298n_mount();
    hang(lm2596_pos[0], lm2596_pos[1]) lm2596_mount();
    hang(0, cam_y) cam_cradle();
    for (x = [-bank[0] / 2 + 20, bank[0] / 2 - 20]) hang(x, bank_y) bank_strap();
}

module top_parts() {
    for (t = tab_list) translate([t[0], t[1], ride_h + board_t]) rotate([0, 0, t[2]]) can_tab(t[3]);
}

module ghost_can() {
    taper = 1.12;
    module footprint(o = 0) {
        if (can_shape == "round") circle(d = can_base_d - o, $fn = 96);
        else offset(r = can_corner_r) square([can_w - 2 * can_corner_r - o, can_dp - 2 * can_corner_r - o], center = true);
    }
    translate([0, 0, ride_h + board_t]) difference() {
        linear_extrude(can_h, scale = taper) footprint();
        translate([0, 0, 3]) linear_extrude(can_h, scale = taper) footprint(6);
    }
}

module assembly() {
    color("burlywood") translate([0, 0, ride_h]) linear_extrude(board_t) board_2d();
    color("orange") under_parts();
    color("orange") top_parts();

    for (s = [-1, 1]) mirror([s < 0 ? 1 : 0, 0, 0]) {
        translate([gearbox_face_x, drive_y, wheel_r]) ghost_motor();
        color("dimgray") translate([wheel_cx - wheel_w / 2, drive_y, wheel_r]) rotate([0, 90, 0]) wheel();
    }
    // caster, trailing backward as it would driving forward
    translate([0, caster_y, caster_plate_bot + caster_plate_t]) {
        color("orange") caster_fork();
        translate([0, 0, -brg_t]) ghost_bearing();
        color("dimgray") translate([-caster_wheel_w / 2 - caster_gap, -caster_trail, caster_axle_zl]) rotate([0, 90, 0]) caster_wheel();
    }
    hang(l298n_pos[0], l298n_pos[1]) ghost_pcb(l298n, l298n_h, "red");
    hang(lm2596_pos[0], lm2596_pos[1]) ghost_pcb(lm2596, lm2596_h, "blue");
    color("darkslategray") translate([-bank[0] / 2, bank_y - bank[1] / 2, ride_h - bank[2]]) cube(bank);
    hang(0, cam_y) cam_place() {
        color("green") translate([cam_xa + ant_l, 0, 0]) cube([cam_L - ant_l, cam_T, cam_W]);
        color("green") translate([cam_xa, 0, ant_z0]) cube([ant_l, ant_t, ant_w]);
        color("black") translate([0, cam_T, cam_W / 2]) rotate([-90, 0, 0]) cylinder(d = 8, h = esp32_lens_proud);
    }
    for (t = tab_list) if (t[3] != 0) translate([t[0], t[1], ride_h + board_t]) rotate([0, 0, t[2]]) tab_eye(t[3]);
    if (show_can) %ghost_can();
}

module handle_2d() hull() for (s = [-1, 1]) translate([s * handle_half, handle_cy]) circle(d = handle_h);

module board_2d() difference() {
    circle(r = board_r, $fn = 128);
    handle_2d();
}

// 1:1 drilling template: footprint of every part at the board face, holes included.
module drill_template() {
    difference() {
        circle(r = board_r, $fn = 180);
        circle(r = board_r - 0.6, $fn = 180);
    }
    difference() {   // handle outline: line it up with the real hole
        handle_2d();
        offset(delta = -0.6) handle_2d();
    }
    for (a = [0, 90]) rotate(a) square([20, 0.5], center = true);
    projection(cut = true) translate([0, 0, -(ride_h - 0.5)]) under_parts();
    // can tab bolts: drill through, target rings so they stand out
    for (b = tab_bolts) translate(b) difference() {
        circle(d = 12);
        circle(d = 11);
    }
    for (b = tab_bolts) translate(b) circle(d = tab_bolt_d);
}

// ---------------------------------------------------------------- print orientation

print_parts = ["saddle", "motor_cradle", "wheel", "caster_mount", "caster_fork",
               "caster_wheel", "caster_bushing", "skid", "l298n_mount",
               "lm2596_mount", "cam_cradle", "cam_fit_test", "bank_strap", "can_tab", "eye_tab", "eye", "eye_pupil"];

module print_part(p) {
    if (p == "saddle") translate([0, 0, sw / 2]) rotate([0, 90, 0]) saddle();
    else if (p == "motor_cradle") translate([0, 0, 6]) rotate([0, 90, 0]) motor_cradle();
    else if (p == "wheel") wheel();
    else if (p == "caster_mount") caster_mount();                          // flange down
    else if (p == "caster_fork") rotate([180, 0, 0]) caster_fork();       // plate down, legs up
    else if (p == "caster_wheel") caster_wheel();
    else if (p == "caster_bushing") caster_bushing();
    else if (p == "skid") skid();
    else if (p == "l298n_mount") l298n_mount();
    else if (p == "lm2596_mount") lm2596_mount();
    else if (p == "cam_cradle") translate([0, 0, cam_bk]) rotate([90, 0, 0]) cam_cradle_body();    // back down
    else if (p == "cam_fit_test") translate([0, 0, cam_bk]) rotate([90, 0, 0]) cam_fit_test();
    else if (p == "bank_strap") translate([0, 0, 7.5]) rotate([0, 90, 0]) bank_strap();
    else if (p == "can_tab") can_tab();
    else if (p == "eye_tab") can_tab(1);
    else if (p == "eye") eye();                                           // face down
    else if (p == "eye_pupil") eye_pupil();
}

// Every part in print orientation on a 3-wide grid, labelled — for pictures, not printing.
module parts_sheet() {
    pitch = 140;
    for (i = [0:len(print_parts) - 1]) translate([(i % 3) * pitch, -floor(i / 3) * pitch, 0]) {
        color("orange") print_part(print_parts[i]);
        color("black") translate([0, -48, 0]) linear_extrude(1)
            text(print_parts[i], size = 7, halign = "center");
    }
}

if (part == "assembly") assembly();
else if (part == "parts_sheet") parts_sheet();
else if (part == "drill_template") drill_template();
else print_part(part);
