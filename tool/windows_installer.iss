; Install binaries only. AppData and credentials survive upgrades/uninstall.
[Setup]
AppId={{1DF6E22B-B9F8-4315-BE3A-F09B81F35051}
AppName=Expense Tracker
AppVersion={#AppVersion}
AppVerName=Expense Tracker {#AppVersion}
VersionInfoVersion={#AppVersion}.{#BuildNumber}
DefaultDirName={localappdata}\Programs\ExpenseTracker
DefaultGroupName=Expense Tracker
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=expense-tracker-{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\expense_tracker.exe

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Expense Tracker"; Filename: "{app}\expense_tracker.exe"

[Run]
Filename: "{app}\expense_tracker.exe"; Description: "Open Expense Tracker"; Flags: nowait postinstall skipifsilent
