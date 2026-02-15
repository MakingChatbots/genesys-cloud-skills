# Complete Workflow Examples

Detailed step-by-step examples of complete workflows for common API exploration tasks.

**Related**: Condensed workflow in SKILL.md

## Table of Contents

- [Example 1: Implementing "Update Queue" Operation](#example-1-implementing-update-queue-operation)
- [Example 2: Finding All User-Related Endpoints](#example-2-finding-all-user-related-endpoints)
- [Example 3: Understanding Permissions for a Resource](#example-3-understanding-permissions-for-a-resource)
- [Example 4: Exploring Nested Definition References](#example-4-exploring-nested-definition-references)
- [Example 5: Comparing Request vs Response Schemas](#example-5-comparing-request-vs-response-schemas)
- [Tips for Using Examples](#tips-for-using-examples)

## Example 1: Implementing "Update Queue" Operation

**Scenario**: User asks "How do I update a queue?"

### Step 1: Find the Endpoint

```bash
jq -r '.paths | keys | map(select(test("routing/queues/\\{queueId\\}$"))) | .[]' "$SCHEMA"
```

**Output**: `/api/v2/routing/queues/{queueId}`

**Analysis**: This endpoint pattern suggests it operates on a specific queue (has `{queueId}` parameter).

### Step 2: Check Available Methods

```bash
jq '.paths["/api/v2/routing/queues/{queueId}"] | keys' "$SCHEMA"
```

**Output**: `["delete", "get", "patch", "put"]`

**Analysis**: Both PUT and PATCH are available. PUT typically replaces the entire resource, PATCH applies partial updates.

### Step 3: Get PUT Operation Permissions

```bash
jq '.paths["/api/v2/routing/queues/{queueId}"]["put"]["x-inin-requires-permissions"]' "$SCHEMA"
```

**Output**:
```json
{
  "type": "ALL",
  "permissions": ["routing:queue:edit"]
}
```

**Analysis**: Requires ALL permissions in the list (in this case, just one: `routing:queue:edit`).

### Step 4: Extract Parameters

```bash
jq '.paths["/api/v2/routing/queues/{queueId}"]["put"].parameters[] | {name, in, required, description, schemaRef: .schema."$ref"?}' "$SCHEMA"
```

**Output**:
```json
{
  "name": "queueId",
  "in": "path",
  "required": true,
  "description": "Queue ID",
  "schemaRef": null
}
{
  "name": "body",
  "in": "body",
  "required": true,
  "description": "Queue",
  "schemaRef": "#/definitions/QueueRequest"
}
```

**Analysis**: Need queueId in path and a body matching QueueRequest schema.

### Step 5: Get Input Schema Reference

```bash
jq -r '.paths["/api/v2/routing/queues/{queueId}"]["put"].parameters[] | select(.in == "body") | .schema."$ref"' "$SCHEMA"
```

**Output**: `#/definitions/QueueRequest`

### Step 6: Resolve Input Schema

```bash
jq '.definitions["QueueRequest"] | {type, description, required, properties: (.properties | keys)}' "$SCHEMA"
```

**Output**:
```json
{
  "type": "object",
  "description": "Queue request object",
  "required": ["name"],
  "properties": ["name", "description", "division", "acwSettings", "skillEvaluationMethod", ...]
}
```

**Analysis**: Only `name` is required. Other fields are optional.

### Step 7: Get Output Schema

```bash
jq -r '.paths["/api/v2/routing/queues/{queueId}"]["put"].responses["200"].schema."$ref"' "$SCHEMA"
```

**Output**: `#/definitions/Queue`

### Step 8: Resolve Output Schema

```bash
jq '.definitions["Queue"] | {type, description, properties: (.properties | keys | .[0:10])}' "$SCHEMA"
```

**Output**: Shows the Queue object structure returned on success.

### Complete Response to User

```
## Recommended Endpoint

**Endpoint**: `PUT /api/v2/routing/queues/{queueId}`
**Operation ID**: `putRoutingQueue`
**Summary**: Update a queue

### Permissions
- Type: ALL
- Required: routing:queue:edit

### Key Parameters
- `queueId` (path, required): Queue ID
- `body` (body, required): Queue object with the following structure:
  - `name` (required): Queue name
  - `description` (optional): Queue description
  - `division` (optional): Division assignment
  - Additional optional fields for ACW settings, evaluation method, etc.

### Usage Notes
- Use PUT to replace the entire queue configuration
- Only the `name` field is required in the request body
- Returns the complete updated Queue object
- Requires `routing:queue:edit` permission
```

---

## Example 2: Finding All User-Related Endpoints

**Scenario**: User asks "What user endpoints are available?"

### Execute in PARALLEL (Steps 1-3)

```bash
# Tool Call 1: List all user endpoints
jq -r '.paths | keys | map(select(test("/users"))) | .[]' "$SCHEMA"

# Tool Call 2: Get summary of first 5 user endpoints with operations
jq '.paths | to_entries | map(select(.key | test("/users"))) | map({
  path: .key,
  operations: (.value | to_entries | map({method: .key, id: .value.operationId, summary: .value.summary}))
}) | .[0:5]' "$SCHEMA"

# Tool Call 3: Count total user endpoints
jq '.paths | keys | map(select(test("/users"))) | length' "$SCHEMA"
```

### Response to User

```
Found 47 user-related endpoints in the API. Here are the most common:

### Collection Endpoints
- `GET /api/v2/users` - List all users (supports pagination, filtering)
- `POST /api/v2/users` - Create a new user
- `POST /api/v2/users/search` - Search users with advanced criteria

### Individual User Endpoints
- `GET /api/v2/users/{userId}` - Get user by ID
- `PATCH /api/v2/users/{userId}` - Update user (partial)
- `PUT /api/v2/users/{userId}` - Update user (full replace)
- `DELETE /api/v2/users/{userId}` - Delete user

### User Profile & Settings
- `GET /api/v2/users/{userId}/profile` - Get user profile
- `PUT /api/v2/users/{userId}/profile` - Update user profile
- `GET /api/v2/users/{userId}/station` - Get user's station

### User Roles & Permissions
- `GET /api/v2/users/{userId}/roles` - Get user roles
- `PUT /api/v2/users/{userId}/roles` - Update user roles

Would you like details on any specific endpoint?
```

---

## Example 3: Understanding Permissions for a Resource

**Scenario**: User asks "What permissions are needed for queue operations?"

### Execute Query

```bash
jq '.paths | to_entries | map(select(.key | test("/routing/queues"))) | map({
  path: .key,
  operations: (.value | to_entries | map({
    method: .key,
    operationId: .value.operationId,
    permissions: .value."x-inin-requires-permissions"
  }))
})' "$SCHEMA"
```

### Response to User

```
## Queue Operation Permissions

### View Operations
- `GET /api/v2/routing/queues` - No special permissions required
- `GET /api/v2/routing/queues/{queueId}` - Requires ANY of: routing:queue:view

### Create Operations
- `POST /api/v2/routing/queues` - Requires ALL of: routing:queue:add

### Update Operations
- `PUT /api/v2/routing/queues/{queueId}` - Requires ALL of: routing:queue:edit
- `PATCH /api/v2/routing/queues/{queueId}` - Requires ALL of: routing:queue:edit

### Delete Operations
- `DELETE /api/v2/routing/queues/{queueId}` - Requires ALL of: routing:queue:delete

### Key Permission Types
- **ALL**: User must have every permission in the list
- **ANY**: User needs at least one permission from the list
- **null**: No special permissions required (public endpoint)

### Summary of Queue Permissions
- `routing:queue:view` - View queue details
- `routing:queue:add` - Create new queues
- `routing:queue:edit` - Update existing queues
- `routing:queue:delete` - Delete queues
```

---

## Example 4: Exploring Nested Definition References

**Scenario**: Understanding the complete structure of a Queue object.

### Step 1: Get Queue Properties

```bash
jq '.definitions["Queue"].properties | keys' "$SCHEMA"
```

**Output**: List of all Queue properties (name, description, division, etc.)

### Step 2: Find Properties with References

```bash
jq '.definitions["Queue"].properties | to_entries | map(select(.value."$ref" != null)) | map({property: .key, ref: .value."$ref"})' "$SCHEMA"
```

**Output**:
```json
[
  {"property": "division", "ref": "#/definitions/WritableDivision"},
  {"property": "dateCreated", "ref": "#/definitions/Date"},
  {"property": "dateModified", "ref": "#/definitions/Date"},
  ...
]
```

### Step 3: Resolve Division Reference

```bash
# Extract definition name
DIVISION_REF=$(jq -r '.definitions["Queue"].properties["division"]."$ref"' "$SCHEMA" | sed 's|#/definitions/||')

# Resolve it
jq --arg ref "$DIVISION_REF" '.definitions[$ref]' "$SCHEMA"
```

**Output**: WritableDivision structure

### Step 4: Continue Exploring Nested Refs

```bash
# Find nested refs in WritableDivision
jq --arg ref "$DIVISION_REF" '.definitions[$ref].properties | to_entries | map(select(.value."$ref" != null))' "$SCHEMA"
```

### Complete Understanding

```
## Queue Object Structure

### Direct Properties (primitives)
- `id` (string): Queue ID
- `name` (string): Queue name
- `description` (string): Queue description

### Referenced Objects
- `division` (WritableDivision):
  - `id` (string): Division ID
  - `name` (string): Division name

- `dateCreated` (Date): Creation timestamp
- `dateModified` (Date): Last modification timestamp

- `acwSettings` (AcwSettings):
  - `wrapupPrompt` (string)
  - `timeoutMs` (integer)

### Required Fields
- `name` (for QueueRequest)

### Notes
- The Queue object has multiple nested references
- Most nested objects follow the pattern of having an id and name
- Dates are ISO-8601 formatted strings
```

---

## Example 5: Comparing Request vs Response Schemas

**Scenario**: Understanding what fields can be sent vs what fields are returned.

### Execute in PARALLEL

```bash
# Tool Call 1: Get input schema
jq '.paths["/api/v2/routing/queues/{queueId}"]["put"] | {
  operationId,
  inputSchema: (.parameters[] | select(.in == "body") | .schema."$ref")
}' "$SCHEMA"

# Tool Call 2: Get output schema
jq '.paths["/api/v2/routing/queues/{queueId}"]["put"] | {
  operationId,
  outputSchema: .responses["200"].schema."$ref"
}' "$SCHEMA"

# Tool Call 3: Get QueueRequest properties
jq '.definitions["QueueRequest"] | {required, properties: (.properties | keys)}' "$SCHEMA"

# Tool Call 4: Get Queue properties
jq '.definitions["Queue"] | {required, properties: (.properties | keys)}' "$SCHEMA"
```

### Response to User

```
## PUT /api/v2/routing/queues/{queueId} Schema Comparison

### Input Schema: QueueRequest
**Required fields**: name
**All fields**: name, description, division, acwSettings, skillEvaluationMethod, queueFlow, whisperPrompt, autoAnswerOnly, callingPartyName, callingPartyNumber, memberCount

### Output Schema: Queue
**Required fields**: (none - all optional in response)
**All fields**: id, name, description, division, dateCreated, dateModified, modifiedBy, createdBy, memberCount, acwSettings, skillEvaluationMethod, queueFlow, whisperPrompt, autoAnswerOnly, callingPartyName, callingPartyNumber, selfUri

### Key Differences
1. **Read-only fields** (only in response):
   - id, dateCreated, dateModified, modifiedBy, createdBy, selfUri

2. **Writable fields** (in both):
   - name, description, division, acwSettings, skillEvaluationMethod, etc.

3. **Request-only fields** (only in request):
   - (none in this case - all request fields appear in response)

### Usage Pattern
- Send QueueRequest with writable fields
- Receive Queue with all fields including server-generated metadata
- id and system timestamps are auto-generated
```

---

## Tips for Using Examples

1. **Always execute independent queries in PARALLEL** for maximum efficiency
2. **Start with search and verification** before extracting detailed information
3. **Use incremental refinement** - get overview first, then drill into details
4. **Cache definition names in variables** when doing multiple resolutions
5. **Document your findings** in the structured format users expect
