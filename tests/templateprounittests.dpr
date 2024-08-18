program templateprounittests;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Generics.Collections,
  System.IOUtils,
  System.Rtti,
  System.Classes,
  UtilsU in 'UtilsU.pas',
  TemplatePro in '..\TemplatePro.pas',
  JsonDataObjects in '..\JsonDataObjects.pas',
  MVCFramework.Nullables in '..\MVCFramework.Nullables.pas';

const
  TestFileNameFilter = '*'; // '*' means "all files'


function SayHelloFilter(const aValue: TValue; const aParameters: TArray<string>): string;
begin
  Result := 'Hello ' + aValue.AsString;
end;

procedure TestTokenWriteReadFromFile;
var
  lBW: TBinaryWriter;
  lToken: TToken;
  lBR: TBinaryReader;
  lToken2: TToken;
begin
  lBW := TBinaryWriter.Create(TFileStream.Create('output.tp', fmOpenWrite or fmShareDenyNone));
  try
    lToken := TToken.Create(ttLoop, 'value1','value2', -1, 2);
    lToken.SaveToBytes(lBW);
  finally
    lBW.Free;
  end;

  lBR := TBinaryReader.Create(TFileStream.Create('output.tp', fmOpenRead or fmShareDenyNone), nil, True);
  try
    lToken2 := TToken.CreateFromBytes(lBR);
  finally
    lBR.Free;
  end;

  Assert(lToken.TokenType = lToken2.TokenType);
  Assert(lToken.Value1 = lToken2.Value1);
  Assert(lToken.Value2 = lToken2.Value2);
  Assert(lToken.Ref1 = lToken2.Ref1);
  Assert(lToken.Ref2 = lToken2.Ref2);
  WriteLn('TestTokenWriteReadFromFile: OK');
end;

procedure TestWriteReadFromFile;
var
  lCompiler : TTProCompiler;
  lCompiledTmpl: ITProCompiledTemplate;
  lOutput1: string;
  lOutput2: string;
begin
  lCompiler := TTProCompiler.Create();
  try
    lCompiledTmpl := lCompiler.Compile('{{:value1}} hello world {{:value2}}');
    lCompiledTmpl.SaveToFile('output.tpc');
  finally
    lCompiler.Free;
  end;


  lCompiledTmpl := TTProCompiledTemplate.CreateFromFile('output.tpc');
  lCompiledTmpl.SetData('value1', 'Daniele');
  lCompiledTmpl.SetData('value2', 'Teti');
  lOutput1 := lCompiledTmpl.Render;

  lCompiledTmpl.ClearData;
  lCompiledTmpl.SetData('value1', 'Bruce');
  lCompiledTmpl.SetData('value2', 'Banner');
  lOutput2 := lCompiledTmpl.Render;

  Assert('Daniele hello world Teti' = lOutput1);
  Assert('Bruce hello world Banner' = lOutput2);

  WriteLn('TestWriteReadFromFile: OK');
end;

procedure Main;
var
  lTPro: TTProCompiler;
  lInput: string;
  lItems, lItemsWithFalsy: TObjectList<TDataItem>;
begin
  var lFailed := False;
  lTPro := TTProCompiler.Create;
  try
    var lInputFileNames := TDirectory.GetFiles('..\test_scripts\', '*.tpro',
      function(const Path: string; const SearchRec: TSearchRec): Boolean
      begin
        Result := (not String(SearchRec.Name).StartsWith('included'))
                   and ((TestFileNameFilter = '*') or String(SearchRec.Name).Contains(TestFileNameFilter));
        Result := Result and not (String(SearchRec.Name).StartsWith('_'));
      end);
    for var lFile in lInputFileNames do
    begin
      try
        lInput := TFile.ReadAllText(lFile, TEncoding.UTF8);
        Write(TPath.GetFileName(lFile).PadRight(30));
        var lTestScriptsFolder := TPath.Combine(GetModuleName(HInstance), '..', '..', 'test_scripts');
        var lCompiledTemplate := lTPro.Compile(lInput, lTestScriptsFolder);
        lCompiledTemplate.SetData('value0','true');
        lCompiledTemplate.SetData('value1','true');
        lCompiledTemplate.SetData('value2','DANIELE2');
        lCompiledTemplate.SetData('value3','DANIELE3');
        lCompiledTemplate.SetData('value4','DANIELE4');
        lCompiledTemplate.SetData('value5','DANIELE5');
        lCompiledTemplate.SetData('value6','DANIELE6');
        lCompiledTemplate.SetData('myhtml','<div>this <strong>HTML</strong></div>');
        lCompiledTemplate.SetData('valuedate', EncodeDate(2024,8,20));
        lCompiledTemplate.AddFilter('sayhello', SayHelloFilter);
        var lJSONArr := TJsonBaseObject.ParseFromFile(TPath.Combine(lTestScriptsFolder, 'people.json')) as TJsonArray;
        try
          var lJSONObj := TJsonObject.Create;
          try
            lJSONObj.A['people'] := lJSONArr.Clone;
            lItems := GetItems;
            try
              lItemsWithFalsy := GetItems(True);
              try
                lCompiledTemplate.SetData('obj', lItems[0]);
                var lCustomers := GetCustomersDataset;
                try
                  lCompiledTemplate.SetData('customers', lCustomers);
                  lCompiledTemplate.SetData('objects', lItems);
                  lCompiledTemplate.SetData('objectsb', lItemsWithFalsy);
                  lCompiledTemplate.SetData('jsonobj', lJSONObj);
                  var l := lJSONArr[0].Path['colors'];

                  var lActualOutput := lCompiledTemplate.Render;
                  var lExpectedOutput := TFile.ReadAllText(lFile + '.expected.txt', TEncoding.UTF8);
                  if lActualOutput <> lExpectedOutput then
                  begin
                    WriteLn(': FAILED');
                    lCompiledTemplate.DumpToFile(lFile + '.failed.dump.txt');
                    TFile.WriteAllText(lFile + '.failed.txt', lActualOutput, TEncoding.UTF8);
                    lFailed := True;
                  end
                  else
                  begin
                    if TFile.Exists(lFile + '.failed.txt') then
                    begin
                      TFile.Delete(lFile + '.failed.txt');
                    end;
                    if TFile.Exists(lFile + '.failed.dump.txt') then
                    begin
                      TFile.Delete(lFile + '.failed.dump.txt');
                    end;
                    WriteLn(' : OK');
                  end;
                finally
                  lCustomers.Free;
                end;
              finally
                lItemsWithFalsy.Free;
              end;
            finally
              lItems.Free;
            end;
          finally
            lJSONObj.Free;
          end;
        finally
          lJSONArr.Free;
        end;
      except
        on E: Exception do
        begin
          Writeln(' : FAIL - ' + E.Message);
          lFailed := True;
        end;
      end;
    end;
  finally
    lTPro.Free;
  end;
  if lFailed or (DebugHook <> 0) then
  begin
    Readln;
  end;
end;


begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Writeln('   |---------------------------|');
    Writeln('---| TEMPLATE PRO - UNIT TESTS |---');
    Writeln('   |---------------------------|');
    Writeln;
    TestTokenWriteReadFromFile;
    TestWriteReadFromFile;
    Main;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
