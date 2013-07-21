import skyui.components.ButtonPanel;
import gfx.managers.FocusHandler;
import gfx.ui.InputDetails;
import skyui.defines.Input;
import gfx.events.EventDispatcher;
import gfx.io.GameDelegate;
import Shared.GlobalFunc;

class Map.MCMwNEditDialog extends MovieClip
{	
  /* PUBLIC PROPERTIES */
  /* PRIVATE VARIABLES */
  	private var _bShown: Boolean = false;
	private var _acceptControls: Object;
	private var _deleteControls: Object;
	private var _hiddenDepth: Number = -1;
	

  /* STAGE ELEMENTS */
	public var markerMessage: Map.MCMwNInputArea;
	public var buttonPanel: ButtonPanel;
	
	// @mixin by gfx.events.EventDispatcher
	public var dispatchEvent: Function;
	public var dispatchQueue: Function;
	public var hasEventListener: Function;
	public var addEventListener: Function;
	public var removeEventListener: Function;
	public var removeAllEventListeners: Function;
	public var cleanUpEvents: Function;
	
	public function MCMwNEditDialog()
	{
		super();
		EventDispatcher.initialize(this);
	}
	
	public function show(): Void
	{
		if(_bShown){
			return;
		}
		_bShown = true;
		FocusHandler.instance.setFocus(markerMessage,0);
		markerMessage.show();
		_hiddenDepth = _parent.getDepth();
		_parent.swapDepths(6);
		_parent.gotoAndPlay("fadeIn");
	}
	
	// @override MovieClip
	private function onLoad(): Void
	{
		hide(true);
	}
	
	public function hide(a_bInstant: Boolean): Void
	{
		if(!_bShown){
			return;
		}
		_bShown = false;
		markerMessage.hide();
		_parent.swapDepths(_hiddenDepth);
		if (a_bInstant)
			_parent.gotoAndStop("hide");
		else
			_parent.gotoAndPlay("fadeOut");
	}
	
	// @GFx
	public function handleInput(details: InputDetails, pathToFocus: Array): Boolean
	{
		if (_bShown) {
			if (GlobalFunc.IsKeyPressed(details)) {
				if (details.skseKeycode == _acceptControls.keyCode) {
					skse.Log("Map.MCMwNEditDialog - handleInput, _acceptControls ");
					onAcceptPress();
					return true;
				} else if(details.skseKeycode == _deleteControls.keyCode){
					skse.Log("Map.MCMwNEditDialog - handleInput, _deleteControls");
					onDeletePress();
					return true;
				}
			}
		}
		var nextClip = pathToFocus.shift();
		return nextClip.handleInput(details, pathToFocus);
	}
	
	public function initButtons(platform: Number): Void
	{
		/*
		if (platform == 0) {
			_acceptControls = Input.Enter;
		} else {
			_acceptControls = Input.Accept;
		}
		*/
		_acceptControls = { keyCode: 29 }; // left ctrl
		_deleteControls = { keyCode: 56 }; // left alt
		
		buttonPanel.clearButtons();
		var acceptButton = buttonPanel.addButton({text: "$OK", controls: _acceptControls});
		var deleteButton = buttonPanel.addButton({text: "$remove", controls: _deleteControls});
		acceptButton.addEventListener("press", this, "onAcceptPress");
		deleteButton.addEventListener("press", this, "onDeletePress");
		buttonPanel.updateButtons();
	}
	
	public function setMessage(msg: String){
		markerMessage.textInput.text = msg;
	}
	
	private function onAcceptPress(){
		hide(false);
		GameDelegate.call("ToggleMapCallback", []);
		var msg = markerMessage.textInput.text;
		dispatchEvent({type: "acceptPress", data: msg });
	}
	
	private function onDeletePress(){
		hide(false);
		GameDelegate.call("ToggleMapCallback", []);
		dispatchEvent({type: "deletePress"});
	}
}