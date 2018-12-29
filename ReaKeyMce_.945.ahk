/*
	ReaKeyMce ver .944Guiwork
	april 10, 2016 by Kip Chatterson
	ReaKeyMce - reaper specfic - ansi-32 ahk 
	
	WHAT IS IT?  Mackie Control Universal emulator (control surface) for the pc computer keyboard
	It converts keypresses into 8 faders, 8 pans, mute/solo/arm buttons emulating a mackie control universal
	Proper use requires Klinke's control surface plugin for reaper to be installed.
	
	Asking Jim for help on my fader problem - bouncy - jumpy faders.
	I left fader 1 with traymenu to see value coming back.
	
	Jim search for your name
	
	
	---------------------
	TODO
	
	- move gui to context menu or on a button on the item, 
	
	because not all windows versions allow the tray icon to show in taskbar anymore.
	
	- make a button for changing pans to sends? working? to test....
	
	
	- make send text and consider toggling collapse and expand for mixing children along with selects. ?
	-  fix auto close
	- fix on first open load defaults, maybe leave ini file?
	- fix gui error on ini creation
	
	
	WHAT IT NEEDS.
	
	
	- user selectable keys for pause - perhaps prompt the first load?
	
	Bank Keys fixed - how to determine what postion it is in?
	
	; Last edited 1/20/2015 11:19 AM by Kip Chatterson - change this when you edit it, please
	bank could be shown on lcd if necessary...
	
	I do not know
	Working on banking, and making sure it is less squrily
	
	- need to test return from pause....
	
	- all buttons on computer keyboard.
	
	
	General -
	
	+ add a reset to 0db for each.
	
	This software is copyright Kip Chatterson 2016
	It is closed source.
	;  < -------
*/

; Jim
;------------ 
;	Could not decide which of these below belonged on
;------------
#SingleInstance force
#NoEnv 	
#Persistent
SetBatchLines, -1

;listline off
#KeyHistory 0 				; does this break something?
SetKeyDelay, -1, -1, Play	; set no delay - Not sure if I need this?
SetMouseDelay, -1
SetWinDelay, 0
SetControlDelay, 0
SetDefaultMouseSpeed, 0
SendMode Input             	; Recommended for new scripts due to its superior speed and reliability.


						; Recommended for performance and compatibility with future AutoHotkey releases.
;#MaxThreadsPerHotkey 1
#usehook 						; did this change behavior?  Do I need this?
;#MaxHotkeysPerInterval 300  	; Interval is 2000 milliSeconds - should be plenty. to prevent beeping from keyRepeats.
;#HotkeyInterval 1
#maxthreads 10
;#HotkeyInterval 10
#MaxThreadsPerHotkey 1
SetWorkingDir %A_ScriptDir% 	; Ensures a consistent starting directory.

#include Mackie_LCD_listener2.ahk ;dorfl68 wrote this - awesome! ; need it loaded first. ;*[ReaKeyMce_.944Guiwork]

Menu, tray, icon, images\active 4.ico 	; SET TRAY ICON

version = ReaKeyMce_0.945_settings	; Change this to reflect current version.
fadermenu = mediumFast		; set these vars before readini
vpotmenu = medium
jogmenu = medium

makeMenu()
readini()                       ; load values from the ini file, via the readini function
Gosub, MidiPortRefresh          ; used to refresh the Input and output port lists 
port_test(numports,numports2)   ; test the ports - check for valid ports?
Gosub, midiin_go                ; opens the midi Input port listening routine  - I think this may be the problem
Gosub, midiout                  ; opens the midi out port see below.

; why am I running this, doesn't it do it anyway?
;Initialize: ; SET STARTUP VALUES FOR VARIBLES AND OTHER STUFF

	SetTimer, Faders_Run, 50 	;%fader_timer% ;Loop Faders_Run THE ORIGINAL TIMER WAS 50 I like 10 here on my system
	SetTimer, Vpots_Run,  75 	;%vpot_timer% ;VPOTS NOT AS CRUCIAL SO THIS SEEMS FINE FOR THEM.

	; set some vars
	Chan  		:= 1   	; midi Chan to Send on - All mackie vpots and jog wheel are on Midi Chan 1
	JogCC   	:= 60  	; cc # for jog wheel in mackie
	Vpot1   	= 16  	; cc# for vpots
	Note		:= 60 	; Note for middle C
	NoteVel		:= 127 	; Midi noteon message value
	Section    	= Start Reaper Now! ; just a reminder to start now.

	; Vpots
	RelUp := 1
	RelDown := 65

	;FADERS ------------------------------

	; Jim this may be part of my problem
	PBdelta = 256 ; Meaning the boucing I see may be due to this var.

	; Reaper specific VARS - these were used when I was trynig to use it with other daws. I can probably pull them out, just not yet.
	/* 
		THESE ARE MACKIE CONTROL UNIVERSAL NOTE ON MESSAGES OR CC NUMBERS OR 
	*/
	zerodb=12400	
	pans=42
	sends=41
	plugins=43
	eq=44
	return_s=51
	loop=86
		undo=76
	redo=79
	pageleft=44
	pageright=45
	shift=70
	option=71
	control=72
	alt=73
	;	vpots = 16|17|18|19|20|21|22|23| ; am i using these???
	vpot1 = 16
	vpot2 = 17
	vpot3 = 18
	vpot4 = 19
	vpot5 = 20
	vpot6 = 21
	vpot7 = 22
	vpot8 = 23

	FlipON		= 0			; set Gui flip to off
	VPotMode	:= "Pans" 	; set start up vpots Controlling pans

	Gosub, display	; run the display

return

;*************************************************
;* 			END OF AUTOEXEC. SECTION
;*************************************************
24GuiContextMenu: 		; right click to show context menu - can put thsis anywhere 
	Menu ContextMenu, Show
return	

; this seems to belong in the midi section
MidiOut: 		; Function to load new settings from midi out menu item 
	OpenCloseMidiAPI()
	h_midiout := midiOutOpen(MidiOutDevice) ; OUTPUT PORT 1 
Return

;*************************************************
;* 			PAUSE KEY SUSPENDS THIS PROGRAM - allowing the keyboard to be used as normal.
;*************************************************
+Del::  ; shift delete = had to rename - there is no pause key on the lenovo computer
	suspend, Permit
	gosub, SuspendIt ; see label below
return

Pause: 				; Suspends script. Threads run. Passes keypress unaffected to active program.
	Suspend, Permit 	; allow Pause Button to be active to Toggle Suspend function.
	Gosub, SuspendIt 	; call the SuspendIt function below.
Return

SuspendIt: ;function to suspend to allow keys to pass on to app.
/*
	NEED TO ADD A DIALOG TO COME BACK FROM PAUSE SETTING FLIP AND RETURNS IN THE RIGHT PLACE
	RIGHT NOW THE GUI IS KINDA SCREWY THAT WAY. ?????????????
*/

	{
		Suspend ; Suspend all keys that are not Permitted.
		Loop
		{
			If (A_IsSuspended = 1) ; if Pause is pushed on
			{
				Menu, tray, icon, images\Pause3.ico,,1 	; change tray icon to Suspended icon
							;Menu, tray, Disable, CenterLCD			; Disable some tray Menu items
				Menu, tray, Disable, MidiSet
				Sleep, 10
							;WinGetPos, winX, winY,,,%version% 		; Gui postion
							;Gui,24: Destroy							; Destroy main Gui
				Gosub, ShowPAUSEgui						; call Suspend Gui subroutine (see below Gui Section)
				Break
			}
			
	;*************************************************
	;* 			QUESTION - DO I NEED TO RERUN PBSEND? no this part is not paused
	; 	if I do do i need to get master fader?
	; 	only problem is if someone pauses when on different bank... need to test that.
	;*************************************************
			
			Else If (A_IsSuspended = 0)
			{
				Menu, tray, icon, images\active 4.ico ,,1 	; change tray icon back to active icon
							;Menu, tray, Enable, CenterLCD				; Enable tray Menu items again.
				Menu, tray, Enable, MidiSet
							;WinGetPos, winX, winY,,,%version% 			; Gui postion
				;			gosub, autodaw
							;Gui, 24: Destroy
				Gosub, ShowUpdategui
							;BankPos = %BankPos%
							;BankPosition(BankPos)
				Break
			}
			Return
		}
		Return
	}

;*************************************************
;*          GET PORTS LIST PARSE
;*************************************************

MidiPortRefresh: ; get the list of portsz
	MIlist := MidiInsList(NumPorts) 
	Loop Parse, MIlist, | 
		{
		}
	TheChoice := MidiInDevice + 1

	MOlist := MidiOutsList(NumPorts2) 
	Loop Parse, MOlist, | 
		{
		}
	TheChoice2 := MidiOutDevice + 1

	MIfaderList := MidiInsList(NumPorts)    
	Loop Parse, MIfaderList, | 
		{
		}
	TheChoice3 := MidiInDevice2 + 1

return ; end of MidiPort Refresh

;*************************************************
;*          LOAD SETTING FROM INI/SETUP MENUS
;*************************************************

makeMenu() ; CREATE THE TRAY AND CONTEXT MENUS
	{
		;SET UP tray menu items?
		global version ; this does not belong here
			;adding the tray menu items
		Menu, tray, noStandard , , 	;NoStandard	; gets rid of the Standard Menu items.
		Menu, tray, add, Quick_Set_Guide  ; the quick set image
		Menu, tray, add, ShowKeys         ; some way to show the keys needed
		Menu, tray, add, TroubleShoot
			;--------------- this line is just for my reference
		Menu tray, add, 			; separator
			;---------------
		Menu, tray, add, MidiSet          ; set midi ports
	;		Menu, Tray, add, KeyMap, key_layout_choice
			;--------------
		Menu, tray, add, 			; separator
			;--------------
		Menu, faderspeed, Add, slow, FaderSpeedSlow                     ; (3) Code this line third
		Menu, faderspeed, Add, medium, FaderSpeedMedium 
		Menu, faderspeed, Add, mediumFast, FaderSpeedMediumFast 
		Menu, faderspeed, Add, fast, FaderSpeedFast                     ; (2) Code this line second
		Menu, Tray, Add, Faders, :faderspeed 
		;----------- no separator
		Menu, vpotspeed, Add, slow, VpotSpeedSlow                   ; (3) Code this line third
		Menu, vpotspeed, Add, medium, VpotSpeedMed                     ; (2) Code this line second
		Menu, vpotspeed, Add, fast, VpotSpeedFast                    ; (2) Code this line second
		Menu, Tray, Add, Vpots , :vpotspeed                              ; (1) Code this line first
		;----------- no separator
		Menu, jogspeed, Add, slow, JogSpeedSlow                    ; (3) Code this line third
		Menu, jogspeed, Add, medium, JogSpeedMed 
		Menu, jogspeed, Add, fast, JogSpeedFast                     ; (2) Code this line second
		Menu, tray, Add, Jog, :jogspeed 
		;-----------	no separator
		menu, tray, add		;separator
			;-----------------
		Menu, tray, add, Pause			; Pause the program (Suspend mode)
		Menu, tray, add, Reload, Set_Done ; Reload the script
		Menu, tray, add, CenterLCD        ; reset the LCD disply to Center --------------------------------
		Menu, tray, add, ResetAll         ; Delete the ini file for testing --------------------------------
			;----------------
		Menu tray, add, ; separator
			;----------------
	;		Menu, tray, add, About			; about this program
		Menu, tray, add, UserGuide,OpenPdf	; open pdf
			;---------------
		Menu tray, add, ; separator
			;---------------
			;Menu, tray, add, Update? , ReaKeyMce_Home_Page ; go to the ReaKeyMce home page
			;Menu tray, add, Donate ,Beverageware
		Menu, tray, add, Exit, GuiClose 	; quit the app
		Menu, tray, tip, %version%   ; shows the tool tip of the name of the program
		
		/* 
			RIGHT CLICK CONTEXT MENU FOR GUI 24
			This menu is identical to the tray menu excpet fo the nostandard part.
		*/
		
		menu, contextmenu, add, REAPER
		Menu, contextmenu, add, Quick_Set_Guide  ; the quick set image
		Menu, contextmenu, add, ShowKeys         ; some way to show the keys needed
		Menu, contextmenu, add, TroubleShoot
		Menu, contextmenu, add, 			; separator
		Menu, contextmenu, add, MidiSet          ; set midi ports
	;		Menu, Tray, add, KeyMap, key_layout_choice
		Menu, contextmenu, add, 			; separator	
		
		Menu, faderspeed, Add, slow, FaderSpeedSlow                     ; (3) Code this line third
		Menu, faderspeed, Add, medium, FaderSpeedMedium 
		Menu, faderspeed, Add, mediumFast, FaderSpeedMediumFast 
		Menu, faderspeed, Add, fast, FaderSpeedFast                     ; (2) Code this line second
		Menu, contextmenu, Add, Faders, :faderspeed 
		;-----------
		Menu, vpotspeed, Add, slow, VpotSpeedSlow                   ; (3) Code this line third
		Menu, vpotspeed, Add, medium, VpotSpeedMed                     ; (2) Code this line second
		Menu, vpotspeed, Add, fast, VpotSpeedFast                    ; (2) Code this line second
		Menu, contextmenu, Add, Vpots , :vpotspeed                              ; (1) Code this line first
		;-----------
		Menu, jogspeed, Add, slow, JogSpeedSlow                    ; (3) Code this line third
		Menu, jogspeed, Add, medium, JogSpeedMed 
		Menu, jogspeed, Add, fast, JogSpeedFast                     ; (2) Code this line second
		Menu, contextmenu, Add, Jog, :jogspeed
		;------------
		Menu contextmenu, add, ; separator
		;-----------
		Menu, contextmenu, add, Pause			; Pause the program (Suspend mode)
		Menu, contextmenu, add, Reload, Set_Done ; Reload the script
		Menu, contextmenu, add, CenterLCD        ; reset the LCD disply to Center --------------------------------
		Menu, contextmenu, add, ResetAll         ; Delete the ini file for testing --------------------------------
		Menu, contextmenu, add, 		; separator
		Menu, contextmenu, add, UserGuide -fix this,OpenPdf	; open pdf
		Menu contextmenu, add, ; separator
	;Menu, tray, add, Update? , ReaKeyMce_Home_Page ; go to the ReaKeyMce home page
	;Menu tray, add, Donate ,Beverageware
		Menu, contextmenu, add, Exit, GuiClose 	; quit the app
	}

/* 
	THIS ONLY OWRKS FOR ME... CHANGE IT TO LOOK FOR REAPER OR ALLOW VARIBLE FOR USER TO ENTER PATH OF REAPER
*/

REAPER: ; label called from context menu to launch portable reaper on 
	run d:\Reaper\reaper.exe
return

ReadIni() ; also set up the tray Menu
	{
		global MidiInDevice, MidiInDevice2, MidiOutDevice, winX, winY, version, fadermenu, jogmenu, vpotmenu ; var is set at the beginning.
		IfExist, %version%.ini ; does ini file Exist? If yes go load values
		{
			IniRead, MidiInDevice, %version%.ini, Settings, MidiInDevice , %MidiInDevice%		;get midi in device from .ini file
			IniRead, MidiOutDevice, %version%.ini, Settings, MidiOutDevice , %MidiOutDevice%	; get midi out device from .ini file
			IniRead, MidiInDevice2, %version%.ini, Settings, MidiInDevice2 , %MidiInDevice2%  ; read the midi out port from ini file
			IniRead, fadermenu, %version%.ini, Settings, fadermenu, %fadermenu%					; fadermenu from ini
			menu, faderspeed, check, %fadermenu%											; place check mark
			IniRead, vpotrmenu, %version%.ini, Settings, vpotmenu, %vpotmenu%				; need default values for these when no .ini exists
			menu, vpotspeed, check, %vpotmenu%
			IniRead, jogmenu, %version%.ini, Settings, jogmenu, %jogmenu%	
			menu, jogspeed, check, %jogmenu%
			IniRead, winX, %version%.ini, GuiPosition, winX 									; Gui x postion
			If winX not Between 0 and 1600 ; if not Between these values set Gui top Center Screen.
				winX = Center
			IniRead, winY, %version%.ini, GuiPosition, winY ; Gui y postion
			If winY not Between -10 and 1600
				winY = 0
			Return winX winY ; Return those values out of the function.
		}
		Else ; no ini Exists and this is either the First Run or settings have been reset.
		{	; display text below. maybe put a button for loading pdf here?
			MsgBox, 0, ReaKeyMce - Read THIS! -, `nImportant notes - Read IT!`n`n+ Works with REAPER, ONLY`n+ Requires Klinke's csurf plugin (see pdf)`n+ Requires 2 vitrual midi ports installed (see pdf).`n+ Designed on US - QWERTY keyboard, all commands are physically located based on QWERTY. Other keylayouts`, such as QWERTZ - "Z" is in the same place as Y for qwerty`, therefore it will have the same function as "Y" in qwerty. ReaKeyMce will take over most of your keyboard when active.`n-----------------------------------------------------------------`nPress the "SHIFT + DELETE keys" `non your computer keyboard to PAUSE program and allow you to type again.`n-----------------------------------------------------------------`n+ Right Click on LCD DISPLAY OR tray icon for Menu`, settings and Exit.`n+ RTFM`n`
			
			winX = "Center" ; will this work, seems to or did it alReady happen above? no it did not
			winY = 0
		}
	}

