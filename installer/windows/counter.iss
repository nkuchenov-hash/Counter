; Counter — per-user Windows installer (Inno Setup 6).

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
CloseApplications=force
CloseApplicationsFilter=*.exe,*.dll

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

[Code]
function KillProcessByName(const ExeName: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec('taskkill.exe', '/IM ' + ExeName + ' /T /F', '', SW_HIDE,
    ewWaitUntilTerminated, ResultCode);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  NeedsRestart := False;
  Log('DESKTOP_INSTALLER_CLOSE_RUNNING_APP_STARTED');
  if KillProcessByName('counter.exe') then
    Log('DESKTOP_INSTALLER_COUNTER_PROCESS_CLOSED');
  if KillProcessByName('counter_stt_helper.exe') then
    Log('DESKTOP_INSTALLER_STT_HELPER_PROCESS_CLOSED');
  Log('DESKTOP_INSTALLER_NO_STALE_PROCESS_AFTER_INSTALL');
  Result := '';
end;
