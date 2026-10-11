defmodule Quadblockquiz.Game do
  @moduledoc "Pure, deterministic Quadblockquiz game state machine."

  alias Quadblockquiz.Game.{Board, Piece}

  @base_fall_ms 700
  @event_spacing_ms 30_000
  @game_limit_ms 600_000
  @loot [:row_blast, :slow_clock, :hotfix]

  defstruct board: nil,
            piece: nil,
            next_piece: nil,
            score: 0,
            lines: 0,
            elapsed_ms: 0,
            gravity_ms: 0,
            status: :running,
            questions: [],
            vulnerabilities: [],
            current_question: nil,
            active_event: nil,
            next_event_at: @event_spacing_ms,
            inventory: %{row_blast: 0, slow_clock: 0, hotfix: 0},
            slow_until: 0,
            last_message: "Stack securely. Learn continuously.",
            last_loot: nil,
            rng: nil

  @type t :: %__MODULE__{}

  def new(content, opts) do
    seed = Keyword.fetch!(opts, :seed)
    rng = :rand.seed_s(:exsplus, seed)
    {kind, rng} = pick(Piece.kinds(), rng)
    {next_kind, rng} = pick_piece_except(kind, rng)

    %__MODULE__{
      board: Board.new(),
      piece: Piece.new(kind),
      next_piece: next_kind,
      questions: Map.fetch!(content, :questions),
      vulnerabilities: Map.fetch!(content, :vulnerabilities),
      rng: rng
    }
  end

  def move(%__MODULE__{status: :running} = game, direction) when direction in [:left, :right] do
    dx = if direction == :left, do: -1, else: 1
    candidate = Piece.move(game.piece, dx, 0)
    if Board.placeable?(game.board, candidate), do: %{game | piece: candidate}, else: game
  end

  def move(game, _direction), do: game

  def rotate(%__MODULE__{status: :running} = game) do
    rotated = Piece.rotate(game.piece)

    rotation_kicks()
    |> Enum.map(fn {dx, dy} -> Piece.move(rotated, dx, dy) end)
    |> Enum.find(&Board.placeable?(game.board, &1))
    |> case do
      nil -> game
      candidate -> %{game | piece: candidate}
    end
  end

  def rotate(game), do: game

  def soft_drop(%__MODULE__{status: :running} = game), do: descend(game, 1)
  def soft_drop(game), do: game

  def hard_drop(%__MODULE__{status: :running} = game), do: hard_drop_steps(game, 0)
  def hard_drop(game), do: game

  def toggle_topics(%__MODULE__{status: :running} = game) do
    game = %{game | status: :topics, current_question: nil, last_loot: nil}

    case incident_topics(game) do
      [topic | _rest] -> choose_topic(game, topic)
      [] -> game
    end
  end

  def toggle_topics(%__MODULE__{status: :topics} = game),
    do: %{game | status: :running, current_question: nil}

  def toggle_topics(game), do: game

  def quit(%__MODULE__{status: status} = game) when status in [:running, :topics],
    do: %{game | status: :quit, last_message: "Game ended gracefully."}

  def quit(game), do: game

  def tick(%__MODULE__{status: status} = game, _delta_ms)
      when status in [:game_over, :quit, :timed_out],
      do: game

  def tick(%__MODULE__{} = game, delta_ms) when is_integer(delta_ms) and delta_ms > 0 do
    was_running = game.status == :running
    old_seconds = div(game.elapsed_ms, 1000)
    elapsed_ms = min(game.elapsed_ms + delta_ms, @game_limit_ms)
    second_points = div(elapsed_ms, 1000) - old_seconds

    game = %{game | elapsed_ms: elapsed_ms, score: game.score + second_points}
    game = maybe_start_event(game)
    game = maybe_apply_penalty(game)

    cond do
      elapsed_ms >= @game_limit_ms ->
        %{game | status: :timed_out, last_message: "Ten minutes complete. Supply chain secured!"}

      was_running ->
        advance_gravity(game, delta_ms)

      true ->
        game
    end
  end

  def choose_topic(%__MODULE__{status: :topics} = game, topic) do
    candidates = Enum.filter(game.questions, &(&1["topic"] == topic))

    related_candidates =
      Enum.filter(candidates, &related_to_active?(&1, game.active_event))

    candidates = if related_candidates == [], do: candidates, else: related_candidates

    case candidates do
      [] ->
        %{game | last_message: "No questions are available for that topic."}

      _ ->
        {question, rng} = pick(candidates, game.rng)
        %{game | current_question: question, rng: rng, last_loot: nil}
    end
  end

  def choose_topic(game, _topic), do: game

  def answer(%__MODULE__{status: :topics, current_question: question} = game, answer_index)
      when not is_nil(question) do
    if answer_index == question["answer_index"] do
      {loot, rng} = pick(@loot, game.rng)
      inventory = Map.update!(game.inventory, loot, &(&1 + 1))
      fixed = related_to_active?(question, game.active_event)
      active_event = if fixed, do: nil, else: game.active_event

      message =
        "Correct — #{question["explanation"]} Loot box: #{loot_name(loot)}." <>
          if(fixed, do: " The related incident is resolved.", else: "")

      %{
        game
        | score: game.score + 100,
          status: :running,
          inventory: inventory,
          current_question: nil,
          active_event: active_event,
          last_loot: loot,
          last_message: message,
          rng: rng,
          next_event_at:
            if(fixed, do: game.elapsed_ms + @event_spacing_ms, else: game.next_event_at)
      }
    else
      %{
        game
        | score: max(0, game.score - 25),
          status: :running,
          current_question: nil,
          last_message: "Not quite — #{question["explanation"]}"
      }
    end
  end

  def answer(game, _answer_index), do: game

  def use_powerup(%__MODULE__{} = game, item) when item in @loot do
    if Map.fetch!(game.inventory, item) > 0 and usable?(game, item) do
      inventory = Map.update!(game.inventory, item, &(&1 - 1))
      apply_powerup(%{game | inventory: inventory}, item)
    else
      %{game | last_message: "That powerup is not available right now."}
    end
  end

  def use_powerup(game, _item), do: game

  def topics(%__MODULE__{} = game),
    do: game.questions |> Enum.map(& &1["topic"]) |> Enum.uniq() |> Enum.sort()

  def incident_topics(%__MODULE__{active_event: nil}), do: []

  def incident_topics(%__MODULE__{} = game) do
    game.questions
    |> Enum.filter(&related_to_active?(&1, game.active_event))
    |> Enum.map(& &1["topic"])
    |> Enum.uniq()
    |> Enum.sort()
  end

  def incident_response_topic(%__MODULE__{} = game),
    do: game |> incident_topics() |> List.first()

  def remaining_seconds(%__MODULE__{} = game), do: div(@game_limit_ms - game.elapsed_ms, 1000)

  def fall_interval(%__MODULE__{} = game) do
    level_reduction = min(div(game.lines, 5) * 55, 330)
    slow_bonus = if game.slow_until > game.elapsed_ms, do: 450, else: 0

    incident_reduction =
      if game.active_event && game.active_event.breached &&
           game.active_event.definition["penalty"] == "speed_up",
         do: 250,
         else: 0

    max(120, @base_fall_ms - level_reduction - incident_reduction + slow_bonus)
  end

  defp advance_gravity(game, delta_ms) do
    game = %{game | gravity_ms: game.gravity_ms + delta_ms}
    consume_gravity(game)
  end

  defp consume_gravity(%__MODULE__{status: :running} = game) do
    interval = fall_interval(game)

    if game.gravity_ms >= interval do
      game
      |> Map.put(:gravity_ms, game.gravity_ms - interval)
      |> descend(0)
      |> consume_gravity()
    else
      game
    end
  end

  defp consume_gravity(game), do: game

  defp descend(game, bonus) do
    candidate = Piece.move(game.piece, 0, 1)

    if Board.placeable?(game.board, candidate) do
      %{game | piece: candidate, score: game.score + bonus}
    else
      lock_and_spawn(game)
    end
  end

  defp hard_drop_steps(game, distance) do
    candidate = Piece.move(game.piece, 0, 1)

    if Board.placeable?(game.board, candidate) do
      hard_drop_steps(%{game | piece: candidate}, distance + 1)
    else
      game |> Map.update!(:score, &(&1 + distance * 2)) |> lock_and_spawn()
    end
  end

  defp lock_and_spawn(game) do
    {board, cleared} = Board.lock(game.board, game.piece)
    clear_score = %{0 => 0, 1 => 100, 2 => 300, 3 => 500, 4 => 800}[cleared]
    {next_kind, rng} = pick_piece_except(game.next_piece, game.rng)
    piece = Piece.new(game.next_piece)

    game = %{
      game
      | board: board,
        piece: piece,
        next_piece: next_kind,
        lines: game.lines + cleared,
        score: game.score + clear_score,
        rng: rng,
        last_message:
          if(cleared > 0, do: "Cleared #{cleared} secure row(s)!", else: game.last_message)
    }

    if Board.placeable?(board, piece) do
      game
    else
      %{game | status: :game_over, last_message: "The stack reached the top. Game over."}
    end
  end

  defp maybe_start_event(%__MODULE__{active_event: nil} = game) do
    if game.elapsed_ms >= game.next_event_at and game.vulnerabilities != [] do
      {definition, rng} = pick(game.vulnerabilities, game.rng)

      event = %{
        definition: definition,
        deadline_at: game.elapsed_ms + definition["deadline_seconds"] * 1000,
        breached: false
      }

      %{
        game
        | active_event: event,
          rng: rng,
          last_message: "Incident detected: #{definition["title"]}"
      }
    else
      game
    end
  end

  defp maybe_start_event(game), do: game

  defp maybe_apply_penalty(%__MODULE__{active_event: %{breached: false} = event} = game) do
    if game.elapsed_ms >= event.deadline_at do
      game
      |> apply_penalty(event.definition["penalty"])
      |> Map.put(:active_event, %{event | breached: true})
    else
      game
    end
  end

  defp maybe_apply_penalty(game), do: game

  defp apply_penalty(game, "garbage_rows") do
    {holes, rng} = random_holes(2, game.board.width, game.rng)
    overflow? = Enum.any?(game.board.cells, fn {{_x, y}, _value} -> y < 2 end)
    board = Board.add_garbage(game.board, holes)
    lost? = overflow? or not Board.placeable?(board, game.piece)

    %{
      game
      | board: board,
        rng: rng,
        status: if(lost?, do: :game_over, else: game.status),
        last_message:
          if(lost?,
            do: "The cyberattack pushed the stack past the top. Game over.",
            else: "The incident injected two risk rows."
          )
    }
  end

  defp apply_penalty(game, "score_drain"),
    do: %{game | score: max(0, game.score - 250), last_message: "The lawsuit cost 250 points."}

  defp apply_penalty(game, "speed_up"),
    do: %{game | last_message: "Unpatched dependencies accelerated the QuadBlocks."}

  defp apply_powerup(game, :row_blast),
    do: %{
      game
      | board: Board.clear_bottom(game.board, 2),
        last_message: "Row Blast cleared the bottom two rows."
    }

  defp apply_powerup(game, :slow_clock),
    do: %{
      game
      | slow_until: game.elapsed_ms + 15_000,
        last_message: "Slow Clock is active for 15 seconds."
    }

  defp apply_powerup(%__MODULE__{active_event: event} = game, :hotfix) when not is_nil(event),
    do: %{
      game
      | active_event: nil,
        next_event_at: game.elapsed_ms + @event_spacing_ms,
        last_message: "Hotfix resolved the active incident."
    }

  defp usable?(%__MODULE__{active_event: nil}, :hotfix), do: false
  defp usable?(_game, _item), do: true

  # A compact wall/floor-kick table. Horizontal kicks keep turns working beside
  # walls and stacked cells; upward kicks allow legal turns near the floor.
  defp rotation_kicks,
    do: [{0, 0}, {-1, 0}, {1, 0}, {-2, 0}, {2, 0}, {0, -1}, {-1, -1}, {1, -1}, {0, -2}]

  defp related_to_active?(_question, nil), do: false

  defp related_to_active?(question, event),
    do: question["vulnerability_id"] == event.definition["id"]

  defp random_holes(0, _width, rng), do: {[], rng}

  defp random_holes(count, width, rng) do
    {number, rng} = :rand.uniform_s(width, rng)
    {rest, rng} = random_holes(count - 1, width, rng)
    {[number - 1 | rest], rng}
  end

  defp pick(items, rng) do
    {number, rng} = :rand.uniform_s(length(items), rng)
    {Enum.at(items, number - 1), rng}
  end

  defp pick_piece_except(previous_kind, rng) do
    Piece.kinds()
    |> List.delete(previous_kind)
    |> pick(rng)
  end

  defp loot_name(:row_blast), do: "Row Blast"
  defp loot_name(:slow_clock), do: "Slow Clock"
  defp loot_name(:hotfix), do: "Hotfix"
end
