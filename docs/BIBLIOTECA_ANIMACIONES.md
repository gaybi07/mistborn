# Biblioteca de animaciones

Generada con `python tools/anim_library.py` (no editar a mano: volver a correrlo).

**Origen:** *nativa* = el clip tal cual vino (Meshy, Mixamo, ActionForge o pack). *Retocada por Claude* = editada
en ActionForge (Adjust, rotaciones de huesos) o recortada en el juego (tramo, velocidad, pose fija).
*Hecha por Claude* = generada por código: **ninguna** de los héroes; solo el cuerpo de reserva hecho con
primitivas (`HumanoidRig`, `Art._procedural`) se anima por código, y no lo usa ningún personaje elegible.

Encima de cualquier clip el juego suma capas en vivo: mano cerrada sin arma (`Punch_Pose`), IK de pies, y las
mezclas entre clips (`ModelRig._begin_fade`). No cambian el clip.

## Qué usa cada acción de los héroes (Vin y los demás de `Art.HEROES`)

El clip se busca en este orden: el modelo del héroe (para Vin, `VinCorregida.glb`), el encapuchado,
`Vin.glb` y `AFClips.glb`. La columna *Archivo* es donde lo encuentra Vin.

| Acción (estado) | Clip | Archivo | Origen | Retoque en el juego |
|---|---|---|---|---|
| `air` | `Regular_Jump` | MistbornHood.glb | Meshy, nativa | retocada: pose fija en el 55% |
| `allomancy` | `mage_soell_cast_3` | MistbornHood.glb | Meshy, nativa | retocada: pose fija en el 50% |
| `attack_air` | `Double_Blade_Spin` | MistbornHood.glb | Meshy, nativa | retocada: tramo 5%–32%, golpe 27% |
| `attack_air_fist` | `Rising_Flying_Kick` | Vin.glb | Meshy, nativa | retocada: tramo 0%–80%, golpe 35% |
| `attack_air_shield` | `Sword_Judgment` | MistbornHood.glb | Meshy, nativa | retocada: tramo 10%–40%, golpe 23% |
| `attack_air_sword` | `Charged_Upward_Slash` | Vin.glb | Meshy, nativa | retocada: tramo 10%–60%, golpe 32% |
| `attack_daggers` | `Right_Hand_Sword_Slash` | Vin.glb | Meshy, nativa | retocada: tramo 5%–70%, golpe 35% |
| `attack_daggers_1` | `Triple_Combo_Attack` | MistbornHood.glb | Meshy, nativa | retocada: tramo 27%–44%, golpe 35% |
| `attack_daggers_2` | `Triple_Combo_Attack` | MistbornHood.glb | Meshy, nativa | retocada: tramo 44%–75%, golpe 52% |
| `attack_daggers_3` | `Double_Blade_Spin` | MistbornHood.glb | Meshy, nativa | retocada: tramo 5%–32%, golpe 27% |
| `attack_fist` | `Punch_Combo` | MistbornHood.glb | Meshy, nativa | retocada: tramo 10%–38%, golpe 27% |
| `attack_fist_1` | `Punch_Combo` | MistbornHood.glb | Meshy, nativa | retocada: tramo 38%–70%, golpe 51% |
| `attack_fist_2` | `Punch_Combo_2` | Vin.glb | Meshy, nativa | retocada: tramo 28%–55%, golpe 42% |
| `attack_fist_3` | `Step_in_High_Kick` | Vin.glb | Meshy, nativa | retocada: tramo 0%–80%, golpe 40% |
| `attack_shield` | `Weapon_Combo_1` | MistbornHood.glb | Meshy, nativa | retocada: tramo 8%–35%, golpe 23% |
| `attack_shield_1` | `Weapon_Combo_1` | MistbornHood.glb | Meshy, nativa | retocada: tramo 35%–58%, golpe 48% |
| `attack_shield_2` | `Shield_Push_Left` | Vin.glb | Meshy, nativa | retocada: tramo 10%–60%, golpe 30% |
| `attack_sword` | `Weapon_Combo` | MistbornHood.glb | Meshy, nativa | retocada: tramo 5%–27%, golpe 18% |
| `attack_sword_1` | `Weapon_Combo` | MistbornHood.glb | Meshy, nativa | retocada: tramo 27%–47%, golpe 35% |
| `attack_sword_2` | `Weapon_Combo_2` | MistbornHood.glb | Meshy, nativa | retocada: tramo 12%–38%, golpe 24% |
| `attack_sword_3` | `Charged_Slash` | Vin.glb | Meshy, nativa | retocada: tramo 20%–80%, golpe 55% |
| `attack_sword_4` | `Weapon_Combo` | MistbornHood.glb | Meshy, nativa | retocada: tramo 47%–90%, golpe 61% |
| `block` | `Block5` | MistbornHood.glb | Meshy, nativa | entera |
| `block_shield` | `Block3` | Vin.glb | Meshy, nativa | entera |
| `block_shield_hit` | `Block3` | Vin.glb | Meshy, nativa | entera |
| `climb` | `Regular_Jump` | MistbornHood.glb | Meshy, nativa | retocada: tramo 20%–50% |
| `coin_shield` | `Charged_Spell_Cast` | MistbornHood.glb | Meshy, nativa | retocada: tramo 10%–80%, golpe 65% |
| `coin_wave` | `mage_soell_cast_2` | MistbornHood.glb | Meshy, nativa | retocada: tramo 0%–70%, golpe 41% |
| `crouch_idle` | `crouch_idle_af` | AFCrouch.glb | ActionForge, retocada por Claude (Crouch Idle Loop, Adjust: pecho -20°, cabeza +25°) | entera |
| `crouch_walk` | `Cautious_Crouch_Walk_Forward_inplace` | Vin.glb | Meshy, nativa | entera |
| `dash` | `Roll_Dodge` | MistbornHood.glb | Meshy, nativa | retocada: tramo 25%–80% |
| `dodge_left` | `Stand_Dodge` | MistbornHood.glb | Meshy, nativa | entera |
| `dodge_right` | `Stand_Dodge` | MistbornHood.glb | Meshy, nativa | entera |
| `down` | `Dead` | MistbornHood.glb | Meshy, nativa | entera |
| `fall_roll` | `Roll_Dodge_1` | MistbornHood.glb | Meshy, nativa | entera |
| `flee` | `Running` | VinCorregida.glb | Meshy, nativa | entera |
| `fly` | `Vuelo_B` | VinCorregida.glb | Meshy, nativa | entera |
| `fly_coin` | `Vuelo_Moneda` | VinCorregida.glb | Meshy, nativa | entera |
| `fly_glide` | `Fall2` | Vin.glb | Meshy, nativa | retocada: pose fija en el 95% |
| `fly_launch` | `Vuelo_A` | VinCorregida.glb | Meshy, nativa | retocada: tramo 10%–45% |
| `fly_rise` | `idle_loop_adjusted` | AFClips.glb | ActionForge, retocada por Claude (brazos, cabeza, postura y piernas juntas: pose Ironman) | entera |
| `freefall` | `Dive_Down_and_Land` | Vin.glb | Meshy, nativa | retocada: pose fija en el 80% |
| `get_up` | `Arise` | Vin.glb | Meshy, nativa | entera |
| `hang` | `Bar_Hang_Idle` | Vin.glb | Meshy, nativa | entera |
| `hit` | `Hit_Reaction` | Vin.glb | Meshy, nativa | retocada: tramo 0%–70% |
| `hit_back` | `Slap_Reaction` | Vin.glb | Meshy, nativa | retocada: tramo 10%–50% |
| `hit_front` | `Step_Back` | Vin.glb | Meshy, nativa | entera |
| `hit_head` | `Hit_Reaction_to_Waist` | Vin.glb | Meshy, nativa | retocada: tramo 0%–70% |
| `hit_knockback` | `Step_Back` | Vin.glb | Meshy, nativa | entera |
| `hit_left` | `Slap_Reaction` | Vin.glb | Meshy, nativa | retocada: tramo 10%–50% |
| `hit_right` | `Slap_Reaction` | Vin.glb | Meshy, nativa | retocada: tramo 10%–50% |
| `idle` | `Idle_11` | Vin.glb | Meshy, nativa | entera |
| `idle_armed` | `Combat_Stance` | MistbornHood.glb | Meshy, nativa | entera |
| `idle_armed_daggers` | `knife_idle_mx` | HeroMixamoXBot.glb | Mixamo, nativa (Knife Idle, sobre CH36): guardia de dagas | entera |
| `idle_armed_fist` | `fight_idle_mx` | HeroMixamoXBot.glb | Mixamo, nativa (Fighting Idle, sobre CH36): guardia de puños | entera |
| `idle_armed_shield` | `Alert` | VinCorregida.glb | Meshy, nativa | entera |
| `idle_armed_sword` | `Alert` | VinCorregida.glb | Meshy, nativa | entera |
| `jump` | `Regular_Jump` | MistbornHood.glb | Meshy, nativa | retocada: tramo 12%–60% |
| `jump_crouch` | `Jump_and_Grab_Wall` | Vin.glb | Meshy, nativa | retocada: tramo 12%–55% |
| `jump_double` | `Parkour_Vault_3` | Vin.glb | Meshy, nativa | retocada: tramo 12%–80% |
| `land` | `Regular_Jump` | MistbornHood.glb | Meshy, nativa | retocada: tramo 62%–100% |
| `pickup` | `Collect_Object` | Vin.glb | Meshy, nativa | retocada: tramo 20%–70% |
| `roll` | `Roll_Dodge` | MistbornHood.glb | Meshy, nativa | entera |
| `roll_slide` | `slide_light` | MistbornHood.glb | Meshy, nativa | retocada: tramo 5%–85% |
| `run` | `Running` | VinCorregida.glb | Meshy, nativa | entera |
| `slam` | `Charged_Ground_Slam` | Vin.glb | Meshy, nativa | retocada: tramo 10%–95%, golpe 55% |
| `slide` | `slide_light` | MistbornHood.glb | Meshy, nativa | retocada: pose fija en el 25% |
| `sprint` | `RunFast` | MistbornHood.glb | Meshy, nativa | entera |
| `sprint_top` | `RunFast` | MistbornHood.glb | Meshy, nativa | entera |
| `stop` | `Sprint_and_Sudden_Stop` | Vin.glb | Meshy, nativa | entera |
| `swim` | `Swim_Forward` | MistbornHood.glb | Meshy, nativa | entera |
| `swim_idle` | `Swim_Idle` | MistbornHood.glb | Meshy, nativa | entera |
| `throw` | `mage_soell_cast_4` | MistbornHood.glb | Meshy, nativa | retocada: tramo 10%–70%, golpe 24% |
| `walk` | `Walking` | VinCorregida.glb | Meshy, nativa | entera |
| `walk_fist` | `Walking` | VinCorregida.glb | Meshy, nativa | entera |
| `walk_shield` | `Spear_Walk` | Vin.glb | Meshy, nativa | entera |
| `walk_sword` | `Spear_Walk` | Vin.glb | Meshy, nativa | entera |

