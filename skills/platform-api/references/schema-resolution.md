# Schema Resolution Reference

Comprehensive guide to resolving definition references in the Genesys Cloud Platform API schema.

**Related**: Core workflow step 3 in SKILL.md, variable chaining in `jq-query-patterns.md`

## Table of Contents

- [Understanding $ref References](#understanding-ref-references)
- [Resolve Definition References](#resolve-definition-references)
- [Get Property Details](#get-property-details)
- [Resolve Nested References](#resolve-nested-references)
- [List All Definitions](#list-all-definitions)
- [Practical Resolution Examples](#practical-resolution-examples)
- [Array and Object Handling](#array-and-object-handling)
- [Tips for Schema Resolution](#tips-for-schema-resolution)

## Understanding $ref References

The schema uses JSON Schema `$ref` to reference reusable definitions:

```json
{
  "schema": {
    "$ref": "#/definitions/Queue"
  }
}
```

This means "use the definition named 'Queue' from the definitions section."

## Resolve Definition References

### Direct Definition Access

```bash
# Get definition directly by name
jq '.definitions["Queue"]' "$SCHEMA"

# Get definition properties
jq '.definitions["Queue"].properties | keys' "$SCHEMA"

# Get required fields for a definition
jq '.definitions["Queue"].required' "$SCHEMA"
```

### Extract Definition Name from $ref

```bash
# Method 1: Using sed (fastest)
echo "#/definitions/Queue" | sed 's|#/definitions/||'

# Method 2: Using jq split
echo '"#/definitions/Queue"' | jq -r 'split("/")[2]'

# Method 3: Using bash parameter expansion
REF="#/definitions/Queue"
echo "${REF#*/definitions/}"
```

### Resolve $ref from Response Schema

```bash
# Step 1: Get the $ref
jq -r '.paths["/api/v2/routing/queues/{queueId}"]["get"].responses["200"].schema."$ref"' "$SCHEMA"
# Output: #/definitions/Queue

# Step 2: Extract definition name
REF=$(jq -r '.paths["/api/v2/routing/queues/{queueId}"]["get"].responses["200"].schema."$ref"' "$SCHEMA" | sed 's|#/definitions/||')

# Step 3: Resolve the definition
jq --arg ref "$REF" '.definitions[$ref]' "$SCHEMA"
```

### Resolve $ref from Body Parameter

```bash
# Step 1: Get body parameter schema reference
jq -r '.paths["/api/v2/routing/queues/{queueId}"]["put"].parameters[] | select(.in == "body") | .schema."$ref"' "$SCHEMA"
# Output: #/definitions/QueueRequest

# Step 2: Resolve it
jq '.definitions["QueueRequest"]' "$SCHEMA"
```

## Get Property Details

### Extract Specific Property Information

```bash
# Get a single property
jq '.definitions["Queue"].properties["name"]' "$SCHEMA"

# Get property type
jq -r '.definitions["Queue"].properties["name"].type' "$SCHEMA"

# Get property description
jq -r '.definitions["Queue"].properties["name"].description' "$SCHEMA"
```

### List All Properties

```bash
# List property names only
jq '.definitions["Queue"].properties | keys' "$SCHEMA"

# List properties with types
jq '.definitions["Queue"].properties | to_entries | map({name: .key, type: .value.type})' "$SCHEMA"

# List properties with types and descriptions
jq '.definitions["Queue"].properties | to_entries | map({
  name: .key,
  type: .value.type,
  description: .value.description,
  required: (.key as $k | [.][] | select(.key == $k) | .value.required // false)
})' "$SCHEMA"
```

### Complete Definition Summary

```bash
# Full definition overview
jq '.definitions["Queue"] | {
  type,
  description,
  required,
  propertyCount: (.properties | length),
  properties: (.properties | keys)
}' "$SCHEMA"
```

## Resolve Nested References

### Find Properties with $ref

```bash
# Get a property that has a $ref
jq '.definitions["Queue"].properties["division"]' "$SCHEMA"

# Extract the nested $ref
jq -r '.definitions["Queue"].properties["division"]."$ref"' "$SCHEMA"
# Output: #/definitions/WritableDivision
```

### Resolve Nested Definitions

```bash
# Step 1: Extract nested reference
NESTED_REF=$(jq -r '.definitions["Queue"].properties["division"]."$ref"' "$SCHEMA" | sed 's|#/definitions/||')

# Step 2: Resolve the nested definition
jq --arg ref "$NESTED_REF" '.definitions[$ref]' "$SCHEMA"
```

### Find All Properties with References

```bash
# List all properties that have $ref
jq '.definitions["Queue"].properties | to_entries | map(select(.value."$ref" != null)) | map({property: .key, ref: .value."$ref"})' "$SCHEMA"
```

### Recursively Explore References

```bash
# Example: Explore Queue -> Division -> nested refs
# Step 1: Start with Queue
jq '.definitions["Queue"].properties | keys' "$SCHEMA"

# Step 2: Find properties with $ref
jq '.definitions["Queue"].properties | to_entries | map(select(.value."$ref" != null)) | map({property: .key, ref: .value."$ref"})' "$SCHEMA"

# Step 3: Resolve one (e.g., division)
DIVISION_REF=$(jq -r '.definitions["Queue"].properties["division"]."$ref"' "$SCHEMA" | sed 's|#/definitions/||')
jq --arg ref "$DIVISION_REF" '.definitions[$ref]' "$SCHEMA"

# Step 4: Continue exploring nested refs in Division
jq --arg ref "$DIVISION_REF" '.definitions[$ref].properties | to_entries | map(select(.value."$ref" != null))' "$SCHEMA"
```

## List All Definitions

### Basic Listing

```bash
# Count definitions
jq '.definitions | length' "$SCHEMA"
# Output: 4305

# List definition names (use with caution - 4,305 definitions!)
jq '.definitions | keys | .[]' "$SCHEMA"
```

### Search Definitions

```bash
# Search definitions by name (case-insensitive, limited)
jq -r '.definitions | keys | map(select(test("Queue"; "i"))) | .[0:15] | .[]' "$SCHEMA"

# Find definitions with specific properties
jq -r '.definitions | to_entries | map(select(.value.properties.name != null)) | map(.key) | .[0:15] | .[]' "$SCHEMA"

# Find definitions with enum values
jq -r '.definitions | to_entries | map(select(.value.enum != null)) | map(.key) | .[]' "$SCHEMA"
```

## Practical Resolution Examples

### Example 1: Complete Queue Schema Resolution

```bash
# Step 1: Get Queue definition
jq '.definitions["Queue"]' "$SCHEMA"

# Step 2: Get required fields
jq '.definitions["Queue"].required' "$SCHEMA"

# Step 3: Get property count
jq '.definitions["Queue"].properties | length' "$SCHEMA"

# Step 4: Find properties with nested refs
jq '.definitions["Queue"].properties | to_entries | map(select(.value."$ref" != null)) | map({property: .key, ref: .value."$ref"})' "$SCHEMA"

# Step 5: Resolve a nested ref (division)
jq '.definitions["WritableDivision"]' "$SCHEMA"
```

### Example 2: Understanding Request/Response Schemas

```bash
# Get PUT operation for queue update
jq '.paths["/api/v2/routing/queues/{queueId}"]["put"]' "$SCHEMA"

# Extract input schema reference
INPUT_REF=$(jq -r '.paths["/api/v2/routing/queues/{queueId}"]["put"].parameters[] | select(.in == "body") | .schema."$ref"' "$SCHEMA" | sed 's|#/definitions/||')

# Extract output schema reference
OUTPUT_REF=$(jq -r '.paths["/api/v2/routing/queues/{queueId}"]["put"].responses["200"].schema."$ref"' "$SCHEMA" | sed 's|#/definitions/||')

# Compare input vs output
echo "Input: $INPUT_REF"
echo "Output: $OUTPUT_REF"

# Resolve both
jq --arg ref "$INPUT_REF" '.definitions[$ref] | {type, required, properties: (.properties | keys)}' "$SCHEMA"
jq --arg ref "$OUTPUT_REF" '.definitions[$ref] | {type, required, properties: (.properties | keys)}' "$SCHEMA"
```

### Example 3: Building Field Definitions from Schema

```bash
# Goal: Extract all required fields for QueueRequest
# Step 1: Get the definition
jq '.definitions["QueueRequest"]' "$SCHEMA"

# Step 2: Get required fields
jq '.definitions["QueueRequest"].required' "$SCHEMA"

# Step 3: For each required field, get details
jq '.definitions["QueueRequest"] | .required as $req | .properties | to_entries | map(select(.key as $k | $req | index($k) != null)) | map({
  name: .key,
  type: .value.type,
  description: .value.description,
  ref: .value."$ref"
})' "$SCHEMA"

# Step 4: For fields with $ref, resolve them
# (repeat resolution process for each ref)
```

### Example 4: Finding All Usages of a Definition

```bash
# Find which endpoints use the Queue definition in responses
jq -r '.paths | to_entries | map({
  path: .key,
  operations: (.value | to_entries | map(select(.value.responses["200"].schema."$ref" == "#/definitions/Queue")) | map(.key))
}) | map(select(.operations | length > 0)) | .[]' "$SCHEMA"

# Find which endpoints use Queue in request body
jq -r '.paths | to_entries | map({
  path: .key,
  operations: (.value | to_entries | map(select(.value.parameters != null and (.value.parameters | map(select(.schema."$ref" == "#/definitions/QueueRequest")) | length > 0))) | map(.key))
}) | map(select(.operations | length > 0)) | .[]' "$SCHEMA"
```

## Array and Object Handling

### Arrays of References

```bash
# When a property is an array with items that have $ref
jq '.definitions["QueueEntityListing"].properties["entities"]' "$SCHEMA"

# Extract the array item reference
jq -r '.definitions["QueueEntityListing"].properties["entities"].items."$ref"' "$SCHEMA"
```

### Additional Properties

```bash
# Check if definition allows additional properties
jq '.definitions["Queue"].additionalProperties' "$SCHEMA"

# Get additional properties schema if defined
jq '.definitions["SomeDefinition"].additionalProperties."$ref"' "$SCHEMA"
```

## Tips for Schema Resolution

1. **Always extract the definition name** from `$ref` before using it
2. **Check for nested references** in properties - definitions often reference other definitions
3. **Use required array** to identify mandatory fields
4. **Look at both request and response schemas** for complete operation understanding
5. **Test resolution incrementally** - verify each step works before moving to the next
6. **Cache frequently used definitions** in variables when doing multiple lookups
