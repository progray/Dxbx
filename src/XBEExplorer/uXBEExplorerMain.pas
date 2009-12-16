(*
    This file is part of Dxbx - a XBox emulator written in Delphi (ported over from cxbx)
    Copyright (C) 2007 Shadow_tj and other members of the development team.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*)
unit uXBEExplorerMain;

{$INCLUDE Dxbx.inc}

interface

uses
  // Delphi
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus, ComCtrls, Grids, ExtCtrls,
  StdCtrls, // TMemo
  Math, // Min
  ShellAPI, // DragQueryFile
  // Dxbx
  uConsts,
  uTypes,
  uXbe,
  uHexViewer,
  uStringsViewer;

type
  TFormXBEExplorer = class(TForm)
    MainMenu1: TMainMenu;
    TreeView1: TTreeView;
    PageControl1: TPageControl;
    File1: TMenuItem;
    Open1: TMenuItem;
    N1: TMenuItem;
    Exit1: TMenuItem;
    Help1: TMenuItem;
    About1: TMenuItem;
    OpenDialog1: TOpenDialog;
    Close1: TMenuItem;
    procedure Open1Click(Sender: TObject);
    procedure Exit1Click(Sender: TObject);
    procedure Close1Click(Sender: TObject);
    procedure TreeView1Change(Sender: TObject; Node: TTreeNode);
    procedure About1Click(Sender: TObject);
  protected
    MyXBE: TXbe;
    FXBEFileName: string;
    procedure CloseFile;
    procedure GridAddRow(const aStringGrid: TStringGrid; const aStrings: array of string);
    function NewGrid(const aFixedCols: Integer; const aTitles: array of string): TStringGrid;
    procedure SectionClick(Sender: TObject);
    procedure LibVersionClick(Sender: TObject);
    function OpenFile(const aFilePath: string): Boolean;
    procedure OnDropFiles(var Msg: TMessage); message WM_DROPFILES;
  public
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
  end;

var
  FormXBEExplorer: TFormXBEExplorer;

implementation

{$R *.dfm}

constructor TFormXBEExplorer.Create(Owner: TComponent);
begin
  inherited Create(Owner);

  // Start accepting WM_DROPFILES messages (see OnDropFiles) :
  DragAcceptFiles(Handle, True);
end;

destructor TFormXBEExplorer.Destroy;
begin
  CloseFile;

  inherited Destroy;
end;

procedure TFormXBEExplorer.Exit1Click(Sender: TObject);
begin
  Close;
end;

procedure TFormXBEExplorer.About1Click(Sender: TObject);
begin
  TaskMessageDlg('About ' + Application.Title,
    'XBE Explorer � 2009, PatrickvL.  Released under GPL3.'#13#13 +
    'XBE Explorer is part of Dxbx - the Delphi Xbox1 emulator.'#13#13 +
    'Website : http://sourceforge.net/projects/dxbx/',
    mtInformation, [mbOK], 0);
end;

procedure TFormXBEExplorer.Close1Click(Sender: TObject);
begin
  CloseFile;
end;

procedure TFormXBEExplorer.CloseFile;
begin
  FreeAndNil(MyXBE);
  TreeView1.Items.Clear;
  Caption := Application.Title;
  PageControl1.Visible := False;
  while PageControl1.PageCount > 0 do
    PageControl1.Pages[0].Free;
end;

procedure TFormXBEExplorer.Open1Click(Sender: TObject);
begin
  if OpenDialog1.Execute then
    OpenFile(OpenDialog1.FileName);
end;

procedure TFormXBEExplorer.OnDropFiles(var Msg: TMessage);
var
  i: Integer;
  FileName: array [0..MAX_PATH] of Char;
