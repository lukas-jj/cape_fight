# Punchalot Card Pack Generator
# --------------------------------------------------------------
# Purpose: Quickly create the 25 Punchalot Card resources (.tres)
#          and the two card-pile resources (starting deck &
#          draftable pool) described in the design document.
# Usage:
#   1. In the Godot editor, add this script as an "EditorScript".
#      • Project ▸ Tools ▸ "Run" (or Right-click ▸ Run).
#   2. The script will create:
#        res://characters/punchalot/
#            punchalot_starting_deck.tres
#            punchalot_draftable_cards.tres
#            cards/*.tres (25 files)
#   3. Review the generated resources.
#      For cards listed in NEEDS_SCRIPT, attach or duplicate an
#      appropriate logic script (you can copy warrior card .gd's).
#   4. Wire Punchalot into your character-select screen.
#
# Safe to run multiple times – it overwrites only if the resource
# on disk is identical; otherwise it warns.
# --------------------------------------------------------------
extends EditorScript

const CARD_SCRIPT      : Script = preload("res://custom_resources/card.gd")
const CARD_PILE_SCRIPT : Script = preload("res://custom_resources/card_pile.gd")

# Card IDs that need custom behaviour – attach your scripts later.
const NEEDS_SCRIPT : PackedStringArray = [
    "punchalot_jab",
    "punchalot_shield_bash",
    "punchalot_iron_body",
    "punchalot_unbreakable",
    "punchalot_counter_stance",
    "punchalot_knuckle_crush",
    "punchalot_stonewall",
    "punchalot_pain_to_power",
    "punchalot_focused_wrath",
    "punchalot_shield_return",
    "punchalot_last_stand",
    "punchalot_momentum_guard",
]

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------
func _run() -> void:
    var base_dir  : String = "res://characters/punchalot/"
    var cards_dir : String = base_dir + "cards/"

    DirAccess.make_dir_recursive(cards_dir)

    var card_defs : Array[Dictionary] = [
        {id:"punchalot_jab",           type:Card.Type.ATTACK,  rarity:Card.Rarity.COMMON,   target:Card.Target.SINGLE_ENEMY, cost:0, tooltip:"[center]Deal [color=\"ff0000\"]4[/color] damage. If you have Block, deal 6 instead.[/center]"},
        {id:"punchalot_guard_up",      type:Card.Type.SKILL,   rarity:Card.Rarity.COMMON,   target:Card.Target.SELF,         cost:1, tooltip:"[center]Gain [color=\"0044ff\"]12[/color] Block.[/center]"},
        {id:"punchalot_heavy_slam",    type:Card.Type.ATTACK,  rarity:Card.Rarity.COMMON,   target:Card.Target.SINGLE_ENEMY, cost:2, tooltip:"[center]Deal [color=\"ff0000\"]18[/color] damage.[/center]"},
        {id:"punchalot_shield_bash",   type:Card.Type.ATTACK,  rarity:Card.Rarity.UNCOMMON, target:Card.Target.SINGLE_ENEMY, cost:1, tooltip:"[center]Gain 6 Block. Deal 6 damage. Apply 1 Weak.[/center]"},
        {id:"punchalot_iron_body",     type:Card.Type.SKILL,   rarity:Card.Rarity.UNCOMMON, target:Card.Target.SELF,         cost:1, tooltip:"[center]Gain 8 Block. Start next turn with 4 Block.[/center]"},
        {id:"punchalot_unbreakable",   type:Card.Type.POWER,   rarity:Card.Rarity.UNCOMMON, target:Card.Target.SELF,         cost:2, tooltip:"[center]At the start of your turn, gain 5 Block.[/center]"},
        {id:"punchalot_shockwave",     type:Card.Type.ATTACK,  rarity:Card.Rarity.UNCOMMON, target:Card.Target.ALL_ENEMIES,  cost:2, tooltip:"[center]Deal 10 damage to all enemies. Exhaust.[/center]", exhausts:true},
        {id:"punchalot_bulwark",       type:Card.Type.SKILL,   rarity:Card.Rarity.UNCOMMON, target:Card.Target.SELF,         cost:2, tooltip:"[center]Gain [color=\"0044ff\"]20[/color] Block.[/center]"},
        {id:"punchalot_counter_stance",type:Card.Type.POWER,   rarity:Card.Rarity.UNCOMMON, target:Card.Target.SELF,         cost:1, tooltip:"[center]If hit this turn, deal 10 damage back.[/center]"},
        {id:"punchalot_knuckle_crush", type:Card.Type.ATTACK,  rarity:Card.Rarity.COMMON,   target:Card.Target.SINGLE_ENEMY, cost:1, tooltip:"[center]Deal 8 damage. If you gained Block this turn, deal 6 more.[/center]"},
        {id:"punchalot_stonewall",     type:Card.Type.SKILL,   rarity:Card.Rarity.UNCOMMON, target:Card.Target.SELF,         cost:1, tooltip:"[center]Gain 14 Block. Next turn, gain 2 Strength.[/center]"},
        {id:"punchalot_pain_to_power", type:Card.Type.POWER,   rarity:Card.Rarity.RARE,     target:Card.Target.SELF,         cost:2, tooltip:"[center]Each time you lose HP, gain 1 Strength.[/center]"},

        {id:"punchalot_brace",         type:Card.Type.SKILL,   rarity:Card.Rarity.COMMON,   target:Card.Target.SELF,         cost:1, tooltip:"[center]Gain 10 Block. Draw 1 card.[/center]"},
        {id:"punchalot_ground_pound",  type:Card.Type.ATTACK,  rarity:Card.Rarity.RARE,     target:Card.Target.ALL_ENEMIES, cost:3, tooltip:"[center]Deal 30 damage to all enemies. Exhaust.[/center]", exhausts:true},
        {id:"punchalot_focused_wrath", type:Card.Type.ATTACK,  rarity:Card.Rarity.UNCOMMON, target:Card.Target.SINGLE_ENEMY, cost:1, tooltip:"[center]Deal 12 damage. If this is your only ATTACK this turn, deal 6 more.[/center]"},
        {id:"punchalot_shield_return", type:Card.Type.ATTACK,  rarity:Card.Rarity.UNCOMMON, target:Card.Target.SINGLE_ENEMY, cost:1, tooltip:"[center]Gain 6 Block. Then deal damage equal to your Block.[/center]"},
        {id:"punchalot_last_stand",    type:Card.Type.POWER,   rarity:Card.Rarity.RARE,     target:Card.Target.SELF,         cost:1, tooltip:"[center]While under 20 HP, gain +1 energy each turn.[/center]"},
        {id:"punchalot_bunker_down",   type:Card.Type.SKILL,   rarity:Card.Rarity.COMMON,   target:Card.Target.SELF,         cost:1, tooltip:"[center]Gain 12 Block. If you played no ATTACK this turn, gain 6 more.[/center]"},
        {id:"punchalot_shield_spin",   type:Card.Type.ATTACK,  rarity:Card.Rarity.UNCOMMON, target:Card.Target.ALL_ENEMIES, cost:2, tooltip:"[center]Deal 5 damage twice to all enemies. Gain 5 Block.[/center]"},
        {id:"punchalot_slam_set_up",   type:Card.Type.SKILL,   rarity:Card.Rarity.COMMON,   target:Card.Target.SELF,         cost:0, tooltip:"[center]Next ATTACK this turn deals double damage.[/center]"},
        {id:"punchalot_iron_flex",     type:Card.Type.SKILL,   rarity:Card.Rarity.COMMON,   target:Card.Target.SELF,         cost:1, tooltip:"[center]Gain 8 Block. Next turn, gain 1 Strength.[/center]"},
        {id:"punchalot_momentum_guard",type:Card.Type.POWER,   rarity:Card.Rarity.UNCOMMON, target:Card.Target.SELF,         cost:2, tooltip:"[center]Gain 4 Block at the end of each turn.[/center]"},
        {id:"punchalot_backbreaker",   type:Card.Type.ATTACK,  rarity:Card.Rarity.RARE,     target:Card.Target.SINGLE_ENEMY, cost:2, tooltip:"[center]Deal 24 damage. If the enemy has Vulnerable, apply Weak and Exhaust.[/center]", exhausts:true},
        {id:"punchalot_hammerfall",    type:Card.Type.ATTACK,  rarity:Card.Rarity.UNCOMMON, target:Card.Target.SINGLE_ENEMY, cost:1, tooltip:"[center]Deal 10 damage. Apply 1 Vulnerable.[/center]"},
        {id:"punchalot_steel_hide",    type:Card.Type.SKILL,   rarity:Card.Rarity.COMMON,   target:Card.Target.SELF,         cost:1, tooltip:"[center]Gain 12 Block. Reduce all damage taken by 1 for the rest of this turn.[/center]"},
    ]

    var saved_cards : Dictionary = {}
    for def in card_defs:
        var res_path := cards_dir + def.id + ".tres"
        var card_res : Card
        if ResourceLoader.exists(res_path):
            # Already exists – load & update simple fields if needed.
            card_res = load(res_path)
        else:
            card_res = Card.new()
        
        card_res.script       = CARD_SCRIPT
        card_res.id           = def.id
        card_res.type         = def.type
        card_res.rarity       = def.rarity
        card_res.target       = def.target
        card_res.cost         = def.cost
        card_res.exhausts     = def.get("exhausts", false)
        card_res.tooltip_text = def.tooltip

        var err := ResourceSaver.save(card_res, res_path)
        if err != OK:
            push_error("Failed to save card %s (err=%s)" % [def.id, err])
        else:
            saved_cards[def.id] = load(res_path)

        # Warn if script still needed
        if NEEDS_SCRIPT.has(def.id) and card_res.script == CARD_SCRIPT:
            push_warning("%s still lacks a custom script – gameplay may be incomplete." % def.id)

    # --- Starting Deck (12 specified IDs) ---
    var starting_ids := [
        "punchalot_jab","punchalot_guard_up","punchalot_heavy_slam","punchalot_shield_bash",
        "punchalot_iron_body","punchalot_unbreakable","punchalot_shockwave","punchalot_bulwark",
        "punchalot_counter_stance","punchalot_knuckle_crush","punchalot_stonewall","punchalot_pain_to_power"
    ]
    _save_pile(base_dir + "punchalot_starting_deck.tres", starting_ids, saved_cards)

    # --- Draftable (13 remaining) ---
    var draftable_ids : Array = []
    for d in card_defs:
        if not starting_ids.has(d.id):
            draftable_ids.append(d.id)
    _save_pile(base_dir + "punchalot_draftable_cards.tres", draftable_ids, saved_cards)

    print("[Punchalot] Card pack generated ✔")

# ---------------------------------------------------------------------------
func _save_pile(path:String, ids:Array, card_lookup:Dictionary):
    var pile : Resource
    if ResourceLoader.exists(path):
        pile = load(path)
    else:
        pile = CARD_PILE_SCRIPT.new()
        pile.cards = []
    
    pile.cards.clear()
    for id in ids:
        pile.cards.append(card_lookup[id])

    var err := ResourceSaver.save(pile, path)
    if err != OK:
        push_error("Failed to save pile at %s (err=%s)" % [path, err])
