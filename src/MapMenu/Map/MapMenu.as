﻿import gfx.io.GameDelegate;
import gfx.ui.NavigationCode;
import gfx.ui.InputDetails;
import gfx.managers.FocusHandler;
import gfx.managers.InputDelegate;

import Map.LocalMap;
import Map.LocationFinder;
import Shared.ButtonChange;
import Shared.GlobalFunc;

import skyui.components.ButtonPanel;
import skyui.components.MappedButton;
import skyui.defines.Input;
import skyui.util.DialogManager;

/*
	A few comments:
	* The map menu set up somewhat complicated. There's a lot of @API, so changing that was not an option.
	* The top-level clip contains 3 main components, and the bottombar.
		Root
		+-- MapMenu (aka WorldMap. this class)
		+-- LocalMap
		+-- LocationFinder (new)
		+-- BottomBar
	* To prevent WSAD etc from zooming while the location finder is active, we have to enter a fake local map mode.
	* LocalMap handles the overall state of the menu: worldmap(aka hidden), localmap, locationfinder
	* To open the LocationFinder, we send a request to localmap, which prepares the fake mode, then shows the location finder.
	* For handleInput, MapMenu acts as the root.
	* The bottombar changes happen in LocalMap when the mode is changed.
	* To detect E as NavEquivalent.ENTER, we have to enable a custom fixup in InputDelegate.
	* To receive mouse wheel input for the scrolling list, we need skse.EnableMapMenuMouseWheel(true).
	* Oh, and the localmap reuses this class somehow for its IconView...
 */

class Map.MapMenu
{
	#include "../../version.as"
	
  /* CONSTANTS */
  
	private static var REFRESH_SHOW: Number = 0;
	private static var REFRESH_X: Number = 1;
	private static var REFRESH_Y: Number = 2;
	private static var REFRESH_ROTATION: Number = 3;
	private static var REFRESH_STRIDE: Number = 4;
	private static var CREATE_NAME: Number = 0;
	private static var CREATE_ICONTYPE: Number = 1;
	private static var CREATE_UNDISCOVERED: Number = 2;
	private static var CREATE_STRIDE: Number = 3;
	private static var MARKER_CREATE_PER_FRAME: Number = 10;
	
	
  /* PRIVATE VARIABLES */
  
	private var _markerList: Array;
	
	private var _bottomBar: MovieClip;

	private var _nextCreateIndex: Number = -1;
	private var _mapWidth: Number = 0;
	private var _mapHeight: Number = 0;
	
	private var _mapMovie: MovieClip;
	private var _markerDescriptionHolder: MovieClip;
	private var _markerContainer: MovieClip;
	
	private var _selectedMarker: MovieClip;
	
	private var _platform: Number;
	
	private var _localMapButton: MovieClip;
	private var _journalButton: MovieClip;
	private var _playerLocButton: MovieClip;
	private var _findLocButton: MovieClip;
	private var _searchButton: MovieClip;
	
	private var _locationFinder: LocationFinder;
	
	private var _localMapControls: Object;
	private var _journalControls: Object;
	private var _zoomControls: Object;
	private var _playerLocControls: Object;
	private var _setDestControls: Object;
	private var _findLocControls: Object;
	
   /* MCMwN */
    private static var _instance: MapMenu;
	private static var MCMWN_MARKER_PATTERN: String = "Marked Location ";
	private static var MCMWN_MAX_TITLE_LENGTH: Number = 100;
	private static var MCMWN_MARKER_CLIP: String = "PlayerSetMarker";
	/* dispatched SKSE events */
	private static var sMarkerRemoveEvent: String = "MCMwN_markerRemove"
	private static var sMarkerChangeNoteEvent: String = "MCMwN_markerChangeNote"
	private var _MCMwNEditDialog: Map.MCMwNEditDialog;
	private var _MCMwNclickedMarker: MovieClip;
	//// type of current selected marker
	//public var currentMarkerTypeString: String;
	private var _customMarkersData: Array;
	/* -1 if selected marker is not custom marker */
	private var _selectedCustomMarkerId: Number = -1;
	private var _clickedCustomMarkerId : Number = -1;
	
  /* STAGE ELEMENTS */
  
  	public var locationFinderFader: MovieClip;
	public var localMapFader: MovieClip;
	

  /* PROPERTIES */

	// @API
	public var LocalMapMenu: MovieClip;

	// @API
	public var MarkerDescriptionObj: MovieClip;
	
