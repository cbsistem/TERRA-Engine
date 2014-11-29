Unit TERRA_SceneManager;

{$I terra.inc}

Interface
Uses TERRA_Utils, TERRA_Mesh, TERRA_Matrix, TERRA_Vector3D, TERRA_Vector2D,
  TERRA_BoundingBox, TERRA_Math, TERRA_GraphicsManager, TERRA_Ray, TERRA_Lights,
  TERRA_FileIO, TERRA_IO;

Type
  SceneNode = Class;

  SceneProperty = Record
    Internal:Boolean;
    Key:AnsiString;
    Value:AnsiString;
  End;

  SceneNode = Class
    Protected
      _Name:AnsiString;

      _Parent:SceneNode;

      _Childs:Array Of SceneNode;
      _ChildCount:Integer;

      _Properties:Array Of SceneProperty;
      _PropertyCount:Integer;

      _Position:Vector3D;
      _Rotation:Vector3D;
      _Scale:Vector3D;
      _Static:Boolean;
      _Transform:Matrix;

      Function SameKey(A,B:AnsiString):Boolean;
      Procedure OnPropertyChange(Key, Value:AnsiString); Virtual;

      Function FindNode(Name:AnsiString):SceneNode;
      Function GetBaseNode():SceneNode;

      Procedure Save(Dest:Stream; Tabs:Integer);

    Public
      AutoSnap:Single;

      Constructor Create(Parent:SceneNode; Pos:Vector3D);
      Destructor Destroy;

      Procedure AddChild(N:SceneNode);
      Procedure RemoveChild(N:SceneNode);

      Procedure SetPosition(P:Vector3D);
      Procedure SetRotation(P:Vector3D);
      Procedure SetScale(P:Vector3D);

      Procedure SetName(S:AnsiString);
      Procedure SetParent(Parent:SceneNode);

      Function GetProperty(Key:AnsiString):AnsiString; Overload;
      Procedure AddProperty(Key, Value:AnsiString; Internal:Boolean = False);
      Procedure SetProperty(Key, Value:AnsiString);

      Function GetPropertyName(Index:Integer):AnsiString; Overload;
      Function GetPropertyValue(Index:Integer):AnsiString; Overload;
      Function IsCustomProperty(Index:Integer):Boolean;

      Procedure DeleteProperty(Key:AnsiString); Overload;
      Procedure DeleteProperty(Index:Integer); Overload;

      Function GetBoundingBox:BoundingBox; Virtual;
      Function GetEditorPick(R:Ray; X,Y:Integer):SceneNode; Virtual;

      Procedure Render(); Virtual;

      Property Name:AnsiString Read _Name Write SetName;
      Property Parent:SceneNode Read _Parent Write SetParent;
      Property Position:Vector3D Read _Position Write SetPosition;
      Property Rotation:Vector3D Read _Rotation Write SetRotation;
      Property Scale:Vector3D Read _Scale Write SetScale;
      Property Static:Boolean Read _Static;
      Property PropertyCount:Integer Read _PropertyCount;
  End;

  SceneMesh = Class (SceneNode)
    Protected
      _Instance:MeshInstance;

      Procedure OnPropertyChange(Key, Value:AnsiString); Override;

    Public
      Constructor Create(Parent:SceneNode; Pos:Vector3D; MyMesh:Mesh);

      Function GetBoundingBox:BoundingBox; Override;
      Function GetEditorPick(R:Ray; X,Y:Integer):SceneNode; Override;

      Procedure Render(); Override;
  End;

  SceneOccluder = Class (SceneNode)
    Protected
      _Occluder:Occluder;

    Public

      Procedure Render(); Override;
  End;

Procedure SaveNodes(Node:SceneNode; Dest:Stream); Overload;
Procedure SaveNodes(Node:SceneNode; FileName:AnsiString); Overload;

Var
  AutoSnap:Single = 1;

Implementation
Uses TERRA_FileUtils;

Procedure SaveNodes(Node:SceneNode; Dest:Stream);
Begin
  Node.Save(Dest, 0);
