/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

`include "hvsync_generator.v"

module tt_um_Jo1673 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path: 0=input, 1=output
    input  wire       ena,      // Always 1 when powered
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset, active low
);

  // ------------------------------------------------------------
  // Tiny Tapeout input mapping
  // ------------------------------------------------------------
  //
  // ui_in[3:0] = selected square, values 0 to 8
  // ui_in[4]   = submit button
  // ui_in[5]   = extra reset, active high
  //
  // rst_n      = main reset, active low
  //
  // uo_out[0] = hsync
  // uo_out[1] = vsync
  // uo_out[2] = red
  // uo_out[3] = green
  // uo_out[4] = blue
  // uo_out[5] = X win
  // uo_out[6] = O win
  // uo_out[7] = draw

  wire reset;
  assign reset = ~rst_n | ui_in[5];

  wire [3:0] selected_square;
  assign selected_square = ui_in[3:0];

  wire submit_raw;
  assign submit_raw = ui_in[4];

  // ------------------------------------------------------------
  // VGA sync generator
  // ------------------------------------------------------------

  wire hsync;
  wire vsync;
  wire display_on;
  wire [8:0] hpos;
  wire [8:0] vpos;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(reset),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );

  // ------------------------------------------------------------
  // Submit edge detection
  // ------------------------------------------------------------

  reg submit_1;
  reg submit_2;
  reg submit_prev;

  wire submit_edge;

  assign submit_edge = submit_2 & ~submit_prev;

  always @(posedge clk) begin
    if (reset) begin
      submit_1 <= 1'b0;
      submit_2 <= 1'b0;
      submit_prev <= 1'b0;
    end else begin
      submit_1 <= submit_raw;
      submit_2 <= submit_1;
      submit_prev <= submit_2;
    end
  end

  // ------------------------------------------------------------
  // Game state
  // ------------------------------------------------------------

  reg [8:0] x_board;
  reg [8:0] o_board;

  // turn = 0 means X turn
  // turn = 1 means O turn
  reg turn;

  wire valid_sel;
  wire selected_empty;

  assign valid_sel = selected_square <= 4'd8;

  assign selected_empty =
    valid_sel &&
    !x_board[selected_square] &&
    !o_board[selected_square];

  wire x_win;
  wire o_win;
  wire board_full;
  wire draw;
  wire game_over;

  assign x_win = is_win(x_board);
  assign o_win = is_win(o_board);
  assign board_full = &(x_board | o_board);
  assign draw = board_full && !x_win && !o_win;
  assign game_over = x_win || o_win || draw;

  always @(posedge clk) begin
    if (reset) begin
      x_board <= 9'b000000000;
      o_board <= 9'b000000000;
      turn <= 1'b0;
    end else begin
      if (submit_edge && selected_empty && !game_over) begin
        if (turn == 1'b0) begin
          x_board[selected_square] <= 1'b1;
          turn <= 1'b1;
        end else begin
          o_board[selected_square] <= 1'b1;
          turn <= 1'b0;
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Win detection
  // ------------------------------------------------------------

  function is_win;
    input [8:0] b;
    begin
      is_win =
        // rows
        (b[0] & b[1] & b[2]) |
        (b[3] & b[4] & b[5]) |
        (b[6] & b[7] & b[8]) |

        // columns
        (b[0] & b[3] & b[6]) |
        (b[1] & b[4] & b[7]) |
        (b[2] & b[5] & b[8]) |

        // diagonals
        (b[0] & b[4] & b[8]) |
        (b[2] & b[4] & b[6]);
    end
  endfunction

  // ------------------------------------------------------------
  // Drawing constants
  // Display is 256 x 240
  // Board is 180 x 180
  // Each cell is 60 x 60
  // ------------------------------------------------------------

  localparam [8:0] BOARD_X = 9'd38;
  localparam [8:0] BOARD_Y = 9'd30;

  wire in_board;

  assign in_board =
    hpos >= BOARD_X &&
    hpos <  BOARD_X + 9'd180 &&
    vpos >= BOARD_Y &&
    vpos <  BOARD_Y + 9'd180;

  // ------------------------------------------------------------
  // Grid lines
  // ------------------------------------------------------------

  wire grid_pixel;

  assign grid_pixel =
    in_board &&
    (
      // vertical lines
      (hpos >= BOARD_X + 9'd60  && hpos <= BOARD_X + 9'd62)  ||
      (hpos >= BOARD_X + 9'd120 && hpos <= BOARD_X + 9'd122) ||

      // horizontal lines
      (vpos >= BOARD_Y + 9'd60  && vpos <= BOARD_Y + 9'd62)  ||
      (vpos >= BOARD_Y + 9'd120 && vpos <= BOARD_Y + 9'd122)
    );

  // ------------------------------------------------------------
  // X and O pixels
  // ------------------------------------------------------------

  wire x_pixel;
  wire o_pixel;

  assign x_pixel =
    (x_board[0] && draw_x(hpos, vpos, BOARD_X + 9'd0,   BOARD_Y + 9'd0))   ||
    (x_board[1] && draw_x(hpos, vpos, BOARD_X + 9'd60,  BOARD_Y + 9'd0))   ||
    (x_board[2] && draw_x(hpos, vpos, BOARD_X + 9'd120, BOARD_Y + 9'd0))   ||

    (x_board[3] && draw_x(hpos, vpos, BOARD_X + 9'd0,   BOARD_Y + 9'd60))  ||
    (x_board[4] && draw_x(hpos, vpos, BOARD_X + 9'd60,  BOARD_Y + 9'd60))  ||
    (x_board[5] && draw_x(hpos, vpos, BOARD_X + 9'd120, BOARD_Y + 9'd60))  ||

    (x_board[6] && draw_x(hpos, vpos, BOARD_X + 9'd0,   BOARD_Y + 9'd120)) ||
    (x_board[7] && draw_x(hpos, vpos, BOARD_X + 9'd60,  BOARD_Y + 9'd120)) ||
    (x_board[8] && draw_x(hpos, vpos, BOARD_X + 9'd120, BOARD_Y + 9'd120));

  assign o_pixel =
    (o_board[0] && draw_o(hpos, vpos, BOARD_X + 9'd0,   BOARD_Y + 9'd0))   ||
    (o_board[1] && draw_o(hpos, vpos, BOARD_X + 9'd60,  BOARD_Y + 9'd0))   ||
    (o_board[2] && draw_o(hpos, vpos, BOARD_X + 9'd120, BOARD_Y + 9'd0))   ||

    (o_board[3] && draw_o(hpos, vpos, BOARD_X + 9'd0,   BOARD_Y + 9'd60))  ||
    (o_board[4] && draw_o(hpos, vpos, BOARD_X + 9'd60,  BOARD_Y + 9'd60))  ||
    (o_board[5] && draw_o(hpos, vpos, BOARD_X + 9'd120, BOARD_Y + 9'd60))  ||

    (o_board[6] && draw_o(hpos, vpos, BOARD_X + 9'd0,   BOARD_Y + 9'd120)) ||
    (o_board[7] && draw_o(hpos, vpos, BOARD_X + 9'd60,  BOARD_Y + 9'd120)) ||
    (o_board[8] && draw_o(hpos, vpos, BOARD_X + 9'd120, BOARD_Y + 9'd120));

  // ------------------------------------------------------------
  // Selected square outline
  // ------------------------------------------------------------

  wire select_pixel;

  assign select_pixel =
    valid_sel &&
    (
      (selected_square == 4'd0 && draw_outline(hpos, vpos, BOARD_X + 9'd0,   BOARD_Y + 9'd0))   ||
      (selected_square == 4'd1 && draw_outline(hpos, vpos, BOARD_X + 9'd60,  BOARD_Y + 9'd0))   ||
      (selected_square == 4'd2 && draw_outline(hpos, vpos, BOARD_X + 9'd120, BOARD_Y + 9'd0))   ||

      (selected_square == 4'd3 && draw_outline(hpos, vpos, BOARD_X + 9'd0,   BOARD_Y + 9'd60))  ||
      (selected_square == 4'd4 && draw_outline(hpos, vpos, BOARD_X + 9'd60,  BOARD_Y + 9'd60))  ||
      (selected_square == 4'd5 && draw_outline(hpos, vpos, BOARD_X + 9'd120, BOARD_Y + 9'd60))  ||

      (selected_square == 4'd6 && draw_outline(hpos, vpos, BOARD_X + 9'd0,   BOARD_Y + 9'd120)) ||
      (selected_square == 4'd7 && draw_outline(hpos, vpos, BOARD_X + 9'd60,  BOARD_Y + 9'd120)) ||
      (selected_square == 4'd8 && draw_outline(hpos, vpos, BOARD_X + 9'd120, BOARD_Y + 9'd120))
    );

  // ------------------------------------------------------------
  // Border pixel
  // ------------------------------------------------------------

  wire border_pixel;

  assign border_pixel =
    display_on &&
    (
      hpos < 9'd4 ||
      hpos > 9'd251 ||
      vpos < 9'd4 ||
      vpos > 9'd235
    );

  // ------------------------------------------------------------
  // Drawing helper functions
  // ------------------------------------------------------------

  function draw_x;
    input [8:0] px;
    input [8:0] py;
    input [8:0] x0;
    input [8:0] y0;

    integer lx;
    integer ly;
    integer d1;
    integer d2;

    begin
      lx = {23'b0, px} - {23'b0, x0};
      ly = {23'b0, py} - {23'b0, y0};

      d1 = lx - ly;
      if (d1 < 0)
        d1 = -d1;

      d2 = lx + ly - 32'd60;
      if (d2 < 0)
        d2 = -d2;

      draw_x =
        lx >= 8  &&
        lx <= 52 &&
        ly >= 8  &&
        ly <= 52 &&
        (
          d1 <= 3 ||
          d2 <= 3
        );
    end
  endfunction

  // This O drawing avoids multiplication to make the design smaller
  // and more Tiny Tapeout friendly.
  function draw_o;
    input [8:0] px;
    input [8:0] py;
    input [8:0] x0;
    input [8:0] y0;

    integer lx;
    integer ly;

    begin
      lx = {23'b0, px} - {23'b0, x0};
      ly = {23'b0, py} - {23'b0, y0};

      draw_o =
        lx >= 10 &&
        lx <= 50 &&
        ly >= 10 &&
        ly <= 50 &&
        (
          // top and bottom of O
          ((ly >= 10 && ly <= 14) && (lx >= 18 && lx <= 42)) ||
          ((ly >= 46 && ly <= 50) && (lx >= 18 && lx <= 42)) ||

          // left and right of O
          ((lx >= 10 && lx <= 14) && (ly >= 18 && ly <= 42)) ||
          ((lx >= 46 && lx <= 50) && (ly >= 18 && ly <= 42))
        );
    end
  endfunction

  function draw_outline;
    input [8:0] px;
    input [8:0] py;
    input [8:0] x0;
    input [8:0] y0;

    integer lx;
    integer ly;

    begin
      lx = {23'b0, px} - {23'b0, x0};
      ly = {23'b0, py} - {23'b0, y0};

      draw_outline =
        lx >= 0  &&
        lx <  60 &&
        ly >= 0  &&
        ly <  60 &&
        (
          lx < 3  ||
          lx > 56 ||
          ly < 3  ||
          ly > 56
        );
    end
  endfunction

  // ------------------------------------------------------------
  // RGB generation
  // ------------------------------------------------------------

  reg red;
  reg green;
  reg blue;

  always @(*) begin
    red   = 1'b0;
    green = 1'b0;
    blue  = 1'b0;

    if (display_on) begin

      // Grid is white
      if (grid_pixel) begin
        red   = 1'b1;
        green = 1'b1;
        blue  = 1'b1;
      end

      // Selected square outline is yellow
      if (select_pixel && !game_over) begin
        red   = 1'b1;
        green = 1'b1;
        blue  = 1'b0;
      end

      // X is red
      if (x_pixel) begin
        red   = 1'b1;
        green = 1'b0;
        blue  = 1'b0;
      end

      // O is blue
      if (o_pixel) begin
        red   = 1'b0;
        green = 1'b0;
        blue  = 1'b1;
      end

      // Status border
      if (border_pixel) begin
        if (x_win) begin
          red   = 1'b1;
          green = 1'b0;
          blue  = 1'b0;
        end else if (o_win) begin
          red   = 1'b0;
          green = 1'b0;
          blue  = 1'b1;
        end else if (draw) begin
          red   = 1'b0;
          green = 1'b1;
          blue  = 1'b0;
        end else begin
          red   = 1'b1;
          green = 1'b1;
          blue  = 1'b0;
        end
      end
    end
  end

  // ------------------------------------------------------------
  // Tiny Tapeout output mapping
  // ------------------------------------------------------------

  assign uo_out[0] = hsync;
  assign uo_out[1] = vsync;
  assign uo_out[2] = red;
  assign uo_out[3] = green;
  assign uo_out[4] = blue;
  assign uo_out[5] = x_win;
  assign uo_out[6] = o_win;
  assign uo_out[7] = draw;

  // Use bidirectional pins as optional debug/status outputs
  assign uio_out[0] = turn;
  assign uio_out[1] = game_over;
  assign uio_out[2] = valid_sel;
  assign uio_out[3] = selected_empty;
  assign uio_out[4] = submit_2;
  assign uio_out[5] = x_win;
  assign uio_out[6] = o_win;
  assign uio_out[7] = draw;

  assign uio_oe = 8'b11111111;

  // List unused inputs to prevent warnings
  wire _unused;
  assign _unused = &{ena, uio_in, ui_in[7:6], 1'b0};

endmodule

`default_nettype wire
