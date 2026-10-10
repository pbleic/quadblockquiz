defmodule Quadblockquiz.Game.Piece do
  @moduledoc "Five-square-set definitions and rotation helpers for QuadBlocks."

  @enforce_keys [:kind, :rotation, :x, :y]
  defstruct [:kind, :rotation, :x, :y]

  @type kind :: :bar | :box | :tee | :boot | :zig
  @type t :: %__MODULE__{kind: kind(), rotation: non_neg_integer(), x: integer(), y: integer()}

  @kinds [:bar, :box, :tee, :boot, :zig]
  @base %{
    bar: [{0, 1}, {1, 1}, {2, 1}, {3, 1}],
    box: [{1, 0}, {2, 0}, {1, 1}, {2, 1}],
    tee: [{1, 0}, {0, 1}, {1, 1}, {2, 1}],
    boot: [{0, 0}, {0, 1}, {1, 1}, {2, 1}],
    zig: [{1, 0}, {2, 0}, {0, 1}, {1, 1}]
  }

  def kinds, do: @kinds

  def new(kind, x \\ 3, y \\ 0) when kind in @kinds do
    %__MODULE__{kind: kind, rotation: 0, x: x, y: y}
  end

  def move(%__MODULE__{} = piece, dx, dy),
    do: %{piece | x: piece.x + dx, y: piece.y + dy}

  def rotate(%__MODULE__{kind: :box} = piece), do: piece

  def rotate(%__MODULE__{} = piece),
    do: %{piece | rotation: rem(piece.rotation + 1, 4)}

  def blocks(%__MODULE__{} = piece) do
    @base
    |> Map.fetch!(piece.kind)
    |> rotate_times(piece.rotation)
    |> Enum.map(fn {x, y} -> {x + piece.x, y + piece.y} end)
  end

  defp rotate_times(blocks, 0), do: blocks

  defp rotate_times(blocks, count) do
    rotated = Enum.map(blocks, fn {x, y} -> {3 - y, x} end)
    rotate_times(rotated, count - 1)
  end
end
