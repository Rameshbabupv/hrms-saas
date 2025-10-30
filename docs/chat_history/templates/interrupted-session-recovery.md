# Interrupted Session Recovery Template

This template handles graceful recovery when sessions end abruptly without proper closure.

## Recovery Detection Trigger
Execute this workflow when: `last_session_date ≠ current_date` AND missing/incomplete daily summary

## Phase 1: Context Reconstruction (2-3 minutes)

### Last Session Analysis
```markdown
🔄 **Session Recovery Mode Activated**
**Last Session:** [YYYY-MM-DD]
**Gap Duration:** [X days/weeks]
**Recovery Timestamp:** [YYYY-MM-DD HH:MM ET]

**Detected Status:**
- [ ] Missing daily summary (HIGH confidence interruption)
- [ ] Incomplete daily summary (MEDIUM confidence interruption)
- [ ] Open action items in last Q&A entries
- [ ] No graceful closure markers found
```

### Goal Reconstruction
**From Last Session Conversation:**
- **Tactical Goals Identified:** [Extract from last conversation]
  - [ ] [Goal 1] - Status: [In Progress/Pending]
  - [ ] [Goal 2] - Status: [In Progress/Pending]

- **Strategic Goals Inferred:** [Broader purpose from context]
  - Primary Objective: [What user was ultimately trying to achieve]
  - Success Criteria: [How we would know when done]

- **Context Awareness:** [Environmental factors]
  - Project Phase: [Planning/Development/Testing/Deployment]
  - Dependencies: [What was blocking or enabling progress]
  - Momentum State: [High/Medium/Low based on last entries]

### Accomplishment Reconstruction
**What We Completed:**
- ✅ [Achievement 1]
- ✅ [Achievement 2]

**What Was Left Hanging:**
- ⏳ [Unfinished item 1] - [Status/next step needed]
- ⏳ [Unfinished item 2] - [Status/next step needed]

**Decisions Made:**
- [Key decision 1] - [Rationale from context]
- [Key decision 2] - [Rationale from context]

## Phase 2: Retrospective Summary Generation

### Generated Daily Summary
```markdown
# Retrospective Daily Summary - [LAST-SESSION-DATE]
*Auto-generated during session recovery on [TODAY]*

## Session Overview
**Status:** Interrupted Session (Recovered [TODAY])
**Duration:** [Estimated from timestamps]
**Confidence Level:** [High/Medium/Low] based on available context

## Key Accomplishments
[List what was clearly completed]

## Goals Progress
### Tactical Goals
- [Goal 1]: [Status and next step]
- [Goal 2]: [Status and next step]

### Strategic Goals
- Primary Objective: [Reconstructed purpose]
- Alignment Status: [How tactical supported strategic]

## Open Items (Carried Forward)
- [ ] [Action item 1] - Owner: [Name] - Due: [Updated date]
- [ ] [Action item 2] - Owner: [Name] - Due: [Updated date]

## Context for Continuation
**Starting Point for Next Session:**
[Clear direction for resuming work]

**Key Context to Preserve:**
[Critical information needed for continuation]

## Recovery Notes
- Original session interrupted without formal closure
- Context reconstructed from conversation history
- Goals inferred from discussion patterns
- Action items carried forward with updated dates
```

## Phase 3: Enhanced Continuation Brief

### Recovery Startup Script
```markdown
🔄 **Welcome Back! Session Recovery Complete**

**What Happened:**
Your last session ([LAST-DATE]) ended without formal closure. I've reconstructed the context and goals.

**Where We Left Off:**
- **Main Focus:** [Primary work stream]
- **Last Achievement:** [Most recent accomplishment]
- **Momentum Status:** [What was building/stalling]

**Goals Carried Forward:**
- **Tactical:** [Immediate deliverables you were working on]
- **Strategic:** [Broader objective this supported]
- **Context:** [Key constraints/opportunities affecting approach]

**Your Options for Today:**
1. **Continue Previous Work:** Pick up exactly where we left off with [specific next step]
2. **Pivot with Context:** Use recovered goals as foundation for new direction
3. **Review and Adjust:** Examine recovered context before proceeding

**Recommended Next Step:**
Based on momentum analysis, I suggest: [Specific recommendation with rationale]

Ready to continue with full context restored?
```

## Implementation Notes

### For Claude Code AI Assistant:
**Auto-Detection Commands:**
- Check file modification dates in `daily_summaries/`
- Scan last session file for closure markers
- Analyze final Q&A entries for completion indicators

**Context Extraction Patterns:**
- Look for "action items," "next steps," "TODO" patterns
- Identify decision points and rationale
- Extract goal statements from user questions
- Map tactical tasks to strategic purposes

**Goal Inference Logic:**
- **Tactical:** Direct asks, specific requests, immediate deliverables
- **Strategic:** Repeated themes, broader questions, project-level concerns
- **Context:** Constraints mentioned, dependencies noted, environmental factors

### Quality Assurance Checklist
- [ ] All open action items identified and carried forward
- [ ] Goals reconstruction feels accurate to conversation flow
- [ ] No critical context appears lost
- [ ] Continuation path is clear and actionable
- [ ] User can immediately resume productive work

### Framework Portability Requirements
**When copying this framework to new projects:**
1. Template files must be copied to `chat_history/templates/`
2. Core CLAUDE.md must include recovery workflow instructions
3. Morning startup routine must include recovery detection logic
4. New project gets full session continuity from day one

---

**Success Metric:** User should feel like they never lost momentum, even after extended breaks.