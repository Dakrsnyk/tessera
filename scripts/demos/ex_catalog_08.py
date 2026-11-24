"""Catalog lot 08: push press, power jerk, clean and jerk, one-arm medicine ball slam."""
import math

from demos import demo, show
from engine import PROFILE, THREE_QUARTER, Body, X, Y, Z, lerp, unit, vec
from ex_legs import lunge_pose
from gear import barbell, floor
from keys import keyed, pose
from poses import solve, stance, upright


def smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def mid(body):
    return (body.shoulder[1] + body.shoulder[-1]) / 2


GRIP = 0.26


def top_point(body, forward=-0.02):
    dz = max(0.0, GRIP - Body.SH_HALF)
    return mid(body) + Y * math.sqrt(0.63 ** 2 - dz ** 2 - forward ** 2) + X * forward


def rack_point(body):
    p = body.chest.at(u=Body.THORAX - 0.06, f=Body.W_TORSO / 2 + 0.06)
    p[2] = 0.0
    return p


def draw_bar(s, body, press):
    """The bar goes from the front of the shoulders to above the head, passing in front of the face."""
    rack = rack_point(body)
    top = top_point(body)
    top[2] = 0.0
    bar = lerp(rack, top, press)
    clear = body.head[1] + Body.HEAD + 0.02
    if bar[1] <= clear:
        bar[0] = rack[0]
    else:
        bar[0] = lerp(rack[0], top[0], smooth(min(1.0, (bar[1] - clear) / max(top[1] - clear, 1e-6))))
    k = min(1.0, press * 2.0)
    for side in (1, -1):
        pole = unit(lerp(unit(X + Y * 0.4 + Z * side * 0.3), unit(-Y + X * 0.7 + body.chest.r * side * 0.4), k))
        body.arm(side, bar + Z * side * GRIP, pole)
    barbell(s, bar, Z, plate_r=0.2)
    return bar


def head_tilt(press):
    return -14.0 * math.sin(math.pi * min(1.0, press * 1.6))


# --- Push press --------------------------------------------------------------------------------------

@demo("x-push-press", views=[PROFILE(), THREE_QUARTER(35, 10)],
      muscles=(["shoulders"], ["quads", "triceps"]),
      labels=("Barre sur l'avant des épaules", "Flexion légère des genoux", "Extension explosive des jambes",
              "Bras tendus au-dessus de la tête", "Retour aux épaules"),
      segments=[(0.6, 0.0, 0.0, 0, 1), (0.45, 0.0, 0.2, 1, 1), (0.3, 0.2, 0.4, 2, 1), (0.9, 0.4, 1.0, 3, 1),
                (0.5, 1.0, 1.0, 3, 1), (1.4, 1.0, 0.0, 4, 1)])
def push_press(p, s):
    floor(s, -0.75, 0.75)
    if p < 0.2:
        dip, press = smooth(p / 0.2), 0.0
    elif p < 0.4:
        dip, press = 1.0 - smooth((p - 0.2) / 0.2), 0.12 * smooth((p - 0.2) / 0.2)
    else:
        dip, press = 0.0, 0.12 + 0.88 * smooth((p - 0.4) / 0.6)
    body = upright(0.95 - 0.1 * dip, 0.0, shoulder_x=0.0, head=head_tilt(press))
    stance(body, -0.06, half_width=0.15, toe_out=8.0)
    draw_bar(s, body, press)
    show(s, body)


# --- Power jerk --------------------------------------------------------------------------------------

@demo("x-power-jerk", views=[PROFILE(), THREE_QUARTER(35, 10)],
      muscles=(["quads"], ["shoulders", "triceps", "glutes", "hamstrings", "calves", "abs"]),
      labels=("Barre sur l'avant des épaules", "Flexion rapide des genoux (dip)", "Extension explosive des jambes",
              "Réception, bras verrouillés, genoux fléchis", "Redressement, barre au-dessus de la tête", "Retour aux épaules"),
      segments=[(0.6, 0.0, 0.0, 0, 1), (0.3, 0.0, 0.2, 1, 1), (0.25, 0.2, 0.45, 2, 1), (0.35, 0.45, 0.65, 3, 1),
                (0.8, 0.65, 1.0, 4, 1), (0.5, 1.0, 1.0, 4, 1), (1.6, 1.0, 0.0, 5, 1)])
def power_jerk(p, s):
    floor(s, -0.75, 0.75)
    if p < 0.2:
        depth, press, catch = smooth(p / 0.2), 0.0, 0.0
    elif p < 0.45:
        t = smooth((p - 0.2) / 0.25)
        depth, press, catch = 1.0 - t, 0.5 * t, 0.0
    elif p < 0.65:
        t = smooth((p - 0.45) / 0.2)
        depth, press, catch = 0.0, 0.5 + 0.5 * t, t
    else:
        t = smooth((p - 0.65) / 0.35)
        depth, press, catch = 0.0, 1.0, 1.0 - t
    # The knees give a little when the bar is caught (quarter squat), then straighten.
    hip = 0.95 - 0.1 * depth - 0.17 * catch
    body = upright(hip, 0.0, shoulder_x=0.0, head=head_tilt(press))
    stance(body, -0.06, half_width=0.17 if (catch > 0 or press > 0.5) else 0.15, toe_out=12.0)
    draw_bar(s, body, press)
    show(s, body)


