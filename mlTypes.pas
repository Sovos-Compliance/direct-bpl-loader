{*******************************************************************************
*  Vladimir Georgiev, 2014                                                     *
*                                                                              *
*  Types used by the "Memory Library" units                                    *
*                                                                              *
*******************************************************************************}

unit mlTypes;

interface

uses
  SysUtils, Windows;

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

  TMlLoadDependentLibraryEvent = procedure(const aLibName, aDependentLib: String; var aLoad: Boolean);

implementation

end.

