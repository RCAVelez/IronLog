# IronLog — iPhone App Design Document v2.0
*Evidence-based strength training, built for serious lifters*

---

## 1. Overview

**App Name:** IronLog
**Platform:** iOS 17+ (Swift / SwiftUI)
**Storage:** Core Data (100% on-device, zero external API calls)
**User Profile:** Male, 160 lbs, 5'9", compound-lift focused
**Design Language:** Apple-inspired minimalist — pure black OLED surfaces, white
typography, `#5AC8FA` light blue metric accents, SF Pro Rounded, no clutter

---

## 2. Confirmed Design Decisions

| Question | Answer |
|---|---|
| Schedule | Flexible — app tells you "what's next" each time you open |
| Cardio | Own dedicated 5th session (treadmill run, starts 1 mile) |
| Ab Wheel | Same day as cardio; reps/sets progression tracked |
| Weight Input | Plate-based: shows each plate denomination + quantity + total |
| Units | Pounds only |
| Plate Viz | Color-coded plate chips with counts (numbers, not animated graphic) |

---

## 3. Evidence-Based Training Foundation

All programming is derived from peer-reviewed research (2020–2025):

| Parameter | Evidence-Based Value | Source |
|---|---|---|
| Weekly sets per muscle | 10–16 productive range | Pelland et al., 2025 |
| Training frequency | 2× per muscle/week | Schoenfeld et al. |
| Weight progression (upper) | +2.5 lbs/week via wave | Stronger by Science |
| Weight progression (lower) | +5 lbs/week via wave | Stronger by Science |
| Deload frequency | Every 4 weeks (autoregulated) | Sports Medicine Open, 2024 |
| Deload volume reduction | 40–50% fewer sets, −10% intensity | Bell et al. |
| Rest — heavy compounds | 3–5 min | Barbellmedicine / SbS |
| Rest — moderate compounds | 2–3 min | Kassiano et al., 2024 |
| Rest — accessories | 90–120 sec | Kassiano et al., 2024 |
| RIR target (working sets) | 1–2 RIR (RPE 8–8.5) | Refalo et al., 2024 |
| 1RM test frequency | Every 8 weeks | PMC Tapering Review |
| Run mileage increase | Max 10% per week | BJSM |

---

## 4. Final Workout Split

**5-Day Flexible Split** — Sessions are served in order regardless of calendar day.
App always shows "Session X is next" when you open it.

```
SESSION 1 — Lower A (Quad-dominant)
  • Squat                 [primary — quads, glutes, hamstrings, core]
  Working sets: 3×8 → 4×6 → 3×5 wave
  Rest: 3–4 min between sets

SESSION 2 — Upper A (Horizontal Push + Pull)
  • Bench Press           [primary — chest, anterior deltoid, triceps]
  • Cable Row             [secondary — mid back, rear deltoid, biceps]
  Rest: 3 min (bench), 2 min (cable row)

SESSION 3 — Lower B (Hip-dominant)
  • Deadlift              [primary — hamstrings, glutes, erectors, lats]
  Working sets: 3×8 → 4×6 → 3×5 wave
  Rest: 4–5 min between sets

SESSION 4 — Upper B (Vertical Push + Pull)
  • Military Press        [primary — shoulders, triceps]
  • Lat Pulldown          [secondary — lats, biceps]
  Rest: 2–3 min (OHP), 2 min (lat pulldown)

SESSION 5 — Cardio + Core
  • Treadmill Run         [starts 1 mile, progressive overload]
  • Ab Wheel Rollout      [core — starts 3×5, progresses reps/sets]
```

**Why this split works — no overlap:**
- Squat (S1) and Deadlift (S3): 2+ sessions apart. Posterior chain fully recovered.
- Bench (S2) and Military Press (S4): 2 sessions apart. Anterior deltoid recovered.
- Cable Row (S2) and Lat Pulldown (S4): back hit twice, different planes (horizontal / vertical).
- Cardio/Ab day is standalone. Running after squats or deads would sabotage recovery.
- Squat and Deadlift each get their own session — both are maximally taxing; pairing them
  would wreck the quality of whichever lift comes second.

---

## 5. Progression System (3-Week Wave Loading)

