package dev.heggo.sonic_atlas

import com.ryanheise.audioservice.AudioServiceActivity
import java.io.File
import android.os.Bundle

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        try {
            val file = File(getExternalFilesDir(null), "tracks.json")
            file.writeText("""
hehe pp""")
            println("File written successfully to: ${file.absolutePath}")
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
