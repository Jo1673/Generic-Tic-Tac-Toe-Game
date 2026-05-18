# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


# Tiny Tapeout pin mapping for this project:
# ui_in[3:0] = square select, 0 through 8
# ui_in[4]   = submit move
# ui_in[5]   = game reset, active high
#
# uo_out[0] = hsync
# uo_out[1] = vsync
# uo_out[2] = red
# uo_out[3] = green
# uo_out[4] = blue
# uo_out[5] = X win
# uo_out[6] = O win
# uo_out[7] = draw
#
# uio_out[0] = current turn, 0 = X, 1 = O
# uio_out[1] = game over
# uio_out[2] = valid square selected
# uio_out[3] = selected square is empty
# uio_out[4] = synchronized submit signal
# uio_out[5] = X win debug
# uio_out[6] = O win debug
# uio_out[7] = draw debug


SUBMIT_BIT = 4
RESET_BIT = 5


def bit(value, index):
    """Return one bit from a cocotb value."""
    return (int(value) >> index) & 1


def make_ui(square=0, submit=0, reset=0):
    """Build ui_in from square select, submit, and reset."""
    return (square & 0xF) | ((submit & 1) << SUBMIT_BIT) | ((reset & 1) << RESET_BIT)


async def reset_design(dut):
    """Reset the design through rst_n and clear all input pins."""
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)

    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)


async def submit_move(dut, square):
    """Select a square and pulse submit long enough for the synchronizer."""
    dut.ui_in.value = make_ui(square=square, submit=0)
    await ClockCycles(dut.clk, 2)

    dut.ui_in.value = make_ui(square=square, submit=1)
    await ClockCycles(dut.clk, 5)

    dut.ui_in.value = make_ui(square=square, submit=0)
    await ClockCycles(dut.clk, 5)


async def assert_status(dut, *, turn=None, game_over=None, x_win=None, o_win=None, draw=None):
    """Check status bits exposed by uo_out and uio_out."""
    await ClockCycles(dut.clk, 1)

    if turn is not None:
        assert bit(dut.uio_out.value, 0) == turn, (
            f"Expected turn={turn}, got uio_out={int(dut.uio_out.value):08b}"
        )

    if game_over is not None:
        assert bit(dut.uio_out.value, 1) == game_over, (
            f"Expected game_over={game_over}, got uio_out={int(dut.uio_out.value):08b}"
        )

    if x_win is not None:
        assert bit(dut.uo_out.value, 5) == x_win, (
            f"Expected x_win={x_win}, got uo_out={int(dut.uo_out.value):08b}"
        )
        assert bit(dut.uio_out.value, 5) == x_win, (
            f"Expected x_win debug={x_win}, got uio_out={int(dut.uio_out.value):08b}"
        )

    if o_win is not None:
        assert bit(dut.uo_out.value, 6) == o_win, (
            f"Expected o_win={o_win}, got uo_out={int(dut.uo_out.value):08b}"
        )
        assert bit(dut.uio_out.value, 6) == o_win, (
            f"Expected o_win debug={o_win}, got uio_out={int(dut.uio_out.value):08b}"
        )

    if draw is not None:
        assert bit(dut.uo_out.value, 7) == draw, (
            f"Expected draw={draw}, got uo_out={int(dut.uo_out.value):08b}"
        )
        assert bit(dut.uio_out.value, 7) == draw, (
            f"Expected draw debug={draw}, got uio_out={int(dut.uio_out.value):08b}"
        )


@cocotb.test()
async def test_reset_and_pin_setup(dut):
    """Check reset behavior and fixed Tiny Tapeout IO directions."""
    dut._log.info("Starting reset and pin setup test")

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_design(dut)

    assert int(dut.uio_oe.value) == 0xFF, "All uio pins should be configured as outputs"

    await assert_status(dut, turn=0, game_over=0, x_win=0, o_win=0, draw=0)

    assert bit(dut.uio_out.value, 2) == 1, "Square 0 should be a valid selected square"
    assert bit(dut.uio_out.value, 3) == 1, "Square 0 should be empty after reset"


