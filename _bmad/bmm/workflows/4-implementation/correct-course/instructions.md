# Correct Course - Sprint Change Management Instructions

<critical>The workflow execution engine is governed by: {project-root}/_bmad/core/tasks/workflow.xml</critical>
<critical>You MUST have already loaded and processed: {project-root}/_bmad/bmm/workflows/4-implementation/correct-course/workflow.yaml</critical>
<critical>Communicate all responses in {communication_language} and language MUST be tailored to {user_skill_level}</critical>
<critical>Generate all documents in {document_output_language}</critical>
<critical>Linear is the single source of truth - query Linear for epics/stories and post changes to Linear</critical>

<critical>DOCUMENT OUTPUT: Updated epics, stories, or PRD sections. Clear, actionable changes. User skill level ({user_skill_level}) affects conversation style ONLY, not document updates.</critical>

<workflow>

<step n="1" goal="Initialize Change Navigation">
  <action>Confirm change trigger and gather user description of the issue</action>
  <action>Ask: "What specific issue or change has been identified that requires navigation?"</action>

  <action>Load {linear_mapping_file} to get team_id and project_id</action>
  <check if="linear_mapping_file does not exist OR team_id is empty">
    <output>Linear mapping not initialized. Run sprint-planning first to configure Linear integration.</output>
    <action>HALT</action>
  </check>

  <action>Verify access to required project documents:</action>
    - PRD (Product Requirements Document)
    - Architecture documentation
    - UI/UX specifications

  <action>Query Linear for current epics and stories:
    mcp__linear__list_issues with team={{team_id}}, project={{project_id}}, label="BMAD-Managed"
  </action>
  <action>Store epics (titles starting with "[Epic-") and stories for impact analysis</action>

  <action>Ask user for mode preference:</action>
    - **Incremental** (recommended): Refine each edit collaboratively
    - **Batch**: Present all changes at once for review
  <action>Store mode selection for use throughout workflow</action>

<action if="change trigger is unclear">HALT: "Cannot navigate change without clear understanding of the triggering issue. Please provide specific details about what needs to change and why."</action>

<action if="core documents are unavailable">HALT: "Need access to project documents (PRD, Architecture, UI/UX) to assess change impact. Please ensure these documents are accessible."</action>
</step>

<step n="0.5" goal="Discover and load project documents">
  <invoke-protocol name="discover_inputs" />
  <note>After discovery, these content variables are available: {prd_content}, {architecture_content}, {ux_design_content}, {tech_spec_content}, {document_project_content}</note>
</step>

<step n="2" goal="Execute Change Analysis Checklist">
  <action>Read fully and follow the systematic analysis from: {checklist}</action>
  <action>Work through each checklist section interactively with the user</action>
  <action>Record status for each checklist item:</action>
    - [x] Done - Item completed successfully
    - [N/A] Skip - Item not applicable to this change
    - [!] Action-needed - Item requires attention or follow-up
  <action>Maintain running notes of findings and impacts discovered</action>
  <action>Present checklist progress after each major section</action>

<action if="checklist cannot be completed">Identify blocking issues and work with user to resolve before continuing</action>
</step>

<step n="3" goal="Draft Specific Change Proposals">
<action>Based on checklist findings, create explicit edit proposals for each identified artifact</action>

<action>For Story changes (Linear issues):</action>

- Show old → new text format
- Include story key and Linear issue ID
- Provide rationale for each change
- Example format:

  ```
  Story: [1-2-user-auth] User Authentication
  Linear Issue: {{linear_issue_id}}
  Section: Acceptance Criteria

  OLD:
  - User can log in with email/password

  NEW:
  - User can log in with email/password
  - User can enable 2FA via authenticator app

  Rationale: Security requirement identified during implementation
  ```

<action>For Epic changes (Linear parent issues):</action>

- Identify affected epics by querying Linear
- Show current description and proposed changes
- Note impact on child stories

<action>For PRD modifications:</action>

- Specify exact sections to update
- Show current content and proposed changes
- Explain impact on MVP scope and requirements

<action>For Architecture changes:</action>

- Identify affected components, patterns, or technology choices
- Describe diagram updates needed
- Note any ripple effects on other components

<action>For UI/UX specification updates:</action>

- Reference specific screens or components
- Show wireframe or flow changes needed
- Connect changes to user experience impact

<check if="mode is Incremental">
  <action>Present each edit proposal individually</action>
  <ask>Review and refine this change? Options: Approve [a], Edit [e], Skip [s]</ask>
  <action>Iterate on each proposal based on user feedback</action>
</check>

<action if="mode is Batch">Collect all edit proposals and present together at end of step</action>

</step>

<step n="4" goal="Generate Sprint Change Proposal">
<action>Compile comprehensive Sprint Change Proposal document with following sections:</action>

<action>Section 1: Issue Summary</action>