Each barbell lift follows a **3-week loading block + 1 deload week** cycle.

```
WEEK 1  — Volume      3 sets × 8 reps  @ ~70% e1RM   RPE ~7
WEEK 2  — Accumulate  4 sets × 6 reps  @ ~75% e1RM   RPE ~8
WEEK 3  — Intensity   3 sets × 5 reps  @ ~82% e1RM   RPE 8.5
WEEK 4  — Deload      2 sets × 8 reps  @ ~58% e1RM   RPE 5–6
```

After deload: Wave restarts at **+2.5 lbs (upper)** / **+5 lbs (lower)** above
previous wave's Week 1 weight.

### Ab Wheel Progression (bodyweight, rep-based)
```
Start: 3 sets × 5 reps
Progression: When all sets are completed at RPE ≤ 7, add 1 rep per set next session
Target milestones:
  3×5 → 3×8 → 3×10 → 3×12 → 3×15 → 4×15 → 5×15 (long-term)
Deload week: 2 sets × 5 reps
```

### Run Progression (distance-based)
```
Start: 1 mile (easy pace, Zone 2)
Progression: +0.1 mile per session (until 3 miles reached)
             then +10% per week (weekly total)
Step-back every 4th week (deload week): −20% distance
Milestone unlocks:
  1.0 mi → 1.5 mi → 2.0 mi → 2.5 mi → 3.0 mi → 5K → 10K (long-term)
```

---

## 6. Adaptive Set Feedback & Weight Adjustment

After every working set, a feedback sheet slides up from the bottom:

```
┌─────────────────────────────────────┐
│   Set 2 complete                    │
│   Did you get all 6 reps?           │
│                                     │
│  [💪 Yes, felt strong]              │
│  [✓  Yes, barely made it]           │
│  [✗  No — I got _____ reps]         │
│         [  −  ][ 4 ][ + ]           │
└─────────────────────────────────────┘
```

| Response | This Session | Next Session |
|---|---|---|
| Yes, felt strong | No change | Flag: consider +2.5 lbs next wave |
| Yes, barely | No change | No change |
| No (missed, 1st set) | Reduce weight −10% for remaining sets | −5% next session |
| No (missed, 2+ sets) | Reduce weight −10% for remaining sets | −10% next session; fatigue flagged |

**Fatigue Score:** Tracks failed sets per exercise per week. If 3+ failed sets on
any primary lift in one week → app suggests early deload option.

---

## 7. Plate-Based Weight Display System

### Standard Plates Used
```
45 lb  ████  #D62828  (deep red)
35 lb  ████  #2B6CB0  (steel blue)
25 lb  ████  #D97706  (amber)
10 lb  ████  #2D6A4F  (forest green)
 5 lb  ████  #9CA3AF  (light grey)
2.5 lb ████  #6B7280  (medium grey)
Bar    ████  #4B5563  (dark grey, always 45 lbs)
```

### Display Format
For every exercise weight (working sets and warmup sets), the app shows:

```
┌──────────────────────────────────────────┐
│  225 lbs                                 │
│                                          │
│  Bar (45 lbs)                            │
│  + ██ 45  × 2  each side                 │
│                                          │
│  Total: 225 lbs                          │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│  185 lbs                                 │
│                                          │
│  Bar (45 lbs)                            │
│  + ██ 45  × 1  each side                 │
│  + ██ 25  × 1  each side                 │
│                                          │
│  Total: 185 lbs                          │
└──────────────────────────────────────────┘
```

Each plate denomination is shown as a color chip followed by weight × quantity.
Algorithm: greedy subtraction from largest plate down (45 → 35 → 25 → 10 → 5 → 2.5).

### Cable / Machine Exercises (Lat Pulldown, Cable Row)
No plate math — just shows pin weight:
```
┌────────────────────────┐
│  100 lbs               │
│  Cable pin weight      │
└────────────────────────┘
```
Input: stepper (+5 lbs / −5 lbs) since cable stacks move in 5 lb increments.

---

## 8. Warmup Protocol (Auto-Generated)

User-defined warmup style:
- **Bar × 10 reps** (always first)
- Then ramp up using plate jumps: 5 reps → 3 reps → 2 reps → 1 rep (near target)