	// @API
	public var PlayerLocationMarkerType: String;
	
	// @API
	public var MarkerData: Array;
	
	// @API
	public var YouAreHereMarker: MovieClip;
	
	// @GFx
	public var bPCControlsReady: Boolean = true;
	

  /* INITIALIZATION */

	public function MapMenu(a_mapMovie: MovieClip)
	{
		_instance = this;
		_mapMovie = a_mapMovie == undefined ? _root : a_mapMovie;
		_markerContainer = _mapMovie.createEmptyMovieClip("MarkerClips", 1);
		
		_markerList = new Array();
		_nextCreateIndex = -1;
		
		LocalMapMenu = _mapMovie.localMapFader.MapClip;
		
		_locationFinder = _mapMovie.locationFinderFader.locationFinder;
		
		_bottomBar = _root.bottomBar;
		
		if (LocalMapMenu != undefined) {
			LocalMapMenu.setBottomBar(_bottomBar);
			LocalMapMenu.setLocationFinder(_locationFinder);
			//// <rhobar3@gmail.com>
			_MCMwNEditDialog = _mapMovie.MCMwNEditDialogFaderInstance.MCMwNEditDialogInstance;
			LocalMapMenu.setMCMwNEditDialog(_MCMwNEditDialog);
			_MCMwNEditDialog.addEventListener("acceptPress", this, "onMCMwNEditDialogAcceptPress");
			_MCMwNEditDialog.addEventListener("deletePress", this, "onMCMwNEditDialogDeletePress");
			
			Mouse.addListener(this);
			FocusHandler.instance.setFocus(this,0);
		}
		
		_markerDescriptionHolder = _mapMovie.attachMovie("DescriptionHolder", "markerDescriptionHolder", _mapMovie.getNextHighestDepth());
		_markerDescriptionHolder._visible = false;
		_markerDescriptionHolder.hitTestDisable = true;
		MarkerDescriptionObj = _markerDescriptionHolder.Description;
		Stage.addListener(this);
		initialize();
	}
	
	public function InitExtensions(): Void
	{
		skse.EnableMapMenuMouseWheel(true);
	}
	
	private function initialize(): Void
	{
		onResize();
		
		if (_bottomBar != undefined)
			_bottomBar.swapDepths(4);
		
		if (_mapMovie.localMapFader != undefined) {
			_mapMovie.localMapFader.swapDepths(3);
			_mapMovie.localMapFader.gotoAndStop("hide");
		}
		
		if (_mapMovie.locationFinderFader != undefined) {
			_mapMovie.locationFinderFader.swapDepths(6);
		}
		
		GameDelegate.addCallBack("RefreshMarkers", this, "RefreshMarkers");
		GameDelegate.addCallBack("SetSelectedMarker", this, "SetSelectedMarker");
		GameDelegate.addCallBack("ClickSelectedMarker", this, "ClickSelectedMarker");
		GameDelegate.addCallBack("SetDateString", this, "SetDateString");
		GameDelegate.addCallBack("ShowJournal", this, "ShowJournal");
	}
	
	
  /* PUBLIC FUNCTIONS */

	// @API
	public function SetNumMarkers(a_numMarkers: Number): Void
	{
		if (_markerContainer != null)
		{
			_markerContainer.removeMovieClip();
			_markerContainer = _mapMovie.createEmptyMovieClip("MarkerClips", 1);
			onResize();
		}
		
		delete _markerList;
		_markerList = new Array(a_numMarkers);
		
		Map.MapMarker.topDepth = a_numMarkers;

		_nextCreateIndex = 0;
		SetSelectedMarker(-1);
		
		_locationFinder.list.clearList();
		_locationFinder.setLoading(true);
	}

	// @API
	public function GetCreatingMarkers(): Boolean
	{
		return _nextCreateIndex != -1;
	}

