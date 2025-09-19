## Reforger NPC (Eluna / AzerothCore)
A reforging NPC that applies **two random enchantments** to an equipped item. It uses a custom tier-based enchantment system to determine what's eligible at various player levels, and supports both armor and weapon enchantments — including support for Shaman imbues, poisons, and rare effects like Windfury or Mongoose.

There is now also a manual mode which you can easily toggle on or off in the npc gossip selection. It always applies the 2 highest rolls of a single stat onto an item.

There's an optional Random enchantment section of the script available. You'll need the sql table for the random enchants to work just like the reforger, but this allows random tier enchants to apply to Looted items, Crafted items, and Quest Rewards!

**Big thanks to Xepic90 on the Azerothcore Discord for helping solve the suffix issue!**

### 💾 Installation
1. Make an npc in creature_template id 200004 named Reforger with the IconName as Speak. Add npc id 200004 to creature_template_model with display id 21078. You can use any model you desire or any npc id. Just update the script to hook into the new id.
2. Run `item_enchantment_random_tiers.sql` to install the tiered enchantment definitions.  
3. Place `Reforger.lua` inside your server's `lua_scripts/` directory.

### 🔧 How It Works
When interacting with the NPC, the script lets the player select an eligible equipped item. The script applies up to 2 random enchantments directly to the existing item, **preserving all original item properties** including suffixes (like "of the Bear"), socketed gems, and other item characteristics. Enchantment costs scale with player level. Higher level means more costly enchantments.

Each item has multiple enchant slots:
- **Slot 1 and 2** are used for the random enchantments (+10 Stats, Crusader, etc.)
- Temporary effects like Shaman imbues or poisons may still override these enchantments when applied

Example:  
`Slot 1: +14 Agility`  
`Slot 2: +8 Stamina`  

Casting Flametongue or Poisons would override +8 Stamina.  
Adding a permanent enchant like +10 Stats would override +14 Agility.

### 📊 Enchantment Tier System  
The `item_enchantment_random_tiers` table defines the tiers. The script uses your character level to determine the **highest eligible tier**:
- Tier 1 = Level 1+
- Tier 2 = Level 30+  
- Tier 3 = Level 60+
- Tier 4 = Level 70+
- Tier 5 = Level 80+

Items are only eligible for enchantments of their class (WEAPON, ARMOR, or ANY). Weapon enchantments (like Windfury or Mongoose) are available when reforging weapons, and all enchantments are pulled from your SQL data. Weapon enchants like Windfury 2 are tagged as WEAPON and tier 3 — meaning they only become available at level 60+ and only apply to weapons.

**Duplicate enchantments will never be applied** (e.g., you will not get Windfury 3 twice on the same item). Two similar but distinct enchants (like +43 Spell Power and +44 Spell Power) are allowed on the same item.

### ✅ Key Features
- **Suffix Preservation**: Items keep their original suffixes like "of the Bear", "of the Monkey", etc.
- **Gem Preservation**: Socketed gems remain intact during the reforging process
- **Direct Application**: Enchantments are applied directly without item recreation
- **Smart Targeting**: Ranged Attack Power enchants only apply to Hunters (class ID 4)

### 🛠 Customization
- Edit gold cost per item quality inside `Reforger.lua` (`QUALITY_COST` table).
- Adjust NPC ID or excluded item list freely.

### 🧾 Credit
- You are free to use and modify this for your server. If you do release a variant of this script you **must** provide it for free back into the modding scene! I ask you to kindly credit me if you do (Doodihealz / Corey) 
- I will only support unmodified versions. For questions, visit the WoW Modding Community Discord release thread: https://discord.com/channels/407664041016688662/1366126332702097529
