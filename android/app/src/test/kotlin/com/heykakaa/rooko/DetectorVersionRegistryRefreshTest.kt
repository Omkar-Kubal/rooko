package com.heykakaa.rooko

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import java.nio.charset.StandardCharsets
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.Base64
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DetectorVersionRegistryRefreshTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val preferences by lazy {
        context.getSharedPreferences("rooko_detector_registry", Context.MODE_PRIVATE)
    }

    @Before
    fun clearRegistryCache() {
        preferences.edit().clear().commit()
    }

    @After
    fun clearRegistryCacheAfterTest() {
        preferences.edit().clear().commit()
    }

    @Test
    fun keepsCacheWhenRefreshRollsBackOrReusesSequenceWithChangedPayload() {
        val signingKey = keyPair()
        var nowMillis = NOW_SECONDS * 1000L
        val transport = FakeTransport()
        val registry = client(transport, signingKey, clock = { nowMillis })
        transport.response = envelope(signingKey, sequence = 9)

        assertEquals(9L, refresh(registry)?.sequence)
        val acceptedDigest = registry.readVerified()?.payloadDigest

        nowMillis += REFRESH_INTERVAL_MILLIS + 1
        transport.response = envelope(signingKey, sequence = 8)
        assertEquals(9L, refresh(registry)?.sequence)
        assertEquals(acceptedDigest, registry.readVerified()?.payloadDigest)

        nowMillis += REFRESH_INTERVAL_MILLIS + 1
        transport.response = envelope(signingKey, sequence = 9, sourceUrl = "https://archive.example/changed")
        assertEquals(9L, refresh(registry)?.sequence)
        assertEquals(acceptedDigest, registry.readVerified()?.payloadDigest)
        assertEquals("https://archive.example/21.45.82", registry.readVerified()
            ?.entryFor(YOUTUBE, "21.45.82")?.sourceUrl)
    }

    @Test
    fun preservesUnexpiredCacheOnInvalidRefreshAndExpiresItOffline() {
        val signingKey = keyPair()
        var nowMillis = NOW_SECONDS * 1000L
        val transport = FakeTransport()
        val registry = client(transport, signingKey, clock = { nowMillis })
        transport.response = envelope(signingKey, sequence = 3)
        assertNotNull(refresh(registry))

        nowMillis += REFRESH_INTERVAL_MILLIS + 1
        transport.response = "{bad signature}".toByteArray(StandardCharsets.UTF_8)
        assertEquals(3L, refresh(registry)?.sequence)

        nowMillis = (NOW_SECONDS + REGISTRY_LIFETIME_SECONDS) * 1000L
        transport.response = null
        assertNull(registry.readVerified())
        assertNull(refresh(registry))
    }

    @Test
    fun coalescesConcurrentCallbacksForOneFixedRegistryRequest() {
        val signingKey = keyPair()
        val transport = FakeTransport()
        transport.response = envelope(signingKey, sequence = 4)
        transport.blockFetch = true
        val registry = client(transport, signingKey, clock = { NOW_SECONDS * 1000L })
        val callbacks = CountDownLatch(2)
        val callbackValues = mutableListOf<VerifiedDetectorRegistry?>()

        registry.refreshAsync {
            synchronized(callbackValues) { callbackValues += it }
            callbacks.countDown()
        }
        assertTrue(transport.fetchStarted.await(2, TimeUnit.SECONDS))
        registry.refreshAsync {
            synchronized(callbackValues) { callbackValues += it }
            callbacks.countDown()
        }
        transport.allowFetchToFinish.countDown()

        assertTrue(callbacks.await(3, TimeUnit.SECONDS))
        assertEquals(1, transport.fetchCount.get())
        assertEquals(listOf(REGISTRY_URL), transport.requestedUrls)
        assertEquals(listOf(4L, 4L), synchronized(callbackValues) { callbackValues.map { it?.sequence } })
    }

    @Test
    fun rejectsEndpointWithQueryAndOversizedTransportBody() {
        val signingKey = keyPair()
        val queryTransport = FakeTransport().apply { response = envelope(signingKey, sequence = 1) }
        val queryClient = client(
            transport = queryTransport,
            keyPair = signingKey,
            registryUrl = "$REGISTRY_URL?installedVersion=21.45.82",
            clock = { NOW_SECONDS * 1000L },
        )
        assertNull(refresh(queryClient))
        assertEquals(0, queryTransport.fetchCount.get())

        preferences.edit().clear().commit()
        val oversizedTransport = FakeTransport().apply { response = ByteArray(512 * 1024 + 1) }
        val oversizedClient = client(
            transport = oversizedTransport,
            keyPair = signingKey,
            clock = { NOW_SECONDS * 1000L },
        )
        assertNull(refresh(oversizedClient))
        assertEquals(1, oversizedTransport.fetchCount.get())
        assertNull(oversizedClient.readVerified())
    }

    @Test
    fun doesNotContactTransportWhenRegistryConfigurationIsMissing() {
        val signingKey = keyPair()
        val transport = FakeTransport().apply { response = envelope(signingKey, sequence = 1) }
        val registry = DetectorVersionRegistry(
            context = context,
            registryUrl = "",
            registryPublicKeyBase64 = Base64.getEncoder().encodeToString(signingKey.public.encoded),
            transport = transport,
            clockMillis = { NOW_SECONDS * 1000L },
        )

        assertNull(refresh(registry))
        assertEquals(0, transport.fetchCount.get())
    }

    private fun client(
        transport: FakeTransport,
        keyPair: KeyPair,
        registryUrl: String = REGISTRY_URL,
        clock: () -> Long = { System.currentTimeMillis() },
    ) = DetectorVersionRegistry(
        context = context,
        registryUrl = registryUrl,
        registryPublicKeyBase64 = Base64.getEncoder().encodeToString(keyPair.public.encoded),
        transport = transport,
        clockMillis = clock,
    )

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

    private fun envelope(
        keyPair: KeyPair,
        sequence: Long,
        sourceUrl: String = "https://archive.example/21.45.82",
    ): ByteArray {
        val entry = JSONObject()
            .put("packageName", YOUTUBE)
            .put("versionName", "21.45.82")
            .put("status", "catalogued")
            .put("sourceUrl", sourceUrl)
        val payload = JSONObject()
            .put("schemaVersion", 1)
            .put("sequence", sequence)
            .put("issuedAtEpochSeconds", NOW_SECONDS - 10)
            .put("expiresAtEpochSeconds", NOW_SECONDS + REGISTRY_LIFETIME_SECONDS)
            .put("entries", JSONArray().put(entry))
            .toString()
            .toByteArray(StandardCharsets.UTF_8)
        val signature = Signature.getInstance("SHA256withECDSA").run {
            initSign(keyPair.private)
            update(payload)
            sign()
        }
        return JSONObject()
            .put("payload", Base64.getEncoder().encodeToString(payload))
            .put("signature", Base64.getEncoder().encodeToString(signature))
            .toString()
            .toByteArray(StandardCharsets.UTF_8)
    }

    private fun keyPair(): KeyPair = KeyPairGenerator.getInstance("EC").apply {
        initialize(ECGenParameterSpec("secp256r1"))
    }.generateKeyPair()

    private class FakeTransport : DetectorRegistryTransport {
        val fetchCount = AtomicInteger()
        val fetchStarted = CountDownLatch(1)
        val allowFetchToFinish = CountDownLatch(1)
        val requestedUrls = mutableListOf<String>()
        @Volatile var response: ByteArray? = null
        @Volatile var blockFetch = false

        override fun fetch(endpoint: String): ByteArray? {
            synchronized(requestedUrls) { requestedUrls += endpoint }
            fetchCount.incrementAndGet()
            fetchStarted.countDown()
            if (blockFetch) check(allowFetchToFinish.await(3, TimeUnit.SECONDS))
            return response
        }
    }

    private companion object {
        const val YOUTUBE = "com.google.android.youtube"
        const val REGISTRY_URL = "https://registry.example.test/sync-scroll/v1/registry.json"
        const val NOW_SECONDS = 1_800_000_000L
        const val REFRESH_INTERVAL_MILLIS = 15 * 60 * 1000L
        const val REGISTRY_LIFETIME_SECONDS = 30 * 24 * 60 * 60L
    }
}