## Gestos de poderes (mitad de arriba del cuerpo)

| Poder | Clip | Archivo | Origen | Retoque en el juego |
|---|---|---|---|---|
| `burn_focus` | `mage_soell_cast_6` | MistbornHood.glb | Meshy, nativa | retocada: tramo 10%–45%, suelta en 35% |
| `clear_mind` | `focus_mx` | HeroMixamoXBot.glb | Mixamo, nativa (Focus, sobre CH36): Mente despejada | retocada: tramo 20%–80%, suelta en 55% |
| `coin_flick` | `overhandthrow_adjusted` | AFClips.glb | ActionForge, retocada por Claude (Adjust: pecho -20°, cabeza +20°) | retocada: tramo 12%–36%, suelta en 29%, velocidad 0.47 |
| `coin_magnet` | `mage_soell_cast_7` | Vin.glb | Meshy, nativa | retocada: tramo 30%–90%, suelta en 55% |
| `coin_shield` | `mage_soell_cast_6` | MistbornHood.glb | Meshy, nativa | retocada: tramo 10%–70%, suelta en 40% |
| `coin_wave` | `frisbee_throw_mx` | HeroMixamoXBot.glb | Mixamo, nativa (Frisbee Throw): la Ráfaga de monedas | retocada: tramo 27%–47%, suelta en 44%, velocidad 1.0 |
| `disarm` | `rope_pull_mx` | HeroMixamoXBot.glb | Mixamo, nativa (Pulling A Rope, sobre CH36): Arrastre y Desarme | retocada: tramo 17%–32%, suelta en 28% |
| `drink` | `Stand_and_Drink` | Vin.glb | Meshy, nativa | retocada: tramo 20%–60%, suelta en 55% |
| `extreme_senses` | `looking_around_mx` | HeroMixamoXBot.glb | Mixamo, nativa (Looking Around, sobre CH36): Sentidos extremos | retocada: tramo 5%–85%, suelta en 35% |
| `field` | `mage_soell_cast_1` | Vin.glb | Meshy, nativa | retocada: tramo 20%–65%, suelta en 50% |
| `fury` | `roar_mx` | HeroMixamoXBot.glb | Mixamo, nativa (Roar, sobre CH36): Furia | retocada: tramo 15%–85%, suelta en 35% |
| `hunter_mark` | `pointing_forward_mx` | HeroMixamoXBot.glb | Mixamo, nativa (Pointing Forward, sobre CH36): Marca del cazador | retocada: tramo 25%–62%, suelta en 45% |
| `iron_drag` | `rope_pull_mx` | HeroMixamoXBot.glb | Mixamo, nativa (Pulling A Rope, sobre CH36): Arrastre y Desarme | retocada: tramo 15%–52%, suelta en 30% |
| `iron_pull` | `mage_soell_cast_3` | MistbornHood.glb | Meshy, nativa | retocada: tramo 10%–60%, suelta en 27% |
| `mass_yank` | `magic_pull_blast_mx` | HeroMixamoXBot.glb | Mixamo, nativa (Standing 2H Magic Area Attack 02, sobre CH36): Atracción masiva | retocada: tramo 15%–52%, suelta en 48% |
| `pewter_flex` | `Charged_Spell_Cast` | MistbornHood.glb | Meshy, nativa | retocada: tramo 10%–45%, suelta en 23% |
| `pull_heavy` | `mage_soell_cast_3` | MistbornHood.glb | Meshy, nativa | retocada: tramo 10%–60%, suelta en 27% |
| `spear` | `mage_soell_cast_3` | MistbornHood.glb | Meshy, nativa | retocada: tramo 10%–60%, suelta en 27% |
| `steel_push` | `Punch_Forward_with_Both_Fists` | MistbornHood.glb | Meshy, nativa | retocada: tramo 30%–60%, suelta en 45% |
| `tin_focus` | `thinking_mx` | HeroMixamoXBot.glb | Mixamo, nativa (Thinking, sobre CH36): Foco | retocada: tramo 10%–66%, suelta en 25% |

