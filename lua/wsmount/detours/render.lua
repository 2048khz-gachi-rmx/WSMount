-- do this before anyone loads so no localizing bullshit occurs

local setters = {
	render = {
		render,
		"SetMaterial",
		"MaterialOverride",
		"ModelMaterialOverride",
		"BrushMaterialOverride",
	},

	surface = {
		surface,
		"SetMaterial"
	}
}

-- override material-settting functions to use swap materials, if possible
for namespace, fns in pairs(setters) do
	local tbl = fns[1] -- i dont want to use "_" .. "G", so no bekdor scanerz
	for i=2, #fns do
		local name = fns[i]
		local key = namespace .. "." .. name

		local orig_fn = _WSMountOverrides[key] or tbl[name]
		_WSMountOverrides[key] = orig_fn

		tbl[name] = function(mat, ...)
			mat = WSMount.SwapMaterials[mat] or mat
			return orig_fn(mat, ...)
		end
	end
end