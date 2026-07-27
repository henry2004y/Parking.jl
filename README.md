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

## Development

Because the plotting backends are loaded as
[extensions](https://pkgdocs.julialang.org/dev/extensions/), they must live in the
*same* active environment as `Parking` to be picked up. Working in place on the
repository itself is therefore a bit tricky, and it can also clash with the
environments of your other packages. The recommended workflow is to create a
dedicated package environment for developing or using this package.

> **Caveat:** `Parking` does *not* directly depend on the plotting packages; it only
> works together with them through package extensions. As a result, simply activating
> the local package (e.g. `Pkg.activate(".")` inside the repository) is *not* enough to
> trigger the extension, because the backends are absent from that environment. We fell
> into this trap while testing the extensions: the plotting functions were silently
> unavailable until we added the backends to the same environment.

### 1. Create a dedicated environment

```bash
mkdir parking_dev
cd parking_dev
julia --project=.
```

Then, inside Julia, add `Parking` together with the plotting packages you need.

### 2a. For usage (released copy)

Use `Pkg.add` with the repository URL to install the online version:

```julia
using Pkg
Pkg.add(url = "https://github.com/henry2004y/Parking.jl")
Pkg.add("Plots")
Pkg.add("WGLMakie")
```

### 2b. For development (local copy)

Use `Pkg.develop` so Julia links the local repository in place. Changes to the source
are picked up without reinstalling:

```julia
using Pkg
Pkg.develop(path = "..")   # path to the local Parking.jl repository
Pkg.add("Plots")           # Plots.jl backend
Pkg.add("WGLMakie")        # Makie + Bonito interactive designer
```

In either case the plotting functions (`plot_scene`, `plot_pose!`, `plot_path!`, and the
Makie/Bonito designer) become available as soon as the corresponding backend is in this
environment.

Note that `parking_dev/` is git-ignored and is not part of the package, so you can keep
your working environment there without polluting the repository.

## Authors

This package was initiated by Hongyang Zhou and implemented by Tecent-Hunyuan/Hy3.
