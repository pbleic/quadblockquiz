defmodule Quadblockquiz.Content do
  @moduledoc "Loads and validates original quiz and vulnerability content from JSON."

  @known_penalties ~w(garbage_rows speed_up score_drain)

  def load! do
    %{
      questions: load_file!("questions.json") |> validate_questions!(),
      vulnerabilities: load_file!("vulnerabilities.json") |> validate_vulnerabilities!()
    }
  end

  defp load_file!(name) do
    :quadblockquiz
    |> :code.priv_dir()
    |> Path.join("content/#{name}")
    |> File.read!()
    |> Jason.decode!()
  end

  defp validate_questions!(questions) when is_list(questions) do
    Enum.each(questions, fn question ->
      required!(question, ~w(id topic prompt choices answer_index explanation))

      unless length(question["choices"]) >= 2 and
               question["answer_index"] in 0..(length(question["choices"]) - 1) do
        raise ArgumentError, "question #{question["id"]} has an invalid answer"
      end
    end)

    questions
  end

  defp validate_vulnerabilities!(items) when is_list(items) do
    Enum.each(items, fn item ->
      required!(item, ~w(id kind title summary education penalty deadline_seconds))

      unless item["penalty"] in @known_penalties do
        raise ArgumentError, "unknown vulnerability penalty #{item["penalty"]}"
      end
    end)

    items
  end

  defp required!(map, keys) do
    case Enum.reject(keys, &Map.has_key?(map, &1)) do
      [] -> :ok
      missing -> raise ArgumentError, "content item is missing: #{Enum.join(missing, ", ")}"
    end
  end
end
