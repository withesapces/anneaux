package fr.webeedigital.anneaux

import android.annotation.TargetApi
import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity : exigé par Health Connect.
// Canal « anneaux/files » : sauvegarde dans Téléchargements/Anneaux et ouverture d'un fichier.
class MainActivity : FlutterFragmentActivity() {
    private var pendingOpen: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "anneaux/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "save" -> {
                        val name = call.argument<String>("name")
                        val text = call.argument<String>("text")
                        if (name == null || text == null) {
                            result.error("args", "Nom ou contenu manquant", null)
                        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            result.error("save", "Android 10 minimum pour la sauvegarde automatique", null)
                        } else {
                            try {
                                result.success(save(name, text))
                            } catch (e: Exception) {
                                result.error("save", e.message ?: e.toString(), null)
                            }
                        }
                    }
                    "open" -> {
                        if (pendingOpen != null) {
                            result.error("busy", "Sélecteur déjà ouvert", null)
                        } else {
                            pendingOpen = result
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, OPEN_REQUEST)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Écrit le fichier dans Téléchargements/Anneaux, en remplaçant celui du même nom créé par l'app. */
    @TargetApi(Build.VERSION_CODES.Q)
    private fun save(name: String, text: String): String {
        val folder = Environment.DIRECTORY_DOWNLOADS + "/Anneaux/"
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        var target: Uri? = null
        contentResolver.query(
            collection,
            arrayOf(MediaStore.MediaColumns._ID),
            "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND ${MediaStore.MediaColumns.DISPLAY_NAME}=?",
            arrayOf(folder, name),
            null
        )?.use { c ->
            if (c.moveToFirst()) target = ContentUris.withAppendedId(collection, c.getLong(0))
        }
        val uri: Uri = target ?: contentResolver.insert(collection, ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
            put(MediaStore.MediaColumns.RELATIVE_PATH, folder)
        }) ?: throw Exception("Création du fichier impossible")
        val out = contentResolver.openOutputStream(uri, "wt") ?: throw Exception("Écriture impossible")
        out.use { it.write(text.toByteArray(Charsets.UTF_8)) }
        return folder + name
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != OPEN_REQUEST) return
        val result = pendingOpen ?: return
        pendingOpen = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val input = contentResolver.openInputStream(uri) ?: throw Exception("Lecture impossible")
            val text = input.use { it.readBytes().toString(Charsets.UTF_8) }
            result.success(text)
        } catch (e: Exception) {
            result.error("open", e.message ?: e.toString(), null)
        }
    }

    companion object {
        private const val OPEN_REQUEST = 4207
    }
}
