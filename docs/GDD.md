Monster Breeders of Ahymn — Game Design Document

Oct 26, 2026 · @Tim

Monster Breeders of Ahymn is a 2D farming and creature-taming game for PC and mobile: Stardew Valley's farm, clock, and seasons combined with Dragon Warrior Monsters' monster collecting and battles.

## Vision and pillars

The player runs a farm, grows food for their monsters, travels the world map to find and tame creatures, and competes in optional seasonal tournaments that grow the farm. Anything not stated here is listed as an open question at the end, not decided.

| Pillar | What it means |
|--------|---------------|
| Farming is integral | The player grows their own monster food. Feeding a monster the right food boosts its bonding. |
| Time is the resource | Each day runs continuously from morning to night and the player must manage it. |
| Every creature is unique | Each creature has its own way of gaining affection toward the player. |
| Tournaments are optional | A tournament is held each season and the player may skip any of them. |

## Character creation and the opening

The player creates their character by choosing a name, a farm name, male or female (set at creation), and their appearance: body, skin tone, hair style and color, and outfit colors. There is no starter monster.

1. **The letter.** After character creation, the player reads a letter from the Association. Their application to become a monster breeder of Ahymn has been accepted, and once they complete their Assessment they will be granted a small farm on the outskirts of Ahymn.
2. **Arrival.** The screen shifts to the player arriving at the village. They are dropped off at the Association and meet Angie, who runs the Assessment.
3. **The Assessment.** The player chooses a Biome room, and Angie gives them 5 traps. Creatures move around the room at random. The player places a trap near the monster they want and sees whether it takes the bait. Each monster's rank is shown. The ranks that appear in the Biome rooms are D 79% of the time, C 20%, and B 1%, so a Rank B first monster is possible but very rare. Once the player has captured a monster, they can end the Assessment and keep it, or use all 5 traps and choose one of the five.
4. **Making it official.** Once the player has chosen their first monster, the Assessment ends. Angie makes it official and walks the player to their farm.
5. **The farm.** It has a small house, a small pasture for the new monster, and a small barn. The land around it is overrun and needs a lot of work to clear, the same as Stardew Valley. The first monster the player captured decides the farm's starting biome. Eventually the farm gets a small section of every biome, which the player unlocks wherever they choose to place it.
6. **Angie's walkthrough.** Angie shows the player how to bond with their monster and set it in the barn. She gives them 20 special food items that always count as a favorite, whatever the monster, and 45 seeds of their monster's favorite crop. Then she leaves the player to it, which ends the first day.
7. **Day 2: Tom.** When the player walks out of their house, Tom shows up and talks about traps. He gives them 5 basic traps and a basic trap-crafting recipe, then offers to take them to one of the starter biomes. He teleports them to the one they choose, where they arrive at its portal stone. He explains the portal and the player unlocks their first one. The player then ports back to the farm and Tom heads off.
8. **Looking around.** After this the player can look around the farm and see how much work it needs.

The four starter biomes are Meadowlands, Woodland, Marsh, and Lake and Coast. They are the Biome rooms offered in the Assessment and the places Tom can teleport the player to on day 2.

## Farm habitats and pasture

- **Habitats.** Each biome can have a small section on the farm, called a habitat. Wild-caught monsters from that biome show up in its habitat. A habitat holds up to 12 monsters at a time.
- **Unlocking a habitat.** The player collects ingredients from that biome and uses them, with help from Rowan the Habitat Builder, to build it.
- **Pasture.** A wild-caught monster whose biome has no habitat on the farm goes to the pasture, which has a maximum of 6 spots.
- **Barn.** Once a monster is bonded, it moves into the barn. Monsters in the barn can be taken with the player out into the world, up to two at a time. The barn starts with 20 stalls and can be upgraded four times, for a maximum of 100 monsters.

## Core loop and daily time

Time follows the Stardew Valley model. A day progresses continuously from morning to night. At midnight the character becomes tired, and at 2:00 AM they pass out and wake up in their bed. Passing out costs a percentage of the money the player is carrying, plus a fixed drop in bonding for the monsters they have with them, so a late night out hunting is riskier than a late night at the farm.

