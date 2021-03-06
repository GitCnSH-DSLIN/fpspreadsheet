unit beUtils;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, Forms,
  fpstypes, fpspreadsheet;

function  CreateIni : TCustomIniFile;
procedure ReadFormFromIni(ini: TCustomIniFile; ASection: String; AForm: TCustomForm);
procedure WriteFormToIni(ini: TCustomIniFile; ASection: String; AForm: TCustomForm);

function GetFileFormatName(AFormat: TsSpreadsheetFormat): String;
function GetFormatFromFileHeader(const AFileName: TFileName;
  out SheetType: TsSpreadsheetFormat): Boolean;


implementation

uses
  uvirtuallayer_ole;

function CreateIni : TCustomIniFile;
var
  cfg : string;
begin
  cfg := GetAppConfigDir(false);
  if not DirectoryExists(cfg) then
    CreateDir(cfg);
  result := TMemIniFile.Create(GetAppConfigFile(false));
end;

procedure ReadFormFromIni(ini: TCustomIniFile; ASection: String; AForm: TCustomForm);
var
  L,T,W,H: Integer;
  isMax: Boolean;
begin
  L := ini.ReadInteger(ASection, 'Left', AForm.Left);
  T := Ini.ReadInteger(ASection, 'Top', AForm.Top);
  W := ini.ReadInteger(ASection, 'Width', AForm.Width);
  H := ini.ReadInteger(ASection, 'Height', AForm.Height);
  isMax := ini.ReadBool(ASection, 'Maximized', AForm.WindowState = wsMaximized);
  if W > Screen.Width then W := Screen.Width;
  if H > Screen.Height then H := Screen.Height;
  if L < 0 then L := 0;
  if T < 0 then T := 0;
  if L + W > Screen.Width then L := Screen.Width - W;
  if T + H > Screen.Height then T := Screen.Height - H;
  AForm.Left := L;
  AForm.Top := T;
  AForm.Width := W;
  AForm.Height := H;
  if IsMax then
    AForm.WindowState := wsMaximized
  else
    AForm.WindowState := wsNormal;
end;


procedure WriteFormToIni(ini: TCustomIniFile; ASection: String; AForm: TCustomForm);
begin
  ini.WriteBool(ASection, 'Maximized', (AForm.WindowState = wsMaximized));
  if AForm.WindowState = wsNormal then begin
    ini.WriteInteger(ASection, 'Left', AForm.Left);
    ini.WriteInteger(ASection, 'Top', AForm.Top);
    ini.WriteInteger(ASection, 'Width', AForm.Width);
    ini.WriteInteger(ASection, 'Height', AForm.Height);
  end;
end;

function GetFileFormatName(AFormat: TsSpreadsheetFormat): string;
begin
  case AFormat of
    sfExcel2              : Result := 'BIFF2';
    { Excel3/4 not supported fpspreadsheet
    sfExcel3              : Result := 'BIFF3';
    sfExcel4              : Result := 'BIFF4';
    }
    sfExcel5              : Result := 'BIFF5';
    sfExcel8              : Result := 'BIFF8';
    sfooxml               : Result := 'OOXML';
    sfOpenDocument        : Result := 'Open Document';
    sfCSV                 : Result := 'CSV';
    sfWikiTable_Pipes     : Result := 'WikiTable Pipes';
    sfWikiTable_WikiMedia : Result := 'WikiTable WikiMedia';
    else                    Result := '-unknown format-';
  end;
end;

function GetFormatFromFileHeader(const AFileName: TFileName;
  out SheetType: TsSpreadsheetFormat): Boolean;
const
  BIFF2_HEADER: array[0..3] of byte = (
    $09,$00, $04,$00);  // they are common to all BIFF2 files that I've seen
  BIFF58_HEADER: array[0..7] of byte = (
    $D0,$CF, $11,$E0, $A1,$B1, $1A,$E1);

  function ValidOLEStream(AStream: TStream; AName: String): Boolean;
  var
    fsOLE: TVirtualLayer_OLE;
  begin
    AStream.Position := 0;
    fsOLE := TVirtualLayer_OLE.Create(AStream);
    try
      fsOLE.Initialize;
      Result := fsOLE.FileExists('/'+AName);
    finally
      fsOLE.Free;
    end;
  end;

var
  buf: packed array[0..7] of byte = (0,0,0,0,0,0,0,0);
  stream: TStream;
  i: Integer;
  ok: Boolean;
begin
  Result := false;
  stream := TFileStream.Create(AFileName, fmOpenRead + fmShareDenyNone);
  try
    // Read first 8 bytes
    stream.ReadBuffer(buf, 8);

    // Check for Excel 2
    ok := true;
    for i:=0 to High(BIFF2_HEADER) do
      if buf[i] <> BIFF2_HEADER[i] then
      begin
        ok := false;
        break;
      end;
    if ok then
    begin
      SheetType := sfExcel2;
      Exit(True);
    end;

    // Check for Excel 5 or 8
    for i:=0 to High(BIFF58_HEADER) do
      if buf[i] <> BIFF58_HEADER[i] then
        exit;

    // Now we know that the file is a Microsoft compound document.

    // We check for Excel 5 in which the stream is named "Book"
    if ValidOLEStream(stream, 'Book') then begin
      SheetType := sfExcel5;
      exit(True);
    end;

    // Now we check for Excel 8 which names the stream "Workbook"
    if ValidOLEStream(stream, 'Workbook') then begin
      SheetType := sfExcel8;
      exit(True);
    end;

  finally
    stream.Free;
  end;
end;

end.

