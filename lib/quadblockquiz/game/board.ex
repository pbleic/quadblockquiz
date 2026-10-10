defmodule Quadblockquiz.Game.Board do
  @moduledoc "Pure board collision, locking, line clearing, and penalty operations."

  alias Quadblockquiz.Game.Piece

  @enforce_keys [:width, :height, :cells]
  defstruct width: 10, height: 20, cells: %{}

  @type t :: %__MODULE__{width: pos_integer(), height: pos_integer(), cells: map()}

  def new(width \\ 10, height \\ 20), do: %__MODULE__{width: width, height: height, cells: %{}}

  def placeable?(%__MODULE__{} = board, %Piece{} = piece),
    do: placeable?(board, Piece.blocks(piece))

  def placeable?(%__MODULE__{} = board, blocks) when is_list(blocks) do
    Enum.all?(blocks, fn {x, y} ->
      x >= 0 and x < board.width and y >= 0 and y < board.height and
        not Map.has_key?(board.cells, {x, y})
    end)
  end

  def lock(%__MODULE__{} = board, %Piece{} = piece) do
    cells = Enum.reduce(Piece.blocks(piece), board.cells, &Map.put(&2, &1, piece.kind))
    clear_full_rows(%{board | cells: cells})
  end

  def clear_full_rows(%__MODULE__{} = board) do
    full_rows =
      0..(board.height - 1)
      |> Enum.filter(fn y ->
        Enum.all?(0..(board.width - 1), &Map.has_key?(board.cells, {&1, y}))
      end)

    kept_rows = Enum.reject(0..(board.height - 1), &(&1 in full_rows))
    shift = length(full_rows)

    cells =
      kept_rows
      |> Enum.with_index(shift)
      |> Enum.reduce(%{}, fn {old_y, new_y}, acc ->
        Enum.reduce(0..(board.width - 1), acc, fn x, row_acc ->
          case Map.fetch(board.cells, {x, old_y}) do
            {:ok, value} -> Map.put(row_acc, {x, new_y}, value)
            :error -> row_acc
          end
        end)
      end)

    {%{board | cells: cells}, length(full_rows)}
  end

  def add_garbage(%__MODULE__{} = board, holes) when is_list(holes) do
    count = length(holes)

    shifted =
      Enum.reduce(board.cells, %{}, fn {{x, y}, value}, acc ->
        if y - count >= 0, do: Map.put(acc, {x, y - count}, value), else: acc
      end)

    cells =
      holes
      |> Enum.with_index(board.height - count)
      |> Enum.reduce(shifted, fn {hole, y}, acc ->
        Enum.reduce(0..(board.width - 1), acc, fn x, row_acc ->
          if x == hole, do: row_acc, else: Map.put(row_acc, {x, y}, :threat)
        end)
      end)

    %{board | cells: cells}
  end

  def clear_bottom(%__MODULE__{} = board, count) do
    cutoff = board.height - count
    kept = Enum.reject(board.cells, fn {{_x, y}, _value} -> y >= cutoff end) |> Map.new()

    shifted =
      Enum.reduce(kept, %{}, fn {{x, y}, value}, acc -> Map.put(acc, {x, y + count}, value) end)

    %{board | cells: shifted}
  end
end