# --- Clean and jerk ----------------------------------------------------------------------------------

def cj_keys():
    from ex_full import CLEAN_KEYS
    pos = [0.0, 0.08, 0.14, 0.2, 0.26]
    return [(q, k) for q, (_, k) in zip(pos, CLEAN_KEYS[:5])]


CJ_KEYS = cj_keys()


def jerk_body(depth, press, split):
    """Dip (depth), bar height (press), split of the feet (0 = feet together, 1 = split)."""
    hip_y = 0.95 - 0.1 * depth - 0.17 * split
    head = head_tilt(press)
    if split < 1e-3:
        body = upright(hip_y, 0.0, shoulder_x=0.0, head=head)
        stance(body, -0.06, half_width=0.15, toe_out=8.0)
        return body
    front = -0.06 + 0.42 * split
    back_toe = 0.105 - 0.52 * split
    body = lunge_pose(vec(front, 0.0, 0.14), vec(back_toe, 0.02, -0.14), hip_y, lean=0.0,
                      back_heel_up=40.0 * split, torso_x=-0.06 + (front + back_toe - 0.045) * 0.5 * split)
    return body


@demo("x-clean-and-jerk", views=[PROFILE(), THREE_QUARTER(35, 12)], samples=61,
      muscles=(["shoulders"], ["quads", "glutes", "hamstrings", "lowerBack", "traps", "triceps", "abs"]),
      labels=("Barre au sol, dos plat", "Premier tirage", "Extension explosive", "Réception sur les épaules",
              "Debout, barre en appui avant", "Flexion rapide (dip)", "Extension et poussée",
              "Fente de réception, bras verrouillés", "Pieds ramenés, barre en haut", "Retour"),
      segments=[(0.5, 0.0, 0.0, 0, 1), (0.7, 0.0, 0.08, 1, 1), (0.3, 0.08, 0.14, 2, 1), (0.3, 0.14, 0.2, 3, 1),
                (0.5, 0.2, 0.26, 4, 1), (0.5, 0.26, 0.26, 4, 1), (0.3, 0.26, 0.36, 5, 1), (0.25, 0.36, 0.5, 6, 1),
                (0.4, 0.5, 0.65, 7, 1), (0.7, 0.65, 0.85, 8, 1), (0.6, 0.85, 0.85, 8, 1), (2.4, 0.85, 0.0, 9, 1)])
def clean_and_jerk(p, s):
    floor(s, -0.9, 0.9)
    if p <= 0.26:
        body = pose(keyed(p, CJ_KEYS))
        bar = (body.grip[1] + body.grip[-1]) / 2
        bar[2] = 0.0
        barbell(s, bar, Z)
        show(s, body)
        return
    if p < 0.36:
        depth, press, split = smooth((p - 0.26) / 0.1), 0.0, 0.0
    elif p < 0.5:
        t = smooth((p - 0.36) / 0.14)
        depth, press, split = 1.0 - t, 0.45 * t, 0.0
    elif p < 0.65:
        t = smooth((p - 0.5) / 0.15)
        depth, press, split = 0.0, lerp(0.45, 1.0, t), t
    else:
        t = smooth((p - 0.65) / 0.2)
        depth, press, split = 0.0, 1.0, 1.0 - t
    body = jerk_body(depth, press, split)
    draw_bar(s, body, press)
    show(s, body)


# --- One-arm medicine ball slam ---------------------------------------------------------------------

BALL_R = 0.11


@demo("x-one-arm-medicine-ball-slam", views=[PROFILE(), THREE_QUARTER(40, 12)],
      muscles=(["abs"], ["back", "shoulders"]),
      labels=("Ballon au-dessus de la tête, bras tendu", "Claquement vers le sol", "Ballon au sol, hanches et genoux fléchis",
              "Reprise du ballon"),
      timing=(0.7, 0.45, 0.5, 1.4))
def one_arm_slam(p, s):
    floor(s, -0.8, 1.1)
    k = smooth(p)
    hip_y = lerp(0.95, 0.58, k)
    lean = lerp(-4.0, 62.0, k)
    head = lerp(-4.0, -30.0, k)

    def ax(x):
        return mid(upright(hip_y, lean, pelvis_x=x, head=head))[0]

    body = upright(hip_y, lean, pelvis_x=solve(ax, -1.0, 1.0, lerp(-0.08, 0.1, k)), head=head)
    stance(body, -0.06, half_width=0.17, toe_out=10.0)
    sh = body.shoulder[1]
    start_dir = unit(vec(-0.12, 1.0, 0.0))
    end_dir = unit(vec(0.55, -1.0, 0.0))
    reach = Body.UPPER + Body.LOWER - 0.01
    line = unit(lerp(start_dir, end_dir, k))
    hand = sh + line * reach
    ball = hand + line * (BALL_R * 0.8)
    ball[1] = max(ball[1], BALL_R + 0.005)
    ball[2] = 0.0
    body.arm(1, hand, unit(-X * 0.4 + Z * 0.8 - Y * 0.2))
    free = body.shoulder[-1] + unit(vec(lerp(0.25, 0.3, k), lerp(0.35, -0.6, k), -0.35)) * 0.5
    body.arm(-1, free, unit(-X * 0.3 - Z * 0.8))
    s.ball(ball, BALL_R, "load")
    show(s, body)
