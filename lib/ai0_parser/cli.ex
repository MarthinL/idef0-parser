defmodule Ai0Parser.CLI do
  @moduledoc false

  def main(argv) do
    # First, check for obviously bad options
    known_flags = ["--output", "--no-abc", "--no-prop", "--skip-empty-lists", "--no-fix-abbr"]
    unknown = Enum.filter(argv, fn arg ->
      String.starts_with?(arg, "--") and arg not in known_flags and not String.starts_with?(arg, "--output")
    end)

    if unknown != [] do
      IO.puts("Error: Unknown option(s): #{inspect(unknown)}")
      System.halt(1)
    end

    {opts, args, invalid} = parse_args(argv)

    if invalid != [] do
      IO.puts("Error: Invalid options: #{inspect(Enum.map(invalid, &elem(&1, 0)))}")
      System.halt(1)
    end

    case args do
      [path] ->
        output_file = Keyword.get(opts, :output, "output.json")
        case File.read(path) do
          {:ok, content} ->
            parsed = Ai0Parser.parse_string(content)
            filtered = apply_filters(parsed, opts)
            json = Ai0Parser.to_json(filtered)
            File.write!(output_file, json)

          {:error, reason} ->
            IO.puts("Could not read file: #{inspect(reason)}")
            System.halt(1)
        end

      _ ->
        IO.puts("Usage: ai0_parser [OPTIONS] <file>")
        IO.puts("Options:")
        IO.puts("  --output FILENAME      Output file (default: output.json)")
        IO.puts("  --no-abc               Exclude all ABC Data and Objects in ABC list")
        IO.puts("  --no-prop              Exclude all Property List fields")
        IO.puts("  --skip-empty-lists     Skip empty lists ([] or [{}]) from output")
        IO.puts("  --no-fix-abbr          Skip automatic model abbreviation extraction")
        System.halt(1)
    end
  end

  defp parse_args(argv) do
    OptionParser.parse(argv, switches: [output: :string, no_abc: :boolean, no_prop: :boolean, skip_empty_lists: :boolean, no_fix_abbr: :boolean])
  end

  defp apply_filters(data, opts) do
    data
    |> apply_abc_filter(Keyword.get(opts, :no_abc, false))
    |> apply_prop_filter(Keyword.get(opts, :no_prop, false))
    |> apply_empty_lists_filter(Keyword.get(opts, :skip_empty_lists, false))
    |> apply_abbreviation_filter(Keyword.get(opts, :no_fix_abbr, false))
  end

  defp apply_abc_filter(data, false), do: data

  defp apply_abc_filter(data, true) do
    case data do
      %{"Source" => source} ->
        %{
          "Source" => %{
            "Header" => Map.get(source, "Header", %{}),
            "Pools" => filter_pools(Map.get(source, "Pools", %{}), :abc),
            "Lists" => filter_lists(Map.get(source, "Lists", %{}), :abc)
          }
        }

      %{"Project" => project} ->
        %{
          "Project" => %{
            "Creator" => Map.get(project, "Creator", ""),
            "Description" => Map.get(project, "Description", []),
            "Models" => Enum.map(Map.get(project, "Models", []), fn model ->
              %{
                "Name" => Map.get(model, "Name", ""),
                "Context Diagram ID" => Map.get(model, "Context Diagram ID", ""),
                "Pools" => filter_pools(Map.get(model, "Pools", %{}), :abc),
                "Lists" => filter_lists(Map.get(model, "Lists", %{}), :abc)
              }
            end)
          }
        }

      _ ->
        data
    end
  end

  defp apply_prop_filter(data, false), do: data

  defp apply_prop_filter(data, true) do
    case data do
      %{"Source" => source} ->
        %{
          "Source" => %{
            "Header" => Map.get(source, "Header", %{}),
            "Pools" => filter_pools(Map.get(source, "Pools", %{}), :prop),
            "Lists" => filter_lists(Map.get(source, "Lists", %{}), :prop)
          }
        }

      %{"Project" => project} ->
        %{
          "Project" => %{
            "Creator" => Map.get(project, "Creator", ""),
            "Description" => Map.get(project, "Description", []),
            "Models" => Enum.map(Map.get(project, "Models", []), fn model ->
              %{
                "Name" => Map.get(model, "Name", ""),
                "Context Diagram ID" => Map.get(model, "Context Diagram ID", ""),
                "Pools" => filter_pools(Map.get(model, "Pools", %{}), :prop),
                "Lists" => filter_lists(Map.get(model, "Lists", %{}), :prop)
              }
            end)
          }
        }

      _ ->
        data
    end
  end

  defp filter_pools(pools, filter_type) do
    Enum.reduce(pools, %{}, fn {pool_name, pool_data}, acc ->
      filtered_pool = case pool_data do
        map when is_map(map) ->
          # For ID-keyed pools (Activities, Concepts, etc.)
          Enum.reduce(map, %{}, fn {id, item}, item_acc ->
            filtered_item = filter_item(item, filter_type)
            Map.put(item_acc, id, filtered_item)
          end)

        list when is_list(list) ->
          # For list-based pools
          Enum.map(list, fn item -> filter_item(item, filter_type) end)

        other ->
          other
      end

      Map.put(acc, pool_name, filtered_pool)
    end)
  end

  defp filter_lists(lists, filter_type) do
    Enum.reduce(lists, %{}, fn {list_name, list_data}, acc ->
      filtered_data = case list_name do
        "Objects in ABC" when filter_type == :abc ->
          # Remove this list entirely when filtering ABC
          nil

        _ ->
          # Filter items in other lists
          case list_data do
            list when is_list(list) ->
              Enum.map(list, fn item -> filter_item(item, filter_type) end)

            map when is_map(map) ->
              filter_item(map, filter_type)

            other ->
              other
          end
      end

      if filtered_data == nil do
        acc
      else
        Map.put(acc, list_name, filtered_data)
      end
    end)
  end

  defp filter_item(item, filter_type) when is_map(item) do
    Enum.reduce(item, %{}, fn {key, value}, acc ->
      case key do
        "ABC Data" when filter_type == :abc ->
          # Skip ABC Data entirely when abc filter enabled
          acc

        "Property List" when filter_type == :prop ->
          # Skip Property List entirely when prop filter enabled
          acc

        _ ->
          # Recursively filter nested structures
          filtered_value = case value do
            v when is_map(v) -> filter_item(v, filter_type)
            v when is_list(v) -> Enum.map(v, fn elem ->
              case elem do
                m when is_map(m) -> filter_item(m, filter_type)
                l when is_list(l) -> Enum.map(l, fn nested -> filter_item(nested, filter_type) end)
                other -> other
              end
            end)
            v -> v
          end

          Map.put(acc, key, filtered_value)
      end
    end)
  end

  defp filter_item(item, _filter_type), do: item

  defp apply_empty_lists_filter(data, false), do: data

  defp apply_empty_lists_filter(data, true) do
    case data do
      %{"Project" => project} ->
        %{
          "Project" => %{
            "Creator" => Map.get(project, "Creator", ""),
            "Description" => Map.get(project, "Description", []),
            "Used At" => Map.get(project, "Used At", ""),
            "Models" => Enum.map(Map.get(project, "Models", []), fn model ->
              %{
                "Name" => Map.get(model, "Name", ""),
                "Context Diagram ID" => Map.get(model, "Context Diagram ID", ""),
                "Pools" => filter_pools_empty_lists(Map.get(model, "Pools", %{})),
                "Lists" => filter_lists_empty_lists(Map.get(model, "Lists", %{}))
              }
            end)
          }
        }

      _ ->
        data
    end
  end

  defp filter_pools_empty_lists(pools) do
    Enum.reduce(pools, %{}, fn {pool_name, pool_data}, acc ->
      filtered_pool = case pool_data do
        map when is_map(map) ->
          # For ID-keyed pools (Activities, Concepts, etc.)
          Enum.reduce(map, %{}, fn {id, item}, item_acc ->
            filtered_item = filter_item_empty_lists(item)
            Map.put(item_acc, id, filtered_item)
          end)

        list when is_list(list) ->
          # For list-based pools
          Enum.map(list, fn item -> filter_item_empty_lists(item) end)

        other ->
          other
      end

      Map.put(acc, pool_name, filtered_pool)
    end)
  end

  defp filter_lists_empty_lists(lists) do
    Enum.reduce(lists, %{}, fn {list_name, list_data}, acc ->
      filtered_data = case list_data do
        list when is_list(list) ->
          Enum.map(list, fn item -> filter_item_empty_lists(item) end)

        map when is_map(map) ->
          Enum.reduce(map, %{}, fn {k, v}, inner_acc ->
            case v do
              list when is_list(list) ->
                Enum.map(list, fn item -> filter_item_empty_lists(item) end)
              other ->
                Map.put(inner_acc, k, other)
            end
            |> then(fn new_val -> Map.put(inner_acc, k, new_val) end)
          end)

        other ->
          other
      end

      Map.put(acc, list_name, filtered_data)
    end)
  end

  defp filter_item_empty_lists(item) do
    case item do
      map when is_map(map) ->
        Enum.reduce(map, %{}, fn {key, value}, acc ->
          # Skip if it's a list-type field and it's empty
          if String.contains?(key, "List") and is_empty_list(value) do
            acc
          else
            # Recursively filter nested maps and lists
            filtered_value = case value do
              v when is_map(v) -> filter_item_empty_lists(v)
              v when is_list(v) ->
                Enum.map(v, fn elem ->
                  case elem do
                    m when is_map(m) -> filter_item_empty_lists(m)
                    other -> other
                  end
                end)
              v -> v
            end

            Map.put(acc, key, filtered_value)
          end
        end)

      list when is_list(list) ->
        Enum.map(list, fn elem ->
          case elem do
            m when is_map(m) -> filter_item_empty_lists(m)
            other -> other
          end
        end)

      other ->
        other
    end
  end

  defp is_empty_list(value) do
    case value do
      [] -> true
      # Check if it's a list with single empty map
      [item] when is_map(item) and map_size(item) == 0 -> true
      _ -> false
    end
  end

  defp apply_abbreviation_filter(data, true), do: data

  defp apply_abbreviation_filter(data, false) do
    case data do
      %{"Project" => project} ->
        %{
          "Project" => %{
            "Creator" => Map.get(project, "Creator", ""),
            "Description" => Map.get(project, "Description", []),
            "Used At" => Map.get(project, "Used At", ""),
            "Models" => Enum.map(Map.get(project, "Models", []), fn model ->
              fix_model_abbreviation(model)
            end)
          }
        }

      _ ->
        data
    end
  end

  defp fix_model_abbreviation(model) do
    model_name = Map.get(model, "Name", "")
    notes_pool = get_in(model, ["Pools", "Notes"]) || %{}

    # Extract abbreviation from diagrams' notes
    abbreviation = extract_abbreviation_from_notes(model, notes_pool, model_name)

    updated_model = if abbreviation do
      Map.put(model, "Model Abbreviation", abbreviation)
    else
      model
    end

    updated_model
  end

  defp extract_abbreviation_from_notes(model, notes_pool, model_name) do
    diagrams = get_in(model, ["Lists", "Diagrams"]) || []

    Enum.find_value(diagrams, nil, fn diagram ->
      note_list = Map.get(diagram, "Note List", [])

      Enum.find_value(note_list, nil, fn note ->
        note_id = Map.get(note, "ID")
        note_obj = notes_pool[to_string(note_id)]

        if note_obj do
          note_text = Map.get(note_obj, "Name", "")
          extract_abbr_from_text(note_text, model_name)
        else
          nil
        end
      end)
    end)
  end

  defp extract_abbr_from_text(note_text, model_name) do
    # Pattern: "Model Abbreviation: XXX=ModelName"
    case String.split(note_text, "=") do
      [prefix, suffix] ->
        suffix_trimmed = String.trim(suffix)

        if suffix_trimmed == model_name do
          # Extract the abbreviation part (after "Model Abbreviation: ")
          case String.split(prefix, ":") do
            [_, abbr_part] ->
              String.trim(abbr_part)
            _ ->
              nil
          end
        else
          nil
        end

      _ ->
        nil
    end
  end
end
