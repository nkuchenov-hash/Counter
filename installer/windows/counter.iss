; Counter — per-user Windows installer (Inno Setup 6).
; Packages the full Flutter Windows Release folder (counter.exe + DLLs + data/).
;
; Local compile (after flutter build windows --release):
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\windows\counter.iss
;
; CI may override paths:
;   ISCC.exe /DReleaseDir=build\windows\x64\runner\Release /DOutputDir=installer\windows\output installer\windows\counter.iss

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

#ifndef ReleaseDir
  #define ReleaseDir "..\..\build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
  #define OutputDir "output"
#endif

#define MyAppName "Counter"
#define MyAppExeName "counter.exe"
#define MyAppPublisher "Counter"
#define MyAppURL "https://nkuchenov-hash.github.io/Counter/"

[Setup]
AppId={{A7B3C4D5-E6F7-4890-ABCD-EF1234567890}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\Programs\Counter
DefaultGroupName={#MyAppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#OutputDir}
OutputBaseFilename=CounterSetup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: checkedonce
Name: "autostart"; Description: "Start Counter at Windows login (hidden to tray)"; GroupDescription: "Startup:"; Flags: checkedonce

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"" --tray"; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Parameters: "--tray"; Description: "Launch {#MyAppName} in tray"; Flags: nowait postinstall skipifsilent unchecked

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
