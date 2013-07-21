Scriptname MCMwNmakeMarkerSpellScript extends ActiveMagicEffect 
{Script that add marker on map}

; /* properties */
CustomMapMarkersInitScript property MCMwNCore auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
  ;Debug.Notification("MCMwN - Debug: MCMwNmakeMarkerEffect.OnEffectStart called")
  MCMwNCore.MarkPlayerLocation()
endEvent