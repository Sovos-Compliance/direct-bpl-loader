program TestUnhooked;
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
  TestmlBaseLoader in 'TestmlBaseLoader.pas',
  mlBaseLoader in '..\mlBaseLoader.pas',
  mlPEHeaders in '..\mlPEHeaders.pas',
  mlLibraryManager in '..\mlLibraryManager.pas',
  TestmlLibraryManager in 'TestmlLibraryManager.pas',
  TestConstants in 'TestConstants.pas',
  mlTypes in '..\mlTypes.pas',
  mlBPLLoader in '..\mlBPLLoader.pas',
  TestInterfaces in '..\TestDLLs\TestInterfaces.pas';

{$R *.RES}

begin
  Application.Initialize;
  if IsConsole then
    TextTestRunner.RunRegisteredTests
  else
    GUITestRunner.RunRegisteredTests;
end.

