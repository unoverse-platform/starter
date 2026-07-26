---
sidebarTitle: "Node Types"
title: "Node Types: PromiseNode vs CallbackNode"
---

**Choose the right base class for your node**

## 🎯 Quick Decision Guide

| Use Case                   | Node Type        | Example                              |
| -------------------------- | ---------------- | ------------------------------------ |
| API call that returns once | **PromiseNode**  | OpenAI completion, AWS Bedrock       |
| Data transformation        | **PromiseNode**  | Text processing, format conversion   |
| File operations            | **PromiseNode**  | Upload file, read document           |
| Database operations        | **PromiseNode**  | Insert record, query data            |
| Streaming responses        | **CallbackNode** | Real-time data, chat streaming       |
| Processing collections     | **CallbackNode** | Loop through items, batch processing |
| User interactions          | **CallbackNode** | Wait for input, multi-step workflows |
| Long-running tasks         | **CallbackNode** | Data scraping, bulk operations       |

## 🔄 PromiseNode - Single Execution

**Pattern**: Execute once → Return result → Done

### When to Use

- ✅ Single input → Single output
- ✅ Stateless operations
- ✅ API calls that complete immediately
- ✅ Data transformations
- ✅ Simple workflows

### Key Characteristics

- Extends `PromiseNode<ConfigType>`
- Implements `executeNode()` method
- Returns `Promise<OutputType>`
- No state management needed
- Workflow continues immediately after completion

### Method Signature

```typescript
protected async executeNode(
  inputs: Record<string, any>,
  config: ConfigType,
  context: NodeExecutionContext
): Promise<OutputType>
```

### Real Examples

- **`@unoverse-platform/aws-bedrock`** - BedrockClaude executor
- **`@unoverse-platform/aws-bedrock`** - BedrockClaude completion
- **`@unoverse-platform/aws-s3`** - S3 file operations

## 🔄 CallbackNode - Multiple Outputs

**Pattern**: Initialize → HandleEvent → Emit → HandleEvent → Emit → Complete

### When to Use

- ✅ Multiple outputs over time
- ✅ Stateful operations
- ✅ Processing collections/arrays one by one
- ✅ Waiting for continuation signals
- ✅ Iterative workflows (like Loop node)
- ✅ Streaming responses (like OpenAI streaming)

### Key Characteristics

- Extends `CallbackNode<ConfigType, StateType>`
- Implements `initializeState()` and `handleEvent()` methods
- Maintains state between events
- Can emit multiple outputs via `emit()` function
- Workflow waits for continuation signals (like "continue" input)

### Method Signatures

```typescript
// Initialize the node's state
initializeState(inputs: any): StateType & { isComplete?: boolean }

// Handle events and emit outputs
async handleEvent(
  event: { type: string; inputs?: any; config?: any },
  state: StateType,
  emit: (output: any) => void
): Promise<StateType & { isComplete?: boolean }>
```

### 🚨 CRITICAL: Node Completion

**CallbackNodes MUST set `isComplete: true` to properly close:**

```typescript
// ✅ CORRECT - Node will complete and clean up
return {
  ...state,
  isComplete: true, // Framework detects completion
};

// ❌ WRONG - Node never completes, stays active forever
return {
  __outputs: { text: "done" }, // Missing isComplete flag!
};
```

**What happens without `isComplete: true`:**

- ❌ Node actor never cleaned up (memory leak)
- ❌ Workflow may not complete properly
- ❌ Node appears "stuck" in active state
- ❌ Downstream nodes may not trigger

**The framework checks:**

```typescript
if (nodeState.isComplete) {
  sendBack({ type: "NODE_COMPLETE", nodeId });
  // Actor is cleaned up
}
```

### 🎯 Critical Pattern: `emit()` vs `return`

**Understanding the difference is crucial:**

#### During Processing: Use `emit()`

Emit incremental/intermediate outputs while work is in progress:

```typescript
// Emit incremental updates during streaming
emit({
  __outputs: {
    chunk: currentText, // Only partial data
  },
});
```

#### Final Return: Use `emit()` then `return { isComplete: true }`

**🚨 CRITICAL PATTERN - Read Carefully:**

The `return` statement does **NOT** send outputs to downstream nodes! You **MUST** call `emit()` first:

```typescript
// ✅ CORRECT - Emit final outputs, then mark complete
emit({
  __outputs: {
    text: fullText, // Final complete text
    usage: usageStats, // Token usage
  },
});

return {
  isComplete: true, // CRITICAL: Tells framework to close the node
};
```

```typescript
// ❌ WRONG - Return does NOT send outputs to downstream nodes!
return {
  __outputs: {
    text: fullText,
    usage: usageStats,
  },
  isComplete: true, // Downstream nodes will NEVER receive this data!
};
```

**Key Rules:**

1. **`emit()`** - Sends `NODE_OUTPUT` events to downstream nodes (can be called multiple times)
2. **`return { isComplete: true }`** - Sends `NODE_COMPLETE` event to close the actor (called once)
3. **Always wrap outputs in `__outputs`** - Both `emit()` calls should use `{ __outputs: {...} }`
4. **Final `emit()` has ALL fields** - Downstream nodes receive the complete data from the last `emit()`
5. **MUST call `emit()` before returning `isComplete: true`** - Otherwise downstream nodes get nothing!

### 📝 Complete Streaming Example

**OpenAI Streaming Pattern** - Shows proper `emit()` and `return` usage:

```typescript
class OpenAIStreamExecutor extends CallbackNode<Config, State> {
  initializeState(inputs: any): State {
    return {
      chunk: "",
      text: "",
      usage: { total_tokens: 0, chunk_count: 0 },
      hasStartedStreaming: false,
    };
  }

  async handleEvent(event, state, emit): Promise<any> {
    // Prevent re-execution
    if (state.hasStartedStreaming) {
      return state;
    }

    // Start streaming
    const updatedState = { ...state, hasStartedStreaming: true };

    // Stream and emit incremental chunks
    let fullText = "";
    for await (const chunk of openaiStream) {
      fullText += chunk.content;

      // EMIT incremental updates (partial data)
      emit({
        __outputs: {
          chunk: fullText, // Only chunk field
        },
      });
    }

    // EMIT final complete output for downstream nodes
    emit({
      __outputs: {
        text: fullText, // Complete text for downstream nodes
        usage: usageStats, // Token usage
      },
    });

    // RETURN with isComplete to close the node
    return {
      isComplete: true, // CRITICAL: Mark node as complete
    };
  }
}
```

**Key Takeaways:**

- ✅ `emit()` during streaming - sends partial updates (chunk) to UI
- ✅ **`emit()` at the end** - sends final complete data (text, usage) to downstream nodes
- ✅ `return { isComplete: true }` - closes the callback node actor
- ✅ **CRITICAL:** You MUST call `emit()` with final outputs before returning `isComplete: true`
- ❌ **WRONG:** The `return` statement does NOT send outputs to downstream nodes!

### Real Examples

- **`@unoverse-platform/ingest`** - ApifyResults executor (streaming with emit + return)
- **`@unoverse-platform/ingest`** - ApifyResults executor (processes items one by one)
- **`@unoverse-platform/flow`** - Loop executor (iterates through collections)

## 🔍 Detailed Comparison

### PromiseNode Execution Flow

1. Node receives inputs
2. `executeNode()` is called once
3. Returns final result
4. Workflow continues to next node

### CallbackNode Execution Flow

1. Node receives inputs
2. `initializeState()` creates initial state
3. `handleEvent()` processes first event
4. Emits output, updates state
5. Waits for continuation signal
6. `handleEvent()` processes next event
7. Repeats until `state.isComplete = true`

## 🚨 Common Mistakes

### ❌ Wrong Choice Examples

**Using PromiseNode for streaming:**

```typescript
// WRONG - PromiseNode can't emit multiple outputs
class StreamingNode extends PromiseNode<Config> {
  async executeNode() {
    // Can only return once!
    return { text: "final result" };
  }
}
```

**Using CallbackNode for simple operations:**

```typescript
// WRONG - Unnecessary complexity for single operation
class SimpleAPINode extends CallbackNode<Config, State> {
  initializeState() {
    return { isComplete: false };
  }

  async handleEvent(event, state, emit) {
    const result = await apiCall();
    emit({ __outputs: result });
    return { ...state, isComplete: true };
  }
}
```

### ✅ Correct Patterns

**PromiseNode for API calls:**

```typescript
class APINode extends PromiseNode<Config> {
  async executeNode(inputs, config, context) {
    const result = await apiCall(config);
    return { __outputs: result };
  }
}
```

**CallbackNode for processing collections:**

```typescript
class ProcessorNode extends CallbackNode<Config, State> {
  initializeState(inputs) {
    return {
      items: [],
      currentIndex: 0,
      isComplete: false,
    };
  }

  async handleEvent(event, state, emit) {
    const { inputs, config } = event;

    // Handle continue signal to advance iteration
    if (inputs?.continue !== undefined && state.items.length > 0) {
      // Check if we're done BEFORE processing
      if (state.currentIndex >= state.items.length) {
        return { ...state, isComplete: true }; // ✅ Mark complete
      }

      const item = state.items[state.currentIndex];
      const result = await processItem(item);

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
        isComplete: state.currentIndex + 1 >= state.items.length, // ✅ Mark complete when done
      };
    }

    // Initialize with items from config
    if (state.items.length === 0 && config?.items) {
      return {
        ...state,
        items: config.items,
      };
    }

    return state;
  }
}
```

## 🎯 Decision Framework

Ask yourself:

1. **How many outputs?**

   - One output → PromiseNode
   - Multiple outputs → CallbackNode

2. **Do I need to wait for user input?**

   - No → PromiseNode
   - Yes → CallbackNode

3. **Am I processing a collection?**

   - No → PromiseNode
   - Yes → CallbackNode

4. **Is this a streaming operation?**

   - No → PromiseNode
   - Yes → CallbackNode

5. **Do I need to maintain state between operations?**
   - No → PromiseNode
   - Yes → CallbackNode

## 🔀 Signal-Based Architecture

CallbackNodes use signals for control flow:

```typescript
inputs: [
  {
    name: "items",
    type: NodeInputType.ARRAY,
    signal: "EXECUTE", // Starts the callback node
  },
  {
    name: "continue",
    type: NodeInputType.SIGNAL,
    signal: "CONTINUE", // Advances iteration
  },
];
```

**Benefits:**

- **Visual edges become signal routes** in the workflow UI
- **Clear distinction** between data and control flow
- **Better step debugging** - sends signals, not re-executes
- **Enables complex state machine nodes**

See [Signal Routing](./09-signal-routing.md) for complete details.

## 🔗 Study Real Examples

| Type         | Package                      | File                             |
| ------------ | ---------------------------- | -------------------------------- |
| PromiseNode  | `@unoverse-platform/aws-bedrock` | `BedrockClaude/node/executor.ts` |
| PromiseNode  | `@unoverse-platform/aws-s3`      | `S3Files/node/executor.ts`       |
| CallbackNode | `@unoverse-platform/ingest`      | `ApifyResults/node/executor.ts`  |
| CallbackNode | `@unoverse-platform/flow`        | `Loop/node/executor.ts`          |
| CallbackNode | `@unoverse-platform/flow`        | `Loop/node/executor.ts`          |

---

**Next**: [Implementation Patterns](./03-patterns.md) - Core patterns and architecture
