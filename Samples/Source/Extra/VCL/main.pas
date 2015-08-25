unit main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, Menus,
  TERRA_Utils, TERRA_Application, TERRA_VCLApplication, TERRA_OS, TERRA_Texture,
  TERRA_Object, TERRA_Viewport, TERRA_FileManager, TERRA_Sprite, TERRA_PNG,
  TERRA_EngineManager, TERRA_GraphicsManager, TERRA_Math, TERRA_Matrix3x3, TERRA_Vector2D, TERRA_Color;

type
  TForm1 = class(TForm)
    Button1: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  public
    Procedure RenderViewport(V:TERRAViewport);
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

Var
  _Tex:TERRATexture = Nil;

{ MyScene }
Procedure TForm1.RenderViewport(V: TERRAViewport);
Var
  S:TERRASprite;
  Angle:Single;
Begin
  // A rotating sprite in the bottom, with Scale = 4x
  Angle := RAD * ((Application.GetTime() Div 15) Mod 360);
  S := V.SpriteRenderer.FetchSprite();
  S.SetTexture(_Tex);
  S.Layer := 50;
  S.Rotate(Angle);
  S.SetTransform(MatrixTransformAroundPoint2D(VectorCreate2D(_Tex.Width * 0.5, _Tex.Height * 0.5), S.Transform));
  S.Scale(4);
  S.Translate(100, 100);

  S.MakeQuad(VectorCreate2D(0, 0), 0.0, _Tex.Width, _Tex.Height);
  V.SpriteRenderer.QueueSprite(S);

  Inherited;
End;

Procedure TForm1.FormCreate(Sender: TObject);
Var
  VCLEngineApp:VCLApplication;
Begin
  VCLEngineApp := VCLApplication.Create(Self);

  // hooks up our custom render method to the engine viewport created by the VCL wrapper
  VCLEngineApp.Viewport.OnRender := Self.RenderViewport;

  // Added Asset folder to search path
  FileManager.Instance.AddPath('assets');

  // Load a Tex
  _Tex := Engine.Textures['ghost'];

  // set background color
  GraphicsManager.Instance.DeviceViewport.BackgroundColor := ColorGreen;
End;


procedure TForm1.FormDestroy(Sender: TObject);
begin
  Application.Instance.Terminate();
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  Forms.Application.Terminate();
end;


end.