## Todos los archivos y sus clips

### `assets/actionforge/AFClips.glb` (12)

Origen: ActionForge y Mixamo (ver detalle por clip).

- `punch_cross`: ActionForge, nativa
- `punch_jab`: ActionForge, nativa
- `overhandthrow_adjusted`: ActionForge, retocada por Claude (Adjust: pecho -20°, cabeza +20°)
- `idle_loop_adjusted`: ActionForge, retocada por Claude (brazos, cabeza, postura y piernas juntas: pose Ironman)
- `spell_simple_enter`: ActionForge, nativa (sin uso por ahora)
- `spell_simple_shoot`: ActionForge, nativa (sin uso por ahora)
- `spell_simple_exit`: ActionForge, nativa (sin uso por ahora)
- `push_loop`: ActionForge, nativa (sin uso por ahora)
- `ninjajump_start`: ActionForge, nativa: despegue de los saltos del Lord Legislador
- `ninjajump_land`: ActionForge, nativa: caída de los saltos del Lord Legislador
- `sword_dash`: ActionForge, nativa (sin uso: trae el avance en la cadera)
- `coin_throw_af`: ActionForge, retocada por Claude (Sword Regular B: postura y brazos con claves), sin uso por ahora

### `assets/actionforge/AFCrouch.glb` (1)

Origen: sin clasificar.

`crouch_idle_af`

### `assets/kaykit/characters/Barbarian.glb` (76)

Origen: KayKit: pack nativo (personajes chibi).

`1H_Melee_Attack_Chop`, `1H_Melee_Attack_Slice_Diagonal`, `1H_Melee_Attack_Slice_Horizontal`, `1H_Melee_Attack_Stab`, `1H_Ranged_Aiming`, `1H_Ranged_Reload`, `1H_Ranged_Shoot`, `1H_Ranged_Shooting`, `2H_Melee_Attack_Chop`, `2H_Melee_Attack_Slice`, `2H_Melee_Attack_Spin`, `2H_Melee_Attack_Spinning`, `2H_Melee_Attack_Stab`, `2H_Melee_Idle`, `2H_Ranged_Aiming`, `2H_Ranged_Reload`, `2H_Ranged_Shoot`, `2H_Ranged_Shooting`, `Block`, `Block_Attack`, `Block_Hit`, `Blocking`, `Cheer`, `Death_A`, `Death_A_Pose`, `Death_B`, `Death_B_Pose`, `Dodge_Backward`, `Dodge_Forward`, `Dodge_Left`, `Dodge_Right`, `Dualwield_Melee_Attack_Chop`, `Dualwield_Melee_Attack_Slice`, `Dualwield_Melee_Attack_Stab`, `Hit_A`, `Hit_B`, `Idle`, `Interact`, `Jump_Full_Long`, `Jump_Full_Short`, `Jump_Idle`, `Jump_Land`, `Jump_Start`, `Lie_Down`, `Lie_Idle`, `Lie_Pose`, `Lie_StandUp`, `PickUp`, `Running_A`, `Running_B`, `Running_Strafe_Left`, `Running_Strafe_Right`, `Sit_Chair_Down`, `Sit_Chair_Idle`, `Sit_Chair_Pose`, `Sit_Chair_StandUp`, `Sit_Floor_Down`, `Sit_Floor_Idle`, `Sit_Floor_Pose`, `Sit_Floor_StandUp`, `Spellcast_Long`, `Spellcast_Raise`, `Spellcast_Shoot`, `Spellcasting`, `T-Pose`, `Throw`, `Unarmed_Idle`, `Unarmed_Melee_Attack_Kick`, `Unarmed_Melee_Attack_Punch_A`, `Unarmed_Melee_Attack_Punch_B`, `Unarmed_Pose`, `Use_Item`, `Walking_A`, `Walking_B`, `Walking_Backwards`, `Walking_C`

