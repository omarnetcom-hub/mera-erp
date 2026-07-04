[Setup]
AppName=MerkaERP
AppVersion=1.0.4
AppPublisher=MerkaERP
DefaultDirName={pf}\MerkaERP
DefaultGroupName=MerkaERP
OutputBaseFilename=MerkaERP-Installer-v1.0.4
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
UninstallDisplayIcon={app}\MerkaERP.exe
OutputDir=installers

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\MerkaERP"; Filename: "{app}\MerkaERP.exe"
Name: "{group}\Desinstalar MerkaERP"; Filename: "{uninstallexe}"
Name: "{commondesktop}\MerkaERP"; Filename: "{app}\MerkaERP.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Crear icono en el escritorio"; GroupDescription: "Iconos adicionales:"

[Run]
Filename: "{app}\MerkaERP.exe"; Description: "Iniciar MerkaERP"; Flags: nowait postinstall skipifsilent
