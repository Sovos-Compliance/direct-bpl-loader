{*******************************************************************************
*  Created by Vladimir Georgiev, 2014                                          *
*                                                                              *
*  Description:                                                                *
*  Constants and records for reading the PE image header                       *
*                                                                              *
*  Source:                                                                     *
*  http://www.csn.ul.ie/~caolan/publink/winresdump/winresdump/doc/pefile2.html *
*                                                                              *
*******************************************************************************}

unit mlPEHeaders;

interface
  uses
    Classes,
    Windows;

  const
    IMPORTED_NAME_OFFSET = $00000002;
    IMAGE_ORDINAL_FLAG32 = $80000000;
    IMAGE_ORDINAL_MASK32 = $7FFFFFFF;

  type
    PPointer = ^Pointer;

    PSection = ^TSection;
    TSection = packed record
      Base: Pointer;
      RVA,
      Size,
      Characteristics: LongWord;
    end;
    TSections = array of TSection;

  PImageImportDescriptor=^TImageImportDescriptor;
  TImageImportDescriptor=packed record  //(C++: IMAGE_IMPORT_DESCRIPTOR)
    OriginalFirstThunk:DWORD;
    TimeDateStamp:DWORD;
    ForwarderChain:DWORD;
    Name:DWORD;
    FirstThunk:DWORD;
  end;

  PImageSectionHeaders = ^TImageSectionHeaders;
  TImageSectionHeaders = array[0..(2147483647 div SIZEof(TImageSectionHeader)) - 1] of TImageSectionHeader;

  PImageDOSHeader = ^TImageDOSHeader;
  TImageDOSHeader = packed record
    Signature,
    PartPag,
    PageCnt,
    ReloCnt,
    HdrSize,
    MinMem,
    MaxMem,
    ReloSS,
    ExeSP,
    ChkSum,
    ExeIP,
    ReloCS,
    Tabloff,
    Overlay: WORD;
    Reserved: packed array[0..3] of WORD;
    OEMID,
    OEMInfo: WORD;
    Reserved2: packed array[0..9] of WORD;
    LFAoffset: LONGWORD;
  end;

  TDLLEntryProc = function(hinstDLL: HMODULE; dwReason: LONGWORD; lpvReserved: POINTER): boolean; STDCALL;

  TNameOrID = (niName, niID);

  TExternalLibrarySource = (lsHardDisk, lsMemStream); // lsHardDrive is loaded with the standard APIs, and lsMemStream with the Mem versions
  TExternalLibrary = record
    LibrarySource: TExternalLibrarySource;
    LibraryName  : String;
    LibraryHandle: HINST;
  end;

  TExternalLibrarys = array of TExternalLibrary;

  PDLLfunctionImport = ^TDLLfunctionImport;
  TDLLfunctionImport = record
    NameOrID: TNameOrID;
    Name: string;
    ID: integer;
  end;

  PDLLImport = ^TDLLImport;
  TDLLImport = record
    LibraryName: String;
    LibraryHandle: HINST;
    Entries: Array of TDLLfunctionImport;
  end;

  TImports = array of TDLLImport;

  PDLLfunctionExport = ^TDLLfunctionExport;
  TDLLfunctionExport = record
    Name: string;
    Index: integer;
    functionPointer: POINTER;
  end;

  TExports = array of TDLLfunctionExport;

  PLongWordArray = ^TLongWordArray;
  TLongWordArray = array[0..(2147483647 div SizeOf(LONGWORD)) - 1] of LONGWORD;

implementation

end.
