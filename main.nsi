!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"
!include "XML.nsh"
!include "nsArray.nsh"
!include "WinMessages.nsh"
!include "FileFunc.nsh"

SetCompressor /SOLID lzma

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

!define VERSION 0.0.1.2
!define ARCHIVE_URL https://archive.org/download/WiiUUSBHelper/
!define ARCHIVE_MIRROR https://dl.nul.sh/WiiUUSBHelper/
!define GITHUB_URL https://api.github.com/repos/FailedShack/USBHelperLauncher/releases/latest
!define GITHUB_MIRROR https://dl.nul.sh/USBHelperLauncher/latest
!define METRICS_URL https://api.nul.sh/metrics
!define UNINST_LOG Uninstall.log

VIProductVersion ${VERSION}
VIAddVersionKey "ProductName" "USBHelperInstaller"
VIAddVersionKey "ProductVersion" ${VERSION}
VIAddVersionKey "LegalCopyright" "Copyright (C) 2019 FailedShack"
VIAddVersionKey "FileDescription" "USBHelperInstaller"
VIAddVersionKey "FileVersion" ${VERSION}
RequestExecutionLevel user
Name "USBHelperLauncher"
OutFile "USBHelperInstaller.exe"

Var Dialog
Var DropDown
Var TempFile
Var Guid

/* Helper Release */
Var HelperVersion

/* Launcher Release */
Var Version
Var Size
Var DownloadUrl
Var ChangeLog

Section Launcher launcher

	Push $DownloadUrl
	Push 0
	Call DownloadTemp
	Push $TempFile
	Call Unzip
	Delete $TempFile

SectionEnd

Section Helper helper

	Push "${ARCHIVE_MIRROR}$HelperVersion.zip"
	Push "${ARCHIVE_URL}$HelperVersion.zip"
	Push 0
	Call DownloadTemp
	Push $TempFile
	Call Unzip
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
	
	Call SendMetrics
	FileOpen $0 "$INSTDIR\guid" w
	FileWrite $0 $Guid
	FileClose $0
	
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

	${IfNot} ${FileExists} "$INSTDIR\${UNINST_LOG}"
		MessageBox MB_OK|MB_ICONSTOP "Missing ${UNINST_LOG}. Cannot uninstall."
		Quit
	${EndIf}
	
	FileOpen $0 "$INSTDIR\guid" r
	FileRead $0 $2
	FileClose $0
	
	FileOpen $0 "$INSTDIR\${UNINST_LOG}" r
	${Do}
		ClearErrors
		FileRead $0 $1
		${If} ${Errors}
			${Break}
		${EndIf}
		StrCpy $1 "$INSTDIR\$1" -2
		Delete $1
		/* Attempt to remove directories */
		${DoUntil} ${Errors}
			${GetParent} $1 $1
			RMDir $1
		${LoopUntil} $1 == $INSTDIR
	${Loop}
	FileClose $0
	
	Delete "$INSTDIR\guid"
	Delete "$INSTDIR\Patched.exe"
	Delete "$INSTDIR\conf.json"
	Delete "$INSTDIR\Icon.ico"
	Delete "$INSTDIR\Changelog.txt"
	Delete "$INSTDIR\Uninstall.exe"
	Delete "$INSTDIR\${UNINST_LOG}"
	RMDir $INSTDIR
	
	Delete "$DESKTOP\Wii U USB Helper.lnk"
	Delete "$SMPROGRAMS\Wii U USB Helper.lnk"
	RMDir /r "$LocalAppData\Hikari06"
	RMDir /r "$AppData\USB_HELPER"
	DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\USBHelperLauncher"
	
	nsJSON::Set /tree metrics /value `{ "Url": "${METRICS_URL}", "Verb": "POST", "DataType": "JSON" }`
	nsJSON::Set /tree metrics "Data" "guid" /value `"$2"` /end
	nsJSON::Set /tree metrics "Data" "event" /value `"uninstall"` /end
	nsJSON::Set /http metrics

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
	Push "${ARCHIVE_MIRROR}WiiUUSBHelper_files.xml"
	Push "${ARCHIVE_URL}WiiUUSBHelper_files.xml"
	Push 1
	Call DownloadTemp
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
		${EndIf}
		${xml::Parent} $1 $0
		${xml::NextSibling} "file" $1 $0
	${EndWhile}
	${xml::Unload}
	
	/* Sort descending by key */
	nsArray::Sort releases 9
	nsArray::Length releases
	Pop $0
	StrCpy $1 0
	${DoWhile} $1 < $0
		nsArray::Get releases /at=$1
		Pop $2
		Pop $3 # Don't care about value
		${NSD_CB_AddString} $DropDown $2
		IntOp $1 $1 + 1
	${Loop}
	
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