### `assets/kaykit/characters/Knight.glb` (76)

Origen: KayKit: pack nativo (personajes chibi).

`1H_Melee_Attack_Chop`, `1H_Melee_Attack_Slice_Diagonal`, `1H_Melee_Attack_Slice_Horizontal`, `1H_Melee_Attack_Stab`, `1H_Ranged_Aiming`, `1H_Ranged_Reload`, `1H_Ranged_Shoot`, `1H_Ranged_Shooting`, `2H_Melee_Attack_Chop`, `2H_Melee_Attack_Slice`, `2H_Melee_Attack_Spin`, `2H_Melee_Attack_Spinning`, `2H_Melee_Attack_Stab`, `2H_Melee_Idle`, `2H_Ranged_Aiming`, `2H_Ranged_Reload`, `2H_Ranged_Shoot`, `2H_Ranged_Shooting`, `Block`, `Block_Attack`, `Block_Hit`, `Blocking`, `Cheer`, `Death_A`, `Death_A_Pose`, `Death_B`, `Death_B_Pose`, `Dodge_Backward`, `Dodge_Forward`, `Dodge_Left`, `Dodge_Right`, `Dualwield_Melee_Attack_Chop`, `Dualwield_Melee_Attack_Slice`, `Dualwield_Melee_Attack_Stab`, `Hit_A`, `Hit_B`, `Idle`, `Interact`, `Jump_Full_Long`, `Jump_Full_Short`, `Jump_Idle`, `Jump_Land`, `Jump_Start`, `Lie_Down`, `Lie_Idle`, `Lie_Pose`, `Lie_StandUp`, `PickUp`, `Running_A`, `Running_B`, `Running_Strafe_Left`, `Running_Strafe_Right`, `Sit_Chair_Down`, `Sit_Chair_Idle`, `Sit_Chair_Pose`, `Sit_Chair_StandUp`, `Sit_Floor_Down`, `Sit_Floor_Idle`, `Sit_Floor_Pose`, `Sit_Floor_StandUp`, `Spellcast_Long`, `Spellcast_Raise`, `Spellcast_Shoot`, `Spellcasting`, `T-Pose`, `Throw`, `Unarmed_Idle`, `Unarmed_Melee_Attack_Kick`, `Unarmed_Melee_Attack_Punch_A`, `Unarmed_Melee_Attack_Punch_B`, `Unarmed_Pose`, `Use_Item`, `Walking_A`, `Walking_B`, `Walking_Backwards`, `Walking_C`

### `assets/kaykit/characters/Mage.glb` (76)

Origen: KayKit: pack nativo (personajes chibi).

`1H_Melee_Attack_Chop`, `1H_Melee_Attack_Slice_Diagonal`, `1H_Melee_Attack_Slice_Horizontal`, `1H_Melee_Attack_Stab`, `1H_Ranged_Aiming`, `1H_Ranged_Reload`, `1H_Ranged_Shoot`, `1H_Ranged_Shooting`, `2H_Melee_Attack_Chop`, `2H_Melee_Attack_Slice`, `2H_Melee_Attack_Spin`, `2H_Melee_Attack_Spinning`, `2H_Melee_Attack_Stab`, `2H_Melee_Idle`, `2H_Ranged_Aiming`, `2H_Ranged_Reload`, `2H_Ranged_Shoot`, `2H_Ranged_Shooting`, `Block`, `Block_Attack`, `Block_Hit`, `Blocking`, `Cheer`, `Death_A`, `Death_A_Pose`, `Death_B`, `Death_B_Pose`, `Dodge_Backward`, `Dodge_Forward`, `Dodge_Left`, `Dodge_Right`, `Dualwield_Melee_Attack_Chop`, `Dualwield_Melee_Attack_Slice`, `Dualwield_Melee_Attack_Stab`, `Hit_A`, `Hit_B`, `Idle`, `Interact`, `Jump_Full_Long`, `Jump_Full_Short`, `Jump_Idle`, `Jump_Land`, `Jump_Start`, `Lie_Down`, `Lie_Idle`, `Lie_Pose`, `Lie_StandUp`, `PickUp`, `Running_A`, `Running_B`, `Running_Strafe_Left`, `Running_Strafe_Right`, `Sit_Chair_Down`, `Sit_Chair_Idle`, `Sit_Chair_Pose`, `Sit_Chair_StandUp`, `Sit_Floor_Down`, `Sit_Floor_Idle`, `Sit_Floor_Pose`, `Sit_Floor_StandUp`, `Spellcast_Long`, `Spellcast_Raise`, `Spellcast_Shoot`, `Spellcasting`, `T-Pose`, `Throw`, `Unarmed_Idle`, `Unarmed_Melee_Attack_Kick`, `Unarmed_Melee_Attack_Punch_A`, `Unarmed_Melee_Attack_Punch_B`, `Unarmed_Pose`, `Use_Item`, `Walking_A`, `Walking_B`, `Walking_Backwards`, `Walking_C`

### `assets/kaykit/characters/Rogue.glb` (76)

Origen: KayKit: pack nativo (personajes chibi).

