---
description: Launch the Master Engineering Orchestrator (asks What to do + Which screens, then executes end-to-end)
---

1. Load `personas/orchestrator.md`.
2. If the user has not yet specified both (1) the operation to perform and (2) the target screen(s) or full-app scope, display the 2-question intake menu from Step 1 of `personas/orchestrator.md` and wait for their response.
3. Once confirmed, automatically load the matching platform rules, personas, and skills, execute the entire workflow, run the self-healing verification loop, and present the final report.