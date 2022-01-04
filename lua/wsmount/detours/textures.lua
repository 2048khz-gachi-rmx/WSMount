-- override texture setters because CW2 is insane and uses those

local realTexID = _WSMountOverrides["surface.GetTextureID"] or surface.GetTextureID
_WSMountOverrides["surface.GetTextureID"] = realTexID

local realSetTex = _WSMountOverrides["surface.SetTexture"] or surface.SetTexture
_WSMountOverrides["surface.SetTexture"] = realSetTex

WSMount.PathToTex = WSMount.PathToTex or {}
WSMount.TexToPath = WSMount.TexToPath or {}
WSMount.TexSwap = WSMount.TexSwap or {} 	-- [texID_old] = texID_new

function surface.GetTextureID(path)
	-- whyyyyyy must you do this to me
	local ret = realTexID(path)

	WSMount.PathToTex[path] = WSMount.PathToTex[path] or {}
	WSMount.PathToTex[path][ret] = true
	WSMount.TexToPath[ret] = path

	return ret
end

function surface.SetTexture(id)
	id = WSMount.TexSwap[id] or id

	return realSetTex(id)
end