---
sidebarTitle: "Troubleshooting"
title: "Troubleshooting"
---

**Common issues and solutions for GravityAI plugin node development**

## 🚨 Critical Errors

### "Node X is not a PromiseNode but was executed as one"

**Cause**: Incorrect base class import

**✅ Correct Pattern:**

```typescript
// For PromiseNode:
import { PromiseNode, type NodeExecutionContext } from "@unoverse-platform/plugin-base";

export default class MyExecutor extends PromiseNode {
  constructor() {
    super("MyNode");
  }
}

// For CallbackNode:
import { getPlatformDependencies } from "@unoverse-platform/plugin-base";
const { CallbackNode } = getPlatformDependencies();

export default class MyCallbackExecutor extends CallbackNode {
  constructor() {
    super("MyNode");
  }
}
```

**Why**: The workflow system validates node types. PromiseNode can be imported directly, but CallbackNode still needs `getPlatformDependencies()`.

### "Cannot find name 'PromiseNode'"

**Cause**: Missing import

**✅ Correct:**

```typescript
import { PromiseNode, type NodeExecutionContext } from "@unoverse-platform/plugin-base";

export default class MyExecutor extends PromiseNode {
  constructor() {
    super("MyNode");
  }
}
```

### "Startup Freeze" / Plugin Loading Hangs

**Cause**: Module-level calls to platform dependencies

**✅ Correct - Use Direct Imports:**

```typescript
import { PromiseNode, type NodeExecutionContext } from "@unoverse-platform/plugin-base";
import { myService } from "./service";

export default class MyExecutor extends PromiseNode {
  // No module-level getPlatformDependencies() needed
}
```

**Note**: Only CallbackNode still needs `getPlatformDependencies()` at module level.

## 🔧 Build & Import Errors

### "Module cannot have multiple default exports"

**Cause**: Duplicate default exports in executor file

**❌ Wrong:**

```typescript
export default class MyExecutor extends PromiseNode<Config> {
  // ...
}

// Later in same file
export default MyExecutor; // Duplicate!
```

**✅ Correct:**

```typescript
export default class MyExecutor extends PromiseNode<Config> {
  // ...
}

// OR use named export
export { MyExecutor };
```

### "Cannot find module '@unoverse-platform/plugin-base'"

**Cause**: Missing dependency in package.json

**Solution**: Add to package.json:

```json
{
  "dependencies": {
    "@unoverse-platform/plugin-base": "^1.0.0"
  }
}
```

### TypeScript Compilation Errors

**Common Issues:**

- Missing type imports
- Incorrect generic types
- Missing return types

**✅ Correct Types:**

```typescript
import { PromiseNode, type NodeExecutionContext, type ValidationResult } from "@unoverse-platform/plugin-base";

export default class MyExecutor extends PromiseNode {
  protected async validateConfig(config: MyConfig): Promise<ValidationResult> {
    return { success: true };
  }

  protected async executeNode(
    inputs: Record<string, any>,
    config: MyConfig,
    context: NodeExecutionContext
  ): Promise<MyOutput> {
    // Use injected API
    const logger = context.api?.createLogger?.(this.nodeType) || console;
    const result = await myService(config, credentialContext, context.api);
    return { __outputs: result };
  }
}
```

## 🔐 Credential Issues

### "Credentials are required" Error

**Cause**: Node definition doesn't declare credential requirements

**✅ Solution:**

```typescript
export const MyNode: EnhancedNodeDefinition = {
  type: "MyNode",
  // ... other properties
  credentials: [
    {
      name: "myCredential",
      type: "myCredentialType",
      required: true,
    },
  ],
};
```

### "Credential not found" Error

**Cause**: Node config doesn't have credential ID stored

**Check Config Structure:**

```json
{
  "credentials": {
    "myCredential": "cred_xxxxx"
  },
  "otherConfig": "value"
}
```

**Debug Steps:**

1. Check if credential exists in database
2. Verify credential ID in node config
3. Ensure credential type matches node definition

### Service Can't Access Credentials

**❌ Wrong Pattern:**

```typescript
// Don't access credentials directly
const apiKey = context.credentials.myCredential.apiKey;
```

**✅ Correct Pattern:**

```typescript
// Service fetches credentials from injected API
export async function myService(config: any, credentialContext: CredentialContext, api: any) {
  const credentials = await api.getNodeCredentials(credentialContext, "myCredential");
  const apiKey = credentials.apiKey;
  // Use apiKey...
}
```

## 🔄 Runtime Issues

### Node Doesn't Execute

**Check List:**

1. ✅ Node is registered in plugin setup
2. ✅ Node definition is exported correctly
3. ✅ Executor extends correct base class
4. ✅ `executeNode()` method is implemented
5. ✅ No errors in plugin loading

### CallbackNode Doesn't Continue

**Common Issues:**

- Missing `isComplete` in state
- Not handling "continue" signals properly
- State not updating correctly
- Wrong import pattern for CallbackNode

**✅ Correct CallbackNode Pattern:**

