# Search Operations Reference

Comprehensive search patterns for finding endpoints in the Genesys Cloud Platform API schema.

**Related**: Core workflow step 1 in SKILL.md, advanced queries in `jq-query-patterns.md`

## Table of Contents

- [Critical Rule: ALWAYS Limit Results](#critical-rule-always-limit-results)
- [Search by Keyword](#search-by-keyword)
- [Search by Resource Type](#search-by-resource-type)
- [Count Before Fetch Pattern](#count-before-fetch-pattern)
- [List All Endpoints](#list-all-endpoints)
- [Search Definitions](#search-definitions)
- [Combining Search Criteria](#combining-search-criteria)
- [Practical Search Examples](#practical-search-examples)
- [Tips for Effective Searching](#tips-for-effective-searching)

## Critical Rule: ALWAYS Limit Results

The schema contains 1,900+ endpoints. **ALWAYS use `.[0:15]` or similar limits** to avoid overwhelming output.

```bash
# ✅ CORRECT: Limited search
jq -r '.paths | keys | map(select(test("queue"; "i"))) | .[0:15] | .[]' "$SCHEMA"

# ❌ WRONG: Unlimited search (will return too many results)
jq -r '.paths | keys | map(select(test("queue"; "i"))) | .[]' "$SCHEMA"
```

## Search by Keyword

### Basic Case-Insensitive Search

```bash
# Search for "queue" anywhere in path (limit to 15 results)
jq -r '.paths | keys | map(select(test("queue"; "i"))) | .[0:15] | .[]' "$SCHEMA"

# Search for "user" anywhere in path
jq -r '.paths | keys | map(select(test("user"; "i"))) | .[0:15] | .[]' "$SCHEMA"

# Search for "conversation" anywhere in path
jq -r '.paths | keys | map(select(test("conversation"; "i"))) | .[0:15] | .[]' "$SCHEMA"
```

### Exact Path Segment Match

```bash
# Find endpoints containing exact path segment
jq -r '.paths | keys | map(select(test("/routing/queues/"))) | .[0:15] | .[]' "$SCHEMA"

# Find endpoints with /users/ in path
jq -r '.paths | keys | map(select(test("/users/"))) | .[0:15] | .[]' "$SCHEMA"
```

### Pattern-Based Search

```bash
# Find endpoints ending with specific pattern
jq -r '.paths | keys | map(select(test("queues/\\{queueId\\}$"))) | .[]' "$SCHEMA"

# Find endpoints starting with specific pattern
jq -r '.paths | keys | map(select(test("^/api/v2/routing"))) | .[0:15] | .[]' "$SCHEMA"

# Find endpoints with path parameters
jq -r '.paths | keys | map(select(test("\\{[^}]+\\}"))) | .[0:15] | .[]' "$SCHEMA"
```

## Search by Resource Type

### Find All Endpoints for a Resource

```bash
# All queue endpoints
jq -r '.paths | keys | map(select(test("/routing/queues"))) | .[]' "$SCHEMA"

# All user endpoints
jq -r '.paths | keys | map(select(test("/users"))) | .[]' "$SCHEMA"

# All conversation endpoints
jq -r '.paths | keys | map(select(test("/conversations"))) | .[]' "$SCHEMA"

# All group endpoints
jq -r '.paths | keys | map(select(test("/groups"))) | .[]' "$SCHEMA"
```

### Common Query Patterns

When users ask "find all X" or "get specific X", use these patterns:

```bash
# "find all users" → Search for collection endpoint
jq -r '.paths | keys | map(select(test("/api/v2/users$"))) | .[]' "$SCHEMA"

# "get a specific user" → Search for item endpoint
jq -r '.paths | keys | map(select(test("/api/v2/users/\\{userId\\}"))) | .[]' "$SCHEMA"

# "update queue" → Look for PUT/PATCH on item endpoint
jq -r '.paths | keys | map(select(test("/routing/queues/\\{queueId\\}$"))) | .[]' "$SCHEMA"

# "create queue" → Look for POST on collection endpoint
jq -r '.paths | keys | map(select(test("/routing/queues$"))) | .[]' "$SCHEMA"
```

## Count Before Fetch Pattern

Always count results first to decide on appropriate limit:

```bash
# Step 1: Count matching endpoints
jq -r '.paths | keys | map(select(test("conversation"; "i"))) | length' "$SCHEMA"

# Step 2: Based on count, fetch limited results
jq -r '.paths | keys | map(select(test("conversation"; "i"))) | .[0:15] | .[]' "$SCHEMA"

# If count is very high (100+), use stricter pattern:
jq -r '.paths | keys | map(select(test("/conversations/"))) | .[0:15] | .[]' "$SCHEMA"
```

## List All Endpoints

### Basic Listing

```bash
# List all endpoint paths (NO LIMIT - use carefully!)
jq -r '.paths | keys | .[]' "$SCHEMA"

# Count total endpoints
jq '.paths | length' "$SCHEMA"
```

### List with Summary Information

```bash
# List endpoints with operation count
jq '.paths | to_entries | map({
  path: .key,
  methodCount: (.value | keys | length),
  methods: (.value | keys)
}) | .[0:10]' "$SCHEMA"

# Get summary of operations
jq '.paths | to_entries | map(select(.key | test("/users"))) | map({
  path: .key,
  operations: (.value | to_entries | map({method: .key, id: .value.operationId, summary: .value.summary}))
}) | .[0:5]' "$SCHEMA"
```

## Search Definitions

### Find Definitions by Name

```bash
# Count total definitions
jq '.definitions | length' "$SCHEMA"

# List all definition names (4,305 definitions - use with caution!)
jq '.definitions | keys | .[]' "$SCHEMA"

# Search definitions by name (case-insensitive, limited)
jq -r '.definitions | keys | map(select(test("Queue"; "i"))) | .[0:15] | .[]' "$SCHEMA"

# Search definitions by name (exact match)
jq -r '.definitions | keys | map(select(. == "Queue")) | .[]' "$SCHEMA"
```

## Combining Search Criteria

### Search by Multiple Keywords

```bash
# Find endpoints matching both "routing" AND "queues"
jq -r '.paths | keys | map(select(test("routing") and test("queues"))) | .[0:15] | .[]' "$SCHEMA"

# Find endpoints matching "user" OR "person"
jq -r '.paths | keys | map(select(test("user|person"; "i"))) | .[0:15] | .[]' "$SCHEMA"
```

### Search by Path Pattern and Method

```bash
# Find POST endpoints for queues
jq -r '.paths | to_entries | map(select(.key | test("/routing/queues")) | select(.value.post != null)) | map(.key) | .[]' "$SCHEMA"

# Find PUT/PATCH endpoints for users
jq -r '.paths | to_entries | map(select(.key | test("/users")) | select(.value.put != null or .value.patch != null)) | map(.key) | .[]' "$SCHEMA"
```

## Practical Search Examples

### Example 1: Finding "Update Queue" Endpoint

```bash
# Step 1: Search for queue endpoints with ID parameter
jq -r '.paths | keys | map(select(test("routing/queues/\\{queueId\\}$"))) | .[]' "$SCHEMA"
# Result: /api/v2/routing/queues/{queueId}

# Step 2: Check what methods are available
jq '.paths["/api/v2/routing/queues/{queueId}"] | keys' "$SCHEMA"
# Result: ["delete", "get", "patch", "put"]
```

### Example 2: Finding All User Listing Endpoints

```bash
# Search for endpoints that list users (ending with /users)
jq -r '.paths | keys | map(select(test("/users$"))) | .[]' "$SCHEMA"

# Get more details about each
jq '.paths | to_entries | map(select(.key | test("/users$"))) | map({
  path: .key,
  operations: (.value | to_entries | map({method: .key, id: .value.operationId}))
})' "$SCHEMA"
```

### Example 3: Finding Conversation Creation Endpoint

```bash
# Look for POST on conversations collection
jq -r '.paths | keys | map(select(test("/conversations$"))) | .[]' "$SCHEMA"

# Verify POST method exists
jq '.paths["/api/v2/conversations"] | has("post")' "$SCHEMA"
```

### Example 4: Exploring a Resource Type Completely

```bash
# Step 1: Find all queue-related endpoints
jq -r '.paths | keys | map(select(test("queue"; "i"))) | .[0:20] | .[]' "$SCHEMA"

# Step 2: Get operation summary for each
jq '.paths | to_entries | map(select(.key | test("queue"; "i"))) | map({
  path: .key,
  methods: (.value | keys),
  operations: (.value | to_entries | map({method: .key, operationId: .value.operationId, summary: .value.summary}))
}) | .[0:10]' "$SCHEMA"
```

## Tips for Effective Searching

1. **Start broad, then narrow**: Use keyword search first, then refine with exact patterns
2. **Always count first**: Check result count before fetching to avoid overwhelming output
3. **Use limits liberally**: Default to `.[0:15]` for initial exploration
4. **Leverage regex anchors**: Use `^` and `$` for precise matching
5. **Test incrementally**: Build complex queries step by step
6. **Remember the 1,900+ endpoints**: The schema is massive - always be selective