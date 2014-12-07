program TestHooked;
{

  Delphi DUnit Test Project
  -------------------------
  This project contains the DUnit test framework and the GUI/Console test runners.
  Add "CONSOLE_TESTRUNNER" to the conditional defines entry in the project options 
  to use the console test runner.  Otherwise the GUI test runner will be used by 
  default.

}

{$IFDEF CONSOLE_TESTRUNNER}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  Forms,
  TestFramework,
  GUITestRunner,
  TextTestRunner,
  TestmlLibraryManagerHooked in 'TestmlLibraryManagerHooked.pas',
  TestConstants in 'TestConstants.pas',
  mlBaseLoader in '..\mlBaseLoader.pas',
  mlBPLLoader in '..\mlBPLLoader.pas',
  mlLibrary in '..\mlLibrary.pas',
  mlManagers in '..\mlManagers.pas',
  mlPEHeaders in '..\mlPEHeaders.pas',
  mlTypes in '..\mlTypes.pas';

{$R *.RES}

begin
  Application.Initialize;
  if IsConsole then
    TextTestRunner.RunRegisteredTests
  else
    GUITestRunner.RunRegisteredTests;
end.

