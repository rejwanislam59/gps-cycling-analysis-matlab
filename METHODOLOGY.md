# Methodology

## 1. Data acquisition and parsing

The source file is a **fictitious** GPX 1.1 route (`data/synthetic_ride.gpx`), with latitude and longitude in decimal degrees, elevation in metres and UTC timestamps. The script uses low-level `fopen`, `fgetl` and `fclose` plus regular expressions to extract track points. The parser handles conventional GPX lines, but is not a complete XML parser.

## 2. Projected coordinates

The code converts WGS84 geographic coordinates to UTM Easting and Northing in metres using standard series formulae. It subtracts the first Easting/Northing, so the trajectory starts at relative (0,0). The example requires all points to be in the same UTM zone.

## 3. Kinematics

For consecutive samples, horizontal movement is `sqrt(ΔE² + ΔN²)` metres. The three-dimensional movement is `sqrt(ΔE² + ΔN² + Δelevation²)` metres. Cumulative 3D distance is the running sum. Point speed is segment length divided by the time step; km/h is m/s multiplied by 3.6. Elevation grade is 100 × Δelevation / horizontal movement, when horizontal movement is large enough for a stable ratio.

## 4. Modelled forces and power

The toy model uses **assumed** rider mass 80 kg, bike mass 14 kg, rolling coefficient 0.0253, aerodynamic drag area (CdA) 0.408 m², air density 1.225 kg/m³ and 3% drivetrain loss. Forces are:

- Along-slope gravity: `(rider + bicycle mass) × g × sin(arctan(grade/100))`
- Rolling resistance: `(rider + bicycle mass) × g × Crr × cos(arctan(grade/100))`
- Aerodynamic drag: `0.5 × air density × CdA × speed²` (assumed still air)

The non-negative modelled propulsion power estimate is `max(0, (F_gravity + F_rolling + F_drag) × speed / (1 − loss))` in watts. The zero floor is a modelling choice for downhill coasting, not a statement that negative mechanical work never occurs.

## 5. Energy integral

Trapezoidal integration estimates cumulative energy over the ride: `E_i = E_{i-1} + 0.5 × (P_i + P_{i-1}) × Δt_i` in joules. A graph displays power and cumulative energy on separate vertical axes.

## 6. Validation status

Three original GPX files were inspected privately; they are **not contained** here. A Python reference check found close agreement between the assessed team's UTM coordinates and standard projected coordinates for those rides. The newly written public MATLAB demonstration has **not been executed in MATLAB** in this environment. Python generated the *synthetic preview* graphs using comparable calculations. Users should run the MATLAB code and confirm outputs locally.
