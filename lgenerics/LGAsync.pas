{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Some asynchronous stuff.                                                *
*                                                                           *
*   Copyright(c) 2018-2019 A.Koverdyaev(avk)                                *
*                                                                           *
*   This code is free software; you can redistribute it and/or modify it    *
*   under the terms of the Apache License, Version 2.0;                     *
*   You may obtain a copy of the License at                                 *
*     http://www.apache.org/licenses/LICENSE-2.0.                           *
*                                                                           *
*  Unless required by applicable law or agreed to in writing, software      *
*  distributed under the License is distributed on an "AS IS" BASIS,        *
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
*  See the License for the specific language governing permissions and      *
*  limitations under the License.                                           *
*                                                                           *
*****************************************************************************}
unit LGAsync;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}

interface

uses
  Classes,
  SysUtils,
  LGUtils,
  LGQueue,
  LGVector,
  LGFunction,
  LGStrConst;

type

  TAsyncTask = class abstract
  public
  type
    TState = (tsPending, tsExecuting, tsFinished, tsCancelled);

  strict private
    FState: DWord;
    FAwait: PRtlEvent;
    FException: Exception;
    function GetState: TState; inline;
  strict protected
    procedure DoExecute; virtual; abstract;
  public
    destructor Destroy; override;
    procedure AfterConstruction; override;
    function  Cancel: Boolean;
    procedure Execute;
    procedure WaitFor;
    property  FatalException: Exception read FException;
    property  State: TState read GetState;
  end;

  generic TGAsyncTask<T> = class abstract(TAsyncTask)
  strict protected
    FResult: T; //To be setted inside overriden DoExecute
  public
    property Result: T read FResult;
  end;

{$PUSH}{$INTERFACES CORBA}
  IExecutor = interface
  ['{49381C21-82D6-456E-93A2-B8E0DC4B34BA}']
    procedure EnqueueTask(aTask: TAsyncTask);
  end;
{$POP}

{
  The futures concept describes an asynchronous single-execution pattern.
  Result is requested at an early stage of execution, but becomes available after it is received.
  This implementation implies that futures are intended for use from the main thread.
}

  TFutureState = (fsPending, fsExecuting, fsFinished, fsResolved, fsFatal, fsCancelled);

