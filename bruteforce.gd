extends Node

# Constants
const HANDCUFF_NONE = 0
const HANDCUFF_FREENEXT = 1
const HANDCUFF_CUFFED = 2

const MAGNIFYING_NONE = 0
const MAGNIFYING_LIVE = 1
const MAGNIFYING_BLANK = 2

const OPTION_NONE = 0
const OPTION_SHOOT_SELF = 1
const OPTION_SHOOT_OTHER = 2
const OPTION_MAGNIFY = 3
const OPTION_CIGARETTES = 4
const OPTION_BEER = 5
const OPTION_HANDCUFFS = 6
const OPTION_HANDSAW = 7

const ROUNDTYPE_NORMAL = 0
const ROUNDTYPE_WIRECUT = 1
const ROUNDTYPE_DOUBLEORNOTHING = 2

class Result:
	var option: int
	var healthScore: float
	var itemScore: float

	func _init(option, healthScore, itemScore):
		self.option = option
		self.healthScore = healthScore
		self.itemScore = itemScore

	func _to_string():
		return "Option %s [%s] [%s]" % [
			self.option, self.healthScore, self.itemScore
		]

# Player class
class BruteforcePlayer:
	var player_index: int

	var max_health: int
	var health: int

	var max_magnify: int
	var max_cigarettes: int
	var max_beer: int
	var max_handcuffs: int
	var max_handsaw: int

	var magnify: int
	var cigarettes: int
	var beer: int
	var handcuffs: int
	var handsaw: int

	func _init(player_index, max_health, max_magnify, max_cigarettes, max_beer, max_handcuffs, max_handsaw):
		self.player_index = player_index

		self.max_health = max_health
		self.health = max_health

		self.max_magnify = max_magnify
		self.max_cigarettes = max_cigarettes
		self.max_beer = max_beer
		self.max_handcuffs = max_handcuffs
		self.max_handsaw = max_handsaw

		self.magnify = max_magnify
		self.cigarettes = max_cigarettes
		self.beer = max_beer
		self.handcuffs = max_handcuffs
		self.handsaw = max_handsaw

	func hash(num):
		num *= 2
		num += self.player_index

		num *= (self.max_health+1)
		num += self.health

		num *= (self.max_magnify+1)
		num += self.magnify

		num *= (self.max_cigarettes+1)
		num += self.max_cigarettes

		num *= (self.max_beer+1)
		num += self.beer

		num *= (self.max_handcuffs+1)
		num += self.handcuffs

		num *= (self.max_handsaw+1)
		num += self.handsaw

		return num

	func use(item, count=1):
		var new_player = BruteforcePlayer.new(self.player_index, self.max_health, self.max_magnify, self.max_cigarettes, self.max_beer, self.max_handcuffs, self.max_handsaw)

		# Copy attributes to the new instance
		var found = false
		for attribute in self.get_property_list():
			if not found and attribute["name"] == item:
				found = true
				new_player.set(attribute["name"], self.get(attribute["name"]) - count)
			else:
				new_player.set(attribute["name"], self.get(attribute["name"]))

		if not found and item:
			print("Invalid item:", item)

		return new_player

	func createSubplayer(other: BruteforcePlayer):
		if other.player_index != self.player_index:
			return null
		if other.max_health != self.max_health:
			return null
		if other.magnify > self.max_magnify or other.cigarettes > self.max_cigarettes or other.beer > self.max_beer or other.handcuffs > self.max_handcuffs or other.handsaw > self.max_handsaw:
			return null

		var copy = BruteforcePlayer.new(self.player_index, self.max_health, self.max_magnify, self.max_cigarettes, self.max_beer, self.max_handcuffs, self.max_handsaw)
		copy.health = other.health
		copy.magnify = other.magnify
		copy.cigarettes = other.cigarettes
		copy.beer = other.beer
		copy.handcuffs = other.handcuffs
		copy.handsaw = other.handsaw
		return copy

	func sum_items():
		return self.magnify * 1.5 + self.beer + BruteforcePlayer.falloff(self.handsaw, 2) + BruteforcePlayer.falloff(self.handcuffs, 1) + self.cigarettes * 0.5

	static func falloff(someNum, limit):
		if someNum <= limit:
			return someNum
		return limit + (someNum-limit) / 2

	func _to_string():
		return "Player %s: Health=%s/%s, Magnify=%s, Cigarettes=%s, Beer=%s, Handcuffs=%s, Handsaw=%s" % [
			self.player_index, self.health, self.max_health, self.magnify, self.cigarettes, self.beer, self.handcuffs, self.handsaw
		]

