package com.appylab.rooko

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class BoundedProbeOutputTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun refusesLineThatWouldExceedTheByteCeiling() {
        val output = File(temporaryFolder.root, "probe.tsv")

        assertTrue(BoundedProbeOutput.appendLine(output, "1234", maximumBytes = 5))
        assertFalse(BoundedProbeOutput.appendLine(output, "x", maximumBytes = 5))

        assertEquals(5, output.length())
    }

    @Test
    fun refusesOneLineLargerThanAnEmptyOutputLimit() {
        val output = File(temporaryFolder.root, "probe.tsv")

        assertFalse(BoundedProbeOutput.appendLine(output, "12345", maximumBytes = 5))

        assertEquals(false, output.exists())
    }
}
