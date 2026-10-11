defmodule QuadblockquizWeb.GameLiveTest do
  use QuadblockquizWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders a playable board and opens the topic screen", %{conn: conn} do
    {:ok, view, html} = live(conn, "/")
    assert html =~ "QUADBLOCK"
    assert html =~ "SUPPLY CHAIN EDITION"
    assert has_element?(view, ".cell")

    view |> element("button[phx-value-name=topics]") |> render_click()
    assert has_element?(view, ".topic-overlay", "Choose a topic")
  end

  test "arrow keys move, rotate, and lower the active piece", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    render_keydown(view, "keydown", %{"key" => "ArrowLeft"})
    assert has_element?(view, ".board[data-piece-x=\"2\"]")

    render_keydown(view, "keydown", %{"key" => "ArrowRight"})
    assert has_element?(view, ".board[data-piece-x=\"3\"]")

    render_keydown(view, "keydown", %{"key" => "ArrowUp"})
    assert has_element?(view, ".board[data-piece-rotation=\"1\"]")

    render_keydown(view, "keydown", %{"key" => "ArrowDown"})
    assert has_element?(view, ".board[data-piece-y=\"1\"]")
  end
end