class BruteforceGame:
	var liveCount: int
	var blankCount: int
	var player: BruteforcePlayer
	var opponent: BruteforcePlayer

	func _init(liveCount, blankCount, player: BruteforcePlayer, opponent: BruteforcePlayer):
		self.liveCount = liveCount
		self.blankCount = blankCount
		self.player = player
		self.opponent = opponent

	func CreateSubPlayers(liveCount, blankCount, player, opponent):
		if liveCount > self.liveCount or blankCount > self.blankCount:
			return null
		if player.player_index == self.player.player_index:
			player = self.player.createSubplayer(player)
			opponent = self.opponent.createSubplayer(opponent)
		else:
			player = self.opponent.createSubplayer(player)
			opponent = self.player.createSubplayer(opponent)

		if player == null or opponent == null:
			return null

		return [player, opponent]

static var cachedGame = null
static var cache = {}
static func GetBestChoiceAndDamage(roundType, liveCount, blankCount, player: BruteforcePlayer, opponent: BruteforcePlayer, handcuffState=HANDCUFF_NONE, magnifyingGlassResult=MAGNIFYING_NONE, usedHandsaw=false):
	ModLoaderLog.info("%s: %s Live, %s Blank\n%s\n%s\n%s, %s, %s" % [roundType, liveCount, blankCount, player, opponent, handcuffState, magnifyingGlassResult, usedHandsaw], "ITR-SmarterDealer")

	if cachedGame != null:
		var subPlayers = cachedGame.CreateSubPlayers(liveCount, blankCount, player, opponent)
		if subPlayers != null:
			player = subPlayers[0]
			opponent = subPlayers[1]
		else:
			cachedGame = null

	if cachedGame == null:
		cache = {}
		cachedGame = BruteforceGame.new(liveCount, blankCount, player, opponent)

	var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount, player, opponent, handcuffState, magnifyingGlassResult, usedHandsaw)
	return result