;*************************************************
;*          WRITE TO INI FILE FUNCTION 
;*************************************************

;CALLED TO UPDATE INI WHENEVER SAVED PARAMETERS CHANGE
WriteIni()
	{
		global MidiInDevice, MidiInDevice2, MidiOutDevice, winX, winY, version, fadermenu, vpotmenu, jogmenu
		
		IfNotExist, %version%.ini ; if no ini
			FileAppend,, %version%.ini ; make one with the following entries.
		IniWrite, %MidiInDevice%, %version%.ini, Settings, MidiInDevice
		IniWrite, %MidiOutDevice%, %version%.ini, Settings, MidiOutDevice
		IniWrite, %MidiInDevice2%, %version%.ini, Settings, MidiInDevice2 	; fader feedback
		IniWrite, %fadermenu%, %version%.ini, Settings, fadermenu			; fader speed default
		IniWrite, %vpotmenu%, %version%.ini, Settings, vpotmenu
		IniWrite, %jogmenu%, %version%.ini, Settings, jogmenu
		IniWrite, %winX%, %A_ScriptDir%\%version%.ini, GuiPosition, winX 	; window postion
		IniWrite, %winY%, %A_ScriptDir%\%version%.ini, GuiPosition, winY
	}

;*************************************************
;*                 PORT TESTING
;*************************************************

port_test(numports,numports2) ; confirm selected ports exist ; CLEAN THIS UP STILL 
	{
		global midiInDevice, midiOutDevice, midiInDevice2, midiok, version
		
		; ----- In port selection test based on numports
		If MidiInDevice2 not Between 0 and %numports% 
		{
			MidiIn := 0 ; this var is just to show if there is an error - set if the ports are valid = 1, invalid = 0
				;MsgBox, 0, , midi in port Error ; (this is left only for testing)
			If (MidiInDevice2 = "")              ; if there is no midi in device 
				MidiInerr = Feedback In (MCU out Port) EMPTY. ; set this var = error message
				;MsgBox, 0, , midi in port EMPTY
			If (midiInDevice2 > %numports%)          ; if greater than the number of ports on the system.
				MidiInnerr = Feedback In (MCU out Port) Invalid.  ; set this error message
				;MsgBox, 0, , midi in port out of range
		}
		Else
		{
			MidiIn := 1 ; setting var to non-error state or valid
		}
		; ----- out port selection test based on numports2
		If  MidiOutDevice not Between 0 and %numports2%
		{
			MidiOut := 0 ; set var to 0 as Error state.
			If (MidiOutDevice = "")                 ; if blank
				MidiOuterr = %version% Midi Output Port EMPTY.   ; set this error message
				;MsgBox, 0, , midi o port EMPTY
			If (midiOutDevice > %numports2%)             ; if greater than number of availble ports  
				MidiOuterr = %version% Midi Output Port Invalid.  ; set this error message   
				;MsgBox, 0, , midi out port out of range
		}
		Else
		{
			MidiOut := 1 ;set var to 1 as valid state.
		}
		  ; ---- test to see if ports valid, if either invalid load the gui to select.
		  ;midicheck(MCUin,MCUout)
		
		; =============== midi in feedback port
		/*
			If MidiInDevice2 not Between 0 and %numports3% 
			{
				MidiIn2 := 0 ; this var is just to show if there is an error - set if the ports are valid = 1, invalid = 0
				;MsgBox, 0, , midi in port Error ; (this is left only for testing)
				If (MidiInDevice2 = "")              ; if there is no midi in device 
					MidiInerr = Midi Feeback Port EMPTY. ; set this var = error message
				;MsgBox, 0, , midi in port EMPTY
				If (midiInDevice2 > %numports3%)          ; if greater than the number of ports on the system.
					MidiInnerr = Midi Feedback Port Invalid.  ; set this error message
				;MsgBox, 0, , midi in port out of range
				
			}
			Else
			{
				MidiIn2 := 1 ; setting var to non-error state or valid
			}
		*/
		If (%MidiIn% = 0) Or (%MidiOut% = 0) ;or (%midiIn2% = 0)
		{
			MsgBox, 49, %version% Midi Port Error!,%MidiInerr%`n%MidiOuterr%`n`nLaunch Midi Port Selection!
			IfMsgBox, Cancel
				ExitApp
			midiok = 0 ; Not sure if this is really needed now....
			Gosub, MidiSet ;Gui, show Midi Port Selection
		}
		Else
		{
			midiok = 1
			Return ; DO NOTHING - PERHAPS DO THE NOT TEST INSTEAD ABOVE.
		}
	}
Return

;------------------------------ speed called from context/tray menu labels---------------------

VpotSpeedSlow:
	RelUp   := 1
	RelDown := 65
	gosub, vpotMenuh
return

VpotSpeedMed:
	RelUp 	:= 6 ;(RelUp + 5)
	RelDown := 71 ;(RelDown + 5)
	gosub, vpotMenuh
return

VpotSpeedFast:
	RelUp 	:= 11 ;(RelUp + 10)
	RelDown := 75 ;(RelDown + 10)
	gosub, vpotMenuh
return

JogSpeedSlow:
	JogUpVal  	:= 1  		; UP VALUE TO Send WITH EACH KEY PRESS.
	JogDownVal  := 65 		; DOWN VALUE TO Send WITH EACH KEY PRESS.
	gosub, jogMenuh
return

JogSpeedMed:
	JogUpVal  	:= 5  		; UP VALUE TO Send WITH EACH KEY PRESS.
	JogDownVal  := 69 		; DOWN VALUE TO Send WITH EACH KEY PRESS.
	gosub, jogMenuh
return

JogSpeedFast:
	JogUpVal  	:= 11  		; UP VALUE TO Send WITH EACH KEY PRESS.
	JogDownVal  := 75 		; DOWN VALUE TO Send WITH EACH KEY PRESS.
	gosub, jogMenuh
Return

/*
	Need a way to change speed on the fly, like holding down shift to go fast or slow.. either one
	seems like fast is good most of the time.
	shift should be to slow down?
*/

FaderSpeedSlow:
	PBdelta = 64
	gosub, faderMenuh
return

FaderSpeedMedium:
	PBdelta = 128
	gosub, faderMenuh
return

FaderSpeedMediumFast:
	PBdelta = 256
	gosub, faderMenuh
return

FaderSpeedFast:
	PBdelta = 512
	gosub, faderMenuh
return

/* 
	MENUHANDLERS CHANGE CHECK MARKS
*/
jogMenuh:
	if jogmenu != A_ThisMenuItem ;&& jogmenu != "")
		Menu %A_ThisMenu%, unCheck, %jogmenu%
	Menu %A_ThisMenu%, Check, %A_ThisMenuItem%
	jogmenu := A_ThisMenuItem
	IniWrite, %jogrmenu%, %version%.ini, Settings, jogmenu			; fader speed chosen ini write
return

vpotMenuh:
	if vpotmenu != A_ThisMenuItem ;&& vpotmenu != "")
		Menu %A_ThisMenu%, unCheck, %vpotmenu%
	Menu %A_ThisMenu%, Check, %A_ThisMenuItem%
	vpotmenu := A_ThisMenuItem
	IniWrite, %vpotmenu%, %version%.ini, Settings, vpotmenu			
return

faderMenuh:
		;MsgBox, %fadermenu%
	if fadermenu != A_ThisMenuItem ;&& fadermenu != "")
		Menu, faderspeed, UnCheck, %fadermenu%
	Menu, faderspeed, Check, %A_ThisMenuItem%
	fadermenu := A_ThisMenuItem
			;tooltip, %pbdelta%
	IniWrite, %fadermenu%, %version%.ini, Settings, fadermenu
return

;---------------------------end speed labels

;*************************************************
;*      MIDI INPUT / OUTPUT UNDER THE HOOD
;*************************************************

;######## MIDI LIB from orbik and lazslo#############
;-------- orbiks midi input code --------------
; Set up midi input and callback_window based on the ini file above.
; This code copied from ahk forum Orbik's post on midi input

; =============== midi in =====================

;*************************************************
;*          midi input set 
;          both input ports - only using second port... not sure why I did not change this behavior.
;*************************************************
Midiin_go:

;Thanks to dorfl68 for multiple input ports!

;DeviceID1 := MidiInDevice      ; midiindevice from IniRead above assigned to deviceid
	DeviceID2 := MidiInDevice2  
	CALLBACK_WINDOW := 0x10000    ; from orbiks code for midi input

	Gui, +LastFound 	; set up the window for midi data to arrive.
	hWnd := WinExist()	;MsgBox, 32, , line 176 - mcu-input  is := %MidiInDevice% , 3 ; this is just a test to show midi device selection

	 ; first device
	 ;       h_MidiIn1 =VarSetCapacity(h_MidiIn1, 4, 0)
	  ;      result := DllCall("winmm.dll\midiInOpen", UInt,&h_MidiIn1, UInt,DeviceID1, UInt,hWnd, UInt,0, UInt,CALLBACK_WINDOW, "UInt")
	   ;        h_MidiIn1 := NumGet(h_MidiIn1) ; because midiInOpen writes the value in 32 bit binary Number, AHK stores it as a string
		;    result := DllCall("winmm.dll\midiInStart", UInt,h_MidiIn1)

	; second device
	h_MidiIn2 =VarSetCapacity(h_MidiIn2, 4, 0)
	result := DllCall("winmm.dll\midiInOpen", UInt,&h_MidiIn2, UInt,DeviceID2, UInt,hWnd, UInt,0, UInt,CALLBACK_WINDOW, "UInt")
	h_MidiIn2 := NumGet(h_MidiIn2) ; because midiInOpen writes the value in 32 bit binary Number, AHK stores it as a string
	result := DllCall("winmm.dll\midiInStart", UInt,h_MidiIn2)

	;inport1 = %h_midiin1% ; set var to be more legible to me
	inport_feedback = %h_midiin2% ; readability

	;MsgBox h_midiIn1:%h_midiin1%`ninport1:%inport1%`nh_midiin2:%h_midiin2%`ninport_feedback%inport_feedback%

	OpenCloseMidiAPI()

	  ; ----- the OnMessage listeners ----

		  ; #define MM_MIM_OPEN 0x3C1 /* MIDI input */
		  ; #define MM_MIM_CLOSE 0x3C2
		  ; #define MM_MIM_DATA 0x3C3
		  ; #define MM_MIM_LONGDATA 0x3C4
		  ; #define MM_MIM_ERROR 0x3C5
		  ; #define MM_MIM_LONGERROR 0x3C6

	;Jim - I believe here is my problem. These ONMessages my be causeing my fader pb vars to get weird and in the midimsgdetect below.

	;*************************************************
	;*          MIDI_INPUT ONMESSAGE DETECTOR
	; Jim I only need the midi for the pb value to come back.
	;*************************************************
	OnMessage(0x3C1, "MidiMsgDetect")  ; calling the function MidiMsgDetect in get_midi_in.ahk
	OnMessage(0x3C2, "MidiMsgDetect")  
	OnMessage(0x3C3, "MidiMsgDetect")
		;OnMessage(0x3C4, "MidiMsgDetect") ; for sysex coming soon to theater near you.
	OnMessage(0x3C5, "MidiMsgDetect")
		;OnMessage(0x3C6, "MidiMsgDetect")

Return

;*************************************************
;* 			MIDI INPUT DETECT AND PARSE
;*************************************************

MidiMsgDetect(hInput2, midiMsg, wMsg) ; See http://www.midi.org/techspecs/midimessages.php (decimal values).
	{
			;global Statusbyte, StatusbyteIn, chan, chanIn,  note, cc, byte1, byte1In, byte2, byte2In , stb, vpots_active, faders_active, mfms_active, inport1, inport_feedback, sync
		
		Statusbyte 	:=  midiMsg & 0xFF			; EXTRACT THE Status BYTE (WHAT KIND OF MIDI MESSAGE IS IT?)
		chan 		:= (Statusbyte & 0x0f) + 1	; WHAT MIDI CHANNEL IS THE MESSAGE ON?
		byte1 		:= (midiMsg >> 8) & 0xFF	; THIS IS DATA1 VALUE = NOTE Number OR CC Number
		byte2 		:= (midiMsg >> 16) & 0xFF	; DATA2 VALUE IS NOTE VELEOCITY OR CC VALUE
		pitchb		:= (byte2 << 7) | byte1   	;(midiMsg >> 8) & 0x7F7F  masking to extract the pbs
		
			;*************************************************
			;* 			This is the feedback port from DAW set fader vars to values sent by REAPER
			;*************************************************
		
		IfEqual, statusbyte, 224 	; fader listen track 1 statusbyte 223 is for pitchbend + chan 1 = 224
			fader1(pitchb)			; functions are located just below this function		
		IfEqual, statusbyte, 225 	; fader listen 2
			fader2(pitchb)
		IfEqual, statusbyte, 226 	; fader listen track 3
			fader3(pitchb)	
		IfEqual, statusbyte, 227 	; fader listen 4
			fader4(pitchb)
		IfEqual, statusbyte, 228 	; fader listen track 5
			fader5(pitchb)	
		IfEqual, statusbyte, 229 	; fader listen 6
			fader6(pitchb)
		IfEqual, statusbyte, 230 	; fader listen track 7
			fader7(pitchb)	
		IfEqual, statusbyte, 231 	; fader listen 8
		{
			fader8(pitchb)
						;tooltip , %pitchb%
						;if (%pitchb% != 0) or (%pitchb% != ) ; old something I was kicking around, not used
						;sync = L8
		}   
		
		IfEqual, statusbyte, 232 	; fader listen master chan 9
		{
			fader9(pitchb)	
						;if (%pitchb% != 0) or (%pitchb% != )
						;sync = L9
		}	
		
				; test for status byte 231 or fader #8
		If statusbyte > 232 ;between 224 and 232 ; if above master track do nothing. 
		{
			
							;sync = L ; set var to lock to send in the pbsend label
							;settimer, pbsend, -300 ; adjust this for response time.	
			
		}
		
	}

; Jim - Not sure if I should return the values to the pb now or do it somewhere, somehow else.

;Return ; end of MidiMsgDetect funciton

;*************************************************
;* 	FADER FUNCTIONS ASSIGNING PBx VARS 
;*************************************************

	fader1(pitchb) ; functions to assign initial pitchbend values
		{	global
			PB1 = %pitchb%
					;tooltip , %PB1% ; just using this for texting
					;msgbox %pb1%
		}
	fader2(pitchb)
		{	global
			PB2 = %pitchb%
		}
	fader3(pitchb) ; functions to assign initial pitchbend values
		{	global
			PB3 = %pitchb%
		}
	fader4(pitchb)
		{	global
			PB4 = %pitchb%
		}
	fader5(pitchb) ; functions to assign initial pitchbend values
		{	global
		PB5 = %pitchb%
		}
	fader6(pitchb)
		{	global
		PB6 = %pitchb%
		}
	fader7(pitchb) ; functions to assign initial pitchbend values
		{	global
		PB7 = %pitchb%
		}
	fader8(pitchb)
		{	global
		PB8 = %pitchb%
				;gosub, showfaderlocks
		}
	fader9(pitchb) ; master fader
		{	global
		PB9 = %pitchb%
				;msgbox %pb9%
		}
;return

; faders_run see settimer at top

;Jim - here is suspect to me... the +pbdelta may be arguing with the onmessage assignment somehow.

Faders_Run: ; FADER ROUTINES

	; Seems like these should be arrays, I just don't know how to write thme.

	; ------------- FADER 1 ------

if F_pbend = U ; if the var has this value from the hoteky then move the fader up
		;loop
{
	pb1 := pb1+pbdelta <16384 ? pb1+pbdelta : 16384
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(1+0xDF)|(pb1&0x7F)<<8|(pb1>>7)<<16)
}
		;until F_Pbend != U
	;return
if F_pbend = D ; if the var has this value from the Hotkey then move fader down.
		;loop
{
	pb1 := pb1-pbdelta > 0 ? pb1-pbdelta : 0
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(1+0xDF)|(pb1&0x7F)<<8|(pb1>>7)<<16)
			;MsgBox fader 1 down message
}
		;until F_pbend != D
	;return
