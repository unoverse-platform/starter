---
sidebarTitle: "Patterns"
title: "Implementation Patterns"
---

**Core patterns and architecture for GravityAI plugin nodes**

## 🚨 Critical Pattern: Dependency Injection

**Use `context.api` for all runtime functions - no global state.**

### ✅ CORRECT Pattern - Dependency Injection

```typescript
import { PromiseNode, type NodeExecutionContext } from "@unoverse-platform/plugin-base";

export default class MyExecutor extends PromiseNode {
  constructor() {
    super("MyNode");
  }

  protected async executeNode(inputs: any, config: any, context: NodeExecutionContext) {
    // Get logger from injected API
    const logger = context.api?.createLogger?.("MyNode") || console;

    // Use API functions
    await context.api.gravityPublish(channel, message);
    const credentials = await context.api.getNodeCredentials(ctx, "cred");

    return { __outputs: result };
  }
}
```

### CallbackNode Pattern

````typescript
import { getPlatformDependencies, type NodeExecutionContext } from "@unoverse-platform/plugin-base";

const { CallbackNode } = getPlatformDependencies();

export default class MyCallbackExecutor extends CallbackNode {
  // CallbackNode still needs getPlatformDependencies for base class
  // But use context.api for runtime functions in handleEvent
  async handleEvent(event, state, emit) {
    const executionContext = (this as any).executionContext;
    // Use context.api for runtime functions
    const logger = executionContext.api?.createLogger?.("MyNode") || console;
  }
}

## 🏗️ Plugin Architecture Patterns

### 1. Plugin Definition Pattern
```typescript
// src/index.ts
import { createPlugin, type GravityPluginAPI } from "@unoverse-platform/plugin-base";

const plugin = createPlugin({
  name: packageJson.name,
  version: packageJson.version,
  description: packageJson.description,

  async setup(api: GravityPluginAPI) {
    // Import and register nodes
    const { MyNode } = await import("./MyNode/node");
    api.registerNode(MyNode);

    // Register credentials
    const { MyCredential } = await import("./credentials");
    api.registerCredential(MyCredential);
  },
});

export default plugin;
````

### 2. Node Definition Pattern

```typescript
// src/MyNode/node/index.ts
import { NodeInputType, type EnhancedNodeDefinition } from "@unoverse-platform/plugin-base";
import MyNodeExecutor from "./executor";

function createNodeDefinition(): EnhancedNodeDefinition {
  return {
    type: "MyNode",
    name: "My Node",
    description: "Does something useful",
    category: "AI", // AI, Flow, Output, Storage, Ingest
    inputs: [{ name: "input", type: NodeInputType.STRING, required: true }],
    outputs: [{ name: "output", type: NodeInputType.STRING }],
    configSchema: {
      type: "object",
      properties: {
        // Configuration fields
      },
    },
    capabilities: {
      isTrigger: false,
    },
  };
}

export const MyNode = {
  definition: createNodeDefinition(),
  executor: MyNodeExecutor,
};
```

### 3. Executor Pattern (PromiseNode)

```typescript
// src/MyNode/node/executor.ts
import { PromiseNode, type NodeExecutionContext, type ValidationResult } from "@unoverse-platform/plugin-base";

export default class MyExecutor extends PromiseNode {
  constructor() {
    super("MyNode");
  }

  protected async validateConfig(config: MyConfig): Promise<ValidationResult> {
    // Simple validation - let service handle details
    return { success: true };
  }

  protected async executeNode(
    inputs: Record<string, any>,
    config: MyConfig,
    context: NodeExecutionContext
  ): Promise<MyOutput> {
    const nodeId = context.nodeId;
    const startTime = Date.now();

    this.logger.info(`🚀 [MyNode] Starting execution for node: ${nodeId}`);

    // Build credential context
    const credentialContext = this.buildCredentialContext(context);

    // Call service with injected API
    const result = await myService(config, credentialContext, context.api);

    // Return with __outputs wrapper
    const finalResult = {
      __outputs: {
        output: result.text,
        metadata: result.metadata,
      },
    };

    this.logger.info(`🎯 [MyNode] Returning result for node: ${nodeId}, total execution: ${Date.now() - startTime}ms`);

    return finalResult;
  }

  private buildCredentialContext(context: NodeExecutionContext) {
    const { workflowId, executionId, nodeId } = this.validateAndGetContext(context);

    return {
      workflowId,
      executionId,
      nodeId,
      nodeType: this.nodeType,
      config: context.config,
      credentials: context.credentials || {},
    };
  }
}
```

### 4. Service Pattern

```typescript
// src/MyNode/service/index.ts

