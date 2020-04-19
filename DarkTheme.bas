#define fbc -gen gcc -O 3 res\DarkTheme.rc -dll 
'-x E:\progs\edicao\NotePad++\plugins\DarkTheme.dll

#include "windows.bi"
#include "Inc\PluginInterface.bi"
#include "MyTDT\Detour.bas"

#if __FB_DEBUG__ 
  #include "MyTDT\exceptions.bas"
#endif

#macro DebugOut(_F,_P...)
  scope
    dim as zstring*4096 zTemp
    sprintf(zTemp,_F,_P)
    OutputDebugString(zTemp)
  end scope
#endmacro

const PLUGIN_NAME = wstr("Dark Theme")

dim shared as HINSTANCE _hInst
dim shared as NppData nppData
dim shared as byte iReady = 0
dim shared as byte iActive = 0, iSimpleAA = 0, iDarkMode = 0 
dim shared as byte OrgiActive , OrgiSimpleAA , OrgiDarkMode

declare sub EnableDisable cdecl()  
declare sub BlockClearType cdecl()
declare sub SetModeNotRGB cdecl()
declare sub SetModeNotY cdecl()
declare sub SetModeGray cdecl()
declare sub SetModeRamp cdecl()
declare sub AboutDlg cdecl ()

enum MenuID
  'main
    miEnable
    miNoCT
  miSep0
    miNotRGB , miNotY , miGray , miRamp
  miSep1
    miAbout
end enum

const miFirstMode = miSep0+1, miLastMode = miSep1-1

static shared as FuncItem funcItem(...) = { _
  type( wstr("Enable")          , @EnableDisable  , miEnable  , FALSE , NULL ), _
  type( wstr("Block ClearType") , @BlockClearType , miNoCT    , FALSE , NULL ), _
  type( wstr("---")             , NULL            , miSep0    , FALSE , NULL ), _
  type( wstr("Type: InverseRGB"), @SetModeNotRGB  , miNotRGB  , FALSE , NULL ), _
  type( wstr("Type: InverseY")  , @SetModeNotY    , miNotY    , FALSE , NULL ), _
  type( wstr("Type: Grayscale") , @SetModeGray    , miGray    , FALSE , NULL ), _
  type( wstr("Type: HSV Ramp*") , @SetModeRamp    , miRamp    , FALSE , NULL ), _
  type( wstr("---")             , NULL            , miSep1    , FALSE , NULL ), _
  type( wstr("About")           , @AboutDlg       , miAbout   , FALSE , NULL )  _
}

static shared as HBITMAP hBmpBuffer = 0
static shared as any ptr pOrgProc = 0
static shared as RGBQUAD ptr pPixels = 0
static shared as BITMAPINFO tBmpInfo = any
static shared as wstring*8192 wCfgFile = any

sub DllLoad() constructor
  wCfgFile[0] = 0
  with tBmpInfo.bmiHeader
    .biSize = sizeof(BITMAPINFOHEADER)
    .biPlanes = 1 : .biBitCount = 32
    .biCompression = BI_RGB
  end with
  #if __FB_DEBUG__ 
    StartExceptions()
  #endif
  const cFlags = GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS or GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT
  GetModuleHandleEx(cFlags,cast(any ptr,@DllLoad),@_hInst)
end sub
sub DllUnload() destructor
  if iReady andalso wCfgFile[0] then    
    iSimpleAA = (iSimpleAA and 1):iDarkMode -= miFirstMode
    '#define SetCfgInt(_N,_V) if (Org##_V <> _V) then WritePrivateProfileStringW( wstr("Config") , wstr(_N) , wstr(_V) , wCfgFile )
    #define SetCfgInt(_N,_V) WritePrivateProfileStringW( wstr("Config") , wstr(_N) , wstr(_V) , wCfgFile )
    
    SetCfgInt( "Enabled"        , iActive )
    SetCfgInt( "BlockClearType" , iSimpleAA )
    SetCfgInt( "Type"           , iDarkMode )        
    
  end if
    