The app calculates warmup sets dynamically from the working weight.

**Example: Working weight = 315 lbs**
```
Set 1:  Bar          (45 lbs)  × 10 reps   [rest 60 sec]
Set 2:  Bar + 25s    (95 lbs)  × 5 reps    [rest 60 sec]
Set 3:  Bar + 45s   (135 lbs)  × 3 reps    [rest 90 sec]
Set 4:  Bar+45+25   (185 lbs)  × 2 reps    [rest 90 sec]
Set 5:  Bar+2×45    (225 lbs)  × 2 reps    [rest 2 min]
Set 6:  Bar+2×45+25 (275 lbs)  × 1 rep     [rest 2 min]
Set 7:  Bar+3×45    (315 lbs)  ← Working sets begin
```

**Example: Working weight = 135 lbs**
```
Set 1:  Bar          (45 lbs)  × 10 reps   [rest 60 sec]
Set 2:  Bar + 25s    (95 lbs)  × 5 reps    [rest 60 sec]
Set 3:  Bar + 45s   (135 lbs)  ← Working sets begin
```

Rules:
- Skip any warmup weight that is ≥ 90% of working weight (it becomes the working weight)
- Last warmup is always ≤ 90% of working weight
- Warmup sets never trigger set feedback (no adjustment system)

---

## 9. Rest Timer

- **Full-screen countdown** when a rest period starts
- Large circular ring (light blue stroke on dark track, animates clockwise → depletes)
- Time remaining in center (large, monospaced white digits)
- Below ring: next set preview in small text
- "End Rest Early" button always visible at bottom
- Haptic pulses: at 60 sec, 30 sec, and 10 sec remaining
- Local notification fires at 0 if app is backgrounded: "Rest over — next set ready"

**Rest durations by exercise:**
| Exercise | Between Working Sets | Between Warmup Sets |
|---|---|---|
| Squat | 3 min 30 sec | 60–90 sec |
| Deadlift | 4 min 30 sec | 60–90 sec |
| Bench Press | 3 min | 60 sec |
| Military Press | 2 min 30 sec | 60 sec |
| Lat Pulldown | 2 min | 45 sec |
| Cable Row | 2 min | 45 sec |
| Ab Wheel | 90 sec | N/A |

---

## 10. Cardio (Run) Details

**Start:** 1 mile, easy treadmill pace (Zone 2 — conversational, ~60–70% max HR)
**Logging per session:**
- Distance (miles, entered manually or via treadmill readout)
- Duration (min:sec — timer built in)
- Self-rated effort (RPE 1–10 slider)

**Progression:**
- Add 0.1 mile per session until 3 miles
- After 3 miles: weekly mileage increases max 10%
- Every 4th session (deload week): reduce to 60% of current distance

**What gets tracked:**
- Distance over time (chart)
- Pace per mile over time (chart — lower = better)
- Weekly mileage total (bar chart)
- Fastest pace PR, longest distance PR

---

## 11. Benchmark Test Days

Scheduled every **8 weeks** (end of 2 full 4-week cycles). The app replaces the
normal deload session with a guided benchmark test.

**What gets tested:** Squat, Bench Press, Deadlift, Military Press (in that order,
one session). Lat pulldown and cable row use submaximal rep tests only.

**In-App Protocol (guided, step by step):**
1. Standard warmup for the lift
2. 3 reps @ 80% of current e1RM → log
3. 4-minute rest
4. 1 rep @ 90% → log
5. 4-minute rest
6. Attempt new 1RM (app suggests: +5 lbs upper / +10–15 lbs lower based on feel of previous set)
7. Log final rep count and weight → new e1RM calculated and stored

**Benchmark records stored:**
- Date, exercise, weight, reps, e1RM, delta vs last benchmark (+/− shown in green/red)

**Benchmark History:** Vertical milestone timeline in Progress view. Tappable nodes
show full breakdown of that test day.

---

## 12. Data Model (Core Data)

