program PasGLTFViewer;
{$ifdef fpc}
 {$mode delphi}
{$endif}
{$ifdef profiledebug}
{$apptype console}
{$endif}
{$ifdef win32}
 {$define windows}
{$endif}
{$ifdef win64}
 {$define windows}
{$endif}

//  FastMM4,

uses
  SysUtils,
  Classes,
  Math,
  dglOpenGL in 'dglOpenGL.pas',
  UnitSDL2 in 'UnitSDL2.pas',
  UnitStaticLinking in 'UnitStaticLinking.pas',
  PasDblStrUtils in '..\..\externals\pasdblstrutils\src\PasDblStrUtils.pas',
  PasJSON in '..\..\externals\pasjson\src\PasJSON.pas',
  PasGLTF in '..\PasGLTF.pas',
  UnitGLTFOpenGL in 'UnitGLTFOpenGL.pas',
  UnitOpenGLImage in 'UnitOpenGLImage.pas',
  UnitOpenGLImageJPEG in 'UnitOpenGLImageJPEG.pas',
  UnitOpenGLImagePNG in 'UnitOpenGLImagePNG.pas',
  UnitMath3D in 'UnitMath3D.pas',
  UnitOpenGLShader in 'UnitOpenGLShader.pas',
  UnitOpenGLShadingShader in 'UnitOpenGLShadingShader.pas',
  UnitOpenGLFrameBufferObject in 'UnitOpenGLFrameBufferObject.pas',
  UnitOpenGLBRDFLUTShader in 'UnitOpenGLBRDFLUTShader.pas',
  UnitOpenGLEnvMapFilterShader in 'UnitOpenGLEnvMapFilterShader.pas',
  UnitOpenGLEnvMapDrawShader in 'UnitOpenGLEnvMapDrawShader.pas',
  UnitOpenGLAntialiasingShader in 'UnitOpenGLAntialiasingShader.pas',
  UnitOpenGLHDRToLDRShader in 'UnitOpenGLHDRToLDRShader.pas',
  UnitOpenGLEnvMapGenShader in 'UnitOpenGLEnvMapGenShader.pas',
  UnitFontPNG in 'UnitFontPNG.pas',
  UnitOpenGLSpriteBatch in 'UnitOpenGLSpriteBatch.pas',
  UnitOpenGLExtendedBlitRectShader in 'UnitOpenGLExtendedBlitRectShader.pas',
  UnitConsole in 'UnitConsole.pas',
  UnitOpenGLShadowMapBlurShader in 'UnitOpenGLShadowMapBlurShader.pas',
  UnitOpenGLShadowMapMultisampleResolveShader in 'UnitOpenGLShadowMapMultisampleResolveShader.pas',
  UnitOpenGLSolidColorShader in 'UnitOpenGLSolidColorShader.pas';

const Title='PasGLTF viewer';

      Version='2018.08.29.09.04.0000';

      Copyright='Copyright (C) 2018, Benjamin ''BeRo'' Rosseaux';

// Force usage of dedicated GPU for OpenGL with Delphi and FreePascal/Lazarus on Multi-GPU systems such as Notebooks on Windows
// Insert that into your main source file, which is for example the .dpr (Delphi) or .lpr (Lazarus) file

//{$define ForceDedicatedGPUUsage} // then you can uncomment and recomment this line, for compile-time-switching between
                                   // integrated GPU and dedicated GPU

{$if defined(Windows) and defined(ForceDedicatedGPUUsage) and (defined(cpu386) or defined(cpux64) or defined(cpuamd64))}
{$ifdef fpc}
 {$asmmode intel}
{$endif}
procedure NvOptimusEnablement; {$ifdef fpc}assembler; nostackframe;{$endif}
asm
{$ifdef cpu64}
{$ifndef fpc}
 .NOFRAME
{$endif}
{$endif}
 dd 1
end;

procedure AmdPowerXpressRequestHighPerformance; {$ifdef fpc}assembler; nostackframe;{$endif}
asm
{$ifdef cpu64}
{$ifndef fpc}
 .NOFRAME
{$endif}
{$endif}
 dd 1
end;

exports NvOptimusEnablement,
        AmdPowerXpressRequestHighPerformance;
{$ifend}

const VirtualCanvasWidth=1280;
      VirtualCanvasHeight=720;

      ShadowMapSize=1024;

var InputFileName:TPasGLTFUTF8String='';

    CurrentFileName:TPasGLTFUTF8String='';

    StartPerformanceCounter:Int64=0;

    GLTFOpenGL:TGLTFOpenGL=nil;

    GLTFInstance:TGLTFOpenGL.TInstance=nil;

    SolidColorShader:TSolidColorShader;

    ShadingShaders:array[boolean,boolean] of TShadingShader;

    ShadowShaders:array[boolean,boolean] of TShadingShader;

    BRDFLUTShader:TBRDFLUTShader;

    BRDFLUTFBO:TFBO;

    EnvMapGenShader:TEnvMapGenShader;

    EnvMapFilterShader:TEnvMapFilterShader;

    EnvMapFBO:TFBO;

    EnvMapDrawShader:TEnvMapDrawShader;

    MultisampledShadowMapTexture:glUInt=0;

    MultisampledShadowMapDepthTexture:glUInt=0;

//  MultisampledShadowMapDepthRenderBuffer:glUInt=0;

    MultisampledShadowMapFBO:glUInt=0;

    MultisampledShadowMapSamples:glInt=8;

    ShadowMapFBOs:array[0..2] of TFBO;

    HDRSceneFBO:TFBO;

    HDRToLDRShader:THDRToLDRShader;

    LDRSceneFBO:TFBO;

    ShadowMapMultisampleResolveShader:TShadowMapMultisampleResolveShader;

    ShadowMapBlurShader:TShadowMapBlurShader;

    AntialiasingShader:TAntialiasingShader;

    EmptyVertexArrayObjectHandle:glUInt;

    EnvMapTextureHandle:glUInt=0;

    TimeQueryHandle:glUInt=0;

    SceneFBOWidth:Int32=1280;
    SceneFBOHeight:Int32=720;

    Fullscreen:boolean=false;

    WrapCursor:boolean=false;

    FirstTime:boolean=true;

    AutomaticRotate:boolean=false;

    ButtonLeftPressed:boolean=false;

    ShowJoints:boolean=false;

    Shadows:boolean=false;

    SceneIndex:int32=-1;

    LastAnimationIndex:int32=-2;

    AnimationIndex:int32=0;

    ZoomLevel:TPasGLTFFloat=1.0;

    CameraRotationX:TPasGLTFFloat=0.0;
    CameraRotationY:TPasGLTFFloat=0.0;

    FileName:TPasGLTFUTF8String='';

const CubeMapFileNames:array[0..5] of string=
       (
        'posx',
        'negx',
        'posy',
        'negy',
        'posz',
        'negz'
       );

procedure ResetCamera;
begin
 ZoomLevel:=1.0;
 CameraRotationX:=0.0;
 CameraRotationY:=0.0;
end;

function Matrix4x4ProjectionReversedZ(const aFOV,aAspectRatio,aZNear:single):TMatrix4x4;
var f:single;
begin
 f:=1.0/tan(aFOV*DEG2RAD*0.5);
 result[0,0]:=f/aAspectRatio;
 result[0,1]:=0.0;
 result[0,2]:=0.0;
 result[0,3]:=0.0;
 result[1,0]:=0.0;
 result[1,1]:=f;
 result[1,2]:=0.0;
 result[1,3]:=0.0;
 result[2,0]:=0.0;
 result[2,1]:=0.0;
 result[2,2]:=0.0;
 result[2,3]:=-1.0;
 result[3,0]:=0.0;
 result[3,1]:=0.0;
 result[3,2]:=aZNear;
 result[3,3]:=0.0;
end;

var Event:TSDL_Event;
    SurfaceWindow:PSDL_Window;
    SurfaceContext:PSDL_GLContext;
    SDLDisplayMode:TSDL_DisplayMode;
    VideoFlags:longword;
    SDLWaveFormat:TSDL_AudioSpec;
    BufPosition:integer;
    ScreenWidth,ScreenHeight,BestWidth,BestHeight,ViewPortWidth,ViewPortHeight,ViewPortX,ViewPortY:int32;
    ShowCursor:boolean;
    SDLRunning,OldShowCursor:boolean;
    Time,LastTime,DeltaTime:double;
    AnimationTime:double=0.0;
    AnimationBeginTime:double=0.0;
    AnimationEndTime:double=1.0;

    LightDirection:UnitMath3D.TVector3;

    ShadowMapMatrix:UnitMath3D.TMatrix4x4;

    SceneAABB:TAABB;

function GetShadowMapMatrix(const aCameraViewMatrix:UnitMath3D.TMatrix4x4;
                            const aCameraProjectionMatrix:UnitMath3D.TMatrix4x4;
                            const aShadowCastersAABB:TAABB;
                            const aShadowReceiversAABB:TAABB):UnitMath3D.TMatrix4x4;
var CameraViewProjectionMatrix,
    CameraInverseViewProjectionMatrix,
    CameraInverseViewMatrix:UnitMath3D.TMatrix4x4;
    WorldSpaceCameraViewFrustumCorners:array[0..7] of UnitMath3D.TVector3;
    InterestedAreaAABB:TAABB;
 function GetLightModelMatrix:UnitMath3D.TMatrix4x4;
 var LightForwardVector,LightSideVector,LightUpvector,p:UnitMath3D.TVector3;
 begin
  LightForwardVector:=Vector3Neg(Vector3Norm(LightDirection));
  p.x:=abs(LightForwardVector.x);
  p.y:=abs(LightForwardVector.y);
  p.z:=abs(LightForwardVector.z);
  if (p.x<=p.y) and (p.x<=p.z) then begin
   p.x:=1.0;
   p.y:=0.0;
   p.z:=0.0;
  end else if (p.y<=p.x) and (p.y<=p.z) then begin
   p.x:=0.0;
   p.y:=1.0;
   p.z:=0.0;
  end else begin
   p.x:=0.0;
   p.y:=0.0;
   p.z:=1.0;
  end;
  LightSideVector:=Vector3Sub(p,Vector3ScalarMul(LightForwardVector,Vector3Dot(LightForwardVector,p)));
  LightUpVector:=Vector3Norm(Vector3Cross(LightForwardVector,LightSideVector));
  LightSideVector:=Vector3Norm(Vector3Cross(LightUpVector,LightForwardVector));
  result[0,0]:=LightSideVector.x;
  result[0,1]:=LightUpVector.x;
  result[0,2]:=LightForwardVector.x;
  result[0,3]:=0.0;
  result[1,0]:=LightSideVector.y;
  result[1,1]:=LightUpVector.y;
  result[1,2]:=LightForwardVector.y;
  result[1,3]:=0.0;
  result[2,0]:=LightSideVector.z;
  result[2,1]:=LightUpVector.z;
  result[2,2]:=LightForwardVector.z;
  result[2,3]:=0.0;
  result[3,0]:=0.0;
  result[3,1]:=0.0;
  result[3,2]:=0.0;
  result[3,3]:=1.0;
 end;
 function GetLightViewMatrix:UnitMath3D.TMatrix4x4;
 var LightModelMatrix:UnitMath3D.TMatrix4x4;
     WorldSpaceCameraForwardVector,
     LightSpaceCameraForwardVector:UnitMath3D.TVector3;
 begin
  result:=Matrix4x4Identity;
  LightModelMatrix:=GetLightModelMatrix;
  WorldSpaceCameraForwardVector:=UnitMath3D.PVector3(@CameraInverseViewMatrix[2,0])^;
  LightSpaceCameraForwardVector:=Vector3TermMatrixMul(WorldSpaceCameraForwardVector,LightModelMatrix);
  if abs(LightSpaceCameraForwardVector.z)<0.9997 then begin
   UnitMath3D.PVector3(@result[0,0])^:=Vector3Norm(Vector3Cross(LightSpaceCameraForwardVector,Vector3(0.0,0.0,1.0)));
   UnitMath3D.PVector3(@result[1,0])^:=Vector3Norm(Vector3Cross(Vector3(0.0,0.0,1.0),UnitMath3D.PVector3(@result[0,0])^));
   UnitMath3D.PVector3(@result[2,0])^:=Vector3(0.0,0.0,1.0);
  end;
  result:=Matrix4x4TermMul(LightModelMatrix,Matrix4x4TermTranspose(result));
 end;
 function GetLightProjectionMatrix(const aShadowMapViewMatrix:UnitMath3D.TMatrix4x4):UnitMath3D.TMatrix4x4;
 var AABB:TAABB;
     Left,Right,Top,Bottom,ZNear,ZFar,RightMinusLeft,TopMinusBottom,FarMinusNear:single;
 begin
  AABB:=AABBTransform(InterestedAreaAABB,aShadowMapViewMatrix);
  Left:=-1.0;
  Right:=1.0;
  Bottom:=-1.0;
  Top:=1.0;
  ZNear:=-AABB.Max.z;
  ZFar:=-AABB.Min.z;
  RightMinusLeft:=Right-Left;
  TopMinusBottom:=Top-Bottom;
  FarMinusNear:=ZFar-ZNear;
  result[0,0]:=2.0/RightMinusLeft;
  result[0,1]:=0.0;
  result[0,2]:=0.0;
  result[0,3]:=0.0;
  result[1,0]:=0.0;
  result[1,1]:=2.0/TopMinusBottom;
  result[1,2]:=0.0;
  result[1,3]:=0.0;
  result[2,0]:=0.0;
  result[2,1]:=0.0;
  result[2,2]:=(-2.0)/FarMinusNear;
  result[2,3]:=0.0;
  result[3,0]:=(-(Right+Left))/RightMinusLeft;
  result[3,1]:=(-(Top+Bottom))/TopMinusBottom;
  result[3,2]:=(-(ZFar+ZNear))/FarMinusNear;
  result[3,3]:=1.0;
 end;
 procedure SnapShadowMapProjectionMatrix(const aShadowMapViewMatrix:UnitMath3D.TMatrix4x4;
                                         var aShadowMapProjectionMatrix:UnitMath3D.TMatrix4x4;
                                         const aShadowMapWidth:TPasGLTFInt32=ShadowMapSize;
                                         const aShadowMapHeight:TPasGLTFInt32=ShadowMapSize);
 var RoundedOrigin,RoundOffset:UnitMath3D.TVector2;
     ShadowOrigin:UnitMath3D.TVector4;
 begin
  // Create the rounding matrix, by projecting the world-space origin and determining the fractional offset in texel space
  ShadowOrigin:=Vector4TermMatrixMul(Vector4(0.0,0.0,0.0,1.0),Matrix4x4TermMul(aShadowMapViewMatrix,aShadowMapProjectionMatrix));
  ShadowOrigin.x:=ShadowOrigin.x*aShadowMapWidth;
  ShadowOrigin.y:=ShadowOrigin.y*aShadowMapHeight;
  RoundedOrigin.x:=round(ShadowOrigin.x);
  RoundedOrigin.y:=round(ShadowOrigin.y);
  RoundOffset.x:=((RoundedOrigin.x-ShadowOrigin.x)*2.0)/aShadowMapWidth;
  RoundOffset.y:=((RoundedOrigin.y-ShadowOrigin.y)*2.0)/aShadowMapHeight;
  aShadowMapProjectionMatrix[3,0]:=aShadowMapProjectionMatrix[3,0]+RoundOffset.x;
  aShadowMapProjectionMatrix[3,1]:=aShadowMapProjectionMatrix[3,1]+RoundOffset.y;
 end;
