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
unit uEmuKrnlIo;

{$INCLUDE ..\Dxbx.inc}

interface

uses
  // Delphi
  SysUtils,
  // Jedi
  JwaWinType,
  JwaWinBase,
  JwaWinNT,
  JwaNative,
  JwaNTStatus,
  // OpenXDK
  XboxKrnl,
  // Dxbx
  uLog,
  uEmuFS,
  uEmuFile,
  uEmuXapi,
  uEmuKrnl,
  uDxbxKrnl;

const
  // TODO : Translate all other IRP defines from ReactOS
  IRP_MJ_MAXIMUM_FUNCTION = $1B;

type
  _IRP = record
    cType: CSHORT;
    Size: USHORT;
(*
    MdlAddress: P_MDL;
    Flags: ULONG;
    union begin
      MasterIrp: P_IRP;
      IrpCount: LongInt; // volatile
      SystemBuffer: PVOID;
    end;
    ThreadListEntry: LIST_ENTRY;
    IoStatus: IO_STATUS_BLOCK;
    RequestorMode: KPROCESSOR_MODE;
    PendingReturned: BOOLEAN;
    StackCount: CHAR;
    CurrentLocation: CHAR;
    Cancel: BOOLEAN;
    CancelIrql: KIRQL;
    ApcEnvironment: CCHAR;
    AllocationFlags: UCHAR;
    UserIosb: PIO_STATUS_BLOCK;
    UserEvent: PKEVENT;

    // TODO : Translate all below
    union begin
      struct begin
        PIO_APC_ROUTINE  UserApcRoutine;
        PVOID  UserApcContext;
       end; AsynchronousParameters;
      LARGE_INTEGER  AllocationSize;
     end; Overlay;
    volatile PDRIVER_CANCEL  CancelRoutine;
    PVOID  UserBuffer;
    union begin
      struct begin
        _ANONYMOUS_UNION union begin
          KDEVICE_QUEUE_ENTRY  DeviceQueueEntry;
          _ANONYMOUS_STRUCT struct begin
              DriverContext: array[0..4-1] of PVOID;
           end; DUMMYSTRUCTNAME;
         end; DUMMYUNIONNAME;
        PETHREAD  Thread;
        PCHAR  AuxiliaryBuffer;
        _ANONYMOUS_STRUCT struct begin
          LIST_ENTRY  ListEntry;
          _ANONYMOUS_UNION union begin
            struct _IO_STACK_LOCATION  *CurrentStackLocation;
            ULONG  PacketType;
           end; DUMMYUNIONNAME;
         end; DUMMYSTRUCTNAME;
        struct _FILE_OBJECT  *OriginalFileObject;
       end; Overlay;
      KAPC  Apc;
      PVOID  CompletionKey;
     end; Tail;
*)
  end;
  IRP = _IRP;
  PIRP = ^IRP;

  PDRIVER_EXTENSION = UNKNOWN; // TODO : Lookup in ReactOS
  PFAST_IO_DISPATCH = UNKNOWN; // TODO : Lookup in ReactOS
  PDRIVER_INITIALIZE = UNKNOWN; // TODO : Lookup in ReactOS
  PDRIVER_STARTIO = UNKNOWN; // TODO : Lookup in ReactOS
  PDRIVER_UNLOAD = UNKNOWN; // TODO : Lookup in ReactOS
  PDRIVER_DISPATCH = UNKNOWN; // TODO : Lookup in ReactOS
  PIO_TIMER_ROUTINE = UNKNOWN; // TODO : Lookup in ReactOS
  PVPB = UNKNOWN; // TODO : Lookup in ReactOS
  DEVICE_TYPE = UNKNOWN; // TODO : Lookup in ReactOS
  KDEVICE_QUEUE = UNKNOWN; // TODO : Lookup in ReactOS
  KEVENT = UNKNOWN; // TODO : Lookup in ReactOS
  PKEVENT = ^KEVENT;
  PDEVOBJ_EXTENSION = UNKNOWN; // TODO : Lookup in ReactOS

  PDEVICE_OBJECT = ^DEVICE_OBJECT; // forward;

