program TestLGVarJson;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, GuiTestRunner, LGVarJsonTest;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