end sub

sub PixelsInvertY( iLeft as long , iTop as long , iWid as long , iHei as long )
  #define ToFix( _Float ) cint((_Float)*1024)
  #define ToInt( _Fix ) ((_Fix) shr 10)  
  with tBmpInfo.bmiHeader
    var pPix = pPixels+iTop*.biWidth+iLeft
    for iY as integer = 0 to iHei-1
      for iX as integer = 0 to iWid-1
        #define _R pPix[iX].rgbRed
        #define _G pPix[iX].rgbGreen
        #define _B pPix[iX].rgbBlue      
        dim as integer iY = ToInt(ToFix(0.299)*cint(_R) + ToFix(0.587)*cint(_G) + ToFix(0.114)*cint(_B))
        if iY > 255 then iY = 255
        dim as integer iU = ToInt(ToFix(-0.147)*cint(_R) - ToFix(0.289)*cint(_G) + ToFix(0.436)*cint(_B)) + 128
        'if iU < 0 then iU = 0 else if iU > 255 then iU = 255
        dim as integer iV = ToInt(ToFix(0.615)*cint(_R) - ToFix(0.515)*cint(_G) - ToFix(0.100)*cint(_B)) + 128
        'if iV < 0 then iV = 0 else if iV > 255 then iV = 255
        
        iY = 255-iY
        
        dim as integer iR = iY + ToInt(ToFix(1.140)*(iV-128))
        if iR < 0 then iR = 0 else if iR > 255 then iR = 255
        dim as integer iG = iY - ToInt(ToFix(0.395)*(iU-128)) - ToInt(ToFix(0.581)*(iV-128))
        if iG < 0 then iG = 0 else if iG > 255 then iG = 255
        dim as integer iB = iY + ToInt(ToFix(2.032)*(iU-128))
        if iB < 0 then iB = 0 else if iB > 255 then iB = 255
        
        _R = iR : _G = iG : _B = iB 
      next iX      
      pPix += .biWidth
    next iY
  end with
end sub
sub PixelsGray( iLeft as long , iTop as long , iWid as long , iHei as long )
  #define ToFix( _Float ) cint((_Float)*1024)
  #define ToInt( _Fix ) ((_Fix) shr 10)  
  with tBmpInfo.bmiHeader
    var pPix = pPixels+iTop*.biWidth+iLeft
    for iY as integer = 0 to iHei-1
      for iX as integer = 0 to iWid-1
        #define _R pPix[iX].rgbRed
        #define _G pPix[iX].rgbGreen
        #define _B pPix[iX].rgbBlue        
        var iGraY = 255-((cint(_R)+_G+_B)\3)
        'if iGraY < 0 then iGraY = 0
        _R = iGray : _G = iGray : _B = iGray
      next iX
      pPix += .biWidth
    next iY
  end with
