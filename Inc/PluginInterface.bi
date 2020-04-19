#ifndef PLUGININTERFACE_H
#define PLUGININTERFACE_H

#if 0
  #ifndef SCINTILLA_H
  #include "scintilla.bi"
  #endif '//SCINTILLA_H
  
  #ifndef NOTEPAD_PLUS_MSGS_H  
  #endif '//NOTEPAD_PLUS_MSGS_H
#endif

#include "Notepad_plus_msgs.bi"

const nbChar = 64

#undef TCHAR
type TCHAR as WSTRING

'typedef const TCHAR * (__cdecl * PFUNCGETNAME)();

type NppData
	as HWND _nppHandle
	as HWND _scintillaMainHandle
	as HWND _scintillaSecondHandle
end type
type ToolbarIcons
  as HBITMAP hToolbarBmp
  as HICON hToolbarIcon
end type  

#ifndef SCNotification
  type SCNotification
    nmhdr as NMHDR
  end type
#endif  

type PFUNCSETINFO as sub cdecl (as NppData)
type PFUNCPLUGINCMD as sub cdecl ()
type PBENOTIFIED as sub cdecl (as SCNotification ptr)
type PMESSAGEPROC as function cdecl ( as UINTEGER , as WPARAM , as LPARAM ) as LRESULT

type ShortcutKey
	as winbool _isCtrl
	as winbool _isAlt
	as winbool _isShift
	as UBYTE   _key
end type

type FuncItem
	as WSTRING*nbChar _itemName
	as PFUNCPLUGINCMD _pFunc
	as integer _cmdID
	as winbool _init2Check
	as ShortcutKey ptr _pShKey
end type

'typedef FuncItem * (__cdecl * PFUNCGETFUNCSARRAY)(int *);

#if 0
  // You should implement (or define an empty function body) those functions which are called by Notepad++ plugin manager
  extern "C" __declspec(dllexport) void setInfo(NppData);
  extern "C" __declspec(dllexport) const TCHAR * getName();
  extern "C" __declspec(dllexport) FuncItem * getFuncsArray(int *);
  extern "C" __declspec(dllexport) void beNotified(SCNotification *);
  extern "C" __declspec(dllexport) LRESULT messageProc(UINT Message, WPARAM wParam, LPARAM lParam);
#endif

#if 0
// This API return always true now, since Notepad++ isn't compiled in ANSI mode anymore
extern "C" __declspec(dllexport) BOOL isUnicode();
#endif


#endif 'PLUGININTERFACE_H