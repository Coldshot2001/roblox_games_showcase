local abilities = {}
abilities.Abilities = {
	["Cyber Dawg"] = {
		[1] = {
			["Function"] = function(self, target, chars)
				target["Current Health"] -= 1
				if target["Current Health"] < 0 then
					target["Current Health"] = 0
				end
			end,
			["Type"] = "Attack",
			["CurCD"] = 0,
			["BaseCD"] = 0,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "Cool Ability",
		}, --1st index is the function
		--2nd index is the type of move
		--3rd index is the current cooldown (current turns left until the move can be used again)
		--4th index is the base cooldown(how many turns it takes for the turn to be available again)
		--5th index is the animation ID
		--6th index is the description of the skill
		--7th index is the name of the skill
		--if the base cooldown is "-1" then its a passive
		[2] = {
			["Function"] = function(self, target, chars)
				target["Current Health"] += 1
				if target["Current Health"] > target["Health"] then
					target["Current Health"] = target["Health"]
				end
			end,
			["Type"] = "Support",
			["CurCD"] = 0,
			["BaseCD"] = 2,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "bad Ability",
		},

		[3] = {
			["Function"] = function(self, target, chars)
				print("its pASSIVE ", target)
			end,
			["Type"] = "Passive",
			["CurCD"] = -1,
			["BaseCD"] = -1,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "Passive Ability",
		},
	},
	["Claw Dude"] = {
		[1] = {
			["Function"] = function(self, target, chars)
				target["Current Health"] -= 1000
				if target["Current Health"] < 0 then
					target["Current Health"] = 0
				end
			end,
			["Type"] = "Attack",
			["CurCD"] = 0,
			["BaseCD"] = 0,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "Cool Ability",
		},

		[2] = {
			["Function"] = function(self, target, chars)
				target["Current Health"] += 1
				if target["Current Health"] > target["Health"] then
					target["Current Health"] = target["Health"]
				end
			end,
			["Type"] = "Support",
			["CurCD"] = 0,
			["BaseCD"] = 2,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "bad Ability",
		},

		[3] = {
			["Function"] = function(self, target, chars)
				print("its pASSIVE ", target)
			end,
			["Type"] = "Passive",
			["CurCD"] = -1,
			["BaseCD"] = -1,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "Passive Ability",
		},
	},
	["Palace Sentry"] = {
		[1] = {
			["Function"] = function(self, target, chars)
				target["Current Health"] -= 1000
				if target["Current Health"] < 0 then
					target["Current Health"] = 0
				end
			end,
			["Type"] = "Attack",
			["CurCD"] = 0,
			["BaseCD"] = 0,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "Annihilate",
		},

		[2] = {
			["Function"] = function(self, target, chars)
				target["Current Health"] += 1
				if target["Current Health"] > target["Health"] then
					target["Current Health"] = target["Health"]
				end
			end,
			["Type"] = "Support",
			["CurCD"] = 0,
			["BaseCD"] = 2,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "Awesome Ability",
		},

		[3] = {
			["Function"] = function(self, target, chars)
				print("its pASSIVE ", target)
			end,
			["Type"] = "Passive",
			["CurCD"] = -1,
			["BaseCD"] = -1,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "Passive Ability",
		},
	},
	["Blue Gun Dude"] = {
		[1] = {
			["Function"] = function(self, target, chars)
				print(self, target, chars)
				target["Current Health"] -= 1
				if target["Current Health"] < 0 then
					target["Current Health"] = 0
				end
			end,
			["Type"] = "Attack",
			["CurCD"] = 0,
			["BaseCD"] = 0,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "Cool Ability",
		},

		[2] = {
			["Function"] = function(self, target, chars)
				target["Current Health"] += 1
				if target["Current Health"] > target["Health"] then
					target["Current Health"] = target["Health"]
				end
			end,
			["Type"] = "Support",
			["CurCD"] = 0,
			["BaseCD"] = 2,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "bad Ability",
		},

		[3] = {
			["Function"] = function(self, target, chars)
				print("its pASSIVE ", target)
			end,
			["Type"] = "Passive",
			["CurCD"] = -1,
			["BaseCD"] = -1,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "Passive Ability",
		},
	},
	["Punching Dummy"] = {
		[1] = {
			["Function"] = function(self, target, chars)
				target["Current Health"] -= 1
				if target["Current Health"] < 0 then
					target["Current Health"] = 0
				end
			end,
			["Type"] = "Attack",
			["CurCD"] = 0,
			["BaseCD"] = 0,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "Cool Ability",
		},

		[2] = {
			["Function"] = function(self, target, chars)
				target["Current Health"] += 1
				if target["Current Health"] > target["Health"] then
					target["Current Health"] = target["Health"]
				end
			end,
			["Type"] = "Support",
			["CurCD"] = 0,
			["BaseCD"] = 2,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "bad Ability",
		},

		[3] = {
			["Function"] = function(self, target, chars)
				print("its pASSIVE ", target)
			end,
			["Type"] = "Passive",
			["CurCD"] = -1,
			["BaseCD"] = -1,
			["Animation"] = "",
			["Description"] = "lol",
			["Name"] = "Passive Ability",
		},
	},
}

return abilities
