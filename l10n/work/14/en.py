import sys; sys.path.insert(0, "l10n/work/14")
from common import save
L = """Standing up fully.
Hands on the sled posts, arms straight, torso leaning forward.
Move forward over the planned distance.
Keep your back straight and your torso leaning.
Drive into the floor with your legs, taking short, powerful steps.
Arms straight and locked.
Push with the front of your foot.
Straightening up while pushing.
On all fours, hands under your shoulders, knees just above the floor.
Move one hand and the opposite foot forward at the same time.
Keep your knees low and your back flat.
Then the other hand and the other foot.
Hips at shoulder height.
Small steps.
Knees touching the floor.
Hips too high.
Stand in the middle of the belt, eyes forward, without holding the rails.
Run with a light stride, landing under your body.
Start slowly, then set the speed.
Slow down gradually before you stop.
Stay in the center of the belt.
Raising the speed too fast.
Holding on to the rails.
Stand on the belt set to an incline, eyes forward.
Adjust the incline and speed to your workout.
Walk with long, steady strides.
Place your foot flat and push off through your toes.
Breathe steadily; you should be able to talk.
Torso leaning slightly, no more.
Without holding the rails if possible.
Incline too steep from the start.
Standing with feet hip-width apart, arms bent.
Switch legs quickly, in place.
Your arms move along in rhythm.
Lift one knee to hip height.
Knees at hip height.
Land on the front of your foot.
Knees too low.
Leaning back.
Stand on the pedals, hands on the moving handles, torso upright.
Adjust the resistance to your workout.
Push and pull the handles in rhythm with your legs.
Pedal in an elliptical motion, feet flat.
Torso upright, without leaning on anything.
Heels staying on the pedals.
Resistance too high.
Leaning on the console.
Stand on the stepper pedals, hands resting lightly on the rails.
Alternate at a steady pace.
Keep your torso upright.
Push one pedal down while the other comes back up.
For the planned duration, full range of motion.
Your hands are for balance.
Put your whole foot on the pedal.
Small, fast steps with no range of motion.
Putting all your weight on the rails.
Standing with the rope behind you, hands at hip height, elbows close to your body.
Keep a steady rhythm.
Turn the rope with your wrists.
Jump just high enough to let it pass.
Small jumps on the front of your foot.
Soft landing.
Wrists turning, not your arms.
Landing on your heels.
Jumping too high.
Standing with feet together, arms at your sides.
Jump while spreading your feet and raise your arms overhead.
Jump back to feet together, arms at your sides.
Arms overhead, feet wider than your shoulders.
Soft knees.
Stand facing the box, about one step away, feet hip-width apart.
Walk back down.
Land on both feet on the box, knees bent, then stand up straight.
Jump while swinging your arms forward.
Wind-up: bend your legs, arms back.
Exhale as you jump.
A manageable box height.
Quiet landing, in the center of the box.
Start with a low box.
Jumping back down.
Standing, warmed up, with clear space around you.
Go through the high-intensity circuit exercises (here jumping jacks, jump squats, high knees).
Recover between blocks according to your workout.
Repeat the circuit.
Breathe in rhythm, without holding your breath.
For the planned work and rest times.
Adjust the intensity to your level.
Movement quality before speed.
Skipping the warm-up.
Sacrificing form at the end of a set.
Float face down on the water, body aligned, face in the water.
Alternate your arms: one pulls underwater while the other comes back over the top.
Your legs kick in small, fast movements.
Turn your head to the side to breathe.
Exhale in the water, inhale with your head turned.
For the planned distance or time.
Long, tight body.
Rotate your shoulders with every arm stroke.
Kicking too wide.
Lifting your head forward to breathe.
Fighting stance facing the bag: lead foot forward, fists near your chin, knees soft.
Rear-hand cross, rotating your hip, then back to guard.
Lead-hand jab, then back to guard.
Keep combining while staying on the move.
Arm extended at impact, without locking it.
Exhale with every punch.
Wraps and gloves to protect your hands.
Your fist always returns to protect your chin.
Dropping your guard.
Punching with just your arm, without your legs.
Standing, holding a stick with both hands in a wide grip in front of your thighs, arms straight.
Keep going until it's behind your back.
Raise the stick over your head, arms straight.
Come back the same way.
Full comfortable range, without bending your elbows.
Widen your grip if it feels stuck.
Bending your elbows to get through.
Standing with feet shoulder-width apart, hands on your hips.
Switch direction after a few circles.
Draw big circles with your pelvis.
Your shoulders stay over your feet.
Moving your torso instead of your pelvis.
On all fours, hands under your shoulders, knees under your hips.
Alternate with your breathing.
Round your back and tuck your head (cat).
Gently arch your back and look forward (cow).
Exhale as you round, inhale as you arch.
Arms straight.
Movement that starts from the pelvis.
Forcing into the lower back.
In a forward lunge, opposite hand on the floor inside your front foot.
Bring your elbow toward your front foot.
Open your arm toward the ceiling, rotating your torso.
Come back, then switch sides.
Exhale as you open.
Back knee straight or down.
Look at your hand above you.
Forcing the rotation.
Letting your hips drop.
Back knee on the floor, facing the wall, front foot about four inches from the wall.
Move your front knee toward the wall, over your toes.
Keep your heel on the floor.
Come back, then move your foot back a little to progress.
As long as your heel stays on the floor.
Knee in line with your foot.
Hands on the wall for balance.
Lifting the heel.
Knee caving inward.
On all fours, one hand behind your head.
Bring your elbow toward your supporting arm.
Open your elbow toward the ceiling, rotating your upper back.
Follow your elbow with your eyes.
Standing with feet a little wider than your shoulders, toes turned out.
Lower as far as you can, heels on the floor.
Hands together in front of you, elbows against the inside of your knees.
Hold while you breathe, then stand back up.
As low as is comfortable, heels on the floor.
Back as straight as possible.
Gently push your knees outward with your elbows.
Lifting your heels.
In a lunge, back knee on the floor, front foot in front of you.
Gently shift your pelvis forward.
Squeeze the glute on the side of the knee on the floor.
Hold, then switch sides.
Until you feel a pleasant stretch at the front of your hip.
A cushion under your knee.
Kneeling, big toes together, knees apart or together.
Stretch your arms out on the floor in front of you and let go.
Sit back on your heels.
Lean your torso forward over your thighs.
Until your back feels pleasantly relaxed.
Breathe slowly into your back.
Forehead resting on the floor.
Relaxed shoulders.
Forcing your hips toward your heels.
One leg bent in front of you, shin on the floor, the other leg stretched out behind.
Gently lower your torso forward onto your hands.
Keep your pelvis square.
Until you feel a pleasant stretch in your glute.
Pelvis nice and level.
A cushion under your hip if needed.
Pelvis tilting.
Forcing the front knee.
Lying face down, hands on the floor under your shoulders, legs extended.""".split("\n")
assert len(L) == 184, len(L)
save("en", dict(enumerate(L)))
