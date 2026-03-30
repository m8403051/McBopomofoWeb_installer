!include "MUI2.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"
!include "nsDialogs.nsh"
!include "WinMessages.nsh"

!ifndef VERSION
  !error "VERSION is required"
!endif

!ifndef OUTDIR
  !error "OUTDIR is required"
!endif

!ifndef INSTALLER_NAME
  !error "INSTALLER_NAME is required"
!endif

!ifndef STAGING_DIR
  !error "STAGING_DIR is required"
!endif

!ifndef INCLUDE_VCREDIST
  !define INCLUDE_VCREDIST "0"
!endif

Name "McBopomofo for Windows"
OutFile "${OUTDIR}\\${INSTALLER_NAME}"
InstallDir "$PROGRAMFILES32\\PIME"
RequestExecutionLevel admin
Unicode true
!define MUI_ABORTWARNING
; Use non-solid compression to avoid long "stuck" feel during extraction on some machines.
SetCompressor lzma
SetCompressorDictSize 16

Var UninstKey
Var LogFile
Var FontPageCheckbox
Var NeedFontPrompt
Var InstallFontChoice
Var UserConfigCreated
Var UninstallFontPageCheckbox
Var NeedUninstallFontPrompt
Var RemoveFontChoice

!define PRODUCT_UNINST_KEY "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\McBopomofoPIME"
!define PIME_TSF_CLSID "{35F67E9D-A54D-4177-9697-8B0AB71A9E04}"
!define PIME_TSF_NAME "PIMETextService"
!define PIME_PROFILE_GUID "{5340c1d9-706e-4b6b-b022-2e763fa5f674}"
!define PIME_LANGID "0x00000404"
!define PIME_PROFILE_NAME "McBopomofo (PIME)"
!define PIME_CATEGORY_DISPLAYATTR "{046B8C80-1647-40F7-9B21-B93B81AABC1B}"
!define PIME_CATEGORY_COMLESS "{13A016DF-560B-46CD-947A-4C3AF1E0E35D}"
!define PIME_CATEGORY_IMMERSIVE "{25504FB4-7BAB-4BC1-9C69-CF81890F0EF5}"
!define PIME_CATEGORY_SYSTRAY "{34745C63-B2F0-4784-8B67-5E12C8701A31}"
!define PIME_CATEGORY_SECUREMODE "{49D2F9CF-1F5E-11D7-A6D3-00065B84435C}"
!define PIME_CATEGORY_UIELEMENT "{CCF05DD7-4A87-11D7-A6E2-00065B84435C}"
!define FONT_HELPER_PS1 "$PLUGINSDIR\\install-fonts.ps1"
!define UNFONT_HELPER_PS1 "$PLUGINSDIR\\uninstall-fonts.ps1"
!define CONFIG_FLAG_HELPER_PS1 "$PLUGINSDIR\\set-config-flag.ps1"

!macro CHECK_OPTIONAL_FONT FILE_NAME
  ${If} $0 == "0"
  ${AndIfNot} ${FileExists} "$FONTS\\${FILE_NAME}"
    StrCpy $0 "1"
  ${EndIf}
!macroend

!macro CHECK_INSTALLED_FONT FILE_NAME
  ${If} $0 == "0"
  ${AndIf} ${FileExists} "$FONTS\\${FILE_NAME}"
    StrCpy $0 "1"
  ${EndIf}
!macroend
Function LogLine
  Exch $0
  Push $1
  StrCmp $LogFile "" log_done
  ClearErrors
  FileOpen $1 $LogFile a
  IfErrors log_done
  FileSeek $1 0 END
  FileWrite $1 "$0$\r$\n"
  FileClose $1
log_done:
  Pop $1
  Pop $0
FunctionEnd

Function un.LogLine
  Exch $0
  Push $1
  StrCmp $LogFile "" unlog_done
  ClearErrors
  FileOpen $1 $LogFile a
  IfErrors unlog_done
  FileSeek $1 0 END
  FileWrite $1 "$0$\r$\n"
  FileClose $1
unlog_done:
  Pop $1
  Pop $0
FunctionEnd

!macro LOG MSG
  Push "${MSG}"
  Call LogLine
!macroend

!macro ULOG MSG
  Push "${MSG}"
  Call un.LogLine
!macroend

!macro LOG_FILE_CHECK PATH LABEL
  ${If} ${FileExists} "${PATH}"
    !insertmacro LOG "[diag] ${LABEL}: exists (${PATH})"
  ${Else}
    !insertmacro LOG "[diag] ${LABEL}: missing (${PATH})"
  ${EndIf}
