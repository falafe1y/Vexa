#define VexaName "Vexa"
#define VexaExeName "Vexa.exe"
#define VexaVersion GetStringFileInfo("for_release\PORTABLE\Vexa.exe", "ProductVersion")
#define VexaPublisher GetStringFileInfo("for_release\PORTABLE\Vexa.exe", "CompanyName")

[Setup]
AppId=Vexa
AppName={#VexaName}
AppVersion={#VexaVersion}
AppVerName={#VexaName} {#VexaVersion}
AppPublisher={#VexaPublisher}
DefaultDirName={localappdata}\Programs\Vexa
UsePreviousAppDir=no
DisableDirPage=no
DefaultGroupName=Vexa
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
OutputDir=for_release
OutputBaseFilename=Vexa-Setup-{#VexaVersion}-win64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=Vexa

; Request graceful shutdown of running applications
CloseApplications=yes

; Do not forcibly terminate applications
RestartApplications=no

; Prevent simultaneous Vexa installer instances
SetupMutex=Vexa_MoneyTracker_Setup

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительные действия:"; Flags: unchecked

[Files]
; Install application and its dependencies
; Never include user database or backups here
Source: "for_release\PORTABLE\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs replacesameversion

[Icons]
Name: "{autoprograms}\Vexa"; Filename: "{app}\{#VexaExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\Vexa"; Filename: "{app}\{#VexaExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#VexaExeName}"; Description: "Запустить Vexa"; WorkingDir: "{app}"; Flags: postinstall nowait skipifsilent runasoriginaluser