End;

Procedure SaveNodes(Node:SceneNode; FileName:AnsiString);
Var
  S:Stream;
Begin
  S := FileStream.Create(FileName);
  SaveNodes(Node, S);
  S.Destroy;
End;


{ SceneNode }
Constructor SceneNode.Create(Parent:SceneNode; Pos:Vector3D);
Var
  ParentName:AnsiString;
Begin
  If Assigned(Parent) Then
  Begin
    Parent.AddChild(Self);
    ParentName := Parent.Name;
  End Else
    ParentName := '';

  _Parent := Parent;
  _ChildCount := 0;
  _Name := Self.ClassName;

  _Position := Pos;
  _Rotation := VectorZero;
  _Scale := VectorUniform(1.0);

  AddProperty('name', _Name, True);
  AddProperty('parent', ParentName, True);
  AddProperty('posX', FloatToString(Pos.X), True);
  AddProperty('posY', FloatToString(Pos.Y), True);
  AddProperty('posZ', FloatToString(Pos.Z), True);
  AddProperty('rotX', '0', True);
  AddProperty('rotY', '0', True);
  AddProperty('rotZ', '0', True);
  AddProperty('scaleX', '1', True);
  AddProperty('scaleY', '1', True);
  AddProperty('scaleZ', '1', True);
End;

Destructor SceneNode.Destroy;
Var
  I:Integer;
Begin
  For I:=0 To Pred(_ChildCount) Do
    _Childs[I].Destroy;
End;

Procedure SceneNode.AddChild(N: SceneNode);
Var
  I:Integer;
Begin
  For I:=0 To Pred(_ChildCount) Do
  If (_Childs[I] = N) Then
    Exit;

  Inc(_ChildCount);
  SetLength(_Childs, _ChildCount);
  _Childs[Pred(_ChildCount)] := N;
End;

Procedure SceneNode.RemoveChild(N: SceneNode);
Var
  I:Integer;
Begin
  I:=0;
  While (I<_ChildCount) Do
  If (_Childs[I] = N) Then
  Begin
    _Childs[I] := _Childs[Pred(_ChildCount)];
    Dec(_ChildCount);
    N.Destroy;
    Exit;
  End Else
    Inc(I);
End;

Procedure SceneNode.Render;
Var
  I:Integer;
Begin
  _Transform := MatrixTransform(_Position, _Rotation, _Scale);
  If Assigned(_Parent) Then
    _Transform := MatrixMultiply4x4(_Parent._Transform, _Transform);

  If (AutoSnap>0) Then
  Begin
    For I:=12 To 14 Do
      _Transform.V[I] := Trunc(_Transform.V[I] / AutoSnap) * AutoSnap;
  End;

  For I:=0 To Pred(_ChildCount) Do
    _Childs[I].Render();
End;

Procedure SceneNode.SetPosition(P: Vector3D);
Begin
  SetProperty('posX', FloatToString(P.X));
  SetProperty('posY', FloatToString(P.Y));
  SetProperty('posZ', FloatToString(P.Z));
  _Position := P;
End;

Procedure SceneNode.SetRotation(P: Vector3D);
Begin
  SetProperty('rotX', FloatToString(P.X));
  SetProperty('rotY', FloatToString(P.Y));
  SetProperty('rotZ', FloatToString(P.Z));
  _Rotation := P;
End;

Procedure SceneNode.SetScale(P: Vector3D);
Begin
  SetProperty('scaleX', FloatToString(P.X));
  SetProperty('scaleY', FloatToString(P.Y));
  SetProperty('scaleZ', FloatToString(P.Z));
  _Scale := P;
End;

