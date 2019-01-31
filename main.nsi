!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "ZipDLL.nsh"
!include "LogicLib.nsh"
!include "XML.nsh"
!include "nsArray.nsh"
!include "WinMessages.nsh"

!define MUI_ICON "Icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "bg.bmp"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "gpl-3.0.rtf"
Page custom VersionSelect

!define MUI_PAGE_CUSTOMFUNCTION_PRE PreDirectory
!define MUI_PAGE_CUSTOMFUNCTION_SHOW RetrieveInfo
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_RUN "$INSTDIR\USBHelperLauncher.exe"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Show Changelog"
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\Changelog.txt"
!define MUI_FINISHPAGE_LINK "View USBHelperLauncher on Github!"
!define MUI_FINISHPAGE_LINK_LOCATION "https://github.com/FailedShack/USBHelperLauncher"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

!define ARCHIVE_URL https://archive.org/download/WiiUUSBHelper/

RequestExecutionLevel user
Name "USBHelperLauncher"
OutFile "USBHelperInstaller.exe"

Var Dialog
Var DropDown
Var TempFile

/* Helper Release */
Var HelperVersion

/* Launcher Release */
Var Version
Var Size
Var DownloadUrl
Var ChangeLog

Section Launcher launcher

	inetc::get $DownloadUrl $TempFile
	Call EnsureSuccess
	!insertmacro ZIPDLL_EXTRACT $TempFile $INSTDIR "<ALL>"
	Delete $TempFile

SectionEnd

Section Helper helper

	inetc::get "${ARCHIVE_URL}$HelperVersion.zip" $TempFile
	Call EnsureSuccess
	!insertmacro ZIPDLL_EXTRACT $TempFile $INSTDIR "<ALL>"
	Delete $TempFile

SectionEnd

Section Finish

	SetOutPath $INSTDIR
	File "Icon.ico"

	FileOpen $0 "$INSTDIR\Changelog.txt" w
	FileWrite $0 "USBHelperLauncher $Version Changelog:$\r$\n$\r$\n"
	FileWrite $0 $ChangeLog
	FileClose $0
	
	CreateShortCut "$DESKTOP\Wii U USB Helper.lnk" "$INSTDIR\USBHelperLauncher.exe"
	CreateShortCut "$SMPROGRAMS\Wii U USB Helper.lnk" "$INSTDIR\USBHelperLauncher.exe"
	
	${If} ${FileExists} "$LocalAppData\Hikari06"
	${OrIf} ${FileExists} "$AppData\USB_HELPER"
		${If} ${Cmd} 'MessageBox MB_YESNO|MB_ICONEXCLAMATION "Data from a previous installation has been found.$\r$\n\
		Do you wish to delete it?" /SD IDYES IDNO'
			RMDir /r "$LocalAppData\Hikari06"
			RMDir /r "$AppData\USB_HELPER"
		${EndIf}
	${EndIf}
	
	WriteUninstaller "$INSTDIR\Uninstall.exe"
	StrCpy $0 "Software\Microsoft\Windows\CurrentVersion\Uninstall\USBHelperLauncher"
	WriteRegStr HKCU $0 "DisplayName" "USBHelperLauncher"
	WriteRegStr HKCU $0 "UninstallString" "$\"$INSTDIR\Uninstall.exe$\""
	WriteRegStr HKCU $0 "QuietUninstallString" "$\"$INSTDIR\Uninstall.exe$\" /S"
	WriteRegStr HKCU $0 "InstallLocation" "$\"$INSTDIR$\""
	WriteRegStr HKCU $0 "DisplayIcon" "$\"$INSTDIR\Icon.ico$\""
	WriteRegStr HKCU $0 "Publisher" "FailedShack"
	WriteRegStr HKCU $0 "DisplayVersion" $Version
	WriteRegDWORD HKCU $0 "NoModify" 1
	WriteRegDWORD HKCU $0 "NoRepair" 1

SectionEnd

