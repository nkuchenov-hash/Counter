/// Viktor's application capability catalog.
///
/// Models do not click widgets or write PocketBase rows. They propose tools
/// whose handlers delegate to the *same Brain services* used by LIFE OS UI.
/// One registry enumerates supported user operations and their risk level.
/// Adding an unsupported operation requires a reviewed handler, not a prompt
/// exception or arbitrary server-provided code.
library;

enum ViktorToolRisk { read, reversible, consequential, destructive }

class ViktorToolCapability {
  const ViktorToolCapability(
    this.name, this.domain, this.summary, this.risk);
  final String name;
  final String domain;
  final String summary;
  final ViktorToolRisk risk;
  bool get requiresApproval => risk != ViktorToolRisk.read;
}

abstract final class ViktorAgentCapabilities {
  static const tools = <ViktorToolCapability>[
    ViktorToolCapability('list_day_plans', 'planning',
        'Show plans for a specific day', ViktorToolRisk.read),
    ViktorToolCapability('create_plan', 'planning',
        'Create a timed plan', ViktorToolRisk.reversible),
    ViktorToolCapability('update_plan_duration', 'planning',
        'Change a plan duration with expected-value check',
        ViktorToolRisk.consequential),
    ViktorToolCapability('move_plan_after', 'planning',
        'Place a plan after another', ViktorToolRisk.consequential),
    ViktorToolCapability('swap_plan_positions', 'planning',
        'Swap two plan positions', ViktorToolRisk.consequential),
    ViktorToolCapability('bulk_replan', 'planning',
        'Reschedule plan sets with server ownership and collision checks',
        ViktorToolRisk.consequential),
    ViktorToolCapability('start_record', 'records',
        'Start current time record', ViktorToolRisk.reversible),
    ViktorToolCapability('stop_record', 'records',
        'Stop current time record', ViktorToolRisk.reversible),
    ViktorToolCapability('list_categories', 'categories',
        'Read the existing category tree', ViktorToolRisk.read),
    ViktorToolCapability('create_category', 'categories',
        'Add a new category or nested category', ViktorToolRisk.reversible),
    ViktorToolCapability('list_tags', 'tags',
        'Read existing planning or list tags', ViktorToolRisk.read),
    ViktorToolCapability('create_tag', 'tags',
        'Create a named tag in the planning or lists catalog',
        ViktorToolRisk.reversible),
    ViktorToolCapability('rename_tag', 'tags',
        'Rename an existing tag', ViktorToolRisk.consequential),
    ViktorToolCapability('list_notes', 'notes',
        'Show saved notes (backlog plan documents)', ViktorToolRisk.read),
    ViktorToolCapability('create_note', 'notes',
        'Create a standalone note with text and title',
        ViktorToolRisk.reversible),
    ViktorToolCapability('edit_note', 'notes',
        'Replace plain note text after matching the existing title',
        ViktorToolRisk.consequential),
    ViktorToolCapability('list_paths', 'paths',
        'Read active Paths and their stages', ViktorToolRisk.read),
    ViktorToolCapability('create_path', 'paths',
        'Create a versioned Path with a goal, stages and actions',
        ViktorToolRisk.consequential),
    ViktorToolCapability('get_settings', 'profile',
        'Read safe user-facing profile settings', ViktorToolRisk.read),
    ViktorToolCapability('change_setting', 'profile',
        'Change an allowlisted profile setting', ViktorToolRisk.consequential),
  ];

  static final Set<String> names =
      tools.map((tool) => tool.name).toSet();
  static final Map<String, ViktorToolCapability> byName = {
    for (final tool in tools) tool.name: tool,
  };

  static String promptSummary() =>
      tools.map((tool) => '${tool.name}: ${tool.summary}').join('\n');
}