1. **Farm.** Grow the food your current monsters need.
2. **Hunt and tame.** Travel the world map, find creatures, and win their affection by the method each one requires.
3. **Settle in.** Bring creatures home to their habitat or the pasture, and keep them fed and cared for so they bond and can move to the barn.
4. **Compete (optional).** Enter the seasonal tournament to win the chance to raise farm rank and size and build new habitats.
5. **Sleep.** End the day in bed, or pass out at 2:00 AM, and begin the next one.

Every activity spends the same clock, so the player is always trading farm work against travel, taming, and preparation for the tournament.

## Bonding and breeding

**Bonding.** Each monster has a Bond bar from 0% to 100% that fills as the player interacts with it. At 25% a monster is bonded enough to be sent to the barn. At 100% it gains a star in its bond spot, which means it can be used for breeding.

**Breeding.** The player can breed two of their own monsters of opposite genders at the Nursery on the farm. Both monsters need a star, which they earn at 100% bond. The Arena and befriended villagers can also offer breeding opportunities. For now, breeding always succeeds: once two monsters are bred, they always produce offspring.

- **Result.** If breeding succeeds, then depending on the creature it produces an Egg or the monster becomes pregnant.
- **Climate.** The player must manage the climate for the egg or the pregnant creature. After a period of time the egg hatches or the monster gives birth.
- **The infant.** Its gender is random, and it gets appropriate traits from its parents.
- **Mixed types.** Breeding two different monster types may result in a new type of monster. The first parent is the Pedigree and determines the race of the offspring, so a dragon Pedigree most likely produces a dragon. The second parent is the modifier. Plant and Elemental are not parents. They are breeding modifiers. This allows many different chances at new and rare combinations. Dragon Warrior Monsters' breeding program is the reference model.
- **Recipes.** Specific monsters, especially rare ones, are produced by specific recipes. Recipes must be found, discovered through a Tavern post, or given to the player by a villager once they reach a specific friendship level.
- **Quality.** Offspring quality depends on how good the parents' stats are and how well the player raised and cared for them.
- **Stats and rank.** Offspring stats follow the rules under Stat inheritance. Each parent has a rank determined by an appraiser, from top to bottom: S, A, B, C, D. Rank and species rarity are separate. A hard-to-find species can still be D rank and a common species can be S rank, though in the wild the higher ranks are far less common. Each stat has its own range (for example 1 to 20 or 1 to 25) and is given its own letter: 18 to 20 is S and 1 to 5 is D. The monster's overall rank is the average of its stat letters, rounded down. Three D stats and two C stats is a D, two D stats with a C and two B stats is a C, and one S stat with four B stats is a B. A higher rank means better stat growth, so an offspring that comes out with a higher rank than its parents is the reward for caring for them well. Once appraisal is unlocked, the player sees a wild monster's overall letter on inspection, but the individual stat letters only show after the monster is tamed, brought home, and evaluated. Evaluating a monster in town costs about 50 to 100 Coins. Once the player learns the appraisal skill, they can evaluate monsters at home for free.
- **Skills.** Some skills may pass on at birth, but most are gained over time.
- **Egg evaluation.** Early on, a place in town can evaluate eggs.
- **Recovery.** Infants and birthing parents each have a recovery timer after the birth or hatching.
- **Bonding.** Bred monsters start out bonded, but can become wild if the player does not care for them appropriately.

Climate types and how they are managed, timings, the quality formula, the recipes themselves, which creatures lay eggs versus become pregnant, and what happens when a monster goes wild are not decided yet.

## Monster families

Families are named after real-world animal classes. That makes them easy to read at a glance and opens up more fun breeding combinations. The Pedigree parent's family decides the family of the offspring. There are seven animal families. Plant and Elemental are not families, they are breeding modifiers:

- Bird
- Reptile
- Insect
- Arachnid. Spiders and other arachnids are not insects, so they get their own family.
- Aquatic. Water-dwelling creatures. This replaces Fish, since a pure fish is hard to picture battling out of water.
- Beast. Big, powerful animals such as wolves, bears, big cats, and boars.
- Critter. Small, quick animals such as rabbits, rodents, foxes, and weasels.

Dragons are Reptiles. Undead monsters are not planned for the initial game. Which other monsters belong to each family and what each pairing produces are not decided yet.

### Family crossing grid

Each row is the Pedigree parent's family and each column is the Modifier parent's family. Each cell is one of the 49 base monsters, a mixture of its two families. Specific breeding recipes then use these base monsters to produce specific monsters. Each family can hold several species. For example, Bird could have a Robin, a Crow, and an Eagle. Breeding two monsters from different families produces the monster where their families cross on the grid. Breeding two monsters of the same family produces the Pedigree parent's species. A Robin Pedigree bred with an Eagle gives a Robin, but the offspring gets bonuses from the stats of both parents. These are the defaults for pairings that have no special recipe. A specific recipe overrides the default, and new recipes can be added over time to expand the roster. The cells are empty until they are filled in. A blended grid monster counts as the same family as its Pedigree parent when it is bred.

## Breeding modifiers

Plant and Elemental are not monster families and are never a parent. They come primarily from the farming side of the game and are used as breeding modifiers. After the player pairs two monsters, they get the chance to add a breeding modifier, either a Plant or an Elemental such as fire or ice. Each combination works as a recipe.

- **The modifier decides the result.** Any two monsters of the same family bred with the same breeding modifier produce the same new monster, so it does not matter which species the parents were. Two birds plus fire give a flaming bird with its own unique look, whether the parents were two Robins or a Blue Jay and a Cardinal.
- **Not a recolor.** Each result is its own monster with its own look. A Plant might give a leaf bird, fire a phoenix-like bird, and ice a bird made of ice. This adds new monsters without needing over a thousand hand-made combinations.
- **The family stays the same.** The offspring stays in the Pedigree parent's family, whatever modifier was used.
- **It does not pass on.** Breeding a Phoenix with another bird gives a plain bird of the base species, not a Phoenix. The base species is found from the Phoenix's stored parentage. The modifier has to be added again to get another one. If a modifier monster is bred with a monster of a different family and there is no special recipe for the pair, the baby follows the family grid like any other pairing, using the modifier monster's family. For example, a Cinderkin (Critter) bred with a Reptile gives the Critter and Reptile cell. A special recipe always produces its own new monster instead.
- **Stats still come from the parents.** What the parents' stats and skills allow is what can pass to the offspring.

## Stat inheritance

The Pedigree parent supplies the baby's base stats. The second parent adds a bonus to each stat based on that parent's letter in that specific stat, not on its overall rank.

- **Bonus by stat letter.** S gives +5, A gives +4, B gives +2, C gives +1, and D gives +0.
- **A modifier, not a base stat.** The bonus is added on top of the base stat and only shows in the baby's battle stats. The base stat, and so the stat's letter, does not change. For example, a Robin with a base speed of 19 (S) bred with a second parent that has an S in speed gives a baby with a base speed of 19 and a battle speed of 24.
- **Only for that baby.** The bonus is not inherited. Offspring pass on their base stat, never the bonus. Leveling up raises battle stats over time, but only the base stat matters for breeding.
- **Per stat.** Because the bonus follows each stat's own letter, a monster that is overall C but has an S in speed still gives the full +5 to speed.
- **Min-maxing is fine.** The game is single-player, so players who optimize their stats are not hurting anyone, and an S-rank stat is rare enough to take real effort.

## Rank and rarity

Species rarity and stat rank are separate. Some species are hard to find on the map and some are common. Any species can turn up with high stats, so a common species can be S and a hard-to-find one can be D. In the wild, though, higher overall ranks are far less common: D is very common, C uncommon, B rare, A ultra rare, and S is almost never found. An overall S needs the stat letters to average out to S, which is very hard. That is why the reputation-gated A and S areas matter later in the game.

