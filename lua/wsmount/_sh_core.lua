
local wsCol = Color(81, 126, 189)
local txCol = Color(220, 220, 220)

local badCol = Color(184, 52, 22)
local badTxCol = Color(220, 190, 190)

-- spew into console but don't put a newline
-- args are like printf
function WSMount.LogContinuous(s, ...)
	s = s:format(...)

	MsgC(wsCol, "[WSMount] ", txCol, s)
end

function WSMount.LogErrorContinuous(s, ...)
	s = s:format(...)

	MsgC(badCol, "[WSMount Error] ", badTxCol, s)
end

-- continue continuous log, ie don't put the tag prefix
function WSMount.LogContinue(s, ...)
	s = s:format(...)
	MsgC(txCol, s)
end

function WSMount.LogErrorContinue(s, ...)
	s = s:format(...)
	MsgC(badTxCol, s)
end


-- same but put a newline; log in one function
function WSMount.Log(s, ...) return WSMount.LogContinuous(s .. "\n", ...) end
function WSMount.LogError(s, ...) return WSMount.LogErrorContinuous(s .. "\n", ...) end

if CLIENT then
	function WSMount.Say(s, ...)
		s = s:format(...)

		chat.AddText(wsCol, "[WSMount] ", txCol, s)
	end
end