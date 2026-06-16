---
name: deep-agents-memory
description: "A skill to maintain persistent task memory and context across sessions."
---

# Deep Agents Memory Skill

This skill allows the agent to maintain a persistent `memory.md` file that captures the overarching context, completed tasks, and future TODOs, ensuring a smooth handoff between assignments.

## Usage
The agent should continuously read from and write to `agents/memory.md` before concluding an assignment.

### Reading Memory
Upon entering a workspace, check `agents/memory.md` to establish the current state of the project.

### Writing Memory
Before terminating, document:
1. What was completed during this session.
2. Any configuration changes (e.g. updating `$Rules`).
3. Next steps for the human or agent.
