unit UnitOpenGLShadingShader;
{$ifdef fpc}
 {$mode delphi}
 {$ifdef cpui386}
  {$define cpu386}
 {$endif}
 {$ifdef cpuamd64}
  {$define cpux86_64}
 {$endif}
 {$ifdef cpu386}
  {$define cpux86}
  {$define cpu32}
  {$asmmode intel}
 {$endif}
 {$ifdef cpux86_64}
  {$define cpux64}
  {$define cpu64}
  {$asmmode intel}
 {$endif}
 {$ifdef FPC_LITTLE_ENDIAN}
  {$define LITTLE_ENDIAN}
 {$else}
  {$ifdef FPC_BIG_ENDIAN}
   {$define BIG_ENDIAN}
  {$endif}
 {$endif}
 {-$pic off}
 {$define caninline}
 {$ifdef FPC_HAS_TYPE_EXTENDED}
  {$define HAS_TYPE_EXTENDED}
 {$else}
  {$undef HAS_TYPE_EXTENDED}
 {$endif}
 {$ifdef FPC_HAS_TYPE_DOUBLE}
  {$define HAS_TYPE_DOUBLE}
 {$else}
  {$undef HAS_TYPE_DOUBLE}
 {$endif}
 {$ifdef FPC_HAS_TYPE_SINGLE}
  {$define HAS_TYPE_SINGLE}
 {$else}
  {$undef HAS_TYPE_SINGLE}
 {$endif}
 {$if declared(RawByteString)}
  {$define HAS_TYPE_RAWBYTESTRING}
 {$else}
  {$undef HAS_TYPE_RAWBYTESTRING}
 {$ifend}
 {$if declared(UTF8String)}
  {$define HAS_TYPE_UTF8STRING}
 {$else}
  {$undef HAS_TYPE_UTF8STRING}
 {$ifend}
{$else}
 {$realcompatibility off}
 {$localsymbols on}
 {$define LITTLE_ENDIAN}
 {$ifndef cpu64}
  {$define cpu32}
 {$endif}
 {$ifdef cpux64}
  {$define cpux86_64}
  {$define cpu64}
 {$else}
  {$ifdef cpu386}
   {$define cpux86}
   {$define cpu32}
  {$endif}
 {$endif}
 {$define HAS_TYPE_EXTENDED}
 {$define HAS_TYPE_DOUBLE}
 {$ifdef conditionalexpressions}
  {$if declared(RawByteString)}
   {$define HAS_TYPE_RAWBYTESTRING}
  {$else}
   {$undef HAS_TYPE_RAWBYTESTRING}
  {$ifend}
  {$if declared(UTF8String)}
   {$define HAS_TYPE_UTF8STRING}
  {$else}
   {$undef HAS_TYPE_UTF8STRING}
  {$ifend}
 {$else}
  {$undef HAS_TYPE_RAWBYTESTRING}
  {$undef HAS_TYPE_UTF8STRING}
 {$endif}
{$endif}
{$ifdef win32}
 {$define windows}
{$endif}
{$ifdef win64}
 {$define windows}
{$endif}
{$ifdef wince}
 {$define windows}
{$endif}
{$rangechecks off}
{$extendedsyntax on}
{$writeableconst on}
{$hints off}
{$booleval off}
{$typedaddress off}
{$stackframes off}
{$varstringchecks on}
{$typeinfo on}
{$overflowchecks off}
{$longstrings on}
{$openstrings on}

interface

uses SysUtils,Classes,dglOpenGL,UnitOpenGLShader;

type TShadingShader=class(TShader)
      public
       const uboFrameGlobals=0;
             uboMaterial=1;
             ssboJointMatrices=2;
             ssboMorphTargetVertices=3;
             ssboNodeMeshPrimitiveMetaData=4;
      public
       uBaseColorTexture:glInt;
       uMetallicRoughnessTexture:glInt;
       uNormalTexture:glInt;
       uOcclusionTexture:glInt;
       uEmissiveTexture:glInt;
       uLightDirection:glInt;
       uBRDFLUTTexture:glInt;
       uShadowMapTexture:glInt;
       uEnvMapTexture:glInt;
       uEnvMapMaxLevel:glInt;
       uShadows:glInt;
       constructor Create(const aSkinned,aAlphaTest,aShadowMap:boolean);
       destructor Destroy; override;
       procedure BindAttributes; override;
       procedure BindVariables; override;
      end;

implementation