If F_pbend = 0db ; sets master to 0db
{
	pb1 = %zerodb% ;12400, reaper, 12800 cube, 13926 live ver 6 ; this value sets fader to 0dB
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(1+0xDF)|(pb1&0x7F)<<8|(pb1>>7)<<16)
}
		;return
if F_PBend =  ; if var has no value of is 0 then do nothing.
{
}
	;----------------- END FADER 1 ---------------
	; ------------- FADER 2 ------

If F_PBend2 = U
{
	PB2 := PB2+PBdelta <16384 ? PB2+PBdelta : 16384
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(2+0xDF)|(PB2&0x7F)<<8|(PB2>>7)<<16)
}

If F_PBend2 = D ; First one down
{
	PB2 := PB2-PBdelta > 0 ? PB2-PBdelta : 0
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(2+0xDF)|(PB2&0x7F)<<8|(PB2>>7)<<16)
}
If F_PBend2 = 0db ; sets master to 0db
{
	PB2 = %zerodb% ;12400 ; this value sets fader to 0dB
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(2+0xDF)|(PB2&0x7F)<<8|(PB2>>7)<<16)
}
If F_PBend2 = 0
{
}
	;----------------- END FADER 2 ---------------

	; ------------- FADER 3 ------

If F_PBend3 = U
{
	PB3 := PB3+PBdelta <16384 ? PB3+PBdelta : 16384
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(3+0xDF)|(PB3&0x7F)<<8|(PB3>>7)<<16)
}

If F_PBend3 = D
{
	PB3 := PB3-PBdelta > 0 ? PB3-PBdelta : 0
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(3+0xDF)|(PB3&0x7F)<<8|(PB3>>7)<<16)
}
If F_PBend3 = 0db ; sets master to 0db
{
	PB3 = %zerodb% ;12400 ; this value sets fader to 0dB
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(3+0xDF)|(PB3&0x7F)<<8|(PB3>>7)<<16)
}
If F_PBend3 = 0
{
}
	;----------------- END FADER 3 ---------------
	; ------------- FADER 4 ------

If F_PBend4 = U
{
	PB4 := PB4+PBdelta <16384 ? PB4+PBdelta : 16384
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(4+0xDF)|(PB4&0x7F)<<8|(PB4>>7)<<16)
}

If F_PBend4 = D
{
	PB4 := PB4-PBdelta > 0 ? PB4-PBdelta : 0
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(4+0xDF)|(PB4&0x7F)<<8|(PB4>>7)<<16)
}
If F_PBend4 = 0db ; sets master to 0db
{
	PB4 = %zerodb% ;12400 ; this value sets fader to 0dB
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(4+0xDF)|(PB4&0x7F)<<8|(PB4>>7)<<16)
}
If F_PBend4 = 0
{
}
	;----------------- END FADER 4 ---------------
	; ------------- FADER 5 ------

If F_PBend5 = U
{
	PB5 := PB5+PBdelta <16384 ? PB5+PBdelta : 16384
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(5+0xDF)|(PB5&0x7F)<<8|(PB5>>7)<<16)
}

If F_PBend5 = D
{
	PB5 := PB5-PBdelta > 0 ? PB5-PBdelta : 0
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(5+0xDF)|(PB5&0x7F)<<8|(PB5>>7)<<16)
}
If F_PBend5 = 0db ; sets master to 0db
{
	PB5 = %zerodb% ;12400 ; this value sets fader to 0dB
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(5+0xDF)|(PB5&0x7F)<<8|(PB5>>7)<<16)
}
If F_PBend5 = 0
{
}
	;----------------- END FADER 5 ---------------
	; ------------- FADER 6 ------

If F_PBend6 = U
{
	PB6 := PB6+PBdelta <16384 ? PB6+PBdelta : 16384
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(6+0xDF)|(PB6&0x7F)<<8|(PB6>>7)<<16)
}

If F_PBend6 = D
{
	PB6 := PB6-PBdelta > 0 ? PB6-PBdelta : 0
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(6+0xDF)|(PB6&0x7F)<<8|(PB6>>7)<<16)
}
If F_PBend6 = 0db ; sets master to 0db
{
	PB6 = %zerodb% ;12400 ; this value sets fader to 0dB
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(6+0xDF)|(PB6&0x7F)<<8|(PB6>>7)<<16)
}
If F_PBend6 = 0
{
}
	;----------------- END FADER 6 ---------------
	; ------------- FADER 7 ------

If F_PBend7 = U
{
	PB7 := PB7+PBdelta <16384 ? PB7+PBdelta : 16384
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(7+0xDF)|(PB7&0x7F)<<8|(PB7>>7)<<16)
}

If F_PBend7 = D
{
	PB7 := PB7-PBdelta > 0 ? PB7-PBdelta : 0
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(7+0xDF)|(PB7&0x7F)<<8|(PB7>>7)<<16)
}
If F_PBend7 = 0db ; sets master to 0db
{
	PB7 = %zerodb% ;12400 ; this value sets fader to 0dB
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(7+0xDF)|(PB7&0x7F)<<8|(PB7>>7)<<16)
}
If F_PBend7 = 0
{
}
	;----------------- END FADER 7 ---------------
	; ------------- FADER 8 ------

If F_PBend8 = U ; First one up
{
	PB8 := PB8+PBdelta <16384 ? PB8+PBdelta : 16384
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(8+0xDF)|(PB8&0x7F)<<8|(PB8>>7)<<16)
}

If F_PBend8 = D ; First one down
{
	PB8 := PB8-PBdelta > 0 ? PB8-PBdelta : 0
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(8+0xDF)|(PB8&0x7F)<<8|(PB8>>7)<<16)
}
If F_PBend8 = 0db ; sets master to 0db
{
	PB8 = %zerodb% ;12400 ; this value sets fader to 0dB
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(8+0xDF)|(PB8&0x7F)<<8|(PB8>>7)<<16)
}
If F_PBend8 = 0
{
}
	;----------------- END FADER 8 ---------------

	;------------- Master FADER 9 ------

If F_PBend9 = U ; master up
{
	PB9 := PB9+PBdelta <16384 ? PB9+PBdelta : 16384
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(9+0xDF)|(PB9&0x7F)<<8|(PB9>>7)<<16)
}

If F_PBend9 = D ; master down
{
	PB9 := PB9-PBdelta > 0 ? PB9-PBdelta : 0
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(9+0xDF)|(PB9&0x7F)<<8|(PB9>>7)<<16)
}
If F_PBend9 = M ; mute the track
{
	PB9 := 0
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(9+0xDF)|(PB9&0x7F)<<8|(PB9>>7)<<16)
}
If F_PBend9 = 0db ; sets master to 0db
{
	PB9 = %zerodb% ; 12800 cube ;12400 reaper ; this value sets fader to 0dB
	DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt,(9+0xDF)|(PB9&0x7F)<<8|(PB9>>7)<<16)
}
If F_PBend9 = 0
{
}
	;----------------- END FADER 9 ---------------

Return ; end of all faders

/*
	Faders currently very bumpy...
	
	So think about hotkey repeats
	keywait until up received.
	
	
*/

;/*  uncomment when something is smooth

;FADER 1 TRIGGER ; this one is just an experiememt 
SC01e::
{
	F_PBend = U 			; Pitch bend Up
	Keywait, SC01e
	F_PBend =
	;Hotkey, SC01e, on
}
return		


;SC01e UP::F_PBend = 		; Pitch Bend Off
esc & SC01e::F_PBend = 0db 	; set fader to 0db
SC02c::
{
	F_PBend = D			; Pitch bend down
	keywait, sc02c
	F_PBend = 
}
return	
SC02c UP::F_PBend =
;*/

;FADER 2 TRIGGER
SC01f::F_PBend2 = U 		; Pitch bend Up
SC01f UP::F_PBend2 = 		; Pitch Bend Off
esc & SC01f::F_PBend2 = 0db ; set fader to 0db
SC02d::F_PBend2 = D			; Pitch bend down
SC02d UP::F_PBend2 =

;FADER 3 TRIGGER
SC020::F_PBend3 = U ; Pitch bend Up
SC020 UP::F_PBend3 = ;Pitch Bend Off
esc & SC020::F_PBend3 = 0db ; set fader to 0db
SC02e::F_PBend3 = D	; Pitch bend down
SC02e UP::F_PBend3 =

;FADER 4 TRIGGER
SC021::F_Pbend4 = U ; Pitch bend Up
SC021 UP::F_PBend4 = ;Pitch Bend Off
esc & SC021::F_PBend4 = 0db ; set fader to 0db
SC02f::F_PBend4 = D	; Pitch bend down
SC02f UP::F_PBend4 =

;FADER 5 TRIGGER
SC022::F_PBend5 = U ; Pitch bend Up
SC022 UP::F_PBend5 = ;Pitch Bend Off
esc & SC022::F_PBend5 = 0db ; set fader to 0db
SC030::F_PBend5 = D	; Pitch bend down
SC030 UP::F_PBend5 =

;FADER 6 TRIGGER
SC023::F_PBend6 = U ; Pitch bend Up
SC023 UP::F_PBend6 = ;Pitch Bend Off
esc & SC023::F_PBend6 = 0db ; set fader to 0db
SC031::F_PBend6 = D	; Pitch bend down
SC031 UP::F_PBend6 =

;FADER 7 TRIGGER
SC024::F_PBend7 = U ; Pitch bend Up
SC024 UP::F_PBend7 = ;Pitch Bend Off
esc & SC024::F_PBend7 = 0db ; set fader to 0db
SC032::F_PBend7 = D	; Pitch bend down
SC032 UP::F_PBend7 =

;FADER 8 TRIGGER
SC025::F_PBend8 = U ; Pitch bend Up
SC025 UP::F_PBend8 = ;Pitch Bend Off
esc & SC025::F_PBend8 = 0db ; set fader to 0db
SC033::F_PBend8 = D	; Pitch bend down NOT SURE WHY THIS KEY NEEDS THE *
SC033 UP::F_PBend8 =

;FADER MASTER TRIGGER

esc & UP::F_PBend9 = U 		; Pitch bend Up ; used to be up arrow
esc & up UP:: F_PBend9 = 	; Pitch Bend Off ; up
esc & down::F_PBend9 = D	; Pitch bend down ; down arrow
esc & down UP:: F_PBend9 =  ; down arrow.

esc & left::F_PBend9 = m 	; Pitch bend Up
esc & left UP::F_PBend9 = 	; Pitch Bend Off
esc & Right::F_PBend9 = 0db	; Pitch bend down
esc & Right UP::F_PBend9 =


Vpots_Run: ; vpot routine

loop
{
	   ; ------------- VPOT 1-8 ------
	If Vpot%A_Index% = U ; First one left
	{
		midiOutShortMsg(h_midiout, 176, A_Index+15, RelUp) ; vpots left or down amount
	}
	If Vpot%A_Index% = D ; First one Right
	{
		midiOutShortMsg(h_midiout, 176, A_Index+15, RelDown) ; vpots right or up value
	}
	If Vpot%A_Index% = 0
	{
	}
	If A_Index =9
		Break
}
   ;------------ END VPOT 1-8
Return ; end of vpot_Runs

;*********** VPOT TRIGGERS *******
;VPOT 1 TRIGGER 1,q
SC002::Vpot1 = U ; VPOT CC 16 RELUp
SC002 UP::Vpot1 = ;DO NOTHING LET GO
SC010::Vpot1 = D	; VPOT CC 16 RELdown
SC010 UP::Vpot1 =

;VPOT 2 TRIGGER 2,w
SC003::Vpot2 = U ; VPOT CC 17 RELUp
SC003 UP::Vpot2 = ;Off
SC011::Vpot2 = D	; VPOT CC 17 RELown
SC011 UP::Vpot2 =

;VPOT 3 TRIGGER 3,e
SC004::Vpot3 = U ;18
SC004 UP::Vpot3 = ;Off
SC012::Vpot3 = D	; 18
SC012 UP::Vpot3 =

;VPOT 4 TRIGGER 4,r
SC005::Vpot4 = U ; 19 ETC....
SC005 UP::Vpot4 =
SC013::Vpot4 = D
SC013 UP::Vpot4 =

;VPOT 5 TRIGGER 5,t
5::Vpot5 = U ;SC006
5 UP::Vpot5 = ;SC006
t::Vpot5 = D ;SC014
t UP::Vpot5 =

;VPOT 6 TRIGGER 6,y
SC007::Vpot6 = U
SC007 UP::Vpot6 =
SC015::Vpot6 = D
SC015 UP::Vpot6 =

;VPOT 7 TRIGGER 7, u
SC008::Vpot7 = U
SC008 UP::Vpot7 =
SC016::Vpot7 = D
SC016 UP::Vpot7 =

;VPOT 8 TRIGGER 8, i
SC009::Vpot8 = U
SC009 UP::Vpot8 =
SC017::Vpot8 = D
SC017 UP::Vpot8 =


;*************************************************
;* 	JOG WHEEL FROM KEYPRESS+MOUSEWEEL MAYBE MOVE 
;*************************************************

;Map Jog Wheel to keyboard, midi chan 1, cc#60

; MOUSE WHEEL WORKS WITH CONTROL AS MODIFIER TO SEND JOG


LControl & WheelUp::
	midiOutShortMsg(h_midiout, 176, 60, JogUpVal ) ; JOG UP VALUE 60 is cc# ; JOG WHEEL
	stbout   = JogUP 		; IS THIS USED?
	Gosub, ShowMidiOutMessage
return	

LControl & WheelDown::
	midiOutShortMsg(h_midiout, 176, 60, JogDownVal ) ; vpot 1 up value 60 is cc# ; JOG LEFT
	stbout   = Jogdn
	Gosub, ShowMidiOutMessage
Return

/* 
	Strip out code for other DAWs - reaper klinke specific files
	Do not worry about other key layouts
	
	scan codes do not work for left/right win ctrl alt shift
	
	HOW TO USE KEYS AS WELL AS MIDI INPUT FOR MFMS
	
	HOW TO ENABLE HOTKEYS BASED ON INI FILE.
	IF ACTIVE - TURN OFF THE MFM KEYS.
		
*/
/*
	option key - set in reaper from keyboard - do not map right alt key.
	need to find global reset
	
	
	F1 - F8
	1 PRESS RESULTS IN MUTE
	DOUBLE PRESS = SOLO
	TRIPLE PRESS = ARM
	
	esc + F1 - F8 Keys - 
	folder diving	SINGLE PRESS = CH SELECT hold
	*back space - reverse dive  
	
	DOUBLE = VPOT SELECT
	
	REASSIGN THIS ONE
	f9	- flip/return
	F10	- 
	f11 - plugin
	f12 - vpot pan / double sends
	
	
	MUCH TODO HERE - 
	
	- fader speed? jumpy
	
	1. solo disable
	2. loop toggle
	3. metro toggle
	Midi wise mcu protocol
	
	keystroke sends to reaper - to trigger actions.
	- toggle metro
	- metro volume
	- solo
	
*/

;*************************************************
;*    COUNTPRESSES FUNCTION + TIMER (KEYS)
;*************************************************

CountPresses(param1, param2, param3) ; GENERAL FUNCTION FOR 3 COUNT PRESSES
{
	global
	pressed1 := param1, pressed2 := param2, pressed3 := param3
	PressCount += 1
	if(PressCount > 3)
	{
		PressCount := 3
	}
	SetTimer WaitKeyPress, 250 ; Restart waiting for more presses
}

WaitKeyPress:
SetTimer WaitKeyPress, off ; Run timer only once
If (PressCount >= 1 and PressCount <= 3)
{
	Gosub % PressCount < 3 ? pressed%PressCount% : pressed3
}
PressCount := 0
Return

