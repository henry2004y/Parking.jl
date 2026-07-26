# Examples

These pages document the package's example maneuvers. Each example builds an
environment, plans a parking (or leaving) maneuver with [`plan_park`](@ref) /
[`plan_leave`](@ref), and shows the resulting animation. The full, runnable source
is shown inline on each page.

The examples are:

- **[Three-row parking lot](three_rows_parking.md)** - generated 3×5 lot with a
  single free center spot; plan a perpendicular park-in through the lot.
- **[Perpendicular parking](perpendicular_parking.md)** - nose-in parking into a
  spot flanked by parked cars and a back wall.
- **[Perpendicular nose-out](perpendicular_nose_out.md)** - reverse-in / nose-out
  parking into the same constrained spot.
- **[Parallel parking](parallel_parking.md)** - parallel parking on a tight street,
  plus the reverse "pull out" problem.

The planned trajectories shown in this documentation are stored under `docs/src/figures/`.
