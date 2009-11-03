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
unit uEmuExe;

{$INCLUDE Dxbx.inc}

{$OVERFLOWCHECKS OFF}

interface

uses
  // Delphi
  Windows,
  JwaWinType,
  SysUtils,
  Math, // for IfThen
  // Dxbx
  uConsts,
  uTypes,
  uLog,
  uDxbxUtils,
  uProlog,
  uXbe,
  uExe;

type
  TDWordArray = array[0..3] of Byte;
  TWordArray = array[0..1] of Byte;

  TEmuExe = class(TExe)
  protected
    KrnlHandle: Handle;
  public
    constructor Create(x_Xbe: TXbe; aKernelDebugMode: TDebugMode; aKernelDebugFileName: string; hwndParent: Handle);
    destructor Destroy; override;
  end;

type
  // TODO : Remove Cxbx versions and add non-debug Dxbx version when our DLL starts working :
  TUseDll = (udCxbxKrnl, udCxbx, udDxbxKrnl {, udDxbx});

var
  DllToUse: TUseDLL = udCxbxKrnl;

function GetDllDescription(const aDllToUse: TUseDll): string;
function GetDllName(const aDllToUse: TUseDll): string;
function GetNoFuncImport(const aDllToUse: TUseDll): AnsiString;

implementation

function GetDllDescription(const aDllToUse: TUseDll): string;
begin
  case aDllToUse of
    udCxbxKrnl:
      Result := 'Cxbx debug';
    udCxbx:
      Result := 'Cxbx';
    udDxbxKrnl:
      Result := 'Dxbx debug';
{    udDxbx:
      Result := 'Dxbx';}
  else
    Assert(False);
    Result := '';
  end;
end;

function GetDllName(const aDllToUse: TUseDll): string;
begin
  case aDllToUse of
    udCxbxKrnl:
      Result := CCXBXKRNLDLLNAME;
    udCxbx:
      Result := CCXBXDLLNAME;
    udDxbxKrnl:
      Result := CDXBXKRNLDLLNAME;
{    udDxbx:
      Result := CDXBXDLLNAME;}
  else
    Assert(False);
    Result := '';
  end;
end;

function GetNoFuncImport(const aDllToUse: TUseDll): AnsiString;
begin
  Result := 'CxbxKrnlNoFunc'#0#0 + AnsiString(GetDllName(aDllToUse));
end;

{ TEmuExe }

//------------------------------------------------------------------------------

constructor TEmuExe.Create(x_Xbe: TXbe; aKernelDebugMode: TDebugMode;
  aKernelDebugFileName: string; hwndParent: Handle);

  procedure _WriteDWordToAddr(const aAddr: Pointer; aDWord: DWord);
  begin
    CopyMemory(aAddr, @aDWord, SizeOf(DWord));
  end;

  procedure _WriteDWordToSectionPos(SectionIdx, iPos: Integer; aDWord: DWord);
  begin
    _WriteDWordToAddr(@(m_bzSection[SectionIdx][iPos]), aDWord);
  end;

var
  i, d, v, c: Integer;
  k, t: DWord;

  dwSectionCursor: LongInt;
  RawAddr: LongInt;
  RawSize: LongInt;
  dwVirtAddr: LongInt;
  dwRawSize: LongInt;
  VirtSize: LongInt;
  VirtAddr: LongInt;
  Flags: DWord;
  SectionSize: uint32;
  Characteristics: DWord;

  raw_size: LongInt;
  virt_size: DWord;
  virt_addr: DWord;
  ep: DWord;
  kt: DWord;
  SizeOf_Code: DWord;
  SizeOf_Data: DWord;
  SizeOf_Undata: DWord;
  SizeOf_Image: DWord;
  Imag_Base: DWord;
  DLLBase: DWord;

  TLS_DATA: DWord;
  kt_tbl: PDWordArray;
  GetKernelThunkTable: TGetKernelThunkTable;
  KernelThunkTable: PKernelThunkTable;

  pWriteCursor: PByte; // DWord ?
  WriteCursor: DWord;
  Flag: Byte;

  pEmuInit: Pointer;
  NoFuncImport: AnsiString;
  TmpStr: string;