## Parentage

Every monster stores its parentage, a record of who its parents were. It is used to work out the base species when a modifier monster is bred. Only parentage is stored, not a full lineage. A parent and its offspring cannot be bred together, but siblings can.

## Monster ideas so far

- Rockback. An Aquatic frog combined with Earth.
- Cinderkin. A chipmunk (Critter) combined with Fire.
- Jumping spider and praying mantis. An Arachnid crossed with an Insect. Evan's favorite, and a concept image was made.
- Bird and praying mantis. A Bird crossed with an Insect that Evan also liked.
- Leaf bird, Phoenix, and ice bird. Examples of a bird with Plant, fire, and ice modifiers.

## Monster data

Every monster stores the same set of information. Rockback is the example:

- Species: Rockback (a frog)
- Family: Aquatic
- Gender: male or female
- Rank: D to S
- Stats: HP, STR, DEF, INT, SPD
- Bond level: 0% to 100%
- Favorite food: Snouter Roe

Parentage, skills, and the per-stat letters described elsewhere in this document are stored with it.

## Creature taming methods

Each creature is unique and has its own way of gaining affection. The methods so far are:

| Method | How it works |
|--------|--------------|
| Food | The player offers food that they have grown on the farm. |
| Battle | The player fights the creature to earn its affection. |
| Trap | The player catches the creature in a trap and brings it back to the farm. |

Whatever the method, a wild-caught monster lives in its biome's habitat or the pasture until it is bonded enough to go to the barn.

### Trapping system

The player can buy or build traps and use them in the wild to capture passive monsters.

- **Traps.** Each biome has its own set of traps, in three tiers: Basic, Advanced, and Master.
- **Bait.** The player can use crops grown on the farm, or turn crops into bait made for a specific biome. Some biomes have special bait that attracts rarer monsters.
- **Catching.** Once a trap is set and baited, the player can wait nearby. When a creature is caught, the trap closes and starts to shake. If the trap fails, it is knocked over and the bait is gone.
- **After a catch.** If the trap succeeds, the player chooses to keep or release the monster.

## Farming and habitats

Farming is integral. The player grows food matched to the monsters they have, and feeding it to them raises bonding.

- **Food.** Crops are grown to suit the monsters the player owns or wants to tame.
- **Habitats.** Each biome can have a habitat on the farm, built from ingredients collected in that biome.
- **Barn.** Where bonded monsters live.
- **Farm rank and size.** Both grow through the seasonal tournament. A win gives the chance to build a new habitat, provided the player has the resources it needs.
- **Seasons and favorite crops.** Crops are tied to seasons. Each monster has a favorite crop for each season.
- **Kitchen.** The player can cook kibble at home for specific monster groups and types. Each offspring randomly rolls its tastes, so it may like the kibble of its own family or the kibble of a completely different one. This gives each monster its own personality.
- **Favorite food.** Continuously feeding a monster its favorite food raises its friendship and bonding. It never changes the monster's rank or rarity, but it affects the monster's offspring.

Crop types and the resources habitats cost are not decided yet.

## Farming system

Farms use a tile grid, like Stardew Valley.

- **Tools.** The player starts with basic tools: a Pulaski, a sickle, a pickaxe, a watering can, and so on. At their basic level, each one only works on 1 tile at a time.
- **The Pulaski.** It is two tools in one, an axe and a hoe. It clears trees and tills soil.
- **Trees.** A tree has four growth stages: seed, seedling, sapling, and grown. Seeds and seedlings can be dug out of the ground. Saplings and grown trees must be cut down. A sapling takes 3 hits with the Pulaski. A grown tree takes 10 swings to clear completely: 6 for the tree to fall and 4 to clear the stump.
- **Planting.** After the soil is tilled, the player plants seeds in it, and the ground changes depending on which seed was planted. The player waters the seeds each day until they finish growing. Each crop has four growth stages.
- **Harvesting.** The player walks up to a grown crop and clicks it to harvest.

