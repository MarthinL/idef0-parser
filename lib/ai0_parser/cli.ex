defmodule Ai0Parser.CLI do
  @moduledoc false

  def main(argv) do
    {opts, args, invalid} = parse_args(argv)

    if invalid != [] do
      IO.puts("Invalid options: #{inspect(invalid)}")
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
        IO.puts("  --output FILENAME    Output file (default: output.json)")
        IO.puts("  --no-abc             Exclude all ABC Data and Objects in ABC list")
        IO.puts("  --no-prop            Exclude all Property List fields")
        System.halt(1)
    end
  end

  defp parse_args(argv) do
    OptionParser.parse(argv, switches: [output: :string, no_abc: :boolean, no_prop: :boolean])
  end

  defp apply_filters(data, opts) do
    data
    |> apply_abc_filter(Keyword.get(opts, :no_abc, false))
    |> apply_prop_filter(Keyword.get(opts, :no_prop, false))
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
end
