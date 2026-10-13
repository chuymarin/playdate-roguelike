-- Everything the game says: config/text.json. Each entry is a list of
-- lines (the dialogue box shows one line at a time and Ⓐ moves on) or one
-- short string (toasts, hint templates where %s is filled in). Ⓐ and Ⓑ
-- are the Playdate system font's button glyphs.

Game.text = Game.loadConfig("text")
