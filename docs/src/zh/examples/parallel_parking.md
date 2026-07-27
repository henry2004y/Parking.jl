# 平行泊车

在狭窄街道上平行泊车。示例通过 `parallel_parking` 在两侧已停放车辆与路缘之间构建一个路边车位，然后用 [`plan_park`](@ref) 规划泊入路径。关于反向问题（驶离车位），可参考 [垂直泊车（车头朝外）](perpendicular_nose_out.md) 中 [`plan_leave`](@ref) 的用法。

完整源码：

```julia
# 平行泊车示例
# 规划一条驶入路边车位的平行泊车路径，并将结果动画演示。

using Parking
using Plots

# 1. 构建场景
env, vehicle = parallel_parking()

# 2. 设置起始位形：位于车道上、车位前方
start = Pose(4.0, 1.6, 0.0)

# 3. 规划
res = plan_park(vehicle, env, start; clearance = 0.15)
println("状态：", res.status)
println("路径长度：", length(res.path))

# 4. 绘制与动画
plt = plot_scene(env, vehicle)
plt = plot_path!(plt, res.path; vehicle = vehicle)
display(plt)
filename = animate_parking(env, vehicle, res.path; fps = 10,
                            filename = "parallel_parking.gif")
println("动画已保存至：", filename)
```

规划动作的预生成动画如下：

![平行泊车动画](../../figures/parallel_park.gif)