`1H_Melee_Attack_Chop`, `1H_Melee_Attack_Slice_Diagonal`, `1H_Melee_Attack_Slice_Horizontal`, `1H_Melee_Attack_Stab`, `1H_Ranged_Aiming`, `1H_Ranged_Reload`, `1H_Ranged_Shoot`, `1H_Ranged_Shooting`, `2H_Melee_Attack_Chop`, `2H_Melee_Attack_Slice`, `2H_Melee_Attack_Spin`, `2H_Melee_Attack_Spinning`, `2H_Melee_Attack_Stab`, `2H_Melee_Idle`, `2H_Ranged_Aiming`, `2H_Ranged_Reload`, `2H_Ranged_Shoot`, `2H_Ranged_Shooting`, `Block`, `Block_Attack`, `Block_Hit`, `Blocking`, `Cheer`, `Death_A`, `Death_A_Pose`, `Death_B`, `Death_B_Pose`, `Dodge_Backward`, `Dodge_Forward`, `Dodge_Left`, `Dodge_Right`, `Dualwield_Melee_Attack_Chop`, `Dualwield_Melee_Attack_Slice`, `Dualwield_Melee_Attack_Stab`, `Hit_A`, `Hit_B`, `Idle`, `Interact`, `Jump_Full_Long`, `Jump_Full_Short`, `Jump_Idle`, `Jump_Land`, `Jump_Start`, `Lie_Down`, `Lie_Idle`, `Lie_Pose`, `Lie_StandUp`, `PickUp`, `Running_A`, `Running_B`, `Running_Strafe_Left`, `Running_Strafe_Right`, `Sit_Chair_Down`, `Sit_Chair_Idle`, `Sit_Chair_Pose`, `Sit_Chair_StandUp`, `Sit_Floor_Down`, `Sit_Floor_Idle`, `Sit_Floor_Pose`, `Sit_Floor_StandUp`, `Spellcast_Long`, `Spellcast_Raise`, `Spellcast_Shoot`, `Spellcasting`, `T-Pose`, `Throw`, `Unarmed_Idle`, `Unarmed_Melee_Attack_Kick`, `Unarmed_Melee_Attack_Punch_A`, `Unarmed_Melee_Attack_Punch_B`, `Unarmed_Pose`, `Use_Item`, `Walking_A`, `Walking_B`, `Walking_Backwards`, `Walking_C`

### `assets/kaykit/characters/Rogue_Hooded.glb` (76)

Origen: KayKit: pack nativo (personajes chibi).

`1H_Melee_Attack_Chop`, `1H_Melee_Attack_Slice_Diagonal`, `1H_Melee_Attack_Slice_Horizontal`, `1H_Melee_Attack_Stab`, `1H_Ranged_Aiming`, `1H_Ranged_Reload`, `1H_Ranged_Shoot`, `1H_Ranged_Shooting`, `2H_Melee_Attack_Chop`, `2H_Melee_Attack_Slice`, `2H_Melee_Attack_Spin`, `2H_Melee_Attack_Spinning`, `2H_Melee_Attack_Stab`, `2H_Melee_Idle`, `2H_Ranged_Aiming`, `2H_Ranged_Reload`, `2H_Ranged_Shoot`, `2H_Ranged_Shooting`, `Block`, `Block_Attack`, `Block_Hit`, `Blocking`, `Cheer`, `Death_A`, `Death_A_Pose`, `Death_B`, `Death_B_Pose`, `Dodge_Backward`, `Dodge_Forward`, `Dodge_Left`, `Dodge_Right`, `Dualwield_Melee_Attack_Chop`, `Dualwield_Melee_Attack_Slice`, `Dualwield_Melee_Attack_Stab`, `Hit_A`, `Hit_B`, `Idle`, `Interact`, `Jump_Full_Long`, `Jump_Full_Short`, `Jump_Idle`, `Jump_Land`, `Jump_Start`, `Lie_Down`, `Lie_Idle`, `Lie_Pose`, `Lie_StandUp`, `PickUp`, `Running_A`, `Running_B`, `Running_Strafe_Left`, `Running_Strafe_Right`, `Sit_Chair_Down`, `Sit_Chair_Idle`, `Sit_Chair_Pose`, `Sit_Chair_StandUp`, `Sit_Floor_Down`, `Sit_Floor_Idle`, `Sit_Floor_Pose`, `Sit_Floor_StandUp`, `Spellcast_Long`, `Spellcast_Raise`, `Spellcast_Shoot`, `Spellcasting`, `T-Pose`, `Throw`, `Unarmed_Idle`, `Unarmed_Melee_Attack_Kick`, `Unarmed_Melee_Attack_Punch_A`, `Unarmed_Melee_Attack_Punch_B`, `Unarmed_Pose`, `Use_Item`, `Walking_A`, `Walking_B`, `Walking_Backwards`, `Walking_C`

### `assets/koloss/KolossMoves.glb` (28)

Origen: Mixamo: nativas (packs Great Sword y Mutant).

`coin_shield`, `dodge_left`, `dodge_right`, `gs_block`, `gs_block_hit`, `gs_combo`, `gs_hit`, `gs_idle`, `gs_kick`, `gs_run`, `gs_slash_down`, `gs_slash_low`, `gs_slash_power`, `gs_walk`, `hit_back`, `hit_front`, `hit_left`, `hit_right`, `mt_die`, `mt_flex`, `mt_idle`, `mt_jump_attack`, `mt_punch`, `mt_roar`, `mt_run`, `mt_swipe_l`, `mt_swipe_r`, `mt_walk`

### `assets/meshy/Breeze.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/Cett.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/Clubs.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/Dockson.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/Elend.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/GordoNoble.glb` (14)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Chest_Pound_Taunt`, `Fall3`, `falling_down`, `Frustrated_Turn_Right`, `Limping_Walk_2`, `Running`, `Scheming_Hand_Rub`, `Sneaky_Walk_inplace`, `Walk_Turn_Left`, `Walk_Turn_Right_Idle_Style`, `Walk_Turn_Right`, `Walk_with_Umbrella`, `walking_2_inplace`, `Walking`

### `assets/meshy/Ham.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/Jastes.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/Kelsier.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/KolossAdulto.glb` (17)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Basic_Jump`, `Charged_Slash`, `Charged_Upward_Slash`, `Chest_Pound_Taunt`, `Double_Combo_Attack`, `Fall_Dead_from_Abdominal_Injury`, `Heavy_Hammer_Swing`, `run_fast_3_inplace`, `Run_Turn_Left`, `Run_Turn_Right`, `Running`, `Thrust_Slash`, `Triple_Combo_Attack`, `Walk_Turn_Left`, `Walk_Turn_Right`, `walking_2`, `Walking`

### `assets/meshy/KolossJoven.glb` (14)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Attack`, `Axe_Stance`, `Basic_Jump`, `Charged_Axe_Chop`, `Charged_Ground_Slam`, `Charged_Spell_Cast`, `Dead`, `dying_backwards`, `Heavy_Hammer_Swing`, `Left_Slash`, `RunFast`, `Running`, `slide_right`, `Walking`