!macroend

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${STAGING_DIR}\\core\\licenses\\McBopomofoWeb-LICENSE.txt"
!insertmacro MUI_PAGE_LICENSE "${STAGING_DIR}\\core\\licenses\\PIME-LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
Page Custom FontPageCreate FontPageLeave
!define MUI_PAGE_CUSTOMFUNCTION_PRE FontLicensePagePre
!insertmacro MUI_PAGE_LICENSE "${STAGING_DIR}\\core\\licenses\\Fonts-LICENSE.txt"
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
UninstPage Custom un.FontPageCreate un.FontPageLeave
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
AutoCloseWindow false

!macro FAIL_INSTALL MESSAGE LOGMESSAGE
  !insertmacro LOG "${LOGMESSAGE}"
  SetErrorLevel 1
  IfSilent +2
    MessageBox MB_ICONSTOP|MB_OK "${MESSAGE}"
  Abort
!macroend

Function IsFontPackMissing
  Push $0
  StrCpy $0 "0"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiKaiStd-Regular.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSans-Bold.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSans-ExtraLight.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSans-Heavy.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSans-Light.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSans-Medium.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSans-Regular.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSerif-Bold.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSerif-ExtraLight.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSerif-Heavy.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSerif-Light.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSerif-Medium.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSerif-Regular.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiSerif-SemiBold.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiBox-R.ttf"
  !insertmacro CHECK_OPTIONAL_FONT "BpmfZihiOnly-R.ttf"
  Exch $0
FunctionEnd

Function un.IsAnyOptionalFontInstalled
  Push $0
  StrCpy $0 "0"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiKaiStd-Regular.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSans-Bold.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSans-ExtraLight.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSans-Heavy.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSans-Light.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSans-Medium.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSans-Regular.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSerif-Bold.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSerif-ExtraLight.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSerif-Heavy.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSerif-Light.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSerif-Medium.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSerif-Regular.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiSerif-SemiBold.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiBox-R.ttf"
  !insertmacro CHECK_INSTALLED_FONT "BpmfZihiOnly-R.ttf"
  Exch $0
FunctionEnd

Function FontPageCreate
  ${If} $NeedFontPrompt != "1"
    Abort
  ${EndIf}
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}
  ${NSD_CreateLabel} 0 0 100% 62u "The optional bpmfvs font pack was not fully found on this system.$\r$\n$\r$\nMcBopomofo can install these font families together with the input method:$\r$\n- BpmfZihiKaiStd$\r$\n- BpmfZihiSans$\r$\n- BpmfZihiSerif$\r$\n- BpmfSpecial$\r$\n$\r$\nIf you choose to install them, the next page will show the font notices and license terms."
  Pop $0
  ${NSD_CreateCheckbox} 0 72u 100% 12u "Install the optional bpmfvs font pack"
  Pop $FontPageCheckbox
  ${NSD_Check} $FontPageCheckbox
  nsDialogs::Show
FunctionEnd

Function FontPageLeave
  ${If} $NeedFontPrompt != "1"
    Return
  ${EndIf}
  ${NSD_GetState} $FontPageCheckbox $0
  ${If} $0 == ${BST_CHECKED}
    StrCpy $InstallFontChoice "1"
  ${Else}
    StrCpy $InstallFontChoice "0"
  ${EndIf}
FunctionEnd

Function FontLicensePagePre
  ${If} $NeedFontPrompt != "1"
    Abort
  ${EndIf}
  ${If} $InstallFontChoice != "1"
    Abort
  ${EndIf}
FunctionEnd

Function DeletePimeRegistration
  ${If} ${FileExists} "$INSTDIR\\x86\\PIMETextService.dll"
    SetRegView 32
    ExecWait '"$SYSDIR\\regsvr32.exe" /u /s "$INSTDIR\\x86\\PIMETextService.dll"' $0
  ${Else}
    StrCpy $0 ""
  ${EndIf}
  ${If} ${RunningX64}
    ${If} ${FileExists} "$INSTDIR\\x64\\PIMETextService.dll"
      SetRegView 64
      ExecWait '"$SYSDIR\\regsvr32.exe" /u /s "$INSTDIR\\x64\\PIMETextService.dll"' $1
    ${Else}
      StrCpy $1 ""
    ${EndIf}
    SetRegView 32
  ${EndIf}
  ; Remove any stale keys even if regsvr32 has already done it.
  SetRegView 64
  DeleteRegKey HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}"
  DeleteRegKey HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}"
  ${If} ${RunningX64}
    SetRegView 32
    DeleteRegKey HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}"
    DeleteRegKey HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}"
    SetRegView 64
  ${EndIf}
