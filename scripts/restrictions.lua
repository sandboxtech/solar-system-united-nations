local config = require('config')
local events = require('scripts.events')
local factions = require('scripts.factions')
local state = require('scripts.state')

local M = {}

local TRIGGER_TOKEN = '@trigger'
local RULE_SPECS = {
    ['initial-tech'] = {
        key = 'initial_technologies',
        defaults = 'faction_initial_technologies',
        prototype = 'technology',
        trigger_token = true,
    },
    ['initial-recipe'] = {
        key = 'initial_recipes',
        defaults = 'faction_initial_recipes',
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
    'initial-recipe',
    'disabled-tech',
    'disabled-recipe',
}

local function set_from_list(list)
    local result = {}
    for _, name in ipairs(list or {}) do
        if type(name) == 'string' and name ~= '' then result[name] = true end
    end
    return result
end

local function default_rules()
    local result = {}
    for _, category in ipairs(RULE_ORDER) do
        local spec = RULE_SPECS[category]
        result[spec.key] = set_from_list(config[spec.defaults])
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
            storage.faction_rules[key] = set_from_list(
                config[RULE_SPECS[category].defaults]
            )
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

local function initial_technology_roots(force, rules)
    local roots = {}
    if rules.initial_technologies[TRIGGER_TOKEN] then
        for name, technology in pairs(force.technologies) do
            if technology.prototype.research_trigger then
                roots[name] = true
            end
        end
    end
    for _, name in ipairs(sorted_names(rules.initial_technologies)) do
        if name ~= TRIGGER_TOKEN then roots[name] = true end
    end
    return roots
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

local function grant_roots(force, rules, roots)
    for _, name in ipairs(recursive_technology_names(force, roots)) do
        local technology = force.technologies[name]
        if technology and technology.valid
                and not rules.disabled_technologies[name] then
            technology.enabled = true
            if not technology.researched then technology.researched = true end
        end
    end
end

local function grant_all_initial(force, rules)
    grant_roots(force, rules, initial_technology_roots(force, rules))
end

function M.apply(force)
    if not (force and force.valid) then return end
    local rules = ensure_rules()

    for _, name in ipairs(sorted_names(rules.initial_recipes)) do
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

local function grant_initial_rule_to_all(name)
    local rules = ensure_rules()
    for _, entry in ipairs(factions.all()) do
        local roots = {}
        if name == TRIGGER_TOKEN then
            for technology_name, technology in pairs(entry.force.technologies) do
                if technology.prototype.research_trigger then
                    roots[technology_name] = true
                end
            end
        else
            roots[name] = true
        end
        grant_roots(entry.force, rules, roots)
        M.apply(entry.force)
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
    if spec.trigger_token and name == TRIGGER_TOKEN then return true end
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
            storage.faction_rules[spec.key] = set_from_list(config[spec.defaults])
        end
        rebuild_after_change(previous)
        if category == '' or category == 'initial-tech' then
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
    if action == 'add' and category == 'initial-tech' then
        grant_initial_rule_to_all(name)
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