const NormalizedClipSpaceCameraViewFrustumCorners:array[0..7] of UnitMath3D.TVector3=((x:-1;y:-1;z:1),
                                                                                      (x:1;y:-1;z:1),
                                                                                      (x:-1;y:1;z:1),
                                                                                      (x:1;y:1;z:1),
                                                                                      (x:-1;y:-1;z:-1),
                                                                                      (x:1;y:-1;z:-1),
                                                                                      (x:-1;y:1;z:-1),
                                                                                      (x:1;y:1;z:-1));
var Index:TPasGLTFSizeInt;
    LightViewMatrix,
    LightProjectionMatrix,
    LightSpaceMatrix,
    WarpMatrix,WarppedLightSpaceMatrix,
    FocusTransformMatrix:UnitMath3D.TMatrix4x4;
    WorldSpaceCameraViewFrustumAABB,
    LightSpaceAABB:UnitMath3D.TAABB;
    Scale,
    Offset:UnitMath3D.TVector2;
    ShadowMapDimension:TPasGLTFFloat;
begin
 CameraViewProjectionMatrix:=Matrix4x4TermMul(aCameraViewMatrix,aCameraProjectionMatrix);
 CameraInverseViewProjectionMatrix:=Matrix4x4TermInverse(CameraViewProjectionMatrix);
 CameraInverseViewMatrix:=Matrix4x4TermInverse(aCameraViewMatrix);
 for Index:=Low(WorldSpaceCameraViewFrustumCorners) to High(WorldSpaceCameraViewFrustumCorners) do begin
  WorldSpaceCameraViewFrustumCorners[Index]:=Vector3TermMatrixMulHomogen(NormalizedClipSpaceCameraViewFrustumCorners[Index],
                                                                         CameraInverseViewProjectionMatrix);
 end;
 WorldSpaceCameraViewFrustumAABB.Min:=WorldSpaceCameraViewFrustumCorners[Low(WorldSpaceCameraViewFrustumCorners)];
 WorldSpaceCameraViewFrustumAABB.Max:=WorldSpaceCameraViewFrustumCorners[Low(WorldSpaceCameraViewFrustumCorners)];
 for Index:=Low(WorldSpaceCameraViewFrustumCorners)+1 to High(WorldSpaceCameraViewFrustumCorners) do begin
  WorldSpaceCameraViewFrustumAABB:=AABBCombineVector3(WorldSpaceCameraViewFrustumAABB,WorldSpaceCameraViewFrustumCorners[Index]);
 end;
 InterestedAreaAABB:=AABBCombine(aShadowCastersAABB,aShadowReceiversAABB);
 LightViewMatrix:=GetLightViewMatrix;
 LightProjectionMatrix:=GetLightProjectionMatrix(LightViewMatrix);
 LightSpaceMatrix:=Matrix4x4TermMul(LightViewMatrix,LightProjectionMatrix);
 WarpMatrix:=Matrix4x4Identity;
 WarppedLightSpaceMatrix:=Matrix4x4TermMul(LightSpaceMatrix,WarpMatrix);
 LightSpaceAABB:=AABBTransform(InterestedAreaAABB,WarppedLightSpaceMatrix);
 ShadowMapDimension:=ShadowMapSize;
 Scale.x:=2.0/(LightSpaceAABB.Max.x-LightSpaceAABB.Min.x);
 Scale.y:=2.0/(LightSpaceAABB.Max.y-LightSpaceAABB.Min.y);
 Offset.x:=((LightSpaceAABB.Min.x+LightSpaceAABB.Max.x)*(-0.5))*Scale.x;
 Offset.y:=((LightSpaceAABB.Min.y+LightSpaceAABB.Max.y)*(-0.5))*Scale.y;
 // TODO: Snap scale also
 Offset.x:=ceil(Offset.x*ShadowMapDimension)/ShadowMapDimension;
 Offset.y:=ceil(Offset.y*ShadowMapDimension)/ShadowMapDimension;
 FocusTransformMatrix[0,0]:=Scale.x;
 FocusTransformMatrix[0,1]:=0.0;
 FocusTransformMatrix[0,2]:=0.0;
 FocusTransformMatrix[0,3]:=0.0;
 FocusTransformMatrix[1,0]:=0.0;
 FocusTransformMatrix[1,1]:=Scale.y;
 FocusTransformMatrix[1,2]:=0.0;
 FocusTransformMatrix[1,3]:=0.0;
 FocusTransformMatrix[2,0]:=0.0;
 FocusTransformMatrix[2,1]:=0.0;
 FocusTransformMatrix[2,2]:=1.0;
 FocusTransformMatrix[2,3]:=0.0;
 FocusTransformMatrix[3,0]:=Offset.x;
 FocusTransformMatrix[3,1]:=Offset.y;
 FocusTransformMatrix[3,2]:=0.0;
 FocusTransformMatrix[3,3]:=1.0;
 result:=Matrix4x4TermMul(WarppedLightSpaceMatrix,FocusTransformMatrix);
end;

procedure DumpAnimationJoints;
const FramesPerSecond=8;
      Scale=128;
 function cmul(const a,b:UnitMath3D.TVector2):UnitMath3D.TVector2;
 begin
  result.x:=(a.x*b.x)-(a.y*b.y);
  result.y:=(a.x*b.y)+(a.y*b.x);
 end;
var CountFrames,FrameIndex,JointIndex,AxisIndex,
    CoefficientIndex,CountWantedJoints,
    CountCoefficients,Count:TPasGLTFSizeInt;
    Frames:array of TPasGLTF.TVector3DynamicArray;
    MatrixFrames:array of TPasGLTF.TMatrix4x4DynamicArray;
    WantedJoints:array of TPasGLTFSizeInt;
    FourierCoefficients,tv4:UnitMath3D.TVector4;
    AngleVector:UnitMath3D.TVector2;
    MemoryStream:TMemoryStream;
    UI32:TPasGLTFUInt32;
    UI16:TPasGLTFUInt16;
    UI8,PUI8,OUI8:TPasGLTFUInt8;
    Alpha:TPasGLTFFloat;
    Name:UTF8String;
    WantedJointNodes:TStringList;
    AABB:TAABB;
    F32:TPasGLTFFloat;
