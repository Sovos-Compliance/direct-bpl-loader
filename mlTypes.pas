{*******************************************************************************
*  Vladimir Georgiev, 2014                                                     *
*                                                                              *
*  Types used by the "Memory Library" units                                    *
*                                                                              *
*******************************************************************************}

unit mlTypes;

interface

uses
  SysUtils, Windows, Classes;

type
  /// A helper type for the handles used by the emulated functions
  /// Currently equal to the original HMODULE, but can be changed to another type to avoid
  /// mixing it with handles returned by the original APIs
  TLibHandle = type HMODULE;

  /// Exception classes raised by the "ML" library
  EMlError            = class(Exception);
  EMlInvalidHandle    = class(EMlError);
  EMlLibraryLoadError = class(EMlError);
  EMlProcedureError   = class(EMlError);
  EMlResourceError    = class(EMlError);

  /// A Callback function that is called when a library being loaded needs to load a dependent library
  /// The value set in aLoadAction defines how the dependent library should be loaded
  ///   laDiscard - don't load the library
  ///   laHardDrive - load the library with the standard LoadLibrary Windows API
  ///   laMemStream - load the library from the stream passed in aMemStream (which has to be freed later)
  TLoadAction = (laHardDisk, laMemStream, laDiscard);
  TMlLoadDependentLibraryEvent = procedure(const aLibName, aDependentLib: String; var aLoadAction: TLoadAction; var
      aMemStream: TMemoryStream; var aFreeStream: Boolean) of object;

implementation

end.

