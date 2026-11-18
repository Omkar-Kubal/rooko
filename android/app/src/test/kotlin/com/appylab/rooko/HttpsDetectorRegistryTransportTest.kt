package com.appylab.rooko

import java.io.ByteArrayInputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.Principal
import java.security.Signature
import java.security.cert.Certificate
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.spec.ECGenParameterSpec
import java.util.ArrayDeque
import java.util.Base64
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLPeerUnverifiedException
import javax.security.auth.x500.X500Principal
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class HttpsDetectorRegistryTransportTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val preferences = context.getSharedPreferences("rooko_detector_registry", Context.MODE_PRIVATE)

    @Before
    fun clearCache() {
        preferences.edit().clear().commit()
    }

    @After
    fun clearCacheAfterTest() {
        preferences.edit().clear().commit()
    }

    @Test
    fun tricklingResponseStopsAtOverallDeadlineAndUsesStaticRequest() {
        var nowNanos = 0L
        val readTimeouts = mutableListOf<Int>()
        lateinit var connection: FakeHttpsURLConnection
        val body = object : InputStream() {
            private var reads = 0

            override fun read(): Int = -1

            override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
                readTimeouts += connection.readTimeout
                nowNanos += 4_000_000_000L
                reads += 1
                buffer[offset] = reads.toByte()
                return 1
            }
        }
        connection = FakeHttpsURLConnection(URL(REGISTRY_URL), body)
        var openedUrl: URL? = null
        val transport = HttpsDetectorRegistryTransport(
            connectionFactory = { url -> openedUrl = url; connection },
            monotonicNanos = { nowNanos },
            requestTimeoutMillis = 10_000,
        )

        assertNull(transport.fetch(REGISTRY_URL))
        assertEquals(REGISTRY_URL, openedUrl.toString())
        assertEquals(listOf(5_000, 5_000, 2_000), readTimeouts)
        assertEquals("GET", connection.requestMethod)
        assertFalse(connection.instanceFollowRedirects)
        assertEquals("application/json", connection.requestProperty("Accept"))
        assertEquals("identity", connection.requestProperty("Accept-Encoding"))
        assertEquals("no-cache", connection.requestProperty("Cache-Control"))
        assertEquals("Rooko-DetectorRegistry/1", connection.requestProperty("User-Agent"))
        assertTrue(connection.disconnected)
    }

    @Test
    fun slowResponseHeadersAreCancelledAtTheOverallDeadline() {
        val disconnectSignal = CountDownLatch(1)
        val connection = FakeHttpsURLConnection(
            url = URL(REGISTRY_URL),
            body = InputStream.nullInputStream(),
            responseAction = {
                disconnectSignal.await(400, TimeUnit.MILLISECONDS)
                HttpURLConnection.HTTP_OK
            },
            onDisconnect = { disconnectSignal.countDown() },
        )
        val transport = HttpsDetectorRegistryTransport(
            connectionFactory = { connection },
            requestTimeoutMillis = 50,
        )
        val startedAtNanos = System.nanoTime()

        assertNull(transport.fetch(REGISTRY_URL))

        val elapsedMillis = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startedAtNanos)
        assertTrue("request exceeded its 50 ms deadline: ${elapsedMillis}ms", elapsedMillis < 300)
        assertTrue(connection.disconnected)
    }

    @Test
    fun timeoutReturnsValidCacheAndALaterRefreshCanReplaceIt() {
        val signingKey = keyPair()
        var nowMillis = NOW_SECONDS * 1_000L
        var nowNanos = 0L
        val connections = ArrayDeque<FakeHttpsURLConnection>()
        val transport = HttpsDetectorRegistryTransport(
            connectionFactory = { url ->
                assertEquals(REGISTRY_URL, url.toString())
                connections.removeFirst()
            },
            monotonicNanos = { nowNanos },
            requestTimeoutMillis = 10_000,
        )
        val registry = DetectorVersionRegistry(
            context = context,
            registryUrl = REGISTRY_URL,
            registryPublicKeyBase64 = Base64.getEncoder().encodeToString(signingKey.public.encoded),
            transport = transport,
            clockMillis = { nowMillis },
        )

        connections += FakeHttpsURLConnection(
            URL(REGISTRY_URL),
            ByteArrayInputStream(signedEnvelope(signingKey, sequence = 3)),
        )
        assertEquals(3L, refresh(registry)?.sequence)

        nowMillis += REFRESH_INTERVAL_MILLIS + 1L
        val slowConnection = FakeHttpsURLConnection(
            URL(REGISTRY_URL),
            tricklingBody { nowNanos += 4_000_000_000L },
        )
        connections += slowConnection
        assertEquals(3L, refresh(registry)?.sequence)
        assertTrue(slowConnection.disconnected)

        nowMillis += REFRESH_INTERVAL_MILLIS + 1L
        connections += FakeHttpsURLConnection(
            URL(REGISTRY_URL),
            ByteArrayInputStream(signedEnvelope(signingKey, sequence = 4)),
        )
        assertEquals(4L, refresh(registry)?.sequence)
    }

    @Test
    fun rejectsRedirectsAndStreamingBodiesOverTheEnvelopeLimit() {
        var bodyRead = false
        val redirect = FakeHttpsURLConnection(
            URL(REGISTRY_URL),
            object : InputStream() {
                override fun read(): Int {
                    bodyRead = true
                    return -1
                }
            },
            responseAction = { HttpURLConnection.HTTP_MOVED_TEMP },
        )
        val redirectTransport = HttpsDetectorRegistryTransport(connectionFactory = { redirect })

        assertNull(redirectTransport.fetch(REGISTRY_URL))
        assertFalse(bodyRead)
        assertTrue(redirect.disconnected)

        val oversized = FakeHttpsURLConnection(
            URL(REGISTRY_URL),
            ByteArrayInputStream(ByteArray(MAX_ENVELOPE_BYTES + 1)),
        )
        val oversizedTransport = HttpsDetectorRegistryTransport(connectionFactory = { oversized })

        assertNull(oversizedTransport.fetch(REGISTRY_URL))
        assertTrue(oversized.disconnected)
    }

    private fun refresh(registry: DetectorVersionRegistry): VerifiedDetectorRegistry? {
        val completed = CountDownLatch(1)
        val result = AtomicReference<VerifiedDetectorRegistry?>()
        registry.refreshAsync {
            result.set(it)
            completed.countDown()
        }
        assertTrue(completed.await(3, TimeUnit.SECONDS))
        return result.get()
    }

    private fun tricklingBody(advanceClock: () -> Unit): InputStream = object : InputStream() {
        override fun read(): Int = -1

        override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
            advanceClock()
            buffer[offset] = 1
            return 1
        }
    }

    private fun signedEnvelope(keyPair: KeyPair, sequence: Long): ByteArray {
        val entry = JSONObject()
            .put("packageName", YOUTUBE)
            .put("versionName", "21.45.82")
            .put("status", "catalogued")
            .put("sourceUrl", "https://archive.example/21.45.82")
        val payload = JSONObject()
            .put("schemaVersion", 1)
            .put("sequence", sequence)
            .put("issuedAtEpochSeconds", NOW_SECONDS - 10)
            .put("expiresAtEpochSeconds", NOW_SECONDS + REGISTRY_LIFETIME_SECONDS)
            .put("entries", JSONArray().put(entry))
            .toString()
            .toByteArray(Charsets.UTF_8)
        val signature = Signature.getInstance("SHA256withECDSA").run {
            initSign(keyPair.private)
            update(payload)
            sign()
        }
        return JSONObject()
            .put("payload", Base64.getEncoder().encodeToString(payload))
            .put("signature", Base64.getEncoder().encodeToString(signature))
            .toString()
            .toByteArray(Charsets.UTF_8)
    }

    private fun keyPair(): KeyPair = KeyPairGenerator.getInstance("EC").apply {
        initialize(ECGenParameterSpec("secp256r1"))
    }.generateKeyPair()

    private class FakeHttpsURLConnection(
        url: URL,
        private val body: InputStream,
        private val responseAction: () -> Int = { HTTP_OK },
        private val onDisconnect: () -> Unit = {},
        private val contentLength: Long = -1L,
    ) : HttpsURLConnection(url) {
        private val headers = mutableMapOf<String, String>()
        var disconnected = false
            private set

        override fun connect() = Unit

        override fun disconnect() {
            disconnected = true
            onDisconnect()
        }

        override fun usingProxy(): Boolean = false

        override fun getResponseCode(): Int = responseAction()

        override fun getContentLengthLong(): Long = contentLength

        override fun getInputStream(): InputStream = body

        override fun setRequestProperty(key: String, value: String) {
            headers[key] = value
        }

        fun requestProperty(key: String): String? = headers[key]

        override fun getCipherSuite(): String = "TLS_TEST"

        override fun getLocalCertificates(): Array<Certificate>? = null

        override fun getServerCertificates(): Array<Certificate> =
            throw SSLPeerUnverifiedException("No peer in fake connection")

        override fun getPeerPrincipal(): Principal = X500Principal("CN=registry.example.test")

        override fun getLocalPrincipal(): Principal? = null
    }

    private companion object {
        const val YOUTUBE = "com.google.android.youtube"
        const val REGISTRY_URL = "https://registry.example.test/sync-scroll/v1/registry.json"
        const val NOW_SECONDS = 1_800_000_000L
        const val REFRESH_INTERVAL_MILLIS = 15 * 60 * 1_000L
        const val REGISTRY_LIFETIME_SECONDS = 30 * 24 * 60 * 60L
        const val MAX_ENVELOPE_BYTES = 512 * 1024
    }
}
