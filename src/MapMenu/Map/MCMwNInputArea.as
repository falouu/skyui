import gfx.ui.InputDetails;

class Map.MCMwNInputArea extends MovieClip {
  /* STAGE ELEMENTS */
	public var textInput: TextField;
  /* PRIVATE VARIABLES */
  	private var _bShown: Boolean = false;
	
	// @override MovieClip
	private function onLoad(): Void
	{
		hide();
		textInput.noTranslate = true;
		textInput.SetText("dupa"); //it works!
		textInput.onSetFocus = function(){
			_parent.onSetFocus();
		}
		textInput.onKillFocus = function(){
			_parent.onKillFocus();
		}
	}
	
	// @override MovieClip
	public function onSetFocus() {
		//skse.Log("Map.MCMwNInputArea - onSetFocus");
		if (!_bShown)
			return;
		//textInput.SetText("focus");
		skse.AllowTextInput(true);
	}
	
	// @override MovieClip
	public function onKillFocus(a_newFocus: Object)
	{
		skse.AllowTextInput(false);
	};
	
	public function show(){
		_bShown = true;
	}
	
	public function hide(){
		_bShown = false;
	}
	
	// @GFx
	public function handleInput(details: InputDetails, pathToFocus: Array): Boolean
	{
		var nextClip = pathToFocus.shift();
		return nextClip.handleInput(details, pathToFocus);
	}
}