;*************************************************
;*          MODIFIER HOTKEY ROUTINES
;*************************************************

;************ THINK ABOUT THIS SECTION TO CHANGE

BackSpace:: ; global view - back out of drill down folders
	midiOutShortMsg(h_midiout, 144 , 51, 127)
		; need to unmap backspace from split item at cursor before letting the below happen.  
		;send, +backspace ; map shift backspace to toggle action or write action to show collapse children
return 

;********** Modifier keys ************ THESE NEED REVISION

; I THINK THESE ARE THE SAME MODIFIER KEYS FOR ALL DAWS.

RShift:: ; right shift
	note = %shift%
	midiOutShortMsg(h_midiout, 144 , note, 127) ; 70?
	Modi := "Shift"
	gosub, ShowUpdategui
		;guicontrol,6:, Modi, %Mod%
	KeyWait, RShift
	midiOutShortMsg(h_midiout, 144, note, 0) ; "n0" = "NOTE OFF "Control key    ;**************** 128 or 144 ????????
	Modi := ""
	gosub, ShowUpdategui
			;guicontrol,6:, Modi, %Mod%
return

;/*
RAlt:: ; right alt
	note = %alt%
	midiOutShortMsg(h_midiout, 144 , note, 127)
	Modi := "Alt"
	gosub, ShowUpdategui
			;guicontrol,6:, Modi, %Mod%
	KeyWait, RAlt   ;keyWait, Rshift
	midiOutShortMsg(h_midiout, 144,note, 0) ; "n0" = "NOTE OFF "Control key
	Modi := ""
	gosub, ShowUpdategui
		;guicontrol,6:, Modi, %Mod%
return
;*/

;/* yes used in REAPER

SC035:: ; / key Option
	Note = %option%
	midiOutShortMsg(h_midiout, 144 , note, 127)
	Modi := "Opt"
	gosub, ShowUpdategui
		;guicontrol,6:, Modi, %Mod%
	KeyWait, SC035
	midiOutShortMsg(h_midiout, 144, note, 0) ; "n0" = "NOTE OFF "Control key
	Modi := ""
	gosub, ShowUpdategui
		;guicontrol,6:, Modi, %Mod%
return
;*/    
RCtrl:: ; right ctrl
		;MsgBox right control
	Note = %control% ; 72
	midiOutShortMsg(h_midiout, 144 , note, 127)
	Modi := "Ctrl"
		;gosub, ShowUpdategui
		;guicontrol,6:, Modi, %Mod%
	gosub, ShowUpdategui
	KeyWait, RCtrl
	midiOutShortMsg(h_midiout, 144, note, 0) ; "n0" = "NOTE OFF "Control key
	Modi := ""

	gosub, ShowUpdategui
		;guicontrol,6:, Modi, %Mod%
return

;*************************************************
;*          VPOT MODE SWITCHING - NEEDS REVISION
;		CONSIDER MOVING THESE CHOICES FROM HOTKEYS TO BUTTONS ON THE GUI
;	HOW ABOUT A BUTTON PUSH ON THE PANS TO CHANGE THEM USING MOUSE OR HOTKEY, EITHER ONE SHOULD DO IT... RIGHT?
;*************************************************




/* 
	NEED TO CONSIDER THIS FOR MIDI INPUT AS WELL AS KEY TRIGGER
	THE PANS SENDS ARE LOCATED IN IN MIDI PROCESSING.AHK
*/
  ; *************NEEDS REASSIGNING FROM DUE TO CONFLICT WITH LIVE HOTKEY revising for klinkle's reaper plugin

; RECORD ON IN LIVE

;******* change this countpresses last label to plugin for reaper

;/*
F11:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE ONLY UNTIL FIXED
 ; {
 ;   CountPresses("Plugin","eq","null") ; Countpresses function, top of this file.
  ;  Note_Num :=1 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
  ;}
;Plugin:
	Note =  %plugins% ;Live note Number43 ;

	midiOutShortMsg(h_midiout, 144 , note , 127)
	vpotmode = plugD ;Modi := "Shift"
	gosub, ShowUpdategui
			;guicontrol,6:, Modi, %Mod%
	KeyWait, f11
	midiOutShortMsg(h_midiout, 144, note, 0) ; "n0" = "NOTE OFF "Control key
	vpotmode = plugU
	gosub, ShowUpdategui
		;guicontrol,6:, Modi, %Mod%
	/*
		if toggle != 
		 {
			midiOutShortMsg(h_midiout, 128 , note, 0)
			toggle = 
			VPotMode = Plug0 ; SET VAR Label BASED ON DAW
			
			gosub, ShowUpdategui
			return
	  ;GuiControl,6:, Pot, %VpotMode%
		} 
		if toggle = 
		{
			midiOutShortMsg(h_midiout, 144 , note, 127)
			toggle = 1
		  ;GuiControl,6:, Pot, %VpotMode%
		}  
		
		VPotMode = Plug1 ; SET VAR Label BASED ON DAW
		
		gosub, ShowUpdategui
	*/ ;GuiControl,6:, Pot, %VpotMode%
Return

; need something to tell if eq is active or not.
; test for which programs use this.

/* 
	NEEDS REVISION IN REAkEY
*/

f10:: ; EQ: ; only seems to be used in cubase.
		;	if (section = "Live")
		;		{
		;			;do nothing
		;		}
		;	else
{
	Note =  %eq% ;Live note Number43 ; reaper et al 44
	VPotMode = EQ ; SET VAR Label BASED ON DAW
	gosub, ShowUpdategui
	midiOutShortMsg(h_midiout, 144 , note, 127)
	keywait, f10 ; for future use with reaper
			;midiOutShortMsg(h_midiout, 144 , note, 0)
			;VPotMode =  ; SET VAR Label BASED ON DAW
			;gosub, ShowUpdategui
			;GuiControl,6:, Pot, %VpotMode%
}
Return

; this is also done from midi button if needed.
LCtrl & F11:: ;  Left control + name/view  used with klinkle
	midiOutShortMsg(h_midiout, 144 , 52, 127)
return 

F12:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE ONLY UNTIL FIXED
{
	CountPresses("Pan","send","null") ; Countpresses function, top of this file.
	Note_Num :=1 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
}
Return

;*************************************************
;* VPOT MODE LABELS FROM MIDI TRIGS or KEY Trigs
;*************************************************

/*
	CHECK IN BUTTONS FILE FOR EQ AND PLUGIN
	
	????????????????
	are these needed or should we replace them with the ones in the gui24 
	have them call here instead, since these are already here????????????
	?????????????????
	
	
*/

Pan:        	; mute function forSend hotkey for original function
	byte1  = %pans% ;42  ; %pans%var defined in SelectDaw function at line 10 (this file) ;; NOTE FOR LIVE,
	byte2  = 127
				;SendNote(h_midiout,Note)
	VPotMode  = Pans ; ALL WILL HAVE PAN AS Label
				;GuiControl,6:, Pot, %VpotMode%   BRING THIS BACK WHEN A GUI IS CREATED
	Gosub, ShowUpdateGui
	midiOutShortMsg(h_midiout, 144, byte1, 127)
				;Gosub, ShowMidiOutMessage
				;MsgBox, 0,  ,vpotmode = %vpotmode% Pan = %pans% Label routine reached, .75
Return

Send:
	byte1 = %Sends% ;41
			;byte2 = 127
			;msgbox %sends%

			;SendNote(h_midiout,Note)
	VPotMode = Sends ; SET VAR Label BASED ON DAW
			;GuiControl,6:, Pot, %VpotMode%
	Gosub, ShowUpdateGui
	midiOutShortMsg(h_midiout, 144, byte1, 127)
		;Gosub, ShowMidiOutMessage
		;MsgBox, 0,  ,vpotmode = %vpotmode% Send Label routine reached, .75
Return

null:  ; do nothing from this - null is called several from countpress()when button or note only has 2 stacked
Return

/* 
	MOVE THESE PANS/SENDS CONTROLS TO THE CONTEXT MENU
	
	PUT KLINKE MACKIE SETINGS FOR 
	- FOLDER TRACKS
	- WHICH SET IS SHOWN, TCP MIXER OR MACKIE
	- CONTROLS TO BRING UP THE KLINKE MACKIE SETTINGS AS WELL.
*/


;*/
/* klinkle's newest with plugin stuff. cool but unwieldy 
	F12:: ; set pans active
	Note  = 42  ; %pans%var defined in SelectDaw function at line 10 (this file) ;; NOTE FOR LIVE,  
	midiOutShortMsg(h_midiout, 144 , note, byte2)
	VPotMode = Pans ; ALL WILL HAVE PAN AS Label
	GuiControl,6:, Pot, %VpotMode%
	KeyWait, F12
	midiOutShortMsg(h_midiout, 128, 42, 0) ; "n0" = "NOTE OFF "Control key
	
	Return
	-:: ; set sends active
	Note = 41 ;%Sends%
	midiOutShortMsg(h_midiout, 144 , note, byte2)
	VPotMode = Sends ; SET VAR Label BASED ON DAW
	GuiControl,6:, Pot, %VpotMode%
	Return
	=:: ;set plugins active
	Note =  43 ; %plugins% Live note Number
	midiOutShortMsg(h_midiout, 144 , note, byte2)
	VPotMode = PlugIns ; SET VAR Label BASED ON DAW
	GuiControl,6:, Pot, %VpotMode%
	Return
*/

;*************************************************
;*          RETURNS SWITCH ROUTINE LIVE ONLY
;*************************************************
; 88888 for Live change this second label below in countpresses to Returns

F9:: ; Returns/Flip
{
	CountPresses("Flip","returns","null") ; use $ with a KEY0 Label, or #UseHook
    ;Note_Num :=1 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
}
Return


Returns:   ; TURNS RETURN TRACK CONTROLS - ONLY USEFUL IN LIVE - ON/OFF
  ;msgbox %return_s%
	if (Section = "Live") or (Section = "REAPER")
	{
		byte1 =  %Return_s% ; Live note Number
		
		midiOutShortMsg(h_midiout, 144 , byte1, 127)
		ReturnOn := ReturnON + 1 ; VAR TO Enable WRAP ARound ON KEY FUNCTION increment up 1 value
		IfGreater, ReturnON, 2
		{
			ReturnOn := 1
		}
		  ;Gosub, ReturnGui ; Run THE FUNCT, BELOW
	}
	If section ! = Live
	{
			; do nothing
	}	
Return 			; END OF Hotkey

; SET THE GUI R - IS ALL THIS DOES
	;*********** how to turn off the gui when not in Live.
/*{
	
	ReturnGui:	; R GUI ON/OFF - TO SHOW RETURNS ON OR OFF
	
	If (ReturnON = 1)
		Returns := "R" ; set Gui to show the Letter R
	Else
		Returns := "" ; set to show nothing
	gosub, ShowUpdategui
	;GuiControl,6:, Flip, %returns%
}
*/
;Return 

Flip: ; flip faders for vpots

	midiOutShortMsg(h_midiout, 144 , 50, 127)
			;  FlipOn := FlipON + 1 ; VAR TO Enable WRAP ARound ON KEY FUNCTION increment up 1 value
			;  IfGreater, FlipON, 2
	FlipOn := 1
			;MsgBox, 32, , just before flipgui (keep for testing), 1
			;FlipGui(FlipON) ; Run THE FUNCT, BELOW
			;MsgBox, 0, , just after flipgui
			;GuiControl,, Flip, %Flip%
			;MsgBox, 0, , just after setnormalgui

Return ; END OF FUNCTION

; SET THE GUI R - IS ALL THIS DOES
/* Not needed with display
	FlipGui(FlipOn)	; Flip GUI ON/OFF - TO SHOW fliped ON OR OFF
	{    
		global flip, returns
		If (FlipON = 1)
		{
			Flip := "F" ; set Gui to show the Letter R 
      ;MsgBox, 0, , set value to F
			
		}
		Else
		{
			Flip := "" ; set to show nothing
        ;GuiControl,, Flip, %Flip%
		}
  ;MsgBox, 0, , %flip%
		gosub, returngui ;ShowUpdategui
;GuiControl,6:, Flip, %Flip%
	}	
*/

Return

;*************************************************
;*          MFM - MUTE KEY TRIGGERS
;*************************************************
; leaving this in for multiple possiblities for triggers.  hotkeys or midi presses
; -----------MULTIFUNCTION MUTES TRACK SELECTION 1-8  -----------------

F1:: ; MULTIFUNCTION MUTE 1 MULTI PRESSES 1 = MUTE SEE BELOW
{
	CountPresses("Mute","Solo","Arm") ; use $ with a KEY0 Label, or #UseHook
	Note_Num :=1 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	key = f1
}
Return
F2:: ; MULTIFUNCTION MUTE 2
{
	CountPresses("Mute","Solo","Arm") ; use $ with a KEY0 Label, or #UseHook
	Note_Num :=2
	key = f2
}
Return
F3:: ; MULTIFUNCTION MUTE 3
{
	CountPresses("Mute","Solo","Arm") ; use $ with a KEY0 Label, or #UseHook
	Note_Num :=3
	key = f3
}
Return
F4::
{
	CountPresses("Mute","Solo","Arm") ; use $ with a KEY0 Label, or #UseHook
	Note_Num :=4
	key = f4
}
Return
F5::
{
	CountPresses("Mute","Solo","Arm") ; use $ with a KEY0 Label, or #UseHook
	Note_Num :=5
	key = f5
}
Return
F6::
{
	CountPresses("Mute","Solo","Arm") ; use $ with a KEY0 Label, or #UseHook
	Note_Num :=6
	key = f6
}
Return
F7::
{
	CountPresses("Mute","Solo","Arm") ; use $ with a KEY0 Label, or #UseHook
	Note_Num :=7
	key = f7
}
Return
F8::
{
	CountPresses("Mute","Solo","Arm") ; use $ with a KEY0 Label, or #UseHook
	Note_Num :=8
	key = f8
}
Return

;*************************************************
;* 			MFM MODE CHANGE LABELS
;*  this is called from countpresses or countpresses_midi
;*************************************************

; MADE SO THAT MULTIPLE ARMS CAN BE SELECTED AND MULTIPLE SOLOS WITH OUT PRESSING MODIFIER KEYS
; WHICH FUNCITON TO RUN BASED ON HOW MANY TIMES THE KEY WAS PRESSED
Mute:        	; mute function forSend hotkey for original function
	mutemode = mute
	MFMutes(mutemode,key)		; CALCULATE NOTE Number SO Send BASED ON FUNCTION, MFMutes, just below this Section
Return
Solo:
	mutemode = solo			; SET MUTEMODE TO SOLO
			;midiOutShortMsg(h_midiout, 144, 72, 127) ; "N1" = "NoteOn"  Control key    ONLY FOR REAPER DISABLED.
	MFMutes(mutemode,key)
			;midiOutShortMsg(h_midiout, 144, 72, 0) ; "n0" = "NOTE OFF "Control key     ONLY FOR REAPER DISABLED.
	mutemode = mute			; set mode back to mute
Return
Arm:
	mutemode = arm
			;midiOutShortMsg(h_midiout, 144, 72, 127) ; "N1" = "NoteOn"  Control key ONLY FOR REAPER DISABLED.
	MFMutes(mutemode,key)
			;midiOutShortMsg(h_midiout, 144, 72, 0) ; "n0" = "NOTE OFF "Control key ONLY FOR REAPER DISABLED.
	mutemode = mute ; changing back to mute mode
Return

;*************************************************
;* 				MFM FUNCTION
;*************************************************

