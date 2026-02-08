# Sprint Planning - Linear Status Viewer

<critical>The workflow execution engine is governed by: {project-root}/_bmad/core/tasks/workflow.xml</critical>
<critical>You MUST have already loaded and processed: {project-root}/_bmad/bmm/workflows/4-implementation/sprint-planning/workflow.yaml</critical>
<critical>Linear is the single source of truth for all epics, stories, and sprint status.</critical>

## Overview

Sprint planning now queries Linear directly for all epic and story information. There is no local `sprint-status.yaml` or `epics.md` file to parse - Linear is the single source of truth.

<workflow>

<step n="1" goal="Initialize Linear connection and verify configuration">
<action>Communicate in {communication_language} with {user_name}</action>
<action>Verify Linear MCP is available by checking for mcp__linear__ tools</action>

<check if="Linear MCP not available">
  <output>❌ Linear MCP not available.

**Required Setup:**
1. Install Linear MCP server
2. Configure Linear API token
3. Restart your IDE

Linear is the single source of truth for BMAD sprint tracking.
  </output>
  <action>HALT</action>
</check>

<action>Load {linear_mapping_file} to get team_id and project_id</action>

<check if="linear_mapping_file does not exist OR team_id is empty">
  <output>Linear mapping not initialized.</output>

  <action>Query available teams: mcp__linear__list_teams</action>
  <action>Display numbered list of teams to user:
    "Available Linear teams:
     1. Team Name A
     2. Team Name B
     ..."
  </action>
  <ask>Which team should BMAD use for sprint tracking? (enter number or name)</ask>
  <action>WAIT for user response before proceeding</action>
  <action>Store selected team_id and team_name</action>

  <action>Query projects in selected team: mcp__linear__list_projects with team={selected_team_id}</action>
  <action>Display numbered list of projects to user:
    "Available projects in {team_name}:
     1. Project Name A
     2. Project Name B
     ..."
  </action>
  <ask>Which project should BMAD use for epics and stories? (enter number or name)</ask>
  <action>WAIT for user response before proceeding</action>
  <action>Store selected project_id and project_name</action>

  <action>Save initial {linear_mapping_file}:
    ```yaml
    team_id: {team_id}
    team_name: {team_name}
    project_id: {project_id}
    project_name: {project_name}
    epics: {}
    stories: {}
    ```
  </action>

  <output>Linear configuration saved:
    Team: {team_name}
    Project: {project_name}
  </output>
</check>

<action>Load team_id and project_id from {linear_mapping_file}</action>
</step>

<step n="2" goal="Query Linear for all BMAD-managed issues">
<action>Query all BMAD-Managed issues from Linear:
  mcp__linear__list_issues with team={team_id}, project={project_id}, label="BMAD-Managed"
</action>

<check if="no issues found">
  <output>No BMAD-managed issues found in Linear.

**To create epics and stories:**
Run the `create-epics-and-stories` workflow to define your product backlog.

The workflow will create:
- Epic parent issues with [Epic-N] titles
- Story sub-issues with [{story-key}] titles
- All issues labeled with "BMAD-Managed"
  </output>
  <action>HALT</action>
</check>

<action>Categorize issues:
  - Epics: Issues with titles starting with "[Epic-" (parent issues)
  - Stories: Issues with titles starting with "[" but not "[Epic-" (sub-issues)
</action>

<action>For each issue, map Linear state to BMAD status:
  - Backlog → backlog
  - Todo → ready-for-dev
  - In Progress → in-progress
  - In Review → review
  - Done → done
</action>

<action>Group stories by their parent epic</action>
</step>

<step n="3" goal="Build sprint status from Linear data">
<action>Count story statuses:
  - backlog: stories in Backlog state
  - ready-for-dev: stories in Todo state
  - in-progress: stories in "In Progress" state
  - review: stories in "In Review" state
  - done: stories in Done state
</action>

<action>Count epic statuses:
  - backlog: epics with all stories in Backlog
  - in-progress: epics with any story not in Backlog and not all Done
  - done: epics with all stories in Done
</action>

<action>Check for Retrospective-Complete label on epic issues:
  - If label present → retrospective done
  - If label absent → retrospective optional
</action>

<action>Update {linear_mapping_file} with current issue IDs and statuses</action>
</step>

<step n="4" goal="Validate and report sprint status">
<action>Perform validation checks:</action>

- [ ] All epics have BMAD-Managed label
- [ ] All stories are sub-issues of their parent epic
- [ ] All story titles follow [{story-key}] format
- [ ] Linear connection is healthy

<action>Count totals:</action>

- Total epics: {{epic_count}}
- Total stories: {{story_count}}
- Stories by status: backlog={{backlog}}, ready-for-dev={{ready}}, in-progress={{in_progress}}, review={{review}}, done={{done}}

<action>Display completion summary to {user_name} in {communication_language}:</action>

**Sprint Status from Linear**

- **Team:** {team_name}
- **Project:** {project_name}
- **Total Epics:** {{epic_count}}
- **Total Stories:** {{story_count}}

**Story Status Breakdown:**
| Status | Count |
|--------|-------|
| Backlog | {{backlog}} |
| Ready for Dev (Todo) | {{ready}} |
| In Progress | {{in_progress}} |
| In Review | {{review}} |
| Done | {{done}} |

**Epic Progress:**
{{#each epic}}
- [Epic-{{num}}] {{title}}: {{stories_done}}/{{stories_total}} stories done
{{/each}}

**Next Steps:**
1. Use `create-story` to add Dev Notes to the next backlog story
2. Use `dev-story` to implement stories marked Todo (ready-for-dev)
3. Use `code-review` to review stories In Review
4. Use `retrospective` after completing all stories in an epic

</step>

</workflow>

## Status Mapping Reference

| Workflow State | Linear Status | Description |
|----------------|---------------|-------------|
| backlog | Backlog | Story exists but no context added |
| ready-for-dev | Todo | Story has Dev Notes, ready for development |
| in-progress | In Progress | Developer actively working |
| review | In Review | Ready for code review |
| done | Done | Story completed |

## Linear Issue Structure

**Epic (Parent Issue):**
- Title: `[Epic-N] Epic Title`
- Labels: `BMAD-Managed`, `Epic-N`
- Description: Epic goal and business value

**Story (Sub-Issue):**
- Title: `[story-key] Story Title`
- Labels: `BMAD-Managed`, `Epic-N`
- Parent: Epic issue ID
- Description:
  - Story statement (As a/I want/So that)
  - Acceptance Criteria
  - Dev Notes (added by create-story workflow)