begin
  TmpStr := GetDllName(DllToUse);
  KrnlHandle := SafeLoadLibrary(TmpStr);
  if not IsValidLibraryHandle(KrnlHandle) then
  begin
    TmpStr := 'EmuExe: Cannot open DLL ' + TmpStr + '. Reason :'#13#10 + GetLastErrorString();
    WriteLog(TmpStr);
    RaiseLastOSError;
  end;

  ConstructorInit();

  WriteLog('EmuExe: Generating Exe file...');

  // generate pe header
  m_Header.m_magic := IMAGE_NT_SIGNATURE;
  m_Header.m_machine := IMAGE_FILE_MACHINE_I386; // machine type : i386
  m_Header.m_sections := x_Xbe.m_Header.dwSections + 2; // xbe sections + .cxbximp + .cxbxplg
  m_Header.m_timedate := x_Xbe.m_Header.dwTimeDate; // time/date stamp
  m_Header.m_symbol_table_addr := 0; // unused
  m_Header.m_symbols := 0; // unused
  m_Header.m_sizeof_optional_header := SizeOf(OptionalHeader); // size of optional header
  m_Header.m_characteristics := $010F; // should be fine..
  WriteLog('EmuExe: Generating PE header...OK');

  // generate optional header
  m_OptionalHeader.m_magic := $010B;

  // abitrary linker version : 6.0
  m_OptionalHeader.m_linker_version_major := $06;
  m_OptionalHeader.m_linker_version_minor := $00;

  // size of headers
  m_OptionalHeader.m_sizeof_headers := SizeOf(bzDOSStub) + SizeOf(m_Header);
  m_OptionalHeader.m_sizeof_headers := m_OptionalHeader.m_sizeof_headers + SizeOf(m_OptionalHeader) + SizeOf(SectionHeader) * m_Header.m_sections;
  m_OptionalHeader.m_sizeof_headers := RoundUp(m_OptionalHeader.m_sizeof_headers, PE_FILE_ALIGN);

  m_OptionalHeader.m_image_base := x_Xbe.m_Header.dwBaseAddr;
  m_OptionalHeader.m_section_alignment := PE_SEGM_ALIGN;
  m_OptionalHeader.m_file_alignment := PE_FILE_ALIGN;

  // OS version : 4.0
  m_OptionalHeader.m_os_version_major := $0004;
  m_OptionalHeader.m_os_version_minor := $0000;

  // image version : 0.0
  m_OptionalHeader.m_image_version_major := $0000;
  m_OptionalHeader.m_image_version_minor := $0000;

  // subsystem version : 4.0
  m_OptionalHeader.m_subsystem_version_major := $0004;
  m_OptionalHeader.m_subsystem_version_minor := $0000;

  m_OptionalHeader.m_win32_version := $0000;
  m_OptionalHeader.m_checksum := $0000;
  m_OptionalHeader.m_subsystem := IMAGE_SUBSYSTEM_WINDOWS_GUI;

  // no special dll Characteristics are necessary
  m_OptionalHeader.m_dll_characteristics := $0000;

  m_OptionalHeader.m_sizeof_stack_reserve := $00100000;
  m_OptionalHeader.m_sizeof_stack_commit := x_Xbe.m_Header.dwPeStackCommit;
  m_OptionalHeader.m_sizeof_heap_reserve := x_Xbe.m_Header.dwPeHeapReserve;
  m_OptionalHeader.m_sizeof_heap_commit := x_Xbe.m_Header.dwPeHeapCommit;

  // this member is obsolete, so we'll just set it to zero
  m_OptionalHeader.m_loader_flags := $00000000;

  // we'll set this to the typical 0x10 (16)
  m_OptionalHeader.m_data_directories := $10;

  // clear all data directories (we'll setup some later)
  for d := 1 to m_OptionalHeader.m_data_directories - 1 do
  begin
    m_OptionalHeader.m_image_data_directory[d].m_virtual_addr := 0;
    m_OptionalHeader.m_image_data_directory[d].m_size := 0;
  end;
  WriteLog('EmuExe: Generating Optional Header...OK');


  // generate section headers
  WriteLog('EmuExe: Generating Section Headers...');

  SetLength(m_SectionHeader, m_Header.m_sections);

  // start appending section headers at this point
  dwSectionCursor := RoundUp(m_OptionalHeader.m_sizeof_headers, $1000);

  // generate xbe section headers
  for v := 0 to x_Xbe.m_Header.dwSections - 1 do
  begin
    // generate xbe section name
    ZeroMemory(@(m_SectionHeader[v].m_name[0]), 8);
    for c := 0 to 7 do
    begin
      m_SectionHeader[v].m_name[c] := x_Xbe.m_szSectionName[v][c];
      if m_SectionHeader[v].m_name[c] = #0 then
        Break;
    end;

    // generate xbe section virtual size / addr
    VirtSize := x_Xbe.m_SectionHeader[v].dwVirtualSize;
    VirtAddr := x_Xbe.m_SectionHeader[v].dwVirtualAddr - x_Xbe.m_Header.dwBaseAddr;

    m_SectionHeader[v].m_virtual_size := VirtSize;
    m_SectionHeader[v].m_virtual_addr := VirtAddr;

    // generate xbe section raw size / addr
    // CXBX TODO: get this working such that m_sizeof_raw can be the actual raw size, not virtual size
    RawSize := RoundUp(x_Xbe.m_SectionHeader[v].dwVirtualSize, PE_FILE_ALIGN);
    RawAddr := dwSectionCursor;

    m_SectionHeader[v].m_sizeof_raw := RawSize;
    m_SectionHeader[v].m_raw_addr := RawAddr;

    dwSectionCursor := dwSectionCursor + RawSize;

    // relocation / line numbers will not exist
    m_SectionHeader[v].m_relocations_addr := 0;
    m_SectionHeader[v].m_linenumbers_addr := 0;

    m_SectionHeader[v].m_relocations := 0;
    m_SectionHeader[v].m_linenumbers := 0;

    // generate Flags for this xbe section
    Flags := IMAGE_SCN_MEM_READ;
    if (x_Xbe.m_SectionHeader[v].dwFlags[0] and XBE_SECTIONHEADER_FLAG_Executable) > 0 then
      Flags := Flags or IMAGE_SCN_MEM_EXECUTE or IMAGE_SCN_CNT_CODE
    else
      Flags := Flags or IMAGE_SCN_CNT_INITIALIZED_DATA;

    if (x_Xbe.m_SectionHeader[v].dwFlags[0] and XBE_SECTIONHEADER_FLAG_Writable) > 0 then
      Flags := Flags or IMAGE_SCN_MEM_WRITE;

    m_SectionHeader[v].m_characteristics := Flags;

    DbgPrintf('EmuExe: Generating Section Header 0x%.4x... OK', [v]);
  end;

  // generate .cxbximp section header
  i := m_Header.m_sections - 2;
  Move(AnsiString('.cxbximp'), m_SectionHeader[i].m_name, 8);

  // generate .cxbximp section virtual size / addr
  virt_size := RoundUp($6E, PE_SEGM_ALIGN);
  virt_addr := RoundUp(m_SectionHeader[i - 1].m_virtual_addr + m_SectionHeader[i - 1].m_virtual_size, PE_SEGM_ALIGN);

  m_SectionHeader[i].m_virtual_size := virt_size;
  m_SectionHeader[i].m_virtual_addr := virt_addr;

  // generate .cxbximp section raw size / addr
  raw_size := RoundUp(m_SectionHeader[i].m_virtual_size, PE_FILE_ALIGN);

  m_SectionHeader[i].m_sizeof_raw := raw_size;
  m_SectionHeader[i].m_raw_addr := dwSectionCursor;

  dwSectionCursor := dwSectionCursor + raw_size;

  // relocation / line numbers will not exist
  m_SectionHeader[i].m_relocations_addr := 0;
  m_SectionHeader[i].m_linenumbers_addr := 0;

  m_SectionHeader[i].m_relocations := 0;
  m_SectionHeader[i].m_linenumbers := 0;

  // make this section readable initialized data
  m_SectionHeader[i].m_characteristics := IMAGE_SCN_MEM_READ xor IMAGE_SCN_CNT_INITIALIZED_DATA;

  // update import table directory entry
  m_OptionalHeader.m_image_data_directory[IMAGE_DIRECTORY_ENTRY_IMPORT].m_virtual_addr := m_SectionHeader[i].m_virtual_addr + $08;
  m_OptionalHeader.m_image_data_directory[IMAGE_DIRECTORY_ENTRY_IMPORT].m_size := $28;

  //  update import address table directory entry
  m_OptionalHeader.m_image_data_directory[IMAGE_DIRECTORY_ENTRY_IAT].m_virtual_addr := m_SectionHeader[i].m_virtual_addr;
  m_OptionalHeader.m_image_data_directory[IMAGE_DIRECTORY_ENTRY_IAT].m_size := $08;
  DbgPrintf('EmuExe: Generating Section Header 0x%.4x(.cxbximp)... OK', [i]);

  //  generate .cxbxplg section header
  i := m_Header.m_sections - 1;

  m_SectionHeader[i].m_name := '.cxbxplg';

  // generate .cxbxplg section virtual size / addr
  begin
    if Assigned(x_Xbe.m_TLS) then
      virt_size := SizeOF(XBE_TLS) + (x_Xbe.m_TLS.dwDataEndAddr - x_Xbe.m_TLS.dwDataStartAddr)
    else
      virt_size := 0;

    virt_size := RoundUp(
      m_OptionalHeader.m_image_base + $100 +
      x_Xbe.m_Header.dwSizeofHeaders + 260 +
      DWord(Length(x_Xbe.m_LibraryVersion) * Integer(x_Xbe.m_Header.dwLibraryVersions)) +
      virt_size
      , $1000);
    virt_addr := RoundUp(
      m_SectionHeader[i - 1].m_virtual_addr +
      m_SectionHeader[i - 1].m_virtual_size, PE_SEGM_ALIGN);

    m_SectionHeader[i].m_virtual_size := virt_size;
    m_SectionHeader[i].m_virtual_addr := virt_addr;

    // our entry point should be the first bytes in this section
    m_OptionalHeader.m_entry := virt_addr;
  end;

  // generate .cxbxplg section raw size / addr
  begin
    raw_size := RoundUp(m_SectionHeader[i].m_virtual_size, PE_FILE_ALIGN);

    m_SectionHeader[i].m_sizeof_raw := raw_size;
    m_SectionHeader[i].m_raw_addr := dwSectionCursor;
{$IFDEF KEEP_UNNECCESARY_CODE}
    Inc(dwSectionCursor, raw_size);
{$ENDIF}
  end;

  // relocation / line numbers will not exist
  begin
    m_SectionHeader[i].m_relocations_addr := 0;
    m_SectionHeader[i].m_linenumbers_addr := 0;

    m_SectionHeader[i].m_relocations := 0;
    m_SectionHeader[i].m_linenumbers := 0;
  end;

  // make this section readable and executable
  m_SectionHeader[i].m_characteristics := IMAGE_SCN_MEM_READ xor IMAGE_SCN_MEM_EXECUTE xor IMAGE_SCN_CNT_CODE;

  DbgPrintf('EmuExe: Generating Section Header 0x%.4x(.cxbxplg)... OK', [i]);

  // generate sections
  WriteLog('EmuExe: Generating Sections...');

  SetLength(m_bzSection, m_Header.m_sections);


  // generate xbe sections
  for v := 0 to x_xbe.m_Header.dwSections - 1 do
  begin
    SectionSize := m_SectionHeader[v].m_sizeof_raw;
    // Allocate needed section size + 4 bytes (needed to assure zero-termination of this section) :
    SetLength(m_bzSection[v], SectionSize + 4);

    // Copy over all contents from the Xbe section :
    memcpy(m_bzSection[v], x_Xbe.m_bzSection[v], x_Xbe.m_SectionHeader[v].dwSizeofRaw);
    WriteLog(Format('EmuExe: Generating Section 0x%.4x... OK', [v]));
  end;

  // generate .cxbximp section
  begin
    i := m_Header.m_sections - 2;
    WriteLog(Format('EmuExe: Generating Section 0x%.4x (.cxbximp)... OK', [i]));

    dwVirtAddr := m_SectionHeader[i].m_virtual_addr;
    dwRawSize := m_SectionHeader[i].m_sizeof_raw;
    SetLength(m_bzSection[i], dwRawSize);
    ZeroMemory(m_bzSection[i], dwRawSize);

    _WriteDWordToSectionPos(i, $00, dwVirtAddr + $38);
    _WriteDWordToSectionPos(i, $04, 0);
    _WriteDWordToSectionPos(i, $08, dwVirtAddr + $30);
    _WriteDWordToSectionPos(i, $0C, 0);

    _WriteDWordToSectionPos(i, $10, 0);
    _WriteDWordToSectionPos(i, $14, dwVirtAddr + $4A);
    _WriteDWordToSectionPos(i, $18, dwVirtAddr + $00);
    _WriteDWordToSectionPos(i, $1C, 0);

    _WriteDWordToSectionPos(i, $20, 0);
    _WriteDWordToSectionPos(i, $24, 0);
    _WriteDWordToSectionPos(i, $28, 0);
    _WriteDWordToSectionPos(i, $2C, 0);

    _WriteDWordToSectionPos(i, $30, dwVirtAddr + $38);
    _WriteDWordToSectionPos(i, $34, 0);
    _WriteDWordToSectionPos(i, $38, $0001);

    NoFuncImport := GetNoFuncImport(DllToUse);
    CopyMemory(@(m_bzSection[i][$3A]), PAnsiChar(NoFuncImport), Length(NoFuncImport));
  end;

  // generate .cxbxplg section
  begin
    ep := x_Xbe.m_Header.dwEntryAddr;
    i := m_Header.m_sections - 1;

    DbgPrintf('EmuExe: Generating Section Header 0x%.4x (.cxbxplg)... OK', [i]);

    // decode entry point
    if ((ep xor XOR_EP_RETAIL) > $01000000) then
      ep := ep xor XOR_EP_DEBUG
    else
      ep := ep xor XOR_EP_RETAIL;

    SetLength(m_bzSection[i], m_SectionHeader[i].m_sizeof_raw);

    pWriteCursor := @(m_bzSection[i][0]);

    // Append prolog section
    CopyMemory(pWriteCursor, @(Prolog[0]), Length(Prolog));
    Inc(pWriteCursor, Length(Prolog));

    // Append xbe header
    CopyMemory(pWriteCursor, @(x_Xbe.m_Header), SizeOf(x_Xbe.m_Header));
    Inc(pWriteCursor, SizeOf(x_Xbe.m_Header));

    // Append xbe extra header bytes
    CopyMemory(pWriteCursor, x_Xbe.m_HeaderEx, x_Xbe.m_Header.dwSizeofHeaders - SizeOf(x_Xbe.m_Header));
    Dec(pWriteCursor, SizeOf(x_Xbe.m_Header));
    Inc(pWriteCursor, x_Xbe.m_Header.dwSizeofHeaders);

    // Append x_debug_FileName
    ZeroMemory(pWriteCursor, 260);
    if aKernelDebugFileName <> '' then
      CopyMemory(pWriteCursor, @(AnsiString(aKernelDebugFileName)[1]), Length(AnsiString(aKernelDebugFileName)));
    Inc(pWriteCursor, 260);

    // Append library versions
    for c := 1 to x_xbe.m_Header.dwLibraryVersions do
    begin
      CopyMemory(pWriteCursor, @(x_Xbe.m_LibraryVersion[c - 1]), Sizeof(x_Xbe.m_LibraryVersion[c - 1]));
      Inc(pWriteCursor, SizeOf(x_xbe.m_LibraryVersion[c - 1]));
    end;

    // Append TLS data
    if Assigned(x_Xbe.m_TLS) then
    begin
      CopyMemory(pWriteCursor, x_Xbe.m_TLS, SizeOf(x_Xbe.m_TLS^));
      Inc(pWriteCursor, SizeOf(x_Xbe.m_TLS^));

      CopyMemory(pWriteCursor, Pointer(x_Xbe.GetTLSData()), x_Xbe.m_TLS.dwDataEndAddr - x_Xbe.m_TLS.dwDataStartAddr);
{$IFDEF KEEP_UNNECCESARY_CODE}
      Inc(pWriteCursor, x_Xbe.m_TLS.dwDataEndAddr - x_Xbe.m_TLS.dwDataStartAddr);
{$ENDIF}
    end;

    // patch prolog function parameters
    WriteCursor := m_SectionHeader[i].m_virtual_addr + m_optionalHeader.m_image_base + $100;

    // TODO : Determine the actual ImageBase of the used DLL :
    DLLBase := {CurrentDLLBase=}DWord(KrnlHandle) - {LoadTimeDLLBase=DLL.ImageBase=}DLL_IMAGE_BASE;

    // Function Pointer
    pEmuInit := GetProcAddress(KrnlHandle, CCXBXKRNLINIT);
    _WriteDWordToSectionPos(i, 1, DWord(pEmuInit) -  DLLBase);

    // Param 8 : Entry
    _WriteDWordToSectionPos(i, 6, ep);

    // Param 7 : dwXbeHeaderSize
    _WriteDWordToSectionPos(i, 11, x_Xbe.m_Header.dwSizeofHeaders);

    // Param 6 : pXbeHeader
    _WriteDWordToSectionPos(i, 16, WriteCursor);
    Inc(WriteCursor, x_Xbe.m_Header.dwSizeofHeaders);

    // Param 5 : szDebugFileName
    _WriteDWordToSectionPos(i, 21, WriteCursor);
    Inc(WriteCursor, 260);

    // Param 4 : DbgMode
    _WriteDWordToSectionPos(i, 26, DWord(Ord(aKernelDebugMode)));

    // Param 3 : pLibraryVersion
    if Length(x_Xbe.m_LibraryVersion) <> 0 then
    begin
      _WriteDWordToSectionPos(i, 31, WriteCursor);
      Inc(WriteCursor, SizeOf(x_Xbe.m_LibraryVersion[0]) * x_xbe.m_Header.dwLibraryVersions);
    end
    else
      _WriteDWordToSectionPos(i, 31, 0);

    // Param 2 : pTLS
    if Assigned(x_Xbe.m_TLS) then
    begin
      _WriteDWordToSectionPos(i, 36, WriteCursor);
      Inc(WriteCursor, SizeOf(x_Xbe.m_TLS^));
    end
    else
      _WriteDWordToSectionPos(i, 36, 0);

    // Param 1 : pTLSData
    if Assigned(x_Xbe.m_TLS) then
    begin
      _WriteDWordToSectionPos(i, 41, WriteCursor);
{$IFDEF KEEP_UNNECCESARY_CODE}
      Inc(WriteCursor, x_Xbe.m_TLS.dwDataEndAddr - x_Xbe.m_TLS.dwDataStartAddr);
{$ENDIF}
    end
    else
      _WriteDWordToSectionPos(i, 41, 0);

    // Param 0 : hwndParent
    _WriteDWordToSectionPos(i, 46, hwndParent);
  end;

  // ******************************************************************
  // * patch kernel thunk table
  // ******************************************************************
  WriteLog('EmuExe: Hijacking Kernel Imports...');
  // generate xbe sections
  kt := x_Xbe.m_Header.dwKernelImageThunkAddr;

  // decode kernel thunk address
  if (kt xor XOR_KT_DEBUG) > $01000000 then
    kt := kt xor XOR_KT_RETAIL
  else
    kt := kt xor XOR_KT_DEBUG;

  // locate section containing kernel thunk table
  if DLLToUse in [udCxbxKrnl, udCxbx] then
    KernelThunkTable := GetProcAddress(KrnlHandle, CXBXKRNL_KERNELTHUNKTABLE)
  else
  begin
    // Delphi doesn't support DLL's declaring an exported record,
    // so our thunk is actually a method returning the thunk table :
    GetKernelThunkTable := GetProcAddress(KrnlHandle, CXBXKRNL_KERNELTHUNKTABLE);
    Assert(Assigned(GetKernelThunkTable));
    // Call the method to get to the thunk table :
    KernelThunkTable := GetKernelThunkTable();
  end;

  Assert(Assigned(KernelThunkTable));

  imag_base := m_OptionalHeader.m_image_base;
  for v := 0 to x_Xbe.m_Header.dwSections - 1 do
  begin
    virt_addr := m_SectionHeader[v].m_virtual_addr;
    virt_size := m_SectionHeader[v].m_virtual_size;

    // modify kernel thunk table, if found
    if ((kt >= imag_base + virt_addr) and (kt < imag_base + virt_addr + virt_size)) then
    begin
      WriteLog(Format('EmuExe: Located Thunk Table in Section 0x%.4x (0x%.8X)...', [v, kt]));
      kt_tbl := @(m_bzSection[v][kt - virt_addr - imag_base]);
      k := 0;
      while kt_tbl[k] <> 0 do
      begin
        t := kt_tbl[k] and $7FFFFFFF;
        if  (t < NUMBER_OF_THUNKS)
        and (DWord(KernelThunkTable[t]) > NUMBER_OF_THUNKS) then
        begin
          _WriteDWordToAddr(@(kt_tbl[k]), DWord(KernelThunkTable[t]) - DLLBase);
          WriteLog(Format('EmuExe: Thunk %.3d : *0x%.8X := 0x%.8X', [t, kt + (k * 4), kt_tbl[k]]));
        end
        else
        begin
          _WriteDWordToAddr(@(kt_tbl[k]), t);
          WriteLog(Format('EmuExe: Out-of-range thunk %.3d : *0x%.8X := 0x%.8X', [t, kt + (k * 4), kt_tbl[k]]));
        end;
        
        Inc(k);
      end; // while
    end; // if

  end; // for

  // update imcomplete header fields
  WriteLog('EmuExe: Finalizing Exe file...');

  // calculate size of code / data / image
  begin
    SizeOf_Code := 0;
    SizeOf_Data := 0;
    SizeOf_Undata := 0;

    for v := 0 to m_Header.m_sections - 1 do
    begin
      Characteristics := m_SectionHeader[v].m_characteristics;
      if ((Characteristics and IMAGE_SCN_MEM_EXECUTE) <> 0) or ((Characteristics and IMAGE_SCN_CNT_CODE) <> 0) then
        Inc(SizeOf_Code, m_SectionHeader[v].m_SizeOf_Raw);

      if (Characteristics and IMAGE_SCN_CNT_INITIALIZED_DATA) <> 0 then
        Inc(Sizeof_Data, m_SectionHeader[v].m_sizeof_raw);
    end;

    // calculate size of image
    // The RoundUp is necessary to allow the generated exe to run under Vista
    // This is actually a bug that needs to be corrected in CXBX too
    SizeOf_Image := SizeOf_Undata + SizeOf_Data + SizeOf_Code + RoundUp(m_OptionalHeader.m_sizeof_headers, $1000);
    SizeOf_Image := RoundUp(SizeOf_Image, PE_SEGM_ALIGN);

    // update optional header as necessary
    m_OptionalHeader.m_sizeof_code := sizeof_code;
    m_OptionalHeader.m_sizeof_initialized_data := sizeof_data;
    m_OptionalHeader.m_sizeof_uninitialized_data := sizeof_undata;
    m_OptionalHeader.m_sizeof_image := sizeof_image;
  end;

  // we'll set code base as the virtual address of the first section
  m_OptionalHeader.m_code_base := m_SectionHeader[0].m_virtual_addr;

  // we'll set data base as the virtual address of the first section
  // that is not marked as containing code or being executable

  for v := 0 to m_Header.m_sections - 1 do
  begin
    Characteristics := m_SectionHeader[v].m_characteristics;
    if (   ((Characteristics and IMAGE_SCN_MEM_EXECUTE) = 0)
        or ((Characteristics and IMAGE_SCN_CNT_CODE) = 0)) then
    begin
      m_optionalHeader.m_data_base := m_SectionHeader[v].m_virtual_addr;
      Break;
    end;
  end;

  WriteLog('EmuExe: Finalizing Exe Files...OK');
end; // TEmuExe.Create

//------------------------------------------------------------------------------

destructor TEmuExe.Destroy;
begin
  FreeLibrary(KrnlHandle);

  inherited Destroy;
end;

end.
