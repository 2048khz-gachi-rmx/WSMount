
-- because the hook lib doesnt exist at preboot, we hook after base loads
-- note: this turned out to be useless so it's not used rn, lol
WSMount.Hooks = WSMount.Hooks or {}

for ev, dat in pairs(WSMount.Hooks) do
	for hn, fn in pairs(dat) do
		hook.Add(ev, hn, fn)
	end
end