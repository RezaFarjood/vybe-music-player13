"""Compile the VYBE Kotlin MediaStore bridge against local typed stubs.
This catches Kotlin syntax/signature errors, NOT Gradle/plugin/runtime problems.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
STUBS = {
    'Manifest.kt': '''package android
object Manifest { object permission { const val READ_MEDIA_AUDIO="audio"; const val READ_EXTERNAL_STORAGE="external" } }
''',
    'PackageManager.kt': '''package android.content.pm
object PackageManager { const val PERMISSION_GRANTED=0 }
''',
    'Build.kt': '''package android.os
object Build { object VERSION { const val SDK_INT=35 } }
''',
    'MediaStore.kt': '''package android.provider
object MediaStore { object Audio { object Media {
 const val DATA="_data"; const val IS_MUSIC="is_music"; const val TITLE="title";
 val EXTERNAL_CONTENT_URI:Any = Any()
} } }
''',
    'Cursor.kt': '''package android.database
interface Cursor: java.io.Closeable {
 fun getColumnIndex(columnName:String):Int
 fun moveToNext():Boolean
 fun getString(columnIndex:Int):String?
}
''',
    'Activity.kt': '''package android.app
open class Activity {
 val contentResolver=ContentResolver()
 open fun checkSelfPermission(permission:String):Int=0
 open fun requestPermissions(permissions:Array<String>, requestCode:Int) {}
 open fun runOnUiThread(runnable:Runnable) { runnable.run() }
}
class ContentResolver {
 fun query(uri:Any,projection:Array<String>,selection:String?, selectionArgs:Array<String>?,sortOrder:String?):android.database.Cursor?=null
}
''',
    'FlutterEngine.kt': '''package io.flutter.embedding.engine
class FlutterEngine { val dartExecutor=DartExecutor() }
class DartExecutor { val binaryMessenger:Any=Any() }
''',
    'MethodChannel.kt': '''package io.flutter.plugin.common
class MethodChannel(messenger:Any, name:String) {
 class MethodCall(val method:String)
 interface Result {
  fun success(value:Any?)
  fun error(errorCode:String,errorMessage:String?,errorDetails:Any?)
  fun notImplemented()
 }
 fun setMethodCallHandler(handler:(MethodCall,Result)->Unit) {}
}
''',
    'AudioServiceActivity.kt': '''package com.ryanheise.audioservice
open class AudioServiceActivity: android.app.Activity() {
 open fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {}
 open fun onRequestPermissionsResult(requestCode:Int, permissions:Array<out String>, grantResults:IntArray) {}
}
''',
}
class KotlinSmoke(unittest.TestCase):
    @unittest.skipUnless(shutil.which('kotlinc'), 'Kotlin CLI unavailable')
    def test_android_bridge_compiles_against_api_stubs(self):
        with tempfile.TemporaryDirectory() as work:
            base=Path(work)
            for name, contents in STUBS.items():
                (base/name).write_text(contents, encoding='utf-8')
            activity=(ROOT/'scripts/android/MainActivity.kt.template').read_text(encoding='utf-8')
            (base/'MainActivity.kt').write_text(activity, encoding='utf-8')
            command=['kotlinc',*[str(f) for f in base.glob('*.kt')],'-d',str(base/'out.jar')]
            result=subprocess.run(command,capture_output=True,text=True,timeout=90)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)

if __name__=='__main__':unittest.main()