begin
 if assigned(GLTFInstance) then begin
  GLTFInstance.Scene:=SceneIndex;
  GLTFInstance.Animation:=AnimationIndex;
  if AnimationBeginTime>=AnimationEndTime then begin
   exit;
  end;
  WantedJointNodes:=TStringList.Create;
  try
   WantedJointNodes.Add('mixamorig:Hips');
   WantedJointNodes.Add('mixamorig:Spine');
   WantedJointNodes.Add('mixamorig:Spine2');
   WantedJointNodes.Add('mixamorig:Neck');
   WantedJointNodes.Add('mixamorig:Head');
   WantedJointNodes.Add('mixamorig:HeadTop_End');
   WantedJointNodes.Add('mixamorig:LeftShoulder');
   WantedJointNodes.Add('mixamorig:LeftForeArm');
   WantedJointNodes.Add('mixamorig:LeftHand');
   WantedJointNodes.Add('mixamorig:RightShoulder');
   WantedJointNodes.Add('mixamorig:RightForeArm');
   WantedJointNodes.Add('mixamorig:RightHand');
   WantedJointNodes.Add('mixamorig:LeftUpLeg');
   WantedJointNodes.Add('mixamorig:LeftLeg');
   WantedJointNodes.Add('mixamorig:LeftFoot');
   WantedJointNodes.Add('mixamorig:LeftToeBase');
   WantedJointNodes.Add('mixamorig:RightUpLeg');
   WantedJointNodes.Add('mixamorig:RightLeg');
   WantedJointNodes.Add('mixamorig:RightFoot');
   WantedJointNodes.Add('mixamorig:RightToeBase');
{  WantedJointNodes.Add('mixamorig_Hips');
   WantedJointNodes.Add('mixamorig_Spine');
   WantedJointNodes.Add('mixamorig_Spine2');
   WantedJointNodes.Add('mixamorig_Neck');
   WantedJointNodes.Add('mixamorig_Head');
   WantedJointNodes.Add('mixamorig_HeadTop_End');
   WantedJointNodes.Add('mixamorig_LeftShoulder');
   WantedJointNodes.Add('mixamorig_LeftForeArm');
   WantedJointNodes.Add('mixamorig_LeftHand');
   WantedJointNodes.Add('mixamorig_RightShoulder');
   WantedJointNodes.Add('mixamorig_RightForeArm');
   WantedJointNodes.Add('mixamorig_RightHand');
   WantedJointNodes.Add('mixamorig_LeftUpLeg');
   WantedJointNodes.Add('mixamorig_LeftLeg');
   WantedJointNodes.Add('mixamorig_LeftFoot');
   WantedJointNodes.Add('mixamorig_LeftToeBase');
   WantedJointNodes.Add('mixamorig_RightUpLeg');
   WantedJointNodes.Add('mixamorig_RightLeg');
   WantedJointNodes.Add('mixamorig_RightFoot');
   WantedJointNodes.Add('mixamorig_RightToeBase');}
   CountFrames:=trunc((AnimationEndTime-AnimationBeginTime)*FramesPerSecond);
   if CountFrames>0 then begin
    Frames:=nil;
    MatrixFrames:=nil;
    try
     CountCoefficients:=CountFrames;
     SetLength(Frames,CountFrames);
     SetLength(MatrixFrames,CountFrames);
     for FrameIndex:=0 to CountFrames-1 do begin
      GLTFInstance.AnimationTime:=AnimationBeginTime+(FrameIndex/FramesPerSecond);
      GLTFInstance.Update;
      Frames[FrameIndex]:=GLTFInstance.GetJointPoints;
      MatrixFrames[FrameIndex]:=GLTFInstance.GetJointMatrices;
     end;
     CountWantedJoints:=0;
     SetLength(WantedJoints,Max(WantedJointNodes.Count,length(GLTFOpenGL.Joints)));
     for JointIndex:=0 to length(WantedJoints)-1 do begin
      WantedJoints[JointIndex]:=-1;
     end;
     for JointIndex:=0 to length(GLTFOpenGL.Joints)-1 do begin
      Name:=GLTFOpenGL.Nodes[GLTFOpenGL.Joints[JointIndex].Node].Name;
      CoefficientIndex:=WantedJointNodes.IndexOf(Name);
      if (length(Name)>0) and (CoefficientIndex>=0) then begin
       WantedJoints[CoefficientIndex]:=JointIndex;
       inc(CountWantedJoints);
      end;
     end;
     if WantedJoints[5]<0 then begin
      WantedJoints[5]:=length(Frames[0]);
      inc(CountWantedJoints);
      for FrameIndex:=0 to CountFrames-1 do begin
       SetLength(Frames[FrameIndex],length(Frames[FrameIndex])+1);
       for AxisIndex:=0 to 2 do begin
        Frames[FrameIndex][WantedJoints[5]][AxisIndex]:=Frames[FrameIndex][WantedJoints[4]][AxisIndex]+(MatrixFrames[FrameIndex][WantedJoints[4]][4+AxisIndex]*0.25);
       end;
      end;
     end;
     AABB.Min.x:=INFINITY;
     AABB.Min.y:=INFINITY;
     AABB.Min.z:=INFINITY;
     AABB.Max.x:=-INFINITY;
     AABB.Max.y:=-INFINITY;
     AABB.Max.z:=-INFINITY;
     for JointIndex:=0 to length(Frames[0])-1 do begin
      for FrameIndex:=0 to CountFrames-1 do begin
       AABB:=AABBCombineVector3(AABB,UnitMath3D.PVector3(@Frames[FrameIndex][JointIndex])^);
      end;
     end;
     for JointIndex:=0 to length(Frames[0])-1 do begin
      for FrameIndex:=0 to CountFrames-1 do begin
       for AxisIndex:=0 to 2 do begin
        Frames[FrameIndex][JointIndex][AxisIndex]:=(Frames[FrameIndex][JointIndex][AxisIndex]-AABB.Min.xyz[AxisIndex])/(AABB.Max.xyz[AxisIndex]-AABB.Min.xyz[AxisIndex]);
       end;
      end;
     end;
     MemoryStream:=TMemoryStream.Create;
     try
      UI32:=CountWantedJoints;
      MemoryStream.WriteBuffer(UI32,SizeOf(TPasGLTFUInt32));
      UI32:=CountFrames;
      MemoryStream.WriteBuffer(UI32,SizeOf(TPasGLTFUInt32));
      UI32:=0;
      MemoryStream.WriteBuffer(UI32,SizeOf(TPasGLTFUInt32));
      UI32:=FramesPerSecond;
      MemoryStream.WriteBuffer(UI32,SizeOf(TPasGLTFUInt32));
      begin
       for AxisIndex:=0 to 2 do begin
        F32:=AABB.Min.xyz[AxisIndex];
        MemoryStream.WriteBuffer(F32,SizeOf(TPasGLTFFloat));
       end;
       F32:=0.0;
       MemoryStream.WriteBuffer(F32,SizeOf(TPasGLTFFloat));
      end;
      begin
       for AxisIndex:=0 to 2 do begin
        F32:=AABB.Max.xyz[AxisIndex];
        MemoryStream.WriteBuffer(F32,SizeOf(TPasGLTFFloat));
       end;
       F32:=0.0;
       MemoryStream.WriteBuffer(F32,SizeOf(TPasGLTFFloat));
      end;
{     for JointIndex:=0 to CountWantedJoints-1 do begin
       for FrameIndex:=0 to CountFrames-1 do begin
        UI32:=(Min(Max(trunc(Frames[FrameIndex][WantedJoints[JointIndex]][0]*255),0),255) shl 0) or
              (Min(Max(trunc(Frames[FrameIndex][WantedJoints[JointIndex]][1]*255),0),255) shl 8) or
              (Min(Max(trunc(Frames[FrameIndex][WantedJoints[JointIndex]][2]*255),0),255) shl 16);
        MemoryStream.WriteBuffer(UI32,SizeOf(TPasGLTFUInt32));
       end;
      end;}
      PUI8:=0;
      for AxisIndex:=0 to 2 do begin
       for JointIndex:=0 to CountWantedJoints-1 do begin
        for FrameIndex:=0 to CountFrames-1 do begin
         UI8:=Min(Max(trunc(Frames[FrameIndex][WantedJoints[JointIndex]][AxisIndex]*255),0),255);
         OUI8:=UI8;//-PUI8;
         MemoryStream.WriteBuffer(OUI8,SizeOf(TPasGLTFUInt8));
         PUI8:=UI8;
         inc(Count);
        end;
       end;
      end;
      while (Count and 3)<>0 do begin
       UI8:=0;
       MemoryStream.WriteBuffer(UI8,SizeOf(TPasGLTFUInt8));
       inc(Count);
      end;
      PPasGLTFUInt32(@PAnsiChar(MemoryStream.Memory)[8])^:=Count;
{     for JointIndex:=0 to CountWantedJoints-1 do begin
       for FrameIndex:=0 to CountFrames-1 do begin
        for AxisIndex:=0 to 2 do begin
         UI16:=TPasGLTFUInt64(TPasGLTFInt64(trunc(Frames[FrameIndex][WantedJoints[JointIndex]][AxisIndex]*1024)));
         MemoryStream.WriteBuffer(UI16,SizeOf(TPasGLTFUInt16));
        end;
        UI16:=0;
        MemoryStream.WriteBuffer(UI16,SizeOf(TPasGLTFUInt16));
       end;
      end;}
{      for CoefficientIndex:=0 to CountCoefficients-1 do begin
        FourierCoefficients:=Vector4Origin;
        for FrameIndex:=0 to CountFrames-1 do begin
         Alpha:=(-(PI*2.0)*(CoefficientIndex/CountCoefficients))*FrameIndex;
         AngleVector:=Vector2(cos(Alpha),sin(Alpha));
         UnitMath3D.PVector2(@tv4.xyzw[0])^:=cmul(Vector2(Frames[FrameIndex][WantedJoints[JointIndex]][0],Frames[FrameIndex][WantedJoints[JointIndex]][2]),AngleVector);
         UnitMath3D.PVector2(@tv4.xyzw[2])^:=cmul(Vector2(Frames[FrameIndex][WantedJoints[JointIndex]][1],Frames[FrameIndex][WantedJoints[JointIndex]][2]),AngleVector);
         FourierCoefficients:=Vector4Add(FourierCoefficients,tv4);
        end;}
      MemoryStream.SaveToFile('animationjoints.bin');
     finally
      MemoryStream.Free;
     end;
    finally
     Frames:=nil;
    end;
    AnimationTime:=0.0;
   end;
  finally
   WantedJointNodes.Free;
  end;
 end;
end;

var GPUTimeElapsed:GLuint64=0;
    GPUTimeState:GLint=0;

procedure Draw;
var ModelMatrix,
    ViewMatrix,
    ProjectionMatrix,
    SkyBoxViewProjectionMatrix:UnitMath3D.TMatrix4x4;
    Bounds,Center:UnitMath3D.TVector3;
    t:double;
    v,Zoom,n,f:TPasGLTFFloat;
    ShadingShader:TShadingShader;
    t0,t1:int64;
    Index:int32;
    TimeQueryAvailable:glInt;
begin
 t0:=SDL_GetPerformanceCounter;
 if GPUTimeState=3 then begin
  glGetQueryObjectiv(TimeQueryHandle,GL_QUERY_RESULT_AVAILABLE,@TimeQueryAvailable);
  if TimeQueryAvailable<>0 then begin
   GPUTimeElapsed:=0;
   glGetQueryObjectui64v(TimeQueryHandle,GL_QUERY_RESULT,@GPUTimeElapsed);
   GPUTimeState:=1;
  end;
 end;
 if GPUTimeState in [0,1] then begin
  glBeginQuery(GL_TIME_ELAPSED,TimeQueryHandle);
  GPUTimeState:=2;
 end;
 begin
  ModelMatrix:=Matrix4x4Identity;
  if assigned(GLTFOpenGL) then begin
   Center.x:=(GLTFOpenGL.StaticBoundingBox.Min[0]+GLTFOpenGL.StaticBoundingBox.Max[0])*0.5;
   Center.y:=(GLTFOpenGL.StaticBoundingBox.Min[1]+GLTFOpenGL.StaticBoundingBox.Max[1])*0.5;
   Center.z:=(GLTFOpenGL.StaticBoundingBox.Min[2]+GLTFOpenGL.StaticBoundingBox.Max[2])*0.5;
   Bounds.x:=(GLTFOpenGL.StaticBoundingBox.Max[0]-GLTFOpenGL.StaticBoundingBox.Min[0])*0.5;
   Bounds.y:=(GLTFOpenGL.StaticBoundingBox.Max[1]-GLTFOpenGL.StaticBoundingBox.Min[1])*0.5;
   Bounds.z:=(GLTFOpenGL.StaticBoundingBox.Max[2]-GLTFOpenGL.StaticBoundingBox.Min[2])*0.5;
  end else begin
   Center.x:=0.0;
   Center.y:=0.0;
   Center.z:=0.0;
   Bounds.x:=1.0;
   Bounds.y:=1.0;
   Bounds.z:=1.0;
  end;
  Zoom:=ZoomLevel;
  ViewMatrix:=Matrix4x4LookAt(Vector3Add(Center,
                                         Vector3ScalarMul(Vector3Norm(Vector3(sin(CameraRotationX*PI*2.0)*cos(-CameraRotationY*PI*2.0),
                                                                              sin(-CameraRotationY*PI*2.0),
                                                                              cos(CameraRotationX*PI*2.0)*cos(-CameraRotationY*PI*2.0))),
                                                          Max(Max(Bounds.x,Bounds.y),Bounds.z)*3.0*Zoom)),
                               Center,
                               Vector3YAxis);
{  ViewMatrix:=Matrix4x4LookAt(Vector3Add(Center,
                                         Vector3TermMatrixMul(Vector3(0.0,
                                                                      0.0,
                                                                      Max(Max(Bounds.x,Bounds.y),Bounds.z)*3.0*Zoom),
                                                              Matrix4x4TermMul(Matrix4x4RotateY(CameraRotationX*PI*2.0),
                                                                               Matrix4x4RotateX(CameraRotationY*PI*2.0)))),
                               Center,
                               Vector3YAxis);}
  ProjectionMatrix:=Matrix4x4ProjectionReversedZ(45.0,ViewPortWidth/ViewPortHeight,1e-3);
 end;
 if assigned(GLTFInstance) then begin
  GLTFInstance.Scene:=SceneIndex;
  GLTFInstance.Animation:=AnimationIndex;
  if (LastAnimationIndex<>AnimationIndex) and Shadows then begin
   LastAnimationIndex:=AnimationIndex;