```
User
  id, bodyWeightLbs (160.0), heightInches (69), programStartDate

Exercise
  id, name, type (barbell | cable | bodyweight | cardio)
  primaryMuscles[], restDurationSeconds, warmupStyle

ProgramBlock
  blockNumber, weekInBlock (1–4), isDeload, startDate, endDate

WorkoutSession
  id, date, status (planned | active | completed | skipped)
  sessionType (lowerA | upperA | lowerB | upperB | cardio)
  durationSeconds, sessionOrderIndex

SessionExercise
  session, exercise, order, targetSets, targetReps, targetWeightLbs

WarmupSet
  sessionExercise, setNumber, weightLbs, reps, restAfterSeconds, completed

WorkingSet
  sessionExercise, setNumber
  targetReps, actualReps, weightLbs
  completed (Bool), completionRating (strong | barely | failed)
  restTakenSeconds

AbWheelSet
  sessionExercise, setNumber, targetReps, actualReps, completed, restTakenSeconds

CardioSession
  date, distanceMiles, durationSeconds, paceMinsPerMile, rpeRating (1–10)

BodyWeightEntry
  date, weightLbs

BenchmarkEntry
  date, exercise, weightLbs, reps, estimatedOneRM, deltaVsPrevious

FatigueLog
  weekStartDate, exercise, failedSetCount, earlyDeloadSuggested
```

---

## 13. Screen Architecture

```
TabBar (bottom, 4 tabs):
  [  Home  ]  [  Workout  ]  [  Progress  ]  [  Profile  ]
```

---

### Tab 1 — Home

**What you see when you open the app:**

```
┌─────────────────────────────────────────┐
│  Good morning, Ray              Feb 21  │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │  NEXT UP                         │   │
│  │  Session 3 · Lower B             │   │
│  │  Deadlift                        │   │
│  │  Est. 45 min              [Start]│   │
│  └──────────────────────────────────┘   │
│                                         │
│  This week                              │
│  [S1 ✓] [S2 ✓] [S3 →] [S4 · ] [S5 · ] │
│                                         │
│  Week 2 of 4  ·  Loading Block          │
│  Next deload in 14 days                 │
│  Next benchmark in 54 days              │
│                                         │
│  Body weight    ↗ 160 lbs               │
│  Sets this week  18 of 28               │
└─────────────────────────────────────────┘
```

- The large "NEXT UP" card always reflects the next uncompleted session in order
- Sessions never skip — if you miss a day, the same session waits for you
- Week strip shows this cycle's 5 sessions with completion indicators
- Tapping a past session shows its summary

---

### Tab 2 — Workout (Active Session Flow)

**Step 0 — Session Preview**
```
┌─────────────────────────────────────────┐
│  Upper A                                │
│  Bench Press + Cable Row                │
│                                         │
│  Bench Press                            │
│  4 sets × 6 reps · 185 lbs             │
│  Bar + ██45×1 ██25×1 each side          │
│                                         │
│  Cable Row                              │
│  4 sets × 6 reps · 100 lbs             │
│  Cable pin weight                       │
│                                         │
│         [  Begin Session  ]             │
└─────────────────────────────────────────┘
```

**Step 1 — Warmup Card (per warmup set)**
```
┌─────────────────────────────────────────┐
│  BENCH PRESS — WARMUP                   │
│  Set 2 of 5                             │
│                                         │
│  95 lbs                                 │
│  Bar (45 lbs)                           │
│  + ██ 25  × 1  each side               │
│                                         │
│  5 reps                                 │
│                                         │
│  [  Done  ]                             │
└─────────────────────────────────────────┘
```
Rest timer (60 sec) slides in after "Done". Skippable.

**Step 2 — Working Set Card**
```
┌─────────────────────────────────────────┐
│  BENCH PRESS                            │
│  Set 2 of 4                             │
│                                         │
│            185 lbs                      │  ← large, 48pt SF Rounded
│                                         │
│  Bar (45 lbs)                           │
│  + ██ 45  × 1  each side               │
│  + ██ 25  × 1  each side               │
│                                         │
│  6 reps  ·  RPE target: 8              │
│                                         │
│  [  Complete Set  ]                     │
└─────────────────────────────────────────┘
```