Section Uninstall

	Delete "$DESKTOP\Wii U USB Helper.lnk"
	Delete "$SMPROGRAMS\Wii U USB Helper.lnk"
	RMDir /r "$INSTDIR"
	RMDir /r "$LocalAppData\Hikari06"
	RMDir /r "$AppData\USB_HELPER"
	DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\USBHelperLauncher"

SectionEnd

Function VersionSelect

	/* Disable input */
	Push 0
	Call ChangeButtonState
	
	nsDialogs::Create 1018
	Pop $Dialog
	
	${NSD_CreateComboBox} 0 0 50% 100% ""
	Pop $DropDown
	
	/* Load Wii U USB Helper releases */
	GetTempFileName $TempFile
	inetc::get /silent "${ARCHIVE_URL}WiiUUSBHelper_files.xml" $TempFile
	Call EnsureSuccess
	${xml::LoadFile} "$TempFile" $0
	${xml::GotoPath} "/files" $0
	${xml::FirstChild} "file" $1 $0
	${While} $0 == 0
		${xml::GetAttribute} "name" $2 $0
		${xml::FirstChild} "size" $1 $0
		${xml::GetText} $3 $0
		${xml::NextSibling} "format" $1 $0
		${xml::GetText} $1 $0
		${If} $1 S== "ZIP"
			StrCpy $2 $2 -4 # Remove extension
			IntOp $3 $3 / 1000 # Bytes to KB
			nsArray::Set releases /key=$2 $3
			${NSD_CB_AddString} $DropDown $2
		${EndIf}
		${xml::Parent} $1 $0
		${xml::NextSibling} "file" $1 $0
	${EndWhile}
	${xml::Unload}
	
	/* Select 0.6.1.653 by default */
	StrCpy $HelperVersion "Wii U USB Helper 0.6.1.653"
	${NSD_CB_SelectString} $DropDown $HelperVersion
	nsArray::Get releases $HelperVersion
	Pop $0
	SectionSetSize ${helper} $0
	
	${NSD_OnChange} $DropDown OnDropDownChanged
	
	/* Enable input */
	Push 1
	Call ChangeButtonState
	
	!insertmacro MUI_HEADER_TEXT "Choose Wii U USB Helper Version" "The default selection is recommended for most users."
	nsDialogs::Show

FunctionEnd

Function ChangeButtonState

	Pop $0
	Push $1
	GetDlgItem $1 $HWNDPARENT 1
	EnableWindow $1 $0
	GetDlgItem $1 $HWNDPARENT 2
	EnableWindow $1 $0
	GetDlgItem $1 $HWNDPARENT 3
	EnableWindow $1 $0
	Pop $1

FunctionEnd

Function EnsureSuccess

	Pop $0
	${If} $0 S!= "OK"
		MessageBox MB_OK|MB_ICONSTOP "Could not establish a connection.$\r$\n\
		Please check your internet connection and try again.$\r$\n\
		Reason: $0"
		Quit
	${EndIf}

FunctionEnd

Function OnDropDownChanged

	Pop $DropDown
	SendMessage $DropDown ${CB_GETCURSEL} 0 0 $0
	nsArray::Get releases /at=$0
	Pop $1 # Don't care about key
	Pop $1
	SectionSetSize ${helper} $1

FunctionEnd


Function RetrieveInfo

	/* Disable input */
	Push 0
	Call ChangeButtonState
	
	inetc::get /silent "https://api.github.com/repos/FailedShack/USBHelperLauncher/releases/latest" $TempFile
	Call EnsureSuccess
	nsJSON::Set /file $TempFile
	nsJSON::Get "tag_name" /end
	Pop $Version
	nsJSON::Get "body" /end
	Pop $ChangeLog
	nsJSON::Get "assets" /index 0 "size" /end
	Pop $Size
	IntOp $Size $Size / 1000
	SectionSetSize ${launcher} $Size
	nsJSON::Get "assets" /index 0 "browser_download_url" /end
	Pop $DownloadUrl
	Delete $TempFile
	
	/* Enable input */
	Push 1
	Call ChangeButtonState

FunctionEnd

Function PreDirectory

	StrCpy $INSTDIR "$AppData\USBHelperLauncher"

FunctionEnd