begin
  // Scan for dropped XBE files in reverse, as Windows generally offers them
  // in reversed order (see http://www.techtricks.com/delphi/dropfiles.php) :
  for i := DragQueryFile(Msg.wParam, $FFFFFFFF, FileName, MAX_PATH) - 1 downto 0 do
  begin
    if  (DragQueryFile(Msg.wParam, i, FileName, MAX_PATH) > 0)
    and FileExists(FileName)
    and OpenFile(FileName) then
      // Accept only one file :
      Break;
  end;

  // Release memory 
  DragFinish(Msg.wParam);
end;

procedure TFormXBEExplorer.GridAddRow(const aStringGrid: TStringGrid; const aStrings: array of string);
var
  i, w: Integer;
  Row: TStrings;
begin
  i := 0;
  while (i <= aStringGrid.FixedRows) and (aStringGrid.Cells[0, i] <> '') do
    Inc(i);

  if i > aStringGrid.FixedRows then
  begin
    i := aStringGrid.RowCount;
    aStringGrid.RowCount := aStringGrid.RowCount + 1;
  end;

  Row := aStringGrid.Rows[i];
  for i := 0 to Length(aStrings) - 1 do
  begin
    Row[i] := aStrings[i];
    w := {aStringGrid.}Canvas.TextWidth(aStrings[i]) + 5;
    if aStringGrid.ColWidths[i] < w then
      aStringGrid.ColWidths[i] := w
  end;
end;

procedure TFormXBEExplorer.SectionClick(Sender: TObject);
var
  Grid: TStringGrid;
  i: DWord;
  Hdr: PXbeSectionHeader;
begin
  if not (Sender is TStringGrid) then
    Exit;

  Grid := TStringGrid(Sender);
  i := Grid.Row - Grid.FixedRows;
  Hdr := @(MyXBE.m_SectionHeader[i]);
  i := (i * SizeOf(TXbeSectionHeader)) + MyXBE.m_Header.dwSectionHeadersAddr - MyXBE.m_Header.dwBaseAddr;

  Grid.Cells[2, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeSectionHeader(nil).dwFlags));
  Grid.Cells[3, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeSectionHeader(nil).dwVirtualAddr));
  Grid.Cells[4, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeSectionHeader(nil).dwVirtualSize));
  Grid.Cells[5, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeSectionHeader(nil).dwRawAddr));
  Grid.Cells[6, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeSectionHeader(nil).dwSizeofRaw));
  Grid.Cells[7, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeSectionHeader(nil).dwSectionNameAddr));
  Grid.Cells[8, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeSectionHeader(nil).dwSectionRefCount));
  Grid.Cells[9, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeSectionHeader(nil).dwHeadSharedRefCountAddr));
  Grid.Cells[10, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeSectionHeader(nil).dwTailSharedRefCountAddr));
  Grid.Cells[11, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeSectionHeader(nil).bzSectionDigest));

  THexViewer(TStringGrid(Sender).Tag).SetRegion(@MyXBE.RawData[Hdr.dwRawAddr],
    Hdr.dwSizeofRaw, Hdr.dwRawAddr, 'section "' + Grid.Cells[0, Grid.Row] + '"');
end; // SectionClick

procedure TFormXBEExplorer.LibVersionClick(Sender: TObject);
var
  Grid: TStringGrid;
  i: DWord;
begin
  if not (Sender is TStringGrid) then
    Exit;

  Grid := TStringGrid(Sender);
  i := Grid.Row - Grid.FixedRows;
  i := (i * SizeOf(TXbeLibraryVersion)) + MyXBE.m_Header.dwLibraryVersionsAddr - MyXBE.m_Header.dwBaseAddr;

  Grid.Cells[1, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeLibraryVersion(nil).szName));
  Grid.Cells[2, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeLibraryVersion(nil).wMajorVersion));
  Grid.Cells[3, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeLibraryVersion(nil).wMinorVersion));
  Grid.Cells[4, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeLibraryVersion(nil).wBuildVersion));
  Grid.Cells[5, 2] :=  DWord2Str(i + FIELD_OFFSET(PXbeLibraryVersion(nil).dwFlags));