end sub
sub PixelsRamp( iLeft as long , iTop as long , iWid as long , iHei as long )
  static as DWORD dwRampHSV(255) = {  _
    &h000000,&h010101,&h030101,&h040202,&h060202,&h070303,&h090304,&h0A0405, _
    &h0C0406,&h0D0507,&h0F0507,&h100609,&h120609,&h13070B,&h15070C,&h17070D, _
    &h18080E,&h1A080F,&h1B0911,&h1D0912,&h1E0A13,&h200A15,&h210B16,&h230B18, _
    &h250B1A,&h260C1B,&h280C1D,&h2A0C1F,&h2B0D21,&h2D0D23,&h2E0E25,&h300E27, _
    &h320E29,&h330F2B,&h350F2D,&h370F30,&h381032,&h3A1035,&h3B1137,&h3D1139, _
    &h3F113C,&h40123E,&h421241,&h431244,&h431345,&h441347,&h451349,&h45134B, _
    &h45144C,&h45144E,&h451450,&h451551,&h451553,&h451555,&h451656,&h451658, _
    &h44165A,&h44165C,&h43175D,&h43175F,&h431761,&h421763,&h411864,&h401866, _
    &h401868,&h3F186A,&h3E196B,&h3D196D,&h3B196F,&h3A1971,&h391A72,&h381A74, _
    &h361A76,&h351A78,&h331B79,&h321B7B,&h301B7D,&h2E1B7F,&h2C1B81,&h2A1B83, _
    &h281C84,&h261C86,&h241C88,&h211C8A,&h1F1C8C,&h1C1C8E,&h1D208F,&h1D2391, _
    &h1D2593,&h1D2895,&h1D2B97,&h1D2F99,&h1E339A,&h1E369C,&h1E399E,&h1E3DA0, _
    &h1E40A2,&h1E44A4,&h1E48A6,&h1E4CA8,&h1F50A9,&h1F54AB,&h1F58AD,&h1F5CAF, _
    &h1F60B1,&h1F65B3,&h1F69B5,&h1F6EB7,&h1F72B9,&h1F77BB,&h207CBC,&h1F81BF, _
    &h2086C0,&h208BC2,&h2090C4,&h2095C6,&h209BC8,&h20A0CA,&h20A6CC,&h20ABCE, _
    &h20B1D0,&h20B7D2,&h20BDD4,&h20C3D6,&h20C9D8,&h20CFDA,&h20D6DC,&h20DCDE, _
    &h20E0DE,&h22E0D9,&h23E1D6,&h25E1D2,&h26E2CE,&h28E2CA,&h29E3C7,&h2BE3C3, _
    &h2CE4BF,&h2EE4BB,&h2FE5B8,&h31E5B4,&h32E6B1,&h34E6AD,&h35E7AA,&h37E7A7, _
    &h38E8A4,&h3AE8A0,&h3CE89D,&h3DE99A,&h3FE997,&h41E994,&h42EA91,&h44EA8E, _
    &h45EB8B,&h47EB89,&h48EC86,&h4AEC83,&h4CEC81,&h4DED7E,&h4FED7C,&h51ED79, _
    &h52EE77,&h54EE75,&h55EF72,&h57EF70,&h59EF6E,&h5AF06C,&h5CF06A,&h5EF068, _
    &h5FF166,&h61F164,&h63F163,&h67F264,&h6DF266,&h72F268,&h76F369,&h7BF36B, _
    &h80F36D,&h84F46E,&h89F470,&h8EF472,&h92F573,&h96F575,&h9BF577,&h9FF579, _
    &hA3F67A,&hA7F67C,&hABF67E,&hAFF680,&hB3F781,&hB7F783,&hBBF785,&hBEF787, _
    &hC2F888,&hC6F88A,&hC9F88C,&hCCF88E,&hD0F98F,&hD3F991,&hD6F993,&hD9F995, _
    &hDDFA96,&hE0FA98,&hE2FA9A,&hE5FA9C,&hE8FA9E,&hEBFB9F,&hEDFBA1,&hF0FBA3, _
    &hF2FBA5,&hF4FBA7,&hF7FCA8,&hF9FCAA,&hFBFCAC,&hFCFBAE,&hFCF9B0,&hFCF8B2, _
    &hFDF7B3,&hFDF5B5,&hFDF4B7,&hFDF3B9,&hFDF1BB,&hFDF0BD,&hFDEFBF,&hFDEEC1, _
    &hFEEEC2,&hFEEDC4,&hFEECC6,&hFEECC8,&hFEEBCA,&hFEEBCC,&hFEEACE,&hFEEAD0, _
    &hFFEAD1,&hFFEAD3,&hFFEAD5,&hFFEAD7,&hFFEAD9,&hFFEADB,&hFFEBDD,&hFFEBDF, _
    &hFFECE1,&hFFECE3,&hFFEDE5,&hFFEEE7,&hFFEFE9,&hFFF0EB,&hFFF1ED,&hFFF2EF, _
    &hFFF3F1,&hFFF5F3,&hFFF6F5,&hFFF8F7,&hFFF9F9,&hFFFBFB,&hFFFDFD,&hFFFFFF }
  rem --------------------------------------------------------------------------
  
  #define ToFix( _Float ) cint((_Float)*1024)
  #define ToInt( _Fix ) ((_Fix) shr 10)  
  with tBmpInfo.bmiHeader
    var pPix = pPixels+iTop*.biWidth+iLeft
    for iY as integer = 0 to iHei-1
      for iX as integer = 0 to iWid-1
        #define _R pPix[iX].rgbRed
        #define _G pPix[iX].rgbGreen
        #define _B pPix[iX].rgbBlue      
        dim as integer iY = ToInt(ToFix(0.25)*cint(_R) + ToFix(0.65)*cint(_G) + ToFix(0.10)*cint(_B))
        if iY > 255 then iY = 255
        cptr(DWORD ptr,pPix)[iX] = dwRampHSV(255-iY)        
      next iX      
      pPix += .biWidth
    next iY
  end with
