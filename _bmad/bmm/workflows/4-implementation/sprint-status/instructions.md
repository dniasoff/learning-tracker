# Sprint Status - Multi-Mode Service

<critical>The workflow execution engine is governed by: {project-root}/_bmad/core/tasks/workflow.xml</critical>
<critical>You MUST have already loaded and processed: {project-root}/_bmad/bmm/workflows/4-implementation/sprint-status/workflow.yaml</critical>
<critical>Linear is the single source of truth - query Linear for all status information</critical>
<critical>Modes: interactive (default), validate, data</critical>

<workflow>

<step n="0" goal="Determine execution mode">
  <action>Set mode = {{mode}} if provided by caller; otherwise mode = "interactive"</action>

  <check if="mode == data">
    <action>Jump to Step 20</action>
  </check>

  <check if="mode == validate">
    <action>Jump to Step 30</action>
  </check>

  <check if="mode == interactive">
    <action>Continue to Step 1</action>
  </check>
</step>

<step n="1" goal="Verify Linear access">
  <action>Verify Linear MCP is available by checking for mcp__linear__ tools</action>
  <check if="Linear MCP not available">
    <output>Linear MCP not available. Ensure Linear MCP server is configured.</output>
    <action>Exit workflow</action>
  </check>

  <action>Load {linear_mapping_file} to get team_id and project_id</action>
  <check if="linear_mapping_file does not exist OR team_id is empty">
    <output>Linear mapping not initialized. Run sprint-planning first to configure Linear integration.</output>
    <action>Exit workflow</action>
  </check>

  <action>Continue to Step 2</action>
</step>

<step n="2" goal="Query Linear for status data">

  <action>Query all BMAD-Managed issues from Linear:
    mcp__linear__list_issues with team={team_id}, project={project_id}, label="BMAD-Managed"
  </action>

  <action>Map Linear statuses to BMAD statuses:
    - Backlog → backlog
    - Todo → ready-for-dev
    - In Progress → in-progress
    - In Review → review
    - Done → done
  </action>

  <action>Separate issues into epics and stories:
    - Epic parent issues: titles starting with "[Epic-"
    - Stories: all other issues (titles starting with "[story-key]")
  </action>

  <action>Check for Retrospective-Complete label on epic parent issues</action>

  <action>Build status summary from Linear data:
    - Count story statuses: backlog, ready-for-dev, in-progress, review, done
    - Count epic statuses: backlog, in-progress, done
    - Count retrospective statuses: optional (no label), done (has Retrospective-Complete label)
  </action>

  <action>Store parsed data for summary display</action>

  <action>Detect risks:</action>

  - IF any story has status "review": suggest `/bmad:bmm:workflows:code-review`
  - IF any story has status "in-progress" AND no stories have status "ready-for-dev": recommend staying focused on active story
  - IF all epics have status "backlog" AND no stories have status "ready-for-dev": prompt `/bmad:bmm:workflows:create-story`
  - IF any story key doesn't match an epic pattern (e.g., story "5-1-..." but no Epic-5): warn "orphaned story detected"
  - IF any epic has status in-progress but has no associated stories: warn "in-progress epic has no stories"
</step>

<step n="3" goal="Select next action recommendation">
  <action>Pick the next recommended workflow using priority:</action>
  <note>When selecting "first" story: sort by epic number, then story number (e.g., 1-1 before 1-2 before 2-1)</note>
  1. If any story status == in-progress → recommend `dev-story` for the first in-progress story
  2. Else if any story status == review → recommend `code-review` for the first review story
  3. Else if any story status == ready-for-dev → recommend `dev-story`
  4. Else if any story status == backlog → recommend `create-story`
  5. Else if any retrospective status == optional → recommend `retrospective`
  6. Else → All implementation items done; congratulate the user - you both did amazing work together!
  <action>Store selected recommendation as: next_story_id, next_workflow_id, next_agent (SM/DEV as appropriate)</action>
</step>

<step n="4" goal="Display summary">
  <output>
## Sprint Status

- Project: {{project_name}}
- Tracking: Linear
- Team: {{team_name}}