//
// I/O Timer Object
//
  _IO_TIMER = record // Source: ReactOS
    _Type: USHORT;
    TimerEnabled: USHORT;
    IoTimerList: LIST_ENTRY;
    TimerRoutine: PIO_TIMER_ROUTINE;
    Context: PVOID;
    DeviceObject: PDEVICE_OBJECT;
  end;
  IO_TIMER = _IO_TIMER;
  PIO_TIMER = ^IO_TIMER;

  _DRIVER_OBJECT = record // Source: ReactOS
    _Type: CSHORT;
    Size: CSHORT;
    DeviceObject: PDEVICE_OBJECT;
    Flags: ULONG;
    DriverStart: PVOID;
    DriverSize: ULONG;
    DriverSection: PVOID;
    DriverExtension: PDRIVER_EXTENSION;
    DriverName: UNICODE_STRING;
    HardwareDatabase: PUNICODE_STRING;
    FastIoDispatch: PFAST_IO_DISPATCH;
    DriverInit: PDRIVER_INITIALIZE;
    DriverStartIo: PDRIVER_STARTIO;
    DriverUnload: PDRIVER_UNLOAD;
    MajorFunction: array[0..IRP_MJ_MAXIMUM_FUNCTION] of PDRIVER_DISPATCH;
  end;
  DRIVER_OBJECT = _DRIVER_OBJECT;
  PDRIVER_OBJECT = ^DRIVER_OBJECT;

  _DEVICE_OBJECT = record // Source: XBMC
    _Type: CSHORT;
    Size: USHORT;
    ReferenceCount: LONG;
    DriverObject: PDRIVER_OBJECT;
    // Source: ReactOS
    NextDevice: PDEVICE_OBJECT;
    AttachedDevice: PDEVICE_OBJECT;
    CurrentIrp: PIRP;
    Timer: PIO_TIMER;
    Flags: ULONG;
    Characteristics: ULONG;
    Vpb: PVPB; // volatile
    DeviceExtension: PVOID;
    DeviceType: DEVICE_TYPE;
    StackSize: CCHAR;
//    union {
    ListEntry: LIST_ENTRY;
//      Wcb: WAIT_CONTEXT_BLOCK;
//    } Queue; // TODO
    AlignmentRequirement: ULONG;
    DeviceQueue: KDEVICE_QUEUE;
    Dpc: KDPC;
    ActiveThreadCount: ULONG;
    SecurityDescriptor: PSECURITY_DESCRIPTOR;
    DeviceLock: KEVENT;
    SectorSize: USHORT;
    Spare1: USHORT;
    DeviceObjectExtension: PDEVOBJ_EXTENSION;
    Reserved: PVOID;
  end; // Source: XBMC / ReactOS
  DEVICE_OBJECT = _DEVICE_OBJECT;

  _FILE_OBJECT = record // Source: XBMC
    _Type: CSHORT;
    Size: CSHORT;
    DeviceObject: PDEVICE_OBJECT;
   // ...
  end;
  FILE_OBJECT = _FILE_OBJECT;
  PFILE_OBJECT = ^FILE_OBJECT;

  _SHARE_ACCESS = record // Source: ReactOS
    OpenCount: ULONG;
    Readers: ULONG;
    Writers: ULONG;
    Deleters: ULONG;
    SharedRead: ULONG;
    SharedWrite: ULONG;
    SharedDelete: ULONG;
  end;
  SHARE_ACCESS = _SHARE_ACCESS;
  PSHARE_ACCESS = ^SHARE_ACCESS;

var
  {064}xboxkrnl_IoCompletionObjectType: POBJECT_TYPE = NULL; // Source: Dxbx
  {070}xboxkrnl_IoDeviceObjectType: POBJECT_TYPE = NULL;
  {071}xboxkrnl_IoFileObjectType: POBJECT_TYPE = NULL;

function {059} xboxkrnl_IoAllocateIrp(
  StackSize: CCHAR;
  ChargeQuota: LONGBOOL // TODO : Should this be a WordBool??
  ): PIRP; stdcall; // Source: ReactOS
function {060} xboxkrnl_IoBuildAsynchronousFsdRequest(
  MajorFunction: ULONG;
  DeviceObject: PDEVICE_OBJECT;
  Buffer: PVOID; // OUT OPTIONAL
  Length: ULONG; // OPTIONAL,
  StartingOffset: PLARGE_INTEGER; // OPTIONAL
  IoStatusBlock: PIO_STATUS_BLOCK // OPTIONAL
  ): PIRP; stdcall; // Source: ReactOS
function {061} xboxkrnl_IoBuildDeviceIoControlRequest(
  IoControlCode: ULONG;
  DeviceObject: PDEVICE_OBJECT;
  InputBuffer: PVOID; // OPTIONAL,
  InputBufferLength: ULONG;
  OutputBuffer: PVOID; // OUT OPTIONAL
  OutputBufferLength: ULONG;
  InternalDeviceIoControl: BOOLEAN;
  Event: PKEVENT;
  IoStatusBlock: PIO_STATUS_BLOCK // OUT
  ): PIRP; stdcall; // Source: ReactOS