{$PUSH}{$INTERFACES COM}
  generic IGFuture<T> = interface
  ['{87217C99-9D75-46CC-837A-44624C60C004}']
    function GetState: TFutureState;
    function WaitFor: TFutureState;
  { may be impossible, if task already started }
    function Cancel: Boolean;
  { raises exception if resolving failed }
    function Value: T;
    function Optional: specialize TGOptional<T>;
    property State: TFutureState read GetState;
  end;
{$POP}

  { TGFuture: takes over the management of the inner async task }
  generic TGFuture<T> = class(TInterfacedObject, specialize IGFuture<T>)
  public
  type
    TOptional = specialize TGOptional<T>;

  private
  type
    TTask = specialize TGAsyncTask<T>;

  strict private
    FTask: TTask;
    FTaskResult: T;
    FState: TFutureState;
    procedure Resolve;
  protected
    function GetState: TFutureState;
  public
    constructor Create(aTask: TTask; aEx: IExecutor);
    destructor Destroy; override;
    function WaitFor: TFutureState;
  { may be impossible, if task already started }
    function Cancel: Boolean;
  { raises exception if resolving failed }
    function Value: T;
    function Optional: TOptional;
    property State: TFutureState read GetState;
  end;

  { TGAsyncProc incapsulates method without arguments(which returns void), True indicates execution success }
  TGAsyncProc = class(specialize TGAsyncTask<Boolean>)
  public
  type
    TProcedure = procedure of object;
    IFuture    = specialize IGFuture<Boolean>;

  strict private
    FProc: TProcedure;
  strict protected
    procedure DoExecute; override;
  public
    class function Call(aProc: TProcedure; aEx: IExecutor = nil): IFuture; static;
    constructor Create(aProc: TProcedure);
  end;

  { TAsyncExecutable incapsulates IExecutable, True indicates execution success }
  TAsyncExecutable = class(specialize TGAsyncTask<Boolean>)
  public
  type
    IFuture = specialize IGFuture<Boolean>;

  strict private
    FTask: IExecutable;
  strict protected
    procedure DoExecute; override;
  public
    class function Run(aTask: IExecutable; aEx: IExecutor = nil): IFuture; static;
    constructor Create(aTask: IExecutable);
  end;

  { TGAsyncCallable incapsulates IGCallable}
  generic TGAsyncCallable<T> = class(specialize TGAsyncTask<T>)
  public
  type
    ICallable = specialize IGCallable<T>;
    IFuture   = specialize IGFuture<T>;

  strict private
    FTask: ICallable;
  strict protected
    procedure DoExecute; override;
  public
    class function Run(aTask: ICallable; aEx: IExecutor = nil): IFuture; static;
    constructor Create(aTask: ICallable);
  end;

  { TGAsyncMethod incapsulates niladic method(without arguments which returns T) }
  generic TGAsyncMethod<T> = class(specialize TGAsyncTask<T>)
  public
  type
    TFun    = function: T of object;
    IFuture = specialize IGFuture<T>;

  strict private
    FFun: TFun;
  strict protected
    procedure DoExecute; override;
  public
    class function Call(aFun: TFun; aEx: IExecutor = nil): IFuture; static;
    constructor Create(aFun: TFun);
  end;

  { TGAsyncNested incapsulates nested niladic function (without arguments) }
  generic TGAsyncNested<T> = class(specialize TGAsyncTask<T>)
  public
  type
    TFun    = function: T is nested;
    IFuture = specialize IGFuture<T>;

  strict private
    FFun: TFun;
  strict protected
    procedure DoExecute; override;
  public
    class function Call(aFun: TFun; aEx: IExecutor = nil): IFuture; static;
    constructor Create(aFun: TFun);
  end;

  { TGAsyncNiladic incapsulates regular niladic function (without arguments) }
  generic TGAsyncNiladic<T> = class(specialize TGAsyncTask<T>)
  strict protected
  public
  type
    TFun    = function: T;
    IFuture = specialize IGFuture<T>;

  strict private
    FFun: TFun;
  strict protected
    procedure DoExecute; override;
  public
    class function Call(aFun: TFun; aEx: IExecutor = nil): IFuture; static;
    constructor Create(aFun: TFun);
  end;

  { TGAsyncMonadic incapsulates regular monadic function (with one argument) }
  generic TGAsyncMonadic<T, TResult> = class(specialize TGAsyncTask<TResult>)
  strict protected
  type
    TCall = specialize TGDeferMonadic<T, TResult>;

  public
  type
    TFun    = TCall.TFun;
    IFuture = specialize IGFuture<TResult>;

  strict private
    FCall: TCall;
  strict protected
    procedure DoExecute; override;
  public
    class function Call(aFun: TFun; constref v: T; aEx: IExecutor = nil): IFuture; static;
    constructor Create(aFun: TFun; constref v: T);
  end;

  { TGAsyncDyadic incapsulates regular dyadic function (with two arguments) }
  generic TGAsyncDyadic<T1, T2, TResult> = class(specialize TGAsyncTask<TResult>)
  strict protected
  type
    TCall = specialize TGDeferDyadic<T1, T2, TResult>;

  public
  type
    TFun    = TCall.TFun;
    IFuture = specialize IGFuture<TResult>;

  strict private
    FCall: TCall;
  strict protected
    procedure DoExecute; override;
  public
    class function Call(aFun: TFun; constref v1: T1; constref v2: T2; aEx: IExecutor = nil): IFuture; static;
    constructor Create(aFun: TFun; constref v1: T1; constref v2: T2);
  end;

  { TGAsyncTriadic incapsulates regular triadic function (with three arguments) }
  generic TGAsyncTriadic<T1, T2, T3, TResult> = class(specialize TGAsyncTask<TResult>)
  strict protected
  type
    TCall = specialize TGDeferTriadic<T1, T2, T3, TResult>;

  public
  type
    TFun    = TCall.TFun;
    IFuture = specialize IGFuture<TResult>;

  strict private
    FCall: TCall;
  strict protected
    procedure DoExecute; override;
  public
    class function Call(aFun: TFun; constref v1: T1; constref v2: T2; constref v3: T3;
                        aEx: IExecutor = nil): IFuture; static;
    constructor Create(aFun: TFun; constref v1: T1; constref v2: T2; constref v3: T3);
  end;

