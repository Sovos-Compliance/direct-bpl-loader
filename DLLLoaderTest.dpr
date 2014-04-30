program DLLLoaderTest;

{%ToDo 'DLLLoaderTest.todo'}

uses
  Forms,
  ImageLoader in 'ImageLoader.pas',
  TestFrameWork,
  GUITestRunner,
  PEHeaders in 'PEHeaders.pas',
  ExportTree in 'ExportTree.pas',
  HijackGetProcTest in 'Tests\HijackGetProcTest.pas',
  HijackImportProc in 'HijackImportProc.pas',
  HijackGetProc in 'HijackGetProc.pas',
  HijackLoadLibraryTest in 'Tests\HijackLoadLibraryTest.pas',
  HijackLoadLibrary in 'HijackLoadLibrary.pas',
  HijackResString in 'HijackResString.pas',
  HJPEImage in 'HJPEImage.pas',
  ImportsTable in 'ImportsTable.pas';

{$R *.res}

begin
  Application.Initialize;
  GUITestRunner.RunRegisteredTests;
  
end.