FunctionEnd

Function un.DeletePimeRegistration
  ${If} ${FileExists} "$INSTDIR\\x86\\PIMETextService.dll"
    SetRegView 32
    ExecWait '"$SYSDIR\\regsvr32.exe" /u /s "$INSTDIR\\x86\\PIMETextService.dll"' $0
  ${Else}
    StrCpy $0 ""
  ${EndIf}
  ${If} ${RunningX64}
    ${If} ${FileExists} "$INSTDIR\\x64\\PIMETextService.dll"
      SetRegView 64
      ExecWait '"$SYSDIR\\regsvr32.exe" /u /s "$INSTDIR\\x64\\PIMETextService.dll"' $1
    ${Else}
      StrCpy $1 ""
    ${EndIf}
    SetRegView 32
  ${EndIf}
  SetRegView 64
  DeleteRegKey HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}"
  DeleteRegKey HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}"
  ${If} ${RunningX64}
    SetRegView 32
    DeleteRegKey HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}"
    DeleteRegKey HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}"
    SetRegView 64
  ${EndIf}
FunctionEnd

!macro WRITE_PIME_CATEGORY CATEGORY_GUID
  WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\Category\\Category\\${CATEGORY_GUID}\\${PIME_TSF_CLSID}" "" ""
  WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\Category\\Item\\${PIME_TSF_CLSID}\\${CATEGORY_GUID}" "" ""
!macroend

!macro WRITE_PIME_LANGUAGE_PROFILE
  WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\LanguageProfile" "" ""
  WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\LanguageProfile\\${PIME_LANGID}" "" ""
  WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\LanguageProfile\\${PIME_LANGID}\\${PIME_PROFILE_GUID}" "Description" "${PIME_PROFILE_NAME}"
  WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\LanguageProfile\\${PIME_LANGID}\\${PIME_PROFILE_GUID}" "Display Description" "${PIME_PROFILE_NAME}"
  WriteRegDWORD HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\LanguageProfile\\${PIME_LANGID}\\${PIME_PROFILE_GUID}" "Enable" 1
  WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\LanguageProfile\\${PIME_LANGID}\\${PIME_PROFILE_GUID}" "IconFile" "$INSTDIR\\node\\input_methods\\McBopomofo\\icon.ico"
  WriteRegDWORD HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\LanguageProfile\\${PIME_LANGID}\\${PIME_PROFILE_GUID}" "IconIndex" 0
!macroend

Function WritePimeRegistration
  SetRegView 64
  WriteRegStr HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}" "" "${PIME_TSF_NAME}"
  WriteRegStr HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}\\InprocServer32" "" "$INSTDIR\\x64\\PIMETextService.dll"
  WriteRegStr HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}\\InprocServer32" "ThreadingModel" "Apartment"

  ${If} ${RunningX64}
    SetRegView 32
    WriteRegStr HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}" "" "${PIME_TSF_NAME}"
    WriteRegStr HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}\\InprocServer32" "" "$INSTDIR\\x86\\PIMETextService.dll"
    WriteRegStr HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}\\InprocServer32" "ThreadingModel" "Apartment"
  ${Else}
    WriteRegStr HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}" "" "${PIME_TSF_NAME}"
    WriteRegStr HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}\\InprocServer32" "" "$INSTDIR\\x86\\PIMETextService.dll"
    WriteRegStr HKLM "Software\\Classes\\CLSID\\${PIME_TSF_CLSID}\\InprocServer32" "ThreadingModel" "Apartment"
  ${EndIf}

  SetRegView 64
  WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}" "" ""
  WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\Category" "" ""
  WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\Category\\Category" "" ""
  WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\Category\\Item" "" ""
  WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\Category\\Item\\${PIME_TSF_CLSID}" "" ""
  !insertmacro WRITE_PIME_CATEGORY "${PIME_CATEGORY_DISPLAYATTR}"
  !insertmacro WRITE_PIME_CATEGORY "${PIME_CATEGORY_COMLESS}"
  !insertmacro WRITE_PIME_CATEGORY "${PIME_CATEGORY_IMMERSIVE}"
  !insertmacro WRITE_PIME_CATEGORY "${PIME_CATEGORY_SYSTRAY}"
  !insertmacro WRITE_PIME_CATEGORY "${PIME_CATEGORY_SECUREMODE}"
  !insertmacro WRITE_PIME_CATEGORY "${PIME_CATEGORY_UIELEMENT}"
  !insertmacro WRITE_PIME_LANGUAGE_PROFILE

  ${If} ${RunningX64}
    SetRegView 32
    WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}" "" ""
    WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\Category" "" ""
    WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\Category\\Category" "" ""
    WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\Category\\Item" "" ""
    WriteRegStr HKLM "Software\\Microsoft\\CTF\\TIP\\${PIME_TSF_CLSID}\\Category\\Item\\${PIME_TSF_CLSID}" "" ""
    !insertmacro WRITE_PIME_CATEGORY "${PIME_CATEGORY_DISPLAYATTR}"
    !insertmacro WRITE_PIME_CATEGORY "${PIME_CATEGORY_COMLESS}"
    !insertmacro WRITE_PIME_CATEGORY "${PIME_CATEGORY_IMMERSIVE}"
    !insertmacro WRITE_PIME_CATEGORY "${PIME_CATEGORY_SYSTRAY}"
    !insertmacro WRITE_PIME_CATEGORY "${PIME_CATEGORY_SECUREMODE}"
    !insertmacro WRITE_PIME_CATEGORY "${PIME_CATEGORY_UIELEMENT}"
    !insertmacro WRITE_PIME_LANGUAGE_PROFILE
    SetRegView 64
  ${EndIf}