const
  DEFAULT_POOL_SIZE = 4;

type
  { TDefaultExecutor executes futures in its own thread pool.
    Enqueue procedure is threadsafe, so futures may use other futures.
    Resizing of thread pool is not threadsafe, so MUST be done from main thread. }
  TDefaultExecutor = class
  private
   type
     TTaskQueue = class
     strict private
     type
       TQueue = specialize TGLiteQueue<TAsyncTask>;

     var
       FQueue: TQueue;
       FReadAwait: PRtlEvent;
       FLock: TRtlCriticalSection;
       FClosed: Boolean;
     public
       constructor Create;
       destructor Destroy; override;
       procedure AfterConstruction; override;
       procedure Clear;
       procedure Close;
       procedure Open;
       procedure Enqueue(aTask: TAsyncTask);
       function  Dequeue(out aTask: TAsyncTask): Boolean;
     end;

     TWorkThread = class(TThread)
     strict private
       FQueue: TTaskQueue;
     public
       constructor Create(aQueue: TTaskQueue);
       procedure Execute; override;
     end;

     TThreadPool = specialize TGLiteVector<TWorkThread>;

     TExecutor = class(TObject, IExecutor)
     private
       FTaskQueue: TTaskQueue;
       FThreadPool: TThreadPool;
       function  ThreadCount: Integer; inline;
       function  AddThread: TWorkThread;
       procedure PoolGrow(aValue: Integer);
       procedure PoolShrink(aValue: Integer);
       procedure EnqueueTask(aTask: TAsyncTask); inline;
       procedure TerminatePool;
       procedure FinalizePool; inline;
     public
       constructor Create; overload;
       constructor Create(aThreadCount: Integer); overload;
       destructor  Destroy; override;
     end;

     class constructor InitNil;
     class destructor  DoneQueue;
     class function    GetThreadCount: Integer; static; inline;
     class procedure   SetThreadCount(aValue: Integer); static;
   class var
     CFExecutor: TExecutor; // CF -> Class Field

   public
     class procedure EnsureThreadCount(aValue: Integer); static;
     class procedure Enqueue(aTask: TAsyncTask); static;
     class function  GetInstance: IExecutor; static;
     class property  ThreadCount: Integer read GetThreadCount write SetThreadCount;
   end;

const
  DEFAULT_CHAN_SIZE = 256;

type

  generic TGBlockChannel<T> = class
  strict protected
  type
    TBuffer = array of T;

  var
    FBuffer: TBuffer;
    FLock: TRtlCriticalSection;
    FWriteAwait,
    FReadAwait: PRtlEvent;
    FCount,
    FHead: SizeInt;
    FActive: Boolean;
    function  GetCapacity: SizeInt; inline;
    procedure SendData(constref aValue: T);
    function  ReceiveData: T;
    function  TailIndex: SizeInt; inline;
    procedure Enqueue(constref aValue: T);
    function  Dequeue: T;
    procedure Panic;
    procedure CleanupBuffer; virtual;
    property  Head: SizeInt read FHead;
  public
    constructor Create(aCapacity: SizeInt = DEFAULT_CHAN_SIZE);
    destructor Destroy; override;
    procedure AfterConstruction; override;
    function  Send(constref aValue: T): Boolean;
    function  Receive(out aValue: T): Boolean;
    procedure Close;
    procedure Open;
  { if is not Active then Send and Receive will always return False without blocking }
    property  Active: Boolean read FActive;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  { TGObjBlockChannel }

  generic TGObjBlockChannel<T: class> = class(specialize TGBlockChannel<T>)
  strict private
    FOwnsObjects: Boolean;
  strict protected
    procedure CleanupBuffer; override;
  public
    constructor Create(aSize: SizeInt = DEFAULT_CHAN_SIZE; aOwnsObjects: Boolean = True);
    property OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  { TGListenThread: T is the type of message }
  generic TGListenThread<T> = class abstract
  public
  type
  {$PUSH}{$INTERFACES CORBA}
    IThread = interface
    ['{F75F0E98-08B5-4A7A-B431-C2A2383BDD1D}']
      function  GetThreadID: TThreadID;
      function  GetHandle: TThreadID;
      procedure Synchronize(AMethod: TThreadMethod);
      property  ThreadID: TThreadID read GetThreadID;
      property  Handle: TThreadID read GetHandle;
    end;
  {$POP}
  private
  type
    TChannel = specialize TGBlockChannel<T>;

    TWorker = class(TThread, IThread)
    private
      FChannel: TChannel;
      FOwner: TGListenThread;
    protected
      function  GetThreadID: TThreadID;
      function  GetHandle: TThreadID;
      procedure Execute; override;
    public
      constructor Create(aOwner: TGListenThread; aChannel: TChannel);
    end;

  strict private
    FChannel: TChannel;
    FWorker: TWorker;
    function GetCapacity: SizeInt;
    function GetUnhandled: SizeInt;
  protected
    // must be *pure*
    procedure HandleMessage(aThread: IThread; constref aMessage: T); virtual; abstract;
  public
    constructor Create(aCapacity: SizeInt = DEFAULT_CHAN_SIZE);
    destructor Destroy; override;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    procedure Send(constref aMessage: T);
    property  Unhandled: SizeInt read GetUnhandled;
    property  Capacity: SizeInt read GetCapacity;
  end;

