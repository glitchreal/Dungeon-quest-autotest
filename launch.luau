getgenv().autoexecute = true
getgenv().autoloadconfig = true

-- Autotest checkout: exercise the autotest mirror bundle.
loadstring(game:HttpGet("https://raw.githubusercontent.com/glitchreal/Dungeon-quest-autotest/main/main.luau"))()