```typescript
import { getPlatformDependencies } from "@unoverse-platform/plugin-base";

const { CallbackNode } = getPlatformDependencies();

initializeState(inputs: any): MyState {
  return {
    items: [], // Start empty, get from config
    currentIndex: 0,
    isComplete: false, // Important!
  };
}

async handleEvent(event, state, emit) {
  const { inputs, config } = event;

  // Handle continue signal to advance iteration
  if (inputs?.continue !== undefined && state.items.length > 0) {
    if (state.currentIndex >= state.items.length) {
      return { ...state, isComplete: true };
    }

    const item = state.items[state.currentIndex];
    const result = await processItem(item);

    emit({
      __outputs: {
        item: result,
        index: state.currentIndex,
        hasMore: state.currentIndex < state.items.length - 1
      }
    });

    return {
      ...state,
      currentIndex: state.currentIndex + 1,
      isComplete: state.currentIndex + 1 >= state.items.length
    };
  }

  // Initialize with items from config
  if (state.items.length === 0 && config?.items) {
    return { ...state, items: config.items };
  }

  return state;
}
```

### Logger Not Working

**✅ Correct Pattern:**

```typescript
// In executor, use this.logger
this.logger.info("Processing started");

// Or get from context.api
const logger = context.api?.createLogger?.(this.nodeType) || console;

// In service, get from injected API
export async function myService(config: any, credentialContext: any, api: any) {
  const logger = api?.createLogger?.("MyService") || console;
  logger.info("Service called");
}
```

## 🧪 Testing & Debugging

### Test Your Node

**1. Build Test:**

```bash
npm run build
```

**2. Plugin Loading Test:**

```bash
# Start server and check logs for plugin loading
npm start
```

**3. Debug Execution:**

```bash
# Execute the node directly via the runtime (internal port, local dev)
curl -X POST http://localhost:4106/execute \
  -H "Content-Type: application/json" \
  -d '{
    "nodeType": "MyNode",
    "config": { "test": "value" },
    "inputs": { "input": "test data" }
  }'
```

### Debug Logging

**Add Debug Logs:**

```typescript
protected async executeNode(inputs, config, context) {
  this.logger.info("Node execution started", {
    nodeId: context.nodeId,
    config: config
  });

  try {
    const result = await myService(config, credentialContext);
    this.logger.info("Node execution completed", { result });
    return { __outputs: result };
  } catch (error) {
    this.logger.error("Node execution failed", { error: error.message });
    throw error;
  }
}
```

### Common Debug Steps

1. **Check Plugin Registration:**

   - Look for plugin loading logs in server startup
   - Verify node appears in available nodes list

2. **Check Credential Loading:**

   - Verify credentials exist in database
   - Check credential IDs in node config
   - Test credential fetching in service

3. **Check Execution Flow:**
   - Add logging to executor methods
   - Verify service calls work independently
   - Check output structure matches expected format

## 🔗 Getting Help

### Study Working Examples

**PromiseNode Issues:**

- Compare with `@unoverse-platform/aws-bedrock`
- Check `@unoverse-platform/aws-bedrock` implementation

**CallbackNode Issues:**

- Compare with `@unoverse-platform/ingest`
- Check `@unoverse-platform/flow` implementation

**Credential Issues:**

- Study any working package's credential handling
- Check credential definitions in published packages

### Error Message Patterns

| Error Message                    | Likely Cause                  | Solution                      |
| -------------------------------- | ----------------------------- | ----------------------------- |
| "is not a PromiseNode"           | Wrong import                  | Import PromiseNode directly   |
| "Cannot find name"               | Missing import                | Add import statement          |
| "Startup freeze"                 | Module-level deps call        | Use direct imports            |
| "Credentials are required"       | Missing credential definition | Add to node definition        |
| "Credential not found"           | Missing credential ID         | Check node config             |
| "Multiple default exports"       | Duplicate exports             | Remove duplicate              |
| "Node never completes"           | Missing isComplete            | Return `{ isComplete: true }` |
| "Downstream nodes not triggered" | Wrong emit pattern            | Call `emit()` before `return` |

## 🔀 Signal Routing Issues

### CallbackNode Never Completes

**Cause**: Missing `isComplete: true` in return

**❌ Wrong:**

```typescript
return { __outputs: { text: "done" } }; // Missing isComplete!
```

**✅ Correct:**

```typescript
emit({ __outputs: { text: "done" } });
return { isComplete: true };
```

### Downstream Nodes Not Receiving Data

**Cause**: Returning outputs instead of emitting them

**❌ Wrong:**

```typescript
return { __outputs: { data: result }, isComplete: true }; // Outputs LOST!
```

**✅ Correct:**

```typescript
emit({ __outputs: { data: result } }); // Sends to downstream
return { isComplete: true }; // Closes the actor
```

### Loop Node Stuck After First Item

**Cause**: Missing CONTINUE signal handling

**✅ Correct:**

```typescript
async handleEvent(event, state, emit) {
  const { inputs } = event;

  // Handle continue signal
  if (inputs?.continue !== undefined) {
    // Process next item
    emit({ __outputs: { item: state.items[state.currentIndex] } });
    return { ...state, currentIndex: state.currentIndex + 1 };
  }

  return state;
}
```

### Node Not Executing

**Cause**: Missing connector dependencies

**Solution**: Check that all required connectors have received inputs:

- Verify edges are correctly mapped
- Check targetHandle matches connector name
- Ensure source nodes are completing

See [Signal Routing](./09-signal-routing.md) for complete details.

---

**Previous**: [Credential Management](./04-credentials.md) - Authentication pattern
