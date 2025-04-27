Reforging NPC that applies 2 random enchantments to any equipped item.

How to install:

Step 1. Run Reforger.sql on your creature_template table to make the proper npc

Step 2. Run Item_Enchant_tables.sql on your world database to give the proper random enchantment tables for the script to run off of.

Step 3. Put the Reforger.lua in your scripts folder.

How it works:

The script pulls from the tables included at the chance included and applies 2 enchantments to any equipped item. Every item in WoW has 2 enchantment slots. Weapon poisons, shaman enchants, etc take up slot 2. Slot 1 is taken up by regular enchants you would use from items or the profession.

Example:

+14 Agility
+8 Stamina

Shaman enchants would override +8 Stamina

Normal enchants change slot 1 of any item. So adding +10 all stats would replace the +14 agility

-Side notes-
You may adjust the cost of item quality in the script itself. You can also edit the npc id it hooks into.

In game you may spawn the npc and start reforging your equipped items right away. It works by deleting the item, re-adding it to the player and re-equipping it. It struggles to reforge items with affixes (Of the Monkey).
You may use this for your server but I ask for credit if at all possible.

I will not assist you if you edit the script and break something. Any questions please post on my release page in the WoW Modding Community Discord. 
