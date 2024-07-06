; Created by 		CristÃ³fano Varacolaci
; For 			myself
; Version 		0.1.0.1
; Build 			01:12-2018.02.23
; Update			12:35-2018.04.16
;
;#####################################################################################
; OPTIMIZATIONS
;#####################################################################################
;http://ahkscript.org/boards/viewtopic.php?f=6&t=6413
#NoEnv
#SingleInstance Force
#KeyHistory 0
SetWorkingDir %A_ScriptDir%
Process, Priority, , H
SetBatchLines, -1
ListLines Off
SetTitleMatchMode 2
SetTitleMatchMode Fast
SetWinDelay, 0


;#####################################################################################
; GLOBAL VARIABLES
;#####################################################################################
AddressNameList :=["CHAOS", "AETHER", "CRYSTAL", "DYNAMIS", "PRIMAL"]
AdressList := ["80.239.145.6", "204.2.29.6", "204.2.29.8", "204.2.29.9", "204.2.29.7"]

;------------------------------------------
; GUI Layout
;------------------------------------------
Gui Font, s12
Gui Add, Text, x24 y12 w195 h23 +0x200, Ping Tester
Gui Font
Gui Font, s10
Gui Add, Text, x20 y50 w93 h23 +0x200 Right, PRIMAL:
Gui Add, Text, x20 y80 w93 h23 +0x200 Right, AETHER:
Gui Add, Text, x20 y110 w93 h23 +0x200 Right, CRYSTAL:
Gui Add, Text, x20 y140 w93 h23 +0x200 Right, DYAMIS:

Gui Add, Text, vPRIMAL x130 y50 w93 h23 +0x200 Left, 0 ms
Gui Add, Text, vAETHER x130 y80 w93 h23 +0x200 Left, 0 ms
Gui Add, Text, vCRYSTAL x130 y110 w93 h23 +0x200 Left, 0 ms
Gui Add, Text, vDYNAMIS x130 y140 w93 h23 +0x200 Left, 0 ms
Gui Font
Gui Add, Text, vREFRESH x35 y278 w127 h23 +0x200 Center, Refresh Time (sec)
Gui Add, Edit, x168 y278 w40 h21 +Number vDelay, 15
Gui Add, Button, x20 y315 w80 h23 gBtn_Start, &Start
Gui Add, Button, x142 y315 w80 h23 gBtn_Stop, S&top
Gui Font, s10
Gui Add, Link, x76 y355 w91 h23, <a href="https://varacolaci.com/">Varacolaci</a>
Gui Font

Gui Show, w243 h381, Ping Tester
Return

GuiEscape:
GuiClose:
ExitApp

; Do not edit above this line

;------------------------------------------
; Labels
;------------------------------------------
Btn_start:
GuiControl, Disable, Start
Gui, submit, nohide
For Index, PingTime In RoundTripTimeList(AdressList) 
{
			GuiControl, , % AddressNameList[Index], % PingTime . " ms"
		}
	if ( Delay < 5 )
		{	
			Delay := 5
			GuiControl, , Delay, 5
		}
	SetTimer, PingTimer, % Delay * 1000
	Return

Btn_Stop:
	SetTimer, PingTimer, OFF
	GuiControl, Enable, Start
	Return

;------------------------------------------
; Timers
;------------------------------------------
PingTimer:
	For Index, PingTime In RoundTripTimeList(AdressList) 
		{
			GuiControl, , REFRESH, Refreshing...
			Sleep, 400
			GuiControl, , % AddressNameList[Index], % PingTime . " ms"
			GuiControl, , REFRESH, Refresh Time (sec)
		}
	return


;------------------------------------------
; Emergency exit --------------------------
^x::ExitApp

; ==================================================================================================================================
; Function:       Ping
; Description     Determines the round trip time (sometimes called the "ping")
;					from the local machine to a list of 64 or fewer addresses.
; Usage:          RoundTripTimeList(AddressList,Timeout = 800)
; Parameters:
;  AddressList	  -  Array of IPv4 addresses as strings in dotted number format (e.g., ["127.0.0.1", "8.8.4.4"]).
;  Timeout        -  How long the function should wait, in milliseconds, before giving an error
; Return values:  
;     The data in the response to the ping
; Change history:
;     1.0.00.00/2018-02-23
; Remarks:
;     NONE

