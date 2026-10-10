defmodule Quadblockquiz.Game.PieceTest do
  use ExUnit.Case, async: true

  alias Quadblockquiz.Game.Piece

  test "all five kinds contain four blocks" do
    assert length(Piece.kinds()) == 5
    assert Enum.all?(Piece.kinds(), &(length(Piece.blocks(Piece.new(&1))) == 4))
  end

  test "four rotations return a piece to its original cells" do
    piece = Piece.new(:tee)
    rotated = Enum.reduce(1..4, piece, fn _, acc -> Piece.rotate(acc) end)
    assert Piece.blocks(rotated) == Piece.blocks(piece)
  end
end
