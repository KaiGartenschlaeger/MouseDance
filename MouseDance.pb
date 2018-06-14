XIncludeFile #PB_Compiler_Home + "Include\window.pbi"
XIncludeFile #PB_Compiler_Home + "Include\windowex.pbi"
XIncludeFile #PB_Compiler_Home + "Include\directory.pbi"

EnableExplicit

Enumeration
  #Win_Main
EndEnumeration

Enumeration
  #G_BN_Main_Record
  #G_BN_Main_Play
  #G_BN_Main_Save
  #G_BN_Main_Open
  #G_BN_Main_Info
  #G_FR_Main_Info
  #G_TX_Main_InfoTime
  #G_TX_Main_InfoEvents
  #G_FR_Main_Record
  #G_CH_Main_MouseButton
  #G_CH_Main_Keyboard
  #G_CH_Main_Replay
EndEnumeration

Enumeration
  #Timer_Main
EndEnumeration

Enumeration
  #RType_None
  #RType_Mouse_Move
  #RType_Mouse_LButtonDown
  #RType_Mouse_LButtonUp
  #RType_Mouse_MButtonDown
  #RType_Mouse_MButtonUp
  #RType_Mouse_RButtonDown
  #RType_Mouse_RButtonUp
  #RType_Keyboard_KeyDown
  #RType_Keyboard_KeyUp
EndEnumeration

#AppName = "MouseDance"
#AppVers = 100

Structure _WinLoop
  WindowEvent.i
  EventWindow.i
  EventGadget.i
  EventMenu.i
  EventType.i
  EventTimer.i
  EventlParam.i
  EventwParam.i
  ActiveWindow.i
  ActiveGadget.i
EndStructure
Global Event._WinLoop

Structure _RecordData
  Time.i
  Type.b
  iParam1.i
  iParam2.i
EndStructure
Global NewList RecordData._RecordData()

Structure _Record
  Active.b
  Cancel.b
  StartTime.i
EndStructure
Global Record._Record

Structure _Play
  Active.b
  StartTime.i
  Thread.i
  Cancel.b
EndStructure
Global Play._Play

Structure _Pref
  RecordMouseButtons.b
  RecordKeyboard.b
  Replay.b
EndStructure
Global Pref._Pref

Structure KBDLLHOOKSTRUCT
  vkCode.i
  scanCode.i
  flags.i
  time.i
  dwExtraInfo.i
EndStructure

Global _GT_DevCaps.TIMECAPS

Global iMouseHook.i
Global iKeyboardHook.i

Global iMutex.i

Procedure.s TimeString(Miliseconds.q, Seperator.s = "")
  Protected qHours.q, qMinutes.q, qSeconds.q, sResult.s

  If Miliseconds < 0 : Miliseconds = 0 : EndIf
  Seperator = Trim(Seperator)
  If Seperator = "" Or Len(Seperator) > 1 : Seperator = ":" : EndIf

  qSeconds = Miliseconds / 1000
  qMinutes = qSeconds / 60
  qSeconds = qSeconds - (qMinutes * 60)
  qHours   = qMinutes / 60
  qMinutes = qMinutes - (qHours * 60)

  If qHours < 10
    sResult + RSet(Str(qHours), 2, "0")
  Else
    sResult + Str(qHours)
  EndIf

  sResult + Seperator
  sResult + RSet(Str(qMinutes), 2, "0")
  sResult + Seperator
  sResult + RSet(Str(qSeconds), 2, "0")

  ProcedureReturn sResult
EndProcedure

Procedure.s PointedNumber(Size.q)
  If Size > 999
    Protected lNext.l, sSize.s = Str(Size), sTemp.s, sResult.s
    For lNext = 1 To Len(sSize)
      sResult = Mid(sSize, Len(sSize) - lNext + 1, 1)
      If lNext % 3 = 0 And lNext <> Len(sSize)
        sResult = "." + sResult
      EndIf
      sTemp = sResult + sTemp
    Next
    ProcedureReturn sTemp
  Else
    ProcedureReturn Str(Size)
  EndIf
