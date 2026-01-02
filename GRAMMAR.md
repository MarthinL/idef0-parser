# AI0 Neutral Text Format Grammar

## Overview

This document describes the formal grammar for AI0 Neutral Text Format version 2.20, as implemented by the AI0 Parser. The grammar is expressed in Extended Backus-Naur Form (EBNF) and has been validated against working parser code.

The AI0 format exhibits some syntactic compromises due to historical parser conflicts, particularly around compound parent references. These design choices are documented where relevant.

We do not have access to the formal or original BNF for the file format. This is a work in progress, best effort reconstruction thereof, and very much up for debate and correction.


## File Structure

```
ai0_file ::= header_line block* end_of_file
```

## Header

```
header_line ::= "AI0 Neutral Text;" version_part ";" date_time_part

version_part ::= "Version:" version_number
date_time_part ::= date_part time_part
date_part ::= date
time_part ::= time
```

## Block Categories

AI0 blocks fall into three main categories based on their purpose and syntax:

### 1. Definition Blocks
Blocks that define new entities (activities, diagrams, concepts, etc.) in pools or lists. These have IDs in both start and end markers.

### 2. Container Blocks
Blocks that contain lists of existing items (properties, concepts, etc.). These do not have IDs in their markers.

### 3. Special Breakdown Blocks
Context-dependent breakdown syntax (see below).

## Definition Blocks

```
definition_block ::= activity_def | diagram_def | concept_def | note_def | source_def | costdriver_def

activity_def ::= "Activity" spaces id block_content "End" spaces "Activity" spaces id
diagram_def ::= "Diagram:" spaces id block_content "End" spaces "Diagram" spaces id
concept_def ::= "Concept" spaces id block_content "End" spaces "Concept" spaces id
note_def ::= "Note" spaces id block_content "End" spaces "Note" spaces id
source_def ::= "Source" spaces id block_content "End" spaces "Source" spaces id
costdriver_def ::= "Costdriver" spaces id block_content "End" spaces "Costdriver" spaces id
```

**Syntax Notes:**
- **Activity definitions** use spaces before ID: `Activity 1`
- **Diagram definitions** use colon before ID: `Diagram: 1`
- This "inverted" syntax avoids parsing conflicts with parent references (see below)

## Container Blocks

```
container_block ::= property_list | concept_list | note_list | source_list | assignment_list | activity_list | project_summary

property_list ::= "Property List" container_content "End" spaces "Property List"
concept_list ::= "Concept List" container_content "End" spaces "Concept List"
note_list ::= "Note List" container_content "End" spaces "Note List"
source_list ::= "Source List" container_content "End" spaces "Source List"
assignment_list ::= "Assignment List" container_content "End" spaces "Assignment List"
activity_list ::= "Activity List" container_content "End" spaces "Activity List"
project_summary ::= "Project Summary" project_content "End" spaces "Project Summary"

container_content ::= (item_block | kv_pair | multi_line_text_block | empty_line)*
project_content ::= (kv_pair | description_block | empty_line)*
```

**Syntax Notes:**
- Container blocks do not have IDs in their start/end markers
- They contain existing items by reference or metadata

## Special Breakdown Blocks

Breakdown blocks have context-dependent syntax:

```
breakdown_block ::= breakdown_hash_block | breakdown_colon_block

breakdown_hash_block ::= "Breakdown" spaces "#" id block_content "End" spaces "Breakdown" spaces "#" id
breakdown_colon_block ::= "Breakdown:" spaces id block_content "End" spaces "Breakdown" spaces id
```

**Context Usage:**
- `  #ID` syntax: Used within Breakdown Lists (definition context)
- `:  ID` syntax: Used within Concept Lists (reference context)

## Block Content

```
block_content ::= (kv_pair | sub_block | multi_line_text_block | empty_line)*

sub_block ::= container_block | icom_list_block

multi_line_text_block ::= text_block_type newline multi_line_text "End" spaces text_block_type
text_block_type ::= "Glossary" | "Purpose" | "Description"

multi_line_text ::= (text_line | empty_line)*
text_line ::= [^\n]*
```

## Special List Formats

### ICOM Lists (Input/Control/Output/Mechanism)

```
icom_list_block ::= icom_list_header icom_item* "End" spaces icom_list_type spaces "List"

icom_list_header ::= icom_list_type spaces "List"
icom_list_type ::= "Input" | "Output" | "Control" | "Mechanism"

icom_item ::= id spaces "(" name ")" (spaces "#" usage_tag)? item_properties?
item_properties ::= (abc_data_section | property_list_section)*

abc_data_section ::= "ABC Data" newline abc_content ("ABC Data" | implicit_end)
property_list_section ::= "Property List" newline property_content ("Property List" | implicit_end)

abc_content ::= (kv_pair | sub_block | empty_line)*
property_content ::= (kv_pair | sub_block | empty_line)*
```

### Assignments

```
assignment_item ::= type spaces id spaces "(" name ")"
```

## Key-Value Pairs

```
kv_pair ::= key ":" spaces value
key ::= [A-Za-z0-9_.\-#/\s]+
value ::= [^\n]*
```

**Special Keys:**
- `Parent`: Contains compound references (see below)

## Parent References

Parent specifications use compound syntax to avoid parsing conflicts:

