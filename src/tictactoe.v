`include "hvsync_generator.v"

module top(
  input clk,
  input reset,
  input [7:0] keycode,

  output keystrobe,
  output hsync,
  output vsync,
  output [2:0] rgb,

  output x_win_led,
  output o_win_led,
  output draw_led,
  output turn_led
);

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
  // Keyboard input for 8bitworkshop
  // ------------------------------------------------------------

  assign keystrobe = keycode[7];

  wire key_pressed;
  assign key_pressed = keycode[7];

  wire [6:0] key;
  assign key = keycode[6:0];

  reg key_pressed_prev;

  wire key_edge;
  assign key_edge = key_pressed && !key_pressed_prev;

  reg [3:0] selected_square;
  reg submit_key;

  always @(*) begin
    submit_key = 1'b0;
    selected_square = 4'd15;

    case (key)
      7'h31: begin selected_square = 4'd0; submit_key = 1'b1; end // 1
      7'h32: begin selected_square = 4'd1; submit_key = 1'b1; end // 2
      7'h33: begin selected_square = 4'd2; submit_key = 1'b1; end // 3

      7'h34: begin selected_square = 4'd3; submit_key = 1'b1; end // 4
      7'h35: begin selected_square = 4'd4; submit_key = 1'b1; end // 5
      7'h36: begin selected_square = 4'd5; submit_key = 1'b1; end // 6

      7'h37: begin selected_square = 4'd6; submit_key = 1'b1; end // 7
      7'h38: begin selected_square = 4'd7; submit_key = 1'b1; end // 8
      7'h39: begin selected_square = 4'd8; submit_key = 1'b1; end // 9

      default: begin selected_square = 4'd15; submit_key = 1'b0; end
    endcase
  end

  // ------------------------------------------------------------
  // Game state
  // ------------------------------------------------------------

  reg [8:0] x_board;
  reg [8:0] o_board;

  // turn = 0 means X's turn
  // turn = 1 means O's turn
  reg turn;

  wire submit_edge;
  assign submit_edge = key_edge && submit_key;

  wire valid_sel;
  assign valid_sel = selected_square <= 4'd8;

  wire selected_empty;
  assign selected_empty =
    valid_sel &&
    !x_board[selected_square] &&
    !o_board[selected_square];

  wire x_win;
  wire o_win;
  wire board_full;
  wire game_over;
  wire draw;

  assign x_win = is_win(x_board);
  assign o_win = is_win(o_board);
  assign board_full = &(x_board | o_board);
  assign draw = board_full && !x_win && !o_win;
  assign game_over = x_win || o_win || draw;

  assign x_win_led = x_win;
  assign o_win_led = o_win;
  assign draw_led = draw;
  assign turn_led = turn;

  always @(posedge clk) begin
    if (reset || (key_pressed && (key == 7'h52 || key == 7'h72))) begin
      key_pressed_prev <= 1'b0;

      x_board <= 9'b000000000;
      o_board <= 9'b000000000;
      turn <= 1'b0;
    end else begin
      key_pressed_prev <= key_pressed;

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

  localparam BOARD_X = 38;
  localparam BOARD_Y = 30;
  localparam CELL    = 60;

  wire in_board;
  assign in_board =
    hpos >= BOARD_X &&
    hpos <  BOARD_X + 180 &&
    vpos >= BOARD_Y &&
    vpos <  BOARD_Y + 180;

  wire grid_pixel;

  assign grid_pixel =
    in_board &&
    (
      // vertical grid lines
      (hpos >= BOARD_X + 60  && hpos <= BOARD_X + 62)  ||
      (hpos >= BOARD_X + 120 && hpos <= BOARD_X + 122) ||

      // horizontal grid lines
      (vpos >= BOARD_Y + 60  && vpos <= BOARD_Y + 62)  ||
      (vpos >= BOARD_Y + 120 && vpos <= BOARD_Y + 122)
    );

  // ------------------------------------------------------------
  // Draw X and O marks
  // ------------------------------------------------------------

  wire x_pixel;
  wire o_pixel;

  assign x_pixel =
    (x_board[0] && draw_x(hpos, vpos, BOARD_X + 0,   BOARD_Y + 0))   ||
    (x_board[1] && draw_x(hpos, vpos, BOARD_X + 60,  BOARD_Y + 0))   ||
    (x_board[2] && draw_x(hpos, vpos, BOARD_X + 120, BOARD_Y + 0))   ||

    (x_board[3] && draw_x(hpos, vpos, BOARD_X + 0,   BOARD_Y + 60))  ||
    (x_board[4] && draw_x(hpos, vpos, BOARD_X + 60,  BOARD_Y + 60))  ||
    (x_board[5] && draw_x(hpos, vpos, BOARD_X + 120, BOARD_Y + 60))  ||

    (x_board[6] && draw_x(hpos, vpos, BOARD_X + 0,   BOARD_Y + 120)) ||
    (x_board[7] && draw_x(hpos, vpos, BOARD_X + 60,  BOARD_Y + 120)) ||
    (x_board[8] && draw_x(hpos, vpos, BOARD_X + 120, BOARD_Y + 120));

  assign o_pixel =
    (o_board[0] && draw_o(hpos, vpos, BOARD_X + 0,   BOARD_Y + 0))   ||
    (o_board[1] && draw_o(hpos, vpos, BOARD_X + 60,  BOARD_Y + 0))   ||
    (o_board[2] && draw_o(hpos, vpos, BOARD_X + 120, BOARD_Y + 0))   ||

    (o_board[3] && draw_o(hpos, vpos, BOARD_X + 0,   BOARD_Y + 60))  ||
    (o_board[4] && draw_o(hpos, vpos, BOARD_X + 60,  BOARD_Y + 60))  ||
    (o_board[5] && draw_o(hpos, vpos, BOARD_X + 120, BOARD_Y + 60))  ||

    (o_board[6] && draw_o(hpos, vpos, BOARD_X + 0,   BOARD_Y + 120)) ||
    (o_board[7] && draw_o(hpos, vpos, BOARD_X + 60,  BOARD_Y + 120)) ||
    (o_board[8] && draw_o(hpos, vpos, BOARD_X + 120, BOARD_Y + 120));

  // ------------------------------------------------------------
  // Selected square outline
  // ------------------------------------------------------------

  wire select_pixel;

  assign select_pixel =
    valid_sel &&
    (
      (selected_square == 4'd0 && draw_outline(hpos, vpos, BOARD_X + 0,   BOARD_Y + 0))   ||
      (selected_square == 4'd1 && draw_outline(hpos, vpos, BOARD_X + 60,  BOARD_Y + 0))   ||
      (selected_square == 4'd2 && draw_outline(hpos, vpos, BOARD_X + 120, BOARD_Y + 0))   ||

      (selected_square == 4'd3 && draw_outline(hpos, vpos, BOARD_X + 0,   BOARD_Y + 60))  ||
      (selected_square == 4'd4 && draw_outline(hpos, vpos, BOARD_X + 60,  BOARD_Y + 60))  ||
      (selected_square == 4'd5 && draw_outline(hpos, vpos, BOARD_X + 120, BOARD_Y + 60))  ||

      (selected_square == 4'd6 && draw_outline(hpos, vpos, BOARD_X + 0,   BOARD_Y + 120)) ||
      (selected_square == 4'd7 && draw_outline(hpos, vpos, BOARD_X + 60,  BOARD_Y + 120)) ||
      (selected_square == 4'd8 && draw_outline(hpos, vpos, BOARD_X + 120, BOARD_Y + 120))
    );

  // ------------------------------------------------------------
  // Status border
  // Red border    = X won
  // Blue border   = O won
  // Green border  = draw
  // Yellow border = game ongoing
  // ------------------------------------------------------------

  wire border_pixel;

  assign border_pixel =
    display_on &&
    (
      hpos < 4 ||
      hpos > 251 ||
      vpos < 4 ||
      vpos > 235
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

      d2 = lx + ly - 60;
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

  function draw_o;
    input [8:0] px;
    input [8:0] py;
    input [8:0] x0;
    input [8:0] y0;

    integer lx;
    integer ly;
    integer cx;
    integer cy;
    integer dist2;

    begin
      lx = {23'b0, px} - {23'b0, x0};
      ly = {23'b0, py} - {23'b0, y0};

      cx = lx - 30;
      cy = ly - 30;

      dist2 = cx * cx + cy * cy;

      draw_o =
        lx >= 5 &&
        lx <= 55 &&
        ly >= 5 &&
        ly <= 55 &&
        dist2 >= 360 &&
        dist2 <= 625;
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
  // RGB color generation
  // rgb = {blue, green, red}
  // ------------------------------------------------------------

  reg r;
  reg g;
  reg b;

  always @(*) begin
    r = 1'b0;
    g = 1'b0;
    b = 1'b0;

    if (display_on) begin

      // Grid is white
      if (grid_pixel) begin
        r = 1'b1;
        g = 1'b1;
        b = 1'b1;
      end

      // Selected square outline is yellow
      if (select_pixel && !game_over) begin
        r = 1'b1;
        g = 1'b1;
        b = 1'b0;
      end

      // X is red
      if (x_pixel) begin
        r = 1'b1;
        g = 1'b0;
        b = 1'b0;
      end

      // O is blue
      if (o_pixel) begin
        r = 1'b0;
        g = 1'b0;
        b = 1'b1;
      end

      // Status border
      if (border_pixel) begin
        if (x_win) begin
          r = 1'b1;
          g = 1'b0;
          b = 1'b0;
        end else if (o_win) begin
          r = 1'b0;
          g = 1'b0;
          b = 1'b1;
        end else if (draw) begin
          r = 1'b0;
          g = 1'b1;
          b = 1'b0;
        end else begin
          r = 1'b1;
          g = 1'b1;
          b = 1'b0;
        end
      end
    end
  end

  assign rgb = {b, g, r};

endmodule