EndProcedure

Procedure InitGameTimer()
  SetPriorityClass_(GetCurrentProcess_(), #HIGH_PRIORITY_CLASS)
  timeGetDevCaps_(_GT_DevCaps, SizeOf(TIMECAPS))
  timeBeginPeriod_(_GT_DevCaps\wPeriodMin)
EndProcedure

Procedure StopGameTimer()
  timeEndPeriod_(_GT_DevCaps\wPeriodMin)
EndProcedure

Procedure OpenWindow_Main()
  If OpenWindow(#Win_Main, 0, 0, 280, 152, #AppName, #PB_Window_SystemMenu|#PB_Window_MinimizeGadget|#PB_Window_ScreenCentered|#PB_Window_Invisible)
    Frame3DGadget(#G_FR_Main_Info, 93, 5, 180, 50, "Info")
    TextGadget(#G_TX_Main_InfoTime, 105, 20, 150, 15, "", #SS_CENTERIMAGE|#SS_LEFTNOWORDWRAP)
    TextGadget(#G_TX_Main_InfoEvents, 105, 35, 150, 15, "", #SS_CENTERIMAGE|#SS_LEFTNOWORDWRAP)
    Frame3DGadget(#G_FR_Main_Record, 93, 60, 180, 65, "Aufnahme von")
    CheckBoxGadget(#G_CH_Main_MouseButton, 105, 80, 150, 15, "Mausknöpfe")
    CheckBoxGadget(#G_CH_Main_Keyboard, 105, 97, 150, 15, "Tastatur")
    CheckBoxGadget(#G_CH_Main_Replay, 93, 131, 150, 15, "Wiedergabe wiederholen")
    ButtonGadget(#G_BN_Main_Record, 5, 5, 80, 25, "Aufnahme")
    ButtonGadget(#G_BN_Main_Play, 5, 32, 80, 25, "Wiedergabe")
    ButtonGadget(#G_BN_Main_Save, 5, 59, 80, 25, "Speichern")
    ButtonGadget(#G_BN_Main_Open, 5, 86, 80, 25, "Öffnen")
    ButtonGadget(#G_BN_Main_Info, 5, 121, 80, 25, "Info")

    WndEx_AddWindow(#Win_Main)

    EnableWindowDrop(#Win_Main, #PB_Drop_Files, #PB_Drag_Copy)

    AddWindowTimer(#Win_Main, #Timer_Main, 250)
  Else
    MessageRequester("Fehler", "Fenster 'Main' konnte nicht erstellt werden", #MB_OK|#MB_ICONERROR) : End
  EndIf
EndProcedure

Procedure MouseHook(nCode, wParam, lParam)
  If Record\Active
    If nCode = #HC_ACTION
      Protected *MHS.MOUSEHOOKSTRUCT = lParam

      Select wParam
        ; Move
        Case #WM_MOUSEMOVE
          AddElement(RecordData())
          RecordData()\Time    = timeGetTime_() - Record\StartTime
          RecordData()\Type    = #RType_Mouse_Move
          RecordData()\iParam1 = *MHS\pt\x
          RecordData()\iParam2 = *MHS\pt\y
        ; Left Button
        Case #WM_LBUTTONDOWN
          If Pref\RecordMouseButtons
            AddElement(RecordData())
            RecordData()\Time    = timeGetTime_() - Record\StartTime
            RecordData()\Type    = #RType_Mouse_LButtonDown
            RecordData()\iParam1 = *MHS\pt\x
            RecordData()\iParam2 = *MHS\pt\y
          EndIf
        Case #WM_LBUTTONUP
          If Pref\RecordMouseButtons
            AddElement(RecordData())
            RecordData()\Time    = timeGetTime_() - Record\StartTime
            RecordData()\Type    = #RType_Mouse_LButtonUp
            RecordData()\iParam1 = *MHS\pt\x
            RecordData()\iParam2 = *MHS\pt\y
          EndIf
        ; Right Button
        Case #WM_RBUTTONDOWN
          If Pref\RecordMouseButtons
            AddElement(RecordData())
            RecordData()\Time    = timeGetTime_() - Record\StartTime
            RecordData()\Type    = #RType_Mouse_RButtonDown
            RecordData()\iParam1 = *MHS\pt\x
            RecordData()\iParam2 = *MHS\pt\y
          EndIf
        Case #WM_RBUTTONUP
          If Pref\RecordMouseButtons
            AddElement(RecordData())
            RecordData()\Time    = timeGetTime_() - Record\StartTime
            RecordData()\Type    = #RType_Mouse_RButtonUp
            RecordData()\iParam1 = *MHS\pt\x
            RecordData()\iParam2 = *MHS\pt\y
          EndIf
        ; MiddleButton
        Case #WM_MBUTTONDOWN
          If Pref\RecordMouseButtons
            AddElement(RecordData())
            RecordData()\Time    = timeGetTime_() - Record\StartTime
            RecordData()\Type    = #RType_Mouse_MButtonDown
            RecordData()\iParam1 = *MHS\pt\x
            RecordData()\iParam2 = *MHS\pt\y
          EndIf
        Case #WM_MBUTTONUP
          If Pref\RecordMouseButtons
            AddElement(RecordData())
            RecordData()\Time    = timeGetTime_() - Record\StartTime
            RecordData()\Type    = #RType_Mouse_MButtonUp
            RecordData()\iParam1 = *MHS\pt\x
            RecordData()\iParam2 = *MHS\pt\y
          EndIf
      EndSelect

    EndIf
  EndIf

  ProcedureReturn CallNextHookEx_(iMouseHook, nCode, wParam, lParam)
EndProcedure

Procedure KeyboardHook(nCode, wParam, lParam)
  Protected *KBBD.KBDLLHOOKSTRUCT = lParam

  ; Aufnahme / Wiedergabe abbrechen
  If wParam = #WM_KEYUP And *KBBD\vkCode = #VK_ESCAPE
    Play\Cancel = 1

    If Record\Active
      Record\Active = 0
      SetGadgetText(#G_BN_Main_Record, "Aufnahme")
      DisableGadget(#G_BN_Main_Play, 0)
    EndIf
  EndIf

  ; Aufnahme
  If Record\Active And Pref\RecordKeyboard
    Select wParam
      Case #WM_KEYUP
        AddElement(RecordData())
        RecordData()\Time    = timeGetTime_() - Record\StartTime
        RecordData()\Type    = #RType_Keyboard_KeyUp
        RecordData()\iParam1 = *KBBD\vkCode
        RecordData()\iParam2 = *KBBD\scanCode
      Case #WM_KEYDOWN
        AddElement(RecordData())
        RecordData()\Time    = timeGetTime_() - Record\StartTime
        RecordData()\Type    = #RType_Keyboard_KeyDown
        RecordData()\iParam1 = *KBBD\vkCode
        RecordData()\iParam2 = *KBBD\scanCode
    EndSelect
  EndIf

  ProcedureReturn CallNextHookEx_(iKeyboardHook, nCode, wParam, lParam)
EndProcedure

Procedure Play(*Dummy)
  Global P.POINT
  Global Dim INP.INPUT(0)
  
  Play\StartTime = timeGetTime_()
  
  ResetList(RecordData())
  While NextElement(RecordData())
    If Play\Cancel : Break : EndIf

    Repeat
      If Play\Cancel : Break : EndIf

      If timeGetTime_() - Play\StartTime >= RecordData()\Time

        Select RecordData()\Type
          Case #RType_Keyboard_KeyUp
            INP(0)\type       = #INPUT_KEYBOARD
            INP(0)\ki\dwFlags = #KEYEVENTF_KEYUP
            INP(0)\ki\wVk     = RecordData()\iParam1
            INP(0)\ki\wScan   = RecordData()\iParam2
            SendInput_(1, @INP(), SizeOf(INPUT))
          Case #RType_Keyboard_KeyDown
            INP(0)\type       = #INPUT_KEYBOARD
            INP(0)\ki\dwFlags = 0
            INP(0)\ki\wVk     = RecordData()\iParam1
            INP(0)\ki\wScan   = RecordData()\iParam2
            SendInput_(1, @INP(), SizeOf(INPUT))
          Case #RType_Mouse_Move
            SetCursorPos_(RecordData()\iParam1, RecordData()\iParam2)
          Case #RType_Mouse_LButtonDown
            INP(0)\type = #INPUT_MOUSE
            INP(0)\mi\dwFlags = #MOUSEEVENTF_LEFTDOWN
            SendInput_(1, @INP(), SizeOf(INPUT))
          Case #RType_Mouse_LButtonUp
            INP(0)\type = #INPUT_MOUSE
            INP(0)\mi\dwFlags = #MOUSEEVENTF_LEFTUP
            SendInput_(1, @INP(), SizeOf(INPUT))
          Case #RType_Mouse_MButtonDown
            INP(0)\type = #INPUT_MOUSE
            INP(0)\mi\dwFlags = #MOUSEEVENTF_MIDDLEDOWN
            SendInput_(1, @INP(), SizeOf(INPUT))
          Case #RType_Mouse_MButtonUp
            INP(0)\type = #INPUT_MOUSE
            INP(0)\mi\dwFlags = #MOUSEEVENTF_MIDDLEUP
            SendInput_(1, @INP(), SizeOf(INPUT))
          Case #RType_Mouse_RButtonDown
            INP(0)\type = #INPUT_MOUSE
            INP(0)\mi\dwFlags = #MOUSEEVENTF_RIGHTDOWN
            SendInput_(1, @INP(), SizeOf(INPUT))
          Case #RType_Mouse_RButtonUp
            INP(0)\type = #INPUT_MOUSE
            INP(0)\mi\dwFlags = #MOUSEEVENTF_RIGHTUP
            SendInput_(1, @INP(), SizeOf(INPUT))
        EndSelect

        Break
      EndIf
      
      Delay(2)
    ForEver

  Wend
EndProcedure

Procedure StartPlay()
  If Record\Active = 0
    If Play\Active
      ; Wiedergabe Anhalten
      Play\Active = 0

      SetGadgetText(#G_BN_Main_Play, "Wiedergabe")
      DisableGadget(#G_BN_Main_Record, 0)
    Else
      ; Wiedergabe Starten
      If ListSize(RecordData()) > 0 And IsThread(Play\Thread) = 0
        Play\Active     = 1
        Play\Cancel     = 0
        Play\StartTime  = timeGetTime_()

        Play\Thread     = CreateThread(@Play(), 0)

        SetGadgetText(#G_BN_Main_Play, "Anhalten")
        DisableGadget(#G_BN_Main_Record, 1)
      EndIf
    EndIf
  EndIf
EndProcedure

Procedure OpenRecord(File$ = "", ShowRequester = 1)
  If Play\Active = 0 And Record\Active = 0
    Protected iFile.i, sFile.s
    Protected iContentCount.i, iNext.i

    If File$ = ""
      sFile = OpenFileRequester("Aufnahme Öffnen", GetCurrentDirectory(), "Aufnahme (*.rec)|*.rec|Alle Dateien|*.*", 0)
    Else
      sFile = File$
    EndIf

    If sFile
      iFile = ReadFile(#PB_Any, sFile)
      If iFile

        If ReadCharacter(iFile) = 'M' And ReadCharacter(iFile) = 'D' And ReadCharacter(iFile) = 'F' And ReadByte(iFile) = 1

          iContentCount = ReadInteger(iFile)
          If iContentCount > 0

            For iNext = 0 To iContentCount - 1
              AddElement(RecordData())
              RecordData()\Time = ReadInteger(iFile)
              RecordData()\Type = ReadByte(iFile)
              RecordData()\iParam1 = ReadInteger(iFile)
              RecordData()\iParam2 = ReadInteger(iFile)
            Next

            LastElement(RecordData())
            SetGadgetText(#G_TX_Main_InfoTime, TimeString(RecordData()\Time))
            SetGadgetText(#G_TX_Main_InfoEvents, PointedNumber(ListSize(RecordData())))

          Else
            If ShowRequester
              MessageRequester("Warnung", "Es konnten keine Inhalte gefunden werden.", #MB_OK|#MB_ICONEXCLAMATION)
            EndIf
          EndIf

        Else
          If ShowRequester
            MessageRequester("Ungültige Datei", "Die Datei '" + GetFilePart(sFile) + "' ist keine gültige Datei.", #MB_OK|#MB_ICONEXCLAMATION)
          EndIf
        EndIf

        CloseFile(iFile)
      Else
        If ShowRequester
          MessageRequester("Fehler", "Datei '" + GetFilePart(sFile) + "' konnte nicht geöffnet werden.", #MB_OK|#MB_ICONERROR)
        EndIf
      EndIf

    EndIf

  EndIf
EndProcedure

Procedure OpenRecordDrop()
  Protected sFile.s

  sFile = EventDropFiles()
  If sFile

    sFile = StringField(sFile, 1, #LF$)

    OpenRecord(sFile, 0)
  EndIf
EndProcedure

Procedure OpenRecordProgramParameter()
  Protected sFile.s

  sFile = ProgramParameter()
  If sFile
    OpenRecord(sFile)

    StartPlay()
  EndIf
EndProcedure

Procedure SaveRecord()
  If ListSize(RecordData()) > 0 And Play\Active = 0 And Record\Active = 0
    Protected iFile.i, sFile.s

    sFile = SaveFileRequester("Aufnahme Speichern", GetCurrentDirectory() + "Aufnahme.rec", "Aufnahme (*.rec)|*.rec|Alle Dateien|*.*", 0)
    If sFile

      ; Add Extension
      If SelectedFilePattern() = 0 And GetExtensionPart(sFile) = ""
        sFile + ".rec"
      EndIf

      ; Overwrite
      If FileSize(sFile) > 0
        If MessageRequester("Datei Überschreiben", "Die Datei " + GetFilePart(sFile) + " existiert bereits, soll die Datei überschrieben werden?", #MB_YESNO|#MB_ICONEXCLAMATION) = #IDNO
          ProcedureReturn 0
        EndIf
      EndIf

      iFile = CreateFile(#PB_Any, sFile)
      If iFile

        WriteCharacter(iFile, 'M') ; Control String
        WriteCharacter(iFile, 'D')
        WriteCharacter(iFile, 'F')

        WriteByte(iFile, 1) ; File Version

        WriteInteger(iFile, ListSize(RecordData()))
        ForEach RecordData()
          WriteInteger(iFile, RecordData()\Time)
          WriteByte(iFile,    RecordData()\Type)
          WriteInteger(iFile, RecordData()\iParam1)
          WriteInteger(iFile, RecordData()\iParam2)
        Next

        CloseFile(iFile)

      Else
        MessageRequester("Fehler", "Datei '" + GetFilePart(sFile) + "' konnte nicht erstellt werden.", #MB_OK|#MB_ICONERROR)
      EndIf
    EndIf

  EndIf
EndProcedure

Procedure Preferences_Open()
  OpenPreferences(AppDataDirectory() + "MouseDance\config.ini")

  PreferenceGroup("Main")
  ResizeWindow(#Win_Main, ReadPreferenceInteger("WinX_Main", Window_GetDesktopCenterPos(#Win_Main, 1)), ReadPreferenceInteger("WinY_Main", Window_GetDesktopCenterPos(#Win_Main, 2)), #PB_Ignore, #PB_Ignore)
  Window_CheckPos(#Win_Main)

  If ReadPreferenceInteger("RecordMouseButtons", 1)
    SetGadgetState(#G_CH_Main_MouseButton, 1)
    Pref\RecordMouseButtons = 1
  EndIf
  If ReadPreferenceInteger("RecordKeyboard", 1)
    SetGadgetState(#G_CH_Main_Keyboard, 1)
    Pref\RecordKeyboard = 1
  EndIf
  If ReadPreferenceInteger("Replay", 0)
    SetGadgetState(#G_CH_Main_Replay, 1)
    Pref\Replay = 1
  EndIf

  ClosePreferences()
EndProcedure

Procedure Preferences_Save()
  CreateDirectory(AppDataDirectory() + "MouseDance\")

  If CreatePreferences(AppDataDirectory() + "MouseDance\config.ini")
    PreferenceGroup("Main")

    WritePreferenceInteger("WinX_Main", WindowX(#Win_Main))
    WritePreferenceInteger("WinY_Main", WindowY(#Win_Main))

    WritePreferenceInteger("RecordMouseButtons", GetGadgetState(#G_CH_Main_MouseButton))
    WritePreferenceInteger("RecordKeyboard",     GetGadgetState(#G_CH_Main_Keyboard))
    WritePreferenceInteger("Replay",             GetGadgetState(#G_CH_Main_Replay))

    ClosePreferences()
  EndIf
EndProcedure

Procedure EndApplication()
  Preferences_Save()

  CloseHandle_(iMutex)

  StopGameTimer()

  End
EndProcedure

Procedure Timer_Main()

  ; Aufnahme
  If Record\Active
    Protected sTemp.s

    sTemp = TimeString(timeGetTime_() - Record\StartTime)
    If GetGadgetText(#G_TX_Main_InfoTime) <> sTemp
      SetGadgetText(#G_TX_Main_InfoTime, sTemp)
    EndIf

    sTemp = PointedNumber(ListSize(RecordData()))
    If GetGadgetText(#G_TX_Main_InfoEvents) <> sTemp
      SetGadgetText(#G_TX_Main_InfoEvents, sTemp)
    EndIf
  EndIf

  ; Wiedergabe
  If Play\Active
    If IsThread(Play\Thread)

      sTemp = TimeString(timeGetTime_() - Play\StartTime)
      If GetGadgetText(#G_TX_Main_InfoTime) <> sTemp
        SetGadgetText(#G_TX_Main_InfoTime, sTemp)
      EndIf

      sTemp = PointedNumber(ListIndex(RecordData())) + " / " + PointedNumber(ListSize(RecordData()))
      If GetGadgetText(#G_TX_Main_InfoEvents) <> sTemp
        SetGadgetText(#G_TX_Main_InfoEvents, sTemp)
      EndIf

    Else

      Play\Active = 0
      Play\Thread = 0
      DisableGadget(#G_BN_Main_Record, 0)
      SetGadgetText(#G_BN_Main_Play, "Wiedergabe")

      LastElement(RecordData())
      SetGadgetText(#G_TX_Main_InfoTime, TimeString(RecordData()\Time))
      SetGadgetText(#G_TX_Main_InfoEvents, PointedNumber(ListSize(RecordData())))

      If Pref\Replay And Play\Cancel = 0
        StartPlay()
      EndIf

    EndIf
  EndIf

EndProcedure

Procedure WindowCallback(hWnd, Msg, wParam, lParam)
  Protected iResult.i = #PB_ProcessPureBasicEvents

  WndEx_Callback(hWnd, Msg, wParam, lParam)

  ProcedureReturn iResult
EndProcedure

Procedure Main()
  
  ; Bereits gestartet?
  iMutex = CreateMutex_(0, 0, "1B2001ED-C59D-490C-90B0-A594320E6B1E-MD")
  If GetLastError_() = #ERROR_ALREADY_EXISTS
    CloseHandle_(iMutex)
    End
  EndIf
  
  InitGameTimer()
  
  OpenWindow_Main()
  SetWindowCallback(@WindowCallback())
  
  WndEx_SetMagneticValue(15)
  
  ; MouseHook
  iMouseHook = SetWindowsHookEx_(#WH_MOUSE_LL|#WH_CALLWNDPROC, @MouseHook(), GetModuleHandle_(0), 0)
  If iMouseHook = 0
    MessageRequester("Fehler", "MouseHook konnte nicht gesetzt werden.", #MB_OK|#MB_ICONERROR)
    End
  EndIf
  ; Keyboard Hook
  iKeyboardHook = SetWindowsHookEx_(#WH_KEYBOARD_LL|#WH_CALLWNDPROC, @KeyboardHook(), GetModuleHandle_(0), 0)
  If iKeyboardHook = 0
    MessageRequester("Fehler", "KeyboardHook konnte nicht gesetzt werden.", #MB_OK|#MB_ICONERROR)
    End
  EndIf
  
  Preferences_Open()
  
  HideWindow(#Win_Main, 0)
  
  ; ProgramParameter
  OpenRecordProgramParameter()
  
  Repeat
    Event\WindowEvent = WaitWindowEvent()
    Event\EventGadget = EventGadget()
    Event\EventTimer  = EventTimer()

    Select Event\WindowEvent

      ; EventGadget
      Case #PB_Event_Gadget
        Select Event\EventGadget

          ; Record
          Case #G_BN_Main_Record
            If Record\Active
              Record\Active = 0

              SetGadgetText(#G_BN_Main_Record, "Aufnahme")
              DisableGadget(#G_BN_Main_Play, 0)
            Else
              ClearList(RecordData())

              Record\Active = 1
              Record\StartTime = timeGetTime_()

              SetGadgetText(#G_BN_Main_Record, "Anhalten")
              DisableGadget(#G_BN_Main_Play, 1)
            EndIf

            ; Play
          Case #G_BN_Main_Play
            StartPlay()

          Case #G_BN_Main_Save
            SaveRecord()
          Case #G_BN_Main_Open
            OpenRecord()
          Case #G_BN_Main_Info
            MessageRequester("Informationen", #AppName + " Version " + StrF(#AppVers/100, 2) + #CR$ + #CR$ + "Copyright©Kai Gartenschläger, 2009" + #CR$ + #CR$ + "http://www.kaisnet.de" + #CR$ + "angel-kai@hotmail.de", #MB_OK|#MB_ICONINFORMATION)

          Case #G_CH_Main_MouseButton
            Pref\RecordMouseButtons = GetGadgetState(#G_CH_Main_MouseButton)
          Case #G_CH_Main_Keyboard
            Pref\RecordKeyboard = GetGadgetState(#G_CH_Main_Keyboard)
          Case #G_CH_Main_Replay
            Pref\Replay = GetGadgetState(#G_CH_Main_Replay)

        EndSelect

        ; EventDrop
      Case #PB_Event_WindowDrop
        OpenRecordDrop()

        ; Timer
      Case #PB_Event_Timer
        Select Event\EventTimer
          Case #Timer_Main
            Timer_Main()
        EndSelect

        ; CloseWindow
      Case #PB_Event_CloseWindow
        EndApplication()

    EndSelect

  ForEver
EndProcedure

Main()
; IDE Options = PureBasic 4.40 Beta 7 (Windows - x86)
; Folding = -P9--
; EnableThread
; EnableXP
; UseIcon = icon.ico
; Executable = MouseDance.exe
; CPU = 1
; CompileSourceDirectory
; EnableCompileCount = 346
; EnableBuildCount = 87
; EnableExeConstant