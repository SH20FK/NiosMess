[Setup]
AppId={{5A0F5B4B-0D9C-4235-8E1E-1234567890AB}
AppName=NiosMess
AppVersion=1.0.0
AppPublisher=NiosMess
DefaultDirName={autopf}\NiosMess
DefaultGroupName=NiosMess
AllowNoIcons=yes
LicenseFile=F:\Niosmess V2\legal\combined_legal.txt
InfoBeforeFile=F:\Niosmess V2\legal\Политика кондефициальности.txt
OutputDir=F:\Niosmess V2\Output
OutputBaseFilename=NiosMess_Setup
SetupIconFile=F:\Niosmess V2\pulse_flutter\windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "F:\Niosmess V2\pulse_flutter\build\windows\x64\runner\Release\pulse_flutter.exe"; DestDir: "{app}"; DestName: "NiosMess.exe"; Flags: ignoreversion
Source: "F:\Niosmess V2\pulse_flutter\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Excludes: "pulse_flutter.exe, *.msix"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\NiosMess"; Filename: "{app}\NiosMess.exe"
Name: "{group}\{cm:UninstallProgram,NiosMess}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\NiosMess"; Filename: "{app}\NiosMess.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\NiosMess.exe"; Description: "{cm:LaunchProgram,NiosMess}"; Flags: nowait postinstall skipifsilent
