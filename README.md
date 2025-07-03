## Reforger NPC (Eluna / AzerothCore)

A reforging NPC that applies **two random enchantments** to an equipped item. It uses a custom tier-based enchantment system to determine what's eligible at various player levels, and supports both armor and weapon enchantments — including support for Shaman imbues, poisons, and rare effects like Windfury or Mongoose.

### 💾 Installation

1. Run `Reforger.sql` on your world database to create the reforging NPC.
2. Run `item_enchantment_random_tiers.sql` to install the tiered enchantment definitions.
3. Place `Reforger.lua` inside your server's `lua_scripts/` directory.

### 🔧 How It Works

When interacting with the NPC, the script lets the player select an eligible equipped item. That item is deleted, re-created with 2 random enchantments, and then re-equipped. Because of this, **socketed gems will be lost**, suffixes like “of the Bear” may change, and temporary effects like poisons or imbues may be overridden.

Each item has two enchant slots:
- **Slot 1** is for normal enchants (+10 Stats, Crusader, etc.)
- **Slot 2** is for temp effects (Windfury, poisons, etc.)

Example:  
`Slot 1: +14 Agility`  
`Slot 2: +8 Stamina`  
Casting Flametongue would override +8 Stamina.  
Adding +10 Stats would override +14 Agility.

### 📊 Enchantment Tier System

The `item_enchantment_random_tiers` table defines the tiers. The script uses your character level to determine the **highest eligible tier**:
- Tier 1 = Level 1+
- Tier 2 = Level 30+
- Tier 3 = Level 60+
- Tier 4 = Level 70+
- Tier 5 = Level 80+

Items are only eligible for enchantments of their class (WEAPON, ARMOR, or ANY). Weapon enchantments (like Windfury or Mongoose) are slightly favored when reforging weapons (10% increased chance), but they **can** still be missed for variety.

All enchantments are pulled from your SQL data. Weapon enchants like Windfury 2 are tagged as WEAPON and tier 3 — meaning they only become available at level 60+ and only apply to weapons.

**Duplicate enchantments will never be applied** (e.g., you will not get Windfury 3 twice on the same item). Two similar but distinct enchants (like +43 Spell Power and +44 Spell Power) are allowed on the same item.

### ⚠️ Additional Notes

- **Ranged Attack Power** enchants are only applied if the player is a **Hunter** (class ID 4).
- Items with suffix stats (e.g., “of the Monkey”) will reroll randomly after reforging.

### 🛠 Customization

- Edit gold cost per item quality inside `Reforger.lua` (`QUALITY_COST` table).
- Adjust NPC ID or excluded item list freely.

### 🧾 Credit

- You are free to use and modify this for your server. If you do release a variant of this mod you must provide it for free. I ask you to kindly credit me if you do (Doodihealz / Corey) 
- I will only support unmodified versions. For questions, visit the WoW Modding Community Discord release thread: https://discord.com/channels/407664041016688662/1366126332702097529
