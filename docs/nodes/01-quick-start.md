---
sidebarTitle: "Quick Start"
title: "Quick Start - Essential Templates"
---

**Get a working node in 5 minutes with copy-paste templates**

## 🎯 Choose Your Node Type

- **PromiseNode**: Single execution, single result → [Template](#promisenode-template)
- **CallbackNode**: Multiple outputs over time → [Template](#callbacknode-template)

Need help deciding? See [Node Types](./02-node-types.md)

## 📦 Package Structure Template

```
@unoverse-platform/my-node/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts              # Plugin definition
│   ├── MyNode/
│   │   ├── node/
│   │   │   ├── index.ts      # Node definition
│   │   │   └── executor.ts   # Node executor
│   │   ├── service/
│   │   │   └── index.ts      # Business logic
│   │   └── util/
│   │       └── types.ts      # TypeScript types
│   ├── shared/
│   │   └── platform.ts       # Platform dependencies
│   └── credentials/
│       └── index.ts          # Credential definitions
```

## 🚀 PromiseNode Template

### 1. Plugin Definition (`src/index.ts`)

```typescript
import { createPlugin, type GravityPluginAPI } from "@unoverse-platform/plugin-base";
import packageJson from "../package.json";

const plugin = createPlugin({
  name: packageJson.name,
  version: packageJson.version,
  description: packageJson.description,

  async setup(api: GravityPluginAPI) {
    // Import and register node
    const { MyNodeNode } = await import("./MyNode/node");
    api.registerNode(MyNodeNode);

    // Import and register credentials
    const { MyCredential } = await import("./credentials");
    api.registerCredential(MyCredential);
  },
});

export default plugin;
```

### 2. Node Definition (`src/MyNode/node/index.ts`)

```typescript
import { NodeInputType, type EnhancedNodeDefinition } from "@unoverse-platform/plugin-base";
import MyNodeExecutor from "./executor";

function createNodeDefinition(): EnhancedNodeDefinition {
  return {
    type: "MyNode",
    name: "My Node",
    description: "Does something useful",
    category: "AI", // AI, Flow, Output, Storage, Ingest, etc.
    inputs: [
      {
        name: "input",
        type: NodeInputType.STRING,
        required: true,
        // signal: "EXECUTE"  // Default - triggers node execution
      },
    ],
    outputs: [{ name: "output", type: NodeInputType.STRING }],
    configSchema: {
      type: "object",
      properties: {
        apiEndpoint: {
          type: "string",
          title: "API Endpoint",
          description: "The API endpoint URL",
          default: "https://api.example.com",
        },
        prompt: {
          type: "string",
          title: "Prompt Template",
          description: "User message. Supports {{input.fieldName}} syntax.",
          default: "{{input.text}}",
          "ui:field": "template",
        },
        maxTokens: {
          type: "number",
          title: "Max Tokens",
          description: "Maximum tokens to generate",
          default: 256,
          minimum: 1,
          maximum: 4096,
        },
        enableAdvanced: {
          type: "boolean",
          title: "Enable Advanced Options",
          default: false,
          "ui:widget": "toggle",
        },
        advancedConfig: {
          type: "object",
          title: "Advanced Configuration",
          description: "JavaScript object for advanced settings",
          default: "",
          "ui:field": "template",
          "ui:dependencies": {
            enableAdvanced: true,
          },
        },
      },
      required: ["apiEndpoint", "prompt"],
    },

    serviceConnectors: [
      {
        name: "embeddingService",
        description: "Connect to an embedding service",
        serviceType: "embedding",
        methods: ["createEmbedding"],
        isService: false, // This node consumes services
      },
      // Or provide a service:
      // {
      //   name: "myService",
      //   description: "My custom service",
      //   serviceType: "custom",
      //   methods: ["myMethod"],
      //   isService: true, // This node provides services
      // }
    ],
    capabilities: {
      isTrigger: false,
      // cacheable: true,  // opt in ONLY for idempotent reads (search/scrape/fetch) so
      //                   // the engine can memoize the output. See CLAUDE.md § Node capabilities.
    },
  };
}

const definition = createNodeDefinition();

export const MyNodeNode = {
  definition,
  executor: MyNodeExecutor,
};

export { createNodeDefinition };
```

### 3. Node Executor (`src/MyNode/node/executor.ts`)

```typescript
import { PromiseNode, type NodeExecutionContext, type ValidationResult } from "@unoverse-platform/plugin-base";
import { MyNodeConfig, MyNodeOutput } from "../util/types";
import { myService } from "../service";

export default class MyNodeExecutor extends PromiseNode {
  constructor() {
    super("MyNode");
  }

  protected async validateConfig(config: MyNodeConfig): Promise<ValidationResult> {
    // Simple validation - let service handle details
    return { success: true };
  }

  protected async executeNode(
    inputs: Record<string, any>,
    config: MyNodeConfig,
    context: NodeExecutionContext
  ): Promise<MyNodeOutput> {
    const credentialContext = this.buildCredentialContext(context);
    const result = await myService(config, credentialContext, context.api);

    const finalResult = {
      __outputs: {
        output: result.text,
        metadata: result.metadata,
      },
    };

    this.logger.info(`🎯 [MyNode] Returning result for node: ${nodeId}, total execution: ${Date.now() - startTime}ms`);

    return finalResult;
  }

  protected buildCredentialContext(context: NodeExecutionContext): any {
    return {
      workflowId: context.workflow?.id,
      executionId: context.executionId,
      nodeId: context.nodeId,
      nodeType: this.nodeType,
      config: context.config,
      credentials: context.credentials || {},
    };
  }
}
```

### 4. Service (`src/MyNode/service/index.ts`)

```typescript
import { MyNodeConfig } from "../util/types";

export async function myService(config: MyNodeConfig, credentialContext: any, api: any) {
  // Fetch credentials using the credential pattern
  const credentials = await api.getNodeCredentials(credentialContext, "myCredential");

  if (!credentials?.apiKey) {
    throw new Error("API key not found in credentials");
  }

  // Your business logic here
  const response = await fetch(config.apiEndpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${credentials.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      prompt: config.prompt,
    }),
  });

  if (!response.ok) {
    throw new Error(`API call failed: ${response.statusText}`);
  }

  const data = await response.json();

  return {
    text: data.result,
    metadata: {
      model: data.model,
      tokens: data.usage?.total_tokens || 0,
    },
  };
}
```

### 5. Types (`src/MyNode/util/types.ts`)

```typescript
export interface MyNodeConfig {
  apiEndpoint: string;
  prompt: string;
}

export interface MyNodeOutput {
  __outputs: {
    output: string;
    metadata: {
      model?: string;
      tokens?: number;
    };
  };
}
```

### 6. Platform Dependencies (Optional - for CallbackNode only)

```typescript
// Only needed if you have CallbackNode executors
import { getPlatformDependencies } from "@unoverse-platform/plugin-base";

const deps = getPlatformDependencies();

export const CallbackNode = deps.CallbackNode;
```

### 7. Credentials (`src/credentials/index.ts`)

```typescript
// Import shared credentials from plugin-base
import { OpenAICredential } from "@unoverse-platform/plugin-base";

// Re-export for this package
export { OpenAICredential as MyCredential };

// Or define custom credential:
export const MyCredential = {
  name: "myCredential",
  type: "object",
  title: "My API Credentials",
  properties: {
    apiKey: {
      type: "string",
      title: "API Key",
      description: "Your API key",
    },
  },
  required: ["apiKey"],
};
```

## 🔄 CallbackNode Template

For CallbackNode (streaming/iterative), replace the executor with:

```typescript
import { getPlatformDependencies, type NodeExecutionContext, type ValidationResult } from "@unoverse-platform/plugin-base";

const { CallbackNode } = getPlatformDependencies();

interface MyState {
  items: any[];
  currentIndex: number;
  isComplete: boolean;
}

interface MyEvent {
  type: string;
  inputs?: any;
  config?: MyConfig;
}

export default class MyCallbackExecutor extends CallbackNode<MyConfig, MyState> {
  constructor() {
    super("MyCallbackNode");
  }

  initializeState(inputs: any): MyState {
    return {
      items: [],
      currentIndex: 0,
      isComplete: false,
    };
  }

  protected async validateConfig(config: MyConfig): Promise<ValidationResult> {
    return { success: true };
  }

  async handleEvent(event: MyEvent, state: MyState, emit: (output: any) => void): Promise<MyState> {
    // Get execution context from CallbackNode
    const executionContext = (this as any).executionContext;
    if (!executionContext) {
      throw new Error("Execution context not available");
    }

    const { inputs, config } = event;
    const resolvedConfig = config as MyConfig;

    // Handle continue signal to advance iteration
    if (inputs?.continue !== undefined && state.items.length > 0) {
      if (state.currentIndex >= state.items.length) {
        return { ...state, isComplete: true };
      }

      const currentItem = state.items[state.currentIndex];
      const result = await processItem(currentItem, executionContext);

      emit({
        __outputs: {
          item: result,
          index: state.currentIndex,
          hasMore: state.currentIndex < state.items.length - 1,
        },
      });

      return {
        ...state,
        currentIndex: state.currentIndex + 1,
        isComplete: state.currentIndex + 1 >= state.items.length,
      };
    }

    // Initialize with items from config if available
    if (state.items.length === 0 && resolvedConfig?.items) {
      const items = resolvedConfig.items;

      if (items.length > 0) {
        const firstItem = items[0];
        const result = await processItem(firstItem, executionContext);

        emit({
          __outputs: {
            item: result,
            index: 0,
            hasMore: items.length > 1,
          },
        });

        return {
          items,
          currentIndex: 1,
          isComplete: items.length <= 1,
        };
      }
    }

    return state;
  }
}
```

## � Signal-Based Inputs (CallbackNode)

For CallbackNode that needs control flow signals (like Loop):

```typescript
inputs: [
  {
    name: "items",
    type: NodeInputType.ARRAY,
    required: true,
    signal: "EXECUTE"  // Starts the callback node
  },
  {
    name: "continue",
    type: NodeInputType.SIGNAL,
    required: false,
    signal: "CONTINUE"  // Advances to next iteration
  }
],
```

**Signal Types:**

- `EXECUTE` - Primary execution signal (default for data inputs)
- `CONTINUE` - Advances callback node iterations
- `SPAWN` - Initializes callback node actor

See [Signal Routing](./09-signal-routing.md) for complete details.

## �📋 Setup Checklist

1. ✅ Copy templates above
2. ✅ Replace `MyNode` with your node name throughout
3. ✅ Update `package.json` with your package name
4. ✅ Define your config schema and types (see [Config Schema Reference](./06-config-schema.md))
5. ✅ Implement your service logic
6. ✅ Test with debug resolver
7. ✅ Publish to npm

## 🎨 Config Schema

For complete details on all config schema options including:

- String vs Object templates (`{{input.field}}` vs JavaScript)
- Conditional dependencies (`ui:dependencies`)
- Widgets (`ui:widget: "toggle"`)
- Validation rules
- Real working examples

**See**: [Config Schema Reference](./06-config-schema.md)

## 🔗 Real Examples

**Study these published packages for complete implementations:**

| Type         | Package                      | Description            |
| ------------ | ---------------------------- | ---------------------- |
| PromiseNode  | `@unoverse-platform/aws-bedrock` | BedrockClaude executor |
| PromiseNode  | `@unoverse-platform/aws-bedrock` | BedrockClaude completion |
| CallbackNode | `@unoverse-platform/ingest`      | ApifyResults executor  |
| CallbackNode | `@unoverse-platform/flow`        | Loop executor          |

---

**Next**: [Node Types](./02-node-types.md) - Choose PromiseNode vs CallbackNode