constructor TShadingShader.Create(const aSkinned,aAlphaTest,aShadowMap:boolean);
var f0,f1,f2,f,v:ansistring;
begin
 if aSkinned then begin
  f0:='layout(std140, binding = '+IntToStr(ssboJointMatrices)+') buffer ssboJointMatrices {'+#13#10+
      '  mat4 jointMatrices[];'+#13#10+
      '};'+#13#10;
  f1:='  uint jointMatrixOffset = primitiveMetaData.y;'+#13#10+
      '  mat4 inverseMatrix = inverse(nodeMatrix);'+#13#10+
      '  mat4 skinMatrix = ((inverseMatrix * jointMatrices[jointMatrixOffset + uint(aJoints0.x)]) * aWeights0.x) +'+#13#10+
      '                    ((inverseMatrix * jointMatrices[jointMatrixOffset + uint(aJoints0.y)]) * aWeights0.y) +'+#13#10+
      '                    ((inverseMatrix * jointMatrices[jointMatrixOffset + uint(aJoints0.z)]) * aWeights0.z) +'+#13#10+
      '                    ((inverseMatrix * jointMatrices[jointMatrixOffset + uint(aJoints0.w)]) * aWeights0.w);'+#13#10+
      '  if(any(not(equal(aWeights1, vec4(0.0))))){'+#13#10+
      '    skinMatrix += ((inverseMatrix * jointMatrices[jointMatrixOffset + uint(aJoints1.x)]) * aWeights1.x) +'+#13#10+
      '                  ((inverseMatrix * jointMatrices[jointMatrixOffset + uint(aJoints1.y)]) * aWeights1.y) +'+#13#10+
      '                  ((inverseMatrix * jointMatrices[jointMatrixOffset + uint(aJoints1.z)]) * aWeights1.z) +'+#13#10+
      '                  ((inverseMatrix * jointMatrices[jointMatrixOffset + uint(aJoints1.w)]) * aWeights1.w);'+#13#10+
      '  }'+#13#10;
  f2:=' * skinMatrix';
 end else begin
  f0:='';
  f1:='';
  f2:='';
 end;
 v:='#version 430'+#13#10+
    'layout(location = 0) in vec3 aPosition;'+#13#10+
    'layout(location = 1) in vec3 aNormal;'+#13#10+
    'layout(location = 2) in vec4 aTangent;'+#13#10+
    'layout(location = 3) in vec2 aTexCoord0;'+#13#10+
    'layout(location = 4) in vec2 aTexCoord1;'+#13#10+
    'layout(location = 5) in vec4 aColor0;'+#13#10+
    'layout(location = 6) in uvec4 aJoints0;'+#13#10+
    'layout(location = 7) in uvec4 aJoints1;'+#13#10+
    'layout(location = 8) in vec4 aWeights0;'+#13#10+
    'layout(location = 9) in vec4 aWeights1;'+#13#10+
    'layout(location = 10) in uint aVertexIndex;'+#13#10+
    'out vec3 vWorldSpacePosition;'+#13#10;
 if not aShadowMap then begin
  v:=v+'out vec3 vCameraRelativePosition;'+#13#10;
 end;
 v:=v+
    'out vec2 vTexCoord0;'+#13#10+
    'out vec2 vTexCoord1;'+#13#10+
    'out vec3 vNormal;'+#13#10+
    'out vec3 vTangent;'+#13#10+
    'out vec3 vBitangent;'+#13#10+
    'out vec4 vColor;'+#13#10+
    'layout(std140, binding = '+IntToStr(uboFrameGlobals)+') uniform uboFrameGlobals {'+#13#10+
    '  mat4 inverseViewMatrix;'+#13#10+
    '  mat4 modelMatrix;'+#13#10+
    '  mat4 viewProjectionMatrix;'+#13#10+
    '  mat4 shadowMapMatrix;'+#13#10+
    '} uFrameGlobals;'+#13#10+
    'struct MorphTargetVertex {'+#13#10+
    '  vec4 position;'+#13#10+
    '  vec4 normal;'+#13#10+
    '  vec4 tangent;'+#13#10+
    '  vec4 reversed;'+#13#10+
    '};'+#13#10+
    'layout(std430, binding = '+IntToStr(ssboMorphTargetVertices)+') buffer ssboMorphTargetVertices {'+#13#10+
    '  MorphTargetVertex morphTargetVertices[];'+#13#10+
    '};'+#13#10+
    'layout(std430, binding = '+IntToStr(ssboNodeMeshPrimitiveMetaData)+') buffer ssboNodeMeshPrimitiveMetaData {'+#13#10+
    '  mat4 nodeMatrix;'+#13#10+
    '  uvec4 primitiveMetaData;'+#13#10+
    '  float morphTargetWeights[];'+#13#10+
    '};'+#13#10+
    f0+
    'void main(){'+#13#10+
    f1+
    '  vec3 position = aPosition,'+#13#10+
    '       normal = aNormal,'+#13#10+
    '       tangent = aTangent.xyz;'+#13#10+
    '  for(uint index = 0, count = primitiveMetaData.w; index < count; index++){'+#13#10+
    '    float morphTargetWeight = morphTargetWeights[index];'+#13#10+
    '    uint morphTargetVertexIndex = (index * primitiveMetaData.z) + uint(aVertexIndex);'+#13#10+
    '    position += morphTargetVertices[morphTargetVertexIndex].position.xyz * morphTargetWeight;'+#13#10+
    '    normal += morphTargetVertices[morphTargetVertexIndex].normal.xyz * morphTargetWeight;'+#13#10+
    '    tangent += morphTargetVertices[morphTargetVertexIndex].tangent.xyz * morphTargetWeight;'+#13#10+
    '  }'+#13#10+
    '  mat4 modelMatrix = uFrameGlobals.modelMatrix * nodeMatrix'+f2+';'+#13#10+
    '  mat3 normalMatrix = transpose(inverse(mat3(modelMatrix)));'+#13#10+
    '  vNormal = normalize(normalMatrix * normal);'+#13#10+
    '  vTangent = normalize(normalMatrix * tangent);'+#13#10+
    '  vBitangent = cross(vNormal, vTangent) * aTangent.w;'+#13#10+
    '  vTexCoord0 = aTexCoord0;'+#13#10+
    '  vTexCoord1 = aTexCoord1;'+#13#10+
    '  vColor = aColor0;'+#13#10+
    '  vec4 worldSpacePosition = modelMatrix * vec4(position, 1.0);'+#13#10+
    '  vWorldSpacePosition = worldSpacePosition.xyz / worldSpacePosition.w;'+#13#10;
 if not aShadowMap then begin
  v:=v+'  vCameraRelativePosition = (worldSpacePosition.xyz / worldSpacePosition.w) - uFrameGlobals.inverseViewMatrix[3].xyz;'+#13#10;
 end;
 v:=v+
    '  gl_Position = uFrameGlobals.viewProjectionMatrix * worldSpacePosition;'+#13#10+
    '}'+#13#10;
 f:='#version 430'+#13#10+
    'layout(location = 0) out vec4 oOutput;'+#13#10+
    'in vec3 vWorldSpacePosition;'+#13#10;
 if aShadowMap then begin
 end else begin
  f:=f+'in vec3 vCameraRelativePosition;'+#13#10;
 end;
 f:=f+
    'in vec2 vTexCoord0;'+#13#10+
    'in vec2 vTexCoord1;'+#13#10+
    'in vec3 vNormal;'+#13#10+
    'in vec3 vTangent;'+#13#10+
    'in vec3 vBitangent;'+#13#10+
    'in vec4 vColor;'+#13#10+
    'uniform sampler2D uBaseColorTexture;'+#13#10+
    'uniform sampler2D uMetallicRoughnessTexture;'+#13#10+
    'uniform sampler2D uNormalTexture;'+#13#10+
    'uniform sampler2D uOcclusionTexture;'+#13#10+
    'uniform sampler2D uEmissiveTexture;'+#13#10+
    'uniform sampler2D uBRDFLUTTexture;'+#13#10+
    'uniform sampler2D uShadowMapTexture;'+#13#10+
    'uniform samplerCube uEnvMapTexture;'+#13#10+
    'uniform int uEnvMapMaxLevel;'+#13#10+
    'uniform int uShadows;'+#13#10+
    'uniform vec3 uLightDirection;'+#13#10+
    'layout(std140, binding = '+IntToStr(uboFrameGlobals)+') uniform uboFrameGlobals {'+#13#10+
    '  mat4 inverseViewMatrix;'+#13#10+
    '  mat4 modelMatrix;'+#13#10+
    '  mat4 viewProjectionMatrix;'+#13#10+
    '  mat4 shadowMapMatrix;'+#13#10+
    '} uFrameGlobals;'+#13#10+
    'layout(std140, binding = '+IntToStr(uboMaterial)+') uniform uboMaterial {'+#13#10+
    '  vec4 baseColorFactor;'+#13#10+
    '  vec4 specularFactor;'+#13#10+
    '  vec4 emissiveFactor;'+#13#10+
    '  vec4 metallicRoughnessNormalScaleOcclusionStrengthFactor;'+#13#10+
    '  uvec4 alphaCutOffFlagsTex0Tex1;'+#13#10+
    '} uMaterial;'+#13#10+
    'vec3 convertLinearRGBToSRGB(vec3 c){'+#13#10+
    '  return mix((pow(c, vec3(1.0 / 2.4)) * vec3(1.055)) - vec3(5.5e-2),'+#13#10+
    '             c * vec3(12.92),'+#13#10+
    '             lessThan(c, vec3(3.1308e-3)));'+#13#10+
    '}'+#13#10+
    'vec3 convertSRGBToLinearRGB(vec3 c){'+#13#10+
    '  return mix(pow((c + vec3(5.5e-2)) / vec3(1.055), vec3(2.4)),'+#13#10+
    '             c / vec3(12.92),'+#13#10+
    '             lessThan(c, vec3(4.045e-2)));'+#13#10+
    '}'+#13#10+
    'const float PI = 3.14159265358979323846,'+#13#10+
    '            OneOverPI = 1.0 / PI;'+#13#10+
    'vec3 diffuseLambert(vec3 diffuseColor){'+#13#10+
    '  return diffuseColor * OneOverPI;'+#13#10+
    '}'+#13#10+
    'vec3 diffuseFunction(vec3 diffuseColor, float roughness, float nDotV, float nDotL, float vDotH){'+#13#10+
    '  float FD90 = 0.5 + (2.0 * (vDotH * vDotH * roughness)),'+#13#10+
    '        FdV = 1.0 + ((FD90 - 1.0) * pow(1.0 - nDotV, 5.0)),'+#13#10+
    '        FdL = 1.0 + ((FD90 - 1.0) * pow(1.0 - nDotL, 5.0));'+#13#10+
    '  return diffuseColor * (OneOverPI * FdV * FdL);'+#13#10+
    '}'+#13#10+
    'vec3 specularF(const in vec3 specularColor, const in float vDotH){'+#13#10+
    '  float fc = pow(1.0 - vDotH, 5.0);'+#13#10+
    '  return vec3(clamp(max(max(specularColor.x, specularColor.y), specularColor.z) * 50.0, 0.0, 1.0) * fc) + ((1.0 - fc) * specularColor);'+#13#10+
    '}'+#13#10+
    'float specularD(const in float roughness, const in float nDotH){'+#13#10+
    '  float a = roughness * roughness;'+#13#10+
    '  float a2 = a * a;'+#13#10+
    '  float d = (((nDotH * a2) - nDotH) * nDotH) + 1.0;'+#13#10+
    '  return a2 / (PI * (d * d));'+#13#10+
    '}'+#13#10+
    'float specularG(const in float roughness, const in float nDotV, const in float nDotL){'+#13#10+
    '  float k = (roughness * roughness) * 0.5;'+#13#10+
    '  vec2 GVL = (vec2(nDotV, nDotL) * (1.0 - k)) + vec2(k);'+#13#10+
    '  return 0.25 / (GVL.x * GVL.y);'+#13#10+
    '}'+#13#10+
    'vec3 doSingleLight(const in vec3 lightColor,'+#13#10+
    '                   const in vec3 lightLit,'+#13#10+
    '                   const in vec3 lightDirection,'+#13#10+
    '                   const in vec3 normal,'+#13#10+
    '                   const in vec3 diffuseColor,'+#13#10+
    '                   const in vec3 specularColor,'+#13#10+
    '                   const in vec3 viewDirection,'+#13#10+
    '                   const in float refractiveAngle,'+#13#10+
    '                   const in float materialTransparency,'+#13#10+
    '                   const in float materialRoughness,'+#13#10+
    '                   const in float materialCavity){'+#13#10+
    '  vec3 halfVector = normalize(viewDirection + lightDirection);'+#13#10+
    '  float nDotL = clamp(dot(normal, lightDirection), 1e-5, 1.0);'+#13#10+
    '  float nDotV = clamp(abs(dot(normal, viewDirection)) + 1e-5, 0.0, 1.0);'+#13#10+
    '  float nDotH = clamp(dot(normal, halfVector), 0.0, 1.0);'+#13#10+
    '  float vDotH = clamp(dot(viewDirection, halfVector), 0.0, 1.0);'+#13#10+
    '  vec3 diffuse = diffuseFunction(diffuseColor, materialRoughness, nDotV, nDotL, vDotH) * (1.0 - materialTransparency);'+#13#10+
    '  vec3 specular = specularF(specularColor, max(vDotH, refractiveAngle)) *'+#13#10+
    '                  specularD(materialRoughness, nDotH) *'+#13#10+
    '                  specularG(materialRoughness, nDotV, nDotL);'+#13#10+
    '  return (diffuse + specular) * ((materialCavity * nDotL * lightColor) * lightLit);'+#13#10+
    '}'+#13#10+
    'vec4 getEnvMap(sampler2D texEnvMap, float texLOD, vec3 rayDirection){'+#13#10+
    '  rayDirection = normalize(rayDirection);'+#13#10+
    '  return textureLod(texEnvMap, (vec2((atan(rayDirection.z, rayDirection.x) / 6.283185307179586476925286766559) + 0.5, acos(rayDirection.y) / 3.1415926535897932384626433832795)), texLOD);'+#13#10+
    '}'+#13#10+
    'float computeMSM(in vec4 moments, in float fragmentDepth, in float depthBias, in float momentBias){'+#13#10+
    '  vec4 b = mix(moments, vec4(0.5), momentBias);'+#13#10+
    '  vec3 z;'+#13#10+
    '  z[0] = fragmentDepth - depthBias;'+#13#10+
    '  float L32D22 = fma(-b[0], b[1], b[2]);'+#13#10+
    '  float D22 = fma(-b[0], b[0], b[1]);'+#13#10+
    '  float squaredDepthVariance = fma(-b[1], b[1], b[3]);'+#13#10+
    '  float D33D22 = dot(vec2(squaredDepthVariance, -L32D22), vec2(D22, L32D22));'+#13#10+
    '  float InvD22 = 1.0 / D22;'+#13#10+
    '  float L32 = L32D22 * InvD22;'+#13#10+
    '  vec3 c = vec3(1.0, z[0], z[0] * z[0]);'+#13#10+
    '  c[1] -= b.x;'+#13#10+
    '  c[2] -= b.y + (L32 * c[1]);'+#13#10+
    '  c[1] *= InvD22;'+#13#10+
    '  c[2] *= D22 / D33D22;'+#13#10+
    '  c[1] -= L32 * c[2];'+#13#10+
    '  c[0] -= dot(c.yz, b.xy);'+#13#10+
    '  float InvC2 = 1.0 / c[2];'+#13#10+
    '  float p = c[1] * InvC2;'+#13#10+
    '  float q = c[0] * InvC2;'+#13#10+
    '  float D = (p * p * 0.25) - q;'+#13#10+
    '  float r = sqrt(D);'+#13#10+
    '  z[1] = (p * -0.5) - r;'+#13#10+
    '  z[2] = (p * -0.5) + r;'+#13#10+
    '  vec4 switchVal = (z[2] < z[0]) ? vec4(z[1], z[0], 1.0, 1.0) :'+#13#10+
    '                   ((z[1] < z[0]) ? vec4(z[0], z[1], 0.0, 1.0) :'+#13#10+
    '                   vec4(0.0));'+#13#10+
    '  float quotient = (switchVal[0] * z[2] - b[0] * (switchVal[0] + z[2]) + b[1])/((z[2] - switchVal[1]) * (z[0] - z[1]));'+#13#10+
    '  return clamp((switchVal[2] + (switchVal[3] * quotient)), 0.0, 1.0);'+#13#10+
    '}'+#13#10+
    'vec2 getShadowOffsets(const in vec3 p, const in vec3 N, const in vec3 L){'+#13#10+
    '  float cos_alpha = clamp(dot(N, L), 0.0, 1.0);'+#13#10+
    '  float offset_scale_N = sqrt(1.0 - (cos_alpha * cos_alpha));'+#13#10+ // sin(acos(L?N))
    '  float offset_scale_L = offset_scale_N / cos_alpha;'+#13#10+          // tan(acos(L?N))
    '  return (vec2(offset_scale_N, min(2.0, offset_scale_L)) * vec2(0.0002, 0.00005)) + vec2(0.0, 0.0);'+#13#10+
    '}'+#13#10+
    'float linearStep(float a, float b, float v){'+#13#10+
    '  return clamp((v - a) / (b - a), 0.0, 1.0);'+#13#10+
    '}'+#13#10+
    'float reduceLightBleeding(float pMax, float amount){'+#13#10+
    '  return linearStep(amount, 1.0, pMax);'+#13#10+
    '}'+#13#10+
    'float getMSMShadowIntensity(vec4 moments, float depth, float depthBias, float momentBias){'+#13#10+
    '  vec4 b = mix(moments, vec4(0.5), momentBias);'+#13#10+
    '  float d = depth - depthBias,'+#13#10+
    '        l32d22 = fma(-b.x, b.y, b.z),'+#13#10+
    '        d22 = fma(-b.x, b.x, b.y),'+#13#10+
    '        squaredDepthVariance = fma(-b.y, b.y, b.w),'+#13#10+
    '        d33d22 = dot(vec2(squaredDepthVariance, -l32d22), vec2(d22, l32d22)),'+#13#10+
    '        invD22 = 1.0 / d22,'+#13#10+
    '        l32 = l32d22 * invD22;'+#13#10+
    '  vec3 c = vec3(1.0, d - b.x, d * d);'+#13#10+
    '  c.z -= b.y + (l32 * c.y);'+#13#10+
    '  c.yz *= vec2(invD22, d22 / d33d22);'+#13#10+
    '  c.y -= l32 * c.z;'+#13#10+
    '  c.x -= dot(c.yz, b.xy);'+#13#10+
    '  vec2 pq = c.yx / c.z;'+#13#10+
    '  vec3 z = vec3(d, vec2(-(pq.x * 0.5)) + (vec2(-1.0, 1.0) * sqrt(((pq.x * pq.x) * 0.25) - pq.y)));'+#13#10+
    '  vec4 s = (z.z < z.x)'+#13#10+
    '             ? vec3(z.y, z.x, 1.0).xyzz'+#13#10+
    '                 : ((z.y < z.x)'+#13#10+
    '                     ? vec4(z.x, z.y, 0.0, 1.0)'+#13#10+
    '                     : vec4(0.0));'+#13#10+
    '  return clamp((s.z + (s.w * ((((s.x * z.z) - (b.x * (s.x + z.z))) + b.y) / ((z.z - s.y) * (z.x - z.y))))) * 1.03, 0.0, 1.0);'+#13#10+
    '}'+#13#10+
    'const uint smPBRMetallicRoughness = 0u,'+#13#10+
    '           smPBRSpecularGlossiness = 1u,'+#13#10+
    '           smUnlit = 2u;'+#13#10+
    'uvec2 texCoordIndices = uMaterial.alphaCutOffFlagsTex0Tex1.zw;'+#13#10+
    'vec2 texCoords[2] = vec2[2](vTexCoord0, vTexCoord1);'+#13#10+
    'vec4 textureFetch(const in sampler2D tex, const in int textureIndex, const in vec4 defaultValue){'+#13#10+
    '  uint which = (texCoordIndices[textureIndex >> 3] >> ((uint(textureIndex) & 7u) << 2u)) & 0xfu;'+#13#10+
    '  return (which < 0x2u) ? texture(tex, texCoords[int(which)]) : defaultValue;'+#13#10+
    '}'+#13#10+
    'vec4 textureFetchSRGB(const in sampler2D tex, const in int textureIndex, const in vec4 defaultValue){'+#13#10+
    '  uint which = (texCoordIndices[textureIndex >> 3] >> ((uint(textureIndex) & 7u) << 2u)) & 0xfu;'+#13#10+
    '  vec4 texel;'+#13#10+
    '  if(which < 0x2u){'+#13#10+
    '    texel = texture(tex, texCoords[int(which)]);'+#13#10+
    '    texel.xyz = convertSRGBToLinearRGB(texel.xyz);'+#13#10+
    '  }else{'+#13#10+
    '    texel = defaultValue;'+#13#10+
    '  }'+#13#10+
    '   return texel;'+#13#10+
    '}'+#13#10+
    'void main(){'+#13#10+
    '  vec4 color = vec4(0.0);'+#13#10+
    '  uint flags = uMaterial.alphaCutOffFlagsTex0Tex1.y,'+#13#10+
    '       shadingModel = (flags >> 0u) & 0xfu;'+#13#10;
 if aShadowMap then begin
  f:=f+
       '  vec4 t = uFrameGlobals.shadowMapMatrix * vec4(vWorldSpacePosition, 1.0);'+#13#10+
       '  float d = fma(t.z / t.w, 0.5, 0.5);'+#13#10+
       '  float s = d * d;'+#13#10+
       '  vec4 m = vec4(d, s, s * d, s * s);'+#13#10+
       '  oOutput = m;'+#13#10+
       '  float alpha = textureFetch(uBaseColorTexture, 0, vec4(1.0)).w * uMaterial.baseColorFactor.w * vColor.w;'+#13#10;
 end else begin
  f:=f+