### `assets/meshy/LordRuler.glb` (17)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Axe_Spin_Attack`, `Combat_Idle_Turn_Left`, `Combat_Stance`, `Double_Combo_Attack`, `falling_down`, `Kneel_on_One_Knee_and_Stand`, `Left_Slash`, `Limping_Walk`, `Punch_Combo`, `Running`, `Stage_Walk`, `Triple_Combo_Attack`, `walking_2_inplace`, `walking_2`, `Walking`, `Weapon_Combo_1`, `Weapon_Combo`

### `assets/meshy/Mataneblino.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/MistbornHood.glb` (43)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Attack`, `Axe_Spin_Attack`, `Basic_Jump`, `Block5`, `Combat_Stance`, `Double_Combo_Attack`, `Fall_Dead_from_Abdominal_Injury`, `Heavy_Hammer_Swing`, `Left_Slash`, `Punch_Combo`, `Punch_Forward_with_Both_Fists`, `Running`, `Triple_Combo_Attack`, `Walking`, `Weapon_Combo_1`, `Weapon_Combo_2`, `Weapon_Combo`, `Jump_Down_from_Wall`, `Jump_with_Arms_Open`, `Regular_Jump`, `Run_Turn_Left`, `Run_Turn_Right`, `RunFast`, `slide_light`, `sliding_rool`, `Swim_Forward`, `Swim_Idle`, `Unsteady_Walk`, `walking_2_inplace`, `Charged_Spell_Cast_1`, `Charged_Spell_Cast`, `Dead`, `Double_Blade_Spin`, `dying_backwards`, `mage_soell_cast_2`, `mage_soell_cast_3`, `mage_soell_cast_4`, `mage_soell_cast_6`, `mage_soell_cast`, `Roll_Dodge_1`, `Roll_Dodge`, `Stand_Dodge`, `Sword_Judgment`

### `assets/meshy/Mistborn_Meshy.glb` (8)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`, `_01a18562_67e8_748a_9741_dff7610aaf4f`, `BeHit_FlyUp`, `RunFast`, `Run_03`, `Triple_Combo_Attack`, `Unsteady_Walk`

### `assets/meshy/NinaSkaa.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/NinoSkaa.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/Obligador.glb` (16)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Axe_Spin_Attack`, `Charged_Ground_Slam`, `Charged_Spell_Cast_1`, `Charged_Spell_Cast`, `Dead`, `Knock_Down_1`, `Left_Slash`, `mage_soell_cast_1`, `mage_soell_cast_2`, `mage_soell_cast_6`, `mage_soell_cast_7`, `mage_soell_cast`, `Run_02`, `Running`, `Unsteady_Walk`, `Walking`

### `assets/meshy/Soldado.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/Straff.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/Terrisano.glb` (17)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Attack`, `Combat_Stance`, `Double_Combo_Attack`, `Fall_Dead_from_Abdominal_Injury`, `Fall_Down`, `falling_down`, `Kneel_on_One_Knee_and_Stand`, `Left_Slash`, `Run_Sharp_Turn_Right`, `Run_Turn_Left`, `Running`, `Triple_Combo_Attack`, `Walk_Turn_Left`, `Walk_Turn_Right_Idle_Style`, `Walk_Turn_Right`, `Walking`, `Weapon_Combo`

### `assets/meshy/Tindwyl.glb` (2)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Running`, `Walking`

### `assets/meshy/Vin.glb` (190)

Origen: Meshy: biblioteca de animaciones de Meshy, nativas (rig de Mixamo).

