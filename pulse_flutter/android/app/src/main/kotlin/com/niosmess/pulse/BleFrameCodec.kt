package com.niosmess.pulse

import java.io.ByteArrayOutputStream

/** Small bounded framing shared by central writes and peripheral indications. */
internal class BleFrameCodec(private val clock: () -> Long) {
    private var buffer: ByteArrayOutputStream? = null
    private var expected = 0
    private var sequence = 0
    private var started = 0L

    fun accept(value: ByteArray): ByteArray? {
        require(value.isNotEmpty() && value.size <= 512)
        if (buffer != null && clock() - started > 60000) reset()
        when (value[0].toInt()) {
            1 -> {
                require(value.size == 3)
                val length = ((value[1].toInt() and 255) shl 8) or (value[2].toInt() and 255)
                require(length in 1..MAX_FRAME)
                expected = length; sequence = 0; started = clock()
                buffer = ByteArrayOutputStream(length)
            }
            2 -> {
                val target = buffer ?: throw IllegalArgumentException("Missing frame start")
                require(value.size >= 4)
                val index = ((value[1].toInt() and 255) shl 8) or (value[2].toInt() and 255)
                require(index == sequence && target.size() + value.size - 3 <= expected)
                sequence++; target.write(value, 3, value.size - 3)
            }
            3 -> {
                require(value.size == 1)
                val target = buffer ?: throw IllegalArgumentException("Missing frame")
                require(target.size() == expected)
                val result = target.toByteArray(); reset(); return result
            }
            else -> throw IllegalArgumentException("Unknown frame")
        }
        return null
    }
    fun reset() { buffer = null; expected = 0; sequence = 0 }
    companion object {
        const val MAX_FRAME = 25600
        fun encode(value: ByteArray, capacity: Int): List<ByteArray> {
            require(value.size in 1..MAX_FRAME && capacity in 20..512)
            val chunks = mutableListOf(byteArrayOf(1, (value.size shr 8).toByte(), value.size.toByte()))
            var offset = 0; var sequence = 0
            while (offset < value.size) {
                val count = minOf(capacity - 3, value.size - offset)
                val chunk = ByteArray(count + 3)
                chunk[0] = 2; chunk[1] = (sequence shr 8).toByte(); chunk[2] = sequence.toByte()
                value.copyInto(chunk, 3, offset, offset + count)
                chunks.add(chunk); offset += count; sequence++
            }
            chunks.add(byteArrayOf(3)); return chunks
        }
    }
}
