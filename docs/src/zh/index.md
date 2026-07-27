# Parking.jl

Parking 是一个用 Julia 编写的软件包，用于模拟与规划运动学自行车模型车辆的停车动作。它提供了一套精简、自包含的工具，用于：

- 描述车辆、其位形（pose）与占用轮廓（footprint）；
- 构建包含车位与障碍的停车场环境；
- 进行碰撞检测与安全距离（clearance）计算；
- 基于运动基元（motion primitive）的 A* 搜索，规划垂直与平行泊车（以及驶离）动作；
- 对规划得到的轨迹进行仿真与动画演示。

规划器在离散的 (x, y, θ) 网格上用 A* 搜索一组离散的运动基元，随后对路径进行细化，使车辆能够平滑地跟踪。

## 安装

通过仓库地址添加本包：

```julia
using Pkg
Pkg.add(url = "https://github.com/henry2004y/Parking.jl")
```

本文档本身依赖 [Documenter](https://github.com/JuliaDocs/Documenter.jl)
与 [DocumenterVitepress](https://github.com/LuxDL/DocumenterVitepress.jl)。

## 快速开始

```julia
using Parking

# 构建一个简单的空旷停车场（返回环境与默认车辆）
env, vehicle = build_lot()

# 以几何中心定义起始位形；plan_park 会将其换算为内部使用的后轴中心位形。
start = Pose(6.0, 0.0, 0.0)

# 规划泊入停车场中的空车位。
res = plan_park(vehicle, env, start; clearance = 0.15)
if res.status == SUCCESS
    path = res.path                       # 后轴中心位形序列
    println("找到一条包含 $(length(path)) 个位形的路径。")
end
```

## 目录

- **[首页](index.md)** - 本页。
- **[场景规划](scene_planner.md)** - 用代码或交互式工具规划。
- **[完整流程](walkthrough.md)** - 带代码的端到端示例。
- **[示例](examples/index.md)** - 可运行的示例。
- **[API 参考](api.md)** - 完整的公开 API。

## 下一步

前往 [示例](examples/index.md) 查看完整、可运行的脚本，或浏览
[API 参考](api.md) 了解每个导出函数的细节。English version: [Home](index.md).
