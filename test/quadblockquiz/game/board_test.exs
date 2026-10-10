defmodule Quadblockquiz.Game.BoardTest do
  use ExUnit.Case, async: true

  alias Quadblockquiz.Game.{Board, Piece}

  test "rejects pieces outside the board and accepts an open spawn" do
    board = Board.new()
    assert Board.placeable?(board, Piece.new(:box))
    refute Board.placeable?(board, Piece.new(:bar, -3, 0))
    refute Board.placeable?(board, Piece.new(:bar, 3, 19))
  end

  test "locking clears a full row and shifts cells downward" do
    cells = for x <- 4..9, into: %{}, do: {{x, 19}, :tee}
    board = %{Board.new() | cells: Map.put(cells, {0, 18}, :zig)}
    piece = Piece.new(:bar, 0, 18)

    {cleared, count} = Board.lock(board, piece)

    assert count == 1
    assert cleared.cells[{0, 19}] == :zig
    refute Map.has_key?(cleared.cells, {4, 19})
  end

  test "garbage rows push existing cells upward and leave holes" do
    board = %{Board.new() | cells: %{{2, 10} => :box}}
    board = Board.add_garbage(board, [3, 5])

    assert board.cells[{2, 8}] == :box
    refute Map.has_key?(board.cells, {3, 18})
    refute Map.has_key?(board.cells, {5, 19})
    assert board.cells[{0, 19}] == :threat
  end
end
