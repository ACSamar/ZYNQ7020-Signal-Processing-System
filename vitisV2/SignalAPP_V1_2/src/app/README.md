# 应用层代码结构

## 文件职责

1. `app.c` 负责采集、分析、稳定结果跟踪、命令处理和模块调度。
2. `g_display.c` 负责参数文本、题目模式、视图状态和刷新时机。
3. `g_display_graph.c` 负责波形重建、频谱谱线、坐标刻度、曲线传输和绘图变化判定。
4. `g_display.h` 定义显示模块对外接口及显示状态。
5. `g_display_graph.h` 定义界面调度层调用的绘图接口。
6. `g_question_mode.h` 负责题目小问、页面名称和增益档位映射。
7. `g_amplitude_calibration.h` 负责不同增益档位的幅值校准。
8. `g_measurement_config.h` 保存采集规模、输入通道和检测门限等应用配置。

## 状态划分

`GDisplay` 保存页面、视图、参数刷新计数和保持状态。绘图缓存统一放在 `GDisplayGraphState` 中，包括上次绘图结果、坐标量程和 800 点曲线缓冲区。页面状态与绘图缓存分组后，修改坐标或谱线绘制时无需改动刷新调度逻辑。

## 命名约定

1. 变量名明确包含对象和单位，例如 `frequency_hz_x100`、`voltage_step_uv`。
2. 分量循环统一使用 `component_index`，曲线采样位置统一使用 `curve_index` 或 `sample_index`。
3. 分析器当前帧使用 `g_analyzer_candidate`，稳定输出使用 `g_stable_result`。
4. ADC 原始统计统一放在 `AdcCaptureStatistics` 中，字段名称包含 `code`，避免与校准后的电压值混淆。
5. 返回状态根据作用命名，例如 `analysis_status`、`result_tracker_status` 和 `draw_status`。
