mergeInto(LibraryManager.library, {
  RenkSyncSave: function () {
    // Serialize IDBFS commits; a second save while syncing schedules another pass.
    if (Module.renkSaveBusy) { Module.renkSaveAgain = true; return; }
    Module.renkSaveBusy = true;
    var flush = function () {
      Module.renkSaveAgain = false;
      FS.syncfs(false, function (error) {
        if (error) console.warn('Renk save sync:', error);
        if (Module.renkSaveAgain) flush();
        else Module.renkSaveBusy = false;
      });
    };
    flush();
  }
});
