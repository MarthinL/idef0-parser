defmodule Ai0Parser.Parser do
  @moduledoc """
  Parser for AI0 TXT files.
  """

  import NimbleParsec

  # simple kv parser: `Key:  Value` -> {:kv, key, value}
  key = ascii_string([?A..?Z, ?a..?z, ?0..?9, ?_ , ?\-, ?., ?\s, ?#, ?/], min: 1)
  colon = string(":") |> ignore()
  spaces = ascii_string([?\s], min: 0)
  value = utf8_string([], min: 0)

  kv =
    key
    |> ignore(spaces)
    |> concat(colon)
    |> ignore(spaces)
    |> concat(value)
    |> eos()
    |> reduce({:build_kv, []})

  defparsec(:kv_line, kv)

  defp build_kv([key, value]) do
    {:kv, String.trim(key), String.trim(value)}
  end

  # Public API
  def parse(text) when is_binary(text) do
    lines = String.split(text, ~r/\r?\n/, trim: false)
    {result, _} = parse_lines(lines, 0, %{})

    # Restructure into the final format
    restructure_output(result)
  end

  defp restructure_output(data) do
    # Check if this is a repository file (has Project Summary)
    if Map.has_key?(data, "Project Summary") do
      restructure_repository_output(data)
    else
      restructure_model_output(data)
    end
  end

  defp restructure_repository_output(data) do
    # Extract project summary
    project_summary = Map.get(data, "Project Summary", %{})
    creator = Map.get(project_summary, "Creator", "")
    description = Map.get(project_summary, "Description", [])

    # Get model assignments
    assignments = if Map.has_key?(data, "Assignment List"), do: flatten_list_wrapper(Map.get(data, "Assignment List")), else: []
    models = Enum.filter(assignments, fn a -> a["Type"] == "Model" end)

    # Get all diagrams
    diagrams = if Map.has_key?(data, "Diagram List"), do: flatten_diagram_list(Map.get(data, "Diagram List")), else: []

    # Group diagrams by model based on their top-level parent
    models_with_diagrams = Enum.map(models, fn model ->
      model_id = String.to_integer(model["ID"])
      model_diagrams = find_model_diagrams(diagrams, model_id)

      # Create model structure
      %{
        "Name" => model["Name"],
        "Context Diagram ID" => to_string(model_id),
        "Pools" => extract_model_pools(data),
        "Lists" => extract_model_lists(data, model_diagrams)
      }
    end)

    # Build repository structure
    %{
      "Project" => %{
        "Creator" => creator,
        "Description" => description,
        "Models" => models_with_diagrams
      }
    }
  end

  defp restructure_model_output(data) do
    # Extract header (it's already parsed by parse_ai0_header)
    header = Map.get(data, "AI0 Neutral Text;  Version", %{})

    # Separate pools from lists
    pools = %{}
    pools = if Map.has_key?(data, "Activity Pool"), do: Map.put(pools, "Activities", Map.get(data, "Activity Pool")), else: pools
    pools = if Map.has_key?(data, "Concept Pool"), do: Map.put(pools, "Concepts", Map.get(data, "Concept Pool")), else: pools
    pools = if Map.has_key?(data, "Costdriver Pool"), do: Map.put(pools, "Costdrivers", Map.get(data, "Costdriver Pool")), else: pools
    pools = if Map.has_key?(data, "Note Pool"), do: Map.put(pools, "Notes", Map.get(data, "Note Pool")), else: pools

    # Separate lists with flattening
    lists = %{}

    # Flatten Assignments (if it has intermediate wrapper)
    assignments = if Map.has_key?(data, "Assignment List"), do: flatten_list_wrapper(Map.get(data, "Assignment List")), else: []
    lists = if length(assignments) > 0, do: Map.put(lists, "Assignments", assignments), else: lists

    # Flatten Diagrams (remove "Diagram" wrapper if present)
    diagrams = if Map.has_key?(data, "Diagram List"), do: flatten_diagram_list(Map.get(data, "Diagram List")), else: []
    lists = if length(diagrams) > 0, do: Map.put(lists, "Diagrams", diagrams), else: lists

    # Flatten Objects in ABC (if it has intermediate wrapper) - always include as a list
    objects = if Map.has_key?(data, "Object in ABC List"), do: flatten_list_wrapper(Map.get(data, "Object in ABC List")), else: []
    lists = Map.put(lists, "Objects in ABC", objects)

    # Compute IDEF0 numbering
    numbering = compute_numbering(lists)

    # Add numbering as custom assignments
    assignments = lists["Assignments"] || []
    new_assignments = assignments ++ [
      %{"Name" => "A-Numbers by Activity ID", "Type" => "Custom", "Activity" => numbering["Activity Numbers"]},
      %{"Name" => "ICOM Numbers by Diagram ID and Concept ID", "Type" => "Custom", "Diagram-Concept" => numbering["Concept Numbers"]}
    ]
    lists = Map.put(lists, "Assignments", new_assignments)

    # Build final structure
    %{
      "Source" => %{
        "Header" => header,
        "Pools" => pools,
        "Lists" => lists
      }
    }
  end

  defp flatten_diagram_list(list_data) when is_list(list_data) do
    # Diagrams come as [{Diagram: [diagram1, diagram2, ...]}]
    # We want [diagram1, diagram2, ...]
    Enum.flat_map(list_data, fn item ->
      case item do
        %{"Diagram" => diagrams} when is_list(diagrams) -> diagrams
        %{"Diagram" => diagram} -> [diagram]
        _ -> [item]
      end
    end)
  end
  defp flatten_diagram_list(data), do: [data]

  defp flatten_list_wrapper(list_data) when is_list(list_data) do
    # Generic list flattening - just return as is
    list_data
  end
  defp flatten_list_wrapper(data), do: [data]

  defp compute_numbering(lists) do
    diagrams = lists["Diagrams"] || []
    {activity_numbers, concept_numbers} = compute_numbering_recursive(diagrams, %{}, %{})
    %{
      "Activity Numbers" => activity_numbers,
      "Concept Numbers" => concept_numbers
    }
  end

  defp compute_numbering_recursive(diagrams, activity_numbers, concept_numbers) do
    Enum.reduce(diagrams, {activity_numbers, concept_numbers}, fn diagram, {act_nums, conc_nums} ->
      if diagram["Parent"] == %{} do
        # Context diagram
        [activity | _] = diagram["Activity List"]
        activity_id = activity["ID"]
        new_act_nums = Map.put(act_nums, activity_id, "A0")
        {new_act_nums, conc_nums}
      else
        # Decomposition diagram
        parent_activity_id = diagram["Parent"]["Activity"]
        parent_diagram_id = diagram["Parent"]["Diagram"]
        parent_a_number = act_nums[parent_activity_id]

        # Assign A numbers to activities in this diagram
        new_act_nums = Enum.reduce(Enum.with_index(diagram["Activity List"], 1), act_nums, fn {activity, index}, acc ->
          a_number = if parent_a_number == "A0", do: "A" <> to_string(index), else: parent_a_number <> to_string(index)
          Map.put(acc, activity["ID"], a_number)
        end)

        # Find parent diagram and activity
        parent_diagram = find_diagram_by_id(diagrams, parent_diagram_id)
        parent_activity = find_activity_by_id(parent_diagram["Activity List"], parent_activity_id)

        # Assign concept numbers for boundary arrows
        concept_nums_for_diagram = %{}
        icom_lists = [
          {"Input List", "I"},
          {"Control List", "C"},
          {"Output List", "O"},
          {"Mechanism List", "M"}
        ]
        concept_nums_for_diagram = Enum.reduce(icom_lists, concept_nums_for_diagram, fn {list_name, prefix}, acc ->
          list = parent_activity[list_name] || []
          Enum.reduce(Enum.with_index(list, 1), acc, fn {concept, index}, acc2 ->
            number = prefix <> to_string(index)
            Map.put(acc2, concept["ID"], number)
          end)
        end)

        new_conc_nums = Map.put(conc_nums, diagram["ID"], concept_nums_for_diagram)
        {new_act_nums, new_conc_nums}
      end
    end)
  end

  defp find_diagram_by_id(diagrams, id) do
    Enum.find(diagrams, fn d -> d["ID"] == id end)
  end

  defp find_activity_by_id(activities, id) do
    Enum.find(activities, fn a -> a["ID"] == id end)
  end

  defp process_pool_breakdown(breakdown) do
    # Extract Concept list and convert to Concepts with numeric IDs
    # Keep all other fields as-is, including Type field if present
    case Map.get(breakdown, "Concept") do
      concepts when is_list(concepts) ->
        # Flatten to handle put_block wrapping - extract the actual string list
        flat_concepts = List.flatten(concepts)

        # Extract numeric IDs from the concept reference strings
        concept_ids = Enum.map(flat_concepts, fn item ->
          # Item should be a string, but handle it safely
          line = if is_binary(item), do: item, else: to_string(item)
          case Integer.parse(String.trim(line)) do
            {id, _} -> to_string(id)
            :error -> nil
          end
        end) |> Enum.reject(&is_nil/1) |> Enum.uniq()

        # Remove the Concept list
        breakdown_cleaned = Map.delete(breakdown, "Concept")

        # Add the Concepts list with just the numeric IDs
        if Enum.empty?(concept_ids) do
          breakdown_cleaned
        else
          Map.put(breakdown_cleaned, "Concepts", concept_ids)
        end
      nil ->
        Map.delete(breakdown, "Concept")
      _ ->
        breakdown
    end
  end

  defp parse_lines(lines, i, acc) do
    len = length(lines)
    if i >= len do
      {acc, i}
    else
      line = Enum.at(lines, i) |> String.replace("\t", " ") |> String.trim()

      # Debug: log lines that look like breakdowns
      # (removed for clean output)

      cond do
        line == "" -> parse_lines(lines, i + 1, acc)
        String.starts_with?(line, "/*") -> parse_lines(lines, i + 1, acc)
        String.starts_with?(line, "End") -> {acc, i + 1}

        # Header line: "AI0 Neutral Text;  Version:2.20;  12/25/2025  02:30.36"
        String.starts_with?(line, "AI0 Neutral Text") ->
          header_data = parse_ai0_header(line)
          acc2 = Map.put(acc, "AI0 Neutral Text;  Version", header_data)
          parse_lines(lines, i + 1, acc2)

        # Parent: special handling
        String.starts_with?(line, "Parent:") ->
          val = String.trim_leading(line, "Parent:") |> String.trim()
          parent_obj = parse_parent_value(val)
          acc2 = Map.put(acc, "Parent", parent_obj)
          parse_lines(lines, i + 1, acc2)

        # ICOM Lists (Input, Output, Control, Mechanism) - flatten to single list
        line in ["Input List", "Output List", "Control List", "Mechanism List"] ->
          header = line
          end_idx = find_end_index(lines, i + 1, header)
          if end_idx == nil do
             acc2 = Map.put(acc, header, [])
             parse_lines(lines, i + 1, acc2)
          else
             body = Enum.slice(lines, i + 1, end_idx - (i + 1))
             parsed_items = parse_icom_items(body)
             acc2 = Map.put(acc, header, parsed_items)
             parse_lines(lines, end_idx + 1, acc2)
          end

        # Concept List
        line == "Concept List" ->
          header = line
          end_idx = find_end_index(lines, i + 1, header)
          if end_idx == nil do
             acc2 = put_block(acc, header, [])
             parse_lines(lines, i + 1, acc2)
          else
             body = Enum.slice(lines, i + 1, end_idx - (i + 1))
             parsed_items = parse_icom_items(body)
             acc2 = put_block(acc, header, parsed_items)
             parse_lines(lines, end_idx + 1, acc2)
          end

        # Concept block (for breakdowns) - collects concept references like "11  (Name)"
        line == "Concept" ->
          end_idx = find_end_index(lines, i + 1, "Concept")
          if end_idx == nil do
             acc2 = put_block(acc, "Concept", [])
             parse_lines(lines, i + 1, acc2)
          else
             body = Enum.slice(lines, i + 1, end_idx - (i + 1))
             # Extract concept references - lines that start with digits optionally followed by description
             concept_refs = Enum.map(body, fn line ->
               line = String.trim(line)
               case Integer.parse(line) do
                 {id, _rest} -> {to_string(id), line}
                 :error -> nil
               end
             end) |> Enum.reject(&is_nil/1)

             # Store as a list of strings (the IDs with descriptions)
             # This will be processed later in process_pool_breakdown
             parsed_items = Enum.map(concept_refs, fn {_id, full_line} -> full_line end)

             acc2 = put_block(acc, "Concept", parsed_items)
             parse_lines(lines, end_idx + 1, acc2)
          end

        # Project Summary - special handling to parse project info
        line == "Project Summary" ->
          header = line
          end_idx = find_end_index(lines, i + 1, header)
          if end_idx == nil do
             acc2 = Map.put(acc, header, %{})
             parse_lines(lines, i + 1, acc2)
          else
             body = Enum.slice(lines, i + 1, end_idx - (i + 1))
             {parsed_summary, _} = parse_lines(body, 0, %{})
             acc2 = Map.put(acc, header, parsed_summary)
             parse_lines(lines, end_idx + 1, acc2)
          end

        # Assignment List - special handling to parse assignments
        line == "Assignment List" ->
          header = line
          end_idx = find_end_index(lines, i + 1, header)
          if end_idx == nil do
             acc2 = Map.put(acc, header, [])
             parse_lines(lines, i + 1, acc2)
          else
             body = Enum.slice(lines, i + 1, end_idx - (i + 1))
             parsed_assignments = parse_assignment_items(body)
             acc2 = Map.put(acc, header, parsed_assignments)
             parse_lines(lines, end_idx + 1, acc2)
          end

        # Activity List - special handling to flatten "Activity" key
        line == "Activity List" ->
          header = line
          end_idx = find_end_index(lines, i + 1, header)
          if end_idx == nil do
             acc2 = Map.put(acc, header, [])
             parse_lines(lines, i + 1, acc2)
          else
             body = Enum.slice(lines, i + 1, end_idx - (i + 1))
             {parsed_map, _} = parse_lines(body, 0, %{})

             # Extract "Activity" list and flatten it directly into Activity List
             activities = Map.get(parsed_map, "Activity", [])
             activities = if is_list(activities), do: activities, else: [activities]

             acc2 = Map.put(acc, header, activities)
             parse_lines(lines, end_idx + 1, acc2)
          end

        # Flatten Lists: Breakdown, Property, Source, Note
        line in ["Breakdown List", "Property List", "Source List", "Note List"] ->
          header = line
          end_idx = find_end_index(lines, i + 1, header)
          if end_idx == nil do
             acc2 = Map.put(acc, header, [])
             parse_lines(lines, i + 1, acc2)
          else
             body = Enum.slice(lines, i + 1, end_idx - (i + 1))
             {parsed_map, _} = parse_lines(body, 0, %{})

             # Determine inner key
             inner_key = case header do
               "Breakdown List" -> "Breakdown"
               "Property List" -> "Property"
               "Source List" -> "Source" # Assuming Source
               "Note List" -> "Note"
               _ -> String.replace(header, " List", "")
             end

             items = Map.get(parsed_map, inner_key, [])
             # Ensure items is a list (it might be a single map if put_block logic changes, but currently it is a list)
             items = if is_list(items), do: items, else: [items]

             acc2 = Map.put(acc, header, items)
             parse_lines(lines, end_idx + 1, acc2)
          end

        true ->
          # First try block header patterns (including those with ":")
          block_header_regex = ~r/^(Activity|Diagram|Breakdown|Concept|Note|Source|Costdriver)\b(?::)?\s*#?(\d+)(?:\s+#(\d+))?$/
          case Regex.run(block_header_regex, line) do
            match when is_list(match) ->
              [_, name, id | rest] = match
              internal_id = case rest do
                [val] when val != "" -> val
                _ -> nil
              end

              header_name = String.trim(name)

              # Try "End <Name> <ID>" first (strict), then "End <Name>" as fallback
              end_tag_regex = ~r/^End\s+#{Regex.escape(header_name)}\s+#?#{Regex.escape(id)}\s*$/
              end_idx = find_end_index_regex(lines, i + 1, end_tag_regex)

              if end_idx do
                 body = Enum.slice(lines, i + 1, end_idx - (i + 1))
                 {parsed_body, _} = parse_lines(body, 0, %{})

                 parsed_body = Map.put(parsed_body, "ID", id)
                 parsed_body = if internal_id, do: Map.put(parsed_body, "DBID", internal_id), else: parsed_body

                 # Special handling for Breakdown blocks in Concept Pool
                 parsed_body = if String.trim(header_name) == "Breakdown" do
                   process_pool_breakdown(parsed_body)
                 else
                   parsed_body
                 end

                 acc2 = put_block(acc, header_name, parsed_body)
                 parse_lines(lines, end_idx + 1, acc2)
              else
                 # Fallback: try "End <Name>" without ID
                 end_tag_regex_2 = ~r/^End\s+#{Regex.escape(header_name)}\s*$/
                 end_idx_2 = find_end_index_regex(lines, i + 1, end_tag_regex_2)

                 if end_idx_2 do
                    body = Enum.slice(lines, i + 1, end_idx_2 - (i + 1))
                    {parsed_body, _} = parse_lines(body, 0, %{})
                    parsed_body = Map.put(parsed_body, "ID", id)
                    parsed_body = if internal_id, do: Map.put(parsed_body, "DBID", internal_id), else: parsed_body
                    acc2 = put_block(acc, header_name, parsed_body)
                    parse_lines(lines, end_idx_2 + 1, acc2)
                 else
                    # Final fallback: implicit termination (but log a warning)
                    IO.warn("Warning: Block '#{header_name} #{id}' at line #{i + 1} has no explicit end marker, using implicit termination")
                    handle_implicit_block(lines, i, acc, header_name, id, internal_id)
                 end
              end

            nil ->
              # Not a block header, check if it's a KV pair
              if String.contains?(line, ":") do
                case kv_line(line <> "\n") do
                  {:ok, [{:kv, key, val}], _, _, _, _} ->
                    acc2 = put_kv(acc, key, val)
                    parse_lines(lines, i + 1, acc2)
                  _ ->
                    raise "Parse error: Invalid key-value line: '#{line}'"
                end
              else
                # Not KV, treat as generic block
                handle_generic_block(lines, i, acc, line)
              end
          end
      end
    end
  end

  defp handle_implicit_block(lines, i, acc, header_name, id, internal_id) do
    end_idx_implicit = find_implicit_end(lines, i + 1, header_name)

    body = Enum.slice(lines, i + 1, end_idx_implicit - (i + 1))
    {parsed_body, _} = parse_lines(body, 0, %{})
    parsed_body = Map.put(parsed_body, "ID", id)
    parsed_body = if internal_id, do: Map.put(parsed_body, "DBID", internal_id), else: parsed_body

    acc2 = put_block(acc, header_name, parsed_body)

    # If we hit "--", skip it
    next_i = end_idx_implicit
    next_line = if next_i < length(lines), do: Enum.at(lines, next_i) |> String.trim(), else: ""
    next_i = if next_line == "--", do: next_i + 1, else: next_i

    parse_lines(lines, next_i, acc2)
  end

  defp handle_generic_block(lines, i, acc, header) do
    end_idx = find_end_index(lines, i + 1, header)

    if end_idx == nil do
      if header == "--" do
        parse_lines(lines, i + 1, acc)
      else
        acc2 = put_block(acc, header, %{})
        parse_lines(lines, i + 1, acc2)
      end
    else
      body = Enum.slice(lines, i + 1, end_idx - (i + 1))

      if header in ["Glossary", "Purpose", "Description"] do
        acc2 = put_kv(acc, header, body)
        parse_lines(lines, end_idx + 1, acc2)
      else
        {parsed_body, _} = parse_lines(body, 0, %{})

        if String.ends_with?(header, "Pool") do
             # Transform list of objects to ID-keyed map
             # parsed_body is likely %{"Activity" => [list]}
             # We want to merge all lists found in parsed_body and key them by ID
             transformed_body = Enum.reduce(parsed_body, %{}, fn {_k, list}, acc_pool ->
                if is_list(list) do
                  Enum.reduce(list, acc_pool, fn item, acc_inner ->
                    id = Map.get(item, "ID")
                    if id do
                      Map.put(acc_inner, id, item)
                    else
                      acc_inner
                    end
                  end)
                else
                  acc_pool
                end
             end)
             acc2 = Map.put(acc, header, transformed_body)
             parse_lines(lines, end_idx + 1, acc2)
        else
             acc2 = put_block(acc, header, parsed_body)
             parse_lines(lines, end_idx + 1, acc2)
        end
      end
    end
  end

  defp find_end_index(lines, start_idx, header) do
    re = Regex.compile!("^End\\s+" <> Regex.escape(header) <> "\\s*$")
    find_end_index_regex(lines, start_idx, re)
  end

  defp find_end_index_regex(lines, start_idx, regex) do
    slice = Enum.slice(lines, start_idx..-1//1)
    case Enum.find_index(slice, fn l -> Regex.match?(regex, String.trim(l)) end) do
      nil -> nil
      offset -> start_idx + offset
    end
  end

  defp find_implicit_end(lines, start_idx, header_name) do
    slice = Enum.slice(lines, start_idx..-1//1)
    offset = Enum.find_index(slice, fn l ->
      t = String.trim(l)
      t == "--" or
      String.starts_with?(t, "End ") or
      Regex.match?(~r/^#{Regex.escape(header_name)}\s+\d+/, t)
    end)

    if offset, do: start_idx + offset, else: length(lines)
  end

  defp parse_parent_value(val) do
    if val == "None" do
      %{}
    else
      parts = String.split(val, ",")
      Enum.reduce(parts, %{}, fn part, acc ->
        part = String.trim(part)
        cond do
          String.contains?(part, ":") ->
            [k, v] = String.split(part, ":", parts: 2)
            Map.put(acc, String.trim(k), String.trim(v))
          true ->
            case Regex.run(~r/^(\w+)\s+(\d+)$/, part) do
              [_, k, v] -> Map.put(acc, k, v)
              _ -> acc
            end
        end
      end)
    end
  end

  defp parse_ai0_header(line) do
    # Parse: "AI0 Neutral Text;  Version:2.20;  12/25/2025  02:30.36"
    parts = String.split(line, ";")

    format = Enum.at(parts, 0, "") |> String.trim()
    version_part = Enum.at(parts, 1, "") |> String.trim()
    datetime_part = Enum.at(parts, 2, "") |> String.trim()

    version =
      case String.split(version_part, ":") do
        [_key, val] -> String.trim(val)
        _ -> ""
      end

    {date, time} =
      case String.split(datetime_part) do
        [d, t] -> {String.trim(d), String.trim(t)}
        [d] -> {String.trim(d), ""}
        _ -> {"", ""}
      end

    %{
      "Format" => format,
      "Version" => version,
      "DTM" => %{
        "Date" => date,
        "Time" => time
      }
    }
  end

  defp parse_assignment_items(lines) do
    do_parse_assignment_items(lines, 0, [])
  end

  defp do_parse_assignment_items(lines, i, acc) do
    if i >= length(lines) do
      acc
    else
      line = Enum.at(lines, i) |> String.trim()

      cond do
        line == "" -> do_parse_assignment_items(lines, i + 1, acc)

        # Match pattern: "Type ID (Name)"
        match = Regex.run(~r/^(\w+)\s+(\d+)\s+\((.*)\)$/, line) ->
          [_, type, id, name] = match

          item = %{
            "Type" => type,
            "ID" => id,
            "Name" => name
          }

          do_parse_assignment_items(lines, i + 1, acc ++ [item])

        true ->
          do_parse_assignment_items(lines, i + 1, acc)
      end
    end
  end

  defp parse_icom_items(lines) do
    do_parse_icom_items(lines, 0, [])
  end

  defp do_parse_icom_items(lines, i, acc) do
    if i >= length(lines) do
      acc
    else
      line = Enum.at(lines, i) |> String.trim()

      cond do
        line == "" -> do_parse_icom_items(lines, i + 1, acc)

        match = Regex.run(~r/^(\d+)\s+\((.*)\)(?:\s+#(\d+))?,?$/, line) ->
          [_, id, name | rest] = match
          internal_id = case rest do
            [val] when val != "" -> val
            _ -> nil
          end

          item = %{"ID" => id, "Name" => name}
          item = if internal_id, do: Map.put(item, "DBID", internal_id), else: item

          {updated_item, next_i} = parse_item_properties(lines, i + 1, item)
          do_parse_icom_items(lines, next_i, acc ++ [updated_item])

        true ->
          do_parse_icom_items(lines, i + 1, acc)
      end
    end
  end

  defp parse_item_properties(lines, i, item) do
    if i >= length(lines) do
      {item, i}
    else
      line = Enum.at(lines, i) |> String.trim()

      cond do
        Regex.match?(~r/^\d+\s+\(.*\)(?:\s+#\d+)?,?$/, line) -> {item, i}

        String.starts_with?(line, "ABC Data:") ->
          val = String.trim_leading(line, "ABC Data:") |> String.trim()
          # Handle "Time; 1" -> {"Time": "1"}
          parsed_val = if String.contains?(val, ";") do
             [k, v] = String.split(val, ";", parts: 2)
             %{String.trim(k) => String.trim(v)}
          else
             val
          end
          item = put_kv(item, "ABC Data", parsed_val)
          parse_item_properties(lines, i + 1, item)

        line == "ABC Data" ->
          end_idx = find_end_index(lines, i + 1, "ABC Data")
          if end_idx do
             body = Enum.slice(lines, i + 1, end_idx - (i + 1))
             # Parse body as lines, but we need to fix the "Key: Value" -> [{}, {}] issue
             # The issue is that `kv_line` parser produces `{:kv, key, value}`.
             # If value is empty string (because it was `Cost/Time: 0.0000`), `kv_line` might be misinterpreting or `put_kv` logic is weird.
             # Actually, looking at the user's output: "Cost/Time: 0.000000": [{}]
             # This means the parser saw "Cost/Time: 0.000000" as a KEY with empty value?
             # Ah, the `kv` parser: `key = ascii_string(...)`. If the line is `Cost/Time:  0.000000`,
             # and `key` allows `:`, then it might consume the whole thing as a key if the colon logic is flawed.
             # But `key` does NOT allow `:`.
             # Wait, `key` allows `.` and `\s`.
             # Let's look at `kv` definition again.
             # `key` = ascii_string([?A..?Z, ?a..?z, ?0..?9, ?_ , ?\-, ?., ?\s, ?#], min: 1)
             # `colon` = string(":")
             # If line is `Cost/Time:  0.000000`
             # `key` matches `Cost/Time`? No, `/` is not in the list.
             # So `kv` parser fails.
             # Then it falls back to `handle_generic_block` or `handle_implicit_block`.
             # If it falls back to `handle_generic_block`, it treats the whole line as a header?
             # "Cost/Time:  0.000000" -> header.
             # Then `put_block` puts `header` => `%{}` (empty map) or `[]`.
             # That explains `{"Cost/Time: 0.000000": [{}]}`.

             # We need to fix `key` definition to include `/` or handle this better.
             # AND we need to process the parsed body of ABC Data to flatten it.

             {parsed_abc, _} = parse_lines(body, 0, %{})

             # Flatten/Fix the parsed ABC Data map
             fixed_abc = Enum.reduce(parsed_abc, %{}, fn {k, v}, acc_abc ->
                # If k contains ":", it might be a misparsed KV
                # v might be [%{}] (list with empty map) because put_block wraps body in list
                if String.contains?(k, ":") and (v == [] or v == [%{}] or v == [{}]) do
                   [real_k, real_v] = String.split(k, ":", parts: 2)
                   Map.put(acc_abc, String.trim(real_k), String.trim(real_v))
                else
                   Map.put(acc_abc, k, v)
                end
             end)

             item = put_kv(item, "ABC Data", fixed_abc)
             parse_item_properties(lines, end_idx + 1, item)
          else
             parse_item_properties(lines, i + 1, item)
          end

        line == "Property List" ->
           end_idx = find_end_index(lines, i + 1, "Property List")
           if end_idx do
             body = Enum.slice(lines, i + 1, end_idx - (i + 1))
             {parsed_props, _} = parse_lines(body, 0, %{})
             # Flatten Property List inside Concept List items
             props = Map.get(parsed_props, "Property", [])
             props = if is_list(props), do: props, else: [props]

             item = put_kv(item, "Property List", props)
             parse_item_properties(lines, end_idx + 1, item)
           else
             parse_item_properties(lines, i + 1, item)
           end

        true ->
          parse_item_properties(lines, i + 1, item)
      end
    end
  end

  defp put_kv(acc, key, val) do
    cond do
      Map.has_key?(acc, key) ->
        existing = Map.get(acc, key)
        case existing do
          list when is_list(list) -> Map.put(acc, key, list ++ [val])
          other -> Map.put(acc, key, [other, val])
        end

      true -> Map.put(acc, key, val)
    end
  end

  defp put_block(acc, header, parsed_body) do
    key = header

    cond do
      Map.has_key?(acc, key) ->
        existing = Map.get(acc, key)
        new_list =
          case existing do
            list when is_list(list) -> list ++ [parsed_body]
            other -> [other, parsed_body]
          end

        Map.put(acc, key, new_list)

      true -> Map.put(acc, key, [parsed_body])
    end
  end

  # Helper functions for repository restructuring

  defp find_model_diagrams(diagrams, model_id) do
    # Find the context diagram for this model (Parent: empty map, ID matches model_id)
    context_diagram = Enum.find(diagrams, fn d ->
      d["Parent"] == %{} && d["ID"] == to_string(model_id)
    end)

    if context_diagram do
      # Find all diagrams that belong to this model (same top-level parent or descendants)
      context_id = context_diagram["ID"]
      Enum.filter(diagrams, fn d ->
        parent = d["Parent"]
        # Direct children of context diagram
        (is_map(parent) && parent["Diagram"] == context_id) ||
        # The context diagram itself
        d["ID"] == context_id
      end)
    else
      []
    end
  end

  defp extract_model_pools(data) do
    # For now, include all pools in each model
    pools = %{}
    pools = if Map.has_key?(data, "Activity Pool"), do: Map.put(pools, "Activities", Map.get(data, "Activity Pool")), else: pools
    pools = if Map.has_key?(data, "Concept Pool"), do: Map.put(pools, "Concepts", Map.get(data, "Concept Pool")), else: pools
    pools = if Map.has_key?(data, "Costdriver Pool"), do: Map.put(pools, "Costdrivers", Map.get(data, "Costdriver Pool")), else: pools
    pools = if Map.has_key?(data, "Note Pool"), do: Map.put(pools, "Notes", Map.get(data, "Note Pool")), else: pools
    pools
  end

  defp extract_model_lists(data, model_diagrams) do
    lists = %{}

    # Include only the diagrams for this model
    lists = Map.put(lists, "Diagrams", model_diagrams)

    # For assignments, include only the model assignment itself
    # (The numbering assignments will be computed per model)
    model_assignments = if Map.has_key?(data, "Assignment List") do
      all_assignments = flatten_list_wrapper(Map.get(data, "Assignment List"))
      # Find the model assignment that corresponds to these diagrams
      context_diagram = Enum.find(model_diagrams, fn d -> d["Parent"] == %{} end)
      if context_diagram do
        model_id = context_diagram["ID"]
        model_assignment = Enum.find(all_assignments, fn a ->
          a["Type"] == "Model" && a["ID"] == model_id
        end)
        if model_assignment, do: [model_assignment], else: []
      else
        []
      end
    else
      []
    end

    # Compute IDEF0 numbering for this model's diagrams
    model_lists = %{"Diagrams" => model_diagrams}
    numbering = compute_numbering(model_lists)

    # Add numbering as custom assignments
    assignments = model_assignments ++ [
      %{"Name" => "A-Numbers by Activity ID", "Type" => "Custom", "Activity" => numbering["Activity Numbers"]},
      %{"Name" => "ICOM Numbers by Diagram ID and Concept ID", "Type" => "Custom", "Diagram-Concept" => numbering["Concept Numbers"]}
    ]
    lists = Map.put(lists, "Assignments", assignments)

    # Objects in ABC - include all for now
    objects = if Map.has_key?(data, "Object in ABC List"), do: flatten_list_wrapper(Map.get(data, "Object in ABC List")), else: []
    lists = Map.put(lists, "Objects in ABC", objects)

    lists
  end
end