end sub

extern "windows-ms"  
  dim shared pfCreateFontIndirectW as function (as LOGFONTW ptr) as HFONT
  function CreateFontIndirectW_Detour (lplf as LOGFONTW ptr) as HFONT
    'DebugOut("%s","CreateFontIndirectW")
    if iActive andalso iSimpleAA then lplf->lfQuality = ANTIALIASED_QUALITY
    return pfCreateFontIndirectW(lplf)
  end function  
end extern

function WndProc( hWnd as HWND , uMsg as UINTEGER , wParam as WPARAM , lParam as LPARAM ) as LRESULT
  
  if pOrgProc = 0 then return DefWindowProc( hWnd , uMsg , wParam , lParam )    
  
  select case uMsg
  case WM_PAINT       
    static as long iCurWid=0,iCurHei=0    
    dim as PAINTSTRUCT tPaint = any
    dim as Rect tRC = any : GetClientRect( hWnd , @tRC )        
    dim as HRGN hWndRgn = CreateRectRgn(0,0,0,0)
    GetUpdateRgn( hWnd , hWndRgn , 0 )
    BeginPaint( hWnd , @tPaint )
    var hDCScr = tPaint.hDC
    var hDC = CreateCompatibleDC(hDCScr)
    if hBmpBuffer = 0 orelse tRc.Right <> iCurWid or tRc.Bottom <> iCurHei then 
      iCurWid = tRc.Right : iCurHei = tRc.bottom      
      if hBmpBuffer then DeleteObject(hBmpBuffer):hBmpBuffer=0
      select case iDarkMode
      case miNotRGB
        hBmpBuffer = CreateCompatibleBitmap( hDCScr , iCurWid , iCurHei )
      case else
        tBmpInfo.bmiHeader.biWidth = iCurWid : tBmpInfo.bmiHeader.biHeight = -iCurHei
        hBmpBuffer = CreateDibSection( hDCScr , @tBmpInfo , DIB_RGB_COLORS , @pPixels , NULL , 0 )
      end select
    end if
    var hOldBM = SelectObject( hDC , hBmpBuffer )
    var hOldRGN = SelectObject( hDC , hWndRgn )    
    CallWindowProc( pOrgProc , hWnd , WM_PRINTCLIENT , cast(WPARAM,hDC) , PRF_CHILDREN or PRF_CLIENT or PRF_ERASEBKGND or PRF_NONCLIENT )
    with tPaint.rcPaint
      select case iDarkMode
      case miNotRGB
        BitBlt( hDCScr , .left,.top , .right-.left , .bottom-.top , hDC , .left,.top , NOTSRCCOPY )
      case miNotY
        GdiFlush()
        PixelsInvertY( .left , .top , .right-.left , .bottom-.top )
        BitBlt( hDCScr , .left,.top , .right-.left , .bottom-.top , hDC , .left,.top , SRCCOPY )
      case miGray
        GdiFlush()
        PixelsGray( .left , .top , .right-.left , .bottom-.top )
        BitBlt( hDCScr , .left,.top , .right-.left , .bottom-.top , hDC , .left,.top , SRCCOPY )
      case miRamp
        GdiFlush()
        PixelsRamp( .left , .top , .right-.left , .bottom-.top )
        BitBlt( hDCScr , .left,.top , .right-.left , .bottom-.top , hDC , .left,.top , SRCCOPY )
      end select
    end with
    SelectObject( hDC , hOldBM )    
    DeleteObject( hWndRgn )
    DeleteDC( hDC )
    EndPaint( hWnd , @tPaint )
    return 0
  case WM_DESTROY
    DeleteObject(hBmpBuffer):hBmpBuffer=0
  end select
  
  return CallWindowProc( pOrgProc , hWnd , uMsg , wParam , lParam )
  
