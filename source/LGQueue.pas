{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic queue implementations.                                          *
*                                                                           *
*   Copyright(c) 2018 A.Koverdyaev(avk)                                     *
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
unit LGQueue;

{$mode objfpc}{$H+}
{$INLINE ON}{$WARN 6058 off : }
{$MODESWITCH ADVANCEDRECORDS}

interface

uses
  SysUtils,
  LGUtils,
  LGCustomContainer;

type

  generic TGQueue<T> = class(specialize TGCustomRingArrayBuffer<T>, specialize IGContainer<T>,
    specialize IGQueue<T>)
  public
    procedure Enqueue(constref aValue: T); inline;
    function  EnqueueAll(constref a: array of T): SizeInt;
    function  EnqueueAll(e: IEnumerable): SizeInt; inline;
  { EXTRACTS element from the head of queue }
    function  Dequeue: T; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  Peek: T; inline;
    function  TryPeek(out aValue: T): Boolean; inline;
  end;

  { TGObjectQueue note:
    TGObjectQueue.Dequeue(or TGObjectQueue.TryDequeue) EXTRACTS object from queue;
    you need to free this object yourself }
  generic TGObjectQueue<T: class> = class(specialize TGQueue<T>)
  private
    FOwnsObjects: Boolean;
  protected
    procedure DoClear; override;
  public
    constructor Create(aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aOwnsObjects: Boolean = True);
    constructor Create(constref A: array of T; aOwnsObjects: Boolean = True);
    constructor Create(e: IEnumerable; aOwnsObjects: Boolean = True);
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGThreadQueue<T> = class
  public
  type
    IQueue = specialize IGQueue<T>;

  private
    FQueue: IQueue;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create(aQueue: IQueue);
    destructor Destroy; override;
    procedure Clear;
    procedure Enqueue(constref aValue: T);
    function  TryDequeue(out aValue: T): Boolean;
    function  TryPeek(out aValue: T): Boolean;
    function  Lock: IQueue;
    procedure Unlock; inline;
  end;

  generic TGLiteQueue<T> = record
  type
    TBuffer     = specialize TGLiteRingDynBuffer<T>;
    TEnumerator = TBuffer.TEnumerator;
    TMutables   = TBuffer.TMutables;
    TReverse    = TBuffer.TReverse;
    PItem       = TBuffer.PItem;
    TArray      = TBuffer.TArray;

  private
    FBuffer: TBuffer;
    function  GetCapacity: SizeInt; inline;
  public
    function  GetEnumerator: TEnumerator; inline;
    function  Mutables: TMutables; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    procedure MakeEmpty; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    procedure Enqueue(constref aValue: T); inline;
  { EXTRACTS element from the head of queue }
    function  Dequeue: T; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  Peek: T; inline;
    function  TryPeek(out aValue: T): Boolean; inline;
    property  Count: SizeInt read FBuffer.FCount;
    property  Capacity: SizeInt read GetCapacity;
  end;

  generic TGLiteThreadQueue<T> = class
  public
  type
    TQueue = specialize TGLiteQueue<T>;
    PQueue = ^TQueue;

  strict private
    FQueue: TQueue;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Enqueue(constref aValue: T);
    function  TryDequeue(out aValue: T): Boolean;
    function  TryPeek(out aValue: T): Boolean;
    function  Lock: PQueue;
    procedure Unlock; inline;
  end;

  generic TGLiteWaitableQueue<T> = class
  public
  type
    TQueue = specialize TGLiteQueue<T>;

  strict private
    FQueue: TQueue;
    FLock: TRTLCriticalSection;
    FReadAwait: PRtlEvent;
    procedure Lock; inline;
    procedure UnLock; inline;
    procedure Signaled; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    procedure Clear;
    procedure Enqueue(constref aValue: T);
    function  Dequeue: T;
    function  TryDequeue(out aValue: T): Boolean;
    function  Peek: T;
    function  TryPeek(out aValue: T): Boolean;
  end;

  generic TGLiteObjectQueue<T: class> = record
  strict private
  type
    TQueue      = specialize TGLiteQueue<T>;
    TEnumerator = TQueue.TEnumerator;
    TReverse    = TQueue.TReverse;
    TArray      = TQueue.TArray;

  var
    FQueue: TQueue;
    FOwnsObjects: Boolean;
    function  GetCapacity: SizeInt; inline;
    function  GetCount: SizeInt; inline;
    procedure CheckFreeItems;
    class operator Initialize(var q: TGLiteObjectQueue);
    class operator Finalize(var q: TGLiteObjectQueue);
    class operator Copy(constref aSrc: TGLiteObjectQueue; var aDst: TGLiteObjectQueue);
  public
    function  GetEnumerator: TEnumerator; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    procedure Enqueue(constref aValue: T);
  { EXTRACTS element from the head of queue }
    function  Dequeue: T; inline;
    function  TryDequeue(out aValue: T): Boolean; inline;
    function  Peek: T; inline;
    function  TryPeek(out aValue: T): Boolean; inline;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGLiteThreadObjectQueue<T: class> = class
  public
  type
    TQueue = specialize TGLiteObjectQueue<T>;
    PQueue = ^TQueue;

  private
    FQueue: TQueue;
    FLock: TRTLCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Enqueue(constref aValue: T);
    function  TryDequeue(out aValue: T): Boolean;
    function  TryPeek(out aValue: T): Boolean;
    function  Lock: PQueue;
    procedure Unlock; inline;
  end;

implementation
{$B-}{$COPERATORS ON}

{ TGQueue }

procedure TGQueue.Enqueue(constref aValue: T);
begin
  CheckInIteration;
  Append(aValue);
end;

function TGQueue.EnqueueAll(constref a: array of T): SizeInt;
begin
  CheckInIteration;
  Result := AppendArray(a);
end;

function TGQueue.EnqueueAll(e: IEnumerable): SizeInt;
begin
  CheckInIteration;
  Result := AppendEnumerable(e);
end;

function TGQueue.Dequeue: T;
begin
  CheckInIteration;
  CheckEmpty;
  Result := ExtractHead;
end;

function TGQueue.TryDequeue(out aValue: T): Boolean;
begin
  Result := not InIteration and (ElemCount > 0);
  if Result then
    aValue := ExtractHead;
end;

function TGQueue.Peek: T;
begin
  CheckEmpty;
  Result := FItems[Head];
end;

function TGQueue.TryPeek(out aValue: T): Boolean;
begin
  Result := ElemCount > 0;
  if Result then
    aValue := FItems[Head];
end;

{ TGObjectQueue }

procedure TGObjectQueue.DoClear;
var
  I, CurrIdx, c: SizeInt;
begin
  if OwnsObjects and (ElemCount > 0) then
    begin
      CurrIdx := Head;
      c := Capacity;
      for I := 1 to ElemCount do
        begin
          FItems[CurrIdx].Free;
          Inc(CurrIdx);
          if CurrIdx = c then
            CurrIdx := 0;
        end;
    end;
  inherited;
end;

constructor TGObjectQueue.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectQueue.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectQueue.Create(constref A: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(A);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectQueue.Create(e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(e);
  FOwnsObjects := aOwnsObjects;
end;

{ TGThreadQueue }

procedure TGThreadQueue.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGThreadQueue.Create(aQueue: IQueue);
begin
  System.InitCriticalSection(FLock);
  FQueue := aQueue;
end;

destructor TGThreadQueue.Destroy;
begin
  DoLock;
  try
    FQueue._GetRef.Free;
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGThreadQueue.Clear;
begin
  DoLock;
  try
    FQueue.Clear;
  finally
    UnLock;
  end;
end;

procedure TGThreadQueue.Enqueue(constref aValue: T);
begin
  DoLock;
  try
    FQueue.Enqueue(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadQueue.TryDequeue(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryDequeue(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadQueue.TryPeek(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryPeek(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadQueue.Lock: IQueue;
begin
  Result := FQueue;
  DoLock;
end;

procedure TGThreadQueue.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

{ TGLiteQueue }

function TGLiteQueue.GetCapacity: SizeInt;
begin
  Result := FBuffer.Capacity;
end;

function TGLiteQueue.GetEnumerator: TEnumerator;
begin
  Result := FBuffer.GetEnumerator;
end;

function TGLiteQueue.Mutables: TMutables;
begin
  Result := FBuffer.Mutables;
end;

function TGLiteQueue.Reverse: TReverse;
begin
  Result := FBuffer.Reverse;
end;

function TGLiteQueue.ToArray: TArray;
begin
  Result := FBuffer.ToArray;
end;

procedure TGLiteQueue.Clear;
begin
  FBuffer.Clear;
end;

procedure TGLiteQueue.MakeEmpty;
begin
  FBuffer.MakeEmpty;
end;

function TGLiteQueue.IsEmpty: Boolean;
begin
  Result := FBuffer.Count = 0;
end;

function TGLiteQueue.NonEmpty: Boolean;
begin
  Result := FBuffer.Count <> 0;
end;

procedure TGLiteQueue.EnsureCapacity(aValue: SizeInt);
begin
  FBuffer.EnsureCapacity(aValue);
end;

procedure TGLiteQueue.TrimToFit;
begin
  FBuffer.TrimToFit;
end;

procedure TGLiteQueue.Enqueue(constref aValue: T);
begin
  FBuffer.PushLast(aValue);
end;

function TGLiteQueue.Dequeue: T;
begin
  Result := FBuffer.PopFirst;
end;

function TGLiteQueue.TryDequeue(out aValue: T): Boolean;
begin
  Result := FBuffer.TryPopFirst(aValue);
end;

function TGLiteQueue.Peek: T;
begin
  Result := FBuffer.PeekFirst;
end;

function TGLiteQueue.TryPeek(out aValue: T): Boolean;
begin
  Result := FBuffer.TryPeekFirst(aValue);
end;

{ TGLiteThreadQueue }

procedure TGLiteThreadQueue.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGLiteThreadQueue.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteThreadQueue.Destroy;
begin
  DoLock;
  try
    Finalize(FQueue);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGLiteThreadQueue.Clear;
begin
  DoLock;
  try
    FQueue.Clear;
  finally
    UnLock;
  end;
end;

procedure TGLiteThreadQueue.Enqueue(constref aValue: T);
begin
  DoLock;
  try
    FQueue.Enqueue(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadQueue.TryDequeue(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryDequeue(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadQueue.TryPeek(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryPeek(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadQueue.Lock: PQueue;
begin
  Result := @FQueue;
  DoLock;
end;

procedure TGLiteThreadQueue.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

{ TGLiteWaitableQueue }

procedure TGLiteWaitableQueue.Lock;
begin
  System.EnterCriticalSection(FLock);
end;

procedure TGLiteWaitableQueue.UnLock;
begin
  System.LeaveCriticalSection(FLock);
end;

procedure TGLiteWaitableQueue.Signaled;
begin
  System.RtlEventSetEvent(FReadAwait);
end;

constructor TGLiteWaitableQueue.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteWaitableQueue.Destroy;
begin
  Lock;
  try
    System.RtlEventDestroy(FReadAwait);
    FReadAwait := nil;
    Finalize(FQueue);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGLiteWaitableQueue.AfterConstruction;
begin
  inherited;
  FReadAwait  := System.RtlEventCreate;
end;

procedure TGLiteWaitableQueue.Clear;
begin
  Lock;
  try
    FQueue.Clear;
  finally
    UnLock;
  end;
end;

procedure TGLiteWaitableQueue.Enqueue(constref aValue: T);
begin
  Lock;
  try
    FQueue.Enqueue(aValue);
    Signaled;
  finally
    UnLock;
  end;
end;

function TGLiteWaitableQueue.Dequeue: T;
begin
  System.RtlEventWaitFor(FReadAwait);
  Lock;
  try
    Result := FQueue.Dequeue;
    if FQueue.NonEmpty then
      Signaled;
  finally
    UnLock;
  end;
end;

function TGLiteWaitableQueue.TryDequeue(out aValue: T): Boolean;
begin
  Lock;
  try
    Result := FQueue.TryDequeue(aValue);
    if FQueue.NonEmpty then
      Signaled;
  finally
    UnLock;
  end;
end;

function TGLiteWaitableQueue.Peek: T;
begin
  System.RtlEventWaitFor(FReadAwait);
  Lock;
  try
    Result := FQueue.Peek;
    if FQueue.NonEmpty then
      Signaled;
  finally
    UnLock;
  end;
end;

function TGLiteWaitableQueue.TryPeek(out aValue: T): Boolean;
begin
  Lock;
  try
    Result := FQueue.TryPeek(aValue);
  finally
    UnLock;
  end;
end;

{ TGLiteObjectQueue }

function TGLiteObjectQueue.GetCapacity: SizeInt;
begin
  Result := FQueue.Capacity;
end;

function TGLiteObjectQueue.GetCount: SizeInt;
begin
  Result := FQueue.Count;
end;

procedure TGLiteObjectQueue.CheckFreeItems;
var
  v: T;
begin
  if OwnsObjects and (Count > 0) then
    for v in FQueue do
      v.Free;
end;

class operator TGLiteObjectQueue.Initialize(var q: TGLiteObjectQueue);
begin
  q.FOwnsObjects := True;
end;

class operator TGLiteObjectQueue.Finalize(var q: TGLiteObjectQueue);
begin
  q.Clear;
end;

class operator TGLiteObjectQueue.Copy(constref aSrc: TGLiteObjectQueue; var aDst: TGLiteObjectQueue);
begin
  if @aDst = @aSrc then
    exit;
  aDst.CheckFreeItems;
  aDst.FQueue := aSrc.FQueue;
  aDst.FOwnsObjects := aSrc.OwnsObjects;
end;

function TGLiteObjectQueue.GetEnumerator: TEnumerator;
begin
  Result := FQueue.GetEnumerator;
end;

function TGLiteObjectQueue.Reverse: TReverse;
begin
  Result := FQueue.Reverse;
end;

function TGLiteObjectQueue.ToArray: TArray;
begin
  Result := FQueue.ToArray;
end;

procedure TGLiteObjectQueue.Clear;
begin
  CheckFreeItems;
  FQueue.Clear;
end;

function TGLiteObjectQueue.IsEmpty: Boolean;
begin
  Result := FQueue.IsEmpty;
end;

function TGLiteObjectQueue.NonEmpty: Boolean;
begin
  Result := FQueue.NonEmpty;
end;

procedure TGLiteObjectQueue.EnsureCapacity(aValue: SizeInt);
begin
  FQueue.EnsureCapacity(aValue);
end;

procedure TGLiteObjectQueue.TrimToFit;
begin
  FQueue.TrimToFit;
end;

procedure TGLiteObjectQueue.Enqueue(constref aValue: T);
begin
  FQueue.Enqueue(aValue);
end;

function TGLiteObjectQueue.Dequeue: T;
begin
  Result := FQueue.Dequeue;
end;

function TGLiteObjectQueue.TryDequeue(out aValue: T): Boolean;
begin
  Result := FQueue.TryDequeue(aValue);
end;

function TGLiteObjectQueue.Peek: T;
begin
  Result := FQueue.Peek;
end;

function TGLiteObjectQueue.TryPeek(out aValue: T): Boolean;
begin
  Result := FQueue.TryPeek(aValue);
end;

{ TGLiteThreadObjectQueue }

procedure TGLiteThreadObjectQueue.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGLiteThreadObjectQueue.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteThreadObjectQueue.Destroy;
begin
  DoLock;
  try
    Finalize(FQueue);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGLiteThreadObjectQueue.Clear;
begin
  DoLock;
  try
    FQueue.Clear;
  finally
    UnLock;
  end;
end;

procedure TGLiteThreadObjectQueue.Enqueue(constref aValue: T);
begin
  DoLock;
  try
    FQueue.Enqueue(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectQueue.TryDequeue(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryDequeue(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectQueue.TryPeek(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FQueue.TryPeek(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectQueue.Lock: PQueue;
begin
  Result := @FQueue;
  DoLock;
end;

procedure TGLiteThreadObjectQueue.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

end.

