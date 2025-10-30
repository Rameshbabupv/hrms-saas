# Morning Startup Routine

This routine ensures seamless continuation of work across multiple days and sessions.

## Step 0: Session Recovery Detection (30 seconds)
**AI Assistant Actions:**
1. Compare `last_session_date` with `current_date`
2. If dates differ, check for complete daily summary from last session
3. If missing/incomplete → Trigger **Interrupted Session Recovery**
4. If complete → Proceed to normal startup

**Recovery Trigger Logic:**
```markdown
IF last_session_date ≠ current_date AND (
  - Missing daily summary for last_session_date OR
  - Daily summary incomplete/lacks closure markers OR  
  - Final Q&A entries contain open action items
) THEN execute templates/interrupted-session-recovery.md
```

**Detection Confidence Levels:**
- **HIGH**: Missing daily summary, no closure markers
- **MEDIUM**: Incomplete summary, rushed final entries
- **LOW**: Summary exists but action items unresolved

## Step 1: Context Loading (2 minutes)
**AI Assistant Actions:**
1. Load previous day's summary: `daily_summaries/[PREVIOUS-DATE]-summary.md`
2. Review pending action items and open questions  
3. Check for any blocking issues or dependencies
4. Identify the last significant decision or achievement
5. **NEW**: Extract and preserve goal hierarchy (Tactical/Strategic/Context Awareness)

**Output Format:**
```
🌅 Good morning! Here's where we left off:

**Yesterday's Key Achievement:** [Main accomplishment]
**Current Focus:** [What we were working on]
**Pending Action Items:** [Count] items waiting

**Goal Continuity:**
- **Tactical Goals:** [Immediate deliverables]
- **Strategic Goals:** [Broader objectives]  
- **Context Awareness:** [Key constraints/opportunities]

**Priority Today:** [Suggested next step aligned with goals]
```

## Step 2: Context Briefing (1 minute)
**AI Provides:**
- **Momentum Check:** "We made good progress on [X], next logical step is [Y]"
- **Blocker Alert:** "Heads up - [X] is waiting for [Y] before we can proceed"
- **Energy Assessment:** "Today feels like a good day for [complex task] or prefer [routine task]?"

## Step 3: Session Initialization (1 minute)
**AI Asks:**
```
Based on yesterday's progress, I recommend we:
1. [Option 1 - Continue previous work]
2. [Option 2 - Address urgent item]
3. [Option 3 - Start new priority]

What's your energy level and preference for today?
```

## Step 4: Session Setup (1 minute)
**Once direction is chosen:**
- Create new session file: `sessions/[DATE]/session-01-[topic].md`
- Set session objectives
- Load relevant context and templates
- Begin structured conversation capture

## Example Startup Script

```markdown
🌅 **Morning Context Brief - [DATE] ET**

**Where We Left Off:**
Yesterday we successfully [achievement]. We were in the middle of [current focus] with [X] completed and [Y] remaining.

**Today's Landscape:**
- ✅ [Completed item from yesterday]
- 🔄 [In progress item]
- ⏳ [Waiting for dependency]
- ❗ [Urgent new item]

**Recommended Starting Point:**
"Based on our momentum, I suggest we [specific recommendation]. This would build on yesterday's [achievement] and move us closer to [goal]."

**Your Call:**
What feels right for today's focus?
```

## Automation Triggers

**Daily Startup Questions:**
- "Ready for your morning brief?"
- "Shall we review where we left off?"
- "What's the priority for today's session?"

**Continuation Phrases:**
- "Picking up where we left off..."
- "Building on yesterday's progress..."
- "Let's tackle that open question about..."

## Success Metrics

**Good Startup Indicators:**
- No time wasted on "where were we?"
- Clear direction within first 5 minutes
- User feels informed and ready to proceed
- Context is preserved from previous sessions

**Improvement Areas:**
- If user says "I forgot where we were"
- If first 10 minutes are spent reviewing
- If important context was lost
- If priorities are unclear

## Customization Options

**User Preferences:**
- Brief vs. detailed morning summaries
- Priority level filtering (show only high/medium)
- Focus area preferences (technical vs. planning)
- Energy-based recommendations (complex vs. simple tasks)

---

**Implementation Note:** This routine should feel natural and conversational, not mechanical. The goal is to create seamless continuity that feels like working with a colleague who never forgets context.