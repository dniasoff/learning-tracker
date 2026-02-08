# Sprint Planning Validation Checklist

## Core Validation

### Linear Integration Check

- [ ] Linear MCP is available and connected
- [ ] Team and project are correctly identified
- [ ] linear-mapping.yaml is created with team_id and project_id

### Complete Coverage Check

- [ ] Every epic from PRD appears as a Linear parent issue with "[Epic-N]" title
- [ ] Every story appears as a Linear sub-issue under its epic
- [ ] All issues have "BMAD-Managed" label
- [ ] Issue statuses are valid (Backlog, Todo, In Progress, In Review, Done)

### Parsing Verification

Compare PRD requirements against Linear issues:

```
PRD Contains:                       Linear Contains:
✓ Epic 1: User Authentication       ✓ [Epic-1] User Authentication
  ✓ Story 1.1: User Login             ✓ [1-1-user-login] User Login
  ✓ Story 1.2: Account Mgmt           ✓ [1-2-account-mgmt] Account Management
  ✓ Story 1.3: Password Reset         ✓ [1-3-password-reset] Password Reset

✓ Epic 2: Plant Personality         ✓ [Epic-2] Plant Personality
  ✓ Story 2.1: Personality Model      ✓ [2-1-personality-model] Personality Model
  ✓ Story 2.2: Chat Interface         ✓ [2-2-chat-interface] Chat Interface
```

### Final Check

- [ ] Total count of epics matches PRD
- [ ] Total count of stories matches PRD
- [ ] All issues are in correct parent-child relationships
