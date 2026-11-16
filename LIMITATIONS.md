# Limitations and interpretation

### What the calculation estimates

The script models an idealised mechanical power requirement, **not** a direct measurement from a pedal power meter. Instantaneous values may overreact to GPS fluctuations. The model does not include rider acceleration, changing winds, exact road/tyre conditions, cornering, braking or energy losses not captured by the simple assumptions.

### Data noise

Differences of nearby GPS/elevation points can produce noisy grades and speeds, even when the real journey is smooth. For illustration, the original student team noted a 0.23 km difference between a raw computed ride distance and the Strava distance for one dataset. GPS jitter was one **possible explanation**, not an independently established cause.

### Projection and precision

The code assumes one UTM zone per GPX file, uses a truncated WGS84 projection series, and performs no rigorous survey adjustment or transformation-uncertainty analysis. Relative route plots should not be used for survey set-out or engineering design.

### Privacy and intellectual property

- Do **not** replace `synthetic_ride.gpx` with real cycling logs in a public repository without permission and location-risk review.
- Do **not** upload the assessed group source code, assessment brief, or screenshots/figures from the shared submission until you have confirmed appropriate permissions and university rules.
- The original work should always be credited to the team, not represented as an individual accomplishment.