`Alert_Quick_Turn_Right`, `Alert`, `Axe_Breathe_and_Look_Around`, `Bar_Hang_Idle`, `Catching_Breath`, `CrouchLookAroundBow`, `Female_Crouch_Pick_Throw_Forward`, `Grab_Bar_and_Swing_Forward`, `Grab_Wall_Midair_Idle`, `Grip_and_Throw_Down`, `Heavy_Hammer_Swing`, `Lower_Weapon_Look_Raise`, `Punch_Forward_with_Both_Fists`, `Push_Forward_and_Stop`, `Running`, `Step_Forward_and_Push`, `Walking`, `Block10`, `Block1`, `Block2`, `Block3`, `Block4`, `Block5`, `Block6`, `Block8`, `Block9`, `Cautious_Crouch_Walk_Forward_inplace`, `Cautious_Crouch_Walk_Left_inplace`, `Cautious_Crouch_Walk_Right_inplace`, `Unsteady_Walk`, `Walk_Fight_Forward`, `Walk_Turn_Left`, `Walk_Turn_Right`, `walking_2_inplace`, `Combat_Idle_Turn_Left`, `Combat_Stance`, `Fall3`, `Fall_Dead_from_Abdominal_Injury`, `Fall_from_Bar`, `Hang_and_Climb_Left`, `Hang_and_Climb_Rght`, `Hang_and_Push_with_Foot`, `Quick_Walk`, `Sneaky_Walk`, `Spear_Walk`, `Standard_Forward_Charge`, `Walk_to_Sit`, `Weapon_Combo_1`, `Weapon_Combo`, `Charged_Slash`, `Charged_Upward_Slash`, `Kick_a_Soccer_Ball`, `Knock_Down`, `Punch_Combo_2`, `Punch_Combo`, `Reaping_Swing`, `Right_Hand_Sword_Slash`, `Run_and_Jump`, `Run_Turn_Left`, `Run_Turn_Right`, `Thrust_Slash`, `Weapon_Combo_2`, `Discuss_While_Moving`, `Jumping_Head_Scissor_Takedown`, `Knock_Down_1`, `push_up_to_idle`, `Roll_Dodge`, `Shield_Push_Left`, `slide_right`, `Stand_Dodge_1`, `Stand_Dodge_2`, `Stand_Dodge_3`, `Stand_Dodge`, `Sword_and_Shield_Alert_Turn_Left`, `Sword_Parry_Backward_5`, `Walking_Scan_with_Sudden_Look_Back`, `Wall_Push_Jump_and_Flip`, `Angry_Ground_Stomp`, `Charged_Axe_Chop`, `Charged_Ground_Slam`, `Charged_Spell_Cast_1`, `Charged_Spell_Cast`, `Double_Blade_Spin`, `Gesture_with_Hand_on_Gun`, `Idle_02`, `Idle_11`, `Motivational_Cheer`, `Rightward_Spin`, `Skill_01`, `Skill_02`, `Skill_03`, `Sword_Shout`, `Arise`, `Idle_12`, `Idle_13`, `Idle_14`, `Idle_3`, `Idle_6`, `Lean_Forward_Sprint`, `Over_Shoulder_Throw`, `Stand_Up1`, `Stand_Up2`, `Stand_Up3`, `Stand_Up4`, `Stand_Up6`, `Stand_Up7`, `Sword_Judgment`, `Carry_Heavy_Object_Walk`, `Dead`, `dying_backwards`, `mage_soell_cast_1`, `mage_soell_cast_2`, `mage_soell_cast_3`, `mage_soell_cast_4`, `mage_soell_cast_5`, `mage_soell_cast_6`, `mage_soell_cast_7`, `mage_soell_cast_8`, `mage_soell_cast`, `slide_light`, `Swim_Forward`, `Swim_Idle`, `Angry_Ground_Stomp_2`, `Double_kick_forward`, `Fall1`, `Fall2`, `Flying_Fist_Kick`, `Parkour_Vault_1`, `Parkour_Vault_2`, `Quick_Step_and_Spin_Dodge`, `Rising_Flying_Kick`, `Stand_and_Drink`, `Step_in_High_Kick`, `swimming_to_edge`, `Sword_Parry_Backward`, `Sword_Parry`, `Two_Handed_Parry`, `Axe_Stance`, `Collect_Object`, `Face_Punch_Reaction_1`, `Face_Punch_Reaction_2`, `Female_Throwing_Stance_Charge_inplace`, `Female_Throwing_Stance_Charge`, `Hit_Reaction_to_Waist`, `Hit_Reaction`, `Jumping_Down`, `Long_Breathe_and_Look_Around`, `open_door_3`, `Punch_Pose`, `Roll_Behind_Cover`, `Slap_Reaction`, `Step_Back`, `Chair_Sit_Idle_F`, `Dive_Down_and_Land_1`, `Dive_Down_and_Land_2`, `Dive_Down_and_Land`, `Forward_Roll_and_Fire`, `Jump_and_Grab_Wall`, `Jump_and_Slam_Back_Down`, `Regular_Jump`, `Run_to_Walk_Transition`, `Sit_to_Stand_Transition_F`, `Sit_to_standTransition_Female_2`, `Sprint_and_Sudden_Stop`, `Stand_to_Sit_Transition_M`, `Step_to_Sit_Transition`, `Thomas_Flair_to_Jump_Up`, `Groan_Holding_Stomach_in_Sleep`, `Ground_Flip_and_Sweep_Up`, `Handstand_Flip`, `Pull_Radish`, `Sit_to_Stand_Transition_M`, `Stand_Cheer_and_Sit_Down`, `Stand_To_Side_Lying`, `Victory_Cheer`, `victory`, `Wall_Flip`, `Crouch_Walk_Right_with_Torch_inplace`, `Crouch_Walk_Right_with_Torch`, `diagonal_wall_run`, `Jump_Down_from_Wall`, `Parkour_Vault_3`, `Push_and_Walk_Forward`, `Rope_Hang_Backflip_to_Crouch`, `Sit_Cross_Legged_on_Floor`, `Unicycle_Jump_Dismount`, `Idle_8`, `Jump_with_Arms_Open`, `Wall_Support_Jump_to_Ground`, `Leap_of_Faith`

### `assets/meshy/VinCorregida.glb` (8)

Origen: Meshy: Vin re-rigueada (VIN RERIGGED 1 y 2); Vuelo_A, Vuelo_B y Vuelo_Moneda son clips de Meshy que venían sin nombre, solo renombrados.

`Vuelo_A`, `Vuelo_B`, `Vuelo_Moneda`, `Alert`, `Axe_Breathe_and_Look_Around`, `Running`, `Walking`, `Catching_Breath`

### `assets/mixamo/HeroMixamo.glb` (2)

Origen: Mixamo: nativas (Crouch Idle y Wide Arm Spell Casting, para los héroes).

`burst_open_mx`, `crouch_idle_mx`

### `assets/mixamo/HeroMixamoXBot.glb` (21)

Origen: Mixamo: nativas, bajadas sobre el X Bot (Frisbee Throw: la Ráfaga de monedas).

`frisbee_throw_mx`, `fight_idle_mx`, `bounce_fight_idle_mx`, `knife_idle_mx`, `angry_point_mx`, `pointing_forward_mx`, `thinking_mx`, `focus_mx`, `shaking_it_off_mx`, `look_around_body_mx`, `looking_around_mx`, `nervous_look_mx`, `rope_pull_mx`, `pull_heavy_start_mx`, `reaching_out_mx`, `magic_pull_clap_mx`, `magic_pull_blast_mx`, `roar_mx`, `standing_yell_mx`, `taunt_flex_mx`, `yelling_out_mx`

### `assets/mixamo/Mistborn.glb` (49)

Origen: ActionForge (rig Quaternius) + Mixamo, del modelo viejo del Mistborn.

`idle`, `chest_open`, `death01`, `fixing_kneeling`, `hit_chest`, `hit_head`, `hit_knockback`, `jump_land`, `jump`, `jump_start`, `laytoidle`, `pickup_table`, `roll`, `slide_exit`, `slide`, `slide_start`, `spell_simple_enter`, `spell_simple_exit`, `spell_simple_idle`, `swim_fwd`, `swim_idle`, `sword_attack`, `sword_dash`, `sword_idle`, `sword_regular_a`, `sword_regular_b`, `sword_regular_c`, `walk`, `sprint`, `sad_walk`, `carry_walk`, `crouch_walk`, `crouch_idle`, `sad_idle`, `dodge_left`, `dodge_right`, `hit_front`, `hit_back`, `hit_left`, `hit_right`, `dig`, `push_heavy`, `pull_heavy`, `iron_pull`, `lift_heavy`, `kneel_pull`, `kneel_inspect`, `box_idle`, `warm_hands`

### `assets/mixamo/MixamoCombat.glb` (12)

Origen: Mixamo: nativas.

`coin_shield`, `fist_jab`, `fist_cross`, `fist_uppercut`, `fist_hook`, `fist_roundhouse`, `dagger_lead`, `dagger_rear`, `dagger_double`, `shield_cross`, `shield_down`, `shield_kick`

### `assets/mixamo/MixamoSpells.glb` (37)

Origen: Mixamo: nativas.