export async function myService(config: MyConfig, credentialContext: any, api: any) {
  // Services fetch credentials from injected API
  const credentials = await api.getNodeCredentials(credentialContext, "myCredential");

  // Business logic here
  const response = await externalAPI(config, credentials);

  return {
    text: response.data,
    metadata: { tokens: response.usage },
  };
}
```

## 🔧 API Injection Pattern

### Services Receive API Parameter

```typescript
export async function myService(config: any, credentialContext: any, api: any) {
  // Use injected API
  const credentials = await api.getNodeCredentials(credentialContext, "myCredential");

  // Use credentials...
  const result = await apiCall(credentials);

  // Save token usage if applicable
  if (result.usage) {
    await api.saveTokenUsage({
      workflowId: credentialContext.workflowId,
      executionId: credentialContext.executionId,
      nodeId: credentialContext.nodeId,
      nodeType: credentialContext.nodeType,
      model: "my-model",
      inputTokens: result.usage.input,
      outputTokens: result.usage.output,
      totalTokens: result.usage.total,
      timestamp: new Date(),
    });
  }

  return result;
}
```

## 🎯 Output Patterns

### PromiseNode Output

```typescript
// Always wrap outputs in __outputs
return {
  __outputs: {
    text: result.text,
    metadata: result.metadata,
    usage: result.usage,
  },
};
```

### CallbackNode Output

**🚨 CRITICAL: CallbackNode completion requires TWO steps:**

```typescript
// Step 1: Emit incremental outputs during processing
emit({
  __outputs: {
    item: processedItem,
    index: currentIndex,
    hasMore: currentIndex < totalItems - 1,
  },
});

// Step 2: When done, emit final outputs THEN return isComplete
emit({
  __outputs: {
    finalResult: allProcessedItems,
    totalCount: items.length,
  },
});

return {
  isComplete: true, // Closes the callback node actor
};
```

**Key Points:**

- ✅ `emit()` sends `NODE_OUTPUT` events to downstream nodes
- ✅ `return { isComplete: true }` sends `NODE_COMPLETE` to close the actor
- ❌ **WRONG:** `return { __outputs: {...}, isComplete: true }` - outputs are LOST!
- 📖 See [Node Types](./02-node-types.md) for detailed explanation

## 🚨 Critical Rules

### 1. API Injection Pattern

- ✅ **ALWAYS** use `context.api` for runtime functions
- ✅ **ALWAYS** pass `api` parameter to services
- ❌ **NEVER** use global state or `getPlatformDependencies()` for runtime functions

### 2. Executor Rules

- ✅ **ALWAYS** extend `PromiseNode` or `CallbackNode`
- ✅ **ALWAYS** implement `executeNode()` or `handleEvent()`
- ❌ **NEVER** override `execute()` method

### 3. Credential Rules

- ✅ **ALWAYS** pass `credentialContext` to services
- ✅ **ALWAYS** let services fetch credentials
- ❌ **NEVER** access `context.credentials` directly in executors

### 4. Logger Rules

- ✅ **ALWAYS** use `this.logger` in executors
- ✅ **ALWAYS** pass logger to services
- ❌ **NEVER** create separate loggers

### 5. Output Rules

- ✅ **ALWAYS** wrap outputs in `__outputs`
- ✅ **ALWAYS** return consistent output structure
- ❌ **NEVER** return raw data without wrapper

## 📁 Shared Utils Pattern

The shared utils pattern promotes code reuse between `executor.ts` and `interactions.ts`.

### File Structure

```
NodeName/
├── index.ts           # Node definition
├── executor.ts        # Node execution logic
├── interactions.ts    # UI interactions (optional)
└── utils/
    ├── operations.ts  # Shared business logic
    ├── validation.ts  # Shared validation functions
    └── types.ts       # Shared TypeScript types
```

### Validation Utilities Example

```typescript
// utils/validation.ts
export interface ValidationResult {
  success: boolean;
  error?: string;
  data?: any;
}

export function validateCredentials(credentials: any): ValidationResult {
  if (!credentials?.apiKey) {
    return { success: false, error: "API key not configured" };
  }
  return { success: true };
}

export function validateDataStructure(data: any): ValidationResult {
  if (!Array.isArray(data)) {
    return { success: false, error: "Data must be an array" };
  }
  return { success: true, data };
}
```

### Using Validation in Executor

```typescript
// executor.ts
import { validateCredentials, validateDataStructure } from "./utils/validation";

protected async executeNode(inputs, config, context) {
  const credentialResult = validateCredentials(context.credentials);
  if (!credentialResult.success) {
    throw new Error(credentialResult.error);
  }

  const dataResult = validateDataStructure(inputs.data);
  if (!dataResult.success) {
    throw new Error(dataResult.error);
  }

  // Proceed with validated data
  return { __outputs: await processData(dataResult.data) };
}
```

### Benefits

- **Zero Code Duplication**: Write validation logic once
- **Consistency**: Same validation rules everywhere
- **Maintainability**: Update logic in one place
- **Type Safety**: Shared interfaces ensure consistent data structures
- **Testing**: Test validation logic once

## 🔗 Real Examples

**Study these patterns in published packages:**

### PromiseNode Patterns

| Package                      | Pattern                             |
| ---------------------------- | ----------------------------------- |
| `@unoverse-platform/aws-bedrock` | Complete PromiseNode implementation |
| `@unoverse-platform/aws-bedrock` | API integration pattern             |
| `@unoverse-platform/aws-s3`      | AWS service pattern                 |

### CallbackNode Patterns

| Package                 | Pattern                                  |
| ----------------------- | ---------------------------------------- |
| `@unoverse-platform/ingest` | ApifyResults executor (state management) |
| `@unoverse-platform/flow`   | Loop executor (iteration pattern)        |
| `@unoverse-platform/ingest` | ApifyResults (streaming pattern)         |

---

**Next**: [Credential Management](./04-credentials.md) - Authentication pattern