static func GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player: BruteforcePlayer, opponent: BruteforcePlayer, handcuffState=HANDCUFF_NONE, magnifyingGlassResult=MAGNIFYING_NONE, usedHandsaw=false):
	if player.health <= 0 or opponent.health <= 0:
		var winningBonus = -10 if player.health <= 0 else 10
		return Result.new(OPTION_NONE, winningBonus, player.sum_items() - opponent.sum_items())

	# On wirecut rounds you can no longer smoke, and your health is set to 1
	if roundType == ROUNDTYPE_WIRECUT:
		if player.health == 2 or (player.health <= 2 and player.cigarettes > 0):
			player = player.use("cigarettes", player.cigarettes)
			player.health = 1
		if opponent.health == 2 or (opponent.health <= 2 and opponent.cigarettes > 0):
			opponent = opponent.use("cigarettes", opponent.cigarettes)
			opponent.health = 1

	var hash = blankCount * (liveCount_max+1) + liveCount
	hash = player.hash(hash)
	hash = opponent.hash(hash)
	hash = ((hash * 3 + handcuffState) * 3 + magnifyingGlassResult ) * 2
	if usedHandsaw:
		hash += 1

	if cache.has(hash):
		return cache[hash]

	var smokeAmount = min(player.cigarettes, player.max_health - player.health)

	if liveCount == 0:
		var shootWho = OPTION_SHOOT_SELF
		if blankCount == 1 and randi() % 10 < 3:
			shootWho = OPTION_SHOOT_OTHER

		if player.player_index == 0 or blankCount > 0:
			player = player.use("cigarettes", smokeAmount)

		var opponentSmokeAmount = 0
		if opponent.player_index == 0:
			opponentSmokeAmount = min(opponent.cigarettes, opponent.max_health - opponent.health)
			opponent = opponent.use("cigarettes", opponentSmokeAmount)

		return Result.new(shootWho, smokeAmount - opponentSmokeAmount, player.sum_items() - opponent.sum_items())

	if smokeAmount > 0:
		player = player.use("cigarettes", smokeAmount)
		player.health += smokeAmount

	var options = {
		OPTION_SHOOT_OTHER: 0.0,
		OPTION_SHOOT_SELF: 0.0,
	}
	var itemscores = {
		OPTION_SHOOT_OTHER: 0.0,
		OPTION_SHOOT_SELF: 0.0,
	}

	if handcuffState <= HANDCUFF_NONE and player.handcuffs > 0:
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("handcuffs"), opponent, HANDCUFF_CUFFED, magnifyingGlassResult, usedHandsaw)
		options[OPTION_HANDCUFFS] = result.healthScore
		itemscores[OPTION_HANDCUFFS] = result.itemScore

	if magnifyingGlassResult == MAGNIFYING_NONE and player.magnify > 0 and liveCount > 0 and blankCount > 0:
		var result1 = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("magnify"), opponent, handcuffState, MAGNIFYING_BLANK, usedHandsaw)
		var result2 = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("magnify"), opponent, handcuffState, MAGNIFYING_LIVE, usedHandsaw)
		options[OPTION_MAGNIFY] = (result1.healthScore * blankCount + result2.healthScore * liveCount) / (blankCount + liveCount)
		itemscores[OPTION_MAGNIFY] = (result1.itemScore * blankCount + result2.itemScore * liveCount) / (blankCount + liveCount)

	if not usedHandsaw and player.handsaw > 0 and liveCount > 0:
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("handsaw"), opponent, handcuffState, magnifyingGlassResult, true)
		options[OPTION_HANDSAW] = result.healthScore
		itemscores[OPTION_HANDSAW] = result.itemScore

	if player.beer > 0:
		options[OPTION_BEER] = 0.0
		itemscores[OPTION_BEER] = 0.0

	var liveChance = liveCount / float(liveCount + blankCount)
	var blankChance = blankCount / float(liveCount + blankCount)

	if magnifyingGlassResult == MAGNIFYING_BLANK:
		liveChance = 0.0
		blankChance = 1.0
	elif magnifyingGlassResult == MAGNIFYING_LIVE:
		liveChance = 1.0
		blankChance = 0.0

	var damageToDeal = min(2 if usedHandsaw else 1, opponent.health)

	if liveCount > 0 and magnifyingGlassResult != MAGNIFYING_BLANK:
		var result
		var nextDamageIfShootLive
		var itemscoreTakenIfShootLive
		var nextDamageIfSelfShootLive
		var itemscoreTakenIfSelfShootLive
		if handcuffState <= HANDCUFF_FREENEXT:
			result = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, opponent.use("health", damageToDeal), player)
			nextDamageIfShootLive = result.healthScore
			itemscoreTakenIfShootLive = result.itemScore

			result = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, opponent, player.use("health", damageToDeal))
			nextDamageIfSelfShootLive = result.healthScore
			itemscoreTakenIfSelfShootLive = result.itemScore
		else:
			result = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, player, opponent.use("health", damageToDeal), HANDCUFF_FREENEXT)
			nextDamageIfShootLive = -result.healthScore
			itemscoreTakenIfShootLive = -result.itemScore

			result = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, player.use("health", damageToDeal), opponent, HANDCUFF_FREENEXT)
			nextDamageIfSelfShootLive = -result.healthScore
			itemscoreTakenIfSelfShootLive = -result.itemScore

		options[OPTION_SHOOT_OTHER] += (damageToDeal - nextDamageIfShootLive) * liveChance
		itemscores[OPTION_SHOOT_OTHER] += -itemscoreTakenIfShootLive * liveChance
		options[OPTION_SHOOT_SELF] += (-damageToDeal - nextDamageIfSelfShootLive) * liveChance
		itemscores[OPTION_SHOOT_SELF] += -itemscoreTakenIfSelfShootLive * liveChance

		if player.beer > 0:
			result = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, player.use("beer"), opponent, handcuffState, MAGNIFYING_NONE, usedHandsaw)
			var nextDamageIfBeerLive = result.healthScore
			var itemscoreTakenIfBeerLive = result.itemScore
			options[OPTION_BEER] += nextDamageIfBeerLive * liveChance
			itemscores[OPTION_BEER] += itemscoreTakenIfBeerLive * liveChance

	if blankCount > 0 and magnifyingGlassResult != MAGNIFYING_LIVE:
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount - 1, liveCount_max, player, opponent, handcuffState, MAGNIFYING_NONE, usedHandsaw and player.player_index != 0)
		var nextDamageIfShootBlankContinueTurn = result.healthScore
		var itemscoreTakenIfShootBlankContinueTurn = result.itemScore

		options[OPTION_SHOOT_SELF] += nextDamageIfShootBlankContinueTurn * blankChance
		itemscores[OPTION_SHOOT_SELF] += (itemscoreTakenIfShootBlankContinueTurn) * blankChance

		if handcuffState <= HANDCUFF_FREENEXT:
			result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount - 1, liveCount_max, opponent, player)
			var nextDamageIfShootBlank = -result.healthScore
			var itemscoreIfShootBlank = -result.itemScore
			options[OPTION_SHOOT_OTHER] += nextDamageIfShootBlank * blankChance
			itemscores[OPTION_SHOOT_OTHER] += itemscoreIfShootBlank * blankChance
		else:
			result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount - 1, liveCount_max, player, opponent, HANDCUFF_FREENEXT, MAGNIFYING_NONE, false)
			nextDamageIfShootBlankContinueTurn = result.healthScore
			itemscoreTakenIfShootBlankContinueTurn = result.itemScore
			options[OPTION_SHOOT_OTHER] += nextDamageIfShootBlankContinueTurn * blankChance
			itemscores[OPTION_SHOOT_OTHER] += itemscoreTakenIfShootBlankContinueTurn * blankChance

		if player.beer > 0:
			result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount - 1, liveCount_max, player.use("beer"), opponent, handcuffState, MAGNIFYING_NONE, usedHandsaw)
			var nextDamageIfBeerBlank = result.healthScore
			var itemscoreTakenIfBeerBlank = result.itemScore
			options[OPTION_BEER] += nextDamageIfBeerBlank * blankChance
			itemscores[OPTION_BEER] += itemscoreTakenIfBeerBlank * blankChance

	var highestDamage = -10000.0
	var highestItems = -10000.0
	var results = []

	for key in options:
		if usedHandsaw and key == OPTION_SHOOT_SELF:
			# Disallow this for now
			continue
		if options[key] < highestDamage:
			continue
		var result = Result.new(key, options[key], itemscores[key])
		if options[key] > highestDamage or itemscores[key] > highestItems:
			results = [result]
			highestDamage = options[key]
			highestItems = itemscores[key]
			continue

		if itemscores[key] < highestItems:
			continue

		results += [result]

	if results.size() == 0:
		print("Error, no valid options!")
		return Result.new(OPTION_NONE, 0, 0)

	if results.size() == 1:
		cache[hash] = results[0]
		return results[0]

	results.shuffle()

	cache[hash] = results[0]

	return results[0]
