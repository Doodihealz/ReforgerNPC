Reforging NPC that applies 2 random enchantments to any equipped item.

How to install:

Step 1. Run Reforger.sql on your creature_template table to make the proper npc

Step 2. Run Item_Enchant_tables.sql on your world database to give the proper random enchantment tables for the script to run off of.

Step 3. Put the Reforger.lua in your scripts folder.

Enjoy!

How it works:

The script pulls from the tables included and the chance included and applies 2 enchantments to any equipped item. It deletes the item from the player, re-adds it with the enchants and re-equips it. Because of this any gems you have in the item will be lost upon reforging. Every item in WoW has 2 enchantment slots. Weapon poisons, shaman enchants, etc take up slot 2. Slot 1 is taken up by regular enchants you would use from items or the enchanting profession.

Example:

Slot 1: +14 Agility

Slot 2: +8 Stamina

Shaman's Flametongue Weapon spell would override +8 Stamina

Normal enchants change slot 1 of any item. So adding +10 all stats would replace the +14 agility

-Side notes-
You may adjust the cost of item quality in the script itself. You can also edit the npc id it hooks into.
Because it deletes the items and re-adds them, items with rolls like (Of the Monkey) may be returned with (Of the Whale) or something else.
Some enchants will apply to items but not work. For example, Windfury rolling on a helmet does nothing. Oddly enough if you roll Windfury on a shield it does work.

You may use this for your server but I ask for credit if at all possible.
I will not assist you if you edit the script and break something. Any questions please post on my release page in the WoW Modding Community Discord. https://discord.com/channels/407664041016688662/1366126332702097529