RoundTripTimeList(AddressList,Timeout = 5000)
{
    Count := AddressList.MaxIndex()
    If Count > 64 ;MAXIMUM_WAIT_OBJECTS
        throw Exception("Could not send over 64 requests.")

    If DllCall("LoadLibrary","Str","ws2_32","UPtr") = 0 ;NULL
        throw Exception("Could not load WinSock library.")
    If DllCall("LoadLibrary","Str","icmp","UPtr") = 0 ;NULL
        throw Exception("Could not load ICMP library.")

    hPort := DllCall("icmp\IcmpCreateFile","UPtr") ;open port
    If hPort = -1 ;INVALID_HANDLE_VALUE
        throw Exception("Could not open port.")

    Replies := []
    Result := []

    StructLength := 250 + 20 + (A_PtrSize * 2) ;ICMP_ECHO_REPLY structure
    VarSetCapacity(Events,Count * A_PtrSize)
    For Index, Address In AddressList
    {
        NumericAddress := DllCall("ws2_32\inet_addr","AStr",Address,"UInt")
        If NumericAddress = 0xFFFFFFFF ;INADDR_NONE
            throw Exception("Could not convert IP address string to numeric format.")

        hEvent := DllCall("CreateEvent"
            ,"UPtr",0 ;security attributes structure
            ,"UInt",True ;manual reset event
            ,"UInt",False ;initially not signalled
            ,"UPtr",0 ;event name
            ,"UPtr")
        If !hEvent
            throw Exception("Could not create event.")
        NumPut(hEvent,Events,(Index - 1) * A_PtrSize)

        Replies.SetCapacity(Index,StructLength)
        DllCall("icmp\IcmpSendEcho2"
            ,"UPtr",hPort ;ICMP handle
            ,"UPtr",hEvent ;event handle
            ,"UPtr",0 ;APC routine handle
            ,"UPtr",0 ;APC routine context
            ,"UInt",NumericAddress ;IP address
            ,"Str","" ;request data
            ,"UShort",0 ;length of request data
            ,"UPtr",0 ;pointer to IP options structure
            ,"UPtr",Replies.GetAddress(Index) ;reply buffer
            ,"UInt",StructLength ;length of reply buffer
            ,"UInt",Timeout) ;ping timeout
        If A_LastError != 0x3E5 ;ERROR_IO_PENDING
            throw Exception("Could not send echo.")
    }

    While, Replies.MaxIndex()
    {
        Index := DllCall("WaitForMultipleObjects","UInt",Count,"UPtr",&Events,"UInt",False,"UInt",Timeout * 2)
        If (Index < 0 || Index >= Count) ;WAIT_OBJECT_0, WAIT_OBJECT_0 + Count - 1
            throw Exception("Could not detect ping completions." . Index . " " . A_LastError)

        If !DllCall("ResetEvent","UPtr",NumGet(Events,Index * A_PtrSize)) ;reset event to nonsignalled state
            throw Exception("Could not reset ping event.")

        Index ++ ;zero based index to one based
        Status := NumGet(Replies.GetAddress(Index),4,"UInt")
        If Status In 11002,11003,11004,11005,11010 ;IP_DEST_NET_UNREACHABLE, IP_DEST_HOST_UNREACHABLE, IP_DEST_PROT_UNREACHABLE, IP_DEST_PORT_UNREACHABLE, IP_REQ_TIMED_OUT
            Result[Index] := -1
        Else If Status = 0 ;IP_SUCCESS
            Result[Index] := NumGet(Replies.GetAddress(Index),8,"UInt") ;obtain round trip time
        Else
            throw Exception("Could not retrieve echo response." . Status)
        Replies.Remove(Index,"") ;remove reply entry to signify ping completion
    }

    Loop, %Count%
    {
        If !DllCall("CloseHandle","UPtr",NumGet(Events,(A_Index - 1) * A_PtrSize)) ;close event
            throw Exception("Could not close event.")
    }
    If !DllCall("icmp\IcmpCloseHandle","UInt",hPort) ;close port
        throw Exception("Could not close port.")

    Return, Result
}