`coin_shield`, `block`, `box_idle`, `burn_focus`, `carry_walk`, `climb_wall`, `coin_flick`, `coin_wave`, `crouch_idle`, `crouch_walk`, `dig`, `dodge_left`, `dodge_right`, `drink`, `fall_roll`, `freefall`, `get_up`, `hit_back`, `hit_front`, `hit_left`, `hit_right`, `iron_pull`, `kneel_inspect`, `kneel_pull`, `lift_heavy`, `open_door`, `pewter_flex`, `pick_up`, `pull_heavy`, `push_heavy`, `put_down`, `sad_idle`, `sad_walk`, `sit`, `steel_push`, `vault`, `warm_hands`

### `assets/mixamo/Ninja.glb` (2)

Origen: Mixamo: nativas.

`Climbing`, `Jumping_Down`

### `assets/quaternius/characters/Cleric.glb` (15)

Origen: Quaternius: pack nativo.

`Attack_Idle`, `Death`, `Idle`, `Idle_Weapon`, `PickUp`, `Punch`, `RecieveHit`, `RecieveHit_Attacking`, `Roll`, `Run`, `Run_Weapon`, `Spell1`, `Spell2`, `Staff_Attack`, `Walk`

### `assets/quaternius/characters/Monk.glb` (11)

Origen: Quaternius: pack nativo.

`Attack`, `Attack2`, `Death`, `Idle`, `Idle_Attacking`, `PickUp`, `RecieveHit`, `RecieveHit_Attacking`, `Roll`, `Run`, `Walk`

### `assets/quaternius/characters/Ranger.glb` (14)

Origen: Quaternius: pack nativo.

`Bow_Attack_Draw`, `Bow_Attack_Shoot`, `Death`, `Idle`, `Idle_Attacking`, `Idle_Weapon`, `PickUp`, `Punch`, `RecieveHit`, `RecieveHit_Attacking`, `Roll`, `Run`, `Run_Holding`, `Walk`

### `assets/quaternius/characters/Rogue.glb` (12)

Origen: Quaternius: pack nativo.

`Attacking_Idle`, `Dagger_Attack`, `Dagger_Attack2`, `Death`, `Idle`, `PickUp`, `Punch`, `RecieveHit`, `RecieveHit_Attacking`, `Roll`, `Run`, `Walk`

### `assets/quaternius/characters/Warrior.glb` (14)

Origen: Quaternius: pack nativo.

`Death`, `Idle`, `Idle_Attacking`, `Idle_Weapon`, `PickUp`, `Punch`, `RecieveHit`, `RecieveHit_Attacking`, `Roll`, `Run`, `Run_Weapon`, `Sword_Attack`, `Sword_AttackFast`, `Walk`

### `assets/quaternius/characters/Wizard.glb` (15)

Origen: Quaternius: pack nativo.

`Death`, `Idle`, `Idle_Attacking`, `Idle_Weapon`, `PickUp`, `Punch`, `RecieveHit`, `RecieveHit_Attacking`, `Roll`, `Run`, `Run_Weapon`, `Spell1`, `Spell2`, `Staff_Attack`, `Walk`

### `assets/skaa/Skaa.glb` (48)

Origen: ActionForge + Mixamo, con el esqueleto del Mistborn viejo (rig_like_mistborn.py).

`box_idle`, `carry_walk`, `chest_open`, `crouch_walk`, `death01`, `dig`, `dodge_left`, `dodge_right`, `fixing_kneeling`, `hit_back`, `hit_chest`, `hit_front`, `hit_head`, `hit_knockback`, `hit_left`, `hit_right`, `idle`, `iron_pull`, `jump`, `jump_land`, `jump_start`, `kneel_inspect`, `kneel_pull`, `laytoidle`, `lift_heavy`, `pickup_table`, `pull_heavy`, `push_heavy`, `roll`, `sad_idle`, `sad_walk`, `slide`, `slide_exit`, `slide_start`, `spell_simple_enter`, `spell_simple_exit`, `spell_simple_idle`, `sprint`, `swim_fwd`, `swim_idle`, `sword_attack`, `sword_dash`, `sword_idle`, `sword_regular_a`, `sword_regular_b`, `sword_regular_c`, `walk`, `warm_hands`

### `assets/skaa/SkaaObrero.glb` (49)

Origen: ActionForge + Mixamo, con el esqueleto del Mistborn viejo (rig_like_mistborn.py).

`box_idle`, `carry_walk`, `chest_open`, `crouch_idle`, `crouch_walk`, `death01`, `dig`, `dodge_left`, `dodge_right`, `fixing_kneeling`, `hit_back`, `hit_chest`, `hit_front`, `hit_head`, `hit_knockback`, `hit_left`, `hit_right`, `idle`, `iron_pull`, `jump`, `jump_land`, `jump_start`, `kneel_inspect`, `kneel_pull`, `laytoidle`, `lift_heavy`, `pickup_table`, `pull_heavy`, `push_heavy`, `roll`, `sad_idle`, `sad_walk`, `slide`, `slide_exit`, `slide_start`, `spell_simple_enter`, `spell_simple_exit`, `spell_simple_idle`, `sprint`, `swim_fwd`, `swim_idle`, `sword_attack`, `sword_dash`, `sword_idle`, `sword_regular_a`, `sword_regular_b`, `sword_regular_c`, `walk`, `warm_hands`

### `assets/skaa/SkaaPilgrim.glb` (8)

Origen: ActionForge + Mixamo, con el esqueleto del Mistborn viejo (rig_like_mistborn.py).

`Alert`, `Arise`, `Attack`, `Run_03`, `RunFast`, `Running`, `Walking`, `Walking_Woman`

## Fuentes fuera del repo

- `Escritorio/Mistborn/MESHY 3D/*.zip`: los FBX de Meshy de cada personaje (VIN 1 a 15 = `Vin.glb`;
  VIN RERIGGED 1 y 2 = `VinCorregida.glb`). Todo lo que traen ya está en el juego.
- `Escritorio/Mistborn/ActionForge/*.fbx`: lo que va en `AFClips.glb` (se arma con `tools/blender/anim_fbx_to_glb.py`).
- `Descargas/*.fbx`: clips de Mixamo bajados (golpes, espada y escudo, agachado...). Solo `Crouch Idle` está en uso.
