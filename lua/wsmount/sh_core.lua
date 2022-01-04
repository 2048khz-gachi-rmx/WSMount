
local wsCol = Color(81, 126, 189)
local txCol = Color(220, 220, 220)

local badCol = Color(184, 52, 22)
local badTxCol = Color(220, 190, 190)

function WSMount.Log(s, ...)
	s = s:format(...)

	MsgC(wsCol, "[WSMount] ", txCol, s, "\n")
end

function WSMount.LogError(s, ...)
	s = s:format(...)

	MsgC(badCol, "[WSMount Error] ", badTxCol, s, "\n")
end

if CLIENT then
	function WSMount.Say(s, ...)
		s = s:format(...)

		chat.AddText(wsCol, "[WSMount] ", txCol, s)
	end
end