Function DownloadTemp

	Pop $0
	StrCpy $1 0
	${DoUntil} ${Errors}
		Pop $2
		${If} $1 = 0
			${If} $0 = 1
				inetc::get /silent $2 $TempFile /end
			${Else}
				inetc::get $2 $TempFile /end
			${EndIf}
			Pop $3
			${If} $3 S== "OK"
				StrCpy $1 1
			${EndIf}
		${EndIf}
	${Loop}
	${If} $1 = 0
		MessageBox MB_OK|MB_ICONSTOP "Could not establish a connection.$\r$\n\
		Please check your internet connection and try again.$\r$\n\
		Reason: $3"
		Quit
	${EndIf}

FunctionEnd

Function Unzip

	Pop $0
	CreateDirectory $INSTDIR
	FileOpen $1 "$INSTDIR\${UNINST_LOG}" a
	FileSeek $1 0 END
	nsisunz::UnzipToStack $0 $INSTDIR
	Pop $0
	${DoUntil} ${Errors}
		Pop $0
		FileWrite $1 "$0$\r$\n"
		DetailPrint "Extract: $0"
	${Loop}
	FileClose $1

FunctionEnd

Function OnDropDownChanged

	Pop $DropDown
	SendMessage $DropDown ${CB_GETCURSEL} 0 0 $0
	nsArray::Get releases /at=$0
	Pop $HelperVersion
	Pop $1
	SectionSetSize ${helper} $1

FunctionEnd

Function RetrieveInfo

	/* Disable input */
	Push 0
	Call ChangeButtonState
	
	Push ${GITHUB_MIRROR}
	Push ${GITHUB_URL}
	Push 1
	Call DownloadTemp
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

Function SendMetrics

	System::Call 'kernel32::GetSystemDefaultLangID() i .r0'
	System::Call 'kernel32::GetLocaleInfoA(i 1024, i 0x59, t .r1, i ${NSIS_MAX_STRLEN}) i r0'
	System::Call 'kernel32::GetLocaleInfoA(i 1024, i 0x5A, t .r2, i ${NSIS_MAX_STRLEN}) i r0'
	StrCpy $0 "$1-$2"
	
	System::Call `ole32::CoCreateGuid(g .r1)`
	StrCpy $Guid $1 -1 1
	
	ReadRegStr $2 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion" ProductName
	${If} $2 == ""
		ReadRegStr $2 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion" ProductName
	${EndIf}
	
	nsJSON::Set /tree metrics /value `{ "Url": "${METRICS_URL}", "Verb": "POST", "DataType": "JSON" }`
	nsJSON::Set /tree metrics "Data" "guid" /value `"$Guid"` /end
	nsJSON::Set /tree metrics "Data" "event" /value `"install"` /end
	nsJSON::Set /tree metrics "Data" "context" /value `"USBHelperInstaller"` /end
	nsJSON::Set /tree metrics "Data" "version" /value `"${VERSION}"` /end
	nsJSON::Set /tree metrics "Data" "os" /value `"$2"` /end
	nsJSON::Set /tree metrics "Data" "locale" /value `"$0"` /end
	nsJSON::Set /tree metrics "Data" "products" "USBHelperLauncher" /value `"$Version"` /end
	nsJSON::Set /tree metrics "Data" "products" "Wii U USB Helper" /value `"$HelperVersion"` /end
	nsJSON::Set /http metrics

FunctionEnd

Function PreDirectory

	StrCpy $INSTDIR "$AppData\USBHelperLauncher"

FunctionEnd