- Clear problem statement describing what triggered the change
- Context about when/how the issue was discovered
- Evidence or examples demonstrating the issue

<action>Section 2: Impact Analysis</action>

- Epic Impact: Which Linear epic issues are affected and how
- Story Impact: Current and future Linear story issues requiring changes
- Artifact Conflicts: PRD, Architecture, UI/UX documents needing updates
- Technical Impact: Code, infrastructure, or deployment implications

<action>Section 3: Recommended Approach</action>

- Present chosen path forward from checklist evaluation:
  - Direct Adjustment: Modify/add stories within existing plan
  - Potential Rollback: Revert completed work to simplify resolution
  - MVP Review: Reduce scope or modify goals
- Provide clear rationale for recommendation
- Include risk assessment and scope impact

<action>Section 4: Detailed Change Proposals</action>

- Include all refined edit proposals from Step 3
- Group by artifact type (Linear Stories, Linear Epics, PRD, Architecture, UI/UX)
- Ensure each change includes before/after and justification

<action>Section 5: Implementation Handoff</action>

- Categorize change scope:
  - Minor: Direct implementation by dev team
  - Moderate: Backlog reorganization needed (PO/SM)
  - Major: Fundamental replan required (PM/Architect)
- Specify handoff recipients and their responsibilities
- Define success criteria for implementation

<action>Present complete Sprint Change Proposal to user</action>
<action>Write Sprint Change Proposal document to {default_output_file}</action>
<ask>Review complete proposal. Continue [c] or Edit [e]?</ask>
</step>

<step n="5" goal="Finalize and Apply Changes to Linear">
<action>Get explicit user approval for complete proposal</action>
<ask>Do you approve this Sprint Change Proposal for implementation? (yes/no/revise)</ask>

<check if="no or revise">
  <action>Gather specific feedback on what needs adjustment</action>
  <action>Return to appropriate step to address concerns</action>
  <goto step="3">If changes needed to edit proposals</goto>
  <goto step="4">If changes needed to overall proposal structure</goto>

</check>

<check if="yes the proposal is approved by the user">
  <action>Finalize Sprint Change Proposal document</action>
  <action>Determine change scope classification:</action>

- **Minor**: Can be implemented directly by development team
- **Moderate**: Requires backlog reorganization and PO/SM coordination
- **Major**: Needs fundamental replan with PM/Architect involvement

<action>Apply approved changes to Linear:</action>

</check>

<check if="story changes approved">
  <action>For each story change:
    mcp__linear__update_issue with id={{story_issue_id}}, description={{updated_description}}
  </action>
  <action>Add comment documenting change:
    mcp__linear__create_comment with issueId={{story_issue_id}}, body="Story updated via correct-course workflow.\n\nChange: {{change_summary}}\nRationale: {{rationale}}"
  </action>
</check>

<check if="epic changes approved">
  <action>For each epic change:
    mcp__linear__update_issue with id={{epic_issue_id}}, description={{updated_description}}
  </action>
  <action>Add comment documenting change:
    mcp__linear__create_comment with issueId={{epic_issue_id}}, body="Epic updated via correct-course workflow.\n\nChange: {{change_summary}}\nRationale: {{rationale}}"
  </action>
</check>

<check if="new stories need to be created">
  <action>For each new story:
    mcp__linear__create_issue with teamId={{team_id}}, projectId={{project_id}}, title="[{{story_key}}] {{story_title}}", description={{story_description}}, labels=["BMAD-Managed"]
  </action>
</check>

<action>Provide appropriate handoff based on scope:</action>

<check if="Minor scope">
  <action>Route to: Development team for direct implementation</action>
  <action>Deliverables: Finalized edit proposals and implementation tasks</action>
</check>

<check if="Moderate scope">
  <action>Route to: Product Owner / Scrum Master agents</action>
  <action>Deliverables: Sprint Change Proposal + backlog reorganization plan</action>
</check>

<check if="Major scope">
  <action>Route to: Product Manager / Solution Architect</action>
  <action>Deliverables: Complete Sprint Change Proposal + escalation notice</action>

<action>Confirm handoff completion and next steps with user</action>
<action>Document handoff in workflow execution log</action>
</check>

</step>

<step n="6" goal="Workflow Completion">
<action>Summarize workflow execution:</action>
  - Issue addressed: {{change_trigger}}
  - Change scope: {{scope_classification}}
  - Linear issues modified: {{list_of_linear_updates}}
  - Artifacts modified: {{list_of_artifacts}}
  - Routed to: {{handoff_recipients}}

<action>Confirm all deliverables produced:</action>

- Sprint Change Proposal document
- Specific edit proposals with before/after
- Linear issues updated with changes and comments
- Implementation handoff plan

<action>Report workflow completion to user with personalized message: "Correct Course workflow complete, {user_name}!"</action>
<action>Remind user of success criteria and next steps for implementation team</action>
</step>

</workflow>
