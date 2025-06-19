module control_FSM (
    input clk,
    input rst,
    input N_equal_0, N0_equal_1, Count_equal_4,
    output reg NMUX, CountMUX, NLoad, CountLoad, OutputMUX, OE,
    output reg [2:0] state_debug   // <<< 调试端口
);

    // 状态编码
    parameter S0 = 0;  // IDLE
    parameter S1 = 1;  // LOAD
    parameter S2 = 2;  // CHECK
    parameter S3 = 3;  // SHIFT
    parameter S4 = 4;  // TEST
    parameter S5 = 5;  // OUTPUT

    reg [2:0] state, next_state;

    // 状态转移
    always @(*) begin
        case (state)
            S0: next_state = S1;
            S1: next_state = S2;
            S2: next_state = S3;
            S3: next_state = S4;
            S4: next_state = N_equal_0 ? S5 : S2;
            S5: next_state = S0;
            default: next_state = S0;
        endcase
    end

    // 状态寄存器 + 调试输出
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= S0;
        else
            state <= next_state;

        state_debug <= state;
    end

    // 控制输出逻辑
    always @(*) begin
        NMUX = 0;
        CountMUX = 0;
        NLoad = 0;
        CountLoad = 0;
        OutputMUX = 0;
        OE = 0;

        case (state)
            S0: begin
                NMUX = 1;
                CountMUX = 1;
                NLoad = 1;
                CountLoad = 1;
            end
            S1: begin
                NMUX = 1;
                NLoad = 1;
            end
            S2: begin
                CountMUX = N0_equal_1 ? 1 : 0;
                CountLoad = 1;
            end
            S3: begin
                NMUX = 0;
                NLoad = 1;
            end
            S5: begin
                OutputMUX = Count_equal_4 ? 1 : 0;
                OE = 1;
            end
        endcase
    end

endmodule
module datapath (
    input clk,
    input rst,
    input NMUX,
    input CountMUX,
    input NLoad,
    input CountLoad,
    input [7:0] DataIn,
    output N_equal_0,
    output N0_equal_1,
    output Count_equal_4,
    output reg Out
);

    reg [7:0] N_reg;
    reg [2:0] Count;

    wire [7:0] N_next;
    wire [2:0] Count_next;

    // 移位或加载数据选择
    assign N_next = NMUX ? DataIn : {1'b0, N_reg[7:1]};
    assign Count_next = CountMUX ? Count + 1 : Count;

    // N寄存器
    always @(posedge clk or posedge rst) begin
        if (rst)
            N_reg <= 8'd0;
        else if (NLoad)
            N_reg <= N_next;
    end

    // Count寄存器
    always @(posedge clk or posedge rst) begin
        if (rst)
            Count <= 3'd0;
        else if (CountLoad)
            Count <= Count_next;
    end

    // 结果寄存器（可选使用）
    always @(posedge clk or posedge rst) begin
        if (rst)
            Out <= 0;
        // Out 在 top 中不使用此值，因此可空
    end

    // 输出信号
    assign N_equal_0 = (N_reg == 8'd0);
    assign N0_equal_1 = N_reg[0];
    assign Count_equal_4 = (Count == 3'd4);

endmodule

module top (
    input clk,
    input rst,
    input [7:0] sw,
    input start,
    output reg LED,

    // <<< 调试信号输出 >>>
    output wire [2:0] FSM_state,
    output wire OE_debug,
    output wire OutputMUX_debug,
    output wire Count_equal_4_debug
);

    // 控制信号连线
    wire NMUX, CountMUX, NLoad, CountLoad, OutputMUX, OE;
    wire N_equal_0, N0_equal_1, Count_equal_4;
    wire [7:0] DataIn;
    wire Out_wire;

    assign DataIn = sw;

    // FSM 实例
    control_FSM FSM_inst (
        .clk(clk),
        .rst(rst),
        .N_equal_0(N_equal_0),
        .N0_equal_1(N0_equal_1),
        .Count_equal_4(Count_equal_4),
        .NMUX(NMUX),
        .CountMUX(CountMUX),
        .NLoad(NLoad),
        .CountLoad(CountLoad),
        .OutputMUX(OutputMUX),
        .OE(OE),

        // 调试输出
        .state_debug(FSM_state)
    );

    // 数据通路实例
    datapath datapath_inst (
        .clk(clk),
        .rst(rst),
        .NMUX(NMUX),
        .CountMUX(CountMUX),
        .NLoad(NLoad),
        .CountLoad(CountLoad),
        .DataIn(DataIn),
        .N_equal_0(N_equal_0),
        .N0_equal_1(N0_equal_1),
        .Count_equal_4(Count_equal_4),
        .Out(Out_wire)
    );

    // LED 输出逻辑（受控于 FSM）
 // 记录状态用于 LED 输出时机判断
    reg [2:0] state_reg;
    always @(posedge clk or posedge rst) begin
        if (rst)
            state_reg <= 0;
        else
            state_reg <= FSM_state;
    end
    
    // LED 输出（最终稳定版本）
    always @(posedge clk or posedge rst) begin
        if (rst)
            LED <= 0;
        else if (state_reg == 3'd5)  // S5 输出状态
            LED <= (Count_equal_4_debug) ? 1'b1 : 1'b0;
    end

    


    // 调试信号输出
    assign OE_debug = OE;
    assign OutputMUX_debug = OutputMUX;
    assign Count_equal_4_debug = Count_equal_4;

endmodule