implementation
{$B-}{$COPERATORS ON}

{ TAsyncTask }

function TAsyncTask.Cancel: Boolean;
begin
  Result := InterlockedCompareExchange(FState, DWord(tsCancelled), DWord(tsPending)) = DWord(tsPending);
end;

function TAsyncTask.GetState: TState;
begin
  Result := TState(FState);
end;

destructor TAsyncTask.Destroy;
begin
  System.RtlEventDestroy(FAwait);
  FAwait := nil;
  inherited;
end;

procedure TAsyncTask.AfterConstruction;
begin
  inherited;
  FAwait := System.RtlEventCreate;
end;

procedure TAsyncTask.Execute;
begin
  if InterlockedCompareExchange(FState, DWord(tsExecuting), DWord(tsPending)) = DWord(tsPending) then
    begin
      try
        DoExecute;
      except
        on e: Exception do
          FException := Exception(System.AcquireExceptionObject);
      end;
      InterlockedIncrement(FState);
    end;
  System.RtlEventSetEvent(FAwait);
  if State = tsCancelled then
    TThread.Queue(TThread.CurrentThread, @Free);
end;

procedure TAsyncTask.WaitFor;
begin
  if State <> tsCancelled then
    System.RtlEventWaitFor(FAwait);
end;

{ TGFuture }

procedure TGFuture.Resolve;
var
  e: Exception = nil;
begin
  if Assigned(FTask) and (State < fsResolved) then
    try
      FTask.WaitFor;
      e := FTask.FatalException;
      if Assigned(e) then
        FState := fsFatal
      else
        begin
          FState := fsResolved;
          FTaskResult := FTask.Result;
        end;
    finally
      FreeAndNil(FTask);
      if Assigned(e) then
        raise e;
    end;
end;

function TGFuture.GetState: TFutureState;
begin
  if Assigned(FTask) and (FState < fsResolved) then
    try
      case FTask.State of
        tsExecuting: FState := fsExecuting;
        tsFinished:  FState := fsFinished;
      end;
    except
      FState := fsCancelled;
      FTask := nil;
    end;
  Result := FState;
end;

constructor TGFuture.Create(aTask: TTask; aEx: IExecutor);
begin
  inherited Create;
  FTask := aTask;
  if aEx = nil then
    aEx := TDefaultExecutor.GetInstance;
  aEx.EnqueueTask(FTask);
end;

destructor TGFuture.Destroy;
begin
  Cancel;
  WaitFor;
  inherited;
end;

function TGFuture.WaitFor: TFutureState;
begin
  try
    Resolve;
  except
  end;
  Result := FState;
end;

function TGFuture.Cancel: Boolean;
begin
  if Assigned(FTask) and (FState = fsPending) then
    begin
      Result := FTask.Cancel;
      if Result then
        begin
          FState := fsCancelled;
          FTask := nil;
        end;
    end
  else
    Result := False;
end;

function TGFuture.Value: T;
begin
  case State of
    fsPending..fsFinished:
      Resolve;
    fsFatal:
      raise ELGFuture.Create(SEResultUnknownFatal);
    fsCancelled:
      raise ELGFuture.Create(SEResultUnknownCancel);
  end;
  Result := FTaskResult;
