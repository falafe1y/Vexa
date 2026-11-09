; Vexa Windows installer (Inno Setup 6/7).
; Build: ISCC.exe installer\Vexa.iss
; Input: installer\stage\Vexa.exe + all Qt runtime files (windeployqt).
; Inno only packages a prebuilt application; it does not build Qt itself.

#define VexaVersion GetFileVersionString("PORTABLE\Vexa.exe")
#define VexaName "Vexa"
#define VexaExeName "Vexa.exe"

[Setup]
AppId=Vexa
AppName={#VexaName}
AppVersion={#VexaVersion}
AppVerName={#VexaName} {#VexaVersion}
AppPublisher=Vishnevsky Software
DefaultDirName={localappdata}\Programs\Vexa
UsePreviousAppDir=yes
DefaultGroupName=Vexa
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
OutputDir=output
OutputBaseFilename=Vexa-Setup-{#VexaVersion}-win64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=Vexa
CloseApplications=yes
RestartApplications=no
SetupMutex=Vexa_MoneyTracker_Setup

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительные действия:"; Flags: unchecked

[Files]
; Only application binaries and Qt runtime.
; User databases, backups and settings must not be stored here.
Source: "PORTABLE\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs replacesameversion

[Icons]
Name: "{autoprograms}\Vexa"; Filename: "{app}\{#VexaExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\Vexa"; Filename: "{app}\{#VexaExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#VexaExeName}"; Description: "Запустить Vexa"; WorkingDir: "{app}"; Flags: postinstall nowait skipifsilent runasoriginaluser
