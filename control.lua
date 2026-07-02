local TextHelpers = require("scripts.text_helpers")

---create localization structure
---@return table
local function create_localization_structure()
  return {
    pending = false,
    remaining = 0,
    localization_requests = {},
    translated_names = {},
  }
end

---to be used for resetting localization
local function reset_localization()
  storage.fluidmeter_localization = {}
end

---localization access wrapper
---@param player_index any
---@param create_if_missing any
---@return table|unknown
local function access_localization(player_index, create_if_missing)
  if not storage.fluidmeter_localization then
    if create_if_missing then
      storage.fluidmeter_localization = {}
    else
      return nil
    end
  end

  if not storage.fluidmeter_localization[player_index] and create_if_missing then
    storage.fluidmeter_localization[player_index] = create_localization_structure()
  end

  return storage.fluidmeter_localization[player_index]
end

---failsafe command to reset localization state for a player
local function reset_localization_request(command)
  if not command.player_index then
    return
  end

  local localization = access_localization(command.player_index)
  if not localization then
    return
  end

  localization.pending = false
  localization.remaining = 0
  localization.localization_requests = {}

  local player = game.get_player(command.player_index)
  if player then
    player.print("Display panel fluidmeter localization state reset.")
  end
end

---adds type fluid for signals (if not specified, it is seen as item signal)
---@param fluid_name any
---@return table
local function fluid_signal(fluid_name)
  return {
    type = "fluid",
    name = fluid_name,
  }
end

---filters out hidden fluids and blueprint parameters
---@param fluid any
---@return boolean
local function is_real_fluid(fluid)
  return fluid and fluid.valid and not fluid.hidden and not fluid.parameter
end

---make sure current modpack has display-panel prototypes
---@return unknown
local function has_display_panel_prototypes()
  return prototypes.entity["display-panel"] and prototypes.item["display-panel"]
end

---sort prototype_names by translated_names inplace
---@param prototype_names any
---@param translated_names any
local function sort_names_by_translation(prototype_names, translated_names)
  table.sort(prototype_names, function(a, b)
    local translated_a = translated_names[a] or a
    local translated_b = translated_names[b] or b

    if translated_a == translated_b then
      return a < b
    end

    return translated_a < translated_b
  end)
end

---get sorted table of fluid names
---@return table
local function get_sorted_fluid_names()
  local names = {}

  for name, fluid in pairs(prototypes.fluid) do
    if is_real_fluid(fluid) then
      table.insert(names, name)
    end
  end

  table.sort(names)
  return names
end

---fills in the actual displayed bar with the percentage
---output has fixed width so that on zooming out it will stay aligned
---@param fluid_name any
---@param percent any
---@return string
local function display_panel_text(fluid_name, percent)
  local color = TextHelpers.get_fluid_rich_text_color(fluid_name)
  local bar = TextHelpers.make_fill_bar(percent)
  local percent_text = TextHelpers.format_percent(percent)

  return "[font=default]"
    .. "[color="
    .. color
    .. "]"
    .. "[fluid="
    .. fluid_name
    .. "] "
    .. bar
    .. " [/color] "
    .. percent_text
    .. "[/font]"
end

---add decision logic for the display panel which line to show
---@param fluid_name any
---@return table
local function display_panel_parameters(fluid_name)
  local parameters = {}

  for percent = 0, 100 do
    local comparator = "≤"
    -- skipping 49 as it is negligible (and we only have 100 entries available)
    if percent ~= 49 then
      if percent == 100 then
        comparator = "≥"
      end

      table.insert(parameters, {
        icon = {
          type = "fluid",
          name = fluid_name,
        },
        text = display_panel_text(fluid_name, percent),
        condition = {
          first_signal = {
            type = "fluid",
            name = fluid_name,
          },
          comparator = comparator,
          constant = percent,
        },
      })
    end
  end

  return parameters
end

---adds general data for the display panel entity
---@param fluid_name any
---@return table
local function display_panel_entity(fluid_name)
  return {
    {
      entity_number = 1,
      name = "display-panel",
      position = {
        x = 0,
        y = 0,
      },
      direction = 8,
      control_behavior = {
        parameters = display_panel_parameters(fluid_name),
      },
      always_show = true,
    },
  }
end

---adds blueprint for fluid_name to blueprint_stack, with label and description using translated_name
---@param blueprint_stack any
---@param fluid_name any
---@param translated_name any
local function setup_fluidmeter_blueprint(blueprint_stack, fluid_name, translated_name)
  -- first set blueprint entity
  blueprint_stack.set_blueprint_entities(display_panel_entity(fluid_name))

  -- After entity is set, label and description can be filled
  blueprint_stack.label = translated_name
  blueprint_stack.blueprint_description = "Fluidmeter for " .. translated_name

  blueprint_stack.preview_icons = {
    {
      index = 1,
      signal = fluid_signal(fluid_name),
    },
  }
end