FunctionEnd

Function .onInit
  StrCpy $NeedFontPrompt "0"
  StrCpy $InstallFontChoice "0"
  StrCpy $UserConfigCreated "0"
  Call IsFontPackMissing
  Pop $0
  ${If} $0 == "1"
    StrCpy $NeedFontPrompt "1"
    StrCpy $InstallFontChoice "1"
  ${EndIf}
FunctionEnd

Function un.onInit
  StrCpy $NeedUninstallFontPrompt "0"
  StrCpy $RemoveFontChoice "0"
  Call un.IsAnyOptionalFontInstalled
  Pop $0
  ${If} $0 == "1"
    StrCpy $NeedUninstallFontPrompt "1"
  ${EndIf}
FunctionEnd

Function un.FontPageCreate
  ${If} $NeedUninstallFontPrompt != "1"
    Abort
  ${EndIf}
  IfSilent 0 +2
    Abort
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}
  ${NSD_CreateLabel} 0 0 100% 54u "Optional bpmfvs fonts were found on this system.$\r$\n$\r$\nIf you no longer need them, you can remove them together with McBopomofo. Leave this unchecked if you want to keep these fonts for other apps."
  Pop $0
  ${NSD_CreateCheckbox} 0 64u 100% 12u "Also remove the installed bpmfvs fonts"
  Pop $UninstallFontPageCheckbox
  nsDialogs::Show
FunctionEnd

Function un.FontPageLeave
  ${If} $NeedUninstallFontPrompt != "1"
    Return
  ${EndIf}
  ${NSD_GetState} $UninstallFontPageCheckbox $0
  ${If} $0 == ${BST_CHECKED}
    StrCpy $RemoveFontChoice "1"
  ${Else}
    StrCpy $RemoveFontChoice "0"
  ${EndIf}
FunctionEnd