MFMutes(mutemode, key) ; Function to send out the correct note from above based on mode MULTI MUTES
{
	global note_num, h_midiout, h_midiout2, byte1, byte2, Statusbyteout, byte1out, byte2out, stbout ;key
	
	StatusbyteOut := 144 ; note on value for channel 1
	byte2out := 127 	  ; full on note message
	
	If mutemode = mute ; MUTE
	{
            ;msgbox key %key%    
		stbout 	 = Mute%note_num%
		byte1out := note_num + 15
		midiOutShortMsg(h_midiout, Statusbyteout, byte1out, byte2out)
		Gosub, ShowMidiOutMessage
               ; MsgBox, 0, , mute Key = %key%, 1
		keywait, %key%
		
		midiOutShortMsg(h_midiout, Statusbyteout, byte1out, 0) ; note off message
				;SendNote(h_midiout,Note) ; function in main file to Sendnotes
	}
	Else If mutemode = solo ; SOLO
	{
		stbout 	 = Solo%note_num%
		byte1out := note_num + 7
		midiOutShortMsg(h_midiout, Statusbyteout, byte1out, byte2out)
                ;MsgBox, 0, %mutemode% Mutemode(), solo routine reached, .75
		Gosub, ShowMidiOutMessage
                ;MsgBox, 0, , solo Key = %key%, 1
		keywait, %key%
		midiOutShortMsg(h_midiout, Statusbyteout, byte1out, 0) ; noteoff
		
				;msgbox Solo routine %mutemode%
				;SendNote(h_midiout,Note)
	}
	Else If mutemode = arm ;ARM
	{
		stbout 	 = Arm%note_num%
		byte1out :=	note_num - 1
		midiOutShortMsg(h_midiout, Statusbyteout, byte1out, byte2out)
				;MsgBox, 0, %mutemode% Mutemode(), arm routine reached, .75
		Gosub, ShowMidiOutMessage
                ; MsgBox, 0, , arm Key = %key%, 1
		keywait, %key%
		midiOutShortMsg(h_midiout, Statusbyteout, byte1out, 0) ; noteoff
				;msgbox Solo routine %mutemode%
				;SendNote(h_midiout,Note)
	}
	
	/*		;*************************************************
		;* 			needs revision here
		;*************************************************
		Else If mutemode = ChSel ; Ch SEL  CALL WITH THE DOUBLE TAP KEY DEFS BELOW
		{
			stbout 	 = ChSe%note_num%
			byte1out :=	note_num + 23
			midiOutShortMsg(h_midiout, Statusbyteout, byte1out, byte2out)
				;sleep, 100  ; change to see what gives
                ;midiOutShortMsg(h_midiout, Statusbyteout, byte1out, byte2out) 
                ; SendNote(h_midiout,Note)
				;	msgbox ChSel routine %mutemode% disable this when it is finally used.
		}
		
		Else If mutemode = vSel ; Vpot Select  CALL WITH THE DOUBLE TAP KEY DEFS BELOW
		{
			stbout 	 = VSel%note_num%
			byte1out :=	note_num + 31
			midiOutShortMsg(h_midiout, Statusbyteout, byte1out, byte2out)
				;SendNote(h_midiout,Note)
				;	msgbox Vsel routine %mutemode% disable this line 508 midi in process.ahk
		}
	*/
}
Return

; -------------- END OF MULTIFUNCTION MUTES ------------------

;*************************************************
;*          CHANNEL SELECTS - KEY TRIG ONLY 
;*************************************************

; --------------- CHANNEL SELECTS -------------------------------
;	ESC + fkeys#.
; 	CONSIDER WHICH KEYS TO USE....
;	SINGLE GIVES CH SEL
;	DOUBLE GIVES VPOT SEL  must change this for Live. esc = sc00f ?

esc & F1:: ; tab + f key
	note_num = 1 ; first ch select
	byte1out :=	note_num + 23
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f1
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

esc & F2::
	note_num = 2 ; first ch select
	byte1out :=	note_num + 23
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f2
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

Esc & F3::
	note_num = 3 ; first ch select
	byte1out :=	note_num + 23
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f3
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

Esc & F4::
	note_num = 4 ; first ch select
	byte1out :=	note_num + 23
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f4
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

Esc & F5::
	note_num = 5 ; first ch select
	byte1out :=	note_num + 23
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f5
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

Esc & F6::
	note_num = 6 ; first ch select
	byte1out :=	note_num + 23
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f6
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

Esc & F7::
	note_num = 7 ; first ch select
	byte1out :=	note_num + 23
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f7
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

Esc & F8::
	note_num = 8 ; first ch select
	byte1out :=	note_num + 23
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f8
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

;*************************************************
;*          vpot selects have moved to ` +f key
;*************************************************

SC029 & F1:: ;  ` key + Fkeys
	;msgbox  ` f1
	note_num = 1 ; first ch select
	byte1out :=	note_num + 31
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f1
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

SC029 & F2::
	note_num = 2 ; first ch select
	byte1out :=	note_num + 31
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f2
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

SC029 & F3::
	note_num = 3 ; first ch select
	byte1out :=	note_num + 31
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f3
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

SC029 & F4::
	note_num = 4 ; first ch select
	byte1out :=	note_num + 31
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f4
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

SC029 & F5::
	note_num = 5 ; first ch select
	byte1out :=	note_num + 31
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f5
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

SC029 & F6::
	note_num = 6 ; first ch select
	byte1out :=	note_num + 31
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f6
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

SC029 & F7::
	note_num = 7 ; first ch select
	byte1out :=	note_num + 31
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f7
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

SC029 & F8::
	note_num = 8 ; first ch select
	byte1out :=	note_num + 31
	midiOutShortMsg(h_midiout, 144, byte1out, 127)
	keywait, f8
	midiOutShortMsg(h_midiout, 144, byte1out, 0)
return

;*************************************************
;*          BANK KEYS HOTKEY TIRGGERED CURRENTLY
;*      need to add midi triggers for these....
;   just create new button inputs for bank and call bankbank bankdown
;*************************************************

; -------------  BANK KEYS -------------------------

; --- BANK BACK ---
; --- BANK DOWN ---
;Bank<: ;hotkey defined in ini file.
;ü::
SC01a:: ; [ key us 
	Gosub, bankbank
return

bankbank:
	sync =
	Note := 46
	gosub, bankreset
	midiOutShortMsg(h_midiout, 144 , 46, 127) ; note , byte2 ;Send THE NOTE TO THE FUNCTION

		; notify fader_feedback.ahk that bank button pressed.

		;detecthiddenwindows,on ; does this need to be turned off
		; controlclick,Button2,ahk_class AutoHotkeyGUI,UID3 ; CALL THE LISTENER IN FADER FEEDBACK
		;detecthiddenwindows, off
		;BankPos := BankPos - 1
		;IfLess, BankPos, 1
		; {
		;  BankPos := 1
		;}
		;BankPosition(BankPos)  ; see Bottom of this file.

Return

; --- BANK DOWN ---
;Bank>:
;+:: ;]
SC01b:: ;] key us
	gosub, bankdown
return

bankdown:
	sync = ; set sync to blank
	Note = 47
	gosub, bankreset

	midiOutShortMsg(h_midiout, 144 , 47, 127)

		;detecthiddenwindows,on
		; controlclick,Button2,ahk_class AutoHotkeyGUI,UID3 ; call fader_feedback.ahk to launch pbsend again to refresh faders values.
		;DetectHiddenWindows, off
		;BankPos := BankPos +1
		;IfGreater, BankPos, 6
		;  {
		;    BankPos := 6
		; }
		;BankPosition(BankPos)


Return
/*
; gui change
	BankPosition(BankPos)
	{	global bankp
	If (BankPos = 1)
	{
		BankP := "1 - 8 "
	}
	Else If (BankPos = 2)
	{
		BankP := "9 -16"
	}
	Else If (BankPos = 3)
	{
		BankP := "17-24"
	}
	Else If (BankPos = 4)
	{
		BankP := "25-32"
	}
	Else If (BankPos = 5)
	{
		BankP := "33-40"
	}
	Else If (BankPos = 6)
	{
		BankP := "41-48"
	}
    ;Else If (BankPos = 7)
     ; {
      ;  BankP := "NoWay"
      ;}
	gosub, ShowUpdategui
;    GuiControl,6:, BankP, %BankP%
	}
	Return
*/
;*************************************************
;*          attempt to set fccval = blank so
;       new values are obtained to reduce jumps on 
;           banking - does it work?
;*************************************************

bankreset: 
;  Fccval1 =
;  Fccval2 =
;  Fccval3 =
;  Fccval4 =
;  Fccval5 =
;  Fccval6 =
;  Fccval7 =
;  Fccval8 =
	pb1=
	pb2=
	pb3=
	pb4=
	pb5=
	pb6=
	pb7=
	pb8=

 ; Fccval9 = ; should not need to do this one as it won't change with banking. for master fader.
Return
; -------------- END BANK POSTION AND BANK KEYS--------------

;*************************************************
;*          UNDO / REDO COMMANDS
;*************************************************

; --- Undo ---
LCtrl & Del:: ; left ctrl
	Note = %undo% ;76 ;78
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

; --- Redo ---
LCtrl & Ins:: ; left ctrl + key
	Note = %redo% ;79
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

;*************************************************
;*                  LOOP ON/OFF
;*************************************************
; --- Loop On ---

; FYI THIS "CNTRL + L" = SETS MARKERS AND LOOP AROUND SELECTED TIME in reaper (test this)

SC026:: ; loop on = L
	Note = %loop% ;86 ; 84 for traction
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

;*************************************************
;*          SET MARKERS + PREV NEXT MARKER
;*************************************************

;--- Set Mark  ---
LCtrl & SC032:: ; left ctrl + --- Set Mark  --- (m)
	Note = 82
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

; --- Prev Marker Jump ---
LCtrl & SC033:: ; prev marker (,)
	Note = 84
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

LCtrl & SC034:: ; next marker (.)
	Note = 85
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

;*************************************************
;*                PUNCH IN / OUT
;*************************************************

SC019:: ; single press for set punch in / double press for punchout (p)
{
	CountPresses("P_In","P_Out","null") ; use $ with a KEY0 Label, or #UseHook
			;Note_Num :=8 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
}
Return
    ; ----------- FUNCTIONS FOR CHAN SELECT AND VPOT SELECT keys above -----------
    ;They work mute section above and the functions contained in the mute section

P_In:        	; Punch in
	Note = 87
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

P_Out: ; punch out
	Note = 88
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

; NEED TO REASSIGN CONFLICT WITH LIVE
;	ALREADY ASSIGNED IN LIVE
;LControl & f:: ; follow on/off
;	Note = 83
;	NoteVel = 127
;	GoSub, sendit
;	return

; NEED TO REASSIGN CONFLICT WITH LIVE
LCtrl & SC030:: ; left ctrl + bars/beats (b)
	Note = 53
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

; REASSIGNE CONFLICT WITH LIVE
SC01d & SC020:: ; draw on/off (d)
	Note = 81
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

;*************************************************
;*                  HOME / END
;*************************************************

LCtrl & SC047:: ; left control + home    home make this one a multpress for home and end (home)
{
	CountPresses("Home","End","null") ; use $ with a KEY0 Label, or #UseHook
	  ;Note_Num :=8 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
}
Return
; ----------- FUNCTIONS FOR CHAN SELECT AND VPOT SELECT keys above -----------
;They work mute section above and the functions contained in the mute section

Home:    ; go to the beginning home
	Note = 89
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

End: ; end
	Note = 90
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

;*************************************************
;*              PAGE UP / DOWN
;*************************************************

PGUP:: ; pg up / next ; consider a timer and repeat to keep it from flying too far
	Note = %pageleft% ;45
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

PGDN:: ; page previous
	Note = %pageright% ;44
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

; need to add option for stop clip, alt for remove launch button

;*************************************************
;*       ZOOM / SCRUB - NOT IMPLIMENTED YET
;*************************************************

; Zoom on the Right alt and Right Shift key combo

;RAlt & RShift:: ; zoom Button
{
	CountPresses("Play_clip","Stop_clip","Remove_launch") ; use $ with a KEY0 Label, or #UseHook
}
Return

; 1 press = play active clip
; 2 presses = stop active clip
; 3 presses = remove stop button from empty clip.

Play_clip:        	; clip fire
	;Note  = 42  ; %pans%var defined in SelectDaw function at line 10 (this file) ;; NOTE FOR LIVE,
	midiOutShortMsg(h_midiout, 144, 100, 127) ; play clip on
Return

Stop_clip: ; scene fire
	midiOutShortMsg(h_midiout, 144, 71, 127) ; "N1" = "NoteOn"  option key
	Sleep, 10
	midiOutShortMsg(h_midiout, 144, 100, 127) ; "N1" = "Noteon" zoom Button
	Sleep, 10
	midiOutShortMsg(h_midiout, 128, 71, 0) ; "N0" = "Noteoff" option key
Return

Remove_launch: ;remove the launch Button
	midiOutShortMsg(h_midiout, 144, 73, 127) ; "N1" = "NoteOn" alt key
	Sleep, 10
	midiOutShortMsg(h_midiout, 144, 100, 127) ; "N1" - zoom Button
	Sleep, 10
	midiOutShortMsg(h_midiout, 128, 73, 0) ; "N0" = "Noteoff" alt key
Return

	;RCtrl & RShift:: ; scrub Button
{
	CountPresses("Play_scene","Stop_scene","null") ; use $ with a KEY0 Label, or #UseHook
}
Return
	; 1 press = play active clip
	; 2 presses = stop active clip
	; 3 presses = remove stop button from empty clip.
;*************************************************
;*   OTHER KEYS OR FUNCTIONS - NOT USED IN REAPER
;*************************************************	
Play_scene:        	; clip fire
	;Note  = 42  ; %pans%var defined in SelectDaw function at line 10 (this file) ;; NOTE FOR LIVE,
	midiOutShortMsg(h_midiout, 144, 101, 127) ; play selected scene
Return

Stop_scene: ; scene stop
	midiOutShortMsg(h_midiout, 144, 71, 127) ; "N1" = "NoteOn"  option key
	Sleep, 10
	midiOutShortMsg(h_midiout, 144, 101, 127) ; "N1" = "Noteon" zoom Button
	Sleep, 10
	midiOutShortMsg(h_midiout, 128, 71, 0) ; "N0" = "Noteoff" option key
Return

	; this should become remove stop button or is should be somewhere.

	;------------- END ZOOM / SCRUB -------------------------------------
	;*************************************************
	;*   OTHER KEYS OR FUNCTIONS - NOT YET DEFINED
	;*************************************************
		;::
		;  Note = 80
		;  midiOutShortMsg(h_midiout, 144 , note, byte2)
		;Return

':: ; this is theoption key  PROBABLY THINK ABOUT SOME WAY TO HOLD THE NOTE ON, PRIOR TO NOTE OFF GOES THRU. SEPARATE SENDIT ROUTINE
		; SENDIT OPTIONS KEYS....
	Note = 71
	midiOutShortMsg(h_midiout, 144 , note, byte2)
Return

; ------ end  of buttons definitions ------------
; 12.3.13  changing gui size and font for legibility and to line up with keys on laptop better.
; possible option for font and gui size....
; is there an auto gui size.

; remove the indicators and move the change speeds to right click menu to choose.
; save as ini file as well.

; Last edited 10/7/2010 8:59 PM by Kip Chatterson - change this when you edit it, please
; Last edited 9/30/2010 11:37 AM by genmce
; removed main gui elements bank, f, retr, and tracks.


;*************************************************
;*          		MIDI SET GUI 
;*************************************************

MidiSet: ; midi port selection gui

 ; ------------- MIDI INPUT SELECTION Gui-----------------------
	Gui, 6: Destroy
	Gui, 2: Destroy
	Gui, 3: Destroy
	Gui, 4: Destroy
	Gui, 4: +LastFound +AlwaysOnTop   +Caption +ToolWindow ;-SysMenu
	Gui, 4: Font, s12
	Gui, 4: add, text, y10 w300 cmaroon, ReaKeyMce Midi Setup ; Text title
	Gui, 4: Font, s8
		;  Gui, 4: Add, Text, x10 y+10 w175 Center , Midi In Port  ;Just text label
		;  Gui, 4: font, s8
		  ; midi ins list box
		;  Gui, 4: Add, ListBox, x10 w200 h100  Choose%TheChoice% vMidiInPort gDoneInChange AltSubmit, %MiList% ; --- midi in listing of ports
			;Gui,  Add, DropDownList, x10 w200 h120 Choose%TheChoice% vMidiInPort gDoneInChange altsubmit, %MiList%  ; ( you may prefer this style, may need tweak)

		  ; --------------- MidiOutSet Gui---------------------
	Gui, 4: Add, TEXT, xp  y40 w200 Center, ReaKeyMce Out (Reaper MCU in) ; gDoneOutChange
		  ; midi outlist box
	Gui, 4: Add, ListBox, xp y62 w200 h100  Choose%TheChoice2% vMidiOutPort gDoneOutChange AltSubmit, %MOList% ; --- midi out listing
		  ;Gui,  Add, DropDownList, x220 y97 w200 h120 Choose%TheChoice2% vMidiOutPort gDoneOutChange altsubmit , %MoList%
	Gui, 4: Add, TEXT,  x220 y40 w200 Center, Display In (Reaper MCU Out) ; gDoneOutChange
	Gui, 4: Add, ListBox, x220 y62 w200 h100  Choose%TheChoice3% vMidiInPort2 gDoneIn2Change AltSubmit, %MIfaderList% ; --- midi out listing
	Gui, 4: add, Button, x15 w202 gSet_Done, Done - Reload
	Gui, 4: add, Button, xp+202 w202 gCancel, Cancel
		  ;gui, 4: add, checkbox, x10 y+10 vNotShown gDontShow, Do Not Show at startup.
		  ;IfEqual, NotShown, 1
		  ;guicontrol, 4:, NotShown, 1
	Gui, 4: show , AutoSize , %version% Midi Port Selection ; main window title and command to show it.

Return

;*************************************************
;*          GUI LABEL PROCESSES
;*************************************************
;-gui done change stuff - see label in both gui listbox line

DoneInChange: ; this is just the processes for midi change
	gui +lastfound
	Gui, Submit, NoHide
	Gui, Flash
		  ;Gui, 14: Submit, NoHide
		  ;Gui, 14: Flash
	If %MidiInPort%
		UDPort:= MidiInPort - 1, MidiInDevice:= UDPort ; probably a much better way do this, I took this from JimF's qwmidi without out editing much.... it does work same with doneoutchange below.
	GuiControl, 4:, UDPort, %MidiIndevice%
	GuiControl, 14:, UDPort, %MidiIndevice%
	WriteIni()
Return

DoneOutChange:
	gui +lastfound
	Gui, Submit, NoHide
	Gui, Flash
	If %MidiOutPort%
		UDPort2:= MidiOutPort - 1 , MidiOutDevice:= UDPort2
	WriteIni()
	GuiControl, 4: , UDPort2, %MidiOutdevice%
	GuiControl, 14: , UDPort2, %MidiOutdevice%

		 ; MsgBox, 32, , midi out device = %MidioutDevice%`nmidiinport = %MidiOutPort%`n %molist% ; only for testing
		;Gui, Destroy
Return

DoneIn2Change:
	gui +lastfound
	Gui, Submit, NoHide
	Gui, Flash
	If %MidiInPort2%
		UDPort3:= MidiInPort2 - 1 , MidiInDevice2:= UDPort3
	GuiControl, 4: , UDPort3, %MidiIndevice2%
	GuiControl, 14: , UDPort3, %MidiIndevice2%
	WriteIni()
	  ;Gui, Destroy
Return

;------------------------ end of the doneout change stuff.

Set_Done: ;  aka reload program, called from midi selection gui
	WinGetPos, winX, winY, , ,%version% 						; on Exit get Gui postion
	IniWrite, %winX%, %A_ScriptDir%\%version%.ini, GuiPosition, winX	; write postion to ini
	IniWrite, %winY%, %A_ScriptDir%\%version%.ini, GuiPosition, winY
	Suspend, Permit ; allow Exit to work Paused. I just added this yesterday 3.16.09 Can now quit when Paused.
	Gui, 3: Destroy
	Gui, 4: Destroy
	sleep, 200
	Reload
Return

Cancel:
	Gui, Destroy
	Gui, 2: Destroy
	Gui, 3: Destroy
	Gui, 4: Destroy
	Gui, 5: Destroy
	gui,20:destroy
Return
/*
	MidiOut: ; Function to load new settings from midi out menu item
	OpenCloseMidiAPI()
	h_midiout := midiOutOpen(MidiOutDevice) ; OUTPUT PORT 1 SEE BELOW FOR PORT 2
	return
*/

ResetAll: ; for development only, leaving this in for a program reset if needed by user
	MsgBox, 33, %version% - Reset All?, This will delete ALL settings`, and restart this program!
	IfMsgBox, OK
	{
		FileDelete, %version%.ini   ; delete the ini file to reset ports, probably a better way to do this ...
		
			;controlclick,Button1,ahk_class AutoHotkeyGUI,UID1 ; closer fader feedback sender
		
		Reload                        ; restart the app.
	}
	IfMsgBox, Cancel
