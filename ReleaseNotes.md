delight.io Release Notes
========================
___

2.0
===
___

delight.io 2.0 contains a number of API additions, performance improvements, and bug fixes. Users running previous versions of the framework must upgrade to version 2.0; otherwise, new sessions will not be recorded, regardless of whether recordings have been scheduled.

Important Notes
---------------

* A new framework dependency has been added: developers must now link AssetsLibrary.framework in their targets.

Changelog
---------

* API additions:
  * **App User ID Field**: To associate a recording with a particular user, you can call `[Delight setAppUserID:]` with an NSString identifier of your choosing. This identifier will be displayed when viewing the recording in the control panel.

  * **Debug Logging**: Debug logging to the console can be turned on/off by calling `[Delight setDebugLogEnabled:]`.

* Improved UIKit performance.

* Made private views flash when receiving touch events.

* Fixed a crash that occurred when a new session could not be created (e.g. if the app token was invalid).

* Fixed a crash that occurred when recording a UIWebView.

* Fixed touch locations being incorrect in windows other than the main window.

