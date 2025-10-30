# Action Item Template

Quick reference for creating well-formed action items with comprehensive metadata.

## Full Format Template
```markdown
- [ ] [T/S/C] [Clear, actionable description] - Owner: [Name] - Created: [YYYY-MM-DD] - Due: [YYYY-MM-DD] - Priority: [High/Medium/Low] - Severity: [Critical/Major/Minor] - Goal: [Which goal this serves] - Source: [Q&A #X]
```

## Quick Format Template (for Q&A capture)
```markdown
- [ ] [T/S/C] [Description] - Owner: [Name] - Due: [YYYY-MM-DD] - Priority: [H/M/L] - Severity: [C/Ma/Mi]
```

## Field Reference

### Type Classification
- **[T] Tactical**: Immediate deliverables for current session/sprint
  - Examples: "Fix login bug", "Write unit tests", "Deploy to staging"
- **[S] Strategic**: Broader project objectives and long-term goals  
  - Examples: "Research analytics platform", "Design system architecture", "Define product roadmap"
- **[C] Context**: Environmental factors, constraints, dependencies, discoveries
  - Examples: "Document API rate limits", "Update security protocols", "Research compliance requirements"

### Priority Levels
- **High**: Directly impacts current sprint/session goals, blocking progress
- **Medium**: Important for project success but not immediately blocking
- **Low**: Nice-to-have improvements, future enhancements

### Severity Levels  
- **Critical**: Blocking progress, system down, security risk, production issues
- **Major**: Significant delay or quality impact if not addressed soon
- **Minor**: Enhancement that improves experience but doesn't block progress

## Examples

### Well-Formed Action Items
```markdown
- [ ] [T] Fix production login authentication timeout - Owner: DevTeam - Created: 2025-08-12 - Due: 2025-08-13 - Priority: High - Severity: Critical - Goal: System stability - Source: Q&A #23

- [ ] [S] Research and evaluate user analytics platforms - Owner: ProductManager - Created: 2025-08-12 - Due: 2025-08-25 - Priority: Medium - Severity: Major - Goal: Data-driven decisions - Source: Q&A #24

- [ ] [C] Document newly discovered API rate limits in developer guide - Owner: TechWriter - Created: 2025-08-12 - Due: 2025-08-20 - Priority: Low - Severity: Minor - Goal: Developer experience - Source: Q&A #25
```

## Best Practices

### Writing Clear Descriptions
- Start with action verb: "Fix", "Research", "Create", "Update", "Deploy"
- Be specific: "login bug" → "login authentication timeout"
- Include context: "in production", "for mobile users", "in developer guide"

### Setting Realistic Due Dates
- Consider dependencies and current workload
- Allow buffer time for complex tasks
- Align with sprint/project milestones

### Assigning Ownership
- Use real names or team identifiers
- Ensure owner has capacity and skills
- Single owner per action item (avoid shared responsibility)

### Goal Alignment
- Link each action to overarching project objectives
- Explain how completion advances broader goals
- Use consistent goal naming across project

## Integration Workflow

1. **Capture in Q&A**: Use quick format during conversation
2. **Transfer to Central**: Add full metadata to `action_items.md`
3. **Daily Review**: Update status during end-of-day ceremony
4. **Weekly Audit**: Review priorities, due dates, and goal alignment
5. **Monthly Archive**: Move completed items to archive section

## Common Mistakes to Avoid

- ❌ Vague descriptions: "Fix the thing"
- ❌ Missing due dates: No deadline accountability
- ❌ Shared ownership: "Team will handle"
- ❌ Wrong severity: Marking enhancement as Critical
- ❌ No goal link: Action without strategic context
- ❌ Unrealistic timelines: 1-day deadline for 2-week task

✅ **Good Example**: 
`[T] Fix user authentication timeout error on mobile login - Owner: BackendDev - Created: 2025-08-12 - Due: 2025-08-14 - Priority: High - Severity: Critical - Goal: Mobile user experience - Source: Q&A #23`