//   '  vec2 shadowOffsetData = getShadowOffsets(vWorldSpacePosition, vNormal, uLightDirection).xy;'+#13#10+
//   '  vec3 shadowOffset = ((shadowOffsetData.x * vNormal) + (shadowOffsetData.y * uLightDirection));'+#13#10+
     '  float litIntensity = 1.0;'+#13#10+
     '  if(uShadows != 0){'+#13#10+
     '    vec4 shadowNDC = uFrameGlobals.shadowMapMatrix * vec4(vWorldSpacePosition'+{ + shadowOffset}', 1.0);'+#13#10+
     '    shadowNDC /= shadowNDC.w;'+#13#10+
     '    if(all(greaterThanEqual(shadowNDC, vec4(-1.0))) && all(lessThanEqual(shadowNDC, vec4(1.0)))){'+#13#10+
     '      shadowNDC.xyz = fma(shadowNDC.xyz, vec3(0.5), vec3(0.5));'+#13#10+
//   '      vec4 moments = textureLod(uShadowMapTexture, shadowNDC.xy, 0.0);'+#13#10+
     '      vec4 moments = (textureLod(uShadowMapTexture, shadowNDC.xy, 0.0) + vec2(-0.035955884801, 0.0).xyyy) *'+#13#10+
     '                     mat4(0.2227744146, 0.0771972861, 0.7926986636, 0.0319417555,'+#13#10+
     '                          0.1549679261, 0.1394629426, 0.7963415838, -0.172282317,'+#13#10+
     '                          0.1451988946, 0.2120202157, 0.7258694464, -0.2758014811,'+#13#10+
     '                          0.163127443, 0.2591432266, 0.6539092497, -0.3376131734);'+#13#10+{}
     '      litIntensity = 1.0 - reduceLightBleeding(getMSMShadowIntensity(moments, shadowNDC.z, 5e-3, 1e-2), 0.0);'+#13#10+