end function

sub ChangeMode( imiMode as integer )
  if imiMode < miFirstMode or imiMode > miLastMode then exit sub
  iDarkMode = imiMode
  if iReady then
    for iN as integer = miFirstMode to miLastMode
      SendMessage( nppData._nppHandle , NPPM_SETMENUITEMCHECK , funcItem(iN)._cmdID , iN=imiMode )
    next iN
    if hBmpBuffer then DeleteObject(hBmpBuffer):hBmpBuffer=0
    InvalidateRect( nppData._scintillaMainHandle , NULL , TRUE )
  end if
  var iOldAA = iSimpleAA  
  iSimpleAA = iif(imiMode=miRamp,iSimpleAA or 2,iSimpleAA and (not 2))  
  if (iOldAA<>0) <> (iSimpleAA<>0) then
    iSimpleAA xor= 1: BlockClearType()
  end if
  
end sub
sub ForceUpdateFont()
  if iReady then
    dim as integer iLang = 0
    SendMessage( nppData._nppHandle , NPPM_GETCURRENTLANGTYPE , 0 , cast(lParam,@iLang) )
    dim as integer iTempLang = iif(iLang=L_TEXT,L_USER,L_TEXT)
    SendMessage( nppData._nppHandle , NPPM_SETCURRENTLANGTYPE , 0 , iTempLang )
    SendMessage( nppData._nppHandle , NPPM_SETCURRENTLANGTYPE , 0 , iLang )  
  end if
end sub

sub BlockClearType cdecl()
  iSimpleAA xor= 1
  if iReady then SendMessage( nppData._nppHandle , NPPM_SETMENUITEMCHECK , funcItem(miNoCT)._cmdID , (iSimpleAA and 1) )
  
  if iSimpleAA then
    if pfCreateFontIndirectW = 0 then
      SetDetourLibrary("gdi32")
      CreateDetour(CreateFontIndirectW)
    end if
  elseif pfCreateFontIndirectW then
    SetDetourLibrary("gdi32")
    RestoreDetour(CreateFontIndirectW)
    pfCreateFontIndirectW = NULL
  end if
  
  ForceUpdateFont()
end sub
sub SetModeNotRGB cdecl()
  ChangeMode( miNotRGB )
end sub
sub SetModeNotY cdecl()
  ChangeMode( miNotY )
end sub
sub SetModeGray cdecl()
  ChangeMode( miGray )
end sub
sub SetModeRamp cdecl()
  ChangeMode( miRamp )
end sub
sub EnableDisable cdecl()  
  iActive xor= 1
  
  if iReady then SendMessage( nppData._nppHandle , NPPM_SETMENUITEMCHECK , funcItem(miEnable)._cmdID , iActive )
  
  var hwnd = nppData._scintillaMainHandle
  if iActive then    
    pOrgProc = cast(any ptr,SetWindowLongPtr( hwnd , GWLP_WNDPROC , cast(LONG_PTR,@WndProc)))    
  else
    if hBmpBuffer then DeleteObject(hBmpBuffer):hBmpBuffer=0
    if pOrgProc then SetWindowLongPtr( hwnd , GWLP_WNDPROC , cast(LONG_PTR,pOrgProc) ) : pOrgProc = 0 
  end if
  
  ForceUpdateFont()  
  