```
parent_kv ::= "Parent:" spaces parent_value
parent_value ::= "None" | parent_compound
parent_compound ::= diagram_ref ("," spaces activity_ref)?

diagram_ref ::= "Diagram" spaces id
activity_ref ::= "Activity:" spaces id
```

**Historical Design Note:**
The "inverted" syntax (Diagram uses spaces, Activity uses colon) was chosen to avoid parser conflicts with compound parent references. If consistent colon syntax were used:

```
Parent: Diagram: 1, Activity: 23  ← Ambiguous (multiple colons + comma)
```

The compromise syntax ensures unambiguous parsing:

```
Parent: Diagram 1, Activity: 23   ← Clean separation
```

## Generic Blocks and Pools

```
generic_block ::= generic_header generic_content ("End" spaces generic_header | implicit_end)

generic_header ::= pool_header | list_header | other_header
pool_header ::= pool_type spaces "Pool"
pool_type ::= "Activity" | "Concept" | "Note" | "Costdriver" | "Source" | "Property" | "Unknown"

generic_content ::= (definition_block | kv_pair | sub_block | empty_line)*
```

## Termination Rules

```
implicit_end ::= (block_header | end_of_file)
end_marker ::= "End" spaces block_type spaces id
             | "End" spaces block_type
             | "End" spaces container_type
```

**Termination Hierarchy:**
1. **Explicit end marker** (preferred)
2. **Next block header** (implicit, with warning)
3. **End of file** (implicit)

## Basic Elements

```
id ::= digit+
usage_tag ::= digit+
name ::= [^)]*
type ::= [A-Za-z]+

empty_line ::= spaces newline
spaces ::= [ \t]*
newline ::= "\n" | "\r\n" | "\r"
digit ::= [0-9]
```

## Implementation Notes

- **Whitespace**: Significant only in multi-line text blocks (Glossary, Description, Purpose)
- **Strings**: Either rest-of-line after token, or enclosed in `()` parentheses
- **No escaping**: No quotes or escape sequences
- **Case sensitivity**: All keywords are case-sensitive
- **Parser validation**: The reference implementation enforces strict end marker matching with fallbacks for compatibility

## Grammar Validation

This grammar has been validated against:
- Working NimbleParsec parser implementation
- Multiple AI0 format files
- Edge cases including malformed inputs and format variations

The grammar captures the necessary syntactic compromises made for parser compatibility while maintaining format integrity.

## Pool and Block Fields

This section documents the key-value fields parsed within each pool type and block. These are extracted from `kv_pair` elements in block content.

### Activities
- `Account #`: String (optional)
- `Creator`: String
- `Date Created`: Date/time string
- `Glossary`: Multi-line text block
- `ID`: Integer
- `Last Modified`: Date/time string
- `Name`: String
- `Object Type`: String (e.g., "Activity")
- `User Ref`: String (optional)

### Concepts
- `Account #`: String (optional)
- `Breakdown List`: Sub-blocks for part-of relationships
- `Creator`: String
- `Date Created`: Date/time string
- `ID`: Integer
- `Last Modified`: Date/time string
- `Name`: String
- `Note List`: References to notes
- `Object Type`: String (e.g., "Resource", "Cost Object")
- `Source List`: References to sources

### Notes
- `Creator`: String
- `Date Created`: Date/time string
- `ID`: Integer
- `Last Modified`: Date/time string
- `Name`: String

### Properties
- `Name`: String
- Additional fields vary by property type

### Costdrivers
- `Creator`: String
- `Date Created`: Date/time string
- `Driver Type`: String (e.g., "PERCENTAGE")
- `ID`: Integer
- `Last Modified`: Date/time string
- `Name`: String
- `Use Type`: String (e.g., "UNIQUE")

### Sources
- `Creator`: String
- `Date Created`: Date/time string
- `ID`: Integer
- `Last Modified`: Date/time string
- `Name`: String
- `Note List`: References to notes
- `Source List`: References to other sources

### Unknowns
- `Creator`: String
- `Date Created`: Date/time string
- `ID`: Integer
- `Last Modified`: Date/time string
- `Name`: String
- `Note List`: References to notes
- `Source List`: References to sources

### Diagrams
- `Activity List`: Sub-blocks for activities
- `Breakdown List`: Sub-blocks for breakdowns
- `Concept List`: Lists of concepts with usage tags
- `Creator`: String
- `Date Created`: Date/time string
- `Description`: Multi-line text block
- `ID`: Integer
- `Last Modified`: Date/time string
- `Name`: String
- `Note List`: References to notes
- `Parent`: Compound reference (see Parent References)
- `Purpose`: Multi-line text block
- `Review Status`: String (e.g., "Recommended")
- `Revision Number`: String (e.g., "1")

### Project Summary
- `Creator`: String
- `Date Created`: Date/time string
- `Description`: Multi-line text block
- `Last Modified`: Date/time string
- `Used At`: String (optional)

## UsageTag Semantics

UsageTag (#N) is a row identifier from the export query, used for disambiguating reused pool items across diagrams/models. It appears in ICOM lists and activity references to ensure unique identification when the same item is used multiple times.

## Parser Features

The AI0 Parser includes semantic processing beyond the core grammar:

- **Model Abbreviation Extraction**: Automatically extracts abbreviations from notes matching "Model Abbreviation: XXX=Model Name" and adds them to model JSON output.
- **Filtering Options**: CLI flags (--no-abc, --no-prop, --skip-empty-lists, --no-fix-abbr) for customizing JSON output by removing specific data sections.