Procedure SceneNode.OnPropertyChange(Key, Value:AnsiString);
Begin
  Key := UpStr(Key);

  If (SameKey(Key, 'name')) Then
  Begin
    _Name := Value;
  End Else
  If (SameKey(Key, 'parent')) Then
  Begin
    _Parent := Self.GetBaseNode().FindNode(Value);
  End Else
  If (SameKey(Key, 'posX')) Then
  Begin
    _Position.X := StringToFloat(Value);
  End Else
  If (SameKey(Key, 'posY')) Then
  Begin
    _Position.Y := StringToFloat(Value);
  End Else
  If (SameKey(Key, 'posZ')) Then
  Begin
    _Position.Z := StringToFloat(Value);
  End Else
  If (SameKey(Key, 'rotX')) Then
  Begin
    _Rotation.X := StringToFloat(Value);
  End Else
  If (SameKey(Key, 'rotY')) Then
  Begin
    _Rotation.Y := StringToFloat(Value);
  End Else
  If (SameKey(Key, 'rotZ')) Then
  Begin
    _Rotation.Z := StringToFloat(Value);
  End Else
  If (SameKey(Key, 'scaleX')) Then
  Begin
    _Scale.X := StringToFloat(Value);
  End Else
  If (SameKey(Key, 'scaleY')) Then
  Begin
    _Scale.Y := StringToFloat(Value);
  End Else
  If (SameKey(Key, 'scaleZ')) Then
  Begin
    _Scale.Z := StringToFloat(Value);
  End;
End;

Procedure SceneNode.AddProperty(Key, Value:AnsiString; Internal: Boolean);
Var
  I:Integer;
Begin
  For I:=0 To Pred(Self._PropertyCount) Do
  If (UpStr(_Properties[I].Key) = UpStr(Key)) Then
    Exit;

  Inc(_PropertyCount);
  SetLength(_Properties, _PropertyCount);
  _Properties[Pred(_PropertyCount)].Key := Key;
  _Properties[Pred(_PropertyCount)].Value := Value;
  _Properties[Pred(_PropertyCount)].Internal := Internal;
End;

Function SceneNode.GetProperty(Key:AnsiString):AnsiString;
Var
  I:Integer;
Begin
  Key := UpStr(Key);
  For I:=0 To Pred(Self._PropertyCount) Do
  If (UpStr(_Properties[I].Key) = Key) Then
  Begin
    Result := _Properties[I].Value;
    Exit;
  End;

  Result := '';
End;

Function SceneNode.GetPropertyName(Index: Integer):AnsiString;
Begin
  Result := _Properties[Index].Key;
End;

Function SceneNode.GetPropertyValue(Index: Integer):AnsiString;
Begin
  Result := _Properties[Index].Value;
End;

Procedure SceneNode.SetProperty(Key, Value:AnsiString);
Var
  I:Integer;
Begin
  Key := UpStr(Key);
  For I:=0 To Pred(Self._PropertyCount) Do
  If (UpStr(_Properties[I].Key) = Key) Then
  Begin
    _Properties[I].Value := Value;
    Self.OnPropertyChange(Key, Value);
    Exit;
  End;

  AddProperty(Key, Value);
End;

Procedure SceneNode.SetName(S:AnsiString);
Begin
  _Name := S;
  SetProperty('name', S);
End;

Procedure SceneNode.SetParent(Parent: SceneNode);
Var
  S:AnsiString;
Begin
  If Assigned(Parent) Then
    S := Parent.Name
  Else
    S := '';

  _Parent := Parent;
  SetProperty('parent', S);
End;

Function SceneNode.SameKey(A, B:AnsiString): Boolean;
Begin
  Result := UpStr(A) = UpStr(B);
End;

Function SceneNode.FindNode(Name:AnsiString): SceneNode;
Var
  I:Integer;
Begin
  Name := UpStr(Name);
  For I:=0 To Pred(_ChildCount) Do
  If (UpStr(_Childs[I].Name) = Name) Then
  Begin
    Result := _Childs[I];
    Exit;
  End;

  For I:=0 To Pred(_ChildCount) Do
  Begin
    Result := _Childs[I].FindNode(Name);
    If Assigned(Result) Then
      Exit;
  End;

  Result := Nil;
End;

Function SceneNode.GetBaseNode: SceneNode;
Begin
  If Assigned(_Parent) Then
    Result := _Parent.GetBaseNode()
  Else
    Result := Self;