## Energy

The player has two bars, health and stamina, and both start at 100%. Stamina goes down with each use of a tool. At 0, the player is slowed and cannot use tools. Stamina is refilled by eating food, sleeping, or resting in a hot spring.

## Monster care

- **Wild-caught monsters.** They roam freely in the pasture, or in an empty spot in their preferred biome's habitat if one is available.
- **Bond bar.** Every creature has a Bond bar that fills as the player interacts with it. At 25% it is bonded enough to be sent to the barn.
- **Pasture.** Monsters in the pasture do not need to be fed, but feeding them boosts bonding.
- **Barn.** Monsters in the barn need food and water every day. These tasks can be automated eventually. In the barn the player can interact with, feed, and play with the creatures, and add them to their party. Monsters in the party gain passive bonding points.
- **Food.** Each monster has a preferred food type and a favorite food.
- **Breeding star.** At 100% bond a monster gains a star in its Bond spot, which means it can be used for breeding.

## World map and creature hunting

The player travels around the world map hunting creatures and trying to tame them. Each creature is unique, so the approach differs: some need food, some need a battle, and others must be caught in a trap and brought back to the farm.

Travel uses the same daily clock. The player can explore on foot, moving from screen to screen. The farm also has a portal that takes the player instantly to a biome they have unlocked, and the trip itself takes no clock time. A biome is unlocked by exploring it and finding its portal spot, or by buying portal rights. The map's layout and how creatures are placed on it are not decided yet. A map that includes the biomes will be supplied separately.

## The Village

The player has access to a village where they can meet the locals and other trainers.

| Place | What it offers |
|-------|----------------|
| Shop | Seeds and other goods. |
| Tavern | Rumors about rare or trending monsters in specific areas. A new rumor is posted on an in-game message board about once a week, for example that a villager shared news of a rare monster sighting northeast of town and the player should speak to them for more information. Occasionally the player gets a rare report on how to capture a specific monster: its food, habitat, taming method, and so on. Reports on rare monsters can also include a breeding recipe. |
| Arena | A good place to collect information on monsters, and it may offer an occasional breeding opportunity. |
| Job board | Other farms post requests, such as needing a certain food for a number of monsters. Rewards can be Coins, breeding recipes, monster lore, or sighting tips that are only good for a limited number of days. Higher reputation brings better requests, including people who will pay the player to breed monsters for them. |
| Monster Hunter Association | Takes farm-bred monsters the player donates or sells and offers them to new tamers. |

Egg evaluation. Early in the game, the village has a place that can evaluate eggs.

### Villagers

The village has several townsfolk the player can build friendships with, and some can be romanced, though not all of them. Higher friendship can give the player useful items, information, and breeding chances. Some villagers are really into creature breeding and some are not.

The village has 20 named villagers: 9 key roles, 1 elder, 8 romanceable adults (4 men and 4 women), 1 hidden villager, and 1 child. Romance is a minority of the cast and is never offered to key roles. Friendship grows by talking to villagers, giving them gifts, and donating a monster to a villager's younger sibling who is just getting started.

