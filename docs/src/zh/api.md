# API 参考

本页概览 `Parking` 的公开 API。下面列出的所有符号均由本包导出。

> 说明：本包的函数签名与详细文档（docstring）目前为英文，与代码中的注释保持一致，
> 因此逐符号的自动生成 API 文档统一在英文 [API Reference](api.md) 页面生成。
> 本节按主题给出中文说明，并列出对应符号名称，便于对照查阅。

## 车辆与几何

涉及车辆位形与几何的符号：`Vehicle`、`Pose`、`Rectangle`、`corners`、`footprint`、`rear_axle_pose`。
详细签名与说明见英文 [API Reference](api.md)。

## 环境与车位

符号：`ParkingSpot`、`spot_corners`、`Environment`、`inflate_rect`、`with_clearance`、`build_lot`。
见英文 [API Reference](api.md) 对应小节。

## 碰撞检测

符号：`is_collision`、`collision_reason`、`path_clear`。
见英文 [API Reference](api.md)。

## 规划

符号：`PlanResult`、`step_vehicle`、`plan_park`、`plan_leave`。
见英文 [API Reference](api.md)。

规划结果通过 `PlanResult` 返回。其 `status` 字段为下列 `PlanStatus` 之一：
`SUCCESS`、`NO_PATH_FOUND`、`START_IN_COLLISION` 或 `GOAL_IN_COLLISION`。
`reason` 字段包含对结果的可读描述，例如
`"start pose is in collision (not in a valid free space)"`。

## 仿真与路径细化

符号：`simulate`、`refine_path`、`Trajectory`、`duration`、`trajectory`。
见英文 [API Reference](api.md)。

## 可视化

绘图与动画由可选的扩展包提供，以保持核心包轻量：

- `ParkingPlots` - 当 `Plots` 在作用域中时自动加载，提供 `plot_scene`、`plot_pose!`、`plot_path!` 与 `animate_parking`。
- `ParkingMakie` - 当 `Makie`、`Bonito`、`WGLMakie` 在作用域中时自动加载，提供 `plot_scene!`、`makie_scene`、交互式 `designer`，并为 Makie `Axis` 实现 `plot_pose!` / `plot_path!`。

`plot_pose!` 与 `plot_path!` 与后端无关：其 `target` 为 `Plots.Plot`（Plots 后端）或 Makie `Axis`（Makie 后端）。
调用前请加载对应后端，例如 `using Parking, Plots` 或 `using Parking, Makie, Bonito, WGLMakie`。

符号：`plot_scene`、`plot_scene!`、`plot_pose!`、`plot_path!`、`makie_scene`、`animate_parking`、`designer`。
见英文 [API Reference](api.md)。
