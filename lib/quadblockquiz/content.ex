defmodule Quadblockquiz.Content do
  @moduledoc "Loads and validates original quiz and vulnerability content from JSON."

  @known_penalties ~w(garbage_rows speed_up score_drain)

  def load! do
    vulnerabilities = load_file!("vulnerabilities.json") |> validate_vulnerabilities!()

    %{
      questions: load_questions!() |> validate_questions!(vulnerabilities),
      vulnerabilities: vulnerabilities
    }
  end

  defp load_questions! do
    bank_files =
      :quadblockquiz
      |> :code.priv_dir()
      |> Path.join("content/questions/*.json")
      |> Path.wildcard()

    load_file!("questions.json") ++ Enum.flat_map(bank_files, &load_path!/1)
  end

  defp load_file!(name) do
    :quadblockquiz
    |> :code.priv_dir()
    |> Path.join("content/#{name}")
    |> load_path!()
  end

  defp load_path!(path), do: path |> File.read!() |> Jason.decode!()

  defp validate_questions!(questions, vulnerabilities) when is_list(questions) do
    vulnerability_ids = MapSet.new(vulnerabilities, & &1["id"])

    Enum.each(questions, fn question ->
      required!(question, ~w(id topic prompt choices answer_index explanation vulnerability_id))

      unless length(question["choices"]) >= 2 and
               question["answer_index"] in 0..(length(question["choices"]) - 1) do
        raise ArgumentError, "question #{question["id"]} has an invalid answer"
      end

      unless MapSet.member?(vulnerability_ids, question["vulnerability_id"]) do
        raise ArgumentError, "question #{question["id"]} references an unknown vulnerability"
      end
    end)

    duplicate_ids =
      questions |> Enum.frequencies_by(& &1["id"]) |> Enum.filter(&(elem(&1, 1) > 1))

    unless duplicate_ids == [] do
      raise ArgumentError,
            "duplicate question ids: #{inspect(Enum.map(duplicate_ids, &elem(&1, 0)))}"
    end

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