**Step 3 — Set Feedback Sheet** (slides up from bottom)
```
┌─────────────────────────────────────────┐
│  Set 2 · 185 lbs × 6                    │
│                                         │
│  How did it go?                         │
│                                         │
│  [  💪  Yes, felt strong  ]             │
│  [  ✓   Yes, barely       ]             │
│  [  ✗   Missed reps       ]             │
│       Reps completed: [ − ][ 4 ][ + ]   │
└─────────────────────────────────────────┘
```

**Step 4 — Rest Timer (full screen)**
```
┌─────────────────────────────────────────┐
│                                         │
│              REST                       │
│                                         │
│         ┌──────────────┐                │
│         │   2:47       │   ← large mono │
│         │  ○○○○○○○○○   │   ← blue ring  │
│         └──────────────┘                │
│                                         │
│  Next: Set 3 · 185 lbs × 6             │
│                                         │
│         [ End Rest Early ]              │
└─────────────────────────────────────────┘
```

**Step 5 — Exercise Complete Transition**
- Subtle checkmark animation (blue → white pulse)
- "Bench Press — Done" + volume summary for that exercise
- Auto-advances to Cable Row warmup if applicable

**Step 6 — Session Complete**
```
┌─────────────────────────────────────────┐
│  Session Complete                       │
│  Upper A                                │
│                                         │
│  Duration    43 min                     │
│  Total vol   4,620 lbs                  │
│  Sets done   8 of 8                     │
│                                         │
│  Log body weight?                       │
│  [  ○○○  160  lbs  ○○○  ]              │
│  [ Save weight ]  [ Skip ]              │
│                                         │
│  [  View Progress  ]                    │
└─────────────────────────────────────────┘
```

---

### Tab 3 — Progress

**Lift selector (horizontal scroll tabs):**
```
[Squat] [Bench] [Deadlift] [OHP] [Lat Pull] [Row] [Ab Wheel] [Run]
```

**Per-lift view:**
```
┌─────────────────────────────────────────┐
│  Bench Press                            │
│  e1RM  218 lbs  ↑ +12 lbs this block   │
│                                         │
│   220 ┤                          ★      │  ← benchmark star
│   210 ┤              ·  ·  · ·  ╱       │  ← blue line
│   200 ┤     · ·  · ╱               │  gradient fill
│   190 ┤  ·╱                            │
│       └──────────────────────────────  │
│       Jan  Feb  Mar  Apr  May          │
│                                         │
│  [Weekly]  [Monthly]  [All Time]        │
│                                         │
│  Personal Records                       │
│  Best e1RM    218 lbs   Mar 14          │
│  Best set     195 × 5   Mar 10          │
└─────────────────────────────────────────┘
```

**Other metric cards (scroll down):**
1. Body Weight chart (same line chart style)
2. Weekly Volume bar chart (stacked, per session type)
3. Consistency heatmap (7×N grid, blue = completed, dark = rest, empty = missed)
4. Benchmark History (vertical timeline with delta labels)
5. Cardio: Distance line chart + Pace line chart + weekly mileage bars
6. Ab Wheel: Reps/set over time

All charts: black background, `#5AC8FA` lines, gradient fill under curve
(`#5AC8FA33` → transparent), subtle grid at `#2C2C2E`, white data point dots.
Dashed horizontal reference lines for PRs and milestones.

---

### Tab 4 — Profile

```
┌─────────────────────────────────────────┐
│  Ray                                    │
│  160 lbs  ·  5'9"  ·  Started Jan 1    │
│                                         │
│  PROGRAM STATUS                         │
│  Week 2 of 4  ·  Loading Block          │
│  Block 3 of ∞                           │
│                                         │
│  BODY WEIGHT                            │
│  [+ Log Weight]                         │
│  Feb 21  160.0 lbs                      │
│  Feb 18  160.5 lbs                      │
│  Feb 14  161.0 lbs                      │
│                                         │
│  BENCHMARKS                             │
│  Last test:  Jan 26                     │
│  Next test:  Mar 22 (in 29 days)        │
│  [  Run Benchmark Test Now  ]           │
│                                         │
│  SETTINGS                               │
│  Rest timer sounds       [  ON  ]       │
│  Rest timer haptics      [  ON  ]       │
│  Warmup auto-timer       [  ON  ]       │
└─────────────────────────────────────────┘
```

---

## 14. Visual Design System

