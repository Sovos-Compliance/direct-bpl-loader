unit PEHeaders;

interface
  uses
    Classes,
    Types,
    Windows;

  const
    IMPORTED_NAME_OFFSET = $00000002;
    IMAGE_ORDINAL_FLAG32 = $80000000;
    IMAGE_ORDINAL_MASK32 = $7FFFFFFF;

    IMAGE_ORDINAL_FLAG64 = $8000000000000000;
    IMAGE_ORDINAL_MASK64 = $7FFFFFFFFFFFFFFF;


    RTL_CRITSECT_TYPE = 0;
    RTL_RESOURCE_TYPE = 1;
    DLL_PROCESS_ATTACH = 1;
    DLL_THREAD_ATTACH = 2;
    DLL_THREAD_DETACH = 3;
    DLL_PROCESS_DETACH = 0;
    IMAGE_SizeHeader = 20;
    IMAGE_FILE_RELOCS_STRIPPED = $0001;
    IMAGE_FILE_EXECUTABLE_IMAGE = $0002;
    IMAGE_FILE_LINE_NUMS_STRIPPED = $0004;
    IMAGE_FILE_LOCAL_SYMS_STRIPPED = $0008;
    IMAGE_FILE_AGGRESIVE_WS_TRIM = $0010;
    IMAGE_FILE_BYTES_REVERSED_LO = $0080;
    IMAGE_FILE_32BIT_MACHINE = $0100;
    IMAGE_FILE_DEBUG_STRIPPED = $0200;
    IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP = $0400;
    IMAGE_FILE_NET_RUN_FROM_SWAP = $0800;
    IMAGE_FILE_SYSTEM = $1000;
    IMAGE_FILE_DLL = $2000;
    IMAGE_FILE_UP_SYSTEM_ONLY = $4000;
    IMAGE_FILE_BYTES_REVERSED_HI = $8000;
    IMAGE_FILE_MACHINE_UNKNOWN = 0;
    IMAGE_FILE_MACHINE_I386 = $14C;
    IMAGE_FILE_MACHINE_R3000 = $162;
    IMAGE_FILE_MACHINE_R4000 = $166;
    IMAGE_FILE_MACHINE_R10000 = $168;
    IMAGE_FILE_MACHINE_ALPHA = $184;
    IMAGE_FILE_MACHINE_POWERPC = $1F0;
    IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16;
    IMAGE_SUBSYSTEM_UNKNOWN = 0;
    IMAGE_SUBSYSTEM_NATIVE = 1;
    IMAGE_SUBSYSTEM_WINDOWS_GUI = 2;
    IMAGE_SUBSYSTEM_WINDOWS_CUI = 3;
    IMAGE_SUBSYSTEM_OS2_CUI = 5;
    IMAGE_SUBSYSTEM_POSIX_CUI = 7;
    IMAGE_SUBSYSTEM_RESERVED = 8;
    IMAGE_DIRECTORY_ENTRY_EXPORT = 0;
    IMAGE_DIRECTORY_ENTRY_IMPORT = 1;
    IMAGE_DIRECTORY_ENTRY_RESOURCE = 2;
    IMAGE_DIRECTORY_ENTRY_EXCEPTION = 3;
    IMAGE_DIRECTORY_ENTRY_SECURITY = 4;
    IMAGE_DIRECTORY_ENTRY_BASERELOC = 5;
    IMAGE_DIRECTORY_ENTRY_DEBUG = 6;
    IMAGE_DIRECTORY_ENTRY_COPYRIGHT = 7;
    IMAGE_DIRECTORY_ENTRY_GLOBALPTR = 8;
    IMAGE_DIRECTORY_ENTRY_TLS = 9;
    IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG = 10;
    IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT = 11;
    IMAGE_DIRECTORY_ENTRY_IAT = 12;
    IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT = 13;
    IMAGE_SIZEOF_SHORT_NAME = 8;
    IMAGE_SCN_TYIMAGE_REG = $00000000;
    IMAGE_SCN_TYIMAGE_DSECT = $00000001;
    IMAGE_SCN_TYIMAGE_NOLOAD = $00000002;
    IMAGE_SCN_TYIMAGE_GROUP = $00000004;
    IMAGE_SCN_TYIMAGE_NO_PAD = $00000008;
    IMAGE_SCN_TYIMAGE_COPY = $00000010;
    IMAGE_SCN_CNT_CODE = $00000020;
    IMAGE_SCN_CNT_INITIALIZED_DATA = $00000040;
    IMAGE_SCN_CNT_UNINITIALIZED_DATA = $00000080;
    IMAGE_SCN_LNK_OTHER = $00000100;
    IMAGE_SCN_LNK_INFO = $00000200;
    IMAGE_SCN_TYIMAGE_OVER = $0000400;
    IMAGE_SCN_LNK_REMOVE = $00000800;
    IMAGE_SCN_LNK_COMDAT = $00001000;
    IMAGE_SCN_MEM_PROTECTED = $00004000;
    IMAGE_SCN_MEM_FARDATA = $00008000;
    IMAGE_SCN_MEM_SYSHEAP = $00010000;
    IMAGE_SCN_MEM_PURGEABLE = $00020000;
    IMAGE_SCN_MEM_16BIT = $00020000;
    IMAGE_SCN_MEM_LOCKED = $00040000;
    IMAGE_SCN_MEM_PRELOAD = $00080000;
    IMAGE_SCN_ALIGN_1BYTES = $00100000;
    IMAGE_SCN_ALIGN_2BYTES = $00200000;
    IMAGE_SCN_ALIGN_4BYTES = $00300000;
    IMAGE_SCN_ALIGN_8BYTES = $00400000;
    IMAGE_SCN_ALIGN_16BYTES = $00500000;
    IMAGE_SCN_ALIGN_32BYTES = $00600000;
    IMAGE_SCN_ALIGN_64BYTES = $00700000;
    IMAGE_SCN_LNK_NRELOC_OVFL = $01000000;
    IMAGE_SCN_MEM_DISCARDABLE = $02000000;
    IMAGE_SCN_MEM_NOT_CACHED = $04000000;
    IMAGE_SCN_MEM_NOT_PAGED = $08000000;
    IMAGE_SCN_MEM_SHARED = $10000000;
    IMAGE_SCN_MEM_EXECUTE = $20000000;
    IMAGE_SCN_MEM_READ = $40000000;
    IMAGE_SCN_MEM_WRITE = LONGWORD($80000000);
    IMAGE_REL_BASED_ABSOLUTE = 0;
    IMAGE_REL_BASED_HIGH = 1;
    IMAGE_REL_BASED_LOW = 2;
    IMAGE_REL_BASED_HIGHLOW = 3;
    IMAGE_REL_BASED_HIGHADJ = 4;
    IMAGE_REL_BASED_MIPS_JMPADDR = 5;
    IMAGE_REL_BASED_SECTION = 6;
    IMAGE_REL_BASED_REL32 = 7;
    IMAGE_REL_BASED_MIPS_JMPADDR16 = 9;
    IMAGE_REL_BASED_IA64_IMM64 = 9;
    IMAGE_REL_BASED_DIR64 = 10;
    IMAGE_REL_BASED_HIGH3ADJ = 11;
    PAGE_NOACCESS = 1;
    PAGE_READONLY = 2;
    PAGE_READWRITE = 4;
    PAGE_WRITECOPY = 8;
    PAGE_EXECUTE = $10;
    PAGE_EXECUTE_READ = $20;
    PAGE_EXECUTE_READWRITE = $40;
    PAGE_EXECUTE_WRITECOPY = $80;
    PAGE_GUARD = $100;
    PAGE_NOCACHE = $200;
    MEM_COMMIT = $1000;
    MEM_RESERVE = $2000;
    MEM_DECOMMIT = $4000;
    MEM_RELEASE = $8000;
    MEM_FREE = $10000;
    MEM_PRIVATE = $20000;
    MEM_MAPPED = $40000;
    MEM_RESET = $80000;
    MEM_TOP_DOWN = $100000;
    SEC_FILE = $800000;
    SEC_IMAGE = $1000000;
    SEC_RESERVE = $4000000;
    SEC_COMMIT = $8000000;
    SEC_NOCACHE = $10000000;
    MEM_IMAGE = SEC_IMAGE;


  type

    PSection = ^TSection;
    TSection = packed record
        Base: POINTER;
        RVA,
        Size,
        Characteristics: LONGWORD;
    end;
    TSections = array of TSection;

    // record for collect of importing function of dll
    TImportItem  = record
      Name : string;
      PProcVar : ^Pointer;
    end;

    // record of DLL for correct unload it
    TLibInfo = record
      ImageBase : Pointer; // Base adress dll image
      DLLProc : TDLLProc; // pointer on DllMain function
      LibsUsed : TStringList; // List of loaded dll
    end;

    _IMAGE_FILE_HEADER = packed record
      Machine : Word;                 // CPU destination
      NumberOfSections : Word;        // Count PE Section
      DateTimeStamp : DWORD;          // Date and Time creating file
      PointerToSymbolTable : DWORD;   // for DLL - pointer on the table wih debuging info
      NumberOfSymbols : DWORD;
      SizeOfOptionalHeader : Word;    // Size of Optional Header of PE header
      Characteristics : Word;         // Set of informations flags
    end;
    TImageFileHeader = _IMAGE_FILE_HEADER;

  PImageDataDirectory = ^TImageDataDirectory;
  TImageDataDirectory = packed record
    VirtualAddress,
      Size: LONGWORD;
  end;

  PImageOptionalHeader = ^TImageOptionalHeader;
  TImageOptionalHeader = packed record
    Magic: WORD;
    MajorLinkerVersion,
      MinorLinkerVersion: BYTE;
    SizeofCode,
      SizeofInitializedData,
      SizeofUninitializedData,
      AddressofEntryPoint,
      BaseofCode,
      BaseofData,
      ImageBase,
      SectionAlignment,
      FileAlignment: LONGWORD;
    MajorOperatingSystemVersion,
      MinorOperatingSystemVersion,
      MajorImageVersion,
      MinorImageVersion,
      MajorSubsystemVersion,
      MinorSubsystemVersion: WORD;
    Win32VersionValue,
      SizeofImage,
      SizeofHeaders,
      CheckSum: LONGWORD;
    Subsystem,
      DllCharacteristics: WORD;
    SizeofStackReserve,
      SizeofStackCommit,
      SizeofHeapReserve,
      SizeofHeapCommit,
      LoaderFlags,
      NumberofRvaAndSizes: LONGWORD;
    DataDirectory: packed array[0..IMAGE_NUMBERof_DIRECTORY_ENTRIES - 1] of TImageDataDirectory;
  end;

  PImageNTHeaders = ^TImageNTHeaders;
  TImageNTHeaders = packed record
    Signature: LONGWORD;
    FileHeader: TImageFileHeader;
    OptionalHeader: TImageOptionalHeader;
  end;

   TISHMisc = packed record
    case Integer of  //Just union
      0: (PhysicalAddress: DWORD); // For Dll and Exe don't use:
      1: (VirtualSize: DWORD);     // - Size of section in memory
  end;

  _IMAGE_SECTION_HEADER = packed record  //(C++: IMAGE_SECTION_HEADER)
    Name: packed array[0..IMAGE_SIZEOF_SHORT_NAME-1] of Byte; //An 8-byte, null-padded ASCII string
    Misc: TISHMisc; // Virtual Size : Total size of the section when loaded into memory
    VirtualAddress: DWORD;  // Virtual address of section's begin
    SizeOfRawData: DWORD;   // Size of the section (object file) or size of the initialized data on disk (image files)
    PointerToRawData: DWORD;    // For executable images, this must be a multiple of FileAlignment from the optional header
    PointerToRelocations: DWORD; // File pointer to beginning of relocation entries for the section
    PointerToLinenumbers: DWORD;   //File pointer to beginning of line-number entries for the section
    NumberOfRelocations: Word;	//Number of relocation entries for the section. Set to 0 for executable images.
    NumberOfLinenumbers: Word;  // Same for PointerToLineNumbers
    Characteristics: DWORD; // Flags describing section’s characteristics
  end;
  TImageSectionHeader = _IMAGE_SECTION_HEADER;
  PImageSectionHeader = ^TImageSectionHeader;

  PImageBaseRelocation = ^TImageBaseRelocation;
  TImageBaseRelocation=packed record
    VirtualAddress:cardinal;
    SizeOfBlock:cardinal;
  end;

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

  TExternalLibrary = record
    LibraryName: string;
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
    LibraryName: string;
    LibraryHandle: HINST;
    Entries: array of TDLLfunctionImport;
  end;

  TImports = array of TDLLImport;

  PFunctionImport = ^TFunctionImport;
  TFunctionImport = record
    LibraryName : string;
    LibraryHandle : HINST;
    FunctionName : string;
    FunctionID : integer;
    FunctionAddress : Cardinal;
    FunctionPointer : Pointer;
    isBound : boolean;
  end;

  TFunctions = array of TFunctionImport;

  PDLLfunctionExport = ^TDLLfunctionExport;
  TDLLfunctionExport = record
    Name: string;
    Index: integer;
    functionPointer: POINTER;
  end;

  TExports = array of TDLLfunctionExport;


  PImportThunkData = ^TImportThunkData;
  TImportThunkData = record
    case Integer of
      0: (ForwarderString: DWORD);   // PBYTE
      1: (Function_: DWORD);         // PDWORD
      2: (Ordinal: DWORD);
      3: (AddressOfData: DWORD);     // PIMAGE_IMPORT_BY_NAME
  end;


implementation

end.