@cocotb.test()
async def test_x_wins_top_row(dut):
    """Play a game where X wins across the top row: 0, 1, 2."""
    dut._log.info("Starting X top-row win test")

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_design(dut)

    await submit_move(dut, 0)
    await assert_status(dut, turn=1, game_over=0, x_win=0, o_win=0, draw=0)

    await submit_move(dut, 3)
    await assert_status(dut, turn=0, game_over=0, x_win=0, o_win=0, draw=0)

    await submit_move(dut, 1)
    await assert_status(dut, turn=1, game_over=0, x_win=0, o_win=0, draw=0)

    await submit_move(dut, 4)
    await assert_status(dut, turn=0, game_over=0, x_win=0, o_win=0, draw=0)

    await submit_move(dut, 2)
    await assert_status(dut, turn=1, game_over=1, x_win=1, o_win=0, draw=0)

    # Once the game is over, another submit should not change the turn.
    await submit_move(dut, 5)
    await assert_status(dut, turn=1, game_over=1, x_win=1, o_win=0, draw=0)


@cocotb.test()
async def test_o_wins_left_column(dut):
    """Play a game where O wins down the left column: 0, 3, 6."""
    dut._log.info("Starting O left-column win test")

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_design(dut)

    await submit_move(dut, 1)
    await assert_status(dut, turn=1, game_over=0, x_win=0, o_win=0, draw=0)

    await submit_move(dut, 0)
    await assert_status(dut, turn=0, game_over=0, x_win=0, o_win=0, draw=0)

    await submit_move(dut, 2)
    await assert_status(dut, turn=1, game_over=0, x_win=0, o_win=0, draw=0)

    await submit_move(dut, 3)
    await assert_status(dut, turn=0, game_over=0, x_win=0, o_win=0, draw=0)

    await submit_move(dut, 4)
    await assert_status(dut, turn=1, game_over=0, x_win=0, o_win=0, draw=0)

    await submit_move(dut, 6)
    await assert_status(dut, turn=0, game_over=1, x_win=0, o_win=1, draw=0)


@cocotb.test()
async def test_draw_game(dut):
    """Play a full game with no winner and check the draw output."""
    dut._log.info("Starting draw game test")

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_design(dut)

    # Final board:
    #
    # X O X
    # X O O
    # O X X
    #
    # No row, column, or diagonal contains three of the same mark.
    moves = [0, 1, 2, 4, 3, 5, 7, 6, 8]

    for square in moves[:-1]:
        await submit_move(dut, square)
        await assert_status(dut, game_over=0, x_win=0, o_win=0, draw=0)

    await submit_move(dut, moves[-1])
    await assert_status(dut, game_over=1, x_win=0, o_win=0, draw=1)


@cocotb.test()
async def test_invalid_and_occupied_square_are_ignored(dut):
    """Check that invalid square selects and occupied squares do not create moves."""
    dut._log.info("Starting invalid/occupied square test")

    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_design(dut)

    # Select invalid square 9. It should not be valid and should not change turn.
    dut.ui_in.value = make_ui(square=9, submit=0)
    await ClockCycles(dut.clk, 2)
    assert bit(dut.uio_out.value, 2) == 0, "Square 9 should be invalid"

    await submit_move(dut, 9)
    await assert_status(dut, turn=0, game_over=0, x_win=0, o_win=0, draw=0)

    # Play square 0 as X.
    await submit_move(dut, 0)
    await assert_status(dut, turn=1, game_over=0, x_win=0, o_win=0, draw=0)

    # Square 0 is now occupied, so selected_empty should be 0.
    dut.ui_in.value = make_ui(square=0, submit=0)
    await ClockCycles(dut.clk, 2)
    assert bit(dut.uio_out.value, 3) == 0, "Square 0 should be occupied"

    # Trying to submit the occupied square should not toggle the turn.
    await submit_move(dut, 0)
    await assert_status(dut, turn=1, game_over=0, x_win=0, o_win=0, draw=0)

    # The extra ui_in[5] reset should clear the game.
    dut.ui_in.value = make_ui(square=0, submit=0, reset=1)
    await ClockCycles(dut.clk, 3)

    dut.ui_in.value = make_ui(square=0, submit=0, reset=0)
    await ClockCycles(dut.clk, 3)

    await assert_status(dut, turn=0, game_over=0, x_win=0, o_win=0, draw=0)
    assert bit(dut.uio_out.value, 3) == 1, "Square 0 should be empty after ui_in[5] reset"