end; // LibVersionClick

function TFormXBEExplorer.NewGrid(const aFixedCols: Integer; const aTitles: array of string): TStringGrid;
var
  i: Integer;
begin
  Result := TStringGrid.Create(Self);
  Result.RowCount := 2;
  Result.DefaultRowHeight := Canvas.TextHeight('Wg') + 5;
  Result.ColCount := Length(aTitles);
  Result.FixedCols := aFixedCols;
  Result.Options := Result.Options + [goColSizing] - [goRowSizing, goRangeSelect];
  GridAddRow(Result, aTitles);
  for i := 0 to Length(aTitles) - 1 do
    Result.Cells[i, 0] := string(aTitles[i]);
end;

function TFormXBEExplorer.OpenFile(const aFilePath: string): Boolean;
var
  NodeResources: TTreeNode;

  function _Offset(var aValue; const aBaseAddr: DWord = 0): string;
  begin
    Result := DWord2Str(aBaseAddr + FIELD_OFFSET(aValue));
  end;

  function _CreateNode(const aParentNode: TTreeNode; const aName: string; aContents: TControl): TTreeNode;
  var
    TabSheet: TTabSheet;
  begin
    TabSheet := TTabSheet.Create(Self);
    TabSheet.PageControl := PageControl1;
    TabSheet.TabVisible := False;
    if Assigned(aContents) then
    begin
      aContents.Parent := TabSheet;
      aContents.Align := alClient;
    end
    else
      ; // TODO : Show 'Select subnode for more details' or something.

    Result := TreeView1.Items.AddChildObject(aParentNode, aName, TabSheet);
  end; // _CreateNode

  function _Initialize_XPRSection(const aXPR_IMAGE: PXPR_IMAGE): TImage;
  begin
    Result := TImage.Create(Self);
    MyXbe.ExportXPRToBitmap(aXPR_IMAGE, Result.Picture.Bitmap);
  end;

  function _Initialize_IniSection(const aIni: WideString): TMemo;
  begin
    Result := TMemo.Create(Self);
    Result.SetTextBuf(PChar(string(aIni)));
  end;

  function _Initialize_Logo: TImage;
  begin
    Result := TImage.Create(Self);
    MyXbe.ExportLogoBitmap(Result.Picture.Bitmap)
  end;

  function _CreateGrid_File: TStringGrid;
  begin
    Result := NewGrid(1, ['Property', 'Value']);
    GridAddRow(Result, ['File Name', aFilePath]);
    GridAddRow(Result, ['File Type', 'XBE File']);
    GridAddRow(Result, ['File Size', IntToStr(MyXBE.FileSize) + ' bytes']);
  end;

  function _Initialize_XBEHeader: TStringGrid;
  var
    Hdr: PXbeHeader;
  begin
    Hdr := @(MyXBE.m_Header);
    Result := NewGrid(3, ['Member', 'Type', 'Offset', 'Value', 'Meaning']);
    GridAddRow(Result, ['dwMagic', 'Char[4]', _offset(PXbeHeader(nil).dwMagic), Hdr.dwMagic]);
    GridAddRow(Result, ['pbDigitalSignature', 'Byte[256]', _offset(PXbeHeader(nil).pbDigitalSignature), PByteToHexString(@Hdr.pbDigitalSignature[0], 16) + '...']);
    GridAddRow(Result, ['dwBaseAddr', 'Dword', _offset(PXbeHeader(nil).dwBaseAddr), DWord2Str(Hdr.dwBaseAddr)]);
    GridAddRow(Result, ['dwSizeofHeaders', 'Dword', _offset(PXbeHeader(nil).dwSizeofHeaders), DWord2Str(Hdr.dwSizeofHeaders)]);
    GridAddRow(Result, ['dwSizeofImage', 'Dword', _offset(PXbeHeader(nil).dwSizeofImage), DWord2Str(Hdr.dwSizeofImage)]);
    GridAddRow(Result, ['dwSizeofImageHeader', 'Dword', _offset(PXbeHeader(nil).dwSizeofImageHeader), DWord2Str(Hdr.dwSizeofImageHeader)]);
    GridAddRow(Result, ['dwTimeDate', 'Dword', _offset(PXbeHeader(nil).dwTimeDate), DWord2Str(Hdr.dwTimeDate), BetterTime(Hdr.dwTimeDate)]);
    GridAddRow(Result, ['dwCertificateAddr', 'Dword', _offset(PXbeHeader(nil).dwCertificateAddr), DWord2Str(Hdr.dwCertificateAddr)]);
    GridAddRow(Result, ['dwSections', 'Dword', _offset(PXbeHeader(nil).dwSections), DWord2Str(Hdr.dwSections)]);
    GridAddRow(Result, ['dwSectionHeadersAddr', 'Dword', _offset(PXbeHeader(nil).dwSectionHeadersAddr), DWord2Str(Hdr.dwSectionHeadersAddr)]);
    GridAddRow(Result, ['dwInitFlags', 'Dword', _offset(PXbeHeader(nil).dwInitFlags), PByteToHexString(@Hdr.dwInitFlags[0], 4)]);
    GridAddRow(Result, ['dwEntryAddr', 'Dword', _offset(PXbeHeader(nil).dwEntryAddr), DWord2Str(Hdr.dwEntryAddr), Format('Retail: 0x%.8x, Debug: 0x%.8x', [Hdr.dwEntryAddr xor XOR_EP_Retail, Hdr.dwEntryAddr xor XOR_EP_DEBUG])]);
    GridAddRow(Result, ['dwTLSAddr', 'Dword', _offset(PXbeHeader(nil).dwTLSAddr), DWord2Str(Hdr.dwTLSAddr)]);
    GridAddRow(Result, ['dwPeStackCommit', 'Dword', _offset(PXbeHeader(nil).dwPeStackCommit), DWord2Str(Hdr.dwPeStackCommit)]);
    GridAddRow(Result, ['dwPeHeapReserve', 'Dword', _offset(PXbeHeader(nil).dwPeHeapReserve), DWord2Str(Hdr.dwPeHeapReserve)]);
    GridAddRow(Result, ['dwPeHeapCommit', 'Dword', _offset(PXbeHeader(nil).dwPeHeapCommit), DWord2Str(Hdr.dwPeHeapCommit)]);
    GridAddRow(Result, ['dwPeBaseAddr', 'Dword', _offset(PXbeHeader(nil).dwPeBaseAddr), DWord2Str(Hdr.dwPeBaseAddr)]);
    GridAddRow(Result, ['dwPeSizeofImage', 'Dword', _offset(PXbeHeader(nil).dwPeSizeofImage), DWord2Str(Hdr.dwPeSizeofImage)]);
    GridAddRow(Result, ['dwPeChecksum', 'Dword', _offset(PXbeHeader(nil).dwPeChecksum), DWord2Str(Hdr.dwPeChecksum)]);
    GridAddRow(Result, ['dwPeTimeDate', 'Dword', _offset(PXbeHeader(nil).dwPeTimeDate), DWord2Str(Hdr.dwPeTimeDate), BetterTime(Hdr.dwPeTimeDate)]);
    GridAddRow(Result, ['dwDebugPathNameAddr', 'Dword', _offset(PXbeHeader(nil).dwDebugPathNameAddr), DWord2Str(Hdr.dwDebugPathNameAddr), MyXBE.GetAddrStr(Hdr.dwDebugPathNameAddr)]);
    GridAddRow(Result, ['dwDebugFileNameAddr', 'Dword', _offset(PXbeHeader(nil).dwDebugFileNameAddr), DWord2Str(Hdr.dwDebugFileNameAddr), MyXBE.GetAddrStr(Hdr.dwDebugFileNameAddr)]);
    GridAddRow(Result, ['dwDebugUnicodeFileNameAddr', 'Dword', _offset(PXbeHeader(nil).dwDebugUnicodeFileNameAddr), DWord2Str(Hdr.dwDebugUnicodeFileNameAddr)]);
    GridAddRow(Result, ['dwKernelImageThunkAddr', 'Dword', _offset(PXbeHeader(nil).dwKernelImageThunkAddr), DWord2Str(Hdr.dwKernelImageThunkAddr), Format('Retail: 0x%.8x, Debug: 0x%.8x', [Hdr.dwKernelImageThunkAddr xor XOR_KT_RETAIL, Hdr.dwKernelImageThunkAddr xor XOR_KT_DEBUG])]);
    GridAddRow(Result, ['dwNonKernelImportDirAddr', 'Dword', _offset(PXbeHeader(nil).dwNonKernelImportDirAddr), DWord2Str(Hdr.dwNonKernelImportDirAddr)]);
    GridAddRow(Result, ['dwLibraryVersions', 'Dword', _offset(PXbeHeader(nil).dwLibraryVersions), DWord2Str(Hdr.dwLibraryVersions)]);
    GridAddRow(Result, ['dwLibraryVersionsAddr', 'Dword', _offset(PXbeHeader(nil).dwLibraryVersionsAddr), DWord2Str(Hdr.dwLibraryVersionsAddr)]);
    GridAddRow(Result, ['dwKernelLibraryVersionAddr', 'Dword', _offset(PXbeHeader(nil).dwKernelLibraryVersionAddr), DWord2Str(Hdr.dwKernelLibraryVersionAddr)]);
    GridAddRow(Result, ['dwXAPILibraryVersionAddr', 'Dword', _offset(PXbeHeader(nil).dwXAPILibraryVersionAddr), DWord2Str(Hdr.dwXAPILibraryVersionAddr)]);
    GridAddRow(Result, ['dwLogoBitmapAddr', 'Dword', _offset(PXbeHeader(nil).dwLogoBitmapAddr), DWord2Str(Hdr.dwLogoBitmapAddr)]);
    GridAddRow(Result, ['dwSizeofLogoBitmap', 'Dword', _offset(PXbeHeader(nil).dwSizeofLogoBitmap), DWord2Str(Hdr.dwSizeofLogoBitmap)]);
  end; // _Initialize_XBEHeader

  function _Initialize_Certificate: TStringGrid;
  var
    o: DWord;
    i: Integer;
    Cert: PXbeCertificate;
  begin
    o := MyXBE.m_Header.dwCertificateAddr - MyXBE.m_Header.dwBaseAddr;
    Cert := @(MyXBE.m_Certificate);
    Result := NewGrid(3, ['Member', 'Type', 'Offset', 'Value', 'Meaning']);
    GridAddRow(Result, ['dwSize', 'Dword', _offset(PXbeCertificate(nil).dwSize, o), DWord2Str(Cert.dwSize)]);
    GridAddRow(Result, ['dwTimeDate', 'Dword', _offset(PXbeCertificate(nil).dwTimeDate, o), DWord2Str(Cert.dwTimeDate), BetterTime(Cert.dwTimeDate)]);
    GridAddRow(Result, ['dwTitleId', 'Dword', _offset(PXbeCertificate(nil).dwTitleId, o), DWord2Str(Cert.dwTitleId)]);
    GridAddRow(Result, ['wszTitleName', 'WChar[40]', _offset(PXbeCertificate(nil).wszTitleName, o), PWideCharToString(@Cert.wszTitleName[0], 40)]);
    for i := Low(Cert.dwAlternateTitleId) to High(Cert.dwAlternateTitleId) do
      GridAddRow(Result, ['dwAlternateTitleId[' + IntToStr(i) + ']', 'Dword', _offset(PXbeCertificate(nil).dwAlternateTitleId[i], o), DWord2Str(Cert.dwAlternateTitleId[i])]);
    GridAddRow(Result, ['dwAllowedMedia', 'Dword', _offset(PXbeCertificate(nil).dwAllowedMedia, o), DWord2Str(Cert.dwAllowedMedia)]);
    GridAddRow(Result, ['dwGameRegion', 'Dword', _offset(PXbeCertificate(nil).dwGameRegion, o), DWord2Str(Cert.dwGameRegion), GameRegionToString(Cert.dwGameRegion)]);
    GridAddRow(Result, ['dwGameRatings', 'Dword', _offset(PXbeCertificate(nil).dwGameRatings, o), DWord2Str(Cert.dwGameRatings)]);
    GridAddRow(Result, ['dwDiskNumber', 'Dword', _offset(PXbeCertificate(nil).dwDiskNumber, o), DWord2Str(Cert.dwDiskNumber)]);
    GridAddRow(Result, ['dwVersion', 'Dword', _offset(PXbeCertificate(nil).dwVersion, o), DWord2Str(Cert.dwVersion)]);
    GridAddRow(Result, ['bzLanKey', 'Byte[16]', _offset(PXbeCertificate(nil).bzLanKey, o), PByteToHexString(@Cert.bzLanKey[0], 16)]);
    GridAddRow(Result, ['bzSignatureKey', 'Byte[16]', _offset(PXbeCertificate(nil).bzSignatureKey, o), PByteToHexString(@Cert.bzSignatureKey[0], 16)]);
    for i := Low(Cert.bzTitleAlternateSignatureKey) to High(Cert.bzTitleAlternateSignatureKey) do
      GridAddRow(Result, ['bzTitleAlternateSignatureKey[' + IntToStr(i) + ']', 'Byte[16]', _offset(PXbeCertificate(nil).bzTitleAlternateSignatureKey[i], o), PByteToHexString(@Cert.bzTitleAlternateSignatureKey[i][0], 16)]);
  end; // _Initialize_Certificate

  function _Initialize_SectionHeaders: TPanel;
  var
    Grid: TStringGrid;
    i, o: Integer;
    Hdr: PXbeSectionHeader;
    ItemName: string;
    Splitter: TSplitter;
    HexViewer: THexViewer;
  begin
    Result := TPanel.Create(Self);

    Grid := NewGrid(2, [' ', 'Member:', 'Flags', 'Virtual Address', 'Virtual Size',
      'Raw Address', 'Raw Size', 'SectionNamAddr', 'dwSectionRefCount',
      'dwHeadSharedRefCountAddr', 'dwTailSharedRefCountAddr', 'bzSectionDigest']);
    Grid.Parent := Result;
    Grid.Align := alTop;
    Grid.Height := Height div 2;
    Grid.RowCount := 4;
    Grid.Options := Grid.Options + [goRowSelect];
    Grid.FixedRows := 3;
    GridAddRow(Grid, [' ', 'Type:', 'Dword', 'Dword', 'Dword', 'Dword', 'Dword', 'Dword', 'Dword', 'Dword', 'Dword', 'Byte[20]']);
    GridAddRow(Grid, ['Section', 'Offset', '-Click row-']); // This is the offset-row

    o := MyXBE.m_Header.dwSectionHeadersAddr - MyXBE.m_Header.dwBaseAddr;
    for i := 0 to Length(MyXBE.m_SectionHeader) - 1 do
    begin
      Hdr := @(MyXBE.m_SectionHeader[i]);
      ItemName := MyXBE.GetAddrStr(Hdr.dwSectionNameAddr);
      GridAddRow(Grid, [
        ItemName,
        DWord2Str(o),
        PByteToHexString(@Hdr.dwFlags[0], 4),
        DWord2Str(Hdr.dwVirtualAddr),
        DWord2Str(Hdr.dwVirtualSize),
        DWord2Str(Hdr.dwRawAddr),
        DWord2Str(Hdr.dwSizeofRaw),
        DWord2Str(Hdr.dwSectionNameAddr),
        DWord2Str(Hdr.dwSectionRefCount),
        DWord2Str(Hdr.dwHeadSharedRefCountAddr),
        DWord2Str(Hdr.dwTailSharedRefCountAddr),
        PByteToHexString(@Hdr.bzSectionDigest[0], 20)
      ]);

      Inc(o, SizeOf(TXbeSectionHeader));

      // Add image tab when this section seems to contain a XPR resource :
      if PXPR_IMAGE(MyXBE.m_bzSection[i]).hdr.Header.dwMagic = XPR_MAGIC_VALUE then
        _CreateNode(NodeResources, 'Image ' + ItemName,
          _Initialize_XPRSection(PXPR_IMAGE(MyXBE.m_bzSection[i])));

      // Add image tab when this section seems to contain a XPR resource :
      if PWord(MyXBE.m_bzSection[i])^ = $FEFF then
        _CreateNode(NodeResources, 'INI ' + ItemName,
          _Initialize_IniSection(PWideCharToString(@MyXBE.m_bzSection[i][2], (Hdr.dwSizeofRaw div SizeOf(WideChar)) - 1)));
    end;

    Splitter := TSplitter.Create(Self);
    Splitter.Parent := Result;
    Splitter.Align := alTop;
    Splitter.Top := Grid.Height;

    HexViewer := THexViewer.Create(Self);
    HexViewer.Parent := Result;
    HexViewer.Align := alClient;

    Grid.Tag := Integer(HexViewer);
    Grid.OnClick := SectionClick;
  end; // _Initialize_SectionHeaders

  function _Initialize_LibraryVersions: TStringGrid;
  var
    o: DWord;
    i: Integer;
    LibVer: PXbeLibraryVersion;
    ItemName: string;
  begin
    Result := NewGrid(1, ['Member:', 'szName', 'wMajorVersion', 'wMinorVersion', 'wBuildVersion', 'dwFlags']);
    Result.RowCount := 4;
    Result.Options := Result.Options + [goRowSelect];
    Result.FixedRows := 3;
    Result.OnClick := LibVersionClick;
    GridAddRow(Result, ['Type:', 'Char[8]', 'Word', 'Word', 'Word', 'Byte[2]']);
    GridAddRow(Result, ['Offset', '-Click row-']); // This is the offset-row

    o := MyXBE.m_Header.dwLibraryVersionsAddr - MyXBE.m_Header.dwBaseAddr;
    for i := 0 to Length(MyXBE.m_LibraryVersion) - 1 do
    begin
      LibVer := @(MyXBE.m_LibraryVersion[i]);
      ItemName := PCharToString(@LibVer.szName[0], 8);
      GridAddRow(Result, [
        DWord2Str(o),
        ItemName,
        DWord2Str(LibVer.wMajorVersion),
        DWord2Str(LibVer.wMinorVersion),
        IntToStr(LibVer.wBuildVersion),
        PByteToHexString(@LibVer.dwFlags[0], 2)
        ]);
      Inc(o, SizeOf(LibVer^));
    end;
  end;

  function _Initialize_TLS: TStringGrid;
  var
    o: DWord;
    TLS: PXbeTls;
  begin
    o := MyXBE.m_Header.dwTLSAddr - MyXBE.m_Header.dwBaseAddr;
    TLS := @(MyXBE.m_TLS);
    Result := NewGrid(3, ['Member', 'Type', 'Offset', 'Value', 'Meaning']);
    GridAddRow(Result, ['dwDataStartAddr', 'Dword', _offset(PXbeTls(nil).dwDataStartAddr, o), DWord2Str(TLS.dwDataStartAddr)]);
    GridAddRow(Result, ['dwDataEndAddr', 'Dword', _offset(PXbeTls(nil).dwDataEndAddr, o), DWord2Str(TLS.dwDataEndAddr)]);
    GridAddRow(Result, ['dwTLSIndexAddr', 'Dword', _offset(PXbeTls(nil).dwTLSIndexAddr, o), DWord2Str(TLS.dwTLSIndexAddr)]);
    GridAddRow(Result, ['dwTLSCallbackAddr', 'Dword', _offset(PXbeTls(nil).dwTLSCallbackAddr, o), DWord2Str(TLS.dwTLSCallbackAddr)]);
    GridAddRow(Result, ['dwSizeofZeroFill', 'Dword', _offset(PXbeTls(nil).dwSizeofZeroFill, o), DWord2Str(TLS.dwSizeofZeroFill)]);
    GridAddRow(Result, ['dwCharacteristics', 'Dword', _offset(PXbeTls(nil).dwCharacteristics, o), DWord2Str(TLS.dwCharacteristics)]);
  end;

  function _Initialize_HexViewer: THexViewer;
  begin
    Result := THexViewer.Create(Self);
    Result.SetRegion(MyXBE.RawData, MyXBE.FileSize, 0, 'whole file');
  end;

  function _Initialize_Strings: TStringsViewer;
  begin
    Result := TStringsViewer.Create(Self);
    Result.SetRegion(MyXBE.RawData, MyXBE.FileSize);
  end;

