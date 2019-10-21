program LanMonitor;

{$APPTYPE CONSOLE}

uses Windows,Classes,SysUtils,DateUtils,Trayicon,Graphics,Forms,ShellApi,Controls;

function GetConsoleWindow():HWND;stdcall;external 'kernel32.dll';

const temp='lanmonitor';

type TSnap=record
size:Cardinal;
date:TFileTime;
name:string;
end;

type ArrayOfSnap=array of TSnap;

var path:string;
handle:THandle;
icon:TTrayIcon;
messages:string;
msgcnt:Integer;
wind:HWND;

procedure tofile(name:string;const arr:ArrayOfSnap);
var stream:TFileStream;
org:Pointer;
mem:Pinteger;
i,len:Integer;
pc:PChar;
begin
len:=4;
for i:=0 to Length(arr)-1 do Inc(len,Length(arr[i].name)+1+8+4);
GetMem(org,len);
mem:=PInteger(org);
mem^:=Length(arr);
Inc(mem);
for i:=0 to Length(arr)-1 do begin
Move(arr[i],mem^,12);
Inc(mem,3);
end;
pc:=PChar(mem);
for i:=0 to Length(arr)-1 do pc:=StrECopy(pc,PChar(arr[i].name))+1;
stream:=TFileStream.Create(name,fmCreate);
stream.WriteBuffer(org^,len);
stream.Free;
FreeMem(org);
end;

function fromfile(name:string;out arr:ArrayOfSnap):Boolean;
var stream:TFileStream;
org:Pointer;
mem:Pinteger;
i,len:Integer;
pc:PChar;
begin
Result:=False;
org:=nil;
stream:=nil;
try
len:=4;
stream:=TFileStream.Create(name,fmOpenRead or fmShareDenyWrite);
len:=stream.Size;
if len>10*1024*1024 then abort;
GetMem(org,len);
stream.ReadBuffer(org^,len);
mem:=PInteger(org);
len:=mem^;
if (len<1)or(len>1*1024*1024) then Abort;
SetLength(arr,len);
Inc(mem);
for i:=0 to len-1 do begin
Move(mem^,arr[i],12);
Inc(mem,3);
end;
pc:=PChar(mem);
for i:=0 to Length(arr)-1 do begin
arr[i].name:=string(pc);
Inc(pc,Length(arr[i].name)+1);
end;
Result:=True;
except end;
stream.Free;
if org<>nil then FreeMem(org);
end;


procedure ouput(text:string);
begin
Writeln(text,'* ');
Writeln(ErrOutput,'* ',text);
Flush(Output);
Flush(ErrOutput);
messages:=messages+#13+text;
Inc(msgcnt);
end;

procedure add(var search:TSearchRec;var arr:ArrayOfSnap;var count:Integer;dir:string);
begin
if Length(arr)<=count then SetLength(arr,(count+1)*2);
arr[count].name:=dir+search.Name;
arr[count].date:=search.FindData.ftLastWriteTime;
arr[count].size:=search.Size;
Inc(count);
end;

procedure print(arr:ArrayOfSnap);
var index:integer;
begin
for index:=0 to Length(arr)-1 do begin
ouput('"'+arr[index].name+'" ('+IntToStr(arr[index].size)+')');
end;
end;

