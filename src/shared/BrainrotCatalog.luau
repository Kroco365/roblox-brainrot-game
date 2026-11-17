--!nocheck
-- BrainrotCatalog: the whole cast of Brainrot Bazaar, one table per character.
-- Every brainrot is an original meme-born character with its own rarity, income
-- rate, price, colour and accessory. Shared by server and client, so the shop,
-- the index panel and the conveyor all agree on the same numbers.
-- Rarity ladder: Common -> Rare -> Epic -> Legendary -> Mythic -> Secret.

local BrainrotCatalog = {}

export type BrainrotDef = {
	id: string,
	name: string,
	rarity: string,
	rate: number, -- dollars earned per second on a base
	cost: number, -- dollars to buy it off the conveyor
	weight: number, -- spawn weight on the conveyor
	color: Color3,
	accessory: string, -- what CharacterFactory builds on top of it
	blurb: string,
}

local function def(
	id: string,
	name: string,
	rarity: string,
	rate: number,
	cost: number,
	weight: number,
	color: Color3,
	accessory: string,
	blurb: string
): BrainrotDef
	return {
		id = id,
		name = name,
		rarity = rarity,
		rate = rate,
		cost = cost,
		weight = weight,
		color = color,
		accessory = accessory,
		blurb = blurb,
	}
end

BrainrotCatalog.BRAINROTS = {
	def("cone_carl", "Traffic Cone Carl", "Common", 1, 25, 100, Color3.fromRGB(255, 128, 0), "Cone", "A cone that achieved sentience and now directs traffic in your base."),
	def("couch_king", "Couch Potato King", "Common", 2, 60, 90, Color3.fromRGB(150, 90, 50), "Crown", "Has not moved since 2019. Earns rent by sitting there."),
	def("dj_pickle", "DJ Pickle", "Rare", 5, 150, 55, Color3.fromRGB(80, 200, 60), "Headphones", "Drops beats and brine. The brine pays better."),
	def("wifi_grandma", "Grandma's WiFi Router", "Rare", 8, 250, 45, Color3.fromRGB(120, 120, 130), "Antenna", "Blinks. Buffers. Somehow still charges rent."),
	def("toaster_reg", "Sir Reginald Toaster", "Epic", 15, 500, 28, Color3.fromRGB(200, 200, 210), "TopHat", "Knighted for services to breakfast. Burns everything, earns anyway."),
	def("cactus_emo", "Emotional Support Cactus", "Epic", 22, 800, 22, Color3.fromRGB(40, 170, 80), "Spikes", "Hugs back, but only emotionally. Thrives on neglect."),
	def("croissant_cap", "Captain Croissant", "Legendary", 45, 1800, 12, Color3.fromRGB(230, 180, 60), "CaptainHat", "Sailed the seven seas of butter. Flaky, but rich."),
	def("burrito_forbidden", "The Forbidden Burrito", "Legendary", 70, 3000, 9, Color3.fromRGB(190, 140, 70), "Foil", "Nobody knows what is inside. The money comes out anyway."),
	def("banana_quantum", "Quantum Banana", "Mythic", 150, 7500, 4, Color3.fromRGB(255, 230, 40), "Glow", "Exists in two places at once. Both of them pay rent."),
	def("ceo_naps", "CEO of Naps", "Mythic", 300, 18000, 2, Color3.fromRGB(90, 90, 160), "Tie", "Runs a Fortune 500 company from a pillow. Never awake, always paid."),
	def("printer_almighty", "The Almighty Printer", "Secret", 1000, 60000, 1, Color3.fromRGB(230, 230, 230), "PaperStack", "It only prints memes. The memes are legal tender here."),
}

-- Rarity colours, shared by the 3D name tags and the client index panel.
BrainrotCatalog.RARITY_COLORS = {
	Common = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(80, 180, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 180, 40),
	Mythic = Color3.fromRGB(255, 70, 90),
	Secret = Color3.fromRGB(255, 240, 120),
}

-- Mutations roll on every spawn: Normal x1, Golden x2, Diamond x5, Rainbow x10.
BrainrotCatalog.MUTATIONS = {
	{ name = "Normal", multiplier = 1, chance = 0.86, color = Color3.fromRGB(255, 255, 255) },
	{ name = "Golden", multiplier = 2, chance = 0.10, color = Color3.fromRGB(255, 210, 60) },
	{ name = "Diamond", multiplier = 5, chance = 0.03, color = Color3.fromRGB(120, 220, 255) },
	{ name = "Rainbow", multiplier = 10, chance = 0.01, color = Color3.fromRGB(255, 120, 220) },
}

-- Rarity order, for sorting the index panel and the ladder display.
BrainrotCatalog.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

function BrainrotCatalog.getById(id: string): BrainrotDef?
	for _, entry in ipairs(BrainrotCatalog.BRAINROTS) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- Weighted random pick for the conveyor. `boost` multiplies the weight of
-- Epic-or-better entries (used by the Brainrot Rain event).
function BrainrotCatalog.pickRandomSpawn(boost: number?): BrainrotDef
	local total = 0
	local weights = {}
	local rarityRank = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5, Secret = 6 }
	for i, entry in ipairs(BrainrotCatalog.BRAINROTS) do
		local w = entry.weight
		if boost and rarityRank[entry.rarity] >= 3 then
			w *= boost
		end
		weights[i] = w
		total += w
	end
	local roll = math.random() * total
	for i, entry in ipairs(BrainrotCatalog.BRAINROTS) do
		roll -= weights[i]
		if roll <= 0 then
			return entry
		end
	end
	return BrainrotCatalog.BRAINROTS[1]
end

-- Roll a mutation for a fresh spawn.
function BrainrotCatalog.rollMutation(): (string, number, Color3)
	local roll = math.random()
	local acc = 0
	for _, mutation in ipairs(BrainrotCatalog.MUTATIONS) do
		acc += mutation.chance
		if roll <= acc then
			return mutation.name, mutation.multiplier, mutation.color
		end
	end
	return "Normal", 1, Color3.fromRGB(255, 255, 255)
end

-- Dollars per second a brainrot earns, after mutation and rebirth multiplier.
function BrainrotCatalog.rateFor(entry: BrainrotDef, mutationMultiplier: number, rebirthMultiplier: number): number
	return entry.rate * mutationMultiplier * rebirthMultiplier
end

-- The conveyor price of a mutated brainrot: mutations cost extra.
function BrainrotCatalog.priceFor(entry: BrainrotDef, mutationMultiplier: number): number
	return math.floor(entry.cost * (1 + (mutationMultiplier - 1) * 0.5) + 0.5)
end

return BrainrotCatalog
