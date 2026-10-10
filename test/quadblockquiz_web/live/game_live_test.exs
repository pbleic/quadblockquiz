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
end