	// @API
	public function CreateMarkers(): Void
	{
		if (_nextCreateIndex == -1 || _markerContainer == null)
			return;
			
		var i = 0;
		var j = _nextCreateIndex * Map.MapMenu.CREATE_STRIDE;
		
		var markersLen = _markerList.length;
		var dataLen = MarkerData.length;
			
		while (_nextCreateIndex < markersLen && j < dataLen && i < Map.MapMenu.MARKER_CREATE_PER_FRAME) {
			var markerType = MarkerData[j + Map.MapMenu.CREATE_ICONTYPE];
			var markerName = MarkerData[j + Map.MapMenu.CREATE_NAME];
			var isUndiscovered = MarkerData[j + Map.MapMenu.CREATE_UNDISCOVERED];
			
			var cmId = getCustomMarkerId(markerName);
			if(cmId < 0){
				// regular marker
				var mapMarker: MovieClip = _markerContainer.attachMovie(Map.MapMarker.ICON_TYPES[markerType], "Marker" + _nextCreateIndex, _nextCreateIndex);
				if (markerType == PlayerLocationMarkerType) {
					YouAreHereMarker = mapMarker.Icon;
				}
				mapMarker.label = markerName;
				if (isUndiscovered && mapMarker.IconClip != undefined) {
					var depth: Number = mapMarker.IconClip.getNextHighestDepth();
					mapMarker.IconClip.attachMovie(Map.MapMarker.ICON_TYPES[markerType] + "Undiscovered", "UndiscoveredIcon", depth);
				}
			} else {
				// MCMwM custom marker
				var mapMarker: MovieClip = _markerContainer.attachMovie(MCMWN_MARKER_CLIP, "Marker" + _nextCreateIndex, _nextCreateIndex);
				mapMarker._x += 0.15*mapMarker._width;
				mapMarker._y += 0.15*mapMarker._height;
				mapMarker._xscale = 70;
				mapMarker._yscale = 70;
				mapMarker.label = getCustomMarkerTitle(cmId, markerName);
			}
			
			_markerList[_nextCreateIndex] = mapMarker;
			mapMarker.index = _nextCreateIndex;
			mapMarker.textField._visible = false;
			mapMarker.visible = false;
			mapMarker.iconType = markerType;
			
			// Adding the markers directly so we don't have to create data objects.
			// NOTE: Make sure internal entry properties (mappedIndex etc) dont conflict with marker properties
			if (0 < markerType && markerType < Map.LocationFinder.TYPE_RANGE) {
				_locationFinder.list.entryList.push(mapMarker);
			}
			++i;
			++_nextCreateIndex;
			
			j = j + Map.MapMenu.CREATE_STRIDE;
		}
		
		_locationFinder.list.InvalidateData();
		
		if (_nextCreateIndex >= markersLen) {
			_locationFinder.setLoading(false);
			_nextCreateIndex = -1;
		}
	}

	// @API
	public function RefreshMarkers(): Void
	{
		var i: Number = 0;
		var j: Number = 0;
		var markersLen: Number = _markerList.length;
		var dataLen: Number = MarkerData.length;
		
		while (i < markersLen && j < dataLen) {
			var marker: MovieClip = _markerList[i];
			marker._visible = MarkerData[j + Map.MapMenu.REFRESH_SHOW];
			if (marker._visible) {
				marker._x = MarkerData[j + Map.MapMenu.REFRESH_X] * _mapWidth;
				marker._y = MarkerData[j + Map.MapMenu.REFRESH_Y] * _mapHeight;
				marker._rotation = MarkerData[j + Map.MapMenu.REFRESH_ROTATION];
			}
			++i;
			j = j + Map.MapMenu.REFRESH_STRIDE;
		}
		if (_selectedMarker != undefined) {
			_markerDescriptionHolder._x = _selectedMarker._x + _markerContainer._x;
			_markerDescriptionHolder._y = _selectedMarker._y + _markerContainer._y;
		}
	}

	// @API
	public function SetSelectedMarker(a_selectedMarkerIndex: Number): Void
	{
		var marker: MovieClip = a_selectedMarkerIndex < 0 ? null : _markerList[a_selectedMarkerIndex];
		
		if (marker == _selectedMarker)
			return;
			
		if (_selectedMarker != null) {
			_selectedMarker.MarkerRollOut();
			_selectedMarker = null;
			_markerDescriptionHolder.gotoAndPlay("Hide");
		}
		
		if (marker != null && !_bottomBar.hitTest(_root._xmouse, _root._ymouse) && marker.visible && marker.MarkerRollOver()) {
			_selectedMarker = marker;
			_markerDescriptionHolder._visible = true; 
			_markerDescriptionHolder.gotoAndPlay("Show");
			return;
		}
		_selectedMarker = null;
	}