### Color Tokens
```
Background Primary:    #000000   — OLED black (main screens)
Background Secondary:  #111111   — cards, bottom sheets
Background Tertiary:   #1C1C1E   — inputs, nested rows
Surface Elevated:      #2C2C2E   — modals, popovers

Text Primary:          #FFFFFF
Text Secondary:        #8E8E93   — SF System Gray
Text Tertiary:         #48484A   — labels, timestamps

Accent Blue:           #5AC8FA   — all interactive + metric elements
Accent Blue 33%:       #5AC8FA55 — chart fills
Accent Blue 10%:       #5AC8FA1A — subtle highlights

Success Green:         #30D158   — "felt strong" feedback
Warning Amber:         #FF9F0A   — "barely" feedback
Danger Red:            #FF453A   — "missed reps" feedback

Chart Line:            #5AC8FA
Chart Grid:            #2C2C2E
Chart Point:           #FFFFFF   — 6pt circle
Chart Fill:            #5AC8FA33 → transparent (gradient)
Milestone Dashes:      #5AC8FA66 — horizontal reference lines
```

### Plate Colors (color chips in weight display)
```
45 lb plate:    #D62828  (deep red)
35 lb plate:    #2B6CB0  (steel blue)
25 lb plate:    #D97706  (amber)
10 lb plate:    #2D6A4F  (forest green)
 5 lb plate:    #9CA3AF  (light grey)
2.5 lb plate:   #6B7280  (medium grey)
Bar:            #4B5563  (dark grey, always shown as "Bar · 45 lbs")
```

Plate chips: rounded rectangles, small (32×20pt), color background, white text weight label.
Format: `[██ 45 ×2]` — color chip, weight, ×count.

### Typography
```
Hero Weight:    SF Pro Rounded Bold, 52pt    — rest timer countdown
Large Number:   SF Pro Rounded Bold, 40pt    — working weight display
Title:          SF Pro Rounded Semibold, 22pt
Headline:       SF Pro Rounded Semibold, 17pt
Body:           SF Pro Regular, 16pt
Caption:        SF Pro Regular, 13pt
Plate Labels:   SF Pro Rounded Bold, 12pt    — on plate chips
Mono Numbers:   SF Mono Regular, 15pt        — pace, duration
```

### Core Components
```
Card
  background: #111111
  cornerRadius: 16
  padding: 20
  no visible border — uses depth not border

Primary Button
  background: #5AC8FA
  foreground: #000000 (black text on blue)
  height: 54, cornerRadius: 14
  SF Pro Rounded Semibold 17pt
  spring scale on press: 0.97 → 1.0

Secondary Button
  background: #2C2C2E
  foreground: #FFFFFF

Destructive / Missed
  background: #FF453A22
  foreground: #FF453A

Rest Timer Ring
  track: #2C2C2E, strokeWidth: 10
  progress: #5AC8FA, strokeWidth: 10, lineCap: .round
  animates counterclockwise as time depletes
  subtle glow on progress stroke (shadow, blur 8, #5AC8FA66)

Section Header
  Text Secondary (#8E8E93), 13pt, all caps, letter-spaced
  (Apple-style section divider look)
```

### Spacing & Layout
```
Screen edge margins: 20pt horizontal
Card gap: 12pt between cards
Internal card padding: 20pt
Tab bar: system height + safe area, ultraThinMaterial blur
Navigation bar: inline title, transparent background on scroll
```

---

## 15. Technical Architecture