//   '      litIntensity = reduceLightBleeding(getMSMShadowIntensity(moments, shadowNDC.z, 5e-3, 1e-2), 0.0);'+#13#10+
     '    }'+#13#10+
     '  }'+#13#10+
     '  switch(shadingModel){'+#13#10+
     '    case smPBRMetallicRoughness:'+#13#10+
     '    case smPBRSpecularGlossiness:{'+#13#10+
     '      vec4 diffuseColorAlpha, specularColorRoughness;'+#13#10+
     '      switch(shadingModel){'+#13#10+
     '        case smPBRMetallicRoughness:{'+#13#10+
     '          const vec3 f0 = vec3(0.04);'+#13#10+ // dielectricSpecular
     '          vec4 baseColor = textureFetchSRGB(uBaseColorTexture, 0, vec4(1.0)) *'+#13#10+
     '                           uMaterial.baseColorFactor;'+#13#10+
     '          vec2 metallicRoughness = clamp(textureFetch(uMetallicRoughnessTexture, 1, vec4(1.0)).zy *'+#13#10+
     '                                         uMaterial.metallicRoughnessNormalScaleOcclusionStrengthFactor.xy,'+#13#10+
     '                                         vec2(0.0, 1e-3),'+#13#10+
     '                                         vec2(1.0));'+#13#10+
     '          diffuseColorAlpha = vec4((baseColor.xyz * (vec3(1.0) - f0) * (1.0 - metallicRoughness.x)) * PI,'+#13#10+
     '                                   baseColor.w);'+#13#10+
     '          specularColorRoughness = vec4(mix(f0, baseColor.xyz, metallicRoughness.x) * PI,'+#13#10+
     '                                        metallicRoughness.y);'+#13#10+
     '          break;'+#13#10+
     '        }'+#13#10+
     '        case smPBRSpecularGlossiness:{'+#13#10+
     '          vec4 specularGlossiness = textureFetchSRGB(uMetallicRoughnessTexture, 1, vec4(1.0)) *'+#13#10+
     '                                    vec4(uMaterial.specularFactor.xyz,'+#13#10+
     '                                         uMaterial.metallicRoughnessNormalScaleOcclusionStrengthFactor.y);'+#13#10+
     '          diffuseColorAlpha = textureFetchSRGB(uBaseColorTexture, 0, vec4(1.0)) *'+#13#10+
     '                              uMaterial.baseColorFactor *'+#13#10+
     '                              vec2((1.0 - max(max(specularGlossiness.x,'+#13#10+
     '                                                  specularGlossiness.y),'+#13#10+
     '                                              specularGlossiness.z)) * PI,'+#13#10+
     '                                   1.0).xxxy;'+#13#10+
     '          specularColorRoughness = vec4(specularGlossiness.xyz * PI,'+#13#10+
     '                                        clamp(1.0 - specularGlossiness.w, 1e-3, 1.0));'+#13#10+
     '          break;'+#13#10+
     '        }'+#13#10+
     '      }'+#13#10+
     '      vec3 normal;'+#13#10+
     '      if((texCoordIndices.x & 0x00000f00u) != 0x00000f00u){'+#13#10+
     '        vec4 normalTexture = textureFetch(uNormalTexture, 2, vec2(0.0, 1.0).xxyx);'+#13#10+
     '        normal = normalize(mat3(normalize(vTangent), normalize(vBitangent), normalize(vNormal)) * normalize((normalTexture.xyz - vec3(0.5)) * (vec2(uMaterial.metallicRoughnessNormalScaleOcclusionStrengthFactor.z, 1.0).xxy * 2.0)));'+#13#10+
     '      }else{'+#13#10+
     '        normal = normalize(vNormal);'+#13#10+
     '      }'+#13#10+
     '      normal *= (((flags & (1u << 5u)) != 0u) && !gl_FrontFacing) ? -1.0 : 1.0;'+#13#10+
     '      vec4 occlusionTexture = textureFetch(uOcclusionTexture, 3, vec4(1.0));'+#13#10+
     '      vec4 emissiveTexture = textureFetchSRGB(uEmissiveTexture, 4, vec4(1.0)); '+#13#10+
     '      float cavity = clamp(mix(1.0, occlusionTexture.x, uMaterial.metallicRoughnessNormalScaleOcclusionStrengthFactor.w), 0.0, 1.0),'+#13#10+
     '            transparency = 0.0,'+#13#10+
     '            refractiveAngle = 0.0,'+#13#10+
     '            ambientOcclusion = 1.0,'+#13#10+
     '            shadow = 1.0,'+#13#10+
     '            reflectance = max(max(specularColorRoughness.x, specularColorRoughness.y), specularColorRoughness.z);'+#13#10+
     '      vec3 viewDirection = normalize(vCameraRelativePosition);'+#13#10+
{    '      color.xyz += (doSingleLight(vec3(1.70, 1.15, 0.70),'+#13#10+
     '                                  pow(vec3(litIntensity), vec3(1.05, 1.02, 1.0)),'+#13#10+
     '                                  -uLightDirection,'+#13#10+
     '                                  normal.xyz,'+#13#10+
     '                                  diffuseColorAlpha.xyz,'+#13#10+
     '                                  specularColorRoughness.xyz,'+#13#10+
     '                                  -viewDirection,'+#13#10+
     '                                  refractiveAngle,'+#13#10+
     '                                  transparency,'+#13#10+
     '                                  specularColorRoughness.w,'+#13#10+
     '                                  cavity) +'+#13#10+
     '                   (((('+#13#10+
     '                       // Sky light'+#13#10+
     '                       (max(0.0, 0.6 + (0.4 * normal.y)) * vec3(0.05, 0.20, 0.45)) +'+#13#10+
     '                       // Backlight'+#13#10+
     '                       (max(0.0, 0.2 + (0.8 * dot(normal.xyz, normalize(vec3(uLightDirection.xz, 0.0).xzy)))) * vec3(0.20, 0.25, 0.25))'+#13#10+
     '                     ) * ambientOcclusion) +'+#13#10+
     '                     // Bounce light'+#13#10+
     '                     (clamp(-normal.y, 0.0, 1.0) * vec3(0.18, 0.24, 0.24) * mix(0.5, 1.0, ambientOcclusion))'+#13#10+
     '                    ) * diffuseLambert(diffuseColorAlpha.xyz) * cavity));'+#13#10+ (*{}
 (**)'      color.xyz += doSingleLight(vec3(1.70, 1.15, 0.70),'+#13#10+ // Sun light
     '                                 pow(vec3(litIntensity), vec3(1.05, 1.02, 1.0)),'+#13#10+
     '                                 -uLightDirection,'+#13#10+
     '                                 normal.xyz,'+#13#10+
     '                                 diffuseColorAlpha.xyz,'+#13#10+
     '                                 specularColorRoughness.xyz,'+#13#10+
     '                                 -viewDirection,'+#13#10+
     '                                 refractiveAngle,'+#13#10+
     '                                 transparency,'+#13#10+
     '                                 specularColorRoughness.w,'+#13#10+
     '                                 cavity);'+#13#10+(**)
     '      {'+#13#10+
     '        vec3 reflectionVector = normalize(reflect(viewDirection, normal.xyz));'+#13#10+
     '        float NdotV = clamp(abs(dot(normal.xyz, viewDirection)) + 1e-5, 0.0, 1.0),'+#13#10+
     '              ao = cavity * ambientOcclusion,'+#13#10+
     '              lit = mix(1.0, litIntensity, max(0.0, dot(reflectionVector, -uLightDirection) * (1.0 - (specularColorRoughness.w * specularColorRoughness.w)))),'+#13#10+
     '              specularOcclusion = clamp((pow(NdotV + (ao * lit), specularColorRoughness.w * specularColorRoughness.w) - 1.0) + (ao * lit), 0.0, 1.0);'+#13#10+
     '         vec2 brdf = textureLod(uBRDFLUTTexture, vec2(specularColorRoughness.w, NdotV), 0.0).xy;'+#13#10+
     '         color.xyz += ((textureLod(uEnvMapTexture, reflectionVector,'+' clamp((float(uEnvMapMaxLevel) - 1.0) - (1.0 - (1.2 * log2(specularColorRoughness.w))), 0.0, float(uEnvMapMaxLevel))).xyz * ((specularColorRoughness.xyz * brdf.x) +'+' (brdf.yyy * clamp(max(max(specularColorRoughness.x, specularColorRoughness.y), specularColorRoughness.z) * 50.0, 0.0, 1.0))) * specularOcclusion) +'+#13#10+
     '                       (textureLod(uEnvMapTexture, normal.xyz, float(uEnvMapMaxLevel)).xyz * diffuseColorAlpha.xyz * ao)) * OneOverPI;'+#13#10+
     '      }'+#13#10+
     '      color = vec4(vec3(color.xyz + (emissiveTexture.xyz * uMaterial.emissiveFactor.xyz)), diffuseColorAlpha.w);'+#13#10+
     '      break;'+#13#10+
     '    }'+#13#10+
     '    case smUnlit:{'+#13#10+
     '      color = textureFetchSRGB(uBaseColorTexture, 0, vec4(1.0)) * uMaterial.baseColorFactor * vec2((litIntensity * 0.25) + 0.75, 1.0).xxxy;'+#13#10+
     '      break;'+#13#10+
     '    }'+#13#10+
     '  }'+#13#10+
     '  float alpha = color.w * vColor.w;'+#13#10+
     '  oOutput = vec4(color.xyz * vColor.xyz, mix(1.0, alpha, float(int(uint((flags >> 4u) & 1u)))));'+#13#10;
 end;
 if aAlphaTest then begin
  f:=f+'  if(alpha < uintBitsToFloat(uMaterial.alphaCutOffFlagsTex0Tex1.x)){'+#13#10+
       '    discard;'+#13#10+
       '  }'+#13#10;
 end;
 f:=f+'}'+#13#10;
 inherited Create(f,v);
end;

destructor TShadingShader.Destroy;
begin
 inherited Destroy;
end;

procedure TShadingShader.BindAttributes;
begin
 inherited BindAttributes;
 glBindAttribLocation(ProgramHandle,0,'aPosition');
 glBindAttribLocation(ProgramHandle,1,'aNormal');
 glBindAttribLocation(ProgramHandle,2,'aTangent');
 glBindAttribLocation(ProgramHandle,3,'aTexCoord0');
 glBindAttribLocation(ProgramHandle,4,'aTexCoord1');
 glBindAttribLocation(ProgramHandle,5,'aColor0');
 glBindAttribLocation(ProgramHandle,6,'aJoints0');
 glBindAttribLocation(ProgramHandle,7,'aJoints1');
 glBindAttribLocation(ProgramHandle,8,'aWeights0');
 glBindAttribLocation(ProgramHandle,9,'aWeights1');
 glBindAttribLocation(ProgramHandle,10,'aVertexIndex');
end;

procedure TShadingShader.BindVariables;
begin
 inherited BindVariables;
 uBaseColorTexture:=glGetUniformLocation(ProgramHandle,pointer(pansichar('uBaseColorTexture')));
 uMetallicRoughnessTexture:=glGetUniformLocation(ProgramHandle,pointer(pansichar('uMetallicRoughnessTexture')));
 uNormalTexture:=glGetUniformLocation(ProgramHandle,pointer(pansichar('uNormalTexture')));
 uOcclusionTexture:=glGetUniformLocation(ProgramHandle,pointer(pansichar('uOcclusionTexture')));
 uEmissiveTexture:=glGetUniformLocation(ProgramHandle,pointer(pansichar('uEmissiveTexture')));
 uLightDirection:=glGetUniformLocation(ProgramHandle,pointer(pansichar('uLightDirection')));
 uBRDFLUTTexture:=glGetUniformLocation(ProgramHandle,pointer(pansichar('uBRDFLUTTexture')));
 uShadowMapTexture:=glGetUniformLocation(ProgramHandle,pointer(pansichar('uShadowMapTexture')));
 uEnvMapTexture:=glGetUniformLocation(ProgramHandle,pointer(pansichar('uEnvMapTexture')));
 uEnvMapMaxLevel:=glGetUniformLocation(ProgramHandle,pointer(pansichar('uEnvMapMaxLevel')));
 uShadows:=glGetUniformLocation(ProgramHandle,pointer(pansichar('uShadows')));
//uboJointMatrices:=glGetUniformBlockIndex(ProgramHandle,pointer(pansichar('uboJointMatrices')));
 glUniform1i(uBaseColorTexture,0);
 glUniform1i(uMetallicRoughnessTexture,1);
 glUniform1i(uNormalTexture,2);
 glUniform1i(uOcclusionTexture,3);
 glUniform1i(uEmissiveTexture,4);
 glUniform1i(uBRDFLUTTexture,5);
 glUniform1i(uShadowMapTexture,6);
 glUniform1i(uEnvMapTexture,7);
end;

end.
