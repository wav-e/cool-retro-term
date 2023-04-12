/*******************************************************************************
* Copyright (c) 2013-2021 "Filippo Scognamiglio"
* https://github.com/Swordfish90/cool-retro-term
*
* This file is part of cool-retro-term.
*
* cool-retro-term is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*******************************************************************************/

import QtQuick 2.2
import QtGraphicalEffects 1.0

import "utils.js" as Utils

Item {
    property ShaderEffectSource source
    property BurnInEffect burnInEffect
    property ShaderEffectSource bloomSource

    property color fontColor: appSettings.fontColor
    property color backgroundColor: appSettings.backgroundColor

    property real screenCurvature: appSettings.screenCurvature * appSettings.screenCurvatureSize

    property real chromaColor: appSettings.chromaColor

    property real ambientLight: appSettings.ambientLight * 0.2

    property real grid: appSettings.grid
    property real blur: appSettings.blur
    property real blurDirections: appSettings.blurDirections
    property real blurRadius: appSettings.blurRadius
    property real blurQuality: appSettings.blurQuality

    property real rasterization_intensivity: appSettings.rasterization_intensivity

    property size virtualResolution
    property size screenResolution

    property real _screenDensity: Math.min(
        screenResolution.width / virtualResolution.width,
        screenResolution.height / virtualResolution.height
    )

     ShaderEffect {
         id: dynamicShader

         property ShaderLibrary shaderLibrary: ShaderLibrary { }

         property ShaderEffectSource screenBuffer: frameBuffer
         property ShaderEffectSource burnInSource: burnInEffect.source
         property ShaderEffectSource frameSource: terminalFrameLoader.item

         property ShaderEffectSource blurBuffer: blurShaderSource
         property color fontColor: parent.fontColor
         property color backgroundColor: parent.backgroundColor
         property real screenCurvature: parent.screenCurvature
         property real chromaColor: parent.chromaColor
         property real ambientLight: parent.ambientLight

         property real blur: parent.blur
         property real grid: parent.grid
         property real rasterization_intensivity: parent.rasterization_intensivity

         property real flickering: appSettings.flickering
         property real horizontalSync: appSettings.horizontalSync
         property real horizontalSyncStrength: Utils.lint(0.05, 0.35, horizontalSync)
         property real glowingLine: appSettings.glowingLine * 0.2

         // Fast burnin properties
         property real burnIn: appSettings.burnIn
         property real burnInLastUpdate: burnInEffect.lastUpdate
         property real burnInTime: burnInEffect.burnInFadeTime

         property real jitter: appSettings.jitter
         property size jitterDisplacement: Qt.size(0.007 * jitter, 0.002 * jitter)
         property real shadowLength: 0.25 * screenCurvature * Utils.lint(0.50, 1.5, ambientLight)
         property real staticNoise: appSettings.staticNoise
         property size scaleNoiseSize: Qt.size((width * 0.75) / (noiseTexture.width * appSettings.windowScaling * appSettings.totalFontScaling),
                                               (height * 0.75) / (noiseTexture.height * appSettings.windowScaling * appSettings.totalFontScaling))

         property size virtualResolution: parent.virtualResolution
         property size screenResolution: parent.screenResolution

         // Rasterization might display oversamping issues if virtual resolution is close to physical display resolution.
         // We progressively disable rasterization from 4x up to 2x resolution.
         property real rasterizationIntensity: Utils.smoothstep(2.0, 4.0, _screenDensity)

         property real displayTerminalFrame: appSettings._frameMargin > 0 || appSettings.screenCurvature > 0

         property real time: timeManager.time
         property ShaderEffectSource noiseBlueSource: noiseBlueShaderSource
         property size noiseBlueSize: Qt.size(noiseBlueTexture.width, noiseBlueTexture.height)
         property ShaderEffectSource noiseSource: noiseShaderSource

         // If something goes wrong activate the fallback version of the shader.
         property bool fallBack: false

         anchors.fill: parent
         blending: false

         //Smooth random texture used for flickering effect.
         Image {
             id: noiseTexture
             source: "images/allNoise512.png"
             width: 512
             height: 512
             fillMode: Image.Tile
             visible: false
         }
         ShaderEffectSource {
             id: noiseShaderSource
             sourceItem: noiseTexture
             wrapMode: ShaderEffectSource.Repeat
             visible: false
             smooth: true
         }

         // texture used for dithering
         Image {
             id: noiseBlueTexture
             source: "images/blueNoise256.png"
             width: 256
             height: 256
             fillMode: Image.Tile
             visible: false
         }
         ShaderEffectSource {
             id: noiseBlueShaderSource
             sourceItem: noiseBlueTexture
             wrapMode: ShaderEffectSource.Repeat
             mipmap: true
             visible: false
             smooth: false
         }

         //Print the number with a reasonable precision for the shader.
         function str(num){
             return num.toFixed(8);
         }

         vertexShader: "
             uniform highp mat4 qt_Matrix;
             uniform highp float time;

             attribute highp vec4 qt_Vertex;
             attribute highp vec2 qt_MultiTexCoord0;

             varying highp vec2 qt_TexCoord0;" +

             (!fallBack ? "
                 uniform sampler2D noiseSource;" : "") +

             (!fallBack && flickering !== 0.0 ?"
                 varying lowp float brightness;
                 uniform lowp float flickering;" : "") +

             (!fallBack && horizontalSync !== 0.0 ?"
                 uniform lowp float horizontalSyncStrength;
                 varying lowp float distortionScale;
                 varying lowp float distortionFreq;" : "") +

             "
             void main() {
                 qt_TexCoord0 = qt_MultiTexCoord0;
                 vec2 coords = vec2(fract(time/(1024.0*2.0)), fract(time/(1024.0*1024.0)));" +

                 (!fallBack && (flickering !== 0.0 || horizontalSync !== 0.0) ?
                     "vec4 initialNoiseTexel = texture2D(noiseSource, coords);"
                 : "") +

                 (!fallBack && flickering !== 0.0 ? "
                     brightness = 1.0 + (initialNoiseTexel.g - 0.5) * flickering;"
                 : "") +

                 (!fallBack && horizontalSync !== 0.0 ? "
                     float randval = horizontalSyncStrength - initialNoiseTexel.r;
                     distortionScale = step(0.0, randval) * randval * horizontalSyncStrength;
                     distortionFreq = mix(4.0, 40.0, initialNoiseTexel.g);"
                 : "") +

                 "gl_Position = qt_Matrix * qt_Vertex;
             }"

         fragmentShader: "
             #ifdef GL_ES
                 precision mediump float;
             #endif
             uniform sampler2D blurBuffer;

             uniform sampler2D screenBuffer;
             uniform highp float qt_Opacity;
             uniform highp float time;
             varying highp vec2 qt_TexCoord0;

             uniform highp vec4 fontColor;
             uniform highp vec4 backgroundColor;
             uniform lowp float shadowLength;

             uniform lowp float rasterization_intensivity;
             uniform highp vec2 screenResolution;
             uniform highp vec2 virtualResolution;
             uniform lowp float rasterizationIntensity;\n" +
             
             (grid !== 0 ? "
                 uniform lowp float grid;" : "") +    

                 "uniform lowp float blur;" +
             (burnIn !== 0 ? "
                 uniform sampler2D burnInSource;
                 uniform highp float burnInLastUpdate;
                 uniform highp float burnInTime;" : "") +
             (staticNoise !== 0 ? "
                 uniform highp float staticNoise;" : "") +

                 "uniform highp sampler2D noiseBlueSource;" +
                 "uniform vec2 noiseBlueSize;" +

                 "uniform lowp sampler2D noiseSource;" +
                 "uniform highp vec2 scaleNoiseSize;" +
             (displayTerminalFrame ? "
                 uniform lowp sampler2D frameSource;" : "") +
             (screenCurvature !== 0 ? "
                 uniform highp float screenCurvature;" : "") +
             (glowingLine !== 0 ? "
                 uniform highp float glowingLine;" : "") +
             (chromaColor !== 0 ? "
                 uniform lowp float chromaColor;" : "") +
             (jitter !== 0 ? "
                 uniform lowp vec2 jitterDisplacement;" : "") +
             (ambientLight !== 0 ? "
                 uniform lowp float ambientLight;" : "") +

             (fallBack && horizontalSync !== 0 ? "
                 uniform lowp float horizontalSyncStrength;" : "") +
             (fallBack && flickering !== 0.0 ?"
                 uniform lowp float flickering;" : "") +
             (!fallBack && flickering !== 0 ? "
                 varying lowp float brightness;"
             : "") +
             (!fallBack && horizontalSync !== 0 ? "
                 varying lowp float distortionScale;
                 varying lowp float distortionFreq;" : "") +

             (glowingLine !== 0 ? "
                 float randomPass(vec2 coords){
                     return fract(smoothstep(-120.0, 0.0, coords.y - (virtualResolution.y + 120.0) * fract(time * 0.00015)));
                 }" : "") +

             shaderLibrary.min2 +
             shaderLibrary.rgb2grey +
             shaderLibrary.rasterizationShader +

             "
             float isInScreen(vec2 v) {
                 return min2(step(0.0, v) - step(1.0, v));
             }

             vec2 barrel(vec2 v, vec2 cc, float power) {" +

                 (screenCurvature !== 0 ? "
                     float distortion = dot(cc, cc) * power;
                     return (v - cc * (1.0 + distortion) * distortion);"
                 :
                     "return v;") +
             "}" +

             "vec3 convertWithChroma(vec3 inColor) {
                vec3 outColor = inColor;" +

                 (chromaColor !== 0 ?
                     "outColor = fontColor.rgb * mix(vec3(rgb2grey(inColor)), inColor, chromaColor);"
                 :
                     "outColor = fontColor.rgb * rgb2grey(inColor);") +

             "  return outColor;
             }" +

             "void main() {" +
                 "vec2 cc = vec2(0.5) - qt_TexCoord0;" +
                 "float _distance = length(cc);" +

                 //FallBack if there are problems
                 (fallBack && (flickering !== 0.0 || horizontalSync !== 0.0) ?
                     "vec2 initialCoords = vec2(fract(time/(1024.0*2.0)), fract(time/(1024.0*1024.0)));
                      vec4 initialNoiseTexel = texture2D(noiseSource, initialCoords);"
                 : "") +
                 (fallBack && flickering !== 0.0 ? "
                     float brightness = 1.0 + (initialNoiseTexel.g - 0.5) * flickering;"
                 : "") +
                 (fallBack && horizontalSync !== 0.0 ? "
                     float randval = horizontalSyncStrength - initialNoiseTexel.r;
                     float distortionScale = step(0.0, randval) * randval * horizontalSyncStrength;
                     float distortionFreq = mix(4.0, 40.0, initialNoiseTexel.g);"
                 : "") +

                 (staticNoise ? "
                     float noise = staticNoise;" : "") +

                 (screenCurvature !== 0 ? "
                     vec2 staticCoords = barrel(qt_TexCoord0, cc, screenCurvature);"
                 :"
                     vec2 staticCoords = qt_TexCoord0;") +

                 "vec2 coords = qt_TexCoord0;" +

                 (horizontalSync !== 0 ? "
                     float dst = sin((coords.y + time * 0.001) * distortionFreq);
                     coords.x += dst * distortionScale;" +

                     (staticNoise ? "
                         noise += distortionScale * 7.0;" : "")

                 : "") +

                 (jitter !== 0 || staticNoise !== 0 ?
                     "vec4 noiseTexel = texture2D(noiseSource, scaleNoiseSize * coords + vec2(fract(time / 51.0), fract(time / 237.0)));"
                 : "") +

                 (jitter !== 0 ? "
                     vec2 offset = vec2(noiseTexel.b, noiseTexel.a) - vec2(0.5);
                     vec2 txt_coords = coords + offset * jitterDisplacement;"
                 :  "vec2 txt_coords = coords;") +

                 "float color = 0.0001;" +
                 "vec3 txt_color = texture2D(screenBuffer, txt_coords).rgb;" +

                 (staticNoise !== 0 ? "
                     float noiseVal = noiseTexel.a;
                     color += noiseVal * noise * (1.0 - _distance * 1.3);" : "") +

                 (glowingLine !== 0 ? "
                     color += randomPass(coords * virtualResolution) * glowingLine;" : "") +


                 (burnIn !== 0 ? "
                     vec4 txt_blur = texture2D(burnInSource, staticCoords);
                     float blurDecay = clamp((time - burnInLastUpdate) * burnInTime, 0.0, 1.0);
                     vec3 burnInColor = 0.65 * (txt_blur.rgb - vec3(blurDecay));
                     txt_color = max(txt_color, convertWithChroma(burnInColor));"
                 : "") +

                  "txt_color += fontColor.rgb * vec3(color);" +

                  "txt_color = applyRasterization(staticCoords, txt_color, virtualResolution, rasterization_intensivity*2.0);\n" +

                (grid !== 0 ? "
                    vec2 u = screenResolution.y/5.0*qt_TexCoord0;
                    u.x *= screenResolution.x/screenResolution.y;
                    vec2 s = vec2(1.,1.732);
                    vec2 a = mod(u     ,s)*2.-s;
                    vec2 b = mod(u+s*.5,s)*2.-s;
                    
                    txt_color *= 1.0 - vec3(grid*min(dot(a,a),dot(b,b)));

                    //txt_color = txt_color*(1.5);
                    " : "") +

                 "vec3 finalColor = txt_color;" +

                 (flickering !== 0 ? "
                     finalColor *= brightness;" : "") +

                 (ambientLight !== 0 ? "
                     finalColor += vec3(ambientLight) * (1.0 - _distance) * (1.0 - _distance);" : "") +

                 (displayTerminalFrame ?
                    "vec4 frameColor = texture2D(frameSource, qt_TexCoord0);
                     finalColor = mix(finalColor, frameColor.rgb, frameColor.a);"
                 : "") +

                 "//dithering noise add
                 vec4 noise_tex = texture2D(noiseBlueSource, gl_FragCoord.xy/noiseBlueSize);
                 finalColor.rgb += vec3((noise_tex.r + noise_tex.g)-0.5)/255.0;" +

                 "gl_FragColor = vec4(finalColor, qt_Opacity);" +
             "}"

          onStatusChanged: {
              // Print warning messages
              if (log)
                  console.log(log);

              // Activate fallback mode
              if (status == ShaderEffect.Error) {
                 fallBack = true;
              }
          }
     }

     Loader {
         id: terminalFrameLoader

         active: dynamicShader.displayTerminalFrame

         width: staticShader.width
         height: staticShader.height

         sourceComponent: ShaderEffectSource {

             sourceItem: terminalFrame
             hideSource: true
             visible: false
             format: ShaderEffectSource.RGBA

             TerminalFrame {
                 id: terminalFrame
                 blending: false
                 anchors.fill: parent
             }
         }
     }

     ShaderLibrary {
         id: shaderLibrary
     }

     ShaderEffect {
         id: staticShader

         width: parent.width * appSettings.windowScaling
         height: parent.height * appSettings.windowScaling

         property ShaderEffectSource source: parent.source
         property ShaderEffectSource blurBuffer: blurShaderSource


         property ShaderEffectSource bloomSource: parent.bloomSource

         property color fontColor: parent.fontColor
         property color backgroundColor: parent.backgroundColor
         property real bloom: appSettings.bloom * 2.5

         property real screenCurvature: parent.screenCurvature

         property real chromaColor: appSettings.chromaColor;

         property real rbgShift: (appSettings.rbgShift / width) * appSettings.totalFontScaling // TODO FILIPPO width here is wrong.

         property int rasterization: appSettings.rasterization

         property real screen_brightness: Utils.lint(0.5, 1.5, appSettings.brightness)

         property real ambientLight: parent.ambientLight

         property size virtualResolution: parent.virtualResolution

         blending: false
         visible: false

         //Print the number with a reasonable precision for the shader.
         function str(num){
             return num.toFixed(8);
         }

         fragmentShader: "
             #ifdef GL_ES
                 precision mediump float;
             #endif



             uniform sampler2D blurBuffer;

             uniform sampler2D source;
             uniform highp float qt_Opacity;
             varying highp vec2 qt_TexCoord0;

             uniform highp vec4 fontColor;
             uniform highp vec4 backgroundColor;
             uniform lowp float screen_brightness;

             uniform highp vec2 virtualResolution;" +

             (bloom !== 0 ? "
                 uniform highp sampler2D bloomSource;
                 uniform lowp float bloom;" : "") +

             (screenCurvature !== 0 ? "
                 uniform highp float screenCurvature;" : "") +

             (chromaColor !== 0 ? "
                 uniform lowp float chromaColor;" : "") +

             (rbgShift !== 0 ? "
                 uniform lowp float rbgShift;" : "") +

             (ambientLight !== 0 ? "
                 uniform lowp float ambientLight;" : "") +

             shaderLibrary.min2 +
             shaderLibrary.sum2 +
             shaderLibrary.rgb2grey +

             "vec3 convertWithChroma(vec3 inColor) {
                vec3 outColor = inColor;" +

                 (chromaColor !== 0 ?
                     "outColor = fontColor.rgb * mix(vec3(rgb2grey(inColor)), inColor, chromaColor);"
                 :
                     "outColor = fontColor.rgb * rgb2grey(inColor);") +

             "  return outColor;
             }" +

             shaderLibrary.rasterizationShader +

             "void main() {" +
                 "vec2 cc = vec2(0.5) - qt_TexCoord0;" +

                 (screenCurvature !== 0 ? "
                    //barrel transfom, with zoom out + reflections
                     float distortion = dot(cc, cc) * screenCurvature;
                     vec2 curvatureCoords = (qt_TexCoord0 - cc * (1.0 + distortion) * distortion);
                     vec2 txt_coords = - 2.0 * curvatureCoords + 3.0 * step(vec2(0.0), curvatureCoords) * curvatureCoords - 3.0 * step(vec2(1.0), curvatureCoords) * curvatureCoords;"
                 :"
                     vec2 txt_coords = qt_TexCoord0;") +

                 "vec3 txt_color = texture2D(blurBuffer, txt_coords).rgb;" +

                 (rbgShift !== 0 ? "
                     vec2 displacement = vec2(12.0, 0.0) * rbgShift;
                     vec3 rightColor = texture2D(source, txt_coords + displacement).rgb;
                     vec3 leftColor = texture2D(source, txt_coords - displacement).rgb;
                     txt_color.r = leftColor.r * 0.10 + rightColor.r * 0.30 + txt_color.r * 0.60;
                     txt_color.g = leftColor.g * 0.20 + rightColor.g * 0.20 + txt_color.g * 0.60;
                     txt_color.b = leftColor.b * 0.30 + rightColor.b * 0.10 + txt_color.b * 0.60;
                 " : "") +

                  "txt_color += vec3(0.0001);" +
                  "float greyscale_color = rgb2grey(txt_color);" +

                 (screenCurvature !== 0 ? "
                     float reflectionMask = sum2(step(vec2(0.0), curvatureCoords) - step(vec2(1.0), curvatureCoords));
                     reflectionMask = clamp(reflectionMask, 0.0, 1.0);"
                 :
                     "float reflectionMask = 1.0;") +

                 (chromaColor !== 0 ?
                     "vec3 foregroundColor = mix(fontColor.rgb, txt_color * fontColor.rgb / greyscale_color, chromaColor);
                      vec3 finalColor = mix(backgroundColor.rgb, foregroundColor, greyscale_color * reflectionMask);"
                 :
                     "vec3 finalColor = mix(backgroundColor.rgb, fontColor.rgb, greyscale_color * reflectionMask);") +

                     (bloom !== 0 ?
                         "vec4 bloomFullColor = texture2D(bloomSource, txt_coords);
                          vec3 bloomColor = bloomFullColor.rgb;
                          float bloomAlpha = bloomFullColor.a;
                          bloomColor = convertWithChroma(bloomColor);
                          finalColor += clamp(bloomColor * bloom * bloomAlpha, 0.0, 0.5);"
                     : "") +

                 "finalColor *= screen_brightness;" +

                 "gl_FragColor = vec4(finalColor, qt_Opacity);" +
             "}"

         onStatusChanged: {
             // Print warning messages
             if (log) console.log(log);
         }
     }

     ShaderEffectSource {
         id: frameBuffer
         visible: false
         sourceItem: staticShader
         hideSource: true
     }

    ShaderEffectSource {
         id: blurShaderSource
         visible: false
         sourceItem: motionBlur_shaderA
         wrapMode: ShaderEffectSource.Repeat
         hideSource: true
     }

    ShaderEffect {
         id: motionBlur_shaderA


         property size screenResolution: parent.screenResolution
         property size virtualResolution: parent.virtualResolution

         width: parent.width * appSettings.windowScaling
         height: parent.height * appSettings.windowScaling

         property ShaderEffectSource source: terminal.mainSource
        property real blur:        parent.blur

         property real blurDirections: parent.blurDirections
         property real blurRadius:  parent.blurRadius
         property real blurQuality: parent.blurQuality

         property color fontColor: parent.fontColor
         property color backgroundColor: parent.backgroundColor


         property real screenCurvature: parent.screenCurvature

         property real chromaColor: appSettings.chromaColor;

         property real screen_brightness: Utils.lint(0.5, 1.5, appSettings.brightness)


         blending: false
         visible: false

         //Print the number with a reasonable precision for the shader.
         function str(num){
             return num.toFixed(8);
         }

         fragmentShader: "
             #ifdef GL_ES
                 precision mediump float;
             #endif

             uniform sampler2D source;
             
             uniform lowp float blur;
             uniform lowp float blurDirections;
             uniform lowp float blurRadius;
             uniform lowp float blurQuality;

             uniform highp float qt_Opacity;
             varying highp vec2 qt_TexCoord0;
             uniform highp vec4 fontColor;
             uniform highp vec4 backgroundColor;
             uniform lowp float screen_brightness;
             uniform vec2 screenResolution;
             uniform vec2 virtualResolution;" +



             shaderLibrary.min2 +
             shaderLibrary.sum2 +
             shaderLibrary.rgb2grey +

            "float scanline_step(vec2 uv, float num){
                uv = fract(uv*num);
                uv = uv * uv;
                return step(0.25, uv.y);
            }" +


            "vec3 get_tex(vec2 uv){
                return texture2D(source, uv).rgb;// * scanline_step(uv, virtualResolution.y);
            }" +

             "void main() {" +
                 "vec2 cc = vec2(0.5) - qt_TexCoord0;" +
                "vec3 txt_color = get_tex(qt_TexCoord0);" +
                (blur !== 0 ? "
                 const float Pi = 6.28318530718; // Pi*2

                // GAUSSIAN BLUR SETTINGS {{{
                
                float Directions = blurDirections; // BLUR DIRECTIONS (Default 16.0 - More is better but slower)
                float Quality = blurQuality; // BLUR QUALITY (Default 4.0 - More is better but slower)
                float Size = blurRadius; // BLUR SIZE (Radius)

                // GAUSSIAN BLUR SETTINGS }}}
               
                vec2 Radius = Size/screenResolution.xy;
                
                // Normalized pixel coordinates (from 0 to 1)
                // Pixel colour
                vec3 Color = get_tex(qt_TexCoord0);
                // Blur calculations
                for( float d=0.0; d<Pi; d+=Pi/Directions)
                {
                    for(float i=1.0/Quality; i<=1.0; i+=1.0/Quality)
                    {
                        Color += get_tex(qt_TexCoord0+vec2(cos(d),sin(d))*Radius*i); // * 2.0/Quality;      
                    }
                }
                    
                // Output to screen
                Color /= Quality * Directions;   
                vec3 color_blur = Color*4.0;
                txt_color = mix(txt_color, color_blur, blur);" : "") +   

                "gl_FragColor = vec4(txt_color ,qt_Opacity);" +
             "}"

         }
}