function {062} xboxkrnl_IoBuildSynchronousFsdRequest(
  MajorFunction: ULONG;
  DeviceObject: PDEVICE_OBJECT;
  Buffer: PVOID; // OUT OPTIONAL,
  Length: ULONG; // OPTIONAL,
  StartingOffset: PLARGE_INTEGER; // OPTIONAL,
  Event: PKEVENT;
  IoStatusBlock: PIO_STATUS_BLOCK // OUT
  ): PIRP; stdcall; // Source: ReactOS
function {063} xboxkrnl_IoCheckShareAccess(
  DesiredAccess: ACCESS_MASK;
  DesiredShareAccess: ULONG;
  FileObject: PFILE_OBJECT; // OUT
  ShareAccess: PSHARE_ACCESS; // OUT
  Update: BOOLEAN
  ): NTSTATUS; stdcall; // Source: ReactOS
function {065} xboxkrnl_IoCreateDevice(
  DriverObject: PDRIVER_OBJECT;
  DeviceExtensionSize: ULONG;
  DeviceName: PUNICODE_STRING;
  DeviceType: DEVICE_TYPE;
  DeviceCharacteristics: ULONG;
  Exclusive: BOOLEAN;
  var DeviceObject: PDEVICE_OBJECT // out
  ): NTSTATUS; stdcall; // Source: ReactOS
function {066} xboxkrnl_IoCreateFile(
  FileHandle: PHANDLE; // out
  DesiredAccess: ACCESS_MASK;
  ObjectAttributes: POBJECT_ATTRIBUTES;
  IoStatusBlock: PIO_STATUS_BLOCK; // out
  AllocationSize: PLARGE_INTEGER;
  FileAttributes: ULONG;
  ShareAccess: ULONG;
  Disposition: ULONG;
  CreateOptions: ULONG;
  Options: ULONG
  ): NTSTATUS; stdcall; // Source: Cxbx
function xboxkrnl_IoCreateSymbolicLink(
  SymbolicLinkName: PSTRING;
  DeviceName: PSTRING
  ): NTSTATUS; stdcall;