end;

function TGFuture.Optional: TOptional;
begin
  if WaitFor = fsResolved then
    Result.Assign(FTaskResult);
end;

{ TGAsyncProc }

procedure TGAsyncProc.DoExecute;
begin
  FProc();
  FResult := FatalException = nil;
end;

class function TGAsyncProc.Call(aProc: TProcedure; aEx: IExecutor): IFuture;
begin
  Result := specialize TGFuture<Boolean>.Create(TGAsyncProc.Create(aProc), aEx);
end;

constructor TGAsyncProc.Create(aProc: TProcedure);
begin
  inherited Create;
  FProc := aProc;
end;

{ TAsyncExecutable }

procedure TAsyncExecutable.DoExecute;
begin
  FTask.Execute;
  FResult := FatalException = nil;
end;

class function TAsyncExecutable.Run(aTask: IExecutable; aEx: IExecutor): IFuture;
begin
  Result := specialize TGFuture<Boolean>.Create(TAsyncExecutable.Create(aTask), aEx);
end;

constructor TAsyncExecutable.Create(aTask: IExecutable);
begin
  inherited Create;
  FTask := aTask;
end;

{ TGAsyncCallable }

procedure TGAsyncCallable.DoExecute;
begin
  FResult := FTask.Call;
end;

class function TGAsyncCallable.Run(aTask: ICallable; aEx: IExecutor): IFuture;
begin
  Result := specialize TGFuture<T>.Create(TGAsyncCallable.Create(aTask), aEx);
end;

constructor TGAsyncCallable.Create(aTask: ICallable);
begin
  inherited Create;
  FTask := aTask;
end;

{ TGAsyncMethod }

procedure TGAsyncMethod.DoExecute;
begin
  FResult := FFun();
end;

class function TGAsyncMethod.Call(aFun: TFun; aEx: IExecutor): IFuture;
begin
  Result := specialize TGFuture<T>.Create(TGAsyncMethod.Create(aFun), aEx);
end;

constructor TGAsyncMethod.Create(aFun: TFun);
begin
  inherited Create;
  FFun := aFun;
end;

{ TGAsyncNested }

procedure TGAsyncNested.DoExecute;
begin
  FResult := FFun();
end;

class function TGAsyncNested.Call(aFun: TFun; aEx: IExecutor): IFuture;
begin
  Result := specialize TGFuture<T>.Create(TGAsyncNested.Create(aFun), aEx);
end;

constructor TGAsyncNested.Create(aFun: TFun);
begin
  inherited Create;
  FFun := aFun;
end;

{ TGAsyncNiladic }

procedure TGAsyncNiladic.DoExecute;
begin
  FResult := FFun();
end;

class function TGAsyncNiladic.Call(aFun: TFun; aEx: IExecutor): IFuture;
begin
  Result := specialize TGFuture<T>.Create(TGAsyncNiladic.Create(aFun), aEx);
end;

constructor TGAsyncNiladic.Create(aFun: TFun);
begin
  inherited Create;
  FFun := aFun;
end;

{ TGAsyncMonadic }

procedure TGAsyncMonadic.DoExecute;
begin
  FResult := FCall.Call;
end;

class function TGAsyncMonadic.Call(aFun: TFun; constref v: T; aEx: IExecutor): IFuture;
begin
  Result := specialize TGFuture<TResult>.Create(TGAsyncMonadic.Create(aFun, v), aEx);
end;

constructor TGAsyncMonadic.Create(aFun: TFun; constref v: T);
begin
  inherited Create;
  FCall := TCall.Create(aFun, v);
end;

{ TGAsyncDyadic }

procedure TGAsyncDyadic.DoExecute;
begin
  FResult := FCall.Call;
end;

class function TGAsyncDyadic.Call(aFun: TFun; constref v1: T1; constref v2: T2; aEx: IExecutor): IFuture;
begin
  Result := specialize TGFuture<TResult>.Create(TGAsyncDyadic.Create(aFun, v1, v2), aEx);
end;

constructor TGAsyncDyadic.Create(aFun: TFun; constref v1: T1; constref v2: T2);
begin
  inherited Create;
  FCall := TCall.Create(aFun, v1, v2);
end;

