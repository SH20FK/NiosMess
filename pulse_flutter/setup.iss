[Setup]
AppId={{D37F0262-4217-4B69-A3A8-1E745A0079C1}
AppName=NiosMess
AppVersion=1.0.0
AppPublisher=NiosMess Team
DefaultDirName={autopf}\NiosMess
DisableProgramGroupPage=yes
LicenseFile=F:\Niosmess V2\legal\combined_legal.txt
OutputBaseFilename=NiosMess_Setup
SetupIconFile=F:\Niosmess V2\pulse_flutter\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "F:\Niosmess V2\pulse_flutter\build\windows\x64\runner\Release\pulse_flutter.exe"; DestDir: "{app}"; DestName: "NiosMess.exe"; Flags: ignoreversion
Source: "F:\Niosmess V2\pulse_flutter\build\windows\x64\runner\Release\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "F:\Niosmess V2\pulse_flutter\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "F:\Niosmess V2\pulse_flutter\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\NiosMess"; Filename: "{app}\NiosMess.exe"
Name: "{autodesktop}\NiosMess"; Filename: "{app}\NiosMess.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\NiosMess.exe"; Description: "{cm:LaunchProgram,NiosMess}"; Flags: nowait postinstall skipifsilent