Return
;*/

GuiClose: ; on x exit app
	WinGetPos, winX, winY, , ,%version% 						; on Exit get Gui postion
	IniWrite, %winX%, %A_ScriptDir%\%version%.ini, GuiPosition, winX	; write postion to ini
	IniWrite, %winY%, %A_ScriptDir%\%version%.ini, GuiPosition, winY
	Suspend, Permit ; allow Exit to work Paused. I just added this yesterday 3.16.09 Can now quit when Paused.
	midiOutClose(h_midiout)
	Gui, 24: Destroy
	gui, 4: destroy
	gui, 7: destroy
	gui, 20: destroy

	Sleep 100
		  ;msgbox x%winx% y%winy%
		  ;winclose, Midi_in_2 ;close the midi in 2 ahk file
	ExitApp
Return
;*/
;*************************************************
;* 			is this one still need ?
;*************************************************
GuiClose2: ; on x exit app
    ;msgbox guiclose reached
	Suspend, Permit ; allow Exit to work Paused. I just added this yesterday 3.16.09 Can now quit when Paused.
	DetectHiddenWindows On  ; Allows a script's hidden main window to be detected.
			;	SetTitleMatchMode 2  ; Avoids the need to specify the full path of the file below.
			;WinClose Script's File Name.ahk - AutoHotkey  ; Update this to reflect the script's name (case sensitive).
	controlclick,Button1,ahk_class AutoHotkeyGUI,UID1 ; closer fader feedback sender

			;WinClose %fader_feedback% - AutoHotkey  ; Update this to reflect the script's name (case sensitive).  
		 ; MsgBox, 4, Exit %version%, Exit %version% %ver%? ; 
		  ;IfMsgBox No
		   ;   Return
		  ;Else IfMsgBox Yes
	midiOutClose(h_midiout)

	Gui, 6: Destroy
	Gui, 2: Destroy
	Gui, 3: Destroy
	Gui, 4: Destroy
	Gui, 5: Destroy
	gui, 7: destroy
		 ;gui, 
	Sleep 100
		  ;winclose, Midi_in_2 ;close the midi in 2 ahk file
	ExitApp
Return

;*************************************************
;* 			MACKIE DISPLAY SCREEN
;*************************************************

display:

/* 
	add a way to detect sync -
	detect the zeros coming in then note the change on say chan 8
	then show that sync acheived.
	on main gui with BOLD text or different color.
	listview command update or add a new control seperate from the rest...
	small edit box readonly that will change color based on sync, red for not, green for go.
	or an icon of a lock to show sync on the sync cell...
	
*/
;Gui,24: Add, Button, default x70 y2 gChange, Change
;Gui,24: Add, Picture, w10 h10, Green_led.gif
;Gui,24: Show, w200 h200

/* 
	GUI FOR LCD
*/
	Gui, 24: +LastFound +AlwaysOnTop  +SysMenu +Caption ;-ToolWindow 
	Gui,24:Font, s11, Courier New
	gui,24: color, black
	Gui,24: Add, Text,  y2 w515 Backgroundblack clime vupper_line hwndh_upper_line, %upper_LCD% ;xp-75 y18 ;w385
	Gui,24: Add, Text, yp+17 xp-6 w515 Backgroundblack clime vlower_line hwndh_lower_line, %lower_LCD% ;py+15

	Gui,24:Font, s8, verdana
	Gui,24:Add, ListView , x529 y1 r1 w88 Backgroundblack cyellow count1 grid +ReadOnly -hdr -LV0x10 -WantF2   NoSortHdr  vDisplay,vMode|Modi| ;auto flip;Sync| ;F|Tracks Retr| ;x399
				;gui,24:add text, yp+17 cyellow,, %vpotmode%
				;gui,24:add, ListView, xp-275 yp+25 r1 w440 Backgroundblack cyellow Count2 vFaderLocks grid,  fader1|fader2|fader3|fader4|fader5|fader6|fader7|fader8|fader9| ;Backgroundblack
			;/*
				;Button toggle for pan - not inserted yet
				;s := 0
	Gui,24: Add, Button, xm w40 h20 x529 y19 r1 gPans Default, Pans
	Gui,24: Add, Button, xp yp wp hp gSends, Sends
	Gui,24: Add, Button, xp yp wp hp gPlugs, Plugs
	Gui,24: Show, , 
	GuiControl, 24: Hide, Sends  ; On Startup hide the Ctrls u dont want to be shown/used
	GuiControl, 24: Hide, Plugs
				;Return


	WinSetTitle, , , %version% - %section% ;- %vmode% - %flip% - %modi% ;%sync% ;  This sets the title of the display based on version near top line of main file.

		;msgbox x%winX% Y%winy%
		;ui,24: add, edit,   w50 h20 vFccval, ; input monitor

	/* 
		TOFIX 
	*/
	gui,24:Show, autosize x%winX% y%winY% NoActivate, ; figure out how to center this
	vpotmode = pans
	;gosub, ShowUpdategui

		;gui,24: show
	;msgbox just before lcd start

	;*************************************************
	;* 			change this to h_MidiIn for genmce
	;*************************************************

	Start_LCD_Listener(h_MidiIn2, h_upper_line, h_lower_line)  ; Midi in handle, windows handle to upper and lower line in GUI
		;gosub, setup
	gosub, ShowUpdategui 
Return

CenterLCD: ;reload the display to top center

	Gui,6:Destroy ;main display
	Gui,2:Destroy ;Suspend display
	gui, 24:destroy
	winX = Center
	winY = 0
	IniWrite, %winX%, %version%.ini, GuiPosition, winX
	IniWrite, %winY%, %version%.ini, GuiPosition, winY
	Sleep, 100
	IniRead, winX, %version%.ini, GuiPosition, winX
	If winX not Between 0 and 1600 ; if not Between these values set to top Center Screen.
		winX = Center
	IniRead, winY, %version%.ini, GuiPosition, winY
	If winY not Between -10 and 1600
		winY = 0
	Sleep, 100
	Gosub, display

Return

;****************************
;* Labels for Main_gui buttons
;****************************

Pans:
	Gui,24: Submit, NoHide
	GuiControl, 24: hide, Pans ; Just hide the Ctrls u dont want to be used
	GuiControl, 24: show, Sends ; and show those u want to be displayed
	GuiControl, 24: Hide, Plugs
	midiOutShortMsg(h_midiout, 144, 41, 127) ; see button Output
	vpotmode = sends
	gosub, ShowUpdategui
Return

Sends:
	Gui,24: Submit, NoHide
	GuiControl, 24: hide, Pans
	GuiControl, 24: Hide, Sends
	GuiControl, 24: show, Plugs
	midiOutShortMsg(h_midiout, 144, 43, 127)
	vpotmode = Plugs
	gosub, ShowUpdategui
Return

Plugs:
	Gui,24: Submit, NoHide
	GuiControl, 24: show, Pans
	GuiControl, 24: Hide, Sends
	GuiControl, 24: Hide, Plugs
	midiOutShortMsg(h_midiout, 144, 42, 127)
	vpotmode = Pans
	gosub, ShowUpdategui
Return
;*/	




24guiclose:
	gosub, GuiClose
return

/*
	Change:
	;Gui,24: Destroy
	Gui,24: Add, Button, default x70 y5 gChangeBack, Change
	Gui,24: Add, Picture, x43 y40 w10 h10, Red_led.gif
	Gui,24: Show, w200 h200
	Return
	
	ChangeBack:
	;Gui,24: Destroy
	Gui,24: Add, Button, default x70 y5 gChange, Change
	Gui,24: Add, Picture, x43 y40 w10 h10, Green_Led.gif
	Gui,24: Show, w200 h200
	Return
*/

;*************************************************
;* 			show main gui
;*************************************************

ShowUpdategui: ; update the disgui 
;gosub, returngui
	Gui,24:default
	Gui,24:ListView, Display ; see the second listview midi out monitor
	LV_Add("",vpotmode,modi)	;flip,speedname,jspeedname ;sync) ;flip,bankp,returns,,speedname,sync
	LV_ModifyCol(1,auto "center")
	LV_ModifyCol(2,auto "center")
		;LV_ModifyCol(3,"center")
		;LV_ModifyCol(4,"center")
		;LV_ModifyCol(5,"center")
		;LV_ModifyCol(6,"center")
		;LV_ModifyCol(7,"center")
		;LV_ModifyCol(8,"center")
	;LV_ModifyCol(9,"center")
	If (LV_GetCount() > 1)
	{
		LV_Delete(1)
	}
	gui,24:Listview, LCD
	Lv_modify("", "test" upper_line hwndh_upper_line)
return

;*************************************************
;* 			show main gui PAUSED
;*************************************************
ShowPAUSEgui: ; update the disgui 
	;gosub, returngui
	Gui,24:default
	Gui,24:ListView, Display ; see the second listview midi out monitor
	LV_Add("","pause","-") ;flip,bankp,speedname,returns,vpotmode,vspeedname,jspeedname,modi,sync)
	LV_ModifyCol(1, auto "center")
	LV_ModifyCol(2, auto "center")
		;LV_ModifyCol(3,"center")
		;LV_ModifyCol(4,"center")
		;LV_ModifyCol(5,"center")
		;LV_ModifyCol(6,"center")
		;LV_ModifyCol(7,"center")
		;LV_ModifyCol(8,"center")
	;LV_ModifyCol(9,"center")
	If (LV_GetCount() > 1)
	{
		LV_Delete(1)
	}
return


      ; NOT NEEDED FOR REAKEYMCE - YET.
;*************************************************
;* 			MAIN SETUP GUI
;*************************************************

SetUp:

;*************************************************
;* 			MAIN MIDI MONITOR GUI
;*************************************************

	gui,20:destroy
	gui,20:default

	monitorX = 85
	monitorY = 

	gui,20:add,text, x%monitorX% y%monitorY%, Midi Input ;%Udport%
	gui,20:add,text, xp+200 yp, Midi Ouput ; %TheChoice2%
	gui,20:Add, ListView, xp-275 yp+15 r11 w210 Backgroundblack caqua Count10 vIn1,  Event|StatB|Ch|Byte1|Byte2| 
	gui,20:Add, ListView, x+5 r11 w200 Backgroundblack cred Count10 vOut1,  Event|Ch|Byte1|Byte2| ;StatB|w150
	gui,20:add, ListView, x25 r1 w390 Backgroundblack cyellow Count2 vFaderLocks grid,  fader1|fader2|fader3|fader4|fader5|fader6|fader7|fader8|fader9| ;Backgroundblack
	;gui, 14: add, text, x5 h5 w320 
	gosub, ShowFaderLocks
	Gui,20: Show,  ,GenKeyMce SetUp
Return


;*************************************************
;* 	SHOW MIDI (CONTROLLER) IN UPDATE LISTVIEW
;*************************************************
; =============== show midi message update the listview gui ========================

ShowMidiInMessage: ; update the midimonitor gui

	Gui,20:default
	Gui,20:ListView, In1 ; see the first listview midi in monitor
	LV_Add("",stb,statusbyteIn,chanIn,byte1In,byte2in)
	LV_ModifyCol(1,"center")
	LV_ModifyCol(2,"center")
	LV_ModifyCol(3,"center")
	LV_ModifyCol(4,"center")
	LV_ModifyCol(5,"center")
	If (LV_GetCount() > 10)
	{
		LV_Delete(1)
	}
return

;*************************************************
;*		SHOW MIDI OUTPUT (MACKIE CONVERTED) MONITOR			
;*************************************************

ShowMidiOutMessage: ; update the midimonitor gui 

	Gui,20:default
	Gui,20:ListView, Out1 ; see the second listview midi out monitor
	LV_Add("",stbOut,chanOut,byte1Out,byte2Out)
	LV_ModifyCol(1,"center")
	LV_ModifyCol(2,"center")
	LV_ModifyCol(3,"center")
	LV_ModifyCol(4,"center")
	;LV_ModifyCol(5,"center")
	If (LV_GetCount() > 10)
	{
		LV_Delete(1)
	}
return

;*************************************************
;* 			SHOW FADER FEEDBACK ON GUI GRID - i DON'T THINK THIS IS USED IN ReaKEY
;*************************************************

