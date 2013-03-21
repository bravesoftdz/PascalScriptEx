unit FrameEditor;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes,
  Graphics, Controls, Forms, Dialogs, Menus, SynEdit,
  StdCtrls, ExtCtrls, SynEditHighlighter, SynHighlighterPas,
  uPSComponent, uPSCompiler, ActnList, ComCtrls, SynEditKeyCmds,
  SynCompletionProposal, uPSUtils, PSResources;

type
  TFrm_Editor = class(TForm)
    Splitter1: TSplitter;
    Messages: TMemo;
    Editor: TSynEdit;
    SynPasSyn: TSynPasSyn;
    PSScript: TPSScript;
    PSScriptDebugger: TPSScriptDebugger;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    New1: TMenuItem;
    N3: TMenuItem;
    Open1: TMenuItem;
    Save1: TMenuItem;
    Saveas1: TMenuItem;
    N4: TMenuItem;
    Exit1: TMenuItem;
    Search1: TMenuItem;
    Find1: TMenuItem;
    Replace1: TMenuItem;
    Searchagain1: TMenuItem;
    N6: TMenuItem;
    Gotolinenumber1: TMenuItem;
    Run1: TMenuItem;
    Compile1: TMenuItem;
    Decompile1: TMenuItem;
    N5: TMenuItem;
    StepOver1: TMenuItem;
    StepInto1: TMenuItem;
    N1: TMenuItem;
    Pause1: TMenuItem;
    Reset1: TMenuItem;
    N2: TMenuItem;
    Run: TMenuItem;
    este1: TMenuItem;
    SaveCompile1: TMenuItem;
    LoadCompiled1: TMenuItem;
    ActionList1: TActionList;
    acSave: TAction;
    PSCustomPlugin: TPSCustomPlugin;
    acSaveAs: TAction;
    acNew: TAction;
    acOpen: TAction;
    acExit: TAction;
    acReset: TAction;
    acFind: TAction;
    acReplace: TAction;
    acFindNext: TAction;
    acGoToLine: TAction;
    acCompile: TAction;
    acDecompile: TAction;
    acStepOver: TAction;
    acStepInto: TAction;
    acPause: TAction;
    acRun: TAction;
    StatusBar: TStatusBar;
    SynCompletionProposal: TSynCompletionProposal;
    procedure PSScriptCompile(Sender: TPSScript);
    procedure PSScriptExecute(Sender: TPSScript);
    procedure acSaveExecute(Sender: TObject);
    procedure acNewExecute(Sender: TObject);
    procedure acOpenExecute(Sender: TObject);
    procedure acSaveAsExecute(Sender: TObject);
    procedure acExitExecute(Sender: TObject);
    procedure acResetExecute(Sender: TObject);
    procedure acCompileExecute(Sender: TObject);
    procedure acRunExecute(Sender: TObject);
    procedure acGoToLineExecute(Sender: TObject);
    procedure EditorStatusChange(Sender: TObject; Changes: TSynStatusChanges);
    procedure SynCompletionProposalAfterCodeCompletion(Sender: TObject; const Value: string; Shift: TShiftState; Index: Integer; EndToken: Char);
    procedure EditorDropFiles(Sender: TObject; X, Y: Integer; AFiles: TStrings);
  private
    FActiveFile: TFileName;
    function Compile: Boolean;
    function SaveCheck: Boolean;

    procedure RegisterPlugins;

    procedure UpdateStatusBar;

    procedure LoadAutoComplete;

    procedure LoadFromFile(AFileName: string);
  public
    constructor Create(AOwner: TComponent); override;

    property ActiveFile: TFileName read FActiveFile;

  end;

var
  Frm_Editor: TFrm_Editor;

implementation

{$R *.dfm}

uses RegisterPlugins, Frm_GotoLine, StrUtils;

{ TFrame1 }

procedure TFrm_Editor.acCompileExecute(Sender: TObject);
begin
  Compile;
end;

procedure TFrm_Editor.acExitExecute(Sender: TObject);
begin
  acReset.Execute;

  if SaveCheck then
  begin
    Close;
  end;
end;

procedure TFrm_Editor.acGoToLineExecute(Sender: TObject);
begin
  with TFrm_GoToLine.Create(Editor.CaretX, Editor.CaretY) do
  try
    if Execute then
    begin
      Editor.CaretXY := CaretXY;
    end;
  finally
    Free;
    Editor.SetFocus;
  end;
end;

