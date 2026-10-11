defmodule QuadblockquizWeb.GameLive do
  use QuadblockquizWeb, :live_view

  alias Quadblockquiz.{Content, Game}
  alias Quadblockquiz.Game.Piece

  @tick_ms 250

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(@tick_ms, self(), :tick)

    {:ok,
     socket
     |> assign(:page_title, "Quadblockquiz — Supply Chain Edition")
     |> assign(:game, Game.new(Content.load!()))}
  end

  @impl true
  def handle_info(:tick, socket), do: {:noreply, update(socket, :game, &Game.tick(&1, @tick_ms))}

  @impl true
  def handle_event("keydown", %{"key" => key}, socket) do
    game =
      case key do
        "ArrowLeft" -> Game.move(socket.assigns.game, :left)
        "ArrowRight" -> Game.move(socket.assigns.game, :right)
        "ArrowUp" -> Game.rotate(socket.assigns.game)
        "ArrowDown" -> Game.soft_drop(socket.assigns.game)
        "Enter" -> Game.hard_drop(socket.assigns.game)
        " " -> Game.toggle_topics(socket.assigns.game)
        "Space" -> Game.toggle_topics(socket.assigns.game)
        _ -> socket.assigns.game
      end

    {:noreply, assign(socket, :game, game)}
  end

  def handle_event("action", %{"name" => name}, socket) do
    game =
      case name do
        "left" -> Game.move(socket.assigns.game, :left)
        "right" -> Game.move(socket.assigns.game, :right)
        "rotate" -> Game.rotate(socket.assigns.game)
        "down" -> Game.soft_drop(socket.assigns.game)
        "drop" -> Game.hard_drop(socket.assigns.game)
        "topics" -> Game.toggle_topics(socket.assigns.game)
        "quit" -> Game.quit(socket.assigns.game)
        "restart" -> Game.new(Content.load!())
      end

    {:noreply, assign(socket, :game, game)}
  end

  def handle_event("topic", %{"name" => topic}, socket),
    do: {:noreply, update(socket, :game, &Game.choose_topic(&1, topic))}

  def handle_event("answer", %{"index" => index}, socket),
    do: {:noreply, update(socket, :game, &Game.answer(&1, String.to_integer(index)))}

  def handle_event("powerup", %{"name" => name}, socket) do
    item = %{"row_blast" => :row_blast, "slow_clock" => :slow_clock, "hotfix" => :hotfix}[name]
    {:noreply, update(socket, :game, &Game.use_powerup(&1, item))}
  end

  defp board_cells(game) do
    falling = Piece.blocks(game.piece) |> MapSet.new()

    for y <- 0..(game.board.height - 1), x <- 0..(game.board.width - 1) do
      kind =
        if MapSet.member?(falling, {x, y}), do: game.piece.kind, else: game.board.cells[{x, y}]

      %{kind: kind}
    end
  end

  defp cell_class(nil), do: "cell"
  defp cell_class(kind), do: "cell filled #{kind}"

  defp status_label(:running), do: "Playing"
  defp status_label(:topics), do: "Topic screen — gravity paused"
  defp status_label(:game_over), do: "Game over"
  defp status_label(:quit), do: "Finished"
  defp status_label(:timed_out), do: "Time complete"

  defp time_text(seconds) do
    minutes = div(seconds, 60) |> Integer.to_string() |> String.pad_leading(2, "0")
    remainder = rem(seconds, 60) |> Integer.to_string() |> String.pad_leading(2, "0")
    minutes <> ":" <> remainder
  end

  defp deadline_seconds(game),
    do: max(0, div(game.active_event.deadline_at - game.elapsed_ms + 999, 1000))

  defp kind_label("licensing_lawsuit"), do: "Licensing lawsuit"
  defp kind_label(_), do: "Cyberattack"

  @impl true
  def render(assigns) do
    ~H"""
    <div id="game-shell" phx-window-keydown="keydown">
      <header class="hero">
        <div>
          <p class="eyebrow">SUPPLY CHAIN EDITION</p>
          <h1>QUADBLOCK<span>QUIZ</span></h1>
          <p class="tagline">Build a clean stack. Defend the pipeline. Learn under pressure.</p>
        </div>
        <div class="status-pill"><i></i><%= status_label(@game.status) %></div>
      </header>

      <main class="game-layout">
        <section class="board-panel" aria-label="QuadBlock playing board">
          <div class="hud">
            <div><small>SCORE</small><strong><%= @game.score %></strong></div>
            <div><small>ROWS</small><strong><%= @game.lines %></strong></div>
            <div><small>TIME LEFT</small><strong><%= time_text(Game.remaining_seconds(@game)) %></strong></div>
            <div><small>NEXT</small><strong><%= @game.next_piece |> Atom.to_string() |> String.upcase() %></strong></div>
          </div>

          <div class="board-wrap">
            <div
              class="board"
              role="grid"
              data-piece-x={@game.piece.x}
              data-piece-y={@game.piece.y}
              data-piece-rotation={@game.piece.rotation}
            >
              <%= for cell <- board_cells(@game) do %>
                <div class={cell_class(cell.kind)} role="gridcell" aria-label={if cell.kind, do: Atom.to_string(cell.kind), else: "empty"}></div>
              <% end %>
            </div>

            <%= if @game.status == :topics do %>
              <div class="topic-overlay">
                <p class="eyebrow">GRAVITY PAUSED · CLOCK ACTIVE</p>
                <%= if @game.current_question do %>
                  <h2><%= @game.current_question["topic"] %></h2>
                  <p class="question"><%= @game.current_question["prompt"] %></p>
                  <div class="answer-list">
                    <%= for {choice, index} <- Enum.with_index(@game.current_question["choices"]) do %>
                      <button phx-click="answer" phx-value-index={index}><%= choice %></button>
                    <% end %>
                  </div>
                <% else %>
                  <h2>Choose a topic</h2>
                  <div class="topic-list">
                    <%= for topic <- Game.topics(@game) do %>
                      <button phx-click="topic" phx-value-name={topic}><%= topic %></button>
                    <% end %>
                  </div>
                  <div class="overlay-actions">
                    <button class="secondary" phx-click="action" phx-value-name="topics">Resume</button>
                    <button class="danger" phx-click="action" phx-value-name="quit">Quit gracefully</button>
                  </div>
                <% end %>
              </div>
            <% end %>

            <%= if @game.status in [:game_over, :quit, :timed_out] do %>
              <div class="topic-overlay end-screen">
                <p class="eyebrow">RUN COMPLETE</p>
                <h2><%= status_label(@game.status) %></h2>
                <p>Final score: <strong><%= @game.score %></strong></p>
                <button phx-click="action" phx-value-name="restart">Play again</button>
              </div>
            <% end %>
          </div>

          <div class="controls" aria-label="Game controls">
            <button phx-click="action" phx-value-name="left" aria-label="Move left">←</button>
            <button phx-click="action" phx-value-name="rotate" aria-label="Rotate">↻</button>
            <button phx-click="action" phx-value-name="right" aria-label="Move right">→</button>
            <button phx-click="action" phx-value-name="down" aria-label="Move down">↓</button>
            <button class="wide" phx-click="action" phx-value-name="drop">HARD DROP · ENTER</button>
            <button class="wide pause" phx-click="action" phx-value-name="topics">TOPICS · SPACE</button>
          </div>
        </section>

        <aside class="side-panel">
          <section class={"incident-card #{if @game.active_event, do: "active", else: "quiet"}"}>
            <div class="section-title"><span>INCIDENT FEED</span><i></i></div>
            <%= if @game.active_event do %>
              <p class="incident-kind"><%= kind_label(@game.active_event.definition["kind"]) %></p>
              <h2><%= @game.active_event.definition["title"] %></h2>
              <p><%= @game.active_event.definition["summary"] %></p>
              <p class="education"><%= @game.active_event.definition["education"] %></p>
              <%= if @game.active_event.breached do %>
                <div class="deadline breached">PENALTY ACTIVE — answer its topic or use Hotfix</div>
              <% else %>
                <div class="deadline">RESPOND IN <%= deadline_seconds(@game) %>s</div>
              <% end %>
            <% else %>
              <div class="all-clear"><span>✓</span><p><strong>Pipeline clear</strong><br/>Monitor active. Next scan pending.</p></div>
            <% end %>
          </section>

          <section class="powerups">
            <div class="section-title"><span>POWERUPS</span><small>FROM LOOT BOXES</small></div>
            <button phx-click="powerup" phx-value-name="row_blast" disabled={@game.inventory.row_blast == 0}>
              <span class="power-icon">▰</span><span><strong>Row Blast</strong><small>Clear bottom two rows</small></span><b><%= @game.inventory.row_blast %></b>
            </button>
            <button phx-click="powerup" phx-value-name="slow_clock" disabled={@game.inventory.slow_clock == 0}>
              <span class="power-icon">◷</span><span><strong>Slow Clock</strong><small>Slower fall for 15 seconds</small></span><b><%= @game.inventory.slow_clock %></b>
            </button>
            <button phx-click="powerup" phx-value-name="hotfix" disabled={@game.inventory.hotfix == 0 || is_nil(@game.active_event)}>
              <span class="power-icon">✦</span><span><strong>Hotfix</strong><small>Resolve active incident</small></span><b><%= @game.inventory.hotfix %></b>
            </button>
          </section>

          <section class="message-log">
            <div class="section-title"><span>OPS LOG</span></div>
            <p><%= @game.last_message %></p>
          </section>

          <section class="keyboard-help">
            <span><kbd>←</kbd><kbd>→</kbd> move</span><span><kbd>↑</kbd> rotate</span>
            <span><kbd>↓</kbd> soft drop</span><span><kbd>Enter</kbd> hard drop</span>
            <span><kbd>Space</kbd> topics</span>
          </section>
        </aside>
      </main>
    </div>
    """
  end
end
