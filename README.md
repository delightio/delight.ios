Delight
=========================

Basic Setup
-----------

1. Add Delight.framework to your target. Also make sure the following frameworks are linked:
    * AVFoundation
    * CoreGraphics
    * CoreMedia
    * CoreVideo
    * OpenGLES
    * QuartzCore

2. In your build settings, add `-ObjC` to "Other Linker Flags".

3. In your application delegate, `#import <Delight/Delight.h>`. In `applicationDidFinishLaunching:withOptions:`, call `[Delight startWithAppID:]`.

Advanced Setup
--------------

### Scale Factor and Frame Rate ###

By default, it will record at a scale factor of 1 (full size) at as many frames per second as possible. This may use up a lot of CPU, so you may want to scale down the video or limit the frame rate. To do so, call `[Delight setScaleFactor:]` and/or `[Delight setMaximumFrameRate:]` before `[Delight startWithAppID:]`.

### OpenGL ES Support ###

OpenGL ES screen capturing requires some extra work. You must call `[Delight startOpenGLWithAppID:encodeRawBytes:]` rather than `[Delight startWithAppID:]`. The encodesRawBytes parameter is used to toggle a performance boost; when enabled, capturing is faster, but gestures are not shown and the scale factor cannot be changed.

Additionally, you must call `[Delight takeOpenGLScreenshot:colorRenderBuffer:]` with your EAGLView and renderbuffer before calling `presentRenderbuffer:` in your rendering loop. If you are using a GLKView and don't have access to the renderbuffer, you can call `[Delight takeOpenGLScreenshot:backingWidth:backingHeight:]` instead and pass your GLKView along with its renderWidth and renderHeight.

### Pause/Resume ###

Call `[Delight pause]` / `[Delight resume]` to temporarily pause recording. To stop recording altogether, call `[Delight stop]`.

### Private Views ###

You may not want to record certain views, such as password prompts. Call `[Delight registerPrivateView:description:]` with a view and a descriptive text to make a view private (will appear blacked out in the recording). You must call `[Delight unregisterPrivateView:]` before the view is deallocated.

### Hiding the Keyboard ###

To prevent the keyboard from being recorded, call `[Delight setHidesKeyboardInRecording:YES]`.

Troubleshooting
---------------

* Q: Why do I get "Error creating pixel buffer:  status=-6661, pixelBufferPool=0x0"?
* A: The hardware-accelerated audio decoder may be blocking the video encoder. Try setting the audio session category to AVAudioSessionCategoryAmbient to use software audio decoding instead: `[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:NULL];`

* Q: Why is my video rotated 90º?
* A: The screen capturing operates at a window level rather than a view controller level. Windows in iOS are always in portrait mode; the view controllers take care of rotation. If your app is in landscape mode the video will therefore appear rotated.