	// @API
	public function ClickSelectedMarker(): Void
	{
		if (_selectedMarker != undefined) {
			//// <rhobar3@gmail.com> 
			if(_selectedCustomMarkerId > 0){
				_MCMwNclickedMarker = _selectedMarker;
				_clickedCustomMarkerId = _selectedCustomMarkerId
				LocalMapMenu.showMCMwNEditDialog( _customMarkersData[_selectedCustomMarkerId-1] );
			} else {
				_selectedMarker.MarkerClick();
			}
		}
	}

	// @API
	public function SetPlatform(a_platform: Number, a_bPS3Switch: Boolean): Void
	{
	
		if (a_platform == ButtonChange.PLATFORM_PC) {
			_localMapControls = {keyCode: 38}; // L
			_journalControls = {name: "Journal", context: Input.CONTEXT_GAMEPLAY};
			_zoomControls = {keyCode: 283}; // special: mouse wheel
			_playerLocControls = {keyCode: 18}; // E
			_setDestControls = {keyCode: 256}; // Mouse1
			_findLocControls = {keyCode: 33}; // F
		} else {
			_localMapControls = {keyCode: 278}; // X
			_journalControls = {keyCode: 270}; // START
			_zoomControls = [	// LT/RT
				{keyCode: 280},
				{keyCode: 281}
			];
			_playerLocControls = {keyCode: 279}; // Y
			_setDestControls = {keyCode: 276}; // A
			_findLocControls = {keyCode: 273}; // RS
		}
		
		if (_bottomBar != undefined) {
			
			_bottomBar.buttonPanel.setPlatform(a_platform, a_bPS3Switch);

			createButtons(a_platform != ButtonChange.PLATFORM_PC);
		}
		if(LocalMapMenu._MCMwNEditDialog != undefined) {
			_MCMwNEditDialog.buttonPanel.setPlatform(a_platform, a_bPS3Switch);
			_MCMwNEditDialog.initButtons(a_platform);
		}
		
		InputDelegate.instance.isGamepad = a_platform != ButtonChange.PLATFORM_PC;
		InputDelegate.instance.enableControlFixup(true);
		
		_platform = a_platform;
	}

	// @API
	public function SetDateString(a_strDate: String): Void
	{
		_bottomBar.DateText.SetText(a_strDate);
	}

	// @API
	public function ShowJournal(a_bShow: Boolean): Void
	{
		if (_bottomBar != undefined) {
			_bottomBar._visible = !a_bShow;
		}
	}

	// @API
	public function SetCurrentLocationEnabled(a_bEnabled: Boolean): Void
	{
		if (_bottomBar != undefined && _platform == ButtonChange.PLATFORM_PC) {
			_bottomBar.PlayerLocButton.disabled = !a_bEnabled;
		}
	}
	
	// @GFx
	public function handleInput(details: InputDetails, pathToFocus: Array): Boolean
	{			
		var nextClip = pathToFocus.shift();
		if (nextClip.handleInput(details, pathToFocus))
			return true;
		
		// Find Location - L
		if (_platform == ButtonChange.PLATFORM_PC) {
			if (GlobalFunc.IsKeyPressed(details) && (details.skseKeycode == 33)) {
				LocalMapMenu.showLocationFinder();
			}
		}

		return false;
	}
	
	
  /* PRIVATE FUNCTIONS */
	
	private function OnLocalButtonClick(): Void
	{
		GameDelegate.call("ToggleMapCallback", []);
	}

	private function OnJournalButtonClick(): Void
	{
		GameDelegate.call("OpenJournalCallback", []);
	}

	private function OnPlayerLocButtonClick(): Void
	{
		GameDelegate.call("CurrentLocationCallback", []);
	}
	
	private function OnFindLocButtonClick(): Void
	{
		LocalMapMenu.showLocationFinder();
	}
	
	private function onMouseDown(): Void
	{
		if (_bottomBar.hitTest(_root._xmouse, _root._ymouse))
			return;
		GameDelegate.call("ClickCallback", []);
	}
	
	private function onResize(): Void
	{
		_mapWidth = Stage.visibleRect.right - Stage.visibleRect.left;
		_mapHeight = Stage.visibleRect.bottom - Stage.visibleRect.top;
		
		if (_mapMovie == _root) {
			_markerContainer._x = Stage.visibleRect.left;
			_markerContainer._y = Stage.visibleRect.top;
		} else {
			var localMap: LocalMap = LocalMap(_mapMovie);
			if (localMap != undefined) {
				_mapWidth = localMap.TextureWidth;
				_mapHeight = localMap.TextureHeight;
			}
		
		}
		GlobalFunc.SetLockFunction();
		_bottomBar.Lock("B");
	}
	
