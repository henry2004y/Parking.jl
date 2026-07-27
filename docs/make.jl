using Pkg

# Make the parent package (Parking) available to the docs environment.
Pkg.develop(PackageSpec(path = joinpath(@__DIR__, "..")))
Pkg.activate(@__DIR__)
Pkg.instantiate()

using Documenter
using DocumenterVitepress
using Parking

DocMeta.setdocmeta!(
    Parking,
    :DocTestSetup,
    :(using Parking);
    recursive = true,
)

# The documentation is bilingual. English lives at the repository root under
# `docs/src/`; the Chinese translation lives under `docs/src/zh/`. A single
# `makedocs` call builds both page trees, exposed as the "English" and "中文"
# top-level sections of the sidebar. This keeps both languages in one site and
# one deploy, and is the simplest robust setup for Documenter + DocumenterVitepress.
#
# To add or update a page, edit the matching file in BOTH `docs/src/` (English)
# and `docs/src/zh/` (Chinese) so the two languages stay in sync.
makedocs(;
    sitename = "Parking.jl",
    authors = "Parking contributors",
    format = DocumenterVitepress.MarkdownVitepress(;
        repo = "github.com/henry2004y/Parking.jl",
        devbranch = "main",
        devurl = "dev",
    ),
    modules = [Parking],
    pages = [
        "English" => [
            "Home" => "index.md",
            "Scene planner" => "scene_planner.md",
            "Walkthrough" => "walkthrough.md",
            "Examples" => [
                "examples/index.md",
                "examples/three_rows_parking.md",
                "examples/perpendicular_parking.md",
                "examples/perpendicular_nose_out.md",
                "examples/parallel_parking.md",
            ],
            "API Reference" => "api.md",
        ],
        "中文" => [
            "首页" => "zh/index.md",
            "场景规划" => "zh/scene_planner.md",
            "完整流程" => "zh/walkthrough.md",
            "示例" => [
                "zh/examples/index.md",
                "zh/examples/three_rows_parking.md",
                "zh/examples/perpendicular_parking.md",
                "zh/examples/perpendicular_nose_out.md",
                "zh/examples/parallel_parking.md",
            ],
            "API 参考" => "zh/api.md",
        ],
    ],
    checkdocs = :warn,
    clean = true,
)

DocumenterVitepress.deploydocs(;
    repo = "github.com/henry2004y/Parking.jl",
    target = joinpath(@__DIR__, "build"),
    branch = "gh-pages",
    devbranch = "main",
    push_preview = true,
)