function xboxkrnl_IoDeleteDevice(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoDeleteSymbolicLink(
  SymbolicLinkName: PSTRING
  ): NTSTATUS; stdcall;
function xboxkrnl_IoFreeIrp(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoInitializeIrp(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoInvalidDeviceRequest(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoQueryFileInformation(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoQueryVolumeInformation(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoQueueThreadIrp(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoRemoveShareAccess(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoSetIoCompletion(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoSetShareAccess(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoStartNextPacket(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoStartNextPacketByKey(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoStartPacket(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoSynchronousDeviceIoControlRequest(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoSynchronousFsdRequest(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IofCallDriver(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IofCompleteRequest(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoDismountVolume(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoDismountVolumeByName(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE
function xboxkrnl_IoMarkIrpMustComplete(): NTSTATUS; stdcall; // UNKNOWN_SIGNATURE

implementation

function {059} xboxkrnl_IoAllocateIrp(
  StackSize: CCHAR;
  ChargeQuota: LONGBOOL // TODO : Should this be a WordBool??
  ): PIRP; stdcall; // Source: ReactOS
begin
  EmuSwapFS(); // Win2k/XP FS
  Unimplemented('IoAllocateIrp');
  Result := nil;
  EmuSwapFS(); // Xbox FS
end;

function {060} xboxkrnl_IoBuildAsynchronousFsdRequest(
  MajorFunction: ULONG;
  DeviceObject: PDEVICE_OBJECT;
  Buffer: PVOID; // OUT OPTIONAL
  Length: ULONG; // OPTIONAL,
  StartingOffset: PLARGE_INTEGER; // OPTIONAL
  IoStatusBlock: PIO_STATUS_BLOCK // OPTIONAL
  ): PIRP; stdcall; // Source: ReactOS
begin
  EmuSwapFS(); // Win2k/XP FS
  Unimplemented('IoBuildAsynchronousFsdRequest');
  Result := nil;
  EmuSwapFS(); // Xbox FS
end;

function {061} xboxkrnl_IoBuildDeviceIoControlRequest(
  IoControlCode: ULONG;
  DeviceObject: PDEVICE_OBJECT;
  InputBuffer: PVOID; // OPTIONAL,
  InputBufferLength: ULONG;
  OutputBuffer: PVOID; // OUT OPTIONAL
  OutputBufferLength: ULONG;
  InternalDeviceIoControl: BOOLEAN;
  Event: PKEVENT;
  IoStatusBlock: PIO_STATUS_BLOCK // OUT
  ): PIRP; stdcall; // Source: ReactOS
begin
  EmuSwapFS(); // Win2k/XP FS
  Unimplemented('IoBuildDeviceIoControlRequest');
  Result := nil;
  EmuSwapFS(); // Xbox FS
end;

function {062} xboxkrnl_IoBuildSynchronousFsdRequest(
  MajorFunction: ULONG;
  DeviceObject: PDEVICE_OBJECT;
  Buffer: PVOID; // OUT OPTIONAL,
  Length: ULONG; // OPTIONAL,
  StartingOffset: PLARGE_INTEGER; // OPTIONAL,
  Event: PKEVENT;
  IoStatusBlock: PIO_STATUS_BLOCK // OUT
  ): PIRP; stdcall; // Source: ReactOS
begin
  EmuSwapFS(); // Win2k/XP FS
  Unimplemented('IoBuildSynchronousFsdRequest');
  Result := nil;
  EmuSwapFS(); // Xbox FS
end;

function {063} xboxkrnl_IoCheckShareAccess(
  DesiredAccess: ACCESS_MASK;
  DesiredShareAccess: ULONG;
  FileObject: PFILE_OBJECT; // OUT
  ShareAccess: PSHARE_ACCESS; // OUT
  Update: BOOLEAN
  ): NTSTATUS; stdcall; // Source: ReactOS
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoCheckShareAccess');
  EmuSwapFS(); // Xbox FS
end;

// IoCreateDevice
//
// Allocates memory for and intializes a device object for use for
// a driver.
//
// Parameters
//    DriverObject
//       Driver object passed by IO Manager when the driver was loaded.
//
//    DeviceExtensionSize
//       Number of bytes for the device extension.
//
//    DeviceName
//       Unicode name of device.
//
//    DeviceType
//       Device type of the new device.
//
//    DeviceCharacteristics
//       Bit mask of device characteristics.
//
//    Exclusive
//       TRUE if only one thread can access the device at a time.
//
//    DeviceObject
//       On successful return this parameter is filled by pointer to
//       allocated device object.

function {065} xboxkrnl_IoCreateDevice(
  DriverObject: PDRIVER_OBJECT;
  DeviceExtensionSize: ULONG;
  DeviceName: PUNICODE_STRING;
  DeviceType: DEVICE_TYPE;
  DeviceCharacteristics: ULONG;
  Exclusive: BOOLEAN;
  var DeviceObject: PDEVICE_OBJECT // out
  ): NTSTATUS; stdcall; // Source: ReactOS
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoCreateDevice');
  EmuSwapFS(); // Xbox FS
end;

function {066} xboxkrnl_IoCreateFile(
  FileHandle: PHANDLE; // out
  DesiredAccess: ACCESS_MASK;
  ObjectAttributes: POBJECT_ATTRIBUTES;
  IoStatusBlock: PIO_STATUS_BLOCK; // out
  AllocationSize: PLARGE_INTEGER;
  FileAttributes: ULONG;
  ShareAccess: ULONG;
  Disposition: ULONG;
  CreateOptions: ULONG;
  Options: ULONG
  ): NTSTATUS; stdcall; // Source: Cxbx
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoCreateFile');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoCreateSymbolicLink(
  SymbolicLinkName: PSTRING;
  DeviceName: PSTRING
  ): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoCreateSymbolicLink');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoDeleteDevice(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoDeleteDevice');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoDeleteSymbolicLink(
  SymbolicLinkName: PSTRING
  ): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoDeleteSymbolicLink');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoFreeIrp(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoFreeIrp');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoInitializeIrp(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoInitializeIrp');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoInvalidDeviceRequest(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoInvalidDeviceRequest');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoQueryFileInformation(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoQueryFileInformation');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoQueryVolumeInformation(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoQueryVolumeInformation');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoQueueThreadIrp(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoQueueThreadIrp');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoRemoveShareAccess(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoRemoveShareAccess');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoSetIoCompletion(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoSetIoCompletion');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoSetShareAccess(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoSetShareAccess');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoStartNextPacket(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoStartNextPacket');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoStartNextPacketByKey(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoStartNextPacketByKey');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoStartPacket(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoStartPacket');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoSynchronousDeviceIoControlRequest(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoSynchronousDeviceIoControlRequest');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoSynchronousFsdRequest(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoSynchronousFsdRequest');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IofCallDriver(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IofCallDriver');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IofCompleteRequest(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IofCompleteRequest');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoDismountVolume(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoDismountVolume');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoDismountVolumeByName(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoDismountVolumeByName');
  EmuSwapFS(); // Xbox FS
end;

function xboxkrnl_IoMarkIrpMustComplete(): NTSTATUS; stdcall;
begin
  EmuSwapFS(); // Win2k/XP FS
  Result := Unimplemented('IoMarkIrpMustComplete');
  EmuSwapFS(); // Xbox FS
end;

end.