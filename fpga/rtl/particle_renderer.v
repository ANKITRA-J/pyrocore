// Eight-particle fixed-point fireworks rasterizer. No framebuffer storage here.
// Caller must write pixel_* into its BACK buffer and honour busy/done.
// One previous-position trail pixel is drawn before each current head.
// Particle banks rotate once per particle, avoiding an eight-way state read mux.
module particle_renderer (
    input clk, input rst, input start, input launch, input clear,
    input [2:0] material, input [1:0] pattern,
    output reg busy, output reg done,
    output reg pixel_we, output reg [11:0] pixel_addr,
    output reg [2:0] pixel_data
);
    localparam IDLE=4'd0, CLEAR_FB=4'd1, DECIDE=4'd2, INIT=4'd3,
               READ=4'd4, STEP=4'd5, DRAW=4'd6, ADVANCE=4'd7, FINISH=4'd8, TRAIL=4'd9;
    reg [3:0] state;
    reg [11:0] clear_addr;
    reg [2:0] index;
    // Signed Q6.4 positions span -64..63.9375 pixels. Velocities are signed Q3.4.
    reg [87:0] xs, ys;
    reg [55:0] vxs, vys;
    reg [7:0] alive;
    reg [5:0] life;
    reg [2:0] active_material;
    reg launch_pending, clear_pending, frame_launch, frame_clear;
    reg [2:0] queued_material, frame_material;
    reg [1:0] queued_pattern, frame_pattern;
    reg signed [10:0] x, y, nx, ny;
    reg signed [6:0] vx, vy, nvy;
    reg particle_alive, draw_visible;
    reg [15:0] random_state;
    wire in_bounds = !nx[10] && !ny[10];
    wire [2:0] colour = active_material == 0 ? 3'd1 :
                        active_material == 1 ? 3'd2 :
                        active_material == 2 ? 3'd3 :
                        active_material == 3 ? 3'd4 :
                        active_material == 4 ? 3'd6 : 3'd7;

    reg signed [6:0] init_vx, init_vy;
    always @* begin
        // Ring: approximately equal speed around eight directions.
        case (index)
            0: begin init_vx=0;   init_vy=-32; end
            1: begin init_vx=23;  init_vy=-23; end
            2: begin init_vx=32;  init_vy=0;   end
            3: begin init_vx=23;  init_vy=23;  end
            4: begin init_vx=0;   init_vy=32;  end
            5: begin init_vx=-23; init_vy=23;  end
            6: begin init_vx=-32; init_vy=0;   end
            default: begin init_vx=-23; init_vy=-23; end
        endcase
        if (frame_pattern == 0) begin
            // Radial: alternating shorter spokes plus a small pseudorandom boost.
            if (index[0]) begin init_vx=init_vx >>> 1; init_vy=init_vy >>> 1; end
            if (random_state[0]) begin
                if (init_vx>0) init_vx=init_vx+7'sd2;
                else if (init_vx<0) init_vx=init_vx-7'sd2;
            end
        end else if (frame_pattern == 2) begin
            // Willow: upward fan launched from lower screen that gravity pulls down into falling arcs.
            case (index)
                0: init_vx=-14;
                1: init_vx=-10;
                2: init_vx=-6;
                3: init_vx=-2;
                4: init_vx=2;
                5: init_vx=6;
                6: init_vx=10;
                default: init_vx=14;
            endcase
            init_vy = index[0] ? -7'sd24 : -7'sd20;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            state<=IDLE; busy<=0; done<=0; pixel_we<=0;
            pixel_addr<=0; pixel_data<=0; clear_addr<=0; index<=0;
            alive<=0; life<=0; active_material<=0;
            launch_pending<=0; clear_pending<=0;
            frame_launch<=0; frame_clear<=0;
            queued_material<=0; queued_pattern<=0;
            frame_material<=0; frame_pattern<=0;
            // Position/velocity banks are not reset: alive=0 makes them irrelevant
            // until all eight records have been initialized by a launch.
            x<=0; y<=0; vx<=0; vy<=0; nx<=0; ny<=0; nvy<=0;
            particle_alive<=0; draw_visible<=0; random_state<=16'hACE1;
        end else begin
            done<=0;
            pixel_we<=0;
            random_state <= {random_state[14:0],random_state[15]^random_state[13]^random_state[12]^random_state[10]};
            if (launch) begin
                launch_pending<=1;
                queued_material<=material<6 ? material : 3'd0;
                queued_pattern<=pattern<3 ? pattern : 2'd0;
            end
            if (clear) begin clear_pending<=1; launch_pending<=0; end
            case (state)
                IDLE: if (start) begin
                    busy<=1; clear_addr<=0; state<=CLEAR_FB;
                    frame_clear<=clear_pending || clear;
                    frame_launch<=!(clear_pending || clear) && (launch_pending || launch);
                    frame_material<=launch ? (material<6 ? material : 3'd0) : queued_material;
                    frame_pattern<=launch ? (pattern<3 ? pattern : 2'd0) : queued_pattern;
                    launch_pending<=0; clear_pending<=0;
                end
                CLEAR_FB: begin
                    pixel_we<=1; pixel_addr<=clear_addr; pixel_data<=0;
                    clear_addr<=clear_addr+12'd1;
                    if (&clear_addr) state<=DECIDE;
                end
                DECIDE: begin
                    index<=0;
                    if (frame_clear) begin alive<=0; life<=0; state<=FINISH; end
                    else if (frame_launch) begin active_material<=frame_material; state<=INIT; end
                    else if (life!=0) begin life<=life-6'd1; state<=READ; end
                    else begin alive<=0; state<=FINISH; end
                end
                INIT: begin
                    xs<={11'd512,xs[87:11]};
                    ys<={frame_pattern==2'd2 ? 11'd640 : 11'd432,ys[87:11]};
                    vxs<={init_vx,vxs[55:7]};
                    vys<={init_vy,vys[55:7]};
                    alive<={1'b1,alive[7:1]};
                    index<=index+3'd1;
                    if (&index) begin life<=6'd48; index<=0; state<=READ; end
                end
                READ: begin
                    x<=xs[10:0]; y<=ys[10:0];
                    vx<=vxs[6:0]; vy<=vys[6:0];
                    particle_alive<=alive[0]; state<=STEP;
                end
                STEP: begin
                    nx <= x + {{4{vx[6]}},vx};
                    ny <= y + {{4{vy[6]}},vy};
                    nvy <= vy<7'sd60 ? vy+7'sd1 : vy;
                    state<=TRAIL;
                end
                TRAIL: begin
                    // Reuse the already captured old position: no history RAM.
                    // Cache visibility so an aluminium spark's head and tail
                    // flicker together even though the LFSR advances each cycle.
                    draw_visible <= particle_alive && in_bounds &&
                        !(active_material==4 && random_state[1:0]==0);
                    if (particle_alive && in_bounds &&
                        !(active_material==4 && random_state[1:0]==0)) begin
                        pixel_we<=1;
                        pixel_addr<={y[9:4],x[9:4]};
                        pixel_data<=colour;
                    end
                    state<=DRAW;
                end
                DRAW: begin
                    if (draw_visible) begin
                        pixel_we<=1;
                        pixel_addr<={ny[9:4],nx[9:4]};
                        pixel_data<=colour;
                    end
                    state<=ADVANCE;
                end
                ADVANCE: begin
                    xs<={nx,xs[87:11]}; ys<={ny,ys[87:11]};
                    vxs<={vx,vxs[55:7]}; vys<={nvy,vys[55:7]};
                    alive<={particle_alive && in_bounds,alive[7:1]};
                    index<=index+3'd1;
                    if (&index) state<=FINISH; else state<=READ;
                end
                FINISH: begin busy<=0; done<=1; state<=IDLE; end
                default: begin state<=IDLE; busy<=0; end
            endcase
        end
    end
endmodule