{ TGAsyncTriadic }

procedure TGAsyncTriadic.DoExecute;
begin
  FResult := FCall.Call;
end;

class function TGAsyncTriadic.Call(aFun: TFun; constref v1: T1; constref v2: T2; constref v3: T3;
  aEx: IExecutor): IFuture;
begin
  Result := specialize TGFuture<TResult>.Create(TGAsyncTriadic.Create(aFun, v1, v2, v3), aEx);
end;

constructor TGAsyncTriadic.Create(aFun: TFun; constref v1: T1; constref v2: T2; constref v3: T3);
begin
  inherited Create;
  FCall := TCall.Create(aFun, v1, v2, v3);
end;

{ TDefaultExecutor.TTaskQueue }

constructor TDefaultExecutor.TTaskQueue.Create;
begin
  inherited;
  System.InitCriticalSection(FLock);
end;

destructor TDefaultExecutor.TTaskQueue.Destroy;
begin
  System.EnterCriticalSection(FLock);
  try
    Finalize(FQueue);
    System.RtlEventDestroy(FReadAwait);
    FReadAwait := nil;
    inherited;
  finally
    System.LeaveCriticalSection(FLock);
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TDefaultExecutor.TTaskQueue.AfterConstruction;
begin
  inherited;
  FReadAwait := System.RtlEventCreate;
end;

procedure TDefaultExecutor.TTaskQueue.Clear;
var
  Task: TAsyncTask;
begin
  System.EnterCriticalSection(FLock);
  try
    for Task in FQueue do
      Task.Cancel;
    FQueue.Clear;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TDefaultExecutor.TTaskQueue.Close;
begin
  System.EnterCriticalSection(FLock);
  try
    FClosed := True;
    System.RtlEventSetEvent(FReadAwait);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TDefaultExecutor.TTaskQueue.Open;
begin
  System.EnterCriticalSection(FLock);
  try
    FClosed := False;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TDefaultExecutor.TTaskQueue.Enqueue(aTask: TAsyncTask);
begin
  System.EnterCriticalSection(FLock);
  try
    FQueue.Enqueue(aTask);
    System.RtlEventSetEvent(FReadAwait);
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TDefaultExecutor.TTaskQueue.Dequeue(out aTask: TAsyncTask): Boolean;
begin
  System.RtlEventWaitFor(FReadAwait);
  System.EnterCriticalSection(FLock);
  try
    if not FClosed then
      begin
        Result := FQueue.TryDequeue(aTask);
        if FQueue.NonEmpty then
         System.RtlEventSetEvent(FReadAwait);
      end
    else
      begin
        Result := False;
        System.RtlEventSetEvent(FReadAwait);
      end;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

{ TDefaultExecutor.TWorkThread }

constructor TDefaultExecutor.TWorkThread.Create(aQueue: TTaskQueue);
begin
  inherited Create(True);
  FQueue := aQueue;
end;

procedure TDefaultExecutor.TWorkThread.Execute;
var
  CurrTask: TAsyncTask;
begin
  while not Terminated do
    if FQueue.Dequeue(CurrTask) then
      CurrTask.Execute;
end;

{ TDefaultExecutor.TExecutor }

function TDefaultExecutor.TExecutor.ThreadCount: Integer;
begin
  Result := FThreadPool.Count;
end;

function TDefaultExecutor.TExecutor.AddThread: TWorkThread;
begin
  Result := TWorkThread.Create(FTaskQueue);
  FThreadPool.Add(Result);
  Result.Start;
end;

procedure TDefaultExecutor.TExecutor.PoolGrow(aValue: Integer);
begin
  while FThreadPool.Count < aValue do
    AddThread;
end;

procedure TDefaultExecutor.TExecutor.PoolShrink(aValue: Integer);
begin
  if aValue < 1 then
    aValue := 1;
  TerminatePool;
  FTaskQueue.Open;
  PoolGrow(aValue);
end;

procedure TDefaultExecutor.TExecutor.EnqueueTask(aTask: TAsyncTask);
begin
  FTaskQueue.Enqueue(aTask);
end;

procedure TDefaultExecutor.TExecutor.TerminatePool;
var
  CurrThread: TWorkThread;