---Creates blueprint book and iterates over fluids to fill book
---@param player any
---@param translated_names any
local function create_fluid_blueprint_book(player, translated_names)
  if not player or not player.valid then
    return
  end

  if not player.clear_cursor() then
    player.print("Could not clear cursor. Please call the command again with an empty cursor.")
    return
  end

  local book = player.cursor_stack
  if not book or not book.valid then
    player.print("Could not access cursor stack. Please call the command again with an empty cursor.")
    return
  end

  if not book.set_stack({ name = "blueprint-book", count = 1 }) then
    player.print("Could not create blueprint book. Please call the command again with an empty cursor.")
    return
  end

  book.label = "Fluidmeter display panels"
  book.blueprint_description = "Generated by display panel fluidmeter mod from current fluid prototypes."

  book.preview_icons = {
    {
      index = 1,
      signal = {
        type = "item",
        name = "display-panel",
      },
    },
  }

  local book_inventory = book.get_inventory(defines.inventory.item_main)
  if not book_inventory or not book_inventory.valid then
    player.print("Could not access blueprint book inventory.")
    return
  end

  local fluid_names = get_sorted_fluid_names()
  sort_names_by_translation(fluid_names, translated_names)
  local created = 0

  for _, fluid_name in ipairs(fluid_names) do
    local before_count = #book_inventory
    local inserted = book_inventory.insert({ name = "blueprint", count = 1 })

    if inserted == 1 then
      local blueprint_stack = book_inventory[before_count + 1]
      local translated_name = translated_names[fluid_name] or fluid_name

      setup_fluidmeter_blueprint(blueprint_stack, fluid_name, translated_name)
      created = created + 1
    else
      player.print("Could not insert blueprint for " .. fluid_name)
    end
  end

  player.print("Created fluid display book with " .. created .. " fluid blueprints.")
end

---request missing translations for fluids or create blueprint book when all translations are already received
---@param player any
local function handle_fluid_translations(player)
  local fluid_names = get_sorted_fluid_names()

  local localization = access_localization(player.index, true)

  if localization.pending then
    player.print("Translation requests are still pending. The blueprint book will be created in your hand shortly.")
    return
  end

  localization.localization_requests = {}
  localization.remaining = 0

  for _, fluid_name in ipairs(fluid_names) do
    if localization.translated_names[fluid_name] == nil then
      -- request translation for this fluid
      local fluid = prototypes.fluid[fluid_name]
      local request_id = player.request_translation(fluid.localised_name)

      if request_id then
        localization.pending = true
        localization.remaining = localization.remaining + 1
        localization.localization_requests[request_id] = fluid_name
      else
        localization.translated_names[fluid_name] = fluid_name
      end
    end
  end

  if localization.remaining == 0 then
    localization.pending = false
    -- all translations were already available, create the blueprint book
    create_fluid_blueprint_book(player, localization.translated_names)
    return
  end
end

---initiates process - sort-of-main()-function
local function handle_fluidmeter_book_command(command)
  if not command.player_index then
    game.print("This command must be run by a player.")
    return
  end

  local player = game.get_player(command.player_index)
  if not player or not player.valid then
    return
  end

  if not has_display_panel_prototypes() then
    player.print("Display panel prototype is not available. Cannot create fluidmeter blueprints.")
    return
  end

  handle_fluid_translations(player)
end

-- stylua: ignore
-- add console command for main functionality
commands.add_command(
  "fluidmeter-book",
  "Create a fluidmeter blueprint book.",
  handle_fluidmeter_book_command
)

-- add failsafe console command to reset localization handling
commands.add_command(
  "fluidmeter-reset",
  "Reset pending display panel fluidmeter localization requests.",
  reset_localization_request
)

---store localized names in volatile memory
---@param event EventData.on_string_translated
script.on_event(defines.events.on_string_translated, function(event)
  local localization = access_localization(event.player_index)

  if not localization then
    return
  end

  -- remember the translated name for the fluid
  local fluid_name = localization.localization_requests[event.id]
  if not fluid_name then
    return
  end

  -- store localized name or fallback to untranslated name if translation failed
  if event.translated then
    localization.translated_names[fluid_name] = event.result
  else
    localization.translated_names[fluid_name] = fluid_name
  end

  -- remove the request from the pending list and decrement remaining count
  localization.localization_requests[event.id] = nil
  localization.remaining = localization.remaining - 1

  if localization.remaining > 0 then
    return
  end

  -- all translations have been received, create the blueprint book
  localization.pending = false
  localization.localization_requests = {}
  localization.remaining = 0

  local player = game.get_player(event.player_index)
  create_fluid_blueprint_book(player, localization.translated_names)
end)

---Throw away translated name when locale changed
---@param event EventData.on_player_locale_changed
script.on_event(defines.events.on_player_locale_changed, function(event)
  reset_localization()
end)

---Throw away translated names when a mod was updated or removed
script.on_configuration_changed(function(event)
  reset_localization()
end)