```
IronLog.xcodeproj
├── App/
│   ├── IronLogApp.swift           (entry point, Core Data stack init)
│   └── ContentView.swift          (TabView: Home / Workout / Progress / Profile)
│
├── Core/
│   ├── Persistence/
│   │   ├── CoreDataStack.swift    (NSPersistentContainer singleton)
│   │   └── IronLog.xcdatamodeld  (all entities)
│   ├── Models/                    (NSManagedObject subclasses, auto-generated)
│   ├── Repositories/
│   │   ├── UserRepository.swift
│   │   ├── WorkoutRepository.swift
│   │   └── ProgressRepository.swift
│   └── Engine/
│       ├── ProgramEngine.swift         (session ordering, week/block logic)
│       ├── WarmupCalculator.swift      (plate math, warmup set generation)
│       ├── PlateCalculator.swift       (weight → plate breakdown display)
│       ├── ProgressionEngine.swift     (wave loading, weight targets)
│       ├── AdaptiveEngine.swift        (set feedback → weight adjustment)
│       ├── DeloadEngine.swift          (fatigue tracking, deload decisions)
│       ├── CardioEngine.swift          (run progression)
│       └── BenchmarkEngine.swift       (e1RM calc, benchmark scheduling)
│
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   ├── Workout/
│   │   ├── SessionPreviewView.swift
│   │   ├── WarmupView.swift
│   │   ├── WorkingSetView.swift
│   │   ├── SetFeedbackSheet.swift
│   │   ├── RestTimerView.swift
│   │   ├── ExerciseCompleteView.swift
│   │   ├── SessionCompleteView.swift
│   │   ├── CardioSessionView.swift
│   │   └── WorkoutViewModel.swift
│   ├── Progress/
│   │   ├── ProgressView.swift
│   │   ├── LiftProgressCard.swift
│   │   ├── BodyWeightCard.swift
│   │   ├── VolumeCard.swift
│   │   ├── ConsistencyHeatmap.swift
│   │   ├── BenchmarkTimeline.swift
│   │   ├── CardioProgressCard.swift
│   │   └── ProgressViewModel.swift
│   └── Profile/
│       ├── ProfileView.swift
│       ├── BodyWeightLogView.swift
│       └── ProfileViewModel.swift
│
├── Components/
│   ├── RestTimerRing.swift         (circular countdown ring)
│   ├── PlateChip.swift             (colored plate denomination chip)
│   ├── PlateBreakdownView.swift    (full plate display for a weight)
│   ├── IronButton.swift            (styled buttons)
│   ├── MetricLineChart.swift       (reusable chart component)
│   ├── SessionCard.swift           (home screen session card)
│   └── WeekStripView.swift         (session progress indicator)
│
└── Utilities/
    ├── Color+Iron.swift            (design token extensions)
    ├── Font+Iron.swift
    ├── HapticManager.swift
    ├── NotificationManager.swift   (rest timer background notifications)
    └── Formatters.swift            (weight, time, pace, date)
```

### Key Technical Notes
- **State management:** `@StateObject` ViewModels, Core Data `@FetchRequest` for lists
- **Active workout:** `WorkoutViewModel` is an `ObservableObject` that persists
  through app backgrounding via `@ScenePhase` observation. Session state is written
  to Core Data immediately on every action (crash-safe).
- **Rest timer:** `Timer.publish(every: 1, on: .main, in: .common)`, local notification
  scheduled at start of rest period (cancelled if user ends early).
- **Charts:** SwiftUI Charts framework (iOS 16+). Custom styling via `chartPlotStyle`,
  `chartXAxis`, `chartYAxis` modifiers.
- **Onboarding:** `@AppStorage("hasCompletedOnboarding")` gate on first launch.
- **No dependencies:** Zero third-party packages. Pure Apple frameworks only.

---

## 16. Onboarding Flow

**Screen 1 — Welcome**
- "IronLog" — large wordmark, white on black
- Subtitle: "Train smarter. Progress forever."
- [Get Started]

**Screen 2 — Profile**
- Name (optional text field)
- Body weight (scrolling number picker, lbs)
- Height (pre-filled 5'9", editable)

**Screen 3 — Starting Weights**
- "Enter the weight you can lift for a solid 5 reps."
- Per lift: number input with plate breakdown shown live as you type
- [Use conservative defaults] option fills in:
  ```
  Squat:          135 lbs
  Bench Press:    115 lbs
  Deadlift:       155 lbs
  Military Press:  75 lbs
  Lat Pulldown:   100 lbs
  Cable Row:      100 lbs
  Ab Wheel:       Bodyweight
  Run:            1.0 mile
  ```

**Screen 4 — Ready**
- Program overview card: split names, first session highlighted
- "Your first benchmark test is in 8 weeks."
- [Start Program] → sets Day 1, writes initial BodyWeightEntry, generates Session 1.

---

*Design document v2.0 — all questions answered. Ready for implementation.*