begin
  for CurrThread in FThreadPool.Reverse do
    CurrThread.Terminate;
  FTaskQueue.Close;
  while FThreadPool.Count > 0 do
    begin
      CurrThread := FThreadPool.Extract(Pred(FThreadPool.Count));
      CurrThread.WaitFor;
      CurrThread.Free;
    end;
end;

procedure TDefaultExecutor.TExecutor.FinalizePool;
begin
  TerminatePool;
  FThreadPool.Clear;
end;

constructor TDefaultExecutor.TExecutor.Create;
begin
  if TThread.ProcessorCount > DEFAULT_POOL_SIZE then
    Create(TThread.ProcessorCount)
  else
    Create(DEFAULT_POOL_SIZE);
end;

constructor TDefaultExecutor.TExecutor.Create(aThreadCount: Integer);
begin
  FTaskQueue := TTaskQueue.Create;
  if aThreadCount > 0 then
    PoolGrow(aThreadCount)
  else
    PoolGrow(1);
end;

destructor TDefaultExecutor.TExecutor.Destroy;
begin
  FTaskQueue.Clear;
  FinalizePool;
  FTaskQueue.Free;
  inherited;
end;

{ TDefaultExecutor }

class constructor TDefaultExecutor.InitNil;
begin
  CFExecutor := nil;
end;

class destructor TDefaultExecutor.DoneQueue;
begin
  FreeAndNil(CFExecutor);
end;

class function TDefaultExecutor.GetThreadCount: Integer;
begin
  if Assigned(CFExecutor) then
    Result := CFExecutor.ThreadCount
  else
    Result := 0;
end;

class procedure TDefaultExecutor.SetThreadCount(aValue: Integer);
begin
  if (aValue > ThreadCount) or not Assigned(CFExecutor) then
    EnsureThreadCount(aValue)
  else
    if aValue > 0 then
      CFExecutor.PoolShrink(aValue);
end;

class procedure TDefaultExecutor.EnsureThreadCount(aValue: Integer);
begin
  if aValue > ThreadCount then
    if not Assigned(CFExecutor) then
      CFExecutor := TExecutor.Create(aValue)
    else
      CFExecutor.PoolGrow(aValue);
end;

class procedure TDefaultExecutor.Enqueue(aTask: TAsyncTask);
begin
  if not Assigned(CFExecutor) then
    CFExecutor := TExecutor.Create;
  CFExecutor.EnqueueTask(aTask);
end;

class function TDefaultExecutor.GetInstance: IExecutor;
begin
  if not Assigned(CFExecutor) then
    CFExecutor := TExecutor.Create;
  Result := CFExecutor;
end;

{ TGBlockChannel }

function TGBlockChannel.GetCapacity: SizeInt;
begin
  Result := System.Length(FBuffer);
end;

procedure TGBlockChannel.SendData(constref aValue: T);
begin
  Enqueue(aValue);
  System.RtlEventSetEvent(FReadAwait);
  if Count < Capacity then
    System.RtlEventSetEvent(FWriteAwait);
end;

function TGBlockChannel.ReceiveData: T;
begin
  Result := Dequeue;
  System.RtlEventSetEvent(FWriteAwait);
  if Count > 0 then
    System.RtlEventSetEvent(FReadAwait);
end;

function TGBlockChannel.TailIndex: SizeInt;
begin
  Result := Head + Count;
  if Result >= Capacity then
    Result -= Capacity;
end;

procedure TGBlockChannel.Enqueue(constref aValue: T);
begin
  if Count >= Capacity then
    Panic;
  FBuffer[TailIndex] := aValue;
  Inc(FCount);
end;

function TGBlockChannel.Dequeue: T;
begin
  if Count = 0 then
    Panic;
  Result := FBuffer[Head];
  FBuffer[Head] := Default(T);
  Inc(FHead);
  Dec(FCount);
  if Head = Capacity then
    FHead := 0;
end;

procedure TGBlockChannel.Panic;
begin
  raise ELGPanic.Create(SEInternalDataInconsist);
end;

procedure TGBlockChannel.CleanupBuffer;
var
  I: SizeInt;
begin
  for I := 0 to Pred(Count) do
    FBuffer[I] := Default(T);
end;

