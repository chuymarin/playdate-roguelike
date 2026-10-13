-- Everything the game says. Each entry is a list of lines; the dialogue box
-- shows one line at a time and Ⓐ moves on. Ⓐ and Ⓑ are the Playdate
-- system font's button glyphs.

Game.text = {
	intro = { "Home, sweet home.", "Something is waiting in that chest. Face it and press Ⓐ." },
	shield = { "You got a shield!", "Hold it up with Ⓑ. It pushes enemies back one step." },
	sword = { "You got a sword!", "Press Ⓐ to swing it at whatever is in front of you." },
	key = { "You got the dungeon key!", "It opens the locked door into the dungeon." },
	cellKey = { "You got the cell key!", "Somebody must be locked up down here." },
	heart = { "A heart container! You can hold one more heart." },
	locked = { "The door is locked.", "The key must be hidden in a forest or in some ruins." },
	faint = { "You fainted...", "You wake up rested, back where you last slept." },
	cellLocked = { "Help! They locked me in here!", "The guards keep the key in a chest, somewhere in this dungeon." },
	goal = { "You got me out!", "I've been stuck in that cell for so long. Thank you!" },
	theEnd = { "The end. Press Ⓐ for a new world." },
	greetings = { "Hello, traveler!", "Oh! A visitor.", "Nice day for a walk, isn't it?", "Mind the monsters out there." },
	camp = "Rested at camp",
	coin = "+1 coin",
	unlocked = "The door is open",
	cellOpened = "The cell is open",
}
