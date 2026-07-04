[Setup]
AppName=MerkaERP
AppVersion=1.0.0
DefaultDirName={pf}\MerkaERP
DefaultGroupName=MerkaERP
OutputBaseFilename=MerkaERP_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
UninstallDisplayIcon={app}\MerkaERP.exe

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\MerkaERP"; Filename: "{app}\MerkaERP.exe"
Name: "{commondesktop}\MerkaERP"; Filename: "{app}\MerkaERP.exe"

[Run]
Filename: "{app}\MerkaERP.exe"; Description: "Launch MerkaERP"; Flags: nowait postinstall skipifsilent