(Full villager table and details are in the original GDD; key roles include Angie, Devon, Sallie, Tom, Lily, Eldin, Megan, Rowan, Valorie, Ol' Man Timah, etc. Romanceables include Evan, Mairin, Callan, Jack, Sarah, Kendra, Zach, Olive.)

**Friendship system.** Friendship is modeled on Stardew Valley's hearts. These numbers are starting values and can be tuned.

- **Hearts.** Each heart is 250 friendship points, and a villager maxes out at 10 hearts (2,500 points).
- **Talking.** Talking to a villager once a day gives about +20 points.
- **Gifts.** The amount depends on how the villager feels about the item: roughly +80 for loved, +45 for liked, +20 for neutral, and negative points for disliked and hated. A birthday gift counts for several times as much. Each villager can be given two gifts a week. Crops and cooked food from the farm are natural gifts.
- **Favorites.** Each villager has their own loved and hated items, which the player learns over time.
- **Monster donation.** Donating a monster to a villager's younger sibling who is just getting started is a one-time, large friendship gift, since it costs the player a monster.
- **Heart events.** Short scenes trigger at set heart levels, and some unlock things like recipes.
- **Dating.** Once a romanceable villager reaches 6 hearts, the player can start the dating process.

**Dating.** Dating is meant to be more rewarding and more in-depth than Stardew Valley's. Reputation matters very little in relationships.

- **Starting.** Once a romanceable villager reaches 6 hearts, the player can start the dating process.
- **Dates.** The player takes the villager on an actual date. Each villager likes different kinds of dates: some enjoy monster battles, some prefer a day at the farm, and some want the player to join them shopping in town.
- **Good dates.** A date that goes well raises that villager's heart points.
- **Bad dates.** A date that goes poorly can make the villager end the relationship. The player then loses hearts and has to wait out a cooldown timer before trying again.

## Battles and tournaments

**Battles.** Each battle is fought with 1 to 2 creatures per side, in the style of Pokémon. Battles are used for taming creatures that require one and for the seasonal tournament.

- **Turn-based.** Battles are turn-based, like Pokémon.
- **Commands.** The player can command their monster directly or let it fight on its own, similar to Dragon Warrior Monsters.
- **Stats.** HP is health, STR is strength, DEF is defense, INT is intelligence, and SPD is speed. Stats play a vital role in combat. INT decides which skills a monster uses on auto: a monster with high INT picks attacks that are more effective against its opponent.
- **Winning.** A battle ends when the player has defeated the enemy monster.
- **Wild recruits.** After a wild monster is defeated, there is a chance it tries to join the player. If the player accepts, it goes to the farm and lives in its biome's habitat or the pasture, whichever is available.
- **Defeat.** If the player's monsters die, the player chooses to teleport back to the farm or go on without a partner. The Vet can revive monsters lost in battle, and they lose some bond with the player.

**Tournaments.** A monster battle tournament is held every season.

- Participation is optional. The player can skip any season.
- Taking part gives the chance to increase the farm's rank and size.
- Each win gives the chance to build a new habitat, as long as the player has the resources it needs.

Moves, type matchups, damage formulas, turn rules, and the tournament bracket format are not decided yet.

## Progression

Progress is measured by the farm: its rank, its size, and the habitats built on it. Tournament wins are the route to new habitats, and habitats decide which creatures can be kept. Habitats need resources, so gathering them while farming and travelling matters.

The currency is Coins. Prices are set as items are added, and each item gets a buying value and a selling value. The list of resources is not decided yet.

## Economy, releasing, and reputation

- **Selling.** The player can sell crops and the food they cook.
- **Releasing.** A monster caught in the wild can be released back to the wild, which gives a small reward.
- **Farm-bred monsters.** These cannot be released. They are sold or donated to the Monster Hunter Association, which offers them to new tamers. The player chooses between Coins and reputation as the payment.
- **Seasonal festival.** New hunters come to a festival each season, and the player can see where their monster went. As time passes, they may see that trainer using the monster in the Arena.
- **Breeding for others.** The player can breed monsters for NPCs for Coins. The payout depends on the player's Arena rank and reputation level.
- **Reputation.** Reputation is a core stat. It raises what breeders and the Association will pay, and it decides how good the job board requests are.

Prices and the size of the release reward are not decided yet.

## Reputation

Reputation is split into six categories: Trapping, Breeding, Farming, Battle, Exploration, and Creature care. The player is evaluated at the end of each season.

- **Earning it.** Reputation comes mostly from tournament wins and job board quests. Association donation requests are repeatable quests on the job board and are available most of the time. Specific monster types give more reputation than others, and the types in demand rotate week to week or season to season.
- **Rewards.** Rewards are tied to specific categories. They include access to places the Association only opens to select individuals, special buildings, better tools, and special capture items for catching a specific monster.
- **Guarded areas.** Off the beaten path in the biomes the player reaches by portal, some places are closed off by a guard. The player gets in by meeting a reputation threshold. These areas hold only A to S rank monsters of that biome.
- **Friendship.** Reputation only gives a small boost to how fast friendship grows. It never blocks a villager's friendship.

The thresholds, which category unlocks which reward, and how the season evaluation is scored are not decided yet.

## World

The game is set in Ahymn, on a different continent of Acia from the main island the books are based on. It is kept separate from the book canon for now, and some or all of it may become canon later once the game has something solid built. Dragon Warrior Monsters and Stardew Valley are the gameplay inspirations. Any story, factions, or characters are not decided yet.

## Art and platforms

16-bit pixel art with a cozy tone. The game targets PC and mobile and is single-player. A multiplayer or MMO version would be a separate standalone game later. Mobile pricing is undecided, leaning toward a one-time purchase of about $5 to $10. Audio direction and mobile controls are not decided yet.

## UI and technical specs

The UI should look similar to Stardew Valley: clean and clear.

- **Sprites.** Tiles are 16x16. The character sprite is 16x32. Items are 16x16. NPC portraits are 64x64.
- **Resolution.** 1920x1080, with an option for 4K.
- **Options.** The player can zoom in and scale the UI, and there is a colorblind mode.

## Technical notes

The engine is Godot, built with a team of three AI helpers, likely starting next week depending on progress on the tanks game. The design puts these requirements on it:

- One codebase for PC and mobile.
- A continuous in-game clock with a midnight tired state and a 2:00 AM pass-out.
- Per-creature data for affection and taming method, plus farm data for crops, habitats, rank, and size.
- Saving across seasons.

## Suggested build order

No dates or content counts are set. A natural order to prove the game early:

1. The farm, the continuous clock, sleeping, and passing out at 2:00 AM.
2. Growing food and trapping one creature in the Assessment room.
3. A habitat and the barn, so bonding and placement work.
4. A 1 to 2 creature battle.
5. The seasonal tournament with its rank, size, and habitat rewards.
6. The world map, with food, battle, and trap taming.

## Open questions

- How is climate managed for an egg or pregnant monster, and how long do hatching and pregnancy take?
- What percentage of carried money is lost when passing out, and how big is the fixed bonding drop?
- What does it cost to buy portal rights for each biome?
- Do seasons change anything besides crops and favorite foods?
- Do creatures use one taming method each, or can one creature need a combination?
- What do crops, food, and bred monsters sell for?
- When, and how much, of Ahymn becomes canon Acia?
- What is the final mobile pricing model (leaning toward a one-time $5 to $10 purchase)?
- What are the reputation thresholds and rewards for each category, and how is the season evaluation scored?
- How many hearts does a bad date cost, how long is the cooldown, and what does the player get from a good date or at each romance stage?
- How do the other trainers in the village fit in: rivals, friends, or tournament opponents?
- Beyond the stat bonus rules, how does the player's care affect offspring quality?
- Where else can recipes be found, and what friendship level does each villager need to give one?
- Which creatures lay eggs and which become pregnant?
- How long are the recovery timers, and can a monster that has gone wild be tamed again?
- Who is the appraiser, and how does the player learn the appraisal skill?
- Which skills can pass on at birth, and how are the rest gained over time?
- What does the egg evaluation place tell the player, and does it cost anything?
- Which elements and plant types exist as breeding modifiers, and how does the player get each one?
- What do the four barn upgrades cost, and what materials do they need?
- How likely is it that a defeated wild monster asks to join, and does anything change the odds?
- What does reviving a monster at the Vet cost, and how much bond is lost?
- How many skills can a monster know at once, and how are they learned?
- What do traps cost or need to build, and how do trap tier and bait change the chance of a catch?
- Which monsters are passive and can be trapped, and which need food or a battle?
- What do health and 0% health mean outside of battle?
- How do tool upgrades work, and how many days does each crop growth stage take?
- How do the controls work on mobile?

---

*This is a cleaned markdown version of the full GDD for use as the project source of truth.*
