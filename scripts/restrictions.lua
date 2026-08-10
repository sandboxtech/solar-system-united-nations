local config = require('config')
local events = require('scripts.events')
local factions = require('scripts.factions')
local state = require('scripts.state')

local M = {}

local RULE_SPECS = {
    ['initial-tech'] = {
        key = 'initial_technologies',
        defaults = 'faction_initial_technologies',
        prototype = 'technology',
        initial_technology = true,
    },
    ['initial-tech-recursive'] = {
        key = 'initial_technologies_recursive',
        defaults = 'faction_initial_technologies_recursive',
        prototype = 'technology',
        initial_technology = true,
        recursive = true,
    },
    ['initial-recipe'] = {
        key = 'initial_recipes',
        defaults = 'faction_initial_recipes',
        prototype = 'recipe',
        initial_recipe = true,
    },
    ['enabled-recipe'] = {
        key = 'enabled_recipes',
        defaults = 'faction_enabled_recipes',
        prototype = 'recipe',
    },
    ['disabled-tech'] = {
        key = 'disabled_technologies',
        defaults = 'faction_disabled_technologies',
        prototype = 'technology',
    },
    ['disabled-recipe'] = {
        key = 'disabled_recipes',
        defaults = 'faction_disabled_recipes',
        prototype = 'recipe',
    },
}
local RULE_ORDER = {
    'initial-tech',
    'initial-tech-recursive',
}
for _, planet_name in ipairs(config.public_planets) do
    local direct_category = 'initial-tech-' .. planet_name
    RULE_SPECS[direct_category] = {
        key = 'initial_technologies_' .. planet_name,
        defaults = 'faction_initial_technologies_by_planet',
        defaults_planet = planet_name,
        prototype = 'technology',
        initial_technology = true,
        planet = planet_name,
    }
    RULE_ORDER[#RULE_ORDER + 1] = direct_category

    local recursive_category = 'initial-tech-recursive-' .. planet_name
    RULE_SPECS[recursive_category] = {
        key = 'initial_technologies_recursive_' .. planet_name,
        defaults = 'faction_initial_technologies_recursive_by_planet',
        defaults_planet = planet_name,
        prototype = 'technology',
        initial_technology = true,
        recursive = true,
        planet = planet_name,
    }
    RULE_ORDER[#RULE_ORDER + 1] = recursive_category
end
RULE_ORDER[#RULE_ORDER + 1] = 'initial-recipe'
RULE_ORDER[#RULE_ORDER + 1] = 'enabled-recipe'
RULE_ORDER[#RULE_ORDER + 1] = 'disabled-tech'
RULE_ORDER[#RULE_ORDER + 1] = 'disabled-recipe'

local function set_from_list(list)
    local result = {}
    for _, name in ipairs(list or {}) do
        if type(name) == 'string' and name ~= '' then result[name] = true end
    end
    return result
end

local function configured_list(spec)
    local configured = config[spec.defaults]
    if spec.defaults_planet then
        return configured and configured[spec.defaults_planet] or {}
    end
    return configured
end

local function default_rules()
    local result = {}
    for _, category in ipairs(RULE_ORDER) do
        local spec = RULE_SPECS[category]
        result[spec.key] = set_from_list(configured_list(spec))
    end
    return result
end

local function ensure_rules()
    state.ensure()
    if type(storage.faction_rules) ~= 'table' then
        storage.faction_rules = default_rules()
    end
    for _, category in ipairs(RULE_ORDER) do
        local key = RULE_SPECS[category].key
        if type(storage.faction_rules[key]) ~= 'table' then
            storage.faction_rules[key] = set_from_list(configured_list(
                RULE_SPECS[category]
            ))
        end
    end
    return storage.faction_rules
end

local function sorted_names(set)
    local result = {}
    for name, enabled in pairs(set or {}) do
        if enabled then result[#result + 1] = name end
    end
    table.sort(result)
    return result
end

local function merge_set(target, source)
    for name, enabled in pairs(source or {}) do
        if enabled then target[name] = true end
    end
end

local function initial_technology_sets(force, rules)
    local direct = {}
    local recursive = {}
    merge_set(direct, rules.initial_technologies)
    merge_set(recursive, rules.initial_technologies_recursive)
    local planet_name = factions.planet_of_force(force)
    if planet_name then
        merge_set(direct, rules['initial_technologies_' .. planet_name])
        merge_set(
            recursive,
            rules['initial_technologies_recursive_' .. planet_name]
        )
    end
    return direct, recursive
end

local function recursive_technology_names(force, roots)
    local result = {}
    local seen = {}
    local function visit(name)
        if seen[name] then return end
        seen[name] = true
        local technology = force.technologies[name]
        if not (technology and technology.valid) then return end
        local prerequisites = {}
        for prerequisite_name in pairs(technology.prerequisites or {}) do
            prerequisites[#prerequisites + 1] = prerequisite_name
        end
        table.sort(prerequisites)
        for _, prerequisite_name in ipairs(prerequisites) do
            visit(prerequisite_name)
        end
        result[#result + 1] = name
    end
    for _, name in ipairs(sorted_names(roots)) do visit(name) end
    return result
end

local function grant_technology(force, rules, name)
    local technology = force.technologies[name]
    if technology and technology.valid
            and not rules.disabled_technologies[name] then
        technology.enabled = true
        if not technology.researched then technology.researched = true end
    end
end

local function grant_initial_sets(force, rules, direct, recursive)
    for _, name in ipairs(sorted_names(direct)) do
        grant_technology(force, rules, name)
    end
    for _, name in ipairs(recursive_technology_names(force, recursive)) do
        grant_technology(force, rules, name)
    end
end

local function grant_all_initial(force, rules)
    local direct, recursive = initial_technology_sets(force, rules)
    grant_initial_sets(force, rules, direct, recursive)
    for _, name in ipairs(sorted_names(rules.initial_recipes)) do
        local recipe = force.recipes[name]
        if recipe and recipe.valid and not rules.disabled_recipes[name] then
            recipe.enabled = true
        end
    end
end

function M.apply(force)
    if not (force and force.valid) then return end
    local rules = ensure_rules()

    for _, name in ipairs(sorted_names(rules.enabled_recipes)) do
        local recipe = force.recipes[name]
        if recipe and recipe.valid then recipe.enabled = true end
    end

    -- Disabled rules intentionally win if a name appears in both lists.
    for _, name in ipairs(sorted_names(rules.disabled_technologies)) do
        local technology = force.technologies[name]
        if technology and technology.valid then
            technology.researched = false
            technology.enabled = false
        end
    end
    for _, name in ipairs(sorted_names(rules.disabled_recipes)) do
        local recipe = force.recipes[name]
        if recipe and recipe.valid then recipe.enabled = false end
    end
end

local function apply_all()
    for _, entry in ipairs(factions.all()) do M.apply(entry.force) end
end

local function grant_all_initial_to_all()
    local rules = ensure_rules()
    for _, entry in ipairs(factions.all()) do
        grant_all_initial(entry.force, rules)
        M.apply(entry.force)
    end
end

local function grant_initial_recipes_to_all()
    local rules = ensure_rules()
    for _, entry in ipairs(factions.all()) do
        for _, name in ipairs(sorted_names(rules.initial_recipes)) do
            local recipe = entry.force.recipes[name]
            if recipe and recipe.valid and not rules.disabled_recipes[name] then
                recipe.enabled = true
            end
        end
        M.apply(entry.force)
    end
end

local function grant_initial_rule(name, spec)
    local rules = ensure_rules()
    for _, entry in ipairs(factions.all()) do
        if not spec.planet or entry.planet_name == spec.planet then
            local direct = spec.recursive and {} or {[name] = true}
            local recursive = spec.recursive and {[name] = true} or {}
            grant_initial_sets(entry.force, rules, direct, recursive)
            M.apply(entry.force)
        end
    end
end

function M.ensure()
    local rules = ensure_rules()
    for _, entry in ipairs(factions.all()) do
        if not storage.faction_initial_technologies_granted[entry.force.name] then
            grant_all_initial(entry.force, rules)
            storage.faction_initial_technologies_granted[entry.force.name] = true
        end
        M.apply(entry.force)
    end
end

local function reset_recipe_states()
    for _, entry in ipairs(factions.all()) do entry.force.reset_recipes() end
end

function M.repair()
    reset_recipe_states()
    grant_initial_recipes_to_all()
    M.ensure()
end

local function restore_removed_disabled_technologies(previous, current)
    for _, entry in ipairs(factions.all()) do
        for name in pairs(previous or {}) do
            if not current[name] then
                local technology = entry.force.technologies[name]
                if technology and technology.valid then technology.enabled = true end
            end
        end
    end
end

local function rebuild_after_change(previous_disabled_technologies)
    local rules = ensure_rules()
    reset_recipe_states()
    restore_removed_disabled_technologies(
        previous_disabled_technologies,
        rules.disabled_technologies
    )
    apply_all()
    grant_initial_recipes_to_all()
end

local function command_reply(command, message)
    local player = command.player_index and game.get_player(command.player_index)
    if player then player.print(message) else localised_print(message) end
end

local function copy_set(source)
    local result = {}
    for name, enabled in pairs(source or {}) do result[name] = enabled end
    return result
end

local function valid_rule_name(spec, name)
    return prototypes[spec.prototype][name] ~= nil
end

local function print_rules(command)
    local rules = ensure_rules()
    for _, category in ipairs(RULE_ORDER) do
        local names = sorted_names(rules[RULE_SPECS[category].key])
        command_reply(command, {
            'un.force-rules-list',
            category,
            #names > 0 and table.concat(names, ', ') or '-',
        })
    end
end

local function rules_command(command)
    local player = command.player_index and game.get_player(command.player_index)
    if player and not player.admin then
        player.print({'un.admin-only'})
        return
    end

    local action, category, name, extra = (command.parameter or ''):match(
        '^%s*(%S*)%s*(%S*)%s*(%S*)%s*(.-)%s*$'
    )
    if action == '' or action == 'show' then
        print_rules(command)
        return
    end
    if action == 'apply' and category == '' and name == '' and extra == '' then
        grant_all_initial_to_all()
        command_reply(command, {'un.force-rules-applied'})
        return
    end
    if action == 'reset' and name == '' and extra == '' then
        local previous = copy_set(ensure_rules().disabled_technologies)
        if category == '' then
            storage.faction_rules = default_rules()
        else
            local spec = RULE_SPECS[category]
            if not spec then
                command_reply(command, {'un.force-rules-usage'})
                return
            end
            storage.faction_rules[spec.key] = set_from_list(
                configured_list(spec)
            )
        end
        rebuild_after_change(previous)
        if category == '' or RULE_SPECS[category].initial_technology
                or RULE_SPECS[category].initial_recipe then
            grant_all_initial_to_all()
        end
        command_reply(command, {'un.force-rules-reset'})
        return
    end
    local spec = RULE_SPECS[category]
    if (action ~= 'add' and action ~= 'remove') or not spec
            or name == '' or extra ~= '' then
        command_reply(command, {'un.force-rules-usage'})
        return
    end
    if not valid_rule_name(spec, name) then
        command_reply(command, {'un.force-rules-invalid-name', name})
        return
    end

    local rules = ensure_rules()
    local previous = copy_set(rules.disabled_technologies)
    rules[spec.key][name] = action == 'add' or nil
    rebuild_after_change(previous)
    if action == 'add' and spec.initial_technology then
        grant_initial_rule(name, spec)
    elseif action == 'add' and spec.initial_recipe then
        grant_initial_recipes_to_all()
    end
    command_reply(command, {'un.force-rules-updated', category, name})
end

events.on(defines.events.on_research_finished, function(event)
    M.apply(event.research.force)
end)

commands.add_command(
    'un-force-rules',
    {'un.force-rules-command-help'},
    rules_command
)

return M