constructor TGBlockChannel.Create(aCapacity: SizeInt);
begin
  if aCapacity > 0 then
    begin
      System.SetLength(FBuffer, aCapacity);
      System.InitCriticalSection(FLock);
      FActive := True;
    end
  else
    raise ELGPanic.CreateFmt(SEInvalidInputFmt, ['aSize', IntToStr(aCapacity)]);
end;

destructor TGBlockChannel.Destroy;
begin
  Close;
  System.EnterCriticalSection(FLock);
  try
    CleanupBuffer;
    System.RtlEventDestroy(FWriteAwait);
    FWriteAwait := nil;
    System.RtlEventDestroy(FReadAwait);
    FReadAwait := nil;
    inherited;
  finally
    System.LeaveCriticalSection(FLock);
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGBlockChannel.AfterConstruction;
begin
  inherited;
  FWriteAwait := System.RtlEventCreate;
  FReadAwait  := System.RtlEventCreate;
  System.RtlEventSetEvent(FWriteAwait);
end;

function TGBlockChannel.Send(constref aValue: T): Boolean;
begin
  System.RtlEventWaitFor(FWriteAwait);
  System.EnterCriticalSection(FLock);
  try
    if Active then
      begin
        Result := Count < Capacity;
        if Result then
          SendData(aValue);
      end
    else
      begin
        Result := False;
        System.RtlEventSetEvent(FWriteAwait);
      end;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

function TGBlockChannel.Receive(out aValue: T): Boolean;
begin
  System.RtlEventWaitFor(FReadAwait);
  System.EnterCriticalSection(FLock);
  try
    if Active then
      begin
        Result := Count > 0;
        if Result then
          aValue := ReceiveData;
      end
    else
      begin
        Result := False;
        System.RtlEventSetEvent(FReadAwait);
      end;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TGBlockChannel.Close;
begin
  System.EnterCriticalSection(FLock);
  try
    if Active then
      begin
        FActive := False;
        System.RtlEventSetEvent(FReadAwait);
        System.RtlEventSetEvent(FWriteAwait);
      end;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

procedure TGBlockChannel.Open;
begin
  System.EnterCriticalSection(FLock);
  try
    if not Active then
      begin
        FActive := True;
        if Count > 0 then
          System.RtlEventSetEvent(FReadAwait);
        if Count < Capacity then
          System.RtlEventSetEvent(FWriteAwait);
      end;
  finally
    System.LeaveCriticalSection(FLock);
  end;
end;

{ TGObjBlockChannel }

procedure TGObjBlockChannel.CleanupBuffer;
var
  I: Integer;
begin
  if OwnsObjects then
    for I := 0 to Pred(Count) do
      FBuffer[I].Free;
end;

constructor TGObjBlockChannel.Create(aSize: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aSize);
  FOwnsObjects := aOwnsObjects;
end;

{ TGListenThread.TWorker }

function TGListenThread.TWorker.GetThreadID: TThreadID;
begin
  Result := ThreadID;
end;

function TGListenThread.TWorker.GetHandle: TThreadID;
begin
  Result := Handle;
end;

procedure TGListenThread.TWorker.Execute;
var
  Message: T;
begin
  while not Terminated and FChannel.Receive(Message) do
    FOwner.HandleMessage(Self, Message);
end;

constructor TGListenThread.TWorker.Create(aOwner: TGListenThread; aChannel: TChannel);
begin
  inherited Create(True);
  FOwner := aOwner;
  FChannel := aChannel;
  FreeOnTerminate := True;
end;


{ TGListenThread }

function TGListenThread.GetCapacity: SizeInt;
begin
  Result := FChannel.Capacity;
end;

function TGListenThread.GetUnhandled: SizeInt;
begin
  Result := FChannel.Count;
end;

constructor TGListenThread.Create(aCapacity: SizeInt);
begin
  FChannel := TChannel.Create(aCapacity);
  FWorker := TWorker.Create(Self, FChannel);
end;

destructor TGListenThread.Destroy;
begin
  FChannel.Free;
  inherited;
end;

procedure TGListenThread.AfterConstruction;
begin
  inherited;
  FWorker.Start;
end;

procedure TGListenThread.BeforeDestruction;
begin
  FWorker.Terminate;
  FChannel.Close;
  inherited;
end;

procedure TGListenThread.Send(constref aMessage: T);
begin
  FChannel.Send(aMessage);
end;

end.

