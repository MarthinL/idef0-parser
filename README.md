# AI0 Parser

A comprehensive Elixir parser for IDEF0 AI0 neutral text format files, converting legacy IDEF0 models to structured JSON and Elixir data structures.

## Overview

This tool parses IDEF0 AI0 text files (as exported from tools like KBSI's AI0Win) and converts them into clean, structured Elixir maps and JSON output. It's designed to preserve complete model fidelity while enabling modern workflows for IDEF0 documentation and governance.

**Current Status**: Parser is fully functional with configurable output filtering. Unparser (reverse conversion) is planned for future phases to enable complete round-trip workflows.

## Context

IDEF0, despite being deprecated as a federal standard, remains genuinely useful for hierarchical activity modeling and complex system analysis. With KBSI's tooling unmaintained and no modern alternatives, this project addresses the gap by:

1. **Immediate use case**: Converting legacy AI0Win-exported files to JSON for documentation and governance
2. **Long-term vision**: Foundation for a modern web-based IDEF0 modeller (leveraging HTML5 grid layout advantages over legacy Java/SVG approaches)

## Features

### Current Capabilities
- **Complete AI0 parsing**: All IDEF0 elements (activities, concepts, diagrams, ICOM lists, hierarchies)
- **IDEF0 numbering**: Automatic computation of A-numbers for activities and I/C/O/M numbers for boundary concepts on decomposition diagrams
- **Structured output**: Pools (ID-keyed maps) and Lists (flat arrays) with preserved ordering
- **Flexible filtering**: 
  - `--no-abc`: Exclude ABC Data and Objects in ABC list
  - `--no-prop`: Exclude Property List fields
  - Both flags can be combined
- **JSON export**: Pretty-printed JSON for integration into documentation systems
- **Elixir-first**: Internal representation as Elixir maps/lists, JSON is secondary export format

### Planned Capabilities
- **Unparser**: Regenerate AI0 TXT format from Elixir/JSON structures
- **Format validation**: Ensure generated files meet AI0 specification
- **Web modeller**: HTML5-based IDEF0 diagram editor (long-term)

## Installation

### Requirements
- Elixir 1.14+
- Erlang/OTP 25+
- Mix

### Setup
```bash
cd ai0_parser
mix deps.get
mix escript.build
```

This creates an `ai0_parser` executable.

## Usage

### Basic Usage
```bash
./ai0_parser <file.txt>
```

Outputs full JSON with all data to stdout.

### Filtering Options
```bash
# Exclude ABC Data and Objects in ABC list
./ai0_parser --no-abc <file.txt>

# Exclude Property Lists
./ai0_parser --no-prop <file.txt>

# Combine filters
./ai0_parser --no-abc --no-prop <file.txt>
```

### Output Redirection
```bash
./ai0_parser input.txt > output.json
./ai0_parser --no-abc input.txt > output_no_abc.json
```

## Interactive Usage (Inspection)

To load and inspect the Elixir structures interactively:

1. Start the interactive shell:
   ```bash
   iex -S mix
   ```

2. Load and parse a file:
   ```elixir
   # Read the file
   {:ok, content} = File.read("../IMP.TXT")

   # Parse into Elixir Map
   data = Ai0Parser.parse_string(content)

   # Inspect the structure
   Map.keys(data)
   data["Source"]["Pools"]["Activities"]["1"]
   ```

## Project Structure

```
.
├── lib/
│   ├── ai0_parser.ex           # Main module wrapper
│   ├── ai0_parser/
│   │   ├── cli.ex              # CLI and filtering logic
│   │   └── parser.ex           # AI0 text format parser
├── mix.exs                      # Mix project definition
├── .gitignore
├── LICENSE                      # Placeholder (rights reserved)
└── README.md                    # This file
```

## Data Model

### Structure
```
Source
├── Header
│   ├── Format: "AI0 Neutral Text"
│   ├── Version: "2.20"
│   └── DTM
│       ├── Date: "12/25/2025"
│       └── Time: "02:30.36"
├── Pools (ID-keyed maps)
│   ├── Activities
│   ├── Concepts
│   ├── Costdrivers
│   └── Notes
├── Lists (flat arrays)
│   ├── Assignments
│   ├── Diagrams
│   └── Objects in ABC
└── Numbering
    ├── Activity Numbers (ID -> A-number)
    └── Concept Numbers (diagram ID -> concept ID -> I/C/O/M number)
```

### Key Design Decisions
- **Pools**: ID-keyed maps for quick lookup and bidirectional references
- **Lists**: Flat arrays preserve insertion order (critical for diagram element sequencing)
- **Numbering**: Computed IDEF0 display numbers (A-numbers, I/C/O/M numbers) added post-parsing for diagram rendering
- **No artificial nesting**: Format is fundamentally flat; hierarchies are represented via parent/child ID references
- **Complete field preservation**: All original fields present, including ABC Data and Property Lists (can be filtered at export)

## Format Notes

### AI0 Text Format Specifics
- **Block structure**: `Type ID #UsageTag ... End Type ID`
- **ABC Data**: Single KV pairs inline (`ABC Data: Time; 1`), multiple KV pairs in block format
- **ICOM Lists**: Control List, Input List, Output List, Mechanism List preserve item order
- **Diagrams**: Contain references to activities from Activity Pool, organized hierarchically via parent diagram reference
- **No explicit nesting**: All complexity expressed through ID references across flat pools

### Grammar Specification

For a complete formal specification of the AI0 Neutral Text Format grammar, including EBNF notation, syntax compromises, and parsing rules, see [GRAMMAR.md](GRAMMAR.md).

This document provides the authoritative grammar used by the parser implementation, with detailed explanations of the format's historical design decisions and edge cases.

## Development

### Running Tests
```bash
mix test
```

### Building Executable
```bash
mix escript.build
```

## Roadmap

### Phase 1 (Current)
- ✅ Complete AI0 parser
- ✅ JSON export
- ✅ Output filtering (--no-abc, --no-prop)

### Phase 2
- 🔄 Format specification documentation
- 🔄 Unparser (TXT regeneration)
- ⬜ Round-trip validation tests

### Phase 3
- ⬜ Web-based IDEF0 modeller UI
- ⬜ Diagram rendering (SVG generation)
- ⬜ Collaborative editing capabilities

## Contributing

This project is currently under evaluation for IP and licensing implications. Contributions are welcome once the license is finalized.

For now, inquiries regarding participation should be directed to the maintainer.

## References

- [IDEF0 Specification](https://en.wikipedia.org/wiki/IDEF0)
- KBSI AI0Win (legacy reference implementation)
- IDEF0 modeling theory and practice

## License

**PLACEHOLDER LICENSE** - All rights reserved pending legal and commercial evaluation.

See [LICENSE](LICENSE) for details.

---

**Maintainer**: Marthin Laubscher

**Last Updated**: December 30, 2025