ShowFaderLocks: ; update the midimonitor gui

	Gui,20:default
	Gui,20:ListView, faderlocks ; see the first listview midi in monitor
	LV_Add("",pb1,pb2,pb3,pb4,pb5,pb6,pb7,pb8,pb9) ;,byte1,byte2,midimsgin)
	LV_ModifyCol(1,"center")
	LV_ModifyCol(2,"center")
	LV_ModifyCol(3,"center")
	LV_ModifyCol(4,"center")
	LV_ModifyCol(5,"center")
	LV_ModifyCol(6,"center")
	LV_ModifyCol(7,"center")
	LV_ModifyCol(8,"center")
	LV_ModifyCol(9,"center")
	If (LV_GetCount() > 1)
	{
		LV_Delete(1)
	}
	gosub, ShowUpdategui
return


midiMon: ;just a simple gui window for a midi monitor of sorts.


Return


MidiRoute:
	;MsgBox, 32,,pushed button
	Gui, 3: +LastFound   +Caption +ToolWindow
	;gui, 3: color, #909090
	Gui, 3:font, s10
	Gui, 3: add, text , w200 ,Controls in this window are not active`, they are images.`nUse this to Guide setup for this program and daw.`n`nSet %version% (Right) -`nMidi MCU inport = midi yoke 2`nMidi MCU outport = midi yoke 1`n`nSet Reaper (below)`nMidi in port = midi yoke 1`nMidi out port = midi yoke 2`n`nUse x in top Right to Close this window.`nRTFM never hurts...
	;Gui, 3: add, Picture, w309 h82, Midi_Routing.jpg
	Gui, 3: add, Picture , x+5 , images\midi_settings.gif
	Gui, 3: add, Picture, xCenter, images\reaper_setup.gif
	Gui, 3: show, , Read THIS! ------ Midi Routing Example - This window Contains images to aide setup`, only. ------
Return

TroubleShoot:
	Gui, 2: Destroy
	Gui, 3: Destroy
	Gui, 7: Destroy
	Gui, 7: +LastFound +AlwaysOnTop  +Caption +ToolWindow
	Gui, 7: font, s14 underline
	Gui, 7: add, text, w650, This is not a substitute for the manual - RTFM.
	Gui, 7: font, norm s12 italic
	Gui, 7: add, text ,w650 , *ReOpen Project or Daw - everytime settings change!
	Gui, 7: font
	Gui, 7: font, s11
	Gui, 7: add, text, w650 , Test faders First.`n`t1. Faders not moving - Check midiset(rt Click on tray icon) - look at routing example.`n`t2. Faders jumping values - Reopen project`, then Check midi Input on ReaKeyMce and midi output on daw - *set to same port. `n`tSee routing example (midiset).`n`tThese must be the same port!`n`t
	Gui, 7: font, norm s12 italic
	Gui, 7: add, text ,w650 , *ReOpen Project or Daw again!
	Gui, 7: font, s12
	;gui, 7: add, text , , The most common problem -

	Gui, 7: show,, Common problems - what to do.
Return


showkeys: ;not implimented yet
	; ListHotkeys
	gui, 7:destroy
	Gui, 7: add, Picture , Center , images\key_layout.gif
	Gui, 7: show ,, %version% "Most" Keyboard commands - (not finished)
Return

Quick_Set_Guide:
	;MsgBox, 32,,pushed button

	Gui, 5:font, s7
	;Gui, 3: add, text ,  , Routing Example,
	Gui, 5: add, Picture, w438 h589 , images\Quick_Set_Guide.jpg ;
	Gui, 5: show,  y+100, %version% QuickConnect (not revised - yet port names do not match current version.)
Return

About: ; show a message box after the about menu item is pressed
	MsgBox, 64, About %Version%, %version% %ver%`nby`nKip Chatterson`nCopyRight 2016`nSee ReaKeyMce_EULA.txt`, all Rights reserved.`n
Return

OpenPdf:
	Run KeyMce.pdf
Return


Beverageware:
	MsgBox, 4, %version% - is BeverageWare!`nIf you like this, donate.`nAre you ready to buy developer a beverage?, because this is an awesome program and you use it?
	IfMsgBox No
	{
		;	msgbox You must have already bought that beverage, THANK YOU! `n`nIf not, that is lame, he worked a long time just for you`, so buy him a beverage, because it's the right thing to do.
		Return
	}
	Else IfMsgBox Yes
	{
				;MsgBox THANKS! - if site does not load - donate with paypal to k5kip_1999@yahoo.com (that is me).
	;Run http://oneleaf.heliohost.org/here/ ;Site is currently down
	}
Return


KeyMce_Home_Page:

	MsgBox, 4, site., is long gone ... need to remove this.

	IfMsgBox No
	{
				;msgbox That is lame, he worked a long time on this`, and does not want to sell it`, just buy him a beverage. To thank him.
	;Return
	}
	Else IfMsgBox Yes
	{
		MsgBox Nothing here.
	;Run http://oneleaf.heliohost.org/here/ ;Site is currently down
	}
Return



14guiclose:
	gui,14:destroy
	;gosub, guiclose
Return


;****************************************************************************************************************
;******************************************** midi "under the hood" *********************************************
/* 
	This part is meant to take care of the "under the hood" midi input and output selection and save selection to an ini file.
	Hopefully it simplifies usage for others out here trying to do things with midi and ahk.
	
	
	The code here was taken/modified from the work by TomB/Lazslo on Midi Output
	http://www.autohotkey.com/forum/viewtopic.php?t=18711&highlight=midi+output
	
	Orbik's Midi input thread 
	http://www.autohotkey.com/forum/topic30715.html
	This method does NOT use the midi_in.dll, it makes direct calls to the winmm.dll
	
	Many different people took part in the creation of this file.
*/


;*************************************************
;*          MIDI IN PORT HANDLING
;*************************************************

;--- MIDI INS LIST FUNCTIONS - port handling -----

MidiInsList(ByRef NumPorts)
{ ; Returns a "|"-separated list of midi output devices
	local List, MidiInCaps, PortName, result
	VarSetCapacity(MidiInCaps, 50, 0)
	VarSetCapacity(PortName, 32)                       ; PortNameSize 32
	
	NumPorts := DllCall("winmm.dll\midiInGetNumDevs") ; #midi output devices on system, First device ID = 0
	
	Loop %NumPorts%
	{
		result := DllCall("winmm.dll\midiInGetDevCapsA", UInt,A_Index-1, UInt,&MidiInCaps, UInt,50, UInt)
		If (result OR ErrorLevel) {
			List .= "|-Error-"
			Continue
          }
		DllCall("RtlMoveMemory", Str,PortName, UInt,&MidiInCaps+8, UInt,32) ; PortNameOffset 8, PortNameSize 32
		List .= "|" PortName
	}
	Return SubStr(List,2)
}

MidiInGetNumDevs() { ; Get number of midi output devices on system, first device has an ID of 0
	Return DllCall("winmm.dll\midiInGetNumDevs")
}
MidiInNameGet(uDeviceID = 0) { ; Get name of a midiOut device for a given ID
	
    ;MIDIOUTCAPS struct
    ;    WORD      wMid;
    ;    WORD      wPid;
    ;    MMVERSION vDriverVersion;
    ;    CHAR      szPname[MAXPNAMELEN];
    ;    WORD      wTechnology;
    ;    WORD      wVoices;
    ;    WORD      wNotes;
    ;    WORD      wChannelMask;
	;    DWORD     dwSupport;
	
	VarSetCapacity(MidiInCaps, 50, 0)  ; allows for szPname to be 32 bytes
	OffsettoPortName := 8, PortNameSize := 32
	result := DllCall("winmm.dll\midiInGetDevCapsA", UInt,uDeviceID, UInt,&MidiInCaps, UInt,50, UInt)
	
	If (result OR ErrorLevel) {
		MsgBox Error %result% (ErrorLevel = %ErrorLevel%) in retrieving the name of midi Input %uDeviceID%
		Return -1
	}
	
	VarSetCapacity(PortName, PortNameSize)
	DllCall("RtlMoveMemory", Str,PortName, Uint,&MidiInCaps+OffsettoPortName, Uint,PortNameSize)
	Return PortName
}

MidiInsEnumerate() { ; Returns number of midi output devices, creates global array MidiOutPortName with their names
	local NumPorts, PortID
	MidiInPortName =
	NumPorts := MidiInGetNumDevs()
	
	Loop %NumPorts% {
		PortID := A_Index -1
		MidiInPortName%PortID% := MidiInNameGet(PortID)
	}
	Return NumPorts
}

;*************************************************
;*    MIDI OUT LIBRARY FROM lASZLO AND TOMB
;*************************************************

MidiOutsList(ByRef NumPorts)
{ ; Returns a "|"-separated list of midi output devices
	local List, MidiOutCaps, PortName, result
	VarSetCapacity(MidiOutCaps, 50, 0)
	VarSetCapacity(PortName, 32)                       ; PortNameSize 32
	
	NumPorts := DllCall("winmm.dll\midiOutGetNumDevs") ; #midi output devices on system, First device ID = 0
	
	Loop %NumPorts%
	{
		result := DllCall("winmm.dll\midiOutGetDevCapsA", UInt,A_Index-1, UInt,&MidiOutCaps, UInt,50, UInt)
		If (result OR ErrorLevel)
		{
			List .= "|-Error-"
			Continue
          }
		DllCall("RtlMoveMemory", Str,PortName, UInt,&MidiOutCaps+8, UInt,32) ; PortNameOffset 8, PortNameSize 32
		List .= "|" PortName
	}
	Return SubStr(List,2)
}
;---------------------midiOut from TomB and Lazslo and JimF --------------------------------

;THATS THE END OF MY STUFF (JimF) THE REST ID WHAT LASZLo AND PAXOPHONE WERE USING ALREADY
;AHK FUNCTIONS FOR MIDI OUTPUT - calling winmm.dll
;http://msdn.microsoft.com/library/default.asp?url=/library/en-us/multimed/htm/_win32_multimedia_functions.asp
;Derived from Midi.ahk dated 29 August 2008 - streaming support removed - (JimF)


OpenCloseMidiAPI() {  ; at the beginning to load, at the end to unload winmm.dll
	static hModule
	If hModule
		DllCall("FreeLibrary", UInt,hModule), hModule := ""
	If (0 = hModule := DllCall("LoadLibrary",Str,"winmm.dll")) {
		MsgBox Cannot load libray winmm.dll
		Exit
	}
}

;FUNCTIONS FOR SENDING SHORT MESSAGES

midiOutOpen(uDeviceID = 0) { ; Open midi port for sending individual midi messages --> handle
	strh_midiout = 0000
	
	result := DllCall("winmm.dll\midiOutOpen", UInt,&strh_midiout, UInt,uDeviceID, UInt,0, UInt,0, UInt,0, UInt)
	If (result or ErrorLevel) {
		MsgBox There was an Error opening the midi port.`nError code %result%`nErrorLevel = %ErrorLevel%
		Return -1
	}
	Return UInt@(&strh_midiout)
}