procedure snap(var arr:ArrayOfSnap;dir:string='\';Pcount:Pinteger=nil);
var search:TSearchRec;
list:TStringList;
index,count:Integer;
first:boolean;
begin
if Pcount=nil then begin
SetLength(arr,0);
count:=0;
Pcount:=@count;
first:=true;
end else first:=false;
if 0<>FindFirst(path+dir+'*',faAnyFile,search) then Exit;
list:=TStringList.Create;
repeat
if (search.Name<>'.')and(search.Name<>'..') then begin
if (search.Attr and faDirectory)<>0 then list.Add(search.Name)
else add(search,arr,Pcount^,dir);
end;
until FindNext(search)<>0;
FindClose(search);
for index:=0 to list.Count-1 do begin
snap(arr,dir+list[index]+'\',Pcount);
end;
list.Free;
if first then SetLength(arr,count);
end;

function compare(old,new:ArrayOfSnap):Boolean;
var i,j:integer;
sold,snew:integer;
flag:boolean;
cop:ArrayOfSnap;
begin
Result:=False;
sold:=Length(old);
snew:=Length(new);
cop:=old;

SetLength(old,sold);
SetLength(new,snew);
SetLength(cop,sold);

i:=0;
while (i<sold)and(sold>0) do begin
flag:=false;
j:=0;
while (j<snew)and(snew>0) do begin
if (old[i].name=new[j].name)and(old[i].size=new[j].size)and(old[i].date.dwLowDateTime=new[j].date.dwLowDateTime)and(old[i].date.dwHighDateTime=new[j].date.dwHighDateTime) then begin
old[i]:=old[sold-1];
dec(sold);
new[j]:=new[snew-1];
dec(snew);
flag:=true;
break;
end;
Inc(j);
end;
if flag then continue;
Inc(i);
end;

i:=0;
while (i<sold)and(sold>0) do begin
flag:=false;
j:=0;
while (j<snew)and(snew>0) do begin
if (old[i].name=new[j].name) then begin
Result:=True;
ouput('Изм. "'+old[i].name+'" <'+IntToStr(old[i].size)+'> в <'+IntToStr(new[i].size)+'>');
old[i]:=old[sold-1];
dec(sold);
new[j]:=new[snew-1];
dec(snew);
flag:=true;
break;
end;
Inc(j);
end;
if flag then continue;
Inc(i);
end;

i:=0;
while (i<sold)and(sold>0) do begin
flag:=false;
j:=0;
while (j<snew)and(snew>0) do begin
if (old[i].size=new[j].size)and(old[i].date.dwLowDateTime=new[j].date.dwLowDateTime)and(old[i].date.dwHighDateTime=new[j].date.dwHighDateTime) then begin
Result:=True;
ouput('Перем. "'+old[i].name+'" <'+IntToStr(old[i].size)+'> в "'+new[i].name+'"');
old[i]:=old[sold-1];
dec(sold);
new[j]:=new[snew-1];
dec(snew);
flag:=true;
break;
end;
Inc(j);
end;
if flag then continue;
Inc(i);
end;

for i:=0 to sold-1 do begin
Result:=True;
ouput('Удален. "'+old[i].name+'" <'+IntToStr(old[i].size)+'>');
end;

old:=cop;
sold:=Length(cop);

j:=0;
while (j<snew)and(snew>0) do begin
flag:=false;
i:=0;
while (i<sold)and(sold>0) do begin
if (old[i].size=new[j].size)and(old[i].date.dwLowDateTime=new[j].date.dwLowDateTime)and(old[i].date.dwHighDateTime=new[j].date.dwHighDateTime) then begin
Result:=True;
ouput('Скопир. "'+new[j].name+'" из "'+old[i].name+'" <'+IntToStr(old[i].size)+'>');
new[j]:=new[snew-1];
dec(snew);
flag:=true;
break;
end;
Inc(i);
end;
if flag then continue;
Inc(j);
end;

for j:=0 to snew-1 do begin
Result:=True;
ouput('Добавл. "'+new[j].name+'" <'+IntToStr(new[j].size)+'>');
end;

end;


procedure loop(var last:ArrayOfSnap);
var old,cur:TDateTime;
arr:ArrayOfSnap;
cmp:Boolean;
begin
old:=Now();
while FindNextChangeNotification(handle) do begin
WaitForSingleObject(handle,INFINITE);
cur:=Now();
if SecondSpan(cur,old)>2 then ouput(TimeToStr(SysUtils.Now()));
sleep(500);
messages:='';
msgcnt:=0;
old:=now;
snap(arr);
cmp:=compare(last,arr);
last:=arr;
icon.Balloon(messages,'LanMonitor: '+IntToStr(msgcnt));
if cmp then tofile(temp,arr);
sleep(2000);
icon.Balloon();
end;
end;

var Showed:Boolean;

type Tmy=class
procedure LeftClick(Sender:TObject);
procedure RightClick (Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
end;

procedure Tmy.LeftClick(Sender:TObject);
begin
Showed:=not Showed;
if Showed then ShowWindow(wind,SW_MAXIMIZE)
else ShowWindow(wind,SW_HIDE);
end;


procedure Tmy.RightClick (Sender: TObject; Button: TMouseButton;    Shift: TShiftState; X, Y: Integer);
begin
LeftClick(Sender);
end;


function theread(p:Pointer):Integer;
var my:TMy;
msg:tagMSG;
i:TTrayIcon;
begin
i:=TTrayIcon.create(nil);
i.Icon.Handle:=ExtractIcon(HInstance,PChar('shell32.dll'),18);
i.Active:=True;
i.OnClick:=my.LeftClick;
i.OnRightClick:=my.RightClick;
i.ToolTip:='LanMonitor';
icon:=i;
while GetMessage(Msg, 0, 0, 0) do
begin
TranslateMessage(Msg);
DispatchMessage(Msg);
end;
end;

function HandlerRoutine(dwCtrlType:Integer):Boolean;
begin
if dwCtrlType=CTRL_CLOSE_EVENT then begin
Result:=False;
DestroyIcon(icon.Icon.Handle);
FreeAndNil(icon);
FindCloseChangeNotification(handle);
ouput('Работа завершена: '+DateToStr(SysUtils.Now()));
end else Result:=True;
end;

var arr,old:ArrayOfSnap;
c:Cardinal;
begin
wind:=GetConsoleWindow();
ShowWindow(wind,SW_HIDE);
if ParamCount<>1 then Exit;
path:=ParamStr(1);
if not DirectoryExists(path) then Exit;
icon:=nil;
CreateThread(nil,0,@theread,0,0,c);
while icon=nil do Sleep(50);
SetConsoleCtrlHandler(@HandlerRoutine,True);
handle:=FindFirstChangeNotificationA(PChar(path),true,FILE_NOTIFY_CHANGE_FILE_NAME or FILE_NOTIFY_CHANGE_DIR_NAME or FILE_NOTIFY_CHANGE_SIZE or FILE_NOTIFY_CHANGE_LAST_WRITE);
if handle=INVALID_HANDLE_VALUE then exit;
ouput('Мониторинг запущен: "'+path+'", '+DateToStr(SysUtils.Now()));
ouput(TimeToStr(SysUtils.Now()));
snap(arr);
if fromfile(temp,old) then begin
messages:='';
msgcnt:=0;
if compare(old,arr) then begin
icon.Balloon(messages,'LanMonitor STARTED: '+IntToStr(msgcnt));
tofile(temp,arr);
sleep(2000);
icon.Balloon();
end else tofile(temp,arr);
end else tofile(temp,arr);
SetLength(old,0);
loop(arr);
FindCloseChangeNotification(handle);
FreeAndNil(icon);
end.