**Stories:** backlog {{count_backlog}}, ready-for-dev {{count_ready}}, in-progress {{count_in_progress}}, review {{count_review}}, done {{count_done}}

**Epics:** backlog {{epic_backlog}}, in-progress {{epic_in_progress}}, done {{epic_done}}

**Next Recommendation:** /bmad:bmm:workflows:{{next_workflow_id}} ({{next_story_id}})

{{#if risks}}
**Risks:**
{{#each risks}}

- {{this}}
  {{/each}}
  {{/if}}

  </output>
  </step>

<step n="5" goal="Offer actions">
  <ask>Pick an option:
1) Run recommended workflow now
2) Show all stories grouped by status
3) Show Linear issue details
4) Exit
Choice:</ask>

  <check if="choice == 1">
    <output>Run `/bmad:bmm:workflows:{{next_workflow_id}}`.
If the command targets a story, set `story_key={{next_story_id}}` when prompted.</output>
  </check>

  <check if="choice == 2">
    <output>
### Stories by Status
- In Progress: {{stories_in_progress}}
- Review: {{stories_in_review}}
- Ready for Dev: {{stories_ready_for_dev}}
- Backlog: {{stories_backlog}}
- Done: {{stories_done}}
    </output>
  </check>

  <check if="choice == 3">
    <action>Display Linear issue counts and links</action>
  </check>

  <check if="choice == 4">
    <action>Exit workflow</action>
  </check>
</step>

<!-- ========================= -->
<!-- Data mode for other flows -->
<!-- ========================= -->

<step n="20" goal="Data mode output">
  <action>Load Linear mapping and query issues same as Steps 1-2</action>
  <action>Compute recommendation same as Step 3</action>
  <template-output>next_workflow_id = {{next_workflow_id}}</template-output>
  <template-output>next_story_id = {{next_story_id}}</template-output>
  <template-output>count_backlog = {{count_backlog}}</template-output>
  <template-output>count_ready = {{count_ready}}</template-output>
  <template-output>count_in_progress = {{count_in_progress}}</template-output>
  <template-output>count_review = {{count_review}}</template-output>
  <template-output>count_done = {{count_done}}</template-output>
  <template-output>epic_backlog = {{epic_backlog}}</template-output>
  <template-output>epic_in_progress = {{epic_in_progress}}</template-output>
  <template-output>epic_done = {{epic_done}}</template-output>
  <template-output>risks = {{risks}}</template-output>
  <action>Return to caller</action>
</step>

<!-- ========================= -->
<!-- Validate mode -->
<!-- ========================= -->

<step n="30" goal="Validate Linear access">
  <action>Check that Linear MCP is available</action>
  <check if="Linear MCP not available">
    <template-output>is_valid = false</template-output>
    <template-output>error = "Linear MCP not available"</template-output>
    <template-output>suggestion = "Ensure Linear MCP server is configured"</template-output>
    <action>Return</action>
  </check>

  <action>Load {linear_mapping_file}</action>
  <check if="linear_mapping_file does not exist">
    <template-output>is_valid = false</template-output>
    <template-output>error = "linear-mapping.yaml missing"</template-output>
    <template-output>suggestion = "Run sprint-planning to create it"</template-output>
    <action>Return</action>
  </check>

  <action>Verify team_id and project_id are present</action>
  <check if="team_id or project_id missing">
    <template-output>is_valid = false</template-output>
    <template-output>error = "Linear mapping incomplete - missing team_id or project_id"</template-output>
    <template-output>suggestion = "Re-run sprint-planning to configure Linear integration"</template-output>
    <action>Return</action>
  </check>

  <action>Test Linear connection by querying issues</action>
  <check if="Linear query fails">
    <template-output>is_valid = false</template-output>
    <template-output>error = "Cannot connect to Linear"</template-output>
    <template-output>suggestion = "Check Linear MCP configuration and authentication"</template-output>
    <action>Return</action>
  </check>

  <template-output>is_valid = true</template-output>
  <template-output>message = "Linear integration valid: connection successful, mapping complete"</template-output>
</step>

</workflow>
