defmodule Quadblockquiz.ContentTest do
  use ExUnit.Case, async: true

  test "bundled content loads and covers cyberattack and licensing events" do
    content = Quadblockquiz.Content.load!()
    assert length(content.questions) >= 100
    assert Enum.uniq_by(content.questions, & &1["id"]) == content.questions

    question_counts = Enum.frequencies_by(content.questions, & &1["vulnerability_id"])

    assert Enum.all?(content.vulnerabilities, fn vulnerability ->
             Map.fetch!(question_counts, vulnerability["id"]) >= 20
           end)

    assert Enum.any?(content.vulnerabilities, &(&1["kind"] == "cyberattack"))
    assert Enum.any?(content.vulnerabilities, &(&1["kind"] == "licensing_lawsuit"))
  end
end