procedure TFrm_Editor.acNewExecute(Sender: TObject);
begin
  if SaveCheck then
  begin
    Editor.ClearAll;
    Editor.Lines.Text := sEmptyProgram;
    Editor.Modified := False;
    FActiveFile := EmptyStr;
  end;
end;

procedure TFrm_Editor.acOpenExecute(Sender: TObject);
begin
 if SaveCheck and OpenDialog1.Execute then
  begin
    LoadFromFile(OpenDialog1.FileName);
  end;
end;

procedure TFrm_Editor.acResetExecute(Sender: TObject);
begin
  if PSScript.Exec.Status in isRunningOrPaused then
  begin
    PSScript.Stop;
  end;
end;

procedure TFrm_Editor.acRunExecute(Sender: TObject);
begin
  if Compile then
  begin
    if PSScript.Execute then
    begin
      Messages.Lines.Add(sSuccessfullyExecuted);
    end else
    begin
      Messages.Lines.Add(Format(sRuntimeError,
                                ['[empty]', PSScript.ExecErrorRow, PSScript.ExecErrorCol,
                                 PSScript.ExecErrorProcNo, PSScript.ExecErrorByteCodePosition,
                                 PSScript.ExecErrorToString]));
    end;
  end;
end;

procedure TFrm_Editor.acSaveAsExecute(Sender: TObject);
begin
  if SaveDialog1.Execute then
  begin
    FActiveFile := SaveDialog1.FileName;
    Editor.Lines.SaveToFile(FActiveFile);
    Editor.Modified := False;
  end;
end;

procedure TFrm_Editor.acSaveExecute(Sender: TObject);
begin
  if FActiveFile <> EmptyStr then
  begin
    Editor.Lines.SaveToFile(FActiveFile);
    Editor.Modified := False;
  end
  else
  begin
    acSaveAs.Execute;
  end;
end;

function TFrm_Editor.Compile: Boolean;
var
  i: Integer;
  vErrorFound: Boolean;
  vMessage: TPSPascalCompilerMessage;
begin
  Messages.Lines.Clear;

  PSScript.Script.Assign(Editor.Lines);

  Messages.Lines.Add(sBeginCompile);

  Result := PSScript.Compile;

  vErrorFound := False;

  for i := 0 to PSScript.CompilerMessageCount - 1 do
  begin
    vMessage := PSScript.CompilerMessages[i];

    Messages.Lines.Add(String(vMessage.MessageToString));

    if not vErrorFound and (vMessage is TIFPSPascalCompilerError) then
    begin
      Editor.SelStart := vMessage.Pos;

      vErrorFound := True;
    end;
  end;
end;

procedure TFrm_Editor.RegisterPlugins;
begin
  RegisterPSPlugins(PSScript);
  RegisterPSPlugins(PSScriptDebugger);

  //Custom Plugin to Handle events on form
  with TPSPluginItem(PSScript.Plugins.Add) do
  begin
    Plugin := PSCustomPlugin;
  end;
  with TPSPluginItem(PSScriptDebugger.Plugins.Add) do
  begin
    Plugin := PSCustomPlugin;
  end;
end;

function TFrm_Editor.SaveCheck: Boolean;
begin
  if Editor.Modified then
  begin
    case MessageDlg(sFileNotSaved, mtConfirmation, mbYesNoCancel, 0) of
      mrYes:
        begin
          acSave.Execute;

          Result := FActiveFile <> EmptyStr;
        end;
      mrNo: Result := True;
      else
        Result := False;
    end;
  end
  else
    Result := True;
end;

procedure TFrm_Editor.SynCompletionProposalAfterCodeCompletion(Sender: TObject;
  const Value: string; Shift: TShiftState; Index: Integer; EndToken: Char);
begin
  if RightStr(Value, 1) = ')' then
  begin
    Editor.CaretX := Editor.CaretX - 1;
  end;
end;

procedure TFrm_Editor.UpdateStatusBar;
const
  spCaretPos = 0;
  spInsertMode = 1;
  spModified = 2;
  spFile = 3;
const
  InsertText: array[Boolean] of String = ('Overwrite', 'Insert');
begin
  StatusBar.Panels[spCaretPos].Text := Format('%d:%d', [Editor.CaretY, Editor.CaretX]);

  if Editor.ReadOnly then
    StatusBar.Panels[spInsertMode].Text := 'Read only'
  else
    StatusBar.Panels[spInsertMode].Text := InsertText[Editor.InsertMode];

  StatusBar.Panels[spModified].Text := IfThen(Editor.Modified, 'Modified');
  StatusBar.Panels[spFile].Text := FActiveFile;
