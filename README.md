# Parking.jl

A Julia package for parking simulation and kinematic motion planning. The vehicle
uses a bicycle kinematic model (referenced at the **rear axle center**) and A* search
over the configuration space `(x, y, θ)` to find a collision-free path from an
arbitrary starting configuration into (or out of) a target parking spot.

## Quick start

```julia
using Pkg
Pkg.activate(".")
using Parking
```

Run an example:

```bash
julia --project=. docs/examples/three_rows_parking.jl
```

The GIF produced by an example is written to `docs/examples/results/`.

The same examples are also rendered as part of the documentation site (see
[docs/src/examples](docs/src/examples)).
