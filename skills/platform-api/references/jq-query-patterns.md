# jq Query Patterns Reference

Comprehensive jq patterns for querying the Genesys Cloud Platform API schema.

**Related**: Core workflow in SKILL.md, search examples in `search-operations.md`

## Table of Contents

- [Performance Best Practices](#performance-best-practices)
- [Advanced Filtering Techniques](#advanced-filtering-techniques)
- [Variable Chaining Patterns](#variable-chaining-patterns)
- [Grouping and Aggregation](#grouping-and-aggregation)
- [Debugging and Testing](#debugging-and-testing)
- [Extraction Patterns](#extraction-patterns)
- [Common Definition Name Extraction](#common-definition-name-extraction)

## Performance Best Practices

### Use Raw Output for Readability

```bash
# Pretty print (default)
jq '.definitions["Queue"]' "$SCHEMA"

# Raw output (no quotes, easier to read)
jq -r '.paths | keys | .[]' "$SCHEMA"

# Compact output (single line)
jq -c '.definitions["Queue"]' "$SCHEMA"
```

### Test Query Size First

```bash
# ALWAYS count results before fetching to avoid overwhelming output
jq -r '.paths | keys | map(select(test("conversation"; "i"))) | length' "$SCHEMA"

# Then fetch limited results based on count
jq -r '.paths | keys | map(select(test("conversation"; "i"))) | .[0:15] | .[]' "$SCHEMA"
```

### Build Queries Incrementally

```bash
# Step 1: Get the structure
jq '.paths["/api/v2/routing/queues/{queueId}"]["get"] | keys' "$SCHEMA"

# Step 2: Extract specific field
jq '.paths["/api/v2/routing/queues/{queueId}"]["get"].parameters' "$SCHEMA"

# Step 3: Filter and transform
jq '.paths["/api/v2/routing/queues/{queueId}"]["get"].parameters | map(select(.required == true))' "$SCHEMA"
```

## Advanced Filtering Techniques

### Filter by HTTP Method

```bash
# All POST operations (create)
jq -r '.paths | to_entries | map(select(.value.post != null)) | map(.key) | .[]' "$SCHEMA"

# All PUT operations (update)
jq -r '.paths | to_entries | map(select(.value.put != null)) | map(.key) | .[]' "$SCHEMA"

# All DELETE operations
jq -r '.paths | to_entries | map(select(.value.delete != null)) | map(.key) | .[]' "$SCHEMA"

# All PATCH operations
jq -r '.paths | to_entries | map(select(.value.patch != null)) | map(.key) | .[]' "$SCHEMA"
```

### Filter by Tags

```bash
# Get all tags for an endpoint
jq '.paths["/api/v2/routing/queues/{queueId}"]["get"].tags' "$SCHEMA"

# Find all operations with specific tag
jq -r '.paths | to_entries | map({path: .key, ops: (.value | to_entries | map(select(.value.tags != null and (.value.tags | index("Routing")) != null)) | map({method: .key, operationId: .value.operationId}))}) | map(select(.ops | length > 0)) | .[]' "$SCHEMA"
```

### Filter by Permissions

```bash
# Find operations requiring specific permission
jq -r '.paths | to_entries | map({path: .key, ops: (.value | to_entries | map(select(.value."x-inin-requires-permissions".permissions != null and (.value."x-inin-requires-permissions".permissions | index("routing:queue:view")) != null)) | map({method: .key, operationId: .value.operationId}))}) | map(select(.ops | length > 0)) | .[]' "$SCHEMA"

# Find operations requiring ANY permissions vs ALL
jq -r '.paths | to_entries | map({path: .key, ops: (.value | to_entries | map(select(.value."x-inin-requires-permissions".type == "ANY")) | map({method: .key, operationId: .value.operationId, permissions: .value."x-inin-requires-permissions".permissions}))}) | map(select(.ops | length > 0)) | .[0:5]' "$SCHEMA"

# Get all permissions for a resource type
jq '.paths | to_entries | map(select(.key | test("/routing/queues"))) | map({
  path: .key,
  operations: (.value | to_entries | map({
    method: .key,
    operationId: .value.operationId,
    permissions: .value."x-inin-requires-permissions"
  }))
})' "$SCHEMA"
```

### Find Operations with Body Parameters

```bash
# Find operations accepting body parameters
jq -r '.paths | to_entries | map({path: .key, ops: (.value | to_entries | map(select(.value.parameters != null and (.value.parameters | map(select(.in == "body")) | length > 0))) | map({method: .key, operationId: .value.operationId}))}) | map(select(.ops | length > 0)) | .[0:3]' "$SCHEMA"

# Get body parameter schema reference
jq -r '.paths["/api/v2/routing/queues/{queueId}"]["put"].parameters[] | select(.in == "body") | .schema."$ref"' "$SCHEMA"
```

### Find CRUD Operations for a Resource

```bash
# Find all queue CRUD operations
jq '.paths | to_entries | map(select(.key | test("/routing/queues"))) | map({
  path: .key,
  methods: (.value | keys),
  operations: (.value | to_entries | map({method: .key, operationId: .value.operationId, summary: .value.summary}))
})' "$SCHEMA"
```

## Variable Chaining Patterns

### Extract and Resolve References

```bash
# Method 1: Using sed to extract definition name
REF=$(jq -r '.paths["/api/v2/routing/queues/{queueId}"]["get"].responses["200"].schema."$ref"' "$SCHEMA" | sed 's|#/definitions/||')
jq --arg ref "$REF" '.definitions[$ref]' "$SCHEMA"

# Method 2: Using jq to extract definition name
REF=$(jq -r '.paths["/api/v2/routing/queues/{queueId}"]["get"].responses["200"].schema."$ref" | split("/")[2]' "$SCHEMA")
jq --arg ref "$REF" '.definitions[$ref]' "$SCHEMA"
```

### Resolve Nested References

```bash
# Extract nested reference from a property
NESTED_REF=$(jq -r '.definitions["Queue"].properties["division"]."$ref"' "$SCHEMA" | sed 's|#/definitions/||')
jq --arg ref "$NESTED_REF" '.definitions[$ref]' "$SCHEMA"

# Find all properties with references
jq '.definitions["Queue"].properties | to_entries | map(select(.value."$ref" != null)) | map({property: .key, ref: .value."$ref"})' "$SCHEMA"
```

### Compare Input and Output Schemas

```bash
# Get both input and output schemas for an operation
jq '.paths["/api/v2/routing/queues/{queueId}"]["put"] | {
  operationId,
  inputSchema: (.parameters[] | select(.in == "body") | .schema."$ref"),
  outputSchema: .responses["200"].schema."$ref"
}' "$SCHEMA"
```

## Grouping and Aggregation

### Group Parameters by Location

```bash
# Group parameters by location (path, query, body)
jq '.paths["/api/v2/routing/queues/{queueId}"]["put"].parameters | group_by(.in) | map({location: .[0].in, count: length})' "$SCHEMA"
```

### Group Endpoints by Base Path

```bash
# Group endpoints by base path
jq -r '.paths | keys | map(split("/")[1:4] | join("/")) | unique | .[]' "$SCHEMA"
```

### Find Definitions with Specific Properties

```bash
# Find definitions with a "name" property
jq -r '.definitions | to_entries | map(select(.value.properties.name != null)) | map(.key) | .[]' "$SCHEMA"
```

## Debugging and Testing

### Test Path Exists

```bash
# Check if path exists in schema
jq '.paths | has("/api/v2/routing/queues/{queueId}")' "$SCHEMA"

# Check if specific method exists
jq '.paths["/api/v2/routing/queues/{queueId}"] | has("put")' "$SCHEMA"
```

### Handle Null Values

```bash
# Use alternative operator for null values
jq '.paths["/api/v2/routing/queues/{queueId}"]["get"]["x-inin-requires-permissions"] // "No permissions found"' "$SCHEMA"

# Check if permissions is null
jq '.paths["/api/v2/routing/queues/{queueId}"]["get"]["x-inin-requires-permissions"] == null' "$SCHEMA"
```

### Inspect Structure

```bash
# Get all available keys for an operation
jq '.paths["/api/v2/routing/queues/{queueId}"]["get"] | keys' "$SCHEMA"

# Get type of a value
jq '.paths["/api/v2/routing/queues/{queueId}"]["get"].parameters | type' "$SCHEMA"
```

## Extraction Patterns

### Extract Parameter Details

```bash
# Extract parameter details for field definitions
jq '.paths["/api/v2/routing/queues/{queueId}"]["put"].parameters[] | select(.in == "body") | {
  name,
  required,
  description,
  schemaRef: .schema."$ref"
}' "$SCHEMA"

# Get only required parameters
jq '.paths["/api/v2/routing/queues/{queueId}"]["get"].parameters | map(select(.required == true))' "$SCHEMA"
```

### Extract Response Codes and Descriptions

```bash
# Get all response codes
jq '.paths["/api/v2/routing/queues/{queueId}"]["get"].responses | keys' "$SCHEMA"

# Get response descriptions
jq '.paths["/api/v2/routing/queues/{queueId}"]["get"].responses | to_entries | map({code: .key, description: .value.description})' "$SCHEMA"
```

### Extract Complete Operation Metadata

```bash
# Full operation details for implementation
jq '.paths["/api/v2/routing/queues/{queueId}"]["get"] | {
  operationId,
  summary,
  description,
  permissions: ."x-inin-requires-permissions",
  parameters: [.parameters[] | {name, in, required, type, schema: .schema?}],
  responses: .responses
}' "$SCHEMA"
```

## Common Definition Name Extraction

```bash
# Using sed (faster, simpler)
echo "#/definitions/Queue" | sed 's|#/definitions/||'

# Using jq (more portable)
echo '"#/definitions/Queue"' | jq -r 'split("/")[2]'

# Using bash parameter expansion
REF="#/definitions/Queue"
echo "${REF#*/definitions/}"
```