end;

constructor TFrm_Editor.Create(AOwner: TComponent);
begin
  inherited;

  Caption := sEditorTitle;

  RegisterPlugins;

  acNew.Execute;

  acCompile.Execute;

  UpdateStatusBar;
end;

procedure TFrm_Editor.EditorDropFiles(Sender: TObject; X, Y: Integer; AFiles: TStrings);
begin
  if (AFiles.Count > 0) and SaveCheck then
  begin
    LoadFromFile(AFiles[0]);
  end;
end;

procedure TFrm_Editor.EditorStatusChange(Sender: TObject; Changes: TSynStatusChanges);
begin
  UpdateStatusBar;
end;

procedure TFrm_Editor.LoadAutoComplete;
const
  sFunctionStyle  = '\COLOR{clNavy}function \COLOR{clBlack}\STYLE{+B}%s\STYLE{-B}%s;';
  sProcedureStyle = '\COLOR{clNavy}procedure \COLOR{clBlack}\STYLE{+B}%s\STYLE{-B}%s;';
  sVariableStyle = '\COLOR{clNavy}var \COLOR{clBlack}\STYLE{+B}%s: \STYLE{-B}%s;';
  sConstStyle = '\COLOR{clNavy}const \COLOR{clBlack}\STYLE{+B}%s: \COLOR{clBlue}\STYLE{-B}%s;';
  sTypeStyle = '\COLOR{clNavy}type \COLOR{clBlack}\STYLE{+B}%s: \COLOR{clBlue}\STYLE{-B}%s;';
var
  i: Integer;
  obj: TPSRegProc;
  obj_var: TPSVar;
  obj_const: TPSConstant;
  obj_type: TPSType;
  vTemplate: string;
begin
  SynCompletionProposal.ItemList.Clear;

  for i:= 0 to PSScript.Comp.GetRegProcCount-1 do
  begin
    obj := PSScript.Comp.GetRegProc(i);

    vTemplate := sProcedureStyle;
    if obj.Decl.Result <> nil then
    begin
      vTemplate := sFunctionStyle;
    end;

    SynCompletionProposal.AddItem(Format(vTemplate, [obj.OrgName, TPsUtils.GetMethodParametersDeclaration(obj.Decl)]), UnicodeString(obj.OrgName + '()'));
  end;

  for i:= 0 to PSScript.Comp.GetVarCount-1 do
  begin
    obj_var := PSScript.Comp.GetVar(i);

    SynCompletionProposal.AddItem(Format(sVariableStyle, [obj_var.OrgName, obj_var.aType.OriginalName]), UnicodeString(obj_var.OrgName));
  end;

  for i := 0 to PSScript.Comp.GetConstCount-1 do
  begin
   obj_const := PSScript.Comp.GetConst(i);

   SynCompletionProposal.AddItem(Format(sConstStyle, [obj_const.OrgName, TPSUtils.GetAsString(PSScript, obj_const.Value)]), UnicodeString(obj_const.OrgName));
  end;

  for i := 0 to PSScript.Comp.GetTypeCount-1 do
  begin
    obj_type := PSScript.Comp.GetType(i);

    SynCompletionProposal.AddItem(Format(sTypeStyle, [obj_type.OriginalName, TPSUtils.GetPSTypeName(PSScript, obj_type)]), UnicodeString(obj_type.OriginalName));
  end;
end;

procedure TFrm_Editor.LoadFromFile(AFileName: string);
var
  vRelativePath: string;
begin
  SetCurrentDir(ExtractFilePath(Application.ExeName));

  vRelativePath := ExtractRelativePath(IncludeTrailingPathDelimiter(GetCurrentDir), ExtractFilePath(AFileName));

  Editor.ClearAll;
  Editor.Lines.LoadFromFile(vRelativePath + ExtractFileName(AFileName));
  Editor.Modified := False;
  FActiveFile := AFileName;
end;

procedure TFrm_Editor.PSScriptCompile(Sender: TPSScript);
begin
  Sender.AddRegisteredVariable('Application',  'TApplication' );
  Sender.AddRegisteredVariable('Self', 'TForm');

  LoadAutoComplete;
end;

procedure TFrm_Editor.PSScriptExecute(Sender: TPSScript);
begin
  Sender.SetVarToInstance('Application', Application);
  Sender.SetVarToInstance('Self', Self);
end;

end.