Section "Install"
  SetShellVarContext current
  SetOverwrite on
  StrCpy $LogFile "$TEMP\\McBopomofoPIME-install.log"
  Delete "$LogFile"
  !insertmacro LOG "Install start. INSTDIR=$INSTDIR"
  ${If} ${RunningX64}
    !insertmacro LOG "[diag] RunningX64=1"
  ${Else}
    !insertmacro LOG "[diag] RunningX64=0"
  ${EndIf}
  !insertmacro LOG "[diag] WINDIR=$WINDIR"
  !insertmacro LOG "[diag] SYSDIR=$SYSDIR"

  ; 0a) Best-effort cleanup of previous runtime to avoid locked DLL overwrite.
  ${If} ${FileExists} "$INSTDIR\\PIMELauncher.exe"
    !insertmacro LOG "[0a] launcher /quit"
    !insertmacro LOG "[cmd] $INSTDIR\\PIMELauncher.exe /quit"
    ExecWait '"$INSTDIR\\PIMELauncher.exe" /quit' $9
    !insertmacro LOG "[cmd-exit] launcher quit=$9"
    Sleep 1000
  ${EndIf}
  !insertmacro LOG "[0a] taskkill launcher"
  !insertmacro LOG "[cmd] cmd /c taskkill /F /IM PIMELauncher.exe >nul 2>nul"
  nsExec::Exec 'cmd /c taskkill /F /IM PIMELauncher.exe >nul 2>nul'
  Pop $9
  !insertmacro LOG "[cmd-exit] taskkill=$9"
  Sleep 600

  !insertmacro LOG "[0a] remove current registered x86/x64 if exists"
  SetRegView 32
  ClearErrors
  ReadRegStr $3 HKCR "CLSID\\${PIME_TSF_CLSID}\\InprocServer32" ""
  !insertmacro LOG "[diag] current registered x86=$3"
  ${If} ${RunningX64}
    SetRegView 64
    ClearErrors
    ReadRegStr $4 HKCR "CLSID\\${PIME_TSF_CLSID}\\InprocServer32" ""
    !insertmacro LOG "[diag] current registered x64=$4"
  ${Else}
    StrCpy $4 ""
  ${EndIf}
  Call DeletePimeRegistration
  !insertmacro LOG "[cmd-exit] delete registration keys=0"
  SetRegView 32

  ; 1) Install core runtime and McBopomofo payload
  !insertmacro LOG "[1] file copy start"
  SetOutPath "$INSTDIR"
  File /r "${STAGING_DIR}\\core\\*.*"
  ; Some NSIS builds may keep top-level "core" folder when using /r.
  ; If so, flatten it into $INSTDIR.
  IfFileExists "$INSTDIR\\core\\*.*" 0 +4
    !insertmacro LOG "[cmd] cmd /c xcopy /E /I /Y $INSTDIR\\core\\* $INSTDIR\\ >nul 2>nul"
    nsExec::Exec 'cmd /c xcopy /E /I /Y "$INSTDIR\\core\\*" "$INSTDIR\\" >nul 2>nul'
    Pop $9
    !insertmacro LOG "[cmd-exit] xcopy flatten=$9"
    RMDir /r "$INSTDIR\\core"
    !insertmacro LOG "[1] flattened nested core folder"
  !insertmacro LOG "[1] file copy done"

  ; 1.5) Required files sanity check
  !insertmacro LOG "[1.5] required files check"
  !insertmacro LOG_FILE_CHECK "$INSTDIR\\PIMELauncher.exe" "PIMELauncher"
  !insertmacro LOG_FILE_CHECK "$INSTDIR\\x86\\PIMETextService.dll" "x86 TSF DLL"
  !insertmacro LOG_FILE_CHECK "$INSTDIR\\x64\\PIMETextService.dll" "x64 TSF DLL"
  !insertmacro LOG_FILE_CHECK "$INSTDIR\\node\\input_methods\\McBopomofo\\ime.json" "McBopomofo ime.json"
  ${IfNot} ${FileExists} "$INSTDIR\\PIMELauncher.exe"
    !insertmacro FAIL_INSTALL "Install failed: PIMELauncher.exe is missing." "ERROR missing PIMELauncher.exe"
  ${EndIf}
  ${IfNot} ${FileExists} "$INSTDIR\\x86\\PIMETextService.dll"
    !insertmacro FAIL_INSTALL "Install failed: x86 PIMETextService.dll is missing." "ERROR missing x86 PIMETextService.dll"
  ${EndIf}
  ${IfNot} ${FileExists} "$INSTDIR\\node\\input_methods\\McBopomofo\\ime.json"
    !insertmacro FAIL_INSTALL "Install failed: McBopomofo ime.json is missing." "ERROR missing ime.json"
  ${EndIf}
  ${If} ${RunningX64}
    ${IfNot} ${FileExists} "$INSTDIR\\x64\\PIMETextService.dll"
      !insertmacro FAIL_INSTALL "Install failed: x64 PIMETextService.dll is missing." "ERROR missing x64 PIMETextService.dll"
    ${EndIf}
  ${EndIf}

  ; 2) (Optional) Install VC Runtime (Full package only)
  !if "${INCLUDE_VCREDIST}" == "1"
    !insertmacro LOG "[2] vc_redist install start"
    SetOutPath "$TEMP\\McBopomofoPIME"
    File "${STAGING_DIR}\\vcredist\\vc_redist.x64.exe"
    !insertmacro LOG "[cmd] $TEMP\\McBopomofoPIME\\vc_redist.x64.exe /install /quiet /norestart"
    ExecWait '"$TEMP\\McBopomofoPIME\\vc_redist.x64.exe" /install /quiet /norestart' $2
    !insertmacro LOG "[cmd-exit] vc_redist.x64=$2"

    !ifdef VCREDIST_X86_PRESENT
      File "${STAGING_DIR}\\vcredist\\vc_redist.x86.exe"
      !insertmacro LOG "[cmd] $TEMP\\McBopomofoPIME\\vc_redist.x86.exe /install /quiet /norestart"
      ExecWait '"$TEMP\\McBopomofoPIME\\vc_redist.x86.exe" /install /quiet /norestart' $2
      !insertmacro LOG "[cmd-exit] vc_redist.x86=$2"
    !endif
    !insertmacro LOG "[2] vc_redist install done"
  !endif

  ; 3) Default user config (only if packaged and user file doesn't exist yet)
  !insertmacro LOG "[3] default config step"
  !ifdef DEFAULT_CONFIG_PRESENT
    CreateDirectory "$APPDATA\\PIME\\mcbopomofo"
    ${IfNot} ${FileExists} "$APPDATA\\PIME\\mcbopomofo\\config.json"
      File "/oname=$APPDATA\\PIME\\mcbopomofo\\config.json" "${STAGING_DIR}\\core\\defaults\\mcbopomofo\\config.json"
      StrCpy $UserConfigCreated "1"
    ${EndIf}
  !endif

  ; 3.5) Optional font install
  ${If} $InstallFontChoice == "1"
    !insertmacro LOG "[3.5] install bpmfvs font pack"
    SetOutPath "$PLUGINSDIR\\fonts"
    File "${STAGING_DIR}\\core\\fonts\\*.ttf"
    File "/oname=${FONT_HELPER_PS1}" "${STAGING_DIR}\\helpers\\install-fonts.ps1"
    !insertmacro LOG "[cmd] powershell install-fonts.ps1"
    nsExec::Exec '"$SYSDIR\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "${FONT_HELPER_PS1}" -SourceDir "$PLUGINSDIR\\fonts"'
    Pop $0
    !insertmacro LOG "[cmd-exit] install fonts=$0"
    ${If} $0 != 0
      !insertmacro FAIL_INSTALL "Install failed: optional font pack installation failed." "ERROR optional font pack install failed"
    ${EndIf}

    ${If} $UserConfigCreated == "1"
      File "/oname=${CONFIG_FLAG_HELPER_PS1}" "${STAGING_DIR}\\helpers\\set-config-flag.ps1"
      !insertmacro LOG "[cmd] powershell set-config-flag.ps1 bopomofo_font_annotation_support_enabled=true"
      nsExec::Exec '"$SYSDIR\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "${CONFIG_FLAG_HELPER_PS1}" -ConfigPath "$APPDATA\\PIME\\mcbopomofo\\config.json" -Key "bopomofo_font_annotation_support_enabled" -Value "True"'
      Pop $0
      !insertmacro LOG "[cmd-exit] set annotation config=$0"
      ${If} $0 != 0
        !insertmacro FAIL_INSTALL "Install failed: unable to enable the bopomofo font annotation setting." "ERROR unable to enable bopomofo annotation setting"
      ${EndIf}
    ${EndIf}
  ${Else}
    !insertmacro LOG "[3.5] skip optional font pack install"
  ${EndIf}

  ; 4) Register TSF via regsvr32, matching upstream PIME installer behavior.
  !insertmacro LOG "[4] regsvr32 registration start"
  ${If} ${RunningX64}
    SetRegView 64
    ExecWait '"$SYSDIR\\regsvr32.exe" /s "$INSTDIR\\x64\\PIMETextService.dll"' $9
    !insertmacro LOG "[cmd-exit] regsvr32 x64=$9"
  ${Else}
    StrCpy $9 "0"
  ${EndIf}
  SetRegView 32
  ExecWait '"$SYSDIR\\regsvr32.exe" /s "$INSTDIR\\x86\\PIMETextService.dll"' $8
  !insertmacro LOG "[cmd-exit] regsvr32 x86=$8"
  StrCpy $7 "0"
  ${If} $8 != 0
    StrCpy $7 "1"
  ${EndIf}
  ${If} ${RunningX64}
  ${AndIf} $9 != 0
    StrCpy $7 "1"
  ${EndIf}
  SetRegView 64
  ${If} $7 == "1"
    !insertmacro LOG "[4] regsvr32 fallback to direct registry writes"
    Call WritePimeRegistration
  ${EndIf}
  !insertmacro LOG "[4] registration step done"

  ; 5) Auto-start launcher
  !insertmacro LOG "[5] write startup registry"
  WriteRegStr HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Run" "PIMELauncher" "$\"$INSTDIR\\PIMELauncher.exe$\""
  !insertmacro LOG "[5] create startup shortcut"
  CreateShortCut "$SMSTARTUP\\PIMELauncher.lnk" "$INSTDIR\\PIMELauncher.exe" "" "$INSTDIR\\PIMELauncher.exe" 0
  !insertmacro LOG "[5] create start menu shortcuts"
  CreateDirectory "$SMPROGRAMS\\McBopomofo for Windows"
  CreateShortCut "$SMPROGRAMS\\McBopomofo for Windows\\PIMELauncher.lnk" "$INSTDIR\\PIMELauncher.exe" "" "$INSTDIR\\PIMELauncher.exe" 0
  CreateShortCut "$SMPROGRAMS\\McBopomofo for Windows\\McBopomofo Config.lnk" "$INSTDIR\\node\\input_methods\\McBopomofo\\run_config_tool.bat" "" "$INSTDIR\\PIMELauncher.exe" 0
  CreateShortCut "$SMPROGRAMS\\McBopomofo for Windows\\Uninstall McBopomofo for Windows.lnk" "$INSTDIR\\Uninstall-McBopomofoPIME.exe" "" "$INSTDIR\\Uninstall-McBopomofoPIME.exe" 0
  WriteRegStr HKLM "Software\\PIME" "" "$INSTDIR"

  ; 6) Uninstaller metadata
  ; Write uninstaller file first, then publish uninstall registry info.
  ; This avoids a broken Apps/Settings entry if install is interrupted.
  WriteUninstaller "$INSTDIR\\Uninstall-McBopomofoPIME.exe"
  IfFileExists "$INSTDIR\\Uninstall-McBopomofoPIME.exe" uninst_ok 0
    !insertmacro FAIL_INSTALL "Install failed: uninstaller was not created." "ERROR uninstaller not created"
  uninst_ok:
  !insertmacro LOG "[6] uninstaller created"

  StrCpy $UninstKey "${PRODUCT_UNINST_KEY}"
  WriteRegStr HKLM "$UninstKey" "DisplayName" "McBopomofo for Windows"
  WriteRegStr HKLM "$UninstKey" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "$UninstKey" "Publisher" "OpenVanilla"
  WriteRegStr HKLM "$UninstKey" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "$UninstKey" "DisplayIcon" "$INSTDIR\\PIMELauncher.exe"
  WriteRegStr HKLM "$UninstKey" "UninstallString" "$\"$INSTDIR\\Uninstall-McBopomofoPIME.exe$\""
  WriteRegStr HKLM "$UninstKey" "QuietUninstallString" "$\"$INSTDIR\\Uninstall-McBopomofoPIME.exe$\" /S"
  WriteRegDWORD HKLM "$UninstKey" "NoModify" 1
  WriteRegDWORD HKLM "$UninstKey" "NoRepair" 1
  !insertmacro LOG "[6] uninstall registry written"

  ; 7) Restart launcher
  !insertmacro LOG "[7] restart launcher"
  !insertmacro LOG "[cmd] cmd /c taskkill /F /IM PIMELauncher.exe >nul 2>nul"
  nsExec::Exec 'cmd /c taskkill /F /IM PIMELauncher.exe >nul 2>nul'
  Pop $9
  !insertmacro LOG "[cmd-exit] taskkill=$9"
  Sleep 800
  IfSilent skip_launcher_autostart
  !insertmacro LOG "[cmd] Exec PIMELauncher.exe"
  SetOutPath "$INSTDIR"
  ClearErrors
  Exec '"$INSTDIR\\PIMELauncher.exe"'
  ${If} ${Errors}
    !insertmacro LOG "[cmd-exit] start launcher=ExecError"
  ${Else}
    !insertmacro LOG "[cmd-exit] start launcher=launched"
  ${EndIf}
  Goto finish_install
  skip_launcher_autostart:
  !insertmacro LOG "[7] silent install; skip launcher auto-start"

  ; 8) Finish
  finish_install:
  !insertmacro LOG "Install completed."
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  StrCpy $LogFile "$TEMP\\McBopomofoPIME-uninstall.log"
  Delete "$LogFile"
  !insertmacro ULOG "Uninstall start. INSTDIR=$INSTDIR"
  ; Stop launcher
  ${If} ${FileExists} "$INSTDIR\\PIMELauncher.exe"
    !insertmacro ULOG "[U1] launcher /quit"
    !insertmacro ULOG "[cmd] $INSTDIR\\PIMELauncher.exe /quit"
    ExecWait '"$INSTDIR\\PIMELauncher.exe" /quit' $9
    !insertmacro ULOG "[cmd-exit] launcher quit=$9"
    Sleep 1000
  ${EndIf}
  !insertmacro ULOG "[U1] taskkill launcher"
  !insertmacro ULOG "[cmd] cmd /c taskkill /F /T /IM PIMELauncher.exe >nul 2>nul"
  nsExec::Exec 'cmd /c taskkill /F /T /IM PIMELauncher.exe >nul 2>nul'
  Pop $9
  !insertmacro ULOG "[cmd-exit] taskkill=$9"
  !insertmacro ULOG "[cmd] cmd /c taskkill /F /IM node.exe >nul 2>nul"
  nsExec::Exec 'cmd /c taskkill /F /IM node.exe >nul 2>nul'
  Pop $9
  !insertmacro ULOG "[cmd-exit] taskkill node=$9"
  !insertmacro ULOG "[cmd] cmd /c taskkill /F /IM ctfmon.exe >nul 2>nul"
  nsExec::Exec 'cmd /c taskkill /F /IM ctfmon.exe >nul 2>nul'
  Pop $9
  !insertmacro ULOG "[cmd-exit] taskkill ctfmon=$9"
  !insertmacro ULOG "[cmd] cmd /c taskkill /F /IM TextInputHost.exe >nul 2>nul"
  nsExec::Exec 'cmd /c taskkill /F /IM TextInputHost.exe >nul 2>nul'
  Pop $9
  !insertmacro ULOG "[cmd-exit] taskkill TextInputHost=$9"
  Sleep 800

  ; Unregister TSF DLLs, then clean any stale keys.
  !insertmacro ULOG "[U2] unregister x86/x64 registration"
  Call un.DeletePimeRegistration

  DeleteRegValue HKCU "Software\\Microsoft\\Windows\\CurrentVersion\\Run" "PIMELauncher"
  Delete "$SMSTARTUP\\PIMELauncher.lnk"
  Delete "$SMPROGRAMS\\McBopomofo for Windows\\PIMELauncher.lnk"
  Delete "$SMPROGRAMS\\McBopomofo for Windows\\McBopomofo Config.lnk"
  Delete "$SMPROGRAMS\\McBopomofo for Windows\\Uninstall McBopomofo for Windows.lnk"
  RMDir "$SMPROGRAMS\\McBopomofo for Windows"
  DeleteRegKey HKLM "Software\\PIME"
  DeleteRegKey HKLM "${PRODUCT_UNINST_KEY}"
  !insertmacro ULOG "[U3] registry cleaned"

  Delete /REBOOTOK "$INSTDIR\\x64\\PIMETextService.dll"
  Delete /REBOOTOK "$INSTDIR\\x86\\PIMETextService.dll"
  Delete /REBOOTOK "$INSTDIR\\PIMELauncher.exe"
  Delete /REBOOTOK "$INSTDIR\\node\\node.exe"
  Delete /REBOOTOK "$INSTDIR\\Uninstall-McBopomofoPIME.exe"

  ${If} $RemoveFontChoice == "1"
    !insertmacro ULOG "[U4] remove optional bpmfvs fonts"
    SetOutPath "$PLUGINSDIR"
    File "/oname=${UNFONT_HELPER_PS1}" "${STAGING_DIR}\\helpers\\uninstall-fonts.ps1"
    nsExec::Exec '"$SYSDIR\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "${UNFONT_HELPER_PS1}"'
    Pop $9
    !insertmacro ULOG "[cmd-exit] remove fonts=$9"
  ${Else}
    !insertmacro ULOG "[U4] keep optional bpmfvs fonts"
  ${EndIf}

  RMDir /r /REBOOTOK "$INSTDIR"
  !insertmacro ULOG "Uninstall completed."
  ${If} ${RebootFlag}
    !insertmacro ULOG "[U5] reboot required to finish removal"
    IfSilent +2
      MessageBox MB_ICONINFORMATION|MB_OK "Some PIME files are still in use by Windows text input services.$\r$\n$\r$\nPlease restart Windows to completely remove McBopomofo for Windows."
  ${EndIf}
SectionEnd
