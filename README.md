# Parking.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://henry2004y.github.io/Parking.jl/dev)
[![Coverage](https://codecov.io/gh/henry2004y/Parking.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/henry2004y/Parking.jl)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Julia package for parking simulation and kinematic motion planning. The vehicle
uses a bicycle kinematic model (referenced at the **rear axle center**) and A* search
over the configuration space `(x, y, θ)` to find a collision-free path from an
arbitrary starting configuration into (or out of) a target parking spot.

## Installation

Add the package from the repository:

```julia
using Pkg
Pkg.add(url = "https://github.com/henry2004y/Parking.jl")
```

Then load it:

```julia
using Parking
```

## Quick start

Run an example:

```bash
julia --project=. docs/examples/three_rows_parking.jl
```

The GIF produced by an example is written to `docs/examples/results/`.

## Documentation

For more detailed information on the API and usage, please refer to the [documentation](https://henry2004y.github.io/Parking.jl/).
