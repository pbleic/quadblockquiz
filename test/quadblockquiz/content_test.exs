defmodule Quadblockquiz.ContentTest do
  use ExUnit.Case, async: true

  test "bundled content loads and covers cyberattack and licensing events" do
    content = Quadblockquiz.Content.load!()
    assert length(content.questions) >= 8
    assert Enum.any?(content.vulnerabilities, &(&1["kind"] == "cyberattack"))
    assert Enum.any?(content.vulnerabilities, &(&1["kind"] == "licensing_lawsuit"))
  end
end