End;

Function SceneNode.GetBoundingBox: BoundingBox;
Begin
  Result.StartVertex := VectorAdd(_Position, VectorCreate(-10, -10, -10));
  Result.EndVertex := VectorAdd(_Position, VectorCreate(10, 10, 10));
End;

Function SceneNode.GetEditorPick(R: Ray; X, Y: Integer): SceneNode;
Var
  I:Integer;
Begin
  For I:=0 To Pred(_ChildCount) Do
  Begin
    Result := _Childs[I].GetEditorPick(R, X, Y);
    If Assigned(Result) Then
      Exit;
  End;

  Result := Nil;
End;

Procedure SceneNode.Save(Dest: Stream; Tabs:Integer);
Var
  I:Integer;
  S, S2:AnsiString;
Begin
  SetLength(S2, Tabs);
  For I:=1 To Tabs Do
    S2[I] := #9;
  Dest.WriteLine(S2+'<'+Self.ClassName+'>');

  For I:=0 To Pred(_PropertyCount) Do
  Begin
    S := S2 + '  <property name="'+_Properties[I].Key+'" value="'+_Properties[I].Value+'" />';
    Dest.WriteLine(S);
  End;

  For I:=0 To Pred(_ChildCount) Do
    _Childs[I].Save(Dest, Succ(Tabs));

  Dest.WriteLine(S2+'</'+Self.ClassName+'>');
End;

Procedure SceneNode.DeleteProperty(Key:AnsiString);
Var
  I:Integer;
Begin
  Key := UpStr(Key);
  For I:=0 To Pred(_PropertyCount) Do
  If (SameKey(_Properties[I].Key, Key)) Then
  Begin
    DeleteProperty(I);
    Exit;
  End;
End;

Procedure SceneNode.DeleteProperty(Index: Integer);
Var
  I:Integer;
Begin
  For I:=Index To _PropertyCount-2 Do
    _Properties[I] := _Properties[I+1];

  Dec(_PropertyCount);
End;

Function SceneNode.IsCustomProperty(Index: Integer):Boolean;
Begin
  Result := Not _Properties[Index].Internal;
End;

{ SceneMesh }
Constructor SceneMesh.Create(Parent:SceneNode; Pos:Vector3D; MyMesh:Mesh);
Var
  MeshName:AnsiString;
Begin
  Inherited Create(Parent, Pos);

  MeshName := LowStr(GetFileName(MyMesh.Location, True));

  _Instance := MeshInstance.Create(MyMesh);
  AddProperty('mesh', MeshName, True);
End;

Function SceneMesh.GetBoundingBox: BoundingBox;
Begin
  Result := _Instance.GetBoundingBox();
End;

Function SceneMesh.GetEditorPick(R: Ray; X, Y: Integer): SceneNode;
Var
  T:Single;
Begin
  Result := Inherited GetEditorPick(R, X, Y);

  If Assigned(Result) Then
    Exit;

  T := 9999;
  If (R.Intersect(Self.GetBoundingBox(), T)) Then
    Result := Self
  Else
    Result := Nil;
End;

Procedure SceneMesh.OnPropertyChange(Key, Value:AnsiString);
Var
  MyMesh:Mesh;
Begin
  Inherited;

  If (SameKey(Key, 'mesh')) Then
  Begin
    MyMesh := MeshManager.Instance.GetMesh(Value);
    If Assigned(MyMesh) Then
    Begin
      If Assigned(_Instance) Then
        _Instance.Destroy;

      _Instance := MeshInstance.Create(MyMesh);
    End;
  End Else
End;

Procedure SceneMesh.Render;
Begin
  Inherited;

  If (_Instance<>Nil) Then
  Begin
    _Instance.SetTransform(_Transform);
    GraphicsManager.Instance.AddRenderable(_Instance);
  End;
End;

{ SceneOccluder }
Procedure SceneOccluder.Render;
Begin
  GraphicsManager.Instance.AddOccluder(_Occluder);
End;

End.