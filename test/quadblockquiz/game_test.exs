defmodule Quadblockquiz.GameTest do
  use ExUnit.Case, async: true

  alias Quadblockquiz.Game
  alias Quadblockquiz.Game.Board

  @question %{
    "id" => "q1",
    "topic" => "Secure Coding",
    "prompt" => "Safe query?",
    "choices" => ["Parameterized", "Concatenated"],
    "answer_index" => 0,
    "explanation" => "Keep data separate.",
    "vulnerability_id" => "sql-injection"
  }
  @event %{
    "id" => "sql-injection",
    "kind" => "cyberattack",
    "title" => "SQL Injection",
    "summary" => "Unsafe query",
    "education" => "Parameterize it.",
    "penalty" => "garbage_rows",
    "deadline_seconds" => 2
  }
  @unrelated_question %{
    "id" => "q2",
    "topic" => "Secure Coding",
    "prompt" => "Different issue?",
    "choices" => ["Safe", "Unsafe"],
    "answer_index" => 0,
    "explanation" => "Different incident.",
    "vulnerability_id" => "cross-site-scripting"
  }

  defp new_game,
    do: Game.new(%{questions: [@question], vulnerabilities: [@event]}, seed: {1, 2, 3})

  test "movement, rotation, and hard drop update the active game" do
    game = new_game()
    moved = Game.move(game, :left)
    assert moved.piece.x == game.piece.x - 1

    dropped = Game.hard_drop(moved)
    assert map_size(dropped.board.cells) == 4
    assert dropped.score > game.score
  end

  test "the piece generator does not produce back-to-back identical pieces" do
    game = new_game()

    {kinds, _game} =
      Enum.reduce(1..30, {[game.piece.kind], game}, fn _, {kinds, game} ->
        spawned = Game.hard_drop(game)
        reset = %{spawned | board: Board.new(), status: :running}
        {[reset.piece.kind | kinds], reset}
      end)

    assert kinds
           |> Enum.chunk_every(2, 1, :discard)
           |> Enum.all?(fn [left, right] -> left != right end)
  end

  test "rotation uses an upward floor kick instead of stopping near the bottom" do
    game = %{new_game() | piece: Quadblockquiz.Game.Piece.new(:tee, 3, 18)}
    rotated = Game.rotate(game)

    assert rotated.piece.rotation == 1
    assert rotated.piece.y == 17
  end

  test "a breached vulnerability never disables rotation" do
    event = %{definition: @event, remaining_ms: 0, breached: true}
    game = %{new_game() | piece: Quadblockquiz.Game.Piece.new(:tee), active_event: event}

    assert Game.rotate(game).piece.rotation == 1
  end

  test "topic screen pauses gravity but not clock scoring or incidents" do
    game = new_game() |> Game.toggle_topics()
    original_y = game.piece.y
    game = Game.tick(game, 30_000)

    assert game.status == :topics
    assert game.piece.y == original_y
    assert game.score == 30
    assert game.active_event.definition["id"] == "sql-injection"
  end

  test "an ignored incident applies its gameplay penalty once" do
    game = new_game() |> Game.toggle_topics() |> Game.tick(30_000)
    assert map_size(game.board.cells) == 0

    penalized = Game.tick(game, 2_000)
    assert penalized.active_event.breached
    assert map_size(penalized.board.cells) == 18

    later = Game.tick(penalized, 1_000)
    assert map_size(later.board.cells) >= 18
  end

  test "a garbage-row cyberattack can end a run by overflowing the board" do
    game = new_game() |> Game.toggle_topics() |> Game.tick(30_000)
    game = %{game | board: %{game.board | cells: %{{0, 0} => :threat}}}
    attacked = Game.tick(game, 2_000)

    assert attacked.status == :game_over
    assert attacked.last_message =~ "cyberattack"
  end

  test "a related correct answer earns points and loot and resolves the incident" do
    game = new_game() |> Game.tick(30_000) |> Game.toggle_topics()
    game = Game.choose_topic(game, "Secure Coding")
    answered = Game.answer(game, 0)

    assert answered.score == game.score + 100
    assert answered.active_event == nil
    assert Enum.sum(Map.values(answered.inventory)) == 1
    assert answered.last_loot in [:row_blast, :slow_clock, :hotfix]
  end

  test "an incident topic identifies and selects its related question" do
    content = %{questions: [@unrelated_question, @question], vulnerabilities: [@event]}
    game = Game.new(content, seed: {1, 2, 3}) |> Game.tick(30_000) |> Game.toggle_topics()

    assert Game.incident_topics(game) == ["Secure Coding"]
    assert Game.topic_resolves_incident?(game, "Secure Coding")
    assert Game.choose_topic(game, "Secure Coding").current_question["id"] == "q1"
  end

  test "wrong answers cost points and give no loot" do
    game = %{new_game() | score: 50} |> Game.toggle_topics() |> Game.choose_topic("Secure Coding")
    answered = Game.answer(game, 1)
    assert answered.score == 25
    assert Enum.sum(Map.values(answered.inventory)) == 0
  end

  test "hotfix inventory resolves an incident" do
    game = new_game() |> Game.tick(30_000)
    game = %{game | inventory: %{game.inventory | hotfix: 1}}
    patched = Game.use_powerup(game, :hotfix)
    assert patched.active_event == nil
    assert patched.inventory.hotfix == 0
  end

  test "game ends after ten minutes even on the topic screen" do
    game = new_game() |> Game.toggle_topics() |> Game.tick(600_000)
    assert game.status == :timed_out
    assert Game.remaining_seconds(game) == 0
  end
end
