# Learning Tools Session

This directory contains the AI learning tutor and the remaining reusable learning-tool overlays.

`/tools` now opens `ServerChatPage(standalone: true)` as the primary AI learning-tutor page. Problem-solving flows reuse the same page as an ephemeral overlay. The legacy tool pages remain available only for existing internal entry points.

## Structure

- `session/` — Session entry point (learning_tools_entry.dart)
- `ui/pages/` — Page-level UI (timer, notepad, focus_mode, server_chat, chat_placeholder)
- `ui/modals/` — Modal dialogs (learning_tools_modal)
