Scriptname CustomMapMarkersInitScript extends Quest  
{Starts Custom Map Markers with Notes mod}

Float interval = 2.0
String mapMenuName = "MapMenu"

; /* STRINGS TO TRANSLATION */
string sErrorAddingSpell = "MCMwN - ERROR: adding spell 'Mark Location' failed!"
string sMessageNoMarkersAvailable = "You have no markers available. Remove one of your markers first."

; /* registered SKSE events */
string sMarkerRemoveEvent = "MCMwN_markerRemove"
string sMarkerChangeNoteEvent = "MCMwN_markerChangeNote"

; /* private variables */
;array where index is marker number and value is marker note
String[] markersNotes
;array where index is marker number and value is marker state (false - unused, true - used)
bool[] markersState ;default bool value = false

; /* properties */
Spell           property MCMwNmakeMarker            auto
FormList        property MCMwNmarkersFormList       auto
ObjectReference property MCMwNstorageLocationMarker auto

Event OnInit()
	; translation in UI - don't translate here
	Debug.Notification("$Multiple Custom Markers with Notes mod starting...")
	markersNotes = new String[128]
	markersState = new bool[128]
	RegisterForSingleUpdate(interval) ; Give us a single update in one second
	RegisterForMenuEvents()
	RegisterForMenu(mapMenuName)
	LocalizeStrings()
EndEvent

; must be called once per every savegame load
Function RegisterForMenuEvents()
	RegisterForModEvent(sMarkerRemoveEvent, "OnMarkerRemove")
	RegisterForModEvent(sMarkerChangeNoteEvent, "OnMarkerChangeNote")
EndFunction

; set strings values according to game languange
Function LocalizeStrings()
	if (Utility.GetINIString("sLanguage:General") == "POLISH")
		sErrorAddingSpell = "MCMwN - BŁĄD: nie powiodło się dodanie czaru 'Oznacz lokację'!"
		sMessageNoMarkersAvailable = "Nie masz wolnych znaczników. Usuń najpierw jeden z nich z mapy."
	endIf
EndFunction

; do nothing unless in readyState
Function MarkPlayerLocation()
EndFunction
; do nothing unless in readyState
int Function GetFirstUnusedMarkerIndex()
EndFunction
; do nothing unless in readyState
Event OnMarkerRemove(string eventName, string strArg, float numArg, Form sender)
EndEvent
; do nothing unless in readyState
Event OnMarkerChangeNote(string eventName, string strArg, float numArg, Form sender)
EndEvent

Auto State readyState
	Event OnUpdate()
		if (!Game.GetPlayer().AddSpell(MCMwNmakeMarker))
			Debug.Notification(sErrorAddingSpell)
		endIf
	EndEvent

	; /* map menu open event */
	Event OnMenuOpen(String MenuName)
		UI.InvokeStringA(mapMenuName, "_global.Map.MapMenu.setCustomMarkersData", markersNotes)
	EndEvent

	; /* event dispatched by map menu */
	; numArg - marker index
	Event OnMarkerRemove(string eventName, string strArg, float numArg, Form sender)
		gotoState("lockState")
		int mIndex = numArg as int
		; move marker back to the marker storage location
		ObjectReference marker = MCMwNmarkersFormList.getAt(mIndex - 1) as ObjectReference
		marker.Disable();
		marker.MoveTo( MCMwNstorageLocationMarker ) 
		; set marker disabled
		markersState[mIndex - 1] = false
		gotoState("readyState")
	EndEvent

	; /* event dispatched by map menu */
	; strArg - new note
	; numArg - marker index
	Event OnMarkerChangeNote(string eventName, string strArg, float numArg, Form sender)
		gotoState("lockState")
		int mIndex = numArg as int
		;Debug.Notification("MCMwN - Debug: change note of location "+mIndex+" to: "+strArg)
		markersNotes[mIndex - 1] = strArg
		gotoState("readyState")
	EndEvent

	; move available marker to player location
	Function MarkPlayerLocation()
		int uMIndex = GetFirstUnusedMarkerIndex()
		if (uMIndex == -1)
			Debug.MessageBox(sMessageNoMarkersAvailable)
			;Debug.MessageBox("$MCMwN_NO_MARKERS_AVAILABLE")
			return
		endIf
		ObjectReference marker = MCMwNmarkersFormList.getAt(uMIndex) as ObjectReference
		marker.MoveTo(Game.GetPlayer())
		marker.Enable()
		markersState[uMIndex] = true
		markersNotes[uMIndex] = ""
		; translation in UI - don't translate here
		Debug.Notification("$Location marked on map")
	EndFunction


	int Function GetFirstUnusedMarkerIndex()
		int i=0
		int len = markersState.length
		int objCount = MCMwNmarkersFormList.getSize()
		if (objCount < len)
			len = objCount
		endIf
		while (i < len && markersState[i])
			i += 1
		endWhile
		if (i == len)
			return -1
		endIf
		return i
	EndFunction
EndState

State lockState
	;functions are locked for thread safety
EndState