end sub
sub AboutDlg cdecl ()
  Messagebox(nppData._nppHandle,"MyTDT Dark Theme Plugin v1.0 by Mysoft","Notepad++ Dark Theme",MB_ICONINFORMATION)
end sub

extern "C"
  sub setInfo(byval notpadPlusData as NppData) export	  
    nppdata = notpadPlusData
    
    SendMessage( nppData._nppHandle ,  NPPM_GETPLUGINSCONFIGDIR , 8000 , cast(LPARAM,@wCfgFile) )
    wsprintfw(wCfgFile,wstr("%s%hs"),wCfgFile,"\DarkTheme.ini")
    
  end sub
  function getName() as const TCHAR ptr export	  
    return @PLUGIN_NAME
  end function
  function getFuncsArray(nbF as integer ptr) as FuncItem ptr export    
    *nbF = ubound(funcItem)+1
    
    #define GetCfgInt(_N,_D) GetPrivateProfileIntW( wstr("Config") , wstr(_N) , _D , wCfgFile )
    #define MenuCheck(_I,_V) funcItem(_I)._init2Check = _V
    
    iActive = iif(GetCfgInt("Enabled",1),1,0)            
    iSimpleAA = iif(GetCfgInt("BlockClearType",0),1,0)
    iDarkMode = GetCfgInt("Type",1)
    if iDarkMode < 0 or iDarkMode > (miLastMode-miFirstMode) then iDarkMode = 1
    iDarkMode += miFirstMode
    if iDarkMode = miRamp then iSimpleAA or= 2
    
    if iActive then iActive xor= 1:EnableDisable()
    if iSimpleAA then iSimpleAA xor= 1:BlockClearType()
    ChangeMode( iDarkMode )
    
    'MenuCheck(miEnable,iActive)
    MenuCheck(miNoCT,(iSimpleAA and 1))
    for N as integer = miFirstMode to miLastMode
      MenuCheck( N , N=iDarkMode )
    next N
    
    OrgiActive = iActive 
    OrgiSimpleAA = (iSimpleAA and 1) 
    OrgiDarkMode = iDarkMode-miFirstMode
    
    iReady = 1
    
    return @funcItem(0)    
  end function
  sub beNotified(pNotify as SCNotification ptr ) export        
    select case pNotify->nmhdr.code
    case NPPN_READY
      SendMessage( nppData._nppHandle , NPPM_SETMENUITEMCHECK , funcItem(miEnable)._cmdID , iActive )
    case NPPN_TBMODIFICATION      
      var hDCScr = GetDC(nppData._nppHandle)
      var hIco = LoadImage( _hInst , "DarkThemeIcon" , IMAGE_ICON	, 16,16 , LR_SHARED	)
      var hBmp = CreateCompatibleBitmap( hDCScr , 16 , 16 )
      var hDC = CreateCompatibleDC(hDCScr)
      var hBmOld = SelectObject( hDC , hBmp )
      DrawIconEx( hDC , 0,0 , hIco , 16,16 , 0 , NULL , DI_NORMAL )
      ReleaseDC(nppData._nppHandle,hDCScr)
      SelectObject( hDC , hBmOld )
      DeleteDC( hDC )
      dim as ToolBarIcons tIcons = type( hBmp , hIco )      
      'Messagebox( nppData._nppHandle , "Time to add toolbar?" , hex$(hBmp) , MB_ICONWARNING )
      SendMessage( nppData._nppHandle , NPPM_ADDTOOLBARICON , funcItem(miEnable)._cmdID, cast(LPARAM,@tIcons) )      
    end select
  end sub
  function isUnicode() as WINBOOL export    
    return TRUE
  end function
  function messageProc(uMsg as UINT, wParam as WPARAM, lParam as LPARAM) as LRESULT export    
    return TRUE
  end function
  
end extern