	private function createButtons(a_bGamepad: Boolean): Void
	{
		var buttonPanel: ButtonPanel = _bottomBar.buttonPanel;
		buttonPanel.clearButtons();

		_localMapButton =	buttonPanel.addButton({text: "$Local Map", controls: _localMapControls});			// 0
		_journalButton =	buttonPanel.addButton({text: "$Journal", controls: _journalControls});				// 1
							buttonPanel.addButton({text: "$Zoom", controls: _zoomControls});					// 2
		_playerLocButton =	buttonPanel.addButton({text: "$Current Location", controls: _playerLocControls});	// 3
		_findLocButton =	buttonPanel.addButton({text: "$Find Location", controls: _findLocControls});		// 4
							buttonPanel.addButton({text: "$Set Destination", controls: _setDestControls});		// 5
		_searchButton =		buttonPanel.addButton({text: "$Search", controls: Input.Space});					// 6
		
		_localMapButton.addEventListener("click", this, "OnLocalButtonClick");
		_journalButton.addEventListener("click", this, "OnJournalButtonClick");
		_playerLocButton.addEventListener("click", this, "OnPlayerLocButtonClick");
		_findLocButton.addEventListener("click", this, "OnFindLocButtonClick");
		
		_localMapButton.disabled = a_bGamepad;
		_journalButton.disabled = a_bGamepad;
		_playerLocButton.disabled = a_bGamepad;
		_findLocButton.disabled = a_bGamepad;
		
		_findLocButton.visible = !a_bGamepad;
		_searchButton.visible = false;
		
		buttonPanel.updateButtons(true);
	}
	
 ///* MCMwN */

	// @API
	public static function setCustomMarkersData(){
		_instance._customMarkersData = [];
		var cmData = _instance._customMarkersData;
		for (var i = 0; i < arguments.length; i++){
			cmData[i] = arguments[i];
		}
	}
	
	public static function getInstance(): MapMenu
	{
		return _instance;
	}
	
	/* return proper marker title to show */
	public function setAndAnalyzeSelectedMarkerName(markerName: String, select: Boolean): String
	{
		var cmId = getCustomMarkerId(markerName);
		if(select){
		   _selectedCustomMarkerId = cmId;
		}
		if(cmId < 1){
			return markerName;
		}
		return getCustomMarkerTitle(cmId, markerName);
	}
	
	private function getCustomMarkerTitle(cmId: Number, markerName: String): String 
	{
		var cmNote = _customMarkersData[cmId-1];
		if(cmNote == undefined or GlobalFunc.StringTrim(cmNote) == ""){
			return markerName;
		}
		return getCustomMarkerTitleFromNote(cmNote);
	}
	
	/* event listeners */
	private function onMCMwNEditDialogAcceptPress(event: Object)
	{
		//skse.Log("Map.MapMenu - onMCMwNEditDialogAcceptPress()");
		_customMarkersData[ _clickedCustomMarkerId - 1 ] = event.data;
		skse.SendModEvent(sMarkerChangeNoteEvent, event.data,  _clickedCustomMarkerId);
		_MCMwNclickedMarker.MarkerClick();
		_MCMwNclickedMarker = null;
		_clickedCustomMarkerId = -1;
	}
	
	private function onMCMwNEditDialogDeletePress()
	{
		skse.SendModEvent(sMarkerRemoveEvent, null,  _clickedCustomMarkerId);
		_MCMwNclickedMarker = null;
		_clickedCustomMarkerId = -1;
	}
	
	/* return -1 if not custom marker */
	private function getCustomMarkerId(markerName: String): Number
	{
		var pattern = markerName.substr(0, MCMWN_MARKER_PATTERN.length);
		if(pattern != MCMWN_MARKER_PATTERN){
			return -1;
		}
		var id = parseInt( markerName.substr( MCMWN_MARKER_PATTERN.length ) )
		if( id == Number.NaN or id < 1){
			return -1;
		}
		return id;
	}
	
	private function getCustomMarkerTitleFromNote(note: String): String
	{
		note = String(note); 
		var lf = note.indexOf("\r");
		if(lf < 0){
			lf = note.length;
		}
		if(lf > MCMWN_MAX_TITLE_LENGTH){
			lf = MCMWN_MAX_TITLE_LENGTH;
		}
		return note.slice(0, lf)
	}
	

}