// GLTFInstance.UpdateWorstCaseStaticBoundingBox;
  end;
  if AnimationTime<AnimationBeginTime then begin
   AnimationTime:=AnimationBeginTime;
  end;
  if AnimationTime>AnimationEndTime then begin
   AnimationTime:=Modulo(AnimationTime-AnimationBeginTime,AnimationEndTime-AnimationBeginTime)+AnimationBeginTime;
   if AnimationTime>=AnimationEndTime then begin
    AnimationTime:=AnimationEndTime;
   end;
  end;
  GLTFInstance.AnimationTime:=AnimationTime;
  GLTFInstance.Update;
  GLTFInstance.Upload;
 end;
 if assigned(GLTFInstance) and Shadows then begin
{ GLTFInstance.UpdateDynamicBoundingBox(false);
  SceneAABB.Min.x:=GLTFInstance.DynamicBoundingBox.Min[0];
  SceneAABB.Min.y:=GLTFInstance.DynamicBoundingBox.Min[1];
  SceneAABB.Min.z:=GLTFInstance.DynamicBoundingBox.Min[2];
  SceneAABB.Max.x:=GLTFInstance.DynamicBoundingBox.Max[0];
  SceneAABB.Max.y:=GLTFInstance.DynamicBoundingBox.Max[1];
  SceneAABB.Max.z:=GLTFInstance.DynamicBoundingBox.Max[2];}
  SceneAABB.Min.x:=GLTFOpenGL.StaticBoundingBox.Min[0];
  SceneAABB.Min.y:=GLTFOpenGL.StaticBoundingBox.Min[1];
  SceneAABB.Min.z:=GLTFOpenGL.StaticBoundingBox.Min[2];
  SceneAABB.Max.x:=GLTFOpenGL.StaticBoundingBox.Max[0];
  SceneAABB.Max.y:=GLTFOpenGL.StaticBoundingBox.Max[1];
  SceneAABB.Max.z:=GLTFOpenGL.StaticBoundingBox.Max[2];
{ SceneAABB.Min.x:=GLTFInstance.WorstCaseStaticBoundingBox.Min[0];
  SceneAABB.Min.y:=GLTFInstance.WorstCaseStaticBoundingBox.Min[1];
  SceneAABB.Min.z:=GLTFInstance.WorstCaseStaticBoundingBox.Min[2];
  SceneAABB.Max.x:=GLTFInstance.WorstCaseStaticBoundingBox.Max[0];
  SceneAABB.Max.y:=GLTFInstance.WorstCaseStaticBoundingBox.Max[1];
  SceneAABB.Max.z:=GLTFInstance.WorstCaseStaticBoundingBox.Max[2];}
  ShadowMapMatrix:=GetShadowMapMatrix(ViewMatrix,Matrix4x4Perspective(45.0,ViewPortWidth/ViewPortHeight,1e-1,1e+2),SceneAABB,SceneAABB);
  for ShadingShader in ShadowShaders do begin
   ShadingShader.Bind;
   glUniform3fv(ShadingShader.uLightDirection,1,@LightDirection);
   ShadingShader.Unbind;
  end;
  begin
 // glBindFramebuffer(GL_DRAW_FRAMEBUFFER,ShadowMapFBOs[0].FBOs[0]);
   glBindFramebuffer(GL_FRAMEBUFFER,MultisampledShadowMapFBO);
   glDrawBuffer(GL_COLOR_ATTACHMENT0);
   glEnable(GL_MULTISAMPLE);
   glViewport(0,0,ShadowMapSize,ShadowMapSize);
   glClearColor(1.0,1.0,1.0,1.0);
   glClearDepth(1.0);
   glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
   glClipControl(GL_LOWER_LEFT,GL_NEGATIVE_ONE_TO_ONE);
   glEnable(GL_DEPTH_TEST);
   glDepthFunc(GL_LEQUAL);
   ModelMatrix:=Matrix4x4Identity;
   GLTFInstance.Draw(TPasGLTF.TMatrix4x4(Pointer(@ModelMatrix)^),
                     TPasGLTF.TMatrix4x4(Pointer(@Matrix4x4Identity)^),
                     TPasGLTF.TMatrix4x4(Pointer(@ShadowMapMatrix)^),
                     TPasGLTF.TMatrix4x4(Pointer(@ShadowMapMatrix)^),
                     ShadowShaders[false,false],
                     ShadowShaders[false,true],
                     ShadowShaders[true,false],
                     ShadowShaders[true,true],
                     [TPasGLTF.TMaterial.TAlphaMode.Opaque,TPasGLTF.TMaterial.TAlphaMode.Mask]);
   glBindFrameBuffer(GL_FRAMEBUFFER,0);
   glDisable(GL_MULTISAMPLE);
  end;
 begin
   glBindFrameBuffer(GL_FRAMEBUFFER,ShadowMapFBOs[0].FBOs[0]);
   glDrawBuffer(GL_COLOR_ATTACHMENT0);
   glViewport(0,0,ShadowMapFBOs[0].Width,ShadowMapFBOs[0].Height);
   glClear(GL_COLOR_BUFFER_BIT);
   glDisable(GL_BLEND);
   glDisable(GL_DEPTH_TEST);
   glDisable(GL_CULL_FACE);
   glDepthFunc(GL_ALWAYS);
   glActiveTexture(GL_TEXTURE0);
   glBindTexture(GL_TEXTURE_2D_MULTISAMPLE,MultisampledShadowMapTexture);
   ShadowMapMultisampleResolveShader.Bind;
   glUniform1i(ShadowMapMultisampleResolveShader.uTexture,0);
   glUniform1i(ShadowMapMultisampleResolveShader.uSamples,MultisampledShadowMapSamples);
   glBindVertexArray(EmptyVertexArrayObjectHandle);
   glDrawArrays(GL_TRIANGLES,0,3);
   glBindVertexArray(0);
   ShadowMapMultisampleResolveShader.Unbind;
   glBindFrameBuffer(GL_FRAMEBUFFER,0);
   glBindTexture(GL_TEXTURE_2D_MULTISAMPLE,0);
  end;
{ begin // renderdoc don't like this (garbage trace output then as result)
   glBindFramebuffer(GL_DRAW_FRAMEBUFFER,ShadowMapFBOs[0].FBOs[0]);
   glBindFramebuffer(GL_READ_FRAMEBUFFER,MultisampledShadowMapFBO);
   glDrawBuffer(GL_COLOR_ATTACHMENT0);
   glBlitFramebuffer(0,0,ShadowMapSize,ShadowMapSize,
                     0,0,ShadowMapFBOs[0].Width,ShadowMapFBOs[0].Height,
                     GL_COLOR_BUFFER_BIT,
                     GL_NEAREST);
   glBindFramebuffer(GL_DRAW_FRAMEBUFFER,0);
   glBindFramebuffer(GL_READ_FRAMEBUFFER,0);
  end;{}
  for Index:=1 to 2 do begin
   glBindFrameBuffer(GL_FRAMEBUFFER,ShadowMapFBOs[Index].FBOs[0]);
   glDrawBuffer(GL_COLOR_ATTACHMENT0);
   glViewport(0,0,ShadowMapFBOs[Index].Width,ShadowMapFBOs[Index].Height);
   glClear(GL_COLOR_BUFFER_BIT);
   glDisable(GL_BLEND);
   glDisable(GL_DEPTH_TEST);
   glDisable(GL_CULL_FACE);
   glDepthFunc(GL_ALWAYS);
   glActiveTexture(GL_TEXTURE0);
   glBindTexture(GL_TEXTURE_2D,ShadowMapFBOs[Index-1].TextureHandles[0]);
   ShadowMapBlurShader.Bind;
   glUniform1i(ShadowMapBlurShader.uTexture,0);
   if Index=1 then begin
    glUniform2f(ShadowMapBlurShader.uDirection,1.0,0.0);
   end else begin
    glUniform2f(ShadowMapBlurShader.uDirection,0.0,1.0);
   end;
   glBindVertexArray(EmptyVertexArrayObjectHandle);
   glDrawArrays(GL_TRIANGLES,0,3);
   glBindVertexArray(0);
   ShadowMapBlurShader.Unbind;
   glBindFrameBuffer(GL_FRAMEBUFFER,0);
  end;
 end;
 begin
  glBindFrameBuffer(GL_FRAMEBUFFER,HDRSceneFBO.FBOs[0]);
  glDrawBuffer(GL_COLOR_ATTACHMENT0);
  glViewport(0,0,HDRSceneFBO.Width,HDRSceneFBO.Height);
  glClearColor(0.0,0.0,0.0,0.0);
  glClearDepth(0.0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  glClipControl(GL_LOWER_LEFT,GL_ZERO_TO_ONE);
  glDepthFunc(GL_GEQUAL);
  SkyBoxViewProjectionMatrix:=Matrix4x4TermMul(Matrix4x4Rotation(ViewMatrix),ProjectionMatrix);
  begin
   glDisable(GL_DEPTH_TEST);
   glDisable(GL_CULL_FACE);
   glActiveTexture(GL_TEXTURE0);
   glBindTexture(GL_TEXTURE_2D,EnvMapTextureHandle);
   EnvMapDrawShader.Bind;
   glUniform1i(EnvMapDrawShader.uTexture,0);
   glUniformMatrix4fv(EnvMapDrawShader.uViewProjectionMatrix,1,false,@SkyBoxViewProjectionMatrix);
   glBindVertexArray(EmptyVertexArrayObjectHandle);
   glDrawArrays(GL_TRIANGLES,0,36);
   glBindVertexArray(0);
   EnvMapDrawShader.Unbind;
  end;
  begin
   glActiveTexture(GL_TEXTURE5);
   glBindTexture(GL_TEXTURE_2D,BRDFLUTFBO.TextureHandles[0]);
   if Shadows then begin
    glActiveTexture(GL_TEXTURE6);
    glBindTexture(GL_TEXTURE_2D,ShadowMapFBOs[2].TextureHandles[0]);
   end;
   glActiveTexture(GL_TEXTURE7);
   glBindTexture(GL_TEXTURE_CUBE_MAP,EnvMapFBO.TextureHandles[0]);
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_LINEAR);
   glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
   glActiveTexture(GL_TEXTURE0);
   glEnable(GL_DEPTH_TEST);
   glEnable(GL_CULL_FACE);
   glCullFace(GL_BACK);
   for ShadingShader in ShadingShaders do begin
    ShadingShader.Bind;
    glUniform3fv(ShadingShader.uLightDirection,1,@LightDirection);
    glUniform1i(ShadingShader.uEnvMapMaxLevel,Min(EnvMapFBO.WorkMaxLevel,16));
    glUniform1i(ShadingShader.uShadows,ord(Shadows) and 1);
    ShadingShader.Unbind;
   end;
   if assigned(GLTFInstance) then begin
    GLTFInstance.Draw(TPasGLTF.TMatrix4x4(Pointer(@ModelMatrix)^),
                      TPasGLTF.TMatrix4x4(Pointer(@ViewMatrix)^),
                      TPasGLTF.TMatrix4x4(Pointer(@ProjectionMatrix)^),
                      TPasGLTF.TMatrix4x4(Pointer(@ShadowMapMatrix)^),
                      ShadingShaders[false,false],
                      ShadingShaders[false,true],
                      ShadingShaders[true,false],
                      ShadingShaders[true,true]);
    if ShowJoints then begin
     GLTFInstance.DrawJoints(TPasGLTF.TMatrix4x4(Pointer(@ModelMatrix)^),
                             TPasGLTF.TMatrix4x4(Pointer(@ViewMatrix)^),
                             TPasGLTF.TMatrix4x4(Pointer(@ProjectionMatrix)^),
                             SolidColorShader);
    end;
   end;
  end;
  glClipControl(GL_LOWER_LEFT,GL_NEGATIVE_ONE_TO_ONE);
 end;
 begin
  glBindFrameBuffer(GL_FRAMEBUFFER,LDRSceneFBO.FBOs[0]);
  glDrawBuffer(GL_COLOR_ATTACHMENT0);
  glViewport(0,0,LDRSceneFBO.Width,LDRSceneFBO.Height);
  glClearColor(0.0,0.0,0.0,0.0);
  glClear(GL_COLOR_BUFFER_BIT);
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_CULL_FACE);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D,HDRSceneFBO.TextureHandles[0]);
  HDRToLDRShader.Bind;
  glUniform1i(HDRToLDRShader.uTexture,0);
  glBindVertexArray(EmptyVertexArrayObjectHandle);
  glDrawArrays(GL_TRIANGLES,0,3);
  glBindVertexArray(0);
  HDRToLDRShader.Unbind;
 end;
 begin
  glBindFrameBuffer(GL_FRAMEBUFFER,0);
  glDrawBuffer(GL_BACK);
  glViewport(0,0,ViewPortWidth,ViewPortHeight);
  glClearColor(0.0,0.0,0.0,0.0);
  glClearDepth(1.0);
  glViewport(ViewPortX,ViewPortY,ViewPortWidth,ViewPortHeight);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_CULL_FACE);
  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_2D,LDRSceneFBO.TextureHandles[0]);
  AntialiasingShader.Bind;
  glUniform1i(AntialiasingShader.uTexture,0);
  glBindVertexArray(EmptyVertexArrayObjectHandle);
  glDrawArrays(GL_TRIANGLES,0,3);
  glBindVertexArray(0);
  AntialiasingShader.Unbind;
  glDisable(GL_BLEND);
  ConsoleInstance.Draw(DeltaTime,ViewPortX,ViewPortY,ViewPortWidth,ViewPortHeight);
  glEnable(GL_DEPTH_TEST);
 end;
 if GPUTimeState=2 then begin
  glEndQuery(GL_TIME_ELAPSED);
  GPUTimeState:=3;
 end;
 t1:=SDL_GetPerformanceCounter;
{$ifdef profiledebug}
 write(#13,'CPU time: ',(t1-t0)/SDL_GetPerformanceFrequency:8:5,'    GPU time: ',GPUTimeElapsed/1e9:8:5);
{$endif}
end;

procedure Resize(NewWidth,NewHeight:longint);
var Factor:int64;
    rw,rh:longint;
begin
 ScreenWidth:=NewWidth;
 ScreenHeight:=NewHeight;
 if true then begin
  ViewPortX:=0;
  ViewPortY:=0;
  ViewPortWidth:=ScreenWidth;
  ViewPortHeight:=ScreenHeight;
 end else begin
  Factor:=int64($100000000);
  rw:=VirtualCanvasWidth;
  rh:=VirtualCanvasHeight;
  while (max(rw,rh)>=128) and (((rw or rh)<>0) and (((rw or rh) and 1)=0)) do begin
   rw:=rw shr 1;
   rh:=rh shr 1;
  end;
  if ScreenWidth<ScreenHeight then begin
   ViewPortWidth:=((ScreenHeight*rw)+((rh+1) div 2)) div rh;
   ViewPortHeight:=ScreenHeight;
   if ViewPortWidth>ScreenWidth then begin
    Factor:=((ScreenWidth*int64($100000000))+(ViewPortWidth div 2)) div ViewPortWidth;
   end;
  end else begin
   ViewPortWidth:=ScreenWidth;
   ViewPortHeight:=((ScreenWidth*rh)+((rw+1) div 2)) div rw;
   if ViewPortHeight>ScreenHeight then begin
    Factor:=((ScreenHeight*int64($100000000))+(ViewPortHeight div 2)) div ViewPortHeight;
   end;
  end;
  if Factor<int64($100000000) then begin
   ViewPortWidth:=((ViewPortWidth*Factor)+int64($80000000)) div int64($100000000);
   ViewPortHeight:=((ViewPortHeight*Factor)+int64($80000000)) div int64($100000000);
  end;
  if ViewPortWidth<rw then begin
   ViewPortWidth:=rw;
  end;
  if ViewPortHeight<rh then begin
   ViewPortHeight:=rh;
  end;
  ViewPortX:=((ScreenWidth-ViewPortWidth)+1) div 2;
  ViewPortY:=((ScreenHeight-ViewPortHeight)+1) div 2;
 end;
end;

procedure UpdateTitle;
var s:TPasGLTFUTF8String;
begin
 s:=Title+' - Version '+Version+' - '+Copyright+' - F8 = console';
 if length(CurrentFileName)>0 then begin
  s:=s+' - '+ExtractFileName(CurrentFileName);
  if assigned(GLTFOpenGL) then begin
   s:=s+' - Animation: '+IntToStr(AnimationIndex+1)+' / '+IntToStr(length(GLTFOpenGL.Animations));
   begin
    s:=s+' - Automatic rotation: ';
    if AutomaticRotate then begin
     s:=s+' on';
    end else begin
     s:=s+' off';
    end;
   end;
   begin
    s:=s+' - ';
    if Fullscreen then begin
     s:=s+' Fullscreen';
    end else begin
     s:=s+' Window mode';
    end;
   end;
   begin
    s:=s+' - Mouse action: ';
    if ButtonLeftPressed then begin
     s:=s+' Rotate and zoom';
    end else begin
     s:=s+' None';
    end;
   end;
  end;
 end;
 SDL_SetWindowTitle(SurfaceWindow,PAnsiChar(s));
end;

procedure ConsoleCommand(const aCommandLine:RawByteString);
var CommandLineLength,CommandLinePosition,Value,Index:int32;
    Command:RawByteString;
begin

 CommandLineLength:=length(aCommandLine);

 CommandLinePosition:=1;

 while (CommandLinePosition<=CommandLineLength) and (aCommandLine[CommandLinePosition] in [#0..#32]) do begin
  inc(CommandLinePosition);
 end;

 Command:='';
 while (CommandLinePosition<=CommandLineLength) and not (aCommandLine[CommandLinePosition] in [#0..#32]) do begin
  Command:=Command+aCommandLine[CommandLinePosition];
  inc(CommandLinePosition);
 end;

 while (CommandLinePosition<=CommandLineLength) and (aCommandLine[CommandLinePosition] in [#0..#32]) do begin
  inc(CommandLinePosition);
 end;

 if Command='help' then begin
  ConsoleInstance.Lines.Add('');
  ConsoleInstance.Lines.Add(#0#14+'Available commands:');
  ConsoleInstance.Lines.Add('');
  ConsoleInstance.Lines.Add(#0#11+'help                       '+#0#10+'This help');
  ConsoleInstance.Lines.Add(#0#11+'exit                       '+#0#10+'Exit the viewer');
  ConsoleInstance.Lines.Add(#0#11+'quit                       '+#0#10+'Exit the viewer');
  ConsoleInstance.Lines.Add(#0#11+'listscenes                 '+#0#10+'List all avilable scenes');
  ConsoleInstance.Lines.Add(#0#11+'setscene '+#0#9+'x'+#0#11+'                 '+#0#10+'Set scene to '+#0#9+'x'+#0#11+' (number)');
  ConsoleInstance.Lines.Add(#0#11+'listanimations             '+#0#10+'List all avilable animations');
  ConsoleInstance.Lines.Add(#0#11+'setanimation '+#0#9+'x'+#0#11+'             '+#0#10+'Set animation to '+#0#9+'x'+#0#11+' (number)');
  ConsoleInstance.Lines.Add(#0#11+'resetanimation             '+#0#10+'Reset animation');
  ConsoleInstance.Lines.Add(#0#11+'resetcamera                '+#0#10+'Reset camera');
  ConsoleInstance.Lines.Add(#0#11+'setjoints '+#0#9+'x'+#0#11+'                '+#0#10+'Set joints to '+#0#9+'x'+#0#11+' (zero = off, non-zero = on)');
  ConsoleInstance.Lines.Add(#0#11+'setshadows '+#0#9+'x'+#0#11+'               '+#0#10+'Set shadows to '+#0#9+'x'+#0#11+' (zero = off, non-zero = on)');
  ConsoleInstance.Lines.Add(#0#11+'load '+#0#9+'x'+#0#11+'                     '+#0#10+'Load '+#0#9+'x'+#0#11+' (filename)');
  ConsoleInstance.Lines.Add(#0#11+'unload                     '+#0#10+'Unload current GLTF/GLB object');
  ConsoleInstance.Lines.Add('');
 end else if (Command='exit') or (Command='quit') then begin
  SDLRunning:=false;
 end else if (Command='listscenes') then begin
  if assigned(GLTFOpenGL) then begin
   for Index:=0 to length(GLTFOpenGL.Scenes)-1 do begin
    ConsoleInstance.Lines.Add(#0#11+IntToStr(Index+1)+'. '+#0#10+GLTFOpenGL.Scenes[Index].Name);
   end;
  end;
 end else if Command='setscene' then begin
  Value:=0;
  while (CommandLinePosition<=CommandLineLength) and (aCommandLine[CommandLinePosition] in ['0'..'9']) do begin
   Value:=(Value*10)+(ord(aCommandLine[CommandLinePosition])-ord('0'));
   inc(CommandLinePosition);
  end;
  LastAnimationIndex:=-2;
  SceneIndex:=Value-1;
  if assigned(GLTFOpenGL) then begin
   AnimationBeginTime:=GLTFOpenGL.GetAnimationBeginTime(AnimationIndex);
   AnimationEndTime:=GLTFOpenGL.GetAnimationEndTime(AnimationIndex);
  end;
  AnimationTime:=0.0;
 end else if (Command='listanimations') then begin
  ConsoleInstance.Lines.Add(#0#11+'0. '+#0#10+'Static pose');
  if assigned(GLTFOpenGL) then begin
   for Index:=0 to length(GLTFOpenGL.Animations)-1 do begin
    ConsoleInstance.Lines.Add(#0#11+IntToStr(Index+1)+'. '+#0#10+GLTFOpenGL.Animations[Index].Name);
   end;
  end;
 end else if Command='setanimation' then begin
  Value:=0;
  while (CommandLinePosition<=CommandLineLength) and (aCommandLine[CommandLinePosition] in ['0'..'9']) do begin
   Value:=(Value*10)+(ord(aCommandLine[CommandLinePosition])-ord('0'));
   inc(CommandLinePosition);
  end;
  LastAnimationIndex:=-2;
  AnimationIndex:=Value-1;
  if assigned(GLTFOpenGL) then begin
   AnimationBeginTime:=GLTFOpenGL.GetAnimationBeginTime(AnimationIndex);
   AnimationEndTime:=GLTFOpenGL.GetAnimationEndTime(AnimationIndex);
  end;
  AnimationTime:=0.0;
 end else if Command='resetanimation' then begin
  AnimationTime:=0.0;
 end else if Command='resetcamera' then begin
  ResetCamera;
 end else if Command='setjoints' then begin
  Value:=0;
  while (CommandLinePosition<=CommandLineLength) and (aCommandLine[CommandLinePosition] in ['0'..'9']) do begin
   Value:=(Value*10)+(ord(aCommandLine[CommandLinePosition])-ord('0'));
   inc(CommandLinePosition);
  end;
  ShowJoints:=Value<>0;
 end else if Command='setshadows' then begin
  Value:=0;
  while (CommandLinePosition<=CommandLineLength) and (aCommandLine[CommandLinePosition] in ['0'..'9']) do begin
   Value:=(Value*10)+(ord(aCommandLine[CommandLinePosition])-ord('0'));
   inc(CommandLinePosition);
  end;
  Shadows:=Value<>0;
 end else if Command='load' then begin
  InputFileName:=copy(aCommandLine,CommandLinePosition,(CommandLineLength-CommandLinePosition)+1);
 end else if Command='unload' then begin
  FreeAndNil(GLTFInstance);
  if assigned(GLTFOpenGL) then begin
   GLTFOpenGL.Unload;
   FreeAndNil(GLTFOpenGL);
  end;
  CurrentFileName:='';
  UpdateTitle;
 end else begin
  ConsoleInstance.Lines.Add(#0#12'Unknown command '#0#14'"'#0#13+Command+#0#14'"'#0#12'');
 end;

end;

procedure MainLoop;
var RootPath,TextureFileName:string;
    s:ansistring;
    c:ansichar;
    p:pansichar;
    TempScale:TPasGLTFFloat;
begin

 ConsoleInstance.Lines.Add(#0#15+Title);
 ConsoleInstance.Lines.Add(#0#15+'Version '+Version);
 ConsoleInstance.Lines.Add(#0#15+Copyright);
 ConsoleInstance.Lines.Add('');
 ConsoleInstance.Lines.Add(#0#14'  OpenGL vendor: '+GLGetString(GL_VENDOR));
 ConsoleInstance.Lines.Add(#0#14'OpenGL renderer: '+GLGetString(GL_RENDERER));
 ConsoleInstance.Lines.Add(#0#14' OpenGL version: '+GLGetString(GL_VERSION));
 ConsoleInstance.Lines.Add('');
 ConsoleInstance.Lines.Add(#0#12+'Available key shortcuts:');
 ConsoleInstance.Lines.Add('');
 ConsoleInstance.Lines.Add(#0#11'b '#0#14'/'#0#11' n              '#0#10+'Previous / next animation');
 ConsoleInstance.Lines.Add(#0#11'j                  '#0#10+'Toggle joints');
 ConsoleInstance.Lines.Add(#0#11'l                  '#0#10+'Toggle shadows');
 ConsoleInstance.Lines.Add(#0#11'r                  '#0#10+'Reset camera');
 ConsoleInstance.Lines.Add(#0#11't                  '#0#10+'Reset animation');
 ConsoleInstance.Lines.Add(#0#11'Alt+Return         '#0#10+'Toggle fullscreen');
 ConsoleInstance.Lines.Add(#0#11'Space              '#0#10+'Toggle automatic rotation');
 ConsoleInstance.Lines.Add('');
 ConsoleInstance.Lines.Add(#0#12'Use the '#0#14'"'#0#13'help'#0#14'"'#0#12' command for help...');
 ConsoleInstance.Lines.Add('');

 ConsoleCommandHook:=ConsoleCommand;

 SDLRunning:=true;
 while SDLRunning do begin

  while SDL_PollEvent(@Event)<>0 do begin
   case Event.type_ of
    SDL_QUITEV,SDL_APP_TERMINATING:begin
     SDLRunning:=false;
     break;
    end;
    SDL_APP_WILLENTERBACKGROUND:begin
     //SDL_PauseAudio(1);
    end;
    SDL_APP_DIDENTERFOREGROUND:begin
     //SDL_PauseAudio(0);
    end;
    SDL_RENDER_TARGETS_RESET,SDL_RENDER_DEVICE_RESET:begin
    end;
    SDL_KEYDOWN:begin
     if ConsoleInstance.Focus then begin
      case Event.key.keysym.sym of
       SDLK_LEFT:begin
        ConsoleInstance.KeyLeft;
       end;
       SDLK_RIGHT:begin
        ConsoleInstance.KeyRight;
       end;
       SDLK_UP:begin
        ConsoleInstance.KeyUp;
       end;
       SDLK_DOWN:begin
        ConsoleInstance.KeyDown;
       end;
       SDLK_BACKSPACE:begin
        ConsoleInstance.KeyBackspace;
       end;
       SDLK_DELETE:begin
        ConsoleInstance.KeyDelete;
       end;
       SDLK_HOME:begin
        ConsoleInstance.KeyBegin;
       end;
       SDLK_END:begin
        ConsoleInstance.KeyEnd;
       end;
       SDLK_V:begin
        if (Event.key.keysym.modifier and (KMOD_LCTRL or KMOD_RCTRL))<>0 then begin
         p:=SDL_GetClipboardText;
         if assigned(p) then begin
          try
           s:=p;
           for c in s do begin
            ConsoleInstance.KeyChar(c);
           end;
          finally
           SDL_free(p);
          end;
         end;
        end;
       end;
       SDLK_INSERT:begin
        if (Event.key.keysym.modifier and (KMOD_LSHIFT or KMOD_RSHIFT))<>0 then begin
         p:=SDL_GetClipboardText;
         if assigned(p) then begin
          try
           s:=p;
           for c in s do begin
            ConsoleInstance.KeyChar(c);
           end;
          finally
           SDL_free(p);
          end;
         end;
        end;
       end;
      end;
     end else begin
      case Event.key.keysym.sym of
       SDLK_B:begin
        LastAnimationIndex:=-2;
        dec(AnimationIndex);
        if (AnimationIndex<-1) and assigned(GLTFOpenGL) then begin
         AnimationIndex:=length(GLTFOpenGL.Animations)-1;
        end;
        if assigned(GLTFOpenGL) then begin
         AnimationBeginTime:=GLTFOpenGL.GetAnimationBeginTime(AnimationIndex);
         AnimationEndTime:=GLTFOpenGL.GetAnimationEndTime(AnimationIndex);
        end;
        AnimationTime:=0.0;
        UpdateTitle;
       end;
       SDLK_N:begin
        LastAnimationIndex:=-2;
        inc(AnimationIndex);
        if assigned(GLTFOpenGL) and (AnimationIndex>=length(GLTFOpenGL.Animations)) then begin
         AnimationIndex:=-1;
        end;
        if assigned(GLTFOpenGL) then begin
         AnimationBeginTime:=GLTFOpenGL.GetAnimationBeginTime(AnimationIndex);
         AnimationEndTime:=GLTFOpenGL.GetAnimationEndTime(AnimationIndex);
        end;
        AnimationTime:=0.0;
        UpdateTitle;
       end;
       SDLK_T:begin
        AnimationTime:=0.0;
        UpdateTitle;
       end;
       SDLK_M:begin
        WrapCursor:=not WrapCursor;
        SDL_SetRelativeMouseMode(ord(WrapCursor or FullScreen) and 1);
        UpdateTitle;
       end;
       SDLK_R:begin
        ResetCamera;
        UpdateTitle;
       end;
       SDLK_L:begin
        Shadows:=not Shadows;
       end;
       SDLK_J:begin
        ShowJoints:=not ShowJoints;
       end;
      end;
     end;
     case Event.key.keysym.sym of
      SDLK_ESCAPE:begin
//     BackKey;
       if ConsoleInstance.Focus then begin
        ConsoleInstance.KeyEscape;
       end else begin
        SDLRunning:=false;
        break;
       end;
      end;
      SDLK_F2:begin
       DumpAnimationJoints;
      end;
      SDLK_F8,SDLK_CARET,SDLK_BACKQUOTE:begin
       ConsoleInstance.Focus:=not ConsoleInstance.Focus;
      end;
      SDLK_SPACE:begin
       if not ConsoleInstance.Focus then begin
        AutomaticRotate:=not AutomaticRotate;
        UpdateTitle;
       end;
      end;
      SDLK_RETURN:begin
       if (Event.key.keysym.modifier and ((KMOD_LALT or KMOD_RALT) or (KMOD_LMETA or KMOD_RMETA)))<>0 then begin
        FullScreen:=not FullScreen;
        if FullScreen then begin
         SDL_SetWindowFullscreen(SurfaceWindow,SDL_WINDOW_FULLSCREEN_DESKTOP);
        end else begin
         SDL_SetWindowFullscreen(SurfaceWindow,0);
        end;
        SDL_ShowCursor(ord(not FullScreen) and 1);
        SDL_SetRelativeMouseMode(ord(WrapCursor or FullScreen) and 1);
       end else if ConsoleInstance.Focus then begin
        ConsoleInstance.KeyEnter;
       end;
       UpdateTitle;
      end;
      SDLK_F4:begin
       if (Event.key.keysym.modifier and ((KMOD_LALT or KMOD_RALT) or (KMOD_LMETA or KMOD_RMETA)))<>0 then begin
        SDLRunning:=false;
        break;
       end;
      end;
     end;
    end;
    SDL_KEYUP:begin
    end;
    SDL_TEXTINPUT:begin
     if ConsoleInstance.Focus then begin
      if (Event.tedit.text[0] in ([$20..$7f]-[ord('^'),ord('`')])) and (Event.tedit.text[1]=0) then begin
       ConsoleInstance.KeyChar(ansichar(byte(Event.tedit.text[0] and $ff)));
      end;
     end;
    end;
    SDL_DROPFILE:begin
     if assigned(Event.drop.FileName) then begin
      try
       InputFileName:=Event.drop.FileName;
      finally
       SDL_free(Event.drop.FileName);
      end;
     end;
    end;
    SDL_WINDOWEVENT:begin
     case event.window.event of
      SDL_WINDOWEVENT_RESIZED:begin
       ScreenWidth:=event.window.Data1;
       ScreenHeight:=event.window.Data2;
       Resize(ScreenWidth,ScreenHeight);
      end;
     end;
    end;
    SDL_MOUSEMOTION:begin
     if ButtonLeftPressed then begin
      if (event.motion.xrel<>0) or (event.motion.yrel<>0) then begin
       CameraRotationX:=frac(CameraRotationX+(1.0-(event.motion.xrel*(1.0/ScreenWidth))));
       CameraRotationY:=frac(CameraRotationY+(1.0-(event.motion.yrel*(1.0/ScreenHeight))));
      end;
     end;
    end;
    SDL_MOUSEWHEEL:begin
     ZoomLevel:=Max(1e-4,ZoomLevel+((event.wheel.x+event.wheel.y)*0.1));
    end;
    SDL_MOUSEBUTTONDOWN:begin
     case event.button.button of
      SDL_BUTTON_LEFT:begin
       ButtonLeftPressed:=true;
       UpdateTitle;
      end;
      SDL_BUTTON_RIGHT:begin
      end;
     end;
    end;
    SDL_MOUSEBUTTONUP:begin
     case event.button.button of
      SDL_BUTTON_LEFT:begin
       ButtonLeftPressed:=false;
       UpdateTitle;
      end;
      SDL_BUTTON_RIGHT:begin
      end;
     end;
    end;
   end;
  end;

  Time:=(SDL_GetPerformanceCounter-StartPerformanceCounter)/SDL_GetPerformanceFrequency;

  if FirstTime then begin
   FirstTime:=false;
   DeltaTime:=0.0;
  end else begin
   DeltaTime:=Min(Max(Time-LastTime,0.0),1.0);
  end;

  LastTime:=Time;

  begin
   // 1 1/3 % (quadratically total-pixel-count-wise) super-sampling on top on FXAA
   TempScale:=sqrt(1.33333333);
   SceneFBOWidth:=round(ViewPortWidth*TempScale);
   SceneFBOHeight:=round(ViewPortHeight*TempScale);
   if (HDRSceneFBO.Width<>SceneFBOWidth) or
      (HDRSceneFBO.Height<>SceneFBOHeight) then begin
    DestroyFrameBuffer(HDRSceneFBO);
    HDRSceneFBO.Width:=SceneFBOWidth;
    HDRSceneFBO.Height:=SceneFBOHeight;
    CreateFrameBuffer(HDRSceneFBO);
   end;
   if (LDRSceneFBO.Width<>SceneFBOWidth) or
      (LDRSceneFBO.Height<>SceneFBOHeight) then begin
    DestroyFrameBuffer(LDRSceneFBO);
    LDRSceneFBO.Width:=SceneFBOWidth;
    LDRSceneFBO.Height:=SceneFBOHeight;
    CreateFrameBuffer(LDRSceneFBO);
   end;
  end;
  if AutomaticRotate then begin
   CameraRotationX:=frac(CameraRotationX+(1.0-(DeltaTime*0.015625)));
  end;

  Draw;

  SDL_GL_SwapWindow(SurfaceWindow);

  AnimationTime:=AnimationTime+DeltaTime;

  if length(InputFileName)>0 then begin
   try
    FreeAndNil(GLTFInstance);
    if assigned(GLTFOpenGL) then begin
     GLTFOpenGL.Unload;
     FreeAndNil(GLTFOpenGL);
    end;
    FileName:=ExpandFileName(InputFileName);
    try
     GLTFOpenGL:=TGLTFOpenGL.Create;
     GLTFOpenGL.RootPath:=IncludeTrailingPathDelimiter(ExtractFilePath(FileName));
     GLTFOpenGL.LoadFromFile(FileName);
     GLTFOpenGL.Upload;
     GLTFInstance:=GLTFOpenGL.AcquireInstance;
     CurrentFileName:=FileName;
    except
     on e:EPasGLTF do begin
      s:=E.ClassName+': '+E.Message;
      SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR or
                               SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT,
                               PAnsiChar('Exception'),
                               PAnsiChar(s),
                               SurfaceWindow);
      FreeAndNil(GLTFInstance);
      GLTFOpenGL.Unload;
      FreeAndNil(GLTFOpenGL);
      CurrentFileName:='';
     end;
     on e:Exception do begin
      s:=E.ClassName+': '+E.Message;
      SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR or
                               SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT,
                               PAnsiChar('Exception'),
                               PAnsiChar(s),
                               SurfaceWindow);
      FreeAndNil(GLTFInstance);
      GLTFOpenGL.Unload;
      FreeAndNil(GLTFOpenGL);
      CurrentFileName:='';
      raise;
     end;
    end;
    ResetCamera;
    SceneIndex:=GLTFOpenGL.Scene;
    LastAnimationIndex:=-2;
    AnimationIndex:=0;
    if assigned(GLTFOpenGL) then begin
     AnimationBeginTime:=GLTFOpenGL.GetAnimationBeginTime(AnimationIndex);
     AnimationEndTime:=GLTFOpenGL.GetAnimationEndTime(AnimationIndex);
    end;
    AnimationTime:=0.0;
    UpdateTitle;
   finally
    InputFileName:='';
   end;
  end;

 end;
end;

procedure Entry;
var Index,MultiSampleCounter,DepthBufferSizeCounter,Temp:int32;
    MemoryStream:TMemoryStream;
    ImageData:TPasGLTFPointer;
    ImageWidth,ImageHeight:TPasGLTFInt32;
    OK:boolean;
    Major,Minor:glInt;
    RootPath,TextureFileName:string;
    ShadowMapFBO:PFBO;
    Status:glEnum;
begin

 if ParamCount>0 then begin
  InputFileName:=TPasGLTFUTF8String(ParamStr(1));
 end;

 if SDL_Init(SDL_INIT_EVERYTHING)<0 then begin
  exit;
 end;

 ScreenWidth:=1280;
 ScreenHeight:=720;

 if SDL_GetCurrentDisplayMode(0,@SDLDisplayMode)=0 then begin
  BestWidth:=SDLDisplayMode.w;
  BestHeight:=SDLDisplayMode.h;
 end else begin
  BestWidth:=640;
  BestHeight:=360;
 end;

 if ScreenWidth>=((BestWidth*90) div 100) then begin
  Temp:=((BestWidth*90) div 100);
  ScreenHeight:=(ScreenHeight*Temp) div ScreenWidth;
  ScreenWidth:=Temp;
 end;
 if ScreenHeight>=((BestHeight*90) div 100) then begin
  Temp:=((BestHeight*90) div 100);
  ScreenWidth:=(ScreenWidth*Temp) div ScreenHeight;
  ScreenHeight:=Temp;
 end;

 SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION,4);
 SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION,1);
 SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK,SDL_GL_CONTEXT_PROFILE_CORE);
 SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS,0);
 SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS,0);
 SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES,0);
 SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER,1);
 SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE,0);
 SDL_GL_SetSwapInterval(1);

 Resize(ScreenWidth,ScreenHeight);

 VideoFlags:=0;
 if paramstr(1)='f' then begin
  VideoFlags:=VideoFlags or SDL_WINDOW_FULLSCREEN_DESKTOP;
  Fullscreen:=true;
  WrapCursor:=true;
  ScreenWidth:=1280;
  ScreenHeight:=720;
 end;
 for Index:=0 downto 0 do begin
  DepthBufferSizeCounter:=3;
  MultiSampleCounter:=0;
 // writeln(DepthBufferSizeCounter shl 3,' ',1 shl MultiSampleCounter);
  SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE,DepthBufferSizeCounter shl 3);
  if MultiSampleCounter=0 then begin
   SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS,0);
   SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES,0);
  end else begin
   SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS,1);
   SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES,1 shl MultiSampleCounter);
  end;
  SurfaceWindow:=SDL_CreateWindow(pansichar(Title+' - Version '+Version+' - '+Copyright+' - F8 = console - Drop a .GLB/.GLTF file into this window'),(BestWidth-ScreenWidth) div 2,(BestHeight-ScreenHeight) div 2,ScreenWidth,ScreenHeight,SDL_WINDOW_OPENGL or SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE or VideoFlags);
  if assigned(SurfaceWindow) then begin
   SDL_EventState(SDL_DROPFILE,SDL_ENABLE);
   SurfaceContext:=SDL_GL_CreateContext(SurfaceWindow);
   if not assigned(SurfaceContext) then begin
    SDL_DestroyWindow(SurfaceWindow);
    SurfaceWindow:=nil;
    if Index=0 then begin
     exit;
    end else begin
     continue;
    end;
   end;
  end else begin
   exit;
  end;
  OK:=false;
  if InitOpenGL then begin
   ReadOpenGLCore;
   ReadImplementationProperties;
   ReadExtensions;
   OK:=true;
  end;
  if not (OK and assigned(glGenVertexArrays)) then begin
   if assigned(SurfaceContext) then begin
    SDL_GL_DeleteContext(SurfaceContext);
    SurfaceContext:=nil;
   end;
   SDL_DestroyWindow(SurfaceWindow);
   SurfaceWindow:=nil;
   if Index=0 then begin
    exit;
   end else begin
    continue;
   end;
  end;
  break;
 end;

 glGetIntegerv(GL_MAJOR_VERSION,@Major);
 glGetIntegerv(GL_MINOR_VERSION,@Minor);

 if ((Major>4) or ((Major=4) and (Minor>=5))) or
    (GL_ARB_clip_control and
     GL_ARB_shader_storage_buffer_object and
     ((Major>4) or ((Major=4) and (Minor>=1)))) then begin

  SDL_GL_SetSwapInterval(1);

  SDL_ShowCursor(ord(not FullScreen) and 1);

  SDL_SetRelativeMouseMode(ord(WrapCursor or FullScreen) and 1);

  StartPerformanceCounter:=SDL_GetPerformanceCounter;

  glEnable(GL_TEXTURE_CUBE_MAP_SEAMLESS);

  glGetIntegerv(GL_MAX_SAMPLES,@MultisampledShadowMapSamples);
  if MultisampledShadowMapSamples>8 then begin
   MultisampledShadowMapSamples:=8;
  end;

//LightDirection:=Vector3Norm(Vector3(0.0,-1.0,0.0));
//LightDirection:=Vector3Norm(Vector3(0.5,-0.25,-1.0));
//
  LightDirection:=Vector3Norm(Vector3(0.5,-1.0,-1.0));

  glGenVertexArrays(1,@EmptyVertexArrayObjectHandle);
  try

   BRDFLUTShader:=TBRDFLUTShader.Create;
   try

    FillChar(BRDFLUTFBO,SizeOf(TFBO),#0);
    BRDFLUTFBO.Width:=512;
    BRDFLUTFBO.Height:=512;
    BRDFLUTFBO.Depth:=0;
    BRDFLUTFBO.Textures:=1;
    BRDFLUTFBO.TextureFormats[0]:=GL_TEXTURE_RGBA16F;
    BRDFLUTFBO.Format:=GL_TEXTURE_RGBA16F;
    BRDFLUTFBO.SWrapMode:=wmGL_CLAMP_TO_EDGE;
    BRDFLUTFBO.TWrapMode:=wmGL_CLAMP_TO_EDGE;
    BRDFLUTFBO.RWrapMode:=wmGL_CLAMP_TO_EDGE;
    BRDFLUTFBO.MinFilterMode:=fmGL_LINEAR;
    BRDFLUTFBO.MagFilterMode:=fmGL_LINEAR;
    BRDFLUTFBO.Flags:=0;
    CreateFrameBuffer(BRDFLUTFBO);
    glBindFrameBuffer(GL_FRAMEBUFFER,BRDFLUTFBO.FBOs[0]);
    glDrawBuffer(GL_COLOR_ATTACHMENT0);
    glViewport(0,0,BRDFLUTFBO.Width,BRDFLUTFBO.Height);
    glClearColor(0.0,0.0,0.0,0.0);
    glClearDepth(1.0);
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glBindVertexArray(EmptyVertexArrayObjectHandle);
    BRDFLUTShader.Bind;
    glDrawArrays(GL_TRIANGLES,0,3);
    BRDFLUTShader.Unbind;
    glBindVertexArray(0);
    glBindFrameBuffer(GL_FRAMEBUFFER,0);

   finally
    FreeAndNil(BRDFLUTShader);
   end;

   try

    EnvMapGenShader:=TEnvMapGenShader.Create(false);//lowercase(trim(GLGetString(GL_VENDOR)))<>'intel');
    try

     if true then begin
      ImageWidth:=1024;
      ImageHeight:=1024;
      EnvMapFBO.Width:=ImageWidth;
      EnvMapFBO.Height:=ImageHeight;
      EnvMapFBO.Depth:=0;
      EnvMapFBO.Textures:=1;
      EnvMapFBO.TextureFormats[0]:=GL_TEXTURE_RGBA16F;
      EnvMapFBO.Format:=GL_TEXTURE_RGBA16F;
      EnvMapFBO.SWrapMode:=wmGL_REPEAT;
      EnvMapFBO.TWrapMode:=wmGL_REPEAT;
      EnvMapFBO.RWrapMode:=wmGL_REPEAT;
      EnvMapFBO.MinFilterMode:=fmGL_LINEAR_MIPMAP_LINEAR;
      EnvMapFBO.MagFilterMode:=fmGL_LINEAR;
      EnvMapFBO.Flags:=FBOFlagMipMap or FBOFlagCubeMap;
      CreateFrameBuffer(EnvMapFBO);
      EnvMapGenShader.Bind;
      glUniform3fv(EnvMapGenShader.uLightDirection,1,@LightDirection);
      glActiveTexture(GL_TEXTURE0);
      glBindFrameBuffer(GL_FRAMEBUFFER,EnvMapFBO.FBOs[Index]);
      glDrawBuffer(GL_COLOR_ATTACHMENT0);
      glViewport(0,0,EnvMapFBO.Width shr Index,EnvMapFBO.Height shr Index);
      glClearColor(0.0,0.0,0.0,0.0);
      glClearDepth(1.0);
      glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
      glDisable(GL_DEPTH_TEST);
      glDisable(GL_CULL_FACE);
      glCullFace(GL_BACK);
      glBindVertexArray(EmptyVertexArrayObjectHandle);
      glDrawArrays(GL_TRIANGLES,0,18);
      glBindVertexArray(0);
      glBindFrameBuffer(GL_FRAMEBUFFER,0);
      EnvMapTextureHandle:=EnvMapFBO.TextureHandles[0];
      EnvMapFBO.TextureHandles[0]:=0;
      DestroyFrameBuffer(EnvMapFBO);
      EnvMapGenShader.Unbind;
     end else begin
      EnvMapTextureHandle:=0;
      glGenTextures(1,@EnvMapTextureHandle);
      glBindTexture(GL_TEXTURE_CUBE_MAP,EnvMapTextureHandle);
      glTexParameteri(GL_TEXTURE_CUBE_MAP,GL_TEXTURE_WRAP_S,GL_REPEAT);
      glTexParameteri(GL_TEXTURE_CUBE_MAP,GL_TEXTURE_WRAP_T,GL_REPEAT);
      glTexParameteri(GL_TEXTURE_CUBE_MAP,GL_TEXTURE_WRAP_R,GL_REPEAT);
      glTexParameteri(GL_TEXTURE_CUBE_MAP,GL_TEXTURE_MIN_FILTER,GL_LINEAR_MIPMAP_LINEAR);
      glTexParameteri(GL_TEXTURE_CUBE_MAP,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
      RootPath:=IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)))+'envmap');
      for Index:=0 to 5 do begin
       MemoryStream:=TMemoryStream.Create;
       try
        TextureFileName:=RootPath+CubeMapFileNames[Index]+'.png';
        if not FileExists(TextureFileName) then begin
         TextureFileName:=RootPath+CubeMapFileNames[Index]+'.jpeg';
         if not FileExists(TextureFileName) then begin
          TextureFileName:=RootPath+CubeMapFileNames[Index]+'.jpg';
         end;
        end;
        MemoryStream.LoadFromFile(TextureFileName);
        ImageWidth:=2048;
        ImageHeight:=2048;
        if LoadImage(MemoryStream.Memory,MemoryStream.Size,ImageData,ImageWidth,ImageHeight) then begin
         try
          glTexImage2D(CubeMapTexs[Index],0,GL_SRGB8_ALPHA8,ImageWidth,ImageHeight,0,GL_RGBA,GL_UNSIGNED_BYTE,ImageData);
        finally
          FreeMem(ImageData);
         end;
        end;
       finally
        MemoryStream.Free;
       end;
      end;
     end;

     glBindTexture(GL_TEXTURE_CUBE_MAP,EnvMapTextureHandle);
     glTexParameteri(GL_TEXTURE_CUBE_MAP,GL_TEXTURE_BASE_LEVEL,0);
     glTexParameteri(GL_TEXTURE_CUBE_MAP,GL_TEXTURE_MAX_LEVEL,trunc(log2(Min(ImageWidth,ImageHeight))));
     glGenerateMipmap(GL_TEXTURE_CUBE_MAP);
     glBindTexture(GL_TEXTURE_CUBE_MAP,0);

     EnvMapFilterShader:=TEnvMapFilterShader.Create;
     try
      FillChar(EnvMapFBO,SizeOf(TFBO),#0);
      EnvMapFBO.Width:=ImageWidth;
      EnvMapFBO.Height:=ImageHeight;
      EnvMapFBO.Depth:=0;
      EnvMapFBO.Textures:=1;
      EnvMapFBO.TextureFormats[0]:=GL_TEXTURE_RGBA16F;
      EnvMapFBO.Format:=GL_TEXTURE_RGBA16F;
      EnvMapFBO.SWrapMode:=wmGL_REPEAT;
      EnvMapFBO.TWrapMode:=wmGL_REPEAT;
      EnvMapFBO.RWrapMode:=wmGL_REPEAT;
      EnvMapFBO.MinFilterMode:=fmGL_LINEAR_MIPMAP_LINEAR;
      EnvMapFBO.MagFilterMode:=fmGL_LINEAR;
      EnvMapFBO.Flags:=FBOFlagMipMap or FBOFlagMipMapLevelWiseFill or FBOFlagCubeMap;
      CreateFrameBuffer(EnvMapFBO);
      EnvMapFilterShader.Bind;
      for Index:=0 to EnvMapFBO.WorkMaxLevel do begin
       glActiveTexture(GL_TEXTURE0);
       if Index=0 then begin
        glBindTexture(GL_TEXTURE_CUBE_MAP,EnvMapTextureHandle);
       end else begin
        glBindTexture(GL_TEXTURE_CUBE_MAP,EnvMapFBO.TextureHandles[0]);
       end;
       glUniform1i(EnvMapFilterShader.uTexture,0);
       glUniform1i(EnvMapFilterShader.uMipMapLevel,Index);
       glUniform1i(EnvMapFilterShader.uMaxMipMapLevel,EnvMapFBO.WorkMaxLevel);
       glBindFrameBuffer(GL_FRAMEBUFFER,EnvMapFBO.FBOs[Index]);
       glDrawBuffer(GL_COLOR_ATTACHMENT0);
       glViewport(0,0,EnvMapFBO.Width shr Index,EnvMapFBO.Height shr Index);
       glClearColor(0.0,0.0,0.0,0.0);
       glClearDepth(1.0);
       glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
       glDisable(GL_DEPTH_TEST);
       glDisable(GL_CULL_FACE);
       glCullFace(GL_BACK);
       glBindVertexArray(EmptyVertexArrayObjectHandle);
       glDrawArrays(GL_TRIANGLES,0,18);
       glBindVertexArray(0);
       glBindFrameBuffer(GL_FRAMEBUFFER,0);
      end;
      EnvMapFilterShader.Unbind;
     finally
      FreeAndNil(EnvMapFilterShader);
     end;

    finally
     FreeAndNil(EnvMapGenShader);
    end;

    try

     EnvMapDrawShader:=TEnvMapDrawShader.Create;
     try

      glGenFramebuffers(1,@MultisampledShadowMapFBO);
      glBindFramebuffer(GL_FRAMEBUFFER,MultisampledShadowMapFBO);

{     glDrawBuffer(GL_NONE);
      glReadBuffer(GL_NONE);}

      glGenTextures(1,@MultisampledShadowMapTexture);
      glBindTexture(GL_TEXTURE_2D_MULTISAMPLE,MultisampledShadowMapTexture);
      glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE,MultisampledShadowMapSamples,GL_R32F,ShadowMapSize,ShadowMapSize,true);
      glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D_MULTISAMPLE,MultisampledShadowMapTexture,0);

      glGenTextures(1,@MultisampledShadowMapDepthTexture);
      glBindTexture(GL_TEXTURE_2D_MULTISAMPLE,MultisampledShadowMapDepthTexture);
      glTexParameteri(GL_TEXTURE_2D_MULTISAMPLE,GL_DEPTH_TEXTURE_MODE,GL_LUMINANCE);
      glTexParameteri(GL_TEXTURE_2D_MULTISAMPLE,GL_TEXTURE_COMPARE_MODE,GL_NONE);
      glTexParameteri(GL_TEXTURE_2D_MULTISAMPLE,GL_TEXTURE_COMPARE_FUNC,GL_ALWAYS);
      glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE,MultisampledShadowMapSamples,GL_DEPTH_COMPONENT32F,ShadowMapSize,ShadowMapSize,true);
      glFramebufferTexture2D(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,GL_TEXTURE_2D_MULTISAMPLE,MultisampledShadowMapDepthTexture,0);
{
      glGenRenderbuffers(1,@MultisampledShadowMapDepthRenderBuffer);
      glBindRenderbuffer(GL_RENDERBUFFER,MultisampledShadowMapDepthRenderBuffer);
      glRenderbufferStorageMultisample(GL_RENDERBUFFER,MultisampledShadowMapSamples,GL_DEPTH_COMPONENT32F,ShadowMapSize,ShadowMapSize);
      glFramebufferRenderbuffer(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,GL_RENDERBUFFER,MultisampledShadowMapDepthRenderBuffer);
}
      Status:=glCheckFramebufferStatus(GL_FRAMEBUFFER);
      Assert(Status=GL_FRAMEBUFFER_COMPLETE);

      glBindFramebuffer(GL_FRAMEBUFFER,0);

      for Index:=Low(ShadowMapFBOs) to High(ShadowMapFBOs) do begin
       ShadowMapFBO:=@ShadowMapFBOs[Index];
       FillChar(ShadowMapFBO^,SizeOf(TFBO),#0);
       ShadowMapFBO^.Width:=ShadowMapSize;
       ShadowMapFBO^.Height:=ShadowMapSize;
       ShadowMapFBO^.Depth:=0;
       ShadowMapFBO^.Textures:=1;
       ShadowMapFBO^.TextureFormats[0]:=GL_TEXTURE_RGBA16US;
       ShadowMapFBO^.Format:=GL_TEXTURE_RGBA16US;
       ShadowMapFBO^.SWrapMode:=wmGL_CLAMP_TO_EDGE;
       ShadowMapFBO^.TWrapMode:=wmGL_CLAMP_TO_EDGE;
       ShadowMapFBO^.RWrapMode:=wmGL_CLAMP_TO_EDGE;
       ShadowMapFBO^.MinFilterMode:=fmGL_LINEAR;
       ShadowMapFBO^.MagFilterMode:=fmGL_LINEAR;
       if Index=0 then begin
        ShadowMapFBO^.Flags:=FBOFlagDepthBuffer;
       end else begin
        ShadowMapFBO^.Flags:=0;
       end;
       CreateFrameBuffer(ShadowMapFBO^);
      end;

      FillChar(HDRSceneFBO,SizeOf(TFBO),#0);
      HDRSceneFBO.Width:=ViewPortWidth;
      HDRSceneFBO.Height:=ViewPortHeight;
      HDRSceneFBO.Depth:=0;
      HDRSceneFBO.Textures:=1;
      HDRSceneFBO.TextureFormats[0]:=GL_TEXTURE_RGBA16F;
      HDRSceneFBO.Format:=GL_TEXTURE_RGBA16F;
      HDRSceneFBO.SWrapMode:=wmGL_CLAMP_TO_EDGE;
      HDRSceneFBO.TWrapMode:=wmGL_CLAMP_TO_EDGE;
      HDRSceneFBO.RWrapMode:=wmGL_CLAMP_TO_EDGE;
      HDRSceneFBO.MinFilterMode:=fmGL_LINEAR;
      HDRSceneFBO.MagFilterMode:=fmGL_LINEAR;
      HDRSceneFBO.Flags:=FBOFlagDepthBuffer;
      CreateFrameBuffer(HDRSceneFBO);
      try

       HDRToLDRShader:=THDRToLDRShader.Create;
       try

        FillChar(LDRSceneFBO,SizeOf(TFBO),#0);
        LDRSceneFBO.Width:=ViewPortWidth;
        LDRSceneFBO.Height:=ViewPortHeight;
        LDRSceneFBO.Depth:=0;
        LDRSceneFBO.Textures:=1;
        LDRSceneFBO.TextureFormats[0]:=GL_TEXTURE_RGBA8UB;
        LDRSceneFBO.Format:=GL_TEXTURE_RGBA8UB;
        LDRSceneFBO.SWrapMode:=wmGL_CLAMP_TO_EDGE;
        LDRSceneFBO.TWrapMode:=wmGL_CLAMP_TO_EDGE;
        LDRSceneFBO.RWrapMode:=wmGL_CLAMP_TO_EDGE;
        LDRSceneFBO.MinFilterMode:=fmGL_LINEAR;
        LDRSceneFBO.MagFilterMode:=fmGL_LINEAR;
        LDRSceneFBO.Flags:=FBOFlagDepthBuffer;
        CreateFrameBuffer(LDRSceneFBO);
        try

         ShadowMapMultisampleResolveShader:=TShadowMapMultisampleResolveShader.Create;
         try

          ShadowMapBlurShader:=TShadowMapBlurShader.Create;
          try

           AntialiasingShader:=TAntialiasingShader.Create;
           try

            try

             ShadowShaders[false,false]:=TShadingShader.Create(false,false,true);
             ShadowShaders[false,true]:=TShadingShader.Create(false,true,true);
             ShadowShaders[true,false]:=TShadingShader.Create(true,false,true);
             ShadowShaders[true,true]:=TShadingShader.Create(true,true,true);
             ShadingShaders[false,false]:=TShadingShader.Create(false,false,false);
             ShadingShaders[false,true]:=TShadingShader.Create(false,true,false);
             ShadingShaders[true,false]:=TShadingShader.Create(true,false,false);
             ShadingShaders[true,true]:=TShadingShader.Create(true,true,false);
             SolidColorShader:=TSolidColorShader.Create;
             try

              ExtendedBlitRectShader:=TExtendedBlitRectShader.Create;
              try

               ConsoleInstance:=TConsole.Create;
               try

                ConsoleInstance.Upload;

                try

                 glGenQueries(1,@TimeQueryHandle);
                 try

                  MainLoop;

                 finally
                  glDeleteQueries(1,@TimeQueryHandle);
                 end;

                except
                 on e:Exception do begin
                  SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR or
                                           SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT,
                                           PAnsiChar(ansistring(e.ClassName)),
                                           PAnsiChar(ansistring(e.Message)),
                                           SurfaceWindow);
                  raise e;
                 end;
                end;

               finally
                FreeAndNil(ConsoleInstance);
               end;

              finally
               FreeAndNil(ExtendedBlitRectShader);
              end;

             finally
              FreeAndNil(SolidColorShader);
              FreeAndNil(ShadingShaders[false,false]);
              FreeAndNil(ShadingShaders[false,true]);
              FreeAndNil(ShadingShaders[true,false]);
              FreeAndNil(ShadingShaders[true,true]);
              FreeAndNil(ShadowShaders[false,false]);
              FreeAndNil(ShadowShaders[false,true]);
              FreeAndNil(ShadowShaders[true,false]);
              FreeAndNil(ShadowShaders[true,true]);
             end;

            finally
             if assigned(GLTFOpenGL) then begin
              try
               FreeAndNil(GLTFInstance);
              finally
               try
                GLTFOpenGL.Unload;
               finally
                FreeAndNil(GLTFOpenGL);
               end;
              end;
             end;
            end;

           finally
            FreeAndNil(AntialiasingShader);
           end;

          finally
           FreeAndNil(ShadowMapBlurShader);
          end;

         finally
          FreeAndNil(ShadowMapMultisampleResolveShader);
         end;

        finally
         DestroyFrameBuffer(LDRSceneFBO);
        end;

       finally
        FreeAndNil(HDRToLDRShader);
       end;

      finally
       for Index:=Low(ShadowMapFBOs) to High(ShadowMapFBOs) do begin
        DestroyFrameBuffer(ShadowMapFBOs[Index]);
       end;
       glDeleteFramebuffers(1,@MultisampledShadowMapFBO);
//     glDeleteRenderbuffers(1,@MultisampledShadowMapDepthRenderBuffer);
       glDeleteTextures(1,@MultisampledShadowMapTexture);
       glDeleteTextures(1,@MultisampledShadowMapDepthTexture);
       DestroyFrameBuffer(HDRSceneFBO);
      end;

     finally
      EnvMapDrawShader.Free;
     end;

    finally
     DestroyFrameBuffer(EnvMapFBO);
    end;

   finally
    DestroyFrameBuffer(BRDFLUTFBO);
   end;

   if EnvMapTextureHandle>0 then begin
    glDeleteTextures(1,@EnvMapTextureHandle);
   end;

  finally
   glDeleteVertexArrays(1,@EmptyVertexArrayObjectHandle);
  end;

 end else begin

  SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR or
                           SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT,
                           PAnsiChar('Fatal error'),
                           PAnsiChar('Too old OpenGL version! You do need at least OpenGL version 4.5 or alternatively at least OpenGL 4.1 with the GL_ARB_clip_control and GL_ARB_shader_storage_buffer_object extensions'),
                           SurfaceWindow);

 end;

 if assigned(SurfaceContext) then begin
  SDL_GL_DeleteContext(SurfaceContext);
  SurfaceContext:=nil;
 end;
 if assigned(SurfaceWindow) then begin
  SDL_DestroyWindow(SurfaceWindow);
  SurfaceWindow:=nil;
 end;

 SDL_Quit;

end;

begin
 Entry;
end.