var
  Node0, Node1, NodeXBEHeader: TTreeNode;
  PreviousTreeNodeStr: string;
  i: Integer;
begin // OpenFile

  // Construct current tree path (excluding first node) :
  Node0 := TreeView1.Selected;
  PreviousTreeNodeStr := '';
  while Assigned(Node0) and Assigned(Node0.Parent) do
  begin
    PreviousTreeNodeStr := Node0.Text + #0 + PreviousTreeNodeStr;
    Node0 := Node0.Parent;
  end;

  CloseFile;
  MyXBE := TXbe.Create(aFilePath, ftXbe);
  FXBEFileName := ExtractFileName(aFilePath);
  Caption := Application.Title + ' - [' + FXBEFileName + ']';
  PageControl1.Visible := True;

  Node0 := _CreateNode(nil, 'File : ' + FXBEFileName, _CreateGrid_File);
  NodeXBEHeader := _CreateNode(Node0, 'XBE Header', _Initialize_XBEHeader);

  NodeResources := _CreateNode(Node0, 'Resources', nil);
  _CreateNode(NodeResources, 'Logo Bitmap', _Initialize_Logo);

  _CreateNode(NodeXBEHeader, 'Certificate', _Initialize_Certificate);
  _CreateNode(NodeXBEHeader, 'Section Headers', _Initialize_SectionHeaders); // Also adds image resource nodes
  _CreateNode(NodeXBEHeader, 'Library Versions', _Initialize_LibraryVersions);
  _CreateNode(NodeXBEHeader, 'TLS', _Initialize_TLS);

  _CreateNode(Node0, 'Hex Viewer', _Initialize_HexViewer);
  _CreateNode(Node0, 'Strings', _Initialize_Strings);

  TreeView1.FullExpand;

  // Search for previously active node :
  while PreviousTreeNodeStr <> '' do
  begin
    Node1 := nil;
    for i := 0 to Node0.Count - 1 do
    begin
      if Node0.Item[i].Text = Copy(PreviousTreeNodeStr, 1, Length(Node0.Item[i].Text)) then
      begin
        Node1 := Node0.Item[i];
        Delete(PreviousTreeNodeStr, 1, Length(Node0.Item[i].Text) + 1);
        Break;
      end;
    end;

    if Node1 = nil then
      Break;

    Node0 := Node1;
  end;

  TreeView1.Selected := Node0;

  Result := True;
end; // OpenFile

procedure TFormXBEExplorer.TreeView1Change(Sender: TObject; Node: TTreeNode);
begin
  PageControl1.ActivePage := TTabSheet(Node.Data);
end;

end.