midiOutShortMsg(h_midiout, MidiStatus,  Param1, Param2) { ;Channel,
    ;h_midiout: handle to midi output device returned by midiOutOpen
    ;EventType, Channel combined -> MidiStatus byte: http://www.harmony-central.com/MIDI/Doc/table1.html
    ;Param3 should be 0 for PChange, ChanAT, or Wheel
	;Wheel events: entire Wheel value in Param2 - the function splits it into two bytes
	/*
		If (EventType = "NoteOn" OR EventType = "N1")
			MidiStatus := 143 + Channel
		Else If (EventType = "NoteOff" OR EventType = "N0")
			MidiStatus := 127 + Channel
		Else If (EventType = "CC")
			MidiStatus := 175 + Channel
		Else If (EventType = "PolyAT"  OR EventType = "PA")
			MidiStatus := 159 + Channel
		Else If (EventType = "ChanAT"  OR EventType = "AT")
			MidiStatus := 207 + Channel
		Else If (EventType = "PChange" OR EventType = "PC")
			MidiStatus := 191 + Channel
		Else If (EventType = "Wheel"   OR EventType = "W") {
			MidiStatus := 223 + Channel
			Param2 := Param1 >> 8      ; MSB of wheel value
			Param1 := Param1 & 0x00FF  ; strip MSB
		}
	*/
	result := DllCall("winmm.dll\midiOutShortMsg", UInt,h_midiout, UInt, MidiStatus|(Param1<<8)|(Param2<<16), UInt)
	If (result or ErrorLevel)  {
		MsgBox There was an Error Sending the midi event: (%result%`, %ErrorLevel%)
		Return -1
	}
}


midiOutLongMsg(h_midiout, p_Address,  MsgSize) ; thanmks Dorlf68 for this function
{
	MHDR_DONE := 0x1       /* done bit */
	MHDR_PREPARED := 0x2       /* set if header prepared */
	MHDR_INQUEUE := 0x4       /* reserved for driver */
	MHDR_ISSTRM := 0x8
	
	;If I'm reading this right, I need 36 bytes to hold the MIDIHDR Structure.
	Global MIDIHDR      ; other functions can access MIDIHDR
	VarSetCapacity(MIDIHDR, 36, 0)
	PokeInt(p_Address,&MIDIHDR) ;p_Address is the address in memory where the buffer starts.
	PokeInt(MsgSize,    &MIDIHDR+4)
	PokeInt(MsgSize,    &MIDIHDR+8) ; remaining props can all be 0
	
	result := DllCall("winmm.dll\midiOutPrepareHeader", UInt,h_midiout, UInt,&MIDIHDR, UInt,36, UInt) ; 36 = size of header
	If (result)  {
		progress, off
		MsgBox Error %result% in midiOutPrepareHeader
		
		Return -1
     }
	
	
	result := DllCall("winmm.dll\midiOutLongMsg",UInt,h_midiout,UInt,&MIDIHDR,UInt,36,UInt)
	If (result or ErrorLevel)  {
		er:= result . "," . ErrorLevel
		progress, off
          msgbox OutputlongMsg error %er%
		Return er
	}      
	; sleep 30 ; I'm not getting a wait for data using the dwFlag, so this has been working to make it reliable.
	
	result := DllCall("winmm.dll\midiOutUnprepareHeader", UInt,h_midiout, UInt,&MIDIHDR, UInt,36, UInt)
	If (result) {
		progress, off
		MsgBox Error %result% in midiOutUnprepareHeader
		Return -1
     }   
	
	Return 0
}


midiOutClose(h_midiout) {  ; Close MidiOutput
	Loop 9 {
		result := DllCall("winmm.dll\midiOutClose", UInt,h_midiout)
		If !(result or ErrorLevel)
			Return
		Sleep 250
	}
	MsgBox Error in closing the midi output port. There may still be midi events being Processed.
	Return -1
}

;UTILITY FUNCTIONS
MidiOutGetNumDevs() { ; Get number of midi output devices on system, first device has an ID of 0
	Return DllCall("winmm.dll\midiOutGetNumDevs")
}

MidiOutNameGet(uDeviceID = 0) { ; Get name of a midiOut device for a given ID
	/*
    ;MIDIOUTCAPS struct
    ;    WORD      wMid;
    ;    WORD      wPid;
    ;    MMVERSION vDriverVersion;
    ;    CHAR      szPname[MAXPNAMELEN];
    ;    WORD      wTechnology;
    ;    WORD      wVoices;
    ;    WORD      wNotes;
    ;    WORD      wChannelMask;
	;    DWORD     dwSupport;
	*/
	VarSetCapacity(MidiOutCaps, 50, 0)  ; allows for szPname to be 32 bytes
	OffsettoPortName := 8, PortNameSize := 32
	result := DllCall("winmm.dll\midiOutGetDevCapsA", UInt,uDeviceID, UInt,&MidiOutCaps, UInt,50, UInt)
	
	If (result OR ErrorLevel) {
		MsgBox Error %result% (ErrorLevel = %ErrorLevel%) in retrieving the name of midi output %uDeviceID%
		Return -1
	}
	
	VarSetCapacity(PortName, PortNameSize)
	DllCall("RtlMoveMemory", Str,PortName, Uint,&MidiOutCaps+OffsettoPortName, Uint,PortNameSize)
	Return PortName
}

MidiOutsEnumerate() { ; Returns number of midi output devices, creates global array MidiOutPortName with their names
	local NumPorts, PortID
	MidiOutPortName =
	NumPorts := MidiOutGetNumDevs()
	
	Loop %NumPorts% {
		PortID := A_Index -1
		MidiOutPortName%PortID% := MidiOutNameGet(PortID)
	}
	Return NumPorts
}

UInt@(ptr) {
	Return *ptr | *(ptr+1) << 8 | *(ptr+2) << 16 | *(ptr+3) << 24
}

PokeInt(p_value, p_address) { ; Windows 2000 and later
	DllCall("ntdll\RtlFillMemoryUlong", UInt,p_address, UInt,4, UInt,p_value)
}


; NOTHING USED BELOW HERE
; ----------------------------------------------------------------------------------------------------------------



;#include display_setup_gui.ahk   ; display showing activity on the gui
;#include faders.ahk
;#include vpots.ahk
;#include buttons.ahk
;#include auto_daw.ahk


;******* not used with reaper
/*
;*************************************************
;* 			AUTODAW LABEL
;*		Tests win title exists
	;*************************************************
	
	autodaw:
	
	SetTitleMatchMode, 2
	IfWinExist, REAPER
	{
			;settimer, autodaw, off
		;daw		  = REAPER
		Section 	  = REAPER
		vpot_Sends    = null ; fix this to be what it should from before... i messed with it... need to change it back.
		vpot_plugins  = null
		vpot_Returns  = null
		vpot_eq		  = null
		Gosub, auto_daw
	; MsgBox, 0, , reaper, 1
	}
	;/*
	IfWinExist, Live ;change to live
	{
		;settimer, autodaw, off
		Section		 = Live
		vpot_eq		 = null
		vpot_Sends   = Send
		vpot_plugins = plugin
		vpot_Returns = Returns
		;MsgBox, 0, , live, 1
		Gosub, auto_daw
	}
	IfWinExist, Cubase
	{
		;settimer, autodaw, off
		Section = Cubase
		vpot_eq		= eq
		vpot_Sends    = Send
		vpot_plugins 	= plugin
		vpot_Returns 	= null
		;MsgBox, 0, , cubase, 1
		Gosub, auto_daw
	}
	IfWinExist, Nuendo
	{
		;settimer, autodaw, off
		Section = Nuendo
		vpot_eq		= eq
		vpot_Sends    = Send
		vpot_plugins 	= plugin
		vpot_Returns 	= null
		;	  MsgBox, 0, , Nuendo, 1
		Gosub, auto_daw
	}
	IfWinExist, Trackiton
	{
		;settimer, autodaw, off
		Section = Tracktion
		vpot_eq		= eq
		vpot_Sends    = Send
		vpot_plugins 	= plugin
		vpot_Returns 	= null
		;MsgBox, 0, , Tracktion, 1
		Gosub, auto_daw
	}
	IfWinExist, Adobe Audition
	{
		Section 	= AdobeAudition
		vpot_eq		= eq
		vpot_Sends  = Send
		vpot_plugins= plugin
		vpot_Returns= null
		;MsgBox, 0, , Tracktion, 1
		Gosub, auto_daw
	}
	IfWinExist, Sonar
	{
		Section 	= Sonar
		vpot_eq		= eq
		vpot_Sends  = Send
		vpot_plugins= plugin
		vpot_Returns= null
		;MsgBox, 0, , Tracktion, 1
		Gosub, auto_daw
	}
	
	;*/
	Return
	
;*************************************************
;* 				AUTO_DAW LABEL
;*		turns the autodaw timer off
;*		Looks for daw window, if not detected 
;*				will close
	;*************************************************
	
	/*  ; this section not currently used.
	
	auto_daw:
	SetTimer, autodaw, off
	SetTitleMatchMode, 2
	
	WinSetTitle, %version%, ,%version% + %Section%
	
	;sleep, 100
	SetTimer, dawClose, 3000 ; Check to see of previous daw select is still active
	;gui, 6: destroy
	;gosub, showgui
	;WinSetTitle, , , %version% %section%
	;
	;gui, 6: destroy
	;gosub, showgui
	
	;Gui, 6: Show, x%winX% y%winY% w232 NoActivate
	
	;/*
	THIS IS WHERE TO ADD MORE THINGS TO LOAD FROM AUTODAW.INI
	;*/
	IniRead, pans, auto_daw.ini, %Section%, pans
	IniRead, Sends, auto_daw.ini, %Section%, Sends
	IniRead, plugins, auto_daw.ini, %Section%, plugins
	IniRead, Return_s, auto_daw.ini, %Section%, Return_s
	IniRead, Shift, auto_daw.ini, %Section%, Shift
	IniRead, alt, auto_daw.ini, %Section%, alt
	IniRead, Control, auto_daw.ini, %Section%, Control
	IniRead, option, auto_daw.ini, %Section%, option
	IniRead, pageleft, auto_daw.ini, %Section%, pageleft
	IniRead, pageRight, auto_daw.ini, %Section%, pageRight
	IniRead, undo, auto_daw.ini, %Section%, undo
	IniRead, redo, auto_daw.ini, %Section%, redo
	IniRead, loop, auto_daw.ini, %Section%, loop
	IniRead, eq, auto_daw.ini, %Section%, eq
	IniRead, zerodb, auto_daw.ini, %Section%, zerodb
	
	;MsgBox %zerodb%
	;/*
	PULL FROM HERE TO GET NEW VARS TO ENTER 
	
	iniread, pans, auto_daw.ini, %section%, pans
	iniread, sends, auto_daw.ini, %section%, sends
	iniread, plugins, auto_daw.ini, %section%, plugins
	iniread, returns, auto_daw.ini, %section%, returns
	iniread, shift, auto_daw.ini, %section%, shift
	iniread, alt, auto_daw.ini, %section%, alt
	iniread, control, auto_daw.ini, %section%, control
	iniread, pageleft, auto_daw.ini, %section%, pageleft
	iniread, pageright, auto_daw.ini, %section%, pageright
	iniread, undo, auto_daw.ini, %section%, undo
	iniread, redo, auto_daw.ini, %section%, redo
	iniread, loop, auto_daw.ini, %section%, loop
	iniread, eq, auto_daw.ini, %section%, eq
	
	;*/
	
	Return
	
;*************************************************
;* 			 DAW CLOSE LABEL
	;*************************************************
	
	dawclose:
	SetTitleMatchMode, 2
	IfWinNotExist, %Section%,  , %version%
	{
		SetTimer, dawClose, off
		MsgBox, 262144, Exit %version%, %Section% was Closed!`n%version% will now Exit`, automatically in 2 Seconds., 2
		gosub, guiclose
	}
	Return
	
*/

;*************************************************
;*       old switch code for ch sel and vsel   
;*************************************************
/*
	Lwin & f1:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=1 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f2:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=2 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f3:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=3 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f4:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=4 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f5:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=5 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f6:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=6 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f7:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=7 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f8:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=8 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
; ----------- FUNCTIONS FOR CHAN SELECT AND VPOT SELECT keys above -----------
	;They work mute section above and the functions contained in the mute section
	
	ChSel:        	; mute function forSend hotkey for original function
	;Note  = 42  ; %pans%var defined in SelectDaw function at line 10 (this file) ;; NOTE FOR LIVE,
	mutemode = ChSel 			; SET MUTEMODE TO SOLO
	MFMutes(mutemode)
	mutemode = mute 			; set mode back to mute
	Return
	vSel:
	mutemode = vSel			; SET MUTEMODE TO SOLO
	MFMutes(mutemode)
	mutemode = mute			; set mode back to mute
	Return
; ---------------END CH/VPOT SELECTS ---------------
*/

/* 
	Lwin & f1:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=1 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f2:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=2 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f3:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=3 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f4:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=4 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f5:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=5 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f6:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=6 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f7:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=7 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
	Lwin & f8:: ; vpot mode SWITCHING FOR PAN Send AND Plugin FOR LIVE
	{
		CountPresses("ChSel","vSel","null") ; use $ with a KEY0 Label, or #UseHook
		Note_Num :=8 ; SET BASE NOTE FOR WHAT NEEDS TO BE.
	}
	Return
; ----------- FUNCTIONS FOR CHAN SELECT AND VPOT SELECT keys above -----------
	;They work mute section above and the functions contained in the mute section
	
	ChSel:        	; mute function forSend hotkey for original function
	;Note  = 42  ; %pans%var defined in SelectDaw function at line 10 (this file) ;; NOTE FOR LIVE,
	mutemode = ChSel 			; SET MUTEMODE TO SOLO
	MFMutes(mutemode)
	mutemode = mute 			; set mode back to mute
	Return
	vSel:
	mutemode = vSel			; SET MUTEMODE TO SOLO
	MFMutes(mutemode)
	mutemode = mute			; set mode back to mute
	Return
	; ---------------END CH/VPOT SELECTS ---------------
	
*/

/*
	SECTION MOVED TO MIDI IN PROCESS.AHK
; ------- MUTE FUNCTIONS ------------
; MADE SO THAT MULTIPLE ARMS CAN BE SELECTED AND MULTIPLE SOLOS WITH OUT PRESSING MODIFIER KEYS
	; WHICH FUNCITON TO RUN BASED ON HOW MANY TIMES THE KEY WAS PRESSED
	Mute:        	; mute function forSend hotkey for original function
	mutemode = mute
	MFMutes(mutemode)		; CALCULATE NOTE Number SO Send BASED ON FUNCTION, MFMutes, just below this Section
	Return
	Solo:
	mutemode = solo			; SET MUTEMODE TO SOLO
	midiOutShortMsg(h_midiout, 144, 72, 127) ; "N1" = "NoteOn"  Control key
	MFMutes(mutemode)
	midiOutShortMsg(h_midiout, 128, 72, 0) ; "n0" = "NOTE OFF "Control key
	mutemode = mute			; set mode back to mute
	Return
	Arm:
	mutemode = arm
	midiOutShortMsg(h_midiout, 144, 72, 127) ; "N1" = "NoteOn"  Control key
	MFMutes(mutemode)
	midiOutShortMsg(h_midiout, 128, 72, 0) ; "n0" = "NOTE OFF "Control key
	mutemode = mute ; changing back to mute mode
	Return
	
	MFMutes(mutemode) ; Function to send out the correct note from above based on mode MULTI MUTES
	{
		;MsgBox,32,, %mutemode%, 3	; debugging
		global note_num, h_midiout, h_midiout2
		If mutemode = mute ; MUTE
			
		{
			note :=	note_num + 15
			midiOutShortMsg(h_midiout, 144 , note, byte2) ; function in main file to Sendnotes
		}
		
		Else If mutemode = solo ; SOLO
		{
			note :=	note_num + 7
			midiOutShortMsg(h_midiout, 144 , note, byte2)
		}
		Else If mutemode = arm ;ARM
		{
			note :=	note_num - 1
			midiOutShortMsg(h_midiout, 144 , note, byte2)
		}
		Else If mutemode = ChSel ; Ch SEL  CALL WITH THE DOUBLE TAP KEY DEFS BELOW
		{
			note :=	note_num + 23
			midiOutShortMsg(h_midiout, 144 , note, byte2)
		}
		Else If mutemode = vSel ; Vpot Select  CALL WITH THE DOUBLE TAP KEY DEFS BELOW
		{
			note :=	note_num + 31
			midiOutShortMsg(h_midiout, 144 , note, byte2)
		}
	}
	Return
*/

;*************************************************
;* 				JOG SPEED SETTING - not currently used
;*************************************************
/*
	; COMMENT THIS OUT FOR REAPER
	LAlt & F9::	 ; Jog Speed Setting THINK ABOUT A DIFFERENT KEY MAKE F11 SAVE OR SOMETHING
	if Section != REAPER
	{
		JSpeedSetting := JSpeedSetting + 1
		IfGreater, JSpeedSetting, 3
		{
			JSpeedSetting := 1 ; SO IT WRAPS ARound, INCREASING
		}
		;MsgBox, 0, , %JSpeedSetting%, 2 ; debugging only
		JSetSpeed(JSpeedSetting) ; SEE below
	}
	if Section = REAPER
	{
	;do nothing
	}
	Return
	
	JSetSpeed(JSpeedSetting)
	{
		RelativeUp 	:= 1   		; Relative midi data for up is value 1
		RelativeDown := 65  	; Relative midi data for down is value 65
		global JogUpVal , JogDownVal , Jspeedname, Jspeed
		
		If JSpeedSetting = 1 	; BASED ON THE ABOVE Hotkey, WHAT THIS VALUE WILL BE.
		{
			JogUpVal  	:= 1  		; UP VALUE TO Send WITH EACH KEY PRESS.
			JogDownVal  := 65 		; DOWN VALUE TO Send WITH EACH KEY PRESS.
			JSpeedName := "jFine" ; NAME OF SPEED SETTING, SHOWS UP ON Gui
		}
		Else If JSpeedSetting = 2
		{
			JogUpVal  	:= (RelativeUp + 4)
			JogDownVal  := (RelativeDown + 4)
			JSpeedName := "jMed"
		}
		Else If JSpeedSetting = 3
		{
			JogUpVal  	:= (RelativeUp + 10)
			JogDownVal  := (RelativeDown + 10)
			JSpeedName := "jFast"
		}
		Gosub, ShowUpdateGui
	;GuiControl,6:, Jspeed, %JSpeedName%
	}
	Return
	
*/
;*************************************************
;* 			VPOT SPEED SETTING - not currently used.
;*************************************************
/*
	LControl & f9:: ;vpot speed adjustment/depot bank
	VSpeedSetting := VSpeedSetting + 1 ; increase by 1
	IfGreater, VSpeedSetting, 3 ; Number of settings
	{
		VSpeedSetting := 1 ; SO IT WRAPS ARound, INCREASING
	}
	VSetSpeed(VSpeedSetting) ; see FUNCTION VStetSpeed near bottom
	Return
	
	VSetSpeed(VSpeedSetting)
	{
		RelativeUp   := 1   	; Relative midi data for up is value 1
		RelativeDown := 65  	; Relative midi data for down is value 65
		
		global RelUp, RelDown, VSpeedName, vspeed
		
		If VSpeedSetting = 1
		{
			RelUp := 1
			RelDown := 65
			VSpeedName := "vFine" ; VERY FINE Control OF VPOT
		}
		;Else If VSpeedSetting = 2
		;	{
		;		RelUp 	:= (RelativeUp + 2)
		;		RelDown := (RelativeDown + 2)
		;		VSpeedName := "Fine"  ; FINE Control, A LITTLE FASTER THAN  1
		;	}
		Else If VSpeedSetting = 2
		{
			RelUp 	:= (RelativeUp + 5)
			RelDown := (RelativeDown + 5)
			VSpeedName := "vMed"	; PRETTY FAST AND COMFORTABLE FOR COARSE AJDUSTMENTS
		}
		Else If VSpeedSetting = 3
		{
			RelUp 	:= (RelativeUp + 10)
			RelDown := (RelativeDown + 10)
			VSpeedName := "vFast"	; MOVING FAST NOW...
		}
		;Else if VSpeedSetting = 5
		;{
		;Sleeptime := 5
		;	RelUp 	:= (RelativeUp + 10)
		;	RelDown := (RelativeDown + 10)
		;	VSpeedName := "V-Zip"	;OMG THIS IS WAY FAST.
		;}
		Gosub, ShowUpdateGui
	;GuiControl,6:, Vspeed, %VSpeedName%
	}
	Return
*/


;*************************************************
;* 				FADER SPEED SETTING - not currently used.
;*************************************************
/*
	LShift & f9::     ; Sets the fader speed setting
	
	SpeedSetting := SpeedSetting + 1
	IfGreater, SpeedSetting, 3
	{
		SpeedSetting := 1
	}
	SetSpeed(SpeedSetting) ; see bottom of this file.
	Return
	
	SetSpeed(SpeedSetting)
	{
		global PBdelta, SpeedName, Fspeed
		
		If SpeedSetting = 1
		{
			PBdelta = 32
			SpeedName := "F-Slow"
		}
		If SpeedSetting = 2
		{
			PBdelta := 64
			SpeedName := "fFine"
		}
		Else If SpeedSetting = 3
		{
			PBdelta = 256 ;303
			SpeedName := "fMed"
		}
		;Else If SpeedSetting = 4
		;	{
		;		PBdelta = 512
		;		SpeedName := "fFast"
		;	}
		Gosub, ShowUpdateGui
	;GuiControl,6:, Fspeed, %SpeedName% ; update the display gui
	}
